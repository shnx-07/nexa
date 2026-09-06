use std::{
    env,
    fs,
    path::PathBuf,
    process::{Command, Stdio},
};

const MIN_TEMP: u32 = 2500;
const MAX_TEMP: u32 = 6500;
const DEFAULT_TEMP: u32 = 6500;
const DEFAULT_MANUAL_TEMP: u32 = 4500;
const DEFAULT_WALLPAPER_TEMP: u32 = 5000;
const DEFAULT_NIGHT_TEMP: u32 = 3500;

const WALLPAPER_MIN_TEMP: u32 = 3800;
const WALLPAPER_MAX_TEMP: u32 = 6000;
const WALLPAPER_NEUTRAL_TEMP: u32 = 5000;

#[derive(Debug, Clone)]
pub struct ScreenTempState {
    pub enabled: bool,
    pub mode: String,

    pub temperature: u32,

    pub manual_temperature: u32,
    pub wallpaper_temperature: u32,
    pub night_temperature: u32,

    pub schedule_mode: String,
    pub schedule_start: String,
    pub schedule_end: String,
    pub schedule_target: String,
}

impl Default for ScreenTempState {
    fn default() -> Self {
        Self {
            enabled: false,
            mode: "manual".to_string(),

            temperature: DEFAULT_TEMP,

            manual_temperature: DEFAULT_MANUAL_TEMP,
            wallpaper_temperature: DEFAULT_WALLPAPER_TEMP,
            night_temperature: DEFAULT_NIGHT_TEMP,

            schedule_mode: "off".to_string(),
            schedule_start: "22:00".to_string(),
            schedule_end: "06:00".to_string(),
            schedule_target: "none".to_string(),
        }
    }
}

fn config_path() -> PathBuf {
    let home = env::var("HOME")
        .unwrap_or_else(|_| ".".to_string());

    PathBuf::from(home)
        .join(".config")
        .join("nexa")
        .join("config")
        .join("screen-temp.conf")
}

fn clamp_temperature(value: u32) -> u32 {
    value.clamp(MIN_TEMP, MAX_TEMP)
}

fn command_exists(name: &str) -> bool {
    Command::new("sh")
        .arg("-c")
        .arg(format!("command -v {name} >/dev/null 2>&1"))
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

fn ensure_hyprsunset_running() -> Result<(), String> {
    if !command_exists("hyprsunset") {
        return Err(
            "hyprsunset is not installed".to_string()
        );
    }

    let running = Command::new("pgrep")
        .args(["-x", "hyprsunset"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|status| status.success())
        .unwrap_or(false);

    if running {
        return Ok(());
    }

    Command::new("hyprsunset")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|error| {
            format!("failed to start hyprsunset: {error}")
        })?;

    std::thread::sleep(
        std::time::Duration::from_millis(200)
    );

    Ok(())
}

fn apply_temperature(temperature: u32) -> Result<(), String> {
    ensure_hyprsunset_running()?;

    let temperature = clamp_temperature(temperature);

    let output = Command::new("hyprctl")
        .args([
            "hyprsunset",
            "temperature",
            &temperature.to_string(),
        ])
        .output()
        .map_err(|error| {
            format!(
                "failed to execute hyprctl hyprsunset: {error}"
            )
        })?;

    if !output.status.success() {
        return Err(
            String::from_utf8_lossy(&output.stderr)
                .trim()
                .to_string()
        );
    }

    Ok(())
}

fn reset_temperature() -> Result<(), String> {
    if !command_exists("hyprsunset") {
        return Ok(());
    }

    let output = Command::new("hyprctl")
        .args([
            "hyprsunset",
            "identity",
        ])
        .output()
        .map_err(|error| {
            format!(
                "failed to reset screen temperature: {error}"
            )
        })?;

    if !output.status.success() {
        return Err(
            String::from_utf8_lossy(&output.stderr)
                .trim()
                .to_string()
        );
    }

    Ok(())
}

pub(crate) fn load_state() -> ScreenTempState {
    let path = config_path();

    let Ok(content) = fs::read_to_string(path) else {
        return ScreenTempState::default();
    };

    let mut state = ScreenTempState::default();

    for line in content.lines() {
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };

        let key = key.trim();
        let value = value.trim();

        match key {
            "enabled" => {
                state.enabled = value == "true";
            }

            "mode" => {
                if matches!(
                    value,
                    "manual" | "wallpaper" | "night"
                ) {
                    state.mode = value.to_string();
                }
            }

            "manual_temperature" => {
                if let Ok(value) = value.parse::<u32>() {
                    state.manual_temperature =
                        clamp_temperature(value);
                }
            }

            "wallpaper_temperature" => {
                if let Ok(value) = value.parse::<u32>() {
                    state.wallpaper_temperature =
                        clamp_temperature(value);
                }
            }

            "night_temperature" => {
                if let Ok(value) = value.parse::<u32>() {
                    state.night_temperature =
                        clamp_temperature(value);
                }
            }

            "schedule_mode" => {
                if matches!(value, "off" | "sunset" | "custom") {
                    state.schedule_mode = value.to_string();
                }
            }

            "schedule_start" => {
                if !value.is_empty() {
                    state.schedule_start = value.to_string();
                }
            }

            "schedule_end" => {
                if !value.is_empty() {
                    state.schedule_end = value.to_string();
                }
            }

            "schedule_target" => {
                if matches!(value, "on" | "off" | "none") {
                    state.schedule_target = value.to_string();
                }
            }

            _ => {}
        }
    }

    if state.enabled {
        state.temperature =
            active_temperature(&state);
    } else {
        state.temperature =
            DEFAULT_TEMP;
    }

    state
}

pub(crate) fn save_state(state: &ScreenTempState) -> Result<(), String> {
    let path = config_path();

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| {
                format!(
                    "failed to create screen temp config directory: {error}"
                )
            })?;
    }

    let content = format!(
        concat!(
            "enabled={}\n",
            "mode={}\n",
            "manual_temperature={}\n",
            "wallpaper_temperature={}\n",
            "night_temperature={}\n",
            "schedule_mode={}\n",
            "schedule_start={}\n",
            "schedule_end={}\n",
            "schedule_target={}\n"
        ),
        state.enabled,
        state.mode,
        state.manual_temperature,
        state.wallpaper_temperature,
        state.night_temperature,
        state.schedule_mode,
        state.schedule_start,
        state.schedule_end,
        state.schedule_target,
    );

    fs::write(path, content)
        .map_err(|error| {
            format!(
                "failed to save screen temp state: {error}"
            )
        })
}

fn active_temperature(state: &ScreenTempState) -> u32 {
    match state.mode.as_str() {
        "wallpaper" => state.wallpaper_temperature,
        "night" => state.night_temperature,
        _ => state.manual_temperature,
    }
}

fn apply_state(state: &mut ScreenTempState) -> Result<(), String> {
    if !state.enabled {
        reset_temperature()?;
        state.temperature = DEFAULT_TEMP;
        return Ok(());
    }

    let temperature = active_temperature(state);

    apply_temperature(temperature)?;

    state.temperature = temperature;

    Ok(())
}

fn get_sun_times() -> (String, String) {
    let home = env::var("HOME").unwrap_or_else(|_| ".".to_string());
    let path = PathBuf::from(home)
        .join(".cache")
        .join("nexa")
        .join("weather")
        .join("weather.json");

    if let Ok(content) = fs::read_to_string(path) {
        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&content) {
            let sunrise = json
                .get("daily")
                .and_then(|d| d.get(0))
                .and_then(|d0| d0.get("sunrise"))
                .and_then(|s| s.as_str())
                .unwrap_or("06:00")
                .to_string();

            let sunset = json
                .get("daily")
                .and_then(|d| d.get(0))
                .and_then(|d0| d0.get("sunset"))
                .and_then(|s| s.as_str())
                .unwrap_or("18:30")
                .to_string();

            return (sunrise, sunset);
        }
    }

    ("06:00".to_string(), "18:30".to_string())
}

fn print_json(state: &ScreenTempState) {
    let (sunrise, sunset) = get_sun_times();
    println!(
        concat!(
            "{{",
            "\"enabled\":{},",
            "\"mode\":\"{}\",",
            "\"temperature\":{},",
            "\"manualTemperature\":{},",
            "\"wallpaperTemperature\":{},",
            "\"nightTemperature\":{},",
            "\"minTemperature\":{},",
            "\"maxTemperature\":{},",
            "\"scheduleMode\":\"{}\",",
            "\"scheduleStart\":\"{}\",",
            "\"scheduleEnd\":\"{}\",",
            "\"scheduleTarget\":\"{}\",",
            "\"sunrise\":\"{}\",",
            "\"sunset\":\"{}\"",
            "}}"
        ),
        state.enabled,
        state.mode,
        state.temperature,
        state.manual_temperature,
        state.wallpaper_temperature,
        state.night_temperature,
        MIN_TEMP,
        MAX_TEMP,
        state.schedule_mode,
        state.schedule_start,
        state.schedule_end,
        state.schedule_target,
        sunrise,
        sunset,
    );
}

pub fn get_current_time_hm() -> (u32, u32) {
    #[repr(C)]
    struct Tm {
        tm_sec: i32,
        tm_min: i32,
        tm_hour: i32,
        tm_mday: i32,
        tm_mon: i32,
        tm_year: i32,
        tm_wday: i32,
        tm_yday: i32,
        tm_isdst: i32,
        tm_gmtoff: i64,
        tm_zone: *const std::os::raw::c_char,
    }
    unsafe extern "C" {
        fn time(t: *mut i64) -> i64;
        fn localtime_r(timep: *const i64, result: *mut Tm) -> *mut Tm;
    }
    unsafe {
        let mut t: i64 = 0;
        time(&mut t);
        let mut tm: Tm = std::mem::zeroed();
        localtime_r(&t, &mut tm);
        (tm.tm_hour.max(0) as u32, tm.tm_min.max(0) as u32)
    }
}

fn parse_time_hm(time_str: &str) -> (u32, u32) {
    if let Some((h, m)) = time_str.split_once(':') {
        let h = h.trim().parse::<u32>().unwrap_or(0);
        let m = m.trim().parse::<u32>().unwrap_or(0);
        (h.min(23), m.min(59))
    } else {
        (0, 0)
    }
}

pub fn is_in_schedule_window(state: &ScreenTempState) -> bool {
    let (now_h, now_m) = get_current_time_hm();
    let current_mins = now_h * 60 + now_m;

    match state.schedule_mode.as_str() {
        "sunset" => {
            let (sunrise_str, sunset_str) = get_sun_times();
            let (sun_h, sun_m) = parse_time_hm(&sunset_str);
            let (rise_h, rise_m) = parse_time_hm(&sunrise_str);
            let sunset_mins = sun_h * 60 + sun_m;
            let sunrise_mins = rise_h * 60 + rise_m;

            if sunset_mins > sunrise_mins {
                current_mins >= sunset_mins || current_mins < sunrise_mins
            } else {
                current_mins >= sunset_mins && current_mins < sunrise_mins
            }
        }
        "custom" => {
            let (start_h, start_m) = parse_time_hm(&state.schedule_start);
            let (end_h, end_m) = parse_time_hm(&state.schedule_end);
            let start_mins = start_h * 60 + start_m;
            let end_mins = end_h * 60 + end_m;

            if start_mins > end_mins {
                current_mins >= start_mins || current_mins < end_mins
            } else {
                current_mins >= start_mins && current_mins < end_mins
            }
        }
        _ => false,
    }
}

pub fn evaluate_schedule(state: &mut ScreenTempState, force: bool) -> Result<bool, String> {
    if state.schedule_mode == "off" {
        return Ok(false);
    }

    let should_be_on = is_in_schedule_window(state);
    let target_str = if should_be_on { "on" } else { "off" };

    if force {
        state.schedule_target = target_str.to_string();
        if state.enabled != should_be_on {
            state.enabled = should_be_on;
            apply_state(state)?;
            save_state(state)?;
            return Ok(true);
        }
        save_state(state)?;
        return Ok(false);
    }

    // Periodic transition check: detect crossing the scheduled boundary
    if state.schedule_target != target_str {
        state.schedule_target = target_str.to_string();
        state.enabled = should_be_on;
        apply_state(state)?;
        save_state(state)?;
        return Ok(true);
    }

    Ok(false)
}

fn parse_temperature(value: Option<&String>) -> Result<u32, String> {
    let Some(value) = value else {
        return Err(
            "missing temperature value".to_string()
        );
    };

    let temperature = value
        .parse::<u32>()
        .map_err(|_| {
            format!("invalid temperature: {value}")
        })?;

    if !(MIN_TEMP..=MAX_TEMP).contains(&temperature) {
        return Err(
            format!(
                "temperature must be between {}K and {}K",
                MIN_TEMP,
                MAX_TEMP
            )
        );
    }

    Ok(temperature)
}

fn wallpaper_temperature(path: &str) -> Result<u32, String> {
    if !command_exists("ffmpeg") {
        return Err(
            "ffmpeg is required for wallpaper warmth analysis"
                .to_string()
        );
    }

    let output = Command::new("ffmpeg")
        .args([
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            path,
            "-vf",
            "scale=1:1",
            "-frames:v",
            "1",
            "-f",
            "rawvideo",
            "-pix_fmt",
            "rgb24",
            "pipe:1",
        ])
        .output()
        .map_err(|error| {
            format!(
                "failed to analyze wallpaper: {error}"
            )
        })?;

    if !output.status.success() {
        return Err(
            String::from_utf8_lossy(&output.stderr)
                .trim()
                .to_string()
        );
    }

    if output.stdout.len() < 3 {
        return Err(
            "wallpaper analysis returned no RGB data"
                .to_string()
        );
    }

    let red = output.stdout[0] as f32;
    let green = output.stdout[1] as f32;
    let blue = output.stdout[2] as f32;

    // --------------------------------------------------------
    // Warmth score
    //
    // red > blue  => warm image
    // blue > red  => cool image
    //
    // Normalize to roughly -1.0 .. 1.0.
    // --------------------------------------------------------

    let total = (red + green + blue).max(1.0);

    let warmth =
        (red - blue) / total;

    // Amplify gently so typical wallpapers produce
    // a visible but not extreme difference.
    let warmth =
        (warmth * 3.0)
            .clamp(-1.0, 1.0);

    let temperature = if warmth >= 0.0 {
        // Warm wallpaper:
        // 5000K -> 3800K
        WALLPAPER_NEUTRAL_TEMP as f32
            - warmth
                * (
                    WALLPAPER_NEUTRAL_TEMP
                        - WALLPAPER_MIN_TEMP
                ) as f32
    } else {
        // Cool wallpaper:
        // 5000K -> 6000K
        WALLPAPER_NEUTRAL_TEMP as f32
            + (-warmth)
                * (
                    WALLPAPER_MAX_TEMP
                        - WALLPAPER_NEUTRAL_TEMP
                ) as f32
    };

    Ok(
        temperature
            .round()
            .clamp(
                WALLPAPER_MIN_TEMP as f32,
                WALLPAPER_MAX_TEMP as f32,
            ) as u32
    )
}

pub fn handle(args: &[String]) -> Result<(), String> {
    let command = args
        .first()
        .map(String::as_str)
        .unwrap_or("info");

    let mut state = load_state();

    match command {
        "info" => {
            print_json(&state);
        }

        "enable" => {
            state.enabled = true;

            apply_state(&mut state)?;
            save_state(&state)?;

            print_json(&state);
        }

        "disable" => {
            state.enabled = false;

            apply_state(&mut state)?;
            save_state(&state)?;

            print_json(&state);
        }

        "toggle" => {
            state.enabled = !state.enabled;

            apply_state(&mut state)?;
            save_state(&state)?;

            print_json(&state);
        }

        "mode" => {
            let Some(mode) = args.get(1) else {
                return Err(
                    "missing mode: manual | wallpaper | night"
                        .to_string()
                );
            };

            if !matches!(
                mode.as_str(),
                "manual" | "wallpaper" | "night"
            ) {
                return Err(
                    format!(
                        "invalid mode: {mode}"
                    )
                );
            }

            state.mode = mode.clone();

            apply_state(&mut state)?;
            save_state(&state)?;

            print_json(&state);
        }

        "set" => {
            let temperature =
                parse_temperature(args.get(1))?;

            state.manual_temperature =
                temperature;

            state.mode =
                "manual".to_string();

            state.enabled = true;

            apply_state(&mut state)?;
            save_state(&state)?;

            print_json(&state);
        }

        "wallpaper" => {
            let Some(path) = args.get(1) else {
                return Err(
                    "missing wallpaper image path".to_string()
                );
            };

            let temperature =
                wallpaper_temperature(path)?;

            state.wallpaper_temperature =
                temperature;

            if state.enabled
                && state.mode == "wallpaper"
            {
                apply_state(&mut state)?;
            }

            save_state(&state)?;

            print_json(&state);
        }

        "wallpaper-set" => {
            let temperature =
                parse_temperature(args.get(1))?;

            state.wallpaper_temperature =
                temperature;

            if state.enabled
                && state.mode == "wallpaper"
            {
                apply_state(&mut state)?;
            }

            save_state(&state)?;

            print_json(&state);
        }

        "night-set" => {
            let temperature =
                parse_temperature(args.get(1))?;

            state.night_temperature =
                temperature;

            if state.enabled
                && state.mode == "night"
            {
                apply_state(&mut state)?;
            }

            save_state(&state)?;

            print_json(&state);
        }

        "apply" => {
            apply_state(&mut state)?;
            save_state(&state)?;

            print_json(&state);
        }

        "reset" => {
            state = ScreenTempState::default();

            reset_temperature()?;
            save_state(&state)?;

            print_json(&state);
        }

        "schedule" => {
            let mode = args.get(1).map(String::as_str).unwrap_or("off");
            if !matches!(mode, "off" | "sunset" | "custom") {
                return Err("schedule mode must be off, sunset, or custom".to_string());
            }

            state.schedule_mode = mode.to_string();
            if let Some(start) = args.get(2) {
                if !start.is_empty() {
                    state.schedule_start = start.clone();
                }
            }
            if let Some(end) = args.get(3) {
                if !end.is_empty() {
                    state.schedule_end = end.clone();
                }
            }

            let _ = evaluate_schedule(&mut state, true)?;
            save_state(&state)?;
            print_json(&state);
        }

        "evaluate-schedule" => {
            let changed = evaluate_schedule(&mut state, false)?;
            if changed {
                let _ = crate::state::update_state(|s| {
                    s.nightlight_enabled = state.enabled;
                    s.nightlight_mode = state.mode.clone();
                    s.nightlight_temperature = state.temperature;
                });
            }
            print_json(&state);
        }

        _ => {
            return Err(
                format!(
                    "unknown screen temperature command: {command}"
                )
            );
        }
    }

    if command != "info" {
        let _ = crate::state::update_state(|s| {
            s.nightlight_enabled = state.enabled;
            s.nightlight_mode = state.mode.clone();
            s.nightlight_temperature = state.temperature;
        });
    }

    Ok(())
}
