use serde::Serialize;
use std::process::Command;

#[derive(Debug, Serialize)]
pub struct BrightnessInfo {
    pub brightness: u32,
    pub current: u64,
    pub maximum: u64,
}

fn run_brightnessctl(
    args: &[&str]
) -> Result<String, String> {
    let output =
        Command::new("brightnessctl")
            .args(args)
            .output()
            .map_err(|error| {
                format!(
                    "failed to execute brightnessctl: {error}"
                )
            })?;

    if !output.status.success() {
        let stderr =
            String::from_utf8_lossy(
                &output.stderr
            );

        return Err(
            format!(
                "brightnessctl failed: {}",
                stderr.trim()
            )
        );
    }

    Ok(
        String::from_utf8_lossy(
            &output.stdout
        )
        .trim()
        .to_string()
    )
}


pub fn info() -> Result<BrightnessInfo, String> {
    let output =
        run_brightnessctl(&["-m"])?;

    let fields: Vec<&str> =
        output
            .split(',')
            .collect();

    if fields.len() < 5 {
        return Err(
            format!(
                "unable to parse brightnessctl output: {output}"
            )
        );
    }

    let current =
        fields[2]
            .parse::<u64>()
            .map_err(|_| {
                "invalid current brightness"
                    .to_string()
            })?;

    let percentage =
        fields[3]
            .trim_end_matches('%')
            .parse::<u32>()
            .map_err(|_| {
                "invalid brightness percentage"
                    .to_string()
            })?;

    let maximum =
        fields[4]
            .parse::<u64>()
            .map_err(|_| {
                "invalid maximum brightness"
                    .to_string()
            })?;

    Ok(BrightnessInfo {
        brightness: percentage.min(100),
        current,
        maximum,
    })
}

pub fn set(
    brightness: u32
) -> Result<BrightnessInfo, String> {
    let brightness =
        brightness.clamp(1, 100);

    let value =
        format!("{brightness}%");

    run_brightnessctl(&[
        "set",
        &value,
    ])?;

    info()
}

pub fn up(
    amount: u32
) -> Result<BrightnessInfo, String> {
    let amount =
        amount.min(100);

    let value =
        format!("+{amount}%");

    run_brightnessctl(&[
        "set",
        &value,
    ])?;

    info()
}

pub fn down(
    amount: u32
) -> Result<BrightnessInfo, String> {
    let amount =
        amount.min(100);

    let value =
        format!("{amount}%-");

    run_brightnessctl(&[
        "set",
        &value,
    ])?;

    info()
}

fn print_json(
    result: Result<BrightnessInfo, String>
) -> Result<(), String> {
    let info =
        result?;

    println!(
        "{}",
        serde_json::to_string(&info)
            .map_err(|error| error.to_string())?
    );

    Ok(())
}

pub fn handle(
    args: &[String]
) -> Result<(), String> {
    if args.is_empty() {
        return Err(
            "usage: nexad brightness <info|set|up|down>"
                .to_string()
        );
    }

    match args[0].as_str() {
        "info" => {
            print_json(
                info()
            )
        }

        "set" => {
            let value =
                args.get(1)
                    .ok_or_else(|| {
                        "missing brightness percentage"
                            .to_string()
                    })?;

            let brightness =
                value
                    .parse::<u32>()
                    .map_err(|_| {
                        "invalid brightness percentage"
                            .to_string()
                    })?;

            print_json(
                set(brightness)
            )
        }

        "up" => {
            let amount =
                args.get(1)
                    .map(String::as_str)
                    .unwrap_or("5")
                    .parse::<u32>()
                    .map_err(|_| {
                        "invalid brightness amount"
                            .to_string()
                    })?;

            print_json(
                up(amount)
            )
        }

        "down" => {
            let amount =
                args.get(1)
                    .map(String::as_str)
                    .unwrap_or("5")
                    .parse::<u32>()
                    .map_err(|_| {
                        "invalid brightness amount"
                            .to_string()
                    })?;

            print_json(
                down(amount)
            )
        }

        _ => {
            Err(
                "usage: nexad brightness <info|set|up|down>"
                    .to_string()
            )
        }
    }
}
