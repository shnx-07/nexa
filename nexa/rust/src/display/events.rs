//! Live Event Listener & Debouncer (`events.rs`)
//!
//! Turns three noisy sources into a calm stream of normalized `DisplayEvent`s:
//! 1. Hyprland `.socket2.sock` (monitor added/removed, config reloaded).
//! 2. A 1 Hz poller for ACPI lid state and AC power state.
//! 3. A trailing-edge debouncer (200 ms) so a dock that fires many pulses
//!    produces exactly one event.
//!
//! This module NEVER mutates display state. It only reports that "something changed";
//! `manager.rs` re-reads the real hardware and decides what to do.
//!
//! Threads spawned by `spawn_event_listener`:
//! - `nexa-hypr-socket`: reads socket2, reconnects with backoff, sends raw events.
//! - `nexa-debounce`:    coalesces raw bursts into one event.
//! - `nexa-sys-poll`:    watches lid + AC power.

use crate::display::backend;
use crate::display::discovery::{parse_lid_state, parse_power_state};
use crate::display::model::{DisplayEvent, LidState, PowerState};
use std::io::{BufRead, BufReader};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::sync::mpsc::{self, Receiver, RecvTimeoutError, Sender};
use std::thread;
use std::time::{Duration, Instant};

/// Quiet period after the last pulse before a hotplug event is emitted.
pub const HOTPLUG_DEBOUNCE: Duration = Duration::from_millis(200);
/// Upper bound on how long a continuous stream of pulses can delay an event.
pub const HOTPLUG_MAX_WAIT: Duration = Duration::from_millis(1000);
/// Poll interval for lid and AC state.
pub const SYSTEM_POLL_INTERVAL: Duration = Duration::from_millis(1000);

const RECONNECT_MIN: Duration = Duration::from_millis(500);
const RECONNECT_MAX: Duration = Duration::from_secs(5);

/// Starts all background threads and returns the receiving end of the event stream.
///
/// The returned channel closes only if the consumer drops it (threads then exit).
pub fn spawn_event_listener() -> Receiver<DisplayEvent> {
    let (out_tx, out_rx) = mpsc::channel::<DisplayEvent>();
    let (raw_tx, raw_rx) = mpsc::channel::<DisplayEvent>();

    {
        let out_tx = out_tx.clone();
        thread::Builder::new()
            .name("nexa-debounce".into())
            .spawn(move || run_debouncer(raw_rx, out_tx, HOTPLUG_DEBOUNCE, HOTPLUG_MAX_WAIT))
            .expect("failed to spawn nexa-debounce thread");
    }

    thread::Builder::new()
        .name("nexa-hypr-socket".into())
        .spawn(move || run_socket_listener(raw_tx))
        .expect("failed to spawn nexa-hypr-socket thread");

    thread::Builder::new()
        .name("nexa-sys-poll".into())
        .spawn(move || run_system_poller(out_tx))
        .expect("failed to spawn nexa-sys-poll thread");

    out_rx
}

// ---------------------------------------------------------------------------
// Pure parsing
// ---------------------------------------------------------------------------

/// Parses one line from Hyprland's socket2 (`EVENT>>DATA`) into a domain event.
/// Returns `None` for events we do not care about (focus changes, window events, ...).
pub fn parse_hyprland_event(line: &str) -> Option<DisplayEvent> {
    let (name, data) = line.trim().split_once(">>")?;
    match name {
        // v1: DATA = "name"
        "monitoradded" | "monitorremoved" => Some(DisplayEvent::HotplugChanged {
            connector: non_empty(data),
        }),
        // v2: DATA = "id,name,description"
        "monitoraddedv2" | "monitorremovedv2" => Some(DisplayEvent::HotplugChanged {
            connector: data.split(',').nth(1).and_then(non_empty),
        }),
        // User edited hyprland.conf; static monitor= rules may have overridden ours.
        "configreloaded" => Some(DisplayEvent::ForceRefresh),
        _ => None,
    }
}

fn non_empty(s: &str) -> Option<String> {
    let t = s.trim();
    if t.is_empty() {
        None
    } else {
        Some(t.to_string())
    }
}

// ---------------------------------------------------------------------------
// Hyprland socket2 listener
// ---------------------------------------------------------------------------

fn socket2_path() -> Result<PathBuf, String> {
    let signature = std::env::var("HYPRLAND_INSTANCE_SIGNATURE")
        .map_err(|_| "HYPRLAND_INSTANCE_SIGNATURE not set".to_string())?;
    let runtime_dir = std::env::var("XDG_RUNTIME_DIR")
        .ok()
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| "/run/user/1000".to_string());
    Ok(PathBuf::from(runtime_dir)
        .join("hypr")
        .join(signature)
        .join(".socket2.sock"))
}

/// Reads socket2 forever, reconnecting with exponential backoff.
/// On every (re)connect a `ForceRefresh` is emitted, because events may have been
/// missed while disconnected (and it reconciles state at daemon startup).
fn run_socket_listener(raw_tx: Sender<DisplayEvent>) {
    let mut backoff = RECONNECT_MIN;

    loop {
        match socket2_path().and_then(|p| {
            UnixStream::connect(&p).map_err(|e| format!("connect {}: {}", p.display(), e))
        }) {
            Ok(stream) => {
                backoff = RECONNECT_MIN;
                if raw_tx.send(DisplayEvent::ForceRefresh).is_err() {
                    return;
                }

                let reader = BufReader::new(stream);
                // `split` + lossy decode: a stray non-UTF-8 byte (e.g. in a window title)
                // must not tear down the whole listener.
                for chunk in reader.split(b'\n') {
                    let Ok(bytes) = chunk else { break };
                    let line = String::from_utf8_lossy(&bytes);
                    if let Some(event) = parse_hyprland_event(&line) {
                        if raw_tx.send(event).is_err() {
                            return; // debouncer gone -> shutting down
                        }
                    }
                }
                eprintln!("[NexaDisplay] Hyprland socket2 closed; reconnecting...");
            }
            Err(e) => {
                eprintln!(
                    "[NexaDisplay] socket2 unavailable ({}); retrying in {:?}",
                    e, backoff
                );
            }
        }

        thread::sleep(backoff);
        backoff = (backoff * 2).min(RECONNECT_MAX);
    }
}

// ---------------------------------------------------------------------------
// Debouncer
// ---------------------------------------------------------------------------

/// Trailing-edge debouncer with a maximum wait.
///
/// Every incoming event restarts the quiet-period timer and replaces the pending event
/// (the manager always re-reads real hardware, so only "something changed" matters).
/// `max_wait` guarantees that a never-ending stream of pulses cannot starve the consumer.
pub fn run_debouncer(
    raw_rx: Receiver<DisplayEvent>,
    tx: Sender<DisplayEvent>,
    debounce: Duration,
    max_wait: Duration,
) {
    let mut pending: Option<DisplayEvent> = None;
    let mut first_seen = Instant::now();

    loop {
        let received = if pending.is_some() {
            let until_max = max_wait.saturating_sub(first_seen.elapsed());
            raw_rx.recv_timeout(debounce.min(until_max))
        } else {
            raw_rx.recv().map_err(|_| RecvTimeoutError::Disconnected)
        };

        match received {
            Ok(event) => {
                if pending.is_none() {
                    first_seen = Instant::now();
                }
                pending = Some(event);

                // Hit the cap while events are still streaming in: flush now.
                if first_seen.elapsed() >= max_wait {
                    if let Some(ev) = pending.take() {
                        if tx.send(ev).is_err() {
                            return;
                        }
                    }
                }
            }
            Err(RecvTimeoutError::Timeout) => {
                if let Some(ev) = pending.take() {
                    if tx.send(ev).is_err() {
                        return;
                    }
                }
            }
            Err(RecvTimeoutError::Disconnected) => {
                if let Some(ev) = pending.take() {
                    let _ = tx.send(ev);
                }
                return;
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Lid + power poller
// ---------------------------------------------------------------------------

fn read_lid() -> LidState {
    parse_lid_state(backend::read_lid_state_raw().as_deref())
}

fn read_power() -> PowerState {
    parse_power_state(backend::read_ac_online_raw().as_deref())
}

/// Emits `LidChanged` / `PowerChanged` on transitions.
/// Transitions *to* `Unknown` are ignored: a failed sysfs/procfs read is a glitch,
/// not a real state change, and must not flip the layout.
fn run_system_poller(tx: Sender<DisplayEvent>) {
    let mut last_lid = read_lid();
    let mut last_power = read_power();

    loop {
        thread::sleep(SYSTEM_POLL_INTERVAL);

        let lid = read_lid();
        if lid != LidState::Unknown && lid != last_lid {
            last_lid = lid;
            if tx.send(DisplayEvent::LidChanged(lid)).is_err() {
                return;
            }
        }

        let power = read_power();
        if power != PowerState::Unknown && power != last_power {
            last_power = power;
            if tx.send(DisplayEvent::PowerChanged(power)).is_err() {
                return;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_monitor_v1_events() {
        assert_eq!(
            parse_hyprland_event("monitoradded>>HDMI-A-1"),
            Some(DisplayEvent::HotplugChanged {
                connector: Some("HDMI-A-1".into())
            })
        );
        assert_eq!(
            parse_hyprland_event("monitorremoved>>DP-2\n"),
            Some(DisplayEvent::HotplugChanged {
                connector: Some("DP-2".into())
            })
        );
    }

    #[test]
    fn parses_monitor_v2_events() {
        assert_eq!(
            parse_hyprland_event("monitoraddedv2>>1,DP-1,Dell Inc. U2720Q"),
            Some(DisplayEvent::HotplugChanged {
                connector: Some("DP-1".into())
            })
        );
        assert_eq!(
            parse_hyprland_event("monitorremovedv2>>1"),
            Some(DisplayEvent::HotplugChanged { connector: None })
        );
    }

    #[test]
    fn parses_config_reload_and_ignores_noise() {
        assert_eq!(
            parse_hyprland_event("configreloaded>>"),
            Some(DisplayEvent::ForceRefresh)
        );
        assert_eq!(parse_hyprland_event("activewindow>>kitty,~"), None);
        assert_eq!(parse_hyprland_event("garbage without separator"), None);
    }

    #[test]
    fn debouncer_coalesces_burst_into_one_event() {
        let (raw_tx, raw_rx) = mpsc::channel();
        let (tx, rx) = mpsc::channel();
        let handle = thread::spawn(move || {
            run_debouncer(
                raw_rx,
                tx,
                Duration::from_millis(50),
                Duration::from_millis(500),
            )
        });

        for i in 0..5 {
            raw_tx
                .send(DisplayEvent::HotplugChanged {
                    connector: Some(format!("DP-{i}")),
                })
                .unwrap();
            thread::sleep(Duration::from_millis(10));
        }

        let first = rx.recv_timeout(Duration::from_millis(500)).unwrap();
        assert_eq!(
            first,
            DisplayEvent::HotplugChanged {
                connector: Some("DP-4".into())
            }
        );
        assert!(rx.recv_timeout(Duration::from_millis(150)).is_err());

        drop(raw_tx);
        handle.join().unwrap();
    }

    #[test]
    fn debouncer_max_wait_prevents_starvation() {
        let (raw_tx, raw_rx) = mpsc::channel();
        let (tx, rx) = mpsc::channel();
        let handle = thread::spawn(move || {
            run_debouncer(
                raw_rx,
                tx,
                Duration::from_millis(100),
                Duration::from_millis(150),
            )
        });

        // Pulses every 40 ms would never let a 100 ms quiet window elapse.
        let sender = thread::spawn(move || {
            for _ in 0..10 {
                if raw_tx.send(DisplayEvent::ForceRefresh).is_err() {
                    break;
                }
                thread::sleep(Duration::from_millis(40));
            }
        });

        assert!(rx.recv_timeout(Duration::from_millis(300)).is_ok());
        sender.join().unwrap();
        drop(rx);
        let _ = handle.join();
    }
}
