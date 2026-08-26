use serde::{Deserialize, Serialize};
use std::{
    env,
    fs,
    path::PathBuf,
    process::{Command, Stdio},
    thread,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

#[derive(Debug, Serialize)]
struct RecorderResponse {
    success: bool,
    action: &'static str,

    recording: bool,
    paused: bool,

    pid: Option<u32>,
    path: Option<String>,

    elapsed: u64,

    message: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct RecorderState {
    pid: u32,
    path: String,

    started_at: u64,

    paused: bool,
    paused_at: Option<u64>,

    total_paused: u64,
}

// ============================================================
// JSON
// ============================================================

fn print_json<T: Serialize>(
    value: &T,
) {
    match serde_json::to_string(value) {
        Ok(json) => {
            println!("{json}");
        }

        Err(error) => {
            eprintln!(
                "Failed to serialize recorder response: {error}"
            );
        }
    }
}

// ============================================================
// PATHS
// ============================================================

fn recordings_dir() -> PathBuf {
    let home =
        env::var("HOME")
            .unwrap_or_else(|_| ".".to_string());

    PathBuf::from(home)
        .join("Videos")
        .join("Recordings")
}

fn runtime_dir() -> PathBuf {
    if let Ok(path) =
        env::var("XDG_RUNTIME_DIR")
    {
        return PathBuf::from(path)
            .join("nexa");
    }

    env::temp_dir()
        .join("nexa")
}

fn state_path() -> PathBuf {
    runtime_dir()
        .join("recorder.json")
}

fn log_path() -> PathBuf {
    runtime_dir()
        .join("recorder.log")
}

// ============================================================
// TIME
// ============================================================

fn now_seconds() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

fn timestamp() -> String {
    let now =
        now_seconds();

    let output =
        Command::new("date")
            .arg("-d")
            .arg(format!("@{now}"))
            .arg("+%Y-%m-%d_%H-%M-%S")
            .output();

    match output {
        Ok(output)
            if output.status.success() =>
        {
            String::from_utf8_lossy(
                &output.stdout
            )
            .trim()
            .to_string()
        }

        _ => {
            now.to_string()
        }
    }
}

// ============================================================
// ELAPSED
// ============================================================

fn elapsed_time(
    state: &RecorderState,
) -> u64 {
    let end =
        if state.paused {
            state.paused_at
                .unwrap_or_else(now_seconds)
        } else {
            now_seconds()
        };

    end
        .saturating_sub(
            state.started_at
        )
        .saturating_sub(
            state.total_paused
        )
}

// ============================================================
// STATE
// ============================================================

fn load_state() -> Option<RecorderState> {
    let content =
        fs::read_to_string(
            state_path()
        )
        .ok()?;

    serde_json::from_str(
        &content
    )
    .ok()
}

fn save_state(
    state: &RecorderState,
) -> Result<(), String> {
    fs::create_dir_all(
        runtime_dir()
    )
    .map_err(|error| {
        format!(
            "Failed to create recorder runtime directory: {error}"
        )
    })?;

    let json =
        serde_json::to_string(
            state
        )
        .map_err(|error| {
            format!(
                "Failed to serialize recorder state: {error}"
            )
        })?;

    fs::write(
        state_path(),
        json,
    )
    .map_err(|error| {
        format!(
            "Failed to save recorder state: {error}"
        )
    })
}

fn clear_state() {
    let _ =
        fs::remove_file(
            state_path()
        );
}

// ============================================================
// PROCESS
// ============================================================

fn process_alive(
    pid: u32,
) -> bool {
    Command::new("kill")
        .arg("-0")
        .arg(pid.to_string())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|status| {
            status.success()
        })
        .unwrap_or(false)
}

fn send_signal(
    signal: &str,
    pid: u32,
) -> Result<(), String> {
    let status =
        Command::new("kill")
            .arg(signal)
            .arg(pid.to_string())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .map_err(|error| {
                format!(
                    "Failed to send {signal}: {error}"
                )
            })?;

    if status.success() {
        Ok(())
    } else {
        Err(
            format!(
                "Signal {signal} failed with status: {status}"
            )
        )
    }
}

fn active_state() -> Option<RecorderState> {
    let state =
        load_state()?;

    if process_alive(
        state.pid
    ) {
        Some(state)
    } else {
        clear_state();
        None
    }
}

// ============================================================
// RESPONSE HELPERS
// ============================================================

fn state_response(
    action: &'static str,
    state: &RecorderState,
    message: String,
) {
    print_json(
        &RecorderResponse {
            success: true,
            action,

            recording: true,
            paused:
                state.paused,

            pid:
                Some(
                    state.pid
                ),

            path:
                Some(
                    state.path.clone()
                ),

            elapsed:
                elapsed_time(
                    state
                ),

            message,
        }
    );
}

// ============================================================
// START
// ============================================================

pub fn start() {
    if let Some(state) =
        active_state()
    {
        print_json(
            &RecorderResponse {
                success: false,
                action: "start",

                recording: true,
                paused:
                    state.paused,

                pid:
                    Some(
                        state.pid
                    ),

                path:
                    Some(
                        state.path.clone()
                    ),

                elapsed:
                    elapsed_time(
                        &state
                    ),

                message:
                    "Screen recording is already active"
                        .to_string(),
            }
        );

        return;
    }

    let directory =
        recordings_dir();

    if let Err(error) =
        fs::create_dir_all(
            &directory
        )
    {
        print_json(
            &RecorderResponse {
                success: false,
                action: "start",

                recording: false,
                paused: false,

                pid: None,
                path: None,

                elapsed: 0,

                message: format!(
                    "Failed to create recording directory: {error}"
                ),
            }
        );

        return;
    }

    if let Err(error) =
        fs::create_dir_all(
            runtime_dir()
        )
    {
        print_json(
            &RecorderResponse {
                success: false,
                action: "start",

                recording: false,
                paused: false,

                pid: None,
                path: None,

                elapsed: 0,

                message: format!(
                    "Failed to create recorder runtime directory: {error}"
                ),
            }
        );

        return;
    }

    let filename =
        format!(
            "Recording_{}.mp4",
            timestamp()
        );

    let path =
        directory.join(
            filename
        );

    let stdout =
        fs::File::create(
            log_path()
        );

    let stderr =
        fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(
                log_path()
            );

    let stdout =
        stdout
            .map(Stdio::from)
            .unwrap_or_else(
                |_| Stdio::null()
            );

    let stderr =
        stderr
            .map(Stdio::from)
            .unwrap_or_else(
                |_| Stdio::null()
            );

    let child =
        Command::new(
            "wf-recorder"
        )
        .arg("-f")
        .arg(&path)
        .stdin(
            Stdio::null()
        )
        .stdout(
            stdout
        )
        .stderr(
            stderr
        )
        .spawn();

    let child =
        match child {
            Ok(child) => child,

            Err(error) => {
                print_json(
                    &RecorderResponse {
                        success: false,
                        action: "start",

                        recording: false,
                        paused: false,

                        pid: None,
                        path: None,

                        elapsed: 0,

                        message: format!(
                            "Failed to start wf-recorder: {error}"
                        ),
                    }
                );

                return;
            }
        };

    let state =
        RecorderState {
            pid:
                child.id(),

            path:
                path
                    .to_string_lossy()
                    .to_string(),

            started_at:
                now_seconds(),

            paused:
                false,

            paused_at:
                None,

            total_paused:
                0,
        };

    if let Err(error) =
        save_state(
            &state
        )
    {
        let _ =
            send_signal(
                "-INT",
                state.pid
            );

        print_json(
            &RecorderResponse {
                success: false,
                action: "start",

                recording: false,
                paused: false,

                pid: None,
                path: None,

                elapsed: 0,

                message:
                    error,
            }
        );

        return;
    }

    state_response(
        "start",
        &state,
        "Screen recording started"
            .to_string(),
    );
}

// ============================================================
// PAUSE
// ============================================================

pub fn pause() {
    let Some(mut state) =
        active_state()
    else {
        print_json(
            &RecorderResponse {
                success: false,
                action: "pause",

                recording: false,
                paused: false,

                pid: None,
                path: None,

                elapsed: 0,

                message:
                    "No active screen recording"
                        .to_string(),
            }
        );

        return;
    };

    if state.paused {
        print_json(
            &RecorderResponse {
                success: false,
                action: "pause",

                recording: true,
                paused: true,

                pid:
                    Some(
                        state.pid
                    ),

                path:
                    Some(
                        state.path.clone()
                    ),

                elapsed:
                    elapsed_time(
                        &state
                    ),

                message:
                    "Screen recording is already paused"
                        .to_string(),
            }
        );

        return;
    }

    if let Err(error) =
        send_signal(
            "-STOP",
            state.pid
        )
    {
        print_json(
            &RecorderResponse {
                success: false,
                action: "pause",

                recording: true,
                paused: false,

                pid:
                    Some(
                        state.pid
                    ),

                path:
                    Some(
                        state.path.clone()
                    ),

                elapsed:
                    elapsed_time(
                        &state
                    ),

                message:
                    error,
            }
        );

        return;
    }

    state.paused =
        true;

    state.paused_at =
        Some(
            now_seconds()
        );

    if let Err(error) =
        save_state(
            &state
        )
    {
        let _ =
            send_signal(
                "-CONT",
                state.pid
            );

        print_json(
            &RecorderResponse {
                success: false,
                action: "pause",

                recording: true,
                paused: false,

                pid:
                    Some(
                        state.pid
                    ),

                path:
                    Some(
                        state.path.clone()
                    ),

                elapsed:
                    elapsed_time(
                        &state
                    ),

                message:
                    error,
            }
        );

        return;
    }

    state_response(
        "pause",
        &state,
        "Screen recording paused"
            .to_string(),
    );
}

// ============================================================
// RESUME
// ============================================================

pub fn resume() {
    let Some(mut state) =
        active_state()
    else {
        print_json(
            &RecorderResponse {
                success: false,
                action: "resume",

                recording: false,
                paused: false,

                pid: None,
                path: None,

                elapsed: 0,

                message:
                    "No active screen recording"
                        .to_string(),
            }
        );

        return;
    };

    if !state.paused {
        print_json(
            &RecorderResponse {
                success: false,
                action: "resume",

                recording: true,
                paused: false,

                pid:
                    Some(
                        state.pid
                    ),

                path:
                    Some(
                        state.path.clone()
                    ),

                elapsed:
                    elapsed_time(
                        &state
                    ),

                message:
                    "Screen recording is already running"
                        .to_string(),
            }
        );

        return;
    }

    let now =
        now_seconds();

    if let Some(paused_at) =
        state.paused_at
    {
        state.total_paused =
            state.total_paused
                .saturating_add(
                    now.saturating_sub(
                        paused_at
                    )
                );
    }

    if let Err(error) =
        send_signal(
            "-CONT",
            state.pid
        )
    {
        print_json(
            &RecorderResponse {
                success: false,
                action: "resume",

                recording: true,
                paused: true,

                pid:
                    Some(
                        state.pid
                    ),

                path:
                    Some(
                        state.path.clone()
                    ),

                elapsed:
                    elapsed_time(
                        &state
                    ),

                message:
                    error,
            }
        );

        return;
    }

    state.paused =
        false;

    state.paused_at =
        None;

    if let Err(error) =
        save_state(
            &state
        )
    {
        print_json(
            &RecorderResponse {
                success: false,
                action: "resume",

                recording: true,
                paused: false,

                pid:
                    Some(
                        state.pid
                    ),

                path:
                    Some(
                        state.path.clone()
                    ),

                elapsed:
                    elapsed_time(
                        &state
                    ),

                message:
                    error,
            }
        );

        return;
    }

    state_response(
        "resume",
        &state,
        "Screen recording resumed"
            .to_string(),
    );
}

// ============================================================
// STOP
// ============================================================

pub fn stop() {
    let Some(state) =
        active_state()
    else {
        print_json(
            &RecorderResponse {
                success: false,
                action: "stop",

                recording: false,
                paused: false,

                pid: None,
                path: None,

                elapsed: 0,

                message:
                    "No active screen recording"
                        .to_string(),
            }
        );

        return;
    };

    let elapsed =
        elapsed_time(
            &state
        );

    // A stopped process must be continued before SIGINT can
    // finalize wf-recorder cleanly.
    if state.paused {
        let _ =
            send_signal(
                "-CONT",
                state.pid
            );

        thread::sleep(
            Duration::from_millis(
                80
            )
        );
    }

    match send_signal(
        "-INT",
        state.pid
    ) {
        Ok(()) => {
            for _ in 0..30 {
                if !process_alive(
                    state.pid
                ) {
                    break;
                }

                thread::sleep(
                    Duration::from_millis(
                        100
                    )
                );
            }

            clear_state();

            print_json(
                &RecorderResponse {
                    success: true,
                    action: "stop",

                    recording: false,
                    paused: false,

                    pid: None,

                    path:
                        Some(
                            state.path.clone()
                        ),

                    elapsed,

                    message:
                        "Screen recording stopped"
                            .to_string(),
                }
            );
        }

        Err(error) => {
            print_json(
                &RecorderResponse {
                    success: false,
                    action: "stop",

                    recording: true,
                    paused:
                        state.paused,

                    pid:
                        Some(
                            state.pid
                        ),

                    path:
                        Some(
                            state.path.clone()
                        ),

                    elapsed,

                    message:
                        error,
                }
            );
        }
    }
}

// ============================================================
// STATUS
// ============================================================

pub fn status() {
    match active_state() {
        Some(state) => {
            state_response(
                "status",
                &state,

                if state.paused {
                    "Screen recording is paused"
                } else {
                    "Screen recording is active"
                }
                .to_string(),
            );
        }

        None => {
            print_json(
                &RecorderResponse {
                    success: true,
                    action: "status",

                    recording: false,
                    paused: false,

                    pid: None,
                    path: None,

                    elapsed: 0,

                    message:
                        "Screen recorder is idle"
                            .to_string(),
                }
            );
        }
    }
}

// ============================================================
// TOGGLE
// ============================================================

pub fn toggle() {
    if active_state().is_some() {
        stop();
    } else {
        start();
    }
}
