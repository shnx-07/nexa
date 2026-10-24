use std::{
    env,
    path::PathBuf,
    process::Command,
};


fn quickshell_path() -> Result<PathBuf, String> {
    let home =
        env::var("HOME")
            .map_err(|error| {
                format!("HOME unavailable: {error}")
            })?;

    Ok(
        PathBuf::from(home)
            .join(".config")
            .join("nexa")
            .join("quickshell")
    )
}


fn call_quickshell(function: &str) -> Result<(), String> {
    let config_path =
        quickshell_path()?;


    let status =
        Command::new("qs")
            .arg("-p")
            .arg(&config_path)
            .args([
                "ipc",
                "call",
                "nexaIsland",
                function,
            ])
            .status()
            .map_err(|error| {
                format!(
                    "failed to launch qs ipc: {error}"
                )
            })?;


    if !status.success() {
        return Err(
            format!(
                "qs ipc call failed with status: {status}"
            )
        );
    }


    Ok(())
}


pub fn open_search() {
    if let Err(error) =
        call_quickshell("openSearch")
    {
        eprintln!(
            "NEXA Island search error: {error}"
        );

        std::process::exit(2);
    }
}


pub fn open_command() {
    if let Err(error) =
        call_quickshell("openCommand")
    {
        eprintln!(
            "NEXA Island command error: {error}"
        );

        std::process::exit(2);
    }
}
