use serde::Serialize;
use std::env;
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::thread;
use std::time::Duration;

#[derive(Debug, Clone, Serialize)]
pub struct VisualizerFrame {
    pub energy: f32,
    pub bass: f32,
    pub mid: f32,
    pub treble: f32,
    pub is_beat: bool,
    pub amp: f32,
    pub speed: f32,
    pub wave_profile: Vec<f32>,
    pub bars: Vec<f32>,
}

impl Default for VisualizerFrame {
    fn default() -> Self {
        Self {
            energy: 0.0,
            bass: 0.0,
            mid: 0.0,
            treble: 0.0,
            is_beat: false,
            amp: 0.0,
            speed: 1.0,
            wave_profile: vec![0.0; 12],
            bars: vec![0.0; 24],
        }
    }
}

pub fn config_path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| ".".to_string());
    PathBuf::from(home)
        .join(".config")
        .join("nexa")
        .join("config")
        .join("cava.conf")
}

pub fn handle_cli(args: &[String]) {
    let mode = args.first().map(|s| s.as_str()).unwrap_or("stream");
    match mode {
        "stream" => run_stream(),
        "get" | "snapshot" => {
            let frame = VisualizerFrame::default();
            if let Ok(json) = serde_json::to_string(&frame) {
                println!("{json}");
            }
        }
        _ => {
            eprintln!("Usage: nexad visualizer [stream|get]");
        }
    }
}

fn spawn_cava(conf: &PathBuf) -> Option<Child> {
    Command::new("cava")
        .arg("-p")
        .arg(conf)
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()
}

pub fn run_stream() {
    let conf = config_path();
    let stdout = std::io::stdout();
    let mut out = stdout.lock();

    let mut bass_ema: f32 = 0.0;
    let mut wave_amp: f32 = 0.0;
    let mut silent_frames: u32 = 0;

    // Single persistent child instance
    let mut child = match spawn_cava(&conf) {
        Some(c) => c,
        None => {
            let default_frame = VisualizerFrame::default();
            if let Ok(json) = serde_json::to_string(&default_frame) {
                let _ = writeln!(out, "{json}");
                let _ = out.flush();
            }
            return;
        }
    };

    let stdout_handle = match child.stdout.take() {
        Some(h) => h,
        None => {
            let _ = child.kill();
            let _ = child.wait();
            return;
        }
    };

    let reader = BufReader::new(stdout_handle);

    for line_res in reader.lines() {
        let line = match line_res {
            Ok(l) => l,
            Err(_) => break,
        };

        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        // Parse raw values with 3.2x Gain for normal volume listening
        let mut raw_bins = Vec::with_capacity(40);
        let mut total_raw: f32 = 0.0;

        for part in trimmed.split(';') {
            if part.is_empty() {
                continue;
            }
            if let Ok(val) = part.parse::<u16>() {
                // Apply 3.2x acoustic boost so casual listening registers vibrantly
                let normalized = ((val as f32 / 1000.0) * 3.2).clamp(0.0, 1.0);
                raw_bins.push(normalized);
                total_raw += normalized;
            }
        }

        if raw_bins.is_empty() {
            continue;
        }

        // Check if truly silent (less than 0.005 total energy)
        if total_raw < 0.02 {
            silent_frames += 1;
            if silent_frames > 20 {
                // Decay wave smoothly to 0
                wave_amp *= 0.85;
                if wave_amp < 0.05 {
                    wave_amp = 0.0;
                }
                // When silent, emit a clean idle frame every 15 frames and sleep 40ms to keep CPU at near-0%
                if silent_frames % 15 == 0 {
                    let idle = VisualizerFrame {
                        energy: 0.0,
                        bass: 0.0,
                        mid: 0.0,
                        treble: 0.0,
                        is_beat: false,
                        amp: (wave_amp * 100.0).round() / 100.0,
                        speed: 1.0,
                        wave_profile: vec![0.0; 12],
                        bars: vec![0.0; 24],
                    };
                    if let Ok(json) = serde_json::to_string(&idle) {
                        let _ = writeln!(out, "{json}");
                        let _ = out.flush();
                    }
                }
                thread::sleep(Duration::from_millis(30));
                continue;
            }
        } else {
            silent_frames = 0;
        }

        // Frequency band split:
        // Sub-bass & Bass (first 25% of bins)
        let bass_count = (raw_bins.len() / 4).max(1);
        let bass_sum: f32 = raw_bins[0..bass_count].iter().sum();
        let bass = (bass_sum / bass_count as f32).clamp(0.0, 1.0);

        // Mids & Vocals (next 40% of bins)
        let mid_end = (bass_count + (raw_bins.len() * 4 / 10)).min(raw_bins.len());
        let mid_count = mid_end - bass_count;
        let mid_sum: f32 = if mid_count > 0 { raw_bins[bass_count..mid_end].iter().sum() } else { 0.0 };
        let mid = if mid_count > 0 { (mid_sum / mid_count as f32).clamp(0.0, 1.0) } else { 0.0 };

        // Treble & Highs (remaining bins)
        let treble_count = raw_bins.len() - mid_end;
        let treble_sum: f32 = if treble_count > 0 { raw_bins[mid_end..].iter().sum() } else { 0.0 };
        let treble = if treble_count > 0 { (treble_sum / treble_count as f32).clamp(0.0, 1.0) } else { 0.0 };

        // Weighted acoustic energy
        let energy = (bass * 0.55 + mid * 0.30 + treble * 0.15).clamp(0.0, 1.0);

        // Beat transient detector
        bass_ema = bass_ema * 0.80 + bass * 0.20;
        let is_beat = bass > (bass_ema * 1.25) && bass > 0.18;

        // Wave dynamic amplitude (smooth scaling between 3.0 and 8.5 pixels)
        let target_amp = if energy > 0.03 {
            (3.0 + energy * 5.5).clamp(3.0, 8.5)
        } else {
            0.0
        };

        if target_amp > wave_amp {
            wave_amp = wave_amp * 0.35 + target_amp * 0.65;
        } else {
            wave_amp = wave_amp * 0.88 + target_amp * 0.12;
        }

        // Dynamic bead drift speed multiplier
        let speed = 1.0 + (energy * 0.70).clamp(0.0, 0.70);

        // Resample down to 24 smooth bars for Music Drawer & visualizers
        let target_bars_count = 24;
        let mut bars = Vec::with_capacity(target_bars_count);
        let step = raw_bins.len() as f32 / target_bars_count as f32;
        for i in 0..target_bars_count {
            let idx = ((i as f32 * step) as usize).min(raw_bins.len().saturating_sub(1));
            let val = (raw_bins[idx] * 100.0).round() / 100.0;
            bars.push(val);
        }

        // 12 dynamic wave profile nodes
        let mut wave_profile = Vec::with_capacity(12);
        for i in 0..12 {
            let sample_idx = (i * 2).min(raw_bins.len().saturating_sub(1));
            let h = ((raw_bins[sample_idx] * 0.8 + 0.1) * 100.0).round() / 100.0;
            wave_profile.push(h);
        }

        let frame = VisualizerFrame {
            energy: (energy * 100.0).round() / 100.0,
            bass: (bass * 100.0).round() / 100.0,
            mid: (mid * 100.0).round() / 100.0,
            treble: (treble * 100.0).round() / 100.0,
            is_beat,
            amp: (wave_amp * 100.0).round() / 100.0,
            speed: (speed * 100.0).round() / 100.0,
            wave_profile,
            bars,
        };

        if let Ok(json) = serde_json::to_string(&frame) {
            if writeln!(out, "{json}").is_err() || out.flush().is_err() {
                break;
            }
        }
    }

    // Clean exit: kill and reap child to prevent zombies
    let _ = child.kill();
    let _ = child.wait();
}
