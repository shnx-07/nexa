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

fn load_state() -> ScreenTempState {
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

fn save_state(state: &ScreenTempState) -> Result<(), String> {
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
            "night_temperature={}\n"
        ),
        state.enabled,
        state.mode,
        state.manual_temperature,
        state.wallpaper_temperature,
        state.night_temperature,
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

fn print_json(state: &ScreenTempState) {
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
            "\"maxTemperature\":{}",
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
    );
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

        _ => {
            return Err(
                format!(
                    "unknown screen temperature command: {command}"
                )
            );
        }
    }

    Ok(())
}
