use serde::Serialize;
use std::os::unix::process::CommandExt;
use std::process::Command;

#[derive(Serialize)]
struct CommandResult {
    exit_code: i32,
    stdout: String,
    stderr: String,
}

pub fn run(command: &str) {
    let result = Command::new("sh")
        .arg("-lc")
        .arg(command)
        // Put the shell in its own process group so it is not
        // killed when Quickshell restarts and sends SIGTERM to
        // nexad or to Quickshell's process group.
        .process_group(0)
        .output();

    match result {
        Ok(output) => {
            let response = CommandResult {
                exit_code: output.status.code().unwrap_or(-1),
                stdout: String::from_utf8_lossy(&output.stdout).to_string(),
                stderr: String::from_utf8_lossy(&output.stderr).to_string(),
            };

            match serde_json::to_string(&response) {
                Ok(json) => println!("{json}"),
                Err(error) => {
                    eprintln!("Failed to encode command result: {error}");
                    std::process::exit(2);
                }
            }
        }

        Err(error) => {
            eprintln!("Failed to execute command: {error}");
            std::process::exit(2);
        }
    }
}

