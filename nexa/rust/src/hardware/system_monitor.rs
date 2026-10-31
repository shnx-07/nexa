use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use std::ffi::CString;
use std::fs;
use std::mem::MaybeUninit;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const MAX_HISTORY_POINTS: usize = 60;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessInfo {
    pub pid: u32,
    pub name: String,
    pub cpu_pct: f32,
    pub mem_pct: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemSnapshot {
    pub timestamp: u64,
    pub cpu_pct: f32,
    pub cpu_temp: f32,
    pub cpu_freq_mhz: u32,
    pub ram_used_mb: u64,
    pub ram_total_mb: u64,
    pub ram_pct: f32,
    pub swap_used_mb: u64,
    pub swap_total_mb: u64,
    pub swap_pct: f32,
    pub disk_used_gb: f32,
    pub disk_total_gb: f32,
    pub disk_pct: f32,
    pub net_rx_kbps: f32,
    pub net_tx_kbps: f32,
    pub top_processes: Vec<ProcessInfo>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemHistory {
    pub current: SystemSnapshot,
    pub cpu_history: Vec<f32>,
    pub ram_history: Vec<f32>,
    pub net_rx_history: Vec<f32>,
    pub net_tx_history: Vec<f32>,
}

pub struct SystemSampler {
    prev_cpu_idle: u64,
    prev_cpu_total: u64,
    prev_net_rx: u64,
    prev_net_tx: u64,
    prev_sample_time: Instant,
    history: VecDeque<SystemSnapshot>,
}

impl SystemSampler {
    pub fn new() -> Self {
        let (idle, total) = read_cpu_jiffies().unwrap_or((0, 0));
        let (rx, tx) = read_net_bytes().unwrap_or((0, 0));
        Self {
            prev_cpu_idle: idle,
            prev_cpu_total: total,
            prev_net_rx: rx,
            prev_net_tx: tx,
            prev_sample_time: Instant::now(),
            history: VecDeque::with_capacity(MAX_HISTORY_POINTS),
        }
    }

    pub fn sample(&mut self) -> SystemSnapshot {
        let now = Instant::now();
        let elapsed_secs = now.duration_since(self.prev_sample_time).as_secs_f32().max(0.1);
        self.prev_sample_time = now;

        // 1. CPU Utilization Delta
        let (idle, total) = read_cpu_jiffies().unwrap_or((self.prev_cpu_idle, self.prev_cpu_total));
        let d_idle = idle.saturating_sub(self.prev_cpu_idle);
        let d_total = total.saturating_sub(self.prev_cpu_total);
        self.prev_cpu_idle = idle;
        self.prev_cpu_total = total;

        let cpu_pct = if d_total > 0 {
            let used = d_total.saturating_sub(d_idle);
            ((used as f32 / d_total as f32) * 100.0).clamp(0.0, 100.0)
        } else {
            0.0
        };

        // 2. CPU Temperature & Frequency
        let cpu_temp = read_cpu_temp();
        let cpu_freq_mhz = read_cpu_freq_mhz();

        // 3. Memory & Swap
        let (ram_total_mb, ram_avail_mb, swap_total_mb, swap_free_mb) = read_mem_stats().unwrap_or((0, 0, 0, 0));
        let ram_used_mb = ram_total_mb.saturating_sub(ram_avail_mb);
        let ram_pct = if ram_total_mb > 0 {
            ((ram_used_mb as f32 / ram_total_mb as f32) * 100.0).clamp(0.0, 100.0)
        } else {
            0.0
        };

        let swap_used_mb = swap_total_mb.saturating_sub(swap_free_mb);
        let swap_pct = if swap_total_mb > 0 {
            ((swap_used_mb as f32 / swap_total_mb as f32) * 100.0).clamp(0.0, 100.0)
        } else {
            0.0
        };

        // 4. Disk Usage (Root filesystem)
        let (disk_used_gb, disk_total_gb, disk_pct) = read_disk_stats().unwrap_or((0.0, 0.0, 0.0));

        // 5. Network Delta
        let (rx, tx) = read_net_bytes().unwrap_or((self.prev_net_rx, self.prev_net_tx));
        let d_rx = rx.saturating_sub(self.prev_net_rx);
        let d_tx = tx.saturating_sub(self.prev_net_tx);
        self.prev_net_rx = rx;
        self.prev_net_tx = tx;

        let net_rx_kbps = ((d_rx as f32 / 1024.0) / elapsed_secs).max(0.0);
        let net_tx_kbps = ((d_tx as f32 / 1024.0) / elapsed_secs).max(0.0);

        // 6. Top Processes (Sampled quickly via ps)
        let top_processes = read_top_processes();

        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        let snapshot = SystemSnapshot {
            timestamp,
            cpu_pct: (cpu_pct * 10.0).round() / 10.0,
            cpu_temp: (cpu_temp * 10.0).round() / 10.0,
            cpu_freq_mhz,
            ram_used_mb,
            ram_total_mb,
            ram_pct: (ram_pct * 10.0).round() / 10.0,
            swap_used_mb,
            swap_total_mb,
            swap_pct: (swap_pct * 10.0).round() / 10.0,
            disk_used_gb,
            disk_total_gb,
            disk_pct,
            net_rx_kbps: (net_rx_kbps * 10.0).round() / 10.0,
            net_tx_kbps: (net_tx_kbps * 10.0).round() / 10.0,
            top_processes,
        };

        // Maintain ring buffer
        if self.history.len() >= MAX_HISTORY_POINTS {
            self.history.pop_front();
        }
        self.history.push_back(snapshot.clone());

        snapshot
    }

    pub fn get_history(&self, current: SystemSnapshot) -> SystemHistory {
        let mut cpu_history = Vec::with_capacity(self.history.len());
        let mut ram_history = Vec::with_capacity(self.history.len());
        let mut net_rx_history = Vec::with_capacity(self.history.len());
        let mut net_tx_history = Vec::with_capacity(self.history.len());

        for snap in &self.history {
            cpu_history.push(snap.cpu_pct);
            ram_history.push(snap.ram_pct);
            net_rx_history.push(snap.net_rx_kbps);
            net_tx_history.push(snap.net_tx_kbps);
        }

        SystemHistory {
            current,
            cpu_history,
            ram_history,
            net_rx_history,
            net_tx_history,
        }
    }
}

// ------------------------------------------------------------
// Low-Level Linux Virtual FS Parsers (Direct, zero shell overhead)
// ------------------------------------------------------------

fn read_cpu_jiffies() -> Option<(u64, u64)> {
    let stat = fs::read_to_string("/proc/stat").ok()?;
    let line = stat.lines().next()?;
    if !line.starts_with("cpu ") {
        return None;
    }
    let parts: Vec<u64> = line
        .split_whitespace()
        .skip(1)
        .filter_map(|p| p.parse::<u64>().ok())
        .collect();

    if parts.len() < 5 {
        return None;
    }

    let user = parts[0];
    let nice = parts[1];
    let system = parts[2];
    let idle = parts[3];
    let iowait = parts.get(4).copied().unwrap_or(0);
    let irq = parts.get(5).copied().unwrap_or(0);
    let softirq = parts.get(6).copied().unwrap_or(0);
    let steal = parts.get(7).copied().unwrap_or(0);

    let total_idle = idle + iowait;
    let total_busy = user + nice + system + irq + softirq + steal;
    let total = total_idle + total_busy;

    Some((total_idle, total))
}

fn read_mem_stats() -> Option<(u64, u64, u64, u64)> {
    let meminfo = fs::read_to_string("/proc/meminfo").ok()?;
    let mut total_kb = 0;
    let mut avail_kb = 0;
    let mut swap_total_kb = 0;
    let mut swap_free_kb = 0;

    for line in meminfo.lines() {
        if line.starts_with("MemTotal:") {
            total_kb = parse_meminfo_val(line);
        } else if line.starts_with("MemAvailable:") {
            avail_kb = parse_meminfo_val(line);
        } else if line.starts_with("SwapTotal:") {
            swap_total_kb = parse_meminfo_val(line);
        } else if line.starts_with("SwapFree:") {
            swap_free_kb = parse_meminfo_val(line);
        }
    }

    Some((
        total_kb / 1024,
        avail_kb / 1024,
        swap_total_kb / 1024,
        swap_free_kb / 1024,
    ))
}

fn parse_meminfo_val(line: &str) -> u64 {
    line.split_whitespace()
        .nth(1)
        .and_then(|v| v.parse::<u64>().ok())
        .unwrap_or(0)
}

fn read_cpu_temp() -> f32 {
    let hwmon_dir = Path::new("/sys/class/hwmon");
    if let Ok(entries) = fs::read_dir(hwmon_dir) {
        let mut fallback = None;
        for entry in entries.flatten() {
            let path = entry.path();
            let name = fs::read_to_string(path.join("name"))
                .unwrap_or_default()
                .trim()
                .to_lowercase();

            if name.contains("k10temp") || name.contains("coretemp") || name.contains("cpu") {
                if let Ok(val) = fs::read_to_string(path.join("temp1_input")) {
                    if let Ok(mdeg) = val.trim().parse::<f32>() {
                        return mdeg / 1000.0;
                    }
                }
            }

            if fallback.is_none() {
                if let Ok(val) = fs::read_to_string(path.join("temp1_input")) {
                    if let Ok(mdeg) = val.trim().parse::<f32>() {
                        fallback = Some(mdeg / 1000.0);
                    }
                }
            }
        }

        if let Some(fb) = fallback {
            return fb;
        }
    }
    0.0
}

fn read_cpu_freq_mhz() -> u32 {
    let path = Path::new("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq");
    if let Ok(val) = fs::read_to_string(path) {
        if let Ok(khz) = val.trim().parse::<u32>() {
            return khz / 1000;
        }
    }
    0
}

fn read_net_bytes() -> Option<(u64, u64)> {
    let netdev = fs::read_to_string("/proc/net/dev").ok()?;
    let mut total_rx = 0;
    let mut total_tx = 0;

    for line in netdev.lines().skip(2) {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.is_empty() {
            continue;
        }
        let iface = parts[0].trim_end_matches(':');
        if iface == "lo" {
            continue;
        }

        if parts.len() >= 10 {
            let rx = parts[1].parse::<u64>().unwrap_or(0);
            let tx = parts[9].parse::<u64>().unwrap_or(0);
            total_rx += rx;
            total_tx += tx;
        }
    }

    Some((total_rx, total_tx))
}

fn read_disk_stats() -> Option<(f32, f32, f32)> {
    let path = CString::new("/").ok()?;
    let mut stat = MaybeUninit::<libc::statvfs>::uninit();

    let res = unsafe { libc::statvfs(path.as_ptr(), stat.as_mut_ptr()) };
    if res == 0 {
        let stat = unsafe { stat.assume_init() };
        let frsize = stat.f_frsize as f64;
        let total_bytes = (stat.f_blocks as f64) * frsize;
        let free_bytes = (stat.f_bavail as f64) * frsize;
        let used_bytes = (total_bytes - free_bytes).max(0.0);

        let total_gb = (total_bytes / (1024.0 * 1024.0 * 1024.0)) as f32;
        let used_gb = (used_bytes / (1024.0 * 1024.0 * 1024.0)) as f32;
        let pct = if total_gb > 0.0 {
            ((used_gb / total_gb) * 100.0).clamp(0.0, 100.0)
        } else {
            0.0
        };

        Some((
            (used_gb * 10.0).round() / 10.0,
            (total_gb * 10.0).round() / 10.0,
            (pct * 10.0).round() / 10.0,
        ))
    } else {
        None
    }
}

fn read_top_processes() -> Vec<ProcessInfo> {
    let output = Command::new("ps")
        .args(["-eo", "pid,pcpu,pmem,comm", "--sort=-pcpu"])
        .output();

    let mut result = Vec::with_capacity(5);
    if let Ok(out) = output {
        let text = String::from_utf8_lossy(&out.stdout);
        for line in text.lines().skip(1).take(5) {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 4 {
                let pid = parts[0].parse::<u32>().unwrap_or(0);
                let cpu_pct = parts[1].parse::<f32>().unwrap_or(0.0);
                let mem_pct = parts[2].parse::<f32>().unwrap_or(0.0);
                let name = parts[3..].join(" ");
                result.push(ProcessInfo {
                    pid,
                    name,
                    cpu_pct,
                    mem_pct,
                });
            }
        }
    }
    result
}

// ------------------------------------------------------------
// Persistence & Background Watcher
// ------------------------------------------------------------

fn history_file_path() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/shnx".to_string());
    PathBuf::from(home).join(".cache/nexa/system-history.json")
}

pub fn save_history_atomically(history: &SystemHistory) -> Result<(), String> {
    let path = history_file_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let tmp_path = path.with_extension("tmp");
    let json = serde_json::to_string(history).map_err(|e| e.to_string())?;

    fs::write(&tmp_path, json).map_err(|e| format!("Failed to write tmp: {e}"))?;
    fs::rename(&tmp_path, &path).map_err(|e| format!("Failed to rename history: {e}"))?;

    Ok(())
}

pub fn get_cached_history() -> Result<SystemHistory, String> {
    let path = history_file_path();
    if path.exists() {
        if let Ok(content) = fs::read_to_string(&path) {
            if let Ok(history) = serde_json::from_str::<SystemHistory>(&content) {
                return Ok(history);
            }
        }
    }

    // Fallback: perform an immediate single sample
    let mut sampler = SystemSampler::new();
    thread::sleep(Duration::from_millis(200));
    let snap = sampler.sample();
    Ok(sampler.get_history(snap))
}

pub fn run_watch() -> Result<(), String> {
    println!("[NEXA System Monitor] Starting background hardware sampler...");
    let mut sampler = SystemSampler::new();

    loop {
        thread::sleep(Duration::from_millis(1000));
        let snap = sampler.sample();
        let history = sampler.get_history(snap);
        if let Err(e) = save_history_atomically(&history) {
            eprintln!("[NEXA System Monitor] Save error: {e}");
        }
    }
}
