use serde::Serialize;
use std::{
    env,
    fs,
    path::PathBuf,
    process::{Command, Stdio},
    time::{SystemTime, UNIX_EPOCH},
};

#[derive(Debug, Serialize)]
struct SnippingResponse {
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
                "Failed to serialize snipping response: {error}"
            );
        }
    }
}

fn snipping_dir() -> PathBuf {
    let home =
        env::var("HOME")
            .unwrap_or_else(|_| ".".to_string());

    PathBuf::from(home)
        .join("Pictures")
        .join("Snippings")
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
    // ============================================================
    // SELECT REGION
    // ============================================================

    let slurp_output =
        match Command::new("slurp")
            .output()
        {
            Ok(output) => output,

            Err(error) => {
                print_json(
                    &SnippingResponse {
                        success: false,
                        action: "capture",
                        path: None,
                        message: format!(
                            "Failed to start slurp: {error}"
                        ),
                    }
                );

                return;
            }
        };

    if !slurp_output.status.success() {
        print_json(
            &SnippingResponse {
                success: false,
                action: "capture",
                path: None,
                message:
                    "Snipping cancelled"
                        .to_string(),
            }
        );

        return;
    }

    let geometry =
        String::from_utf8_lossy(
            &slurp_output.stdout
        )
        .trim()
        .to_string();

    if geometry.is_empty() {
        print_json(
            &SnippingResponse {
                success: false,
                action: "capture",
                path: None,
                message:
                    "No region selected"
                        .to_string(),
            }
        );

        return;
    }

    // ============================================================
    // CREATE OUTPUT DIRECTORY
    // ============================================================

    let directory =
        snipping_dir();

    if let Err(error) =
        fs::create_dir_all(
            &directory
        )
    {
        print_json(
            &SnippingResponse {
                success: false,
                action: "capture",
                path: None,
                message: format!(
                    "Failed to create snipping directory: {error}"
                ),
            }
        );

        return;
    }

    let filename =
        format!(
            "Snip_{}.png",
            timestamp()
        );

    let path =
        directory.join(filename);

    // ============================================================
    // CAPTURE SELECTED REGION
    // ============================================================

    let grim_status =
        Command::new("grim")
            .arg("-g")
            .arg(&geometry)
            .arg(&path)
            .status();

    match grim_status {
        Ok(status)
            if status.success() => {}

        Ok(status) => {
            print_json(
                &SnippingResponse {
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
                &SnippingResponse {
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
    // COPY TO CLIPBOARD
    // ============================================================

    let file =
        match fs::File::open(
            &path
        ) {
            Ok(file) => file,

            Err(error) => {
                print_json(
                    &SnippingResponse {
                        success: true,
                        action: "capture",
                        path:
                            Some(
                                path
                                    .to_string_lossy()
                                    .to_string()
                            ),
                        message: format!(
                            "Snip saved but failed to open it for clipboard copy: {error}"
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
            .stdin(
                Stdio::from(file)
            )
            .stdout(
                Stdio::null()
            )
            .stderr(
                Stdio::null()
            )
            .status();

    match clipboard_status {
        Ok(status)
            if status.success() =>
        {
            print_json(
                &SnippingResponse {
                    success: true,
                    action: "capture",

                    path:
                        Some(
                            path
                                .to_string_lossy()
                                .to_string()
                        ),

                    message:
                        "Snip saved and copied to clipboard"
                            .to_string(),
                }
            );
        }

        Ok(status) => {
            print_json(
                &SnippingResponse {
                    success: true,
                    action: "capture",

                    path:
                        Some(
                            path
                                .to_string_lossy()
                                .to_string()
                        ),

                    message: format!(
                        "Snip saved, but clipboard copy failed with status: {status}"
                    ),
                }
            );
        }

        Err(error) => {
            print_json(
                &SnippingResponse {
                    success: true,
                    action: "capture",

                    path:
                        Some(
                            path
                                .to_string_lossy()
                                .to_string()
                        ),

                    message: format!(
                        "Snip saved, but failed to start wl-copy: {error}"
                    ),
                }
            );
        }
    }
}
