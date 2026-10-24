use serde::Serialize;
use std::{
    env,
    fs,
    path::PathBuf,
    process::{Command, Stdio},
    time::{SystemTime, UNIX_EPOCH},
};

#[derive(Debug, Serialize)]
struct ScreenshotResponse {
    success: bool,
    action: &'static str,
    path: Option<String>,
    message: String,
}

fn print_json<T: Serialize>(value: &T) {
    match serde_json::to_string(value) {
        Ok(json) => println!("{json}"),

        Err(error) => {
            eprintln!(
                "Failed to serialize screenshot response: {error}"
            );
        }
    }
}

fn screenshot_dir() -> PathBuf {
    let home =
        env::var("HOME")
            .unwrap_or_else(|_| ".".to_string());

    PathBuf::from(home)
        .join("Pictures")
        .join("Screenshots")
}

fn timestamp() -> String {
    let now =
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

    let output =
        Command::new("date")
            .arg("-d")
            .arg(format!("@{now}"))
            .arg("+%Y-%m-%d_%H-%M-%S")
            .output();

    match output {
        Ok(output) if output.status.success() => {
            String::from_utf8_lossy(
                &output.stdout
            )
            .trim()
            .to_string()
        }

        _ => now.to_string(),
    }
}

pub fn capture() {
    let directory =
        screenshot_dir();

    if let Err(error) =
        fs::create_dir_all(&directory)
    {
        print_json(
            &ScreenshotResponse {
                success: false,
                action: "capture",
                path: None,
                message: format!(
                    "Failed to create screenshot directory: {error}"
                ),
            }
        );

        return;
    }

    let filename =
        format!(
            "Screenshot_{}.png",
            timestamp()
        );

    let path =
        directory.join(filename);

    // ============================================================
    // CAPTURE TO FILE
    // ============================================================

    let status =
        Command::new("grim")
            .arg(&path)
            .status();

    match status {
        Ok(status)
            if status.success() => {}

        Ok(status) => {
            print_json(
                &ScreenshotResponse {
                    success: false,
                    action: "capture",
                    path: None,
                    message: format!(
                        "grim failed with status: {status}"
                    ),
                }
            );

            return;
        }

        Err(error) => {
            print_json(
                &ScreenshotResponse {
                    success: false,
                    action: "capture",
                    path: None,
                    message: format!(
                        "Failed to start grim: {error}"
                    ),
                }
            );

            return;
        }
    }

    // ============================================================
    // COPY SAVED IMAGE TO CLIPBOARD
    // ============================================================

    let file =
        match fs::File::open(&path) {
            Ok(file) => file,

            Err(error) => {
                print_json(
                    &ScreenshotResponse {
                        success: false,
                        action: "capture",
                        path:
                            Some(
                                path
                                    .to_string_lossy()
                                    .to_string()
                            ),
                        message: format!(
                            "Screenshot saved but failed to open it for clipboard copy: {error}"
                        ),
                    }
                );

                return;
            }
        };

    let clipboard_status =
        Command::new("wl-copy")
            .arg("--type")
            .arg("image/png")
            .stdin(Stdio::from(file))
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();

    match clipboard_status {
        Ok(status)
            if status.success() =>
        {
            print_json(
                &ScreenshotResponse {
                    success: true,
                    action: "capture",

                    path:
                        Some(
                            path
                                .to_string_lossy()
                                .to_string()
                        ),

                    message:
                        "Screenshot saved and copied to clipboard"
                            .to_string(),
                }
            );
        }

        Ok(status) => {
            print_json(
                &ScreenshotResponse {
                    success: true,
                    action: "capture",

                    path:
                        Some(
                            path
                                .to_string_lossy()
                                .to_string()
                        ),

                    message: format!(
                        "Screenshot saved, but clipboard copy failed with status: {status}"
                    ),
                }
            );
        }

        Err(error) => {
            print_json(
                &ScreenshotResponse {
                    success: true,
                    action: "capture",

                    path:
                        Some(
                            path
                                .to_string_lossy()
                                .to_string()
                        ),

                    message: format!(
                        "Screenshot saved, but failed to start wl-copy: {error}"
                    ),
                }
            );
        }
    }
}
