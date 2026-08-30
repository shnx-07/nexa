use serde::Serialize;
use serde_json::Value;
use std::process::Command;


// ============================================================
// DATA
// ============================================================

#[derive(Debug, Serialize)]
pub struct AudioInfo {
    pub volume: u32,
    pub muted: bool,
}


#[derive(Debug, Serialize)]
pub struct AppAudioInfo {
    pub id: u64,
    pub name: String,
    pub icon: String,
    pub volume: u32,
    pub muted: bool,
}


// ============================================================
// COMMAND HELPERS
// ============================================================

fn run_wpctl(args: &[&str]) -> Result<String, String> {
    let output = Command::new("wpctl")
        .args(args)
        .output()
        .map_err(|error| {
            format!("failed to execute wpctl: {error}")
        })?;

    if !output.status.success() {
        let stderr =
            String::from_utf8_lossy(&output.stderr);

        return Err(format!(
            "wpctl failed: {}",
            stderr.trim()
        ));
    }

    Ok(
        String::from_utf8_lossy(&output.stdout)
            .trim()
            .to_string()
    )
}


fn run_pactl(args: &[&str]) -> Result<String, String> {
    let output = Command::new("pactl")
        .args(args)
        .output()
        .map_err(|error| {
            format!("failed to execute pactl: {error}")
        })?;

    if !output.status.success() {
        let stderr =
            String::from_utf8_lossy(&output.stderr);

        return Err(format!(
            "pactl failed: {}",
            stderr.trim()
        ));
    }

    Ok(
        String::from_utf8_lossy(&output.stdout)
            .trim()
            .to_string()
    )
}


// ============================================================
// GENERIC WPCTL VOLUME
// ============================================================

fn device_info(
    target: &str
) -> Result<AudioInfo, String> {
    let output =
        run_wpctl(&[
            "get-volume",
            target,
        ])?;

    let muted =
        output.contains("[MUTED]");

    let raw_volume =
        output
            .split_whitespace()
            .nth(1)
            .ok_or_else(|| {
                format!(
                    "unable to parse wpctl output: {output}"
                )
            })?;

    let volume_float =
        raw_volume
            .parse::<f32>()
            .map_err(|_| {
                format!(
                    "invalid volume value: {raw_volume}"
                )
            })?;

    let volume =
        (volume_float * 100.0)
            .round()
            .clamp(0.0, 100.0) as u32;

    Ok(AudioInfo {
        volume,
        muted,
    })
}


fn device_set_volume(
    target: &str,
    volume: u32,
) -> Result<AudioInfo, String> {
    let clamped =
        volume.min(100);

    let value =
        format!("{clamped}%");

    run_wpctl(&[
        "set-volume",
        target,
        &value,
    ])?;

    device_info(target)
}


fn device_set_mute(
    target: &str,
    state: &str,
) -> Result<AudioInfo, String> {
    run_wpctl(&[
        "set-mute",
        target,
        state,
    ])?;

    device_info(target)
}


// ============================================================
// OUTPUT / MASTER AUDIO
// ============================================================

pub fn info() -> Result<AudioInfo, String> {
    device_info(
        "@DEFAULT_AUDIO_SINK@"
    )
}


pub fn set(
    volume: u32
) -> Result<AudioInfo, String> {
    let res = device_set_volume(
        "@DEFAULT_AUDIO_SINK@",
        volume,
    )?;
    let _ = crate::state::update_state(|s| {
        s.volume = res.volume;
        s.muted = res.muted;
    });
    Ok(res)
}


pub fn mute() -> Result<AudioInfo, String> {
    let res = device_set_mute(
        "@DEFAULT_AUDIO_SINK@",
        "1",
    )?;
    let _ = crate::state::update_state(|s| {
        s.muted = res.muted;
    });
    Ok(res)
}


pub fn unmute() -> Result<AudioInfo, String> {
    let res = device_set_mute(
        "@DEFAULT_AUDIO_SINK@",
        "0",
    )?;
    let _ = crate::state::update_state(|s| {
        s.muted = res.muted;
    });
    Ok(res)
}


pub fn toggle_mute() -> Result<AudioInfo, String> {
    let res = device_set_mute(
        "@DEFAULT_AUDIO_SINK@",
        "toggle",
    )?;
    let _ = crate::state::update_state(|s| {
        s.muted = res.muted;
    });
    Ok(res)
}


// ============================================================
// INPUT / MICROPHONE
// ============================================================

pub fn input_info() -> Result<AudioInfo, String> {
    device_info(
        "@DEFAULT_AUDIO_SOURCE@"
    )
}


pub fn input_set(
    volume: u32
) -> Result<AudioInfo, String> {
    let res = device_set_volume(
        "@DEFAULT_AUDIO_SOURCE@",
        volume,
    )?;
    let _ = crate::state::update_state(|s| {
        s.input_volume = res.volume;
        s.input_muted = res.muted;
    });
    Ok(res)
}


pub fn input_mute() -> Result<AudioInfo, String> {
    let res = device_set_mute(
        "@DEFAULT_AUDIO_SOURCE@",
        "1",
    )?;
    let _ = crate::state::update_state(|s| {
        s.input_muted = res.muted;
    });
    Ok(res)
}


pub fn input_unmute() -> Result<AudioInfo, String> {
    let res = device_set_mute(
        "@DEFAULT_AUDIO_SOURCE@",
        "0",
    )?;
    let _ = crate::state::update_state(|s| {
        s.input_muted = res.muted;
    });
    Ok(res)
}


pub fn input_toggle_mute()
    -> Result<AudioInfo, String>
{
    let res = device_set_mute(
        "@DEFAULT_AUDIO_SOURCE@",
        "toggle",
    )?;
    let _ = crate::state::update_state(|s| {
        s.input_muted = res.muted;
    });
    Ok(res)
}


// ============================================================
// PER-APPLICATION AUDIO
// ============================================================

fn parse_app_volume(
    entry: &Value
) -> u32 {
    let Some(volume) =
        entry.get("volume")
    else {
        return 0;
    };

    let Some(channels) =
        volume.as_object()
    else {
        return 0;
    };

    let Some(first_channel) =
        channels.values().next()
    else {
        return 0;
    };

    if let Some(percent) =
        first_channel
            .get("value_percent")
            .and_then(|value| value.as_str())
    {
        return percent
            .trim_end_matches('%')
            .parse::<u32>()
            .unwrap_or(0)
            .min(100);
    }

    0
}


pub fn apps()
    -> Result<Vec<AppAudioInfo>, String>
{
    let output =
        run_pactl(&[
            "-f",
            "json",
            "list",
            "sink-inputs",
        ])?;

    let entries: Value =
        serde_json::from_str(&output)
            .map_err(|error| {
                format!(
                    "failed to parse pactl JSON: {error}"
                )
            })?;

    let entries =
        entries
            .as_array()
            .ok_or_else(|| {
                "invalid pactl sink-input JSON"
                    .to_string()
            })?;

    let mut apps =
        Vec::new();

    for entry in entries {
        let id =
            entry
                .get("index")
                .and_then(|value| value.as_u64())
                .unwrap_or(0);

        if id == 0 {
            continue;
        }

        let properties =
            entry.get("properties");

        let app_name =
            properties
                .and_then(|props| {
                    props.get(
                        "application.name"
                    )
                })
                .and_then(|value| {
                    value.as_str()
                });

        let media_name =
            properties
                .and_then(|props| {
                    props.get(
                        "media.name"
                    )
                })
                .and_then(|value| {
                    value.as_str()
                });

        let process_name =
            properties
                .and_then(|props| {
                    props.get(
                        "application.process.binary"
                    )
                })
                .and_then(|value| {
                    value.as_str()
                });

        let name =
            app_name
                .or(media_name)
                .or(process_name)
                .unwrap_or("Unknown")
                .to_string();

        let icon =
            properties
                .and_then(|props| {
                    props.get(
                        "application.icon_name"
                    )
                })
                .and_then(|value| {
                    value.as_str()
                })
                .unwrap_or("")
                .to_string();

        let muted =
            entry
                .get("mute")
                .and_then(|value| {
                    value.as_bool()
                })
                .unwrap_or(false);

        let volume =
            parse_app_volume(entry);

        apps.push(
            AppAudioInfo {
                id,
                name,
                icon,
                volume,
                muted,
            }
        );
    }

    Ok(apps)
}


pub fn app_set(
    id: u64,
    volume: u32,
) -> Result<Vec<AppAudioInfo>, String> {
    let id =
        id.to_string();

    let volume =
        format!(
            "{}%",
            volume.min(100)
        );

    run_pactl(&[
        "set-sink-input-volume",
        &id,
        &volume,
    ])?;

    apps()
}


pub fn app_mute(
    id: u64
) -> Result<Vec<AppAudioInfo>, String> {
    let id =
        id.to_string();

    run_pactl(&[
        "set-sink-input-mute",
        &id,
        "1",
    ])?;

    apps()
}


pub fn app_unmute(
    id: u64
) -> Result<Vec<AppAudioInfo>, String> {
    let id =
        id.to_string();

    run_pactl(&[
        "set-sink-input-mute",
        &id,
        "0",
    ])?;

    apps()
}


pub fn app_toggle_mute(
    id: u64
) -> Result<Vec<AppAudioInfo>, String> {
    let id =
        id.to_string();

    run_pactl(&[
        "set-sink-input-mute",
        &id,
        "toggle",
    ])?;

    apps()
}


// ============================================================
// PRINT HELPERS
// ============================================================

fn print_audio(
    result: Result<AudioInfo, String>
) -> Result<(), String> {
    let state =
        result?;

    println!(
        "{}",
        serde_json::to_string(&state)
            .map_err(|error| {
                error.to_string()
            })?
    );

    Ok(())
}


fn print_apps(
    result: Result<Vec<AppAudioInfo>, String>
) -> Result<(), String> {
    let apps =
        result?;

    println!(
        "{}",
        serde_json::to_string(&apps)
            .map_err(|error| {
                error.to_string()
            })?
    );

    Ok(())
}


fn parse_app_id(
    args: &[String]
) -> Result<u64, String> {
    args.get(1)
        .ok_or_else(|| {
            "missing application stream id"
                .to_string()
        })?
        .parse::<u64>()
        .map_err(|_| {
            "invalid application stream id"
                .to_string()
        })
}


// ============================================================
// CLI
// ============================================================

pub fn handle(
    args: &[String]
) -> Result<(), String> {
    if args.is_empty() {
        return Err(
            "usage: nexad audio \
<info|set|mute|unmute|toggle-mute|\
input-info|input-set|input-mute|input-unmute|input-toggle-mute|\
apps|app-set|app-mute|app-unmute|app-toggle-mute>"
                .to_string()
        );
    }


    match args[0].as_str() {

        // ========================================================
        // OUTPUT
        // ========================================================

        "info" => {
            print_audio(
                info()
            )
        }


        "set" => {
            let volume =
                args.get(1)
                    .ok_or_else(|| {
                        "missing volume percentage"
                            .to_string()
                    })?
                    .parse::<u32>()
                    .map_err(|_| {
                        "invalid volume percentage"
                            .to_string()
                    })?;

            print_audio(
                set(volume)
            )
        }


        "mute" => {
            print_audio(
                mute()
            )
        }


        "unmute" => {
            print_audio(
                unmute()
            )
        }


        "toggle-mute" => {
            print_audio(
                toggle_mute()
            )
        }


        // ========================================================
        // INPUT
        // ========================================================

        "input-info" => {
            print_audio(
                input_info()
            )
        }


        "input-set" => {
            let volume =
                args.get(1)
                    .ok_or_else(|| {
                        "missing microphone volume percentage"
                            .to_string()
                    })?
                    .parse::<u32>()
                    .map_err(|_| {
                        "invalid microphone volume percentage"
                            .to_string()
                    })?;

            print_audio(
                input_set(volume)
            )
        }


        "input-mute" => {
            print_audio(
                input_mute()
            )
        }


        "input-unmute" => {
            print_audio(
                input_unmute()
            )
        }


        "input-toggle-mute" => {
            print_audio(
                input_toggle_mute()
            )
        }


        // ========================================================
        // APPLICATIONS
        // ========================================================

        "apps" => {
            print_apps(
                apps()
            )
        }


        "app-set" => {
            let id =
                parse_app_id(args)?;

            let volume =
                args.get(2)
                    .ok_or_else(|| {
                        "missing application volume"
                            .to_string()
                    })?
                    .parse::<u32>()
                    .map_err(|_| {
                        "invalid application volume"
                            .to_string()
                    })?;

            print_apps(
                app_set(
                    id,
                    volume
                )
            )
        }


        "app-mute" => {
            let id =
                parse_app_id(args)?;

            print_apps(
                app_mute(id)
            )
        }


        "app-unmute" => {
            let id =
                parse_app_id(args)?;

            print_apps(
                app_unmute(id)
            )
        }


        "app-toggle-mute" => {
            let id =
                parse_app_id(args)?;

            print_apps(
                app_toggle_mute(id)
            )
        }


        _ => {
            Err(
                "usage: nexad audio \
<info|set|mute|unmute|toggle-mute|\
input-info|input-set|input-mute|input-unmute|input-toggle-mute|\
apps|app-set|app-mute|app-unmute|app-toggle-mute|\
            )
        }
    }
}
