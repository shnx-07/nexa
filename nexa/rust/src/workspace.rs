use serde::{Deserialize, Serialize};
use std::process::Command;


// ============================================================
// RAW HYPRLAND TYPES
// ============================================================

#[derive(Debug, Deserialize)]
struct HyprWorkspaceRef {
    id: i32,
}


#[derive(Debug, Deserialize)]
struct HyprWorkspace {
    id: i32,
    name: String,

    #[serde(default)]
    monitor: String,
}


#[derive(Debug, Deserialize)]
struct HyprClient {
    address: String,

    #[serde(default)]
    mapped: bool,

    #[serde(default)]
    hidden: bool,

    #[serde(default)]
    at: [i32; 2],

    #[serde(default)]
    size: [i32; 2],

    workspace: HyprWorkspaceRef,

    #[serde(default)]
    floating: bool,

    #[serde(default)]
    pinned: bool,

    #[serde(default)]
    monitor: i32,

    #[serde(default)]
    class: String,

    #[serde(default)]
    title: String,

    #[serde(rename = "initialClass", default)]
    initial_class: String,

    #[serde(rename = "initialTitle", default)]
    initial_title: String,

    #[serde(default)]
    pid: i32,

    #[serde(default)]
    xwayland: bool,
}


#[derive(Debug, Deserialize)]
struct HyprActiveWorkspace {
    id: i32,
}


#[derive(Debug, Deserialize, Default)]
struct HyprActiveWindow {
    #[serde(default)]
    address: String,
}


#[derive(Debug, Deserialize)]
struct HyprMonitor {
    id: i32,
    name: String,

    #[serde(default)]
    x: i32,

    #[serde(default)]
    y: i32,

    #[serde(default)]
    width: i32,

    #[serde(default)]
    height: i32,

    #[serde(default)]
    scale: f64,

    #[serde(default)]
    focused: bool,
}


// ============================================================
// NEXA OUTPUT TYPES
// ============================================================

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WorkspaceState {
    active_workspace: i32,
    active_window: String,

    workspaces: Vec<WorkspaceInfo>,
    special_workspaces: Vec<SpecialWorkspaceInfo>,
    monitors: Vec<MonitorInfo>,
}


#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WorkspaceInfo {
    id: i32,
    name: String,

    exists: bool,
    active: bool,

    monitor: String,

    windows: Vec<WorkspaceWindow>,
}


#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SpecialWorkspaceInfo {
    id: i32,

    name: String,
    display_name: String,

    active: bool,

    monitor: String,

    windows: Vec<WorkspaceWindow>,
}


#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WorkspaceWindow {
    address: String,

    class: String,
    title: String,

    initial_class: String,
    initial_title: String,

    pid: i32,

    x: i32,
    y: i32,

    width: i32,
    height: i32,

    floating: bool,
    pinned: bool,

    hidden: bool,
    mapped: bool,

    xwayland: bool,

    monitor_id: i32,

    focused: bool,
}


#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MonitorInfo {
    id: i32,
    name: String,

    x: i32,
    y: i32,

    width: i32,
    height: i32,

    scale: f64,

    focused: bool,
}


// ============================================================
// HYPRCTL JSON
// ============================================================

fn hyprctl_json<T>(
    section: &str,
) -> Result<T, String>
where
    T: for<'de> Deserialize<'de>,
{
    let output =
        Command::new("hyprctl")
            .args([
                "-j",
                section,
            ])
            .output()
            .map_err(|error| {
                format!(
                    "failed to execute hyprctl: {error}"
                )
            })?;


    if !output.status.success() {

        let stdout =
            String::from_utf8_lossy(
                &output.stdout
            );

        let stderr =
            String::from_utf8_lossy(
                &output.stderr
            );


        let message =
            if !stderr.trim().is_empty() {
                stderr.trim()
            } else if !stdout.trim().is_empty() {
                stdout.trim()
            } else {
                "unknown hyprctl error"
            };


        return Err(
            format!(
                "hyprctl -j {section} failed: {message}"
            )
        );
    }


    serde_json::from_slice(
        &output.stdout
    )
    .map_err(|error| {
        format!(
            "failed to parse hyprctl {section}: {error}"
        )
    })
}


// ============================================================
// LUA / DISPATCH HELPERS
// ============================================================

fn lua_escape(
    value: &str,
) -> String {

    value
        .replace(
            '\\',
            "\\\\",
        )
        .replace(
            '"',
            "\\\"",
        )
}


fn window_selector(
    address: &str,
) -> Result<String, String> {

    let address =
        address.trim();


    if address.is_empty() {
        return Err(
            "window address is empty"
                .to_string()
        );
    }


    if address.starts_with("0x") {

        Ok(
            format!(
                "address:{}",
                address
            )
        )

    } else {

        Ok(
            format!(
                "address:0x{}",
                address
            )
        )
    }
}


fn hyprctl_dispatch(
    expression: &str,
) -> Result<(), String> {

    let output =
        Command::new("hyprctl")
            .args([
                "dispatch",
                expression,
            ])
            .output()
            .map_err(|error| {
                format!(
                    "failed to execute hyprctl: {error}"
                )
            })?;


    if !output.status.success() {

        let stdout =
            String::from_utf8_lossy(
                &output.stdout
            );

        let stderr =
            String::from_utf8_lossy(
                &output.stderr
            );


        let message =
            if !stderr.trim().is_empty() {
                stderr.trim()
            } else if !stdout.trim().is_empty() {
                stdout.trim()
            } else {
                "unknown Hyprland error"
            };


        return Err(
            format!(
                "Hyprland dispatch failed: {message}"
            )
        );
    }


    Ok(())
}


// ============================================================
// WINDOW CONVERSION
// ============================================================

fn make_window(
    client: &HyprClient,
    active_window: &str,
) -> WorkspaceWindow {

    WorkspaceWindow {

        address:
            client.address.clone(),

        class:
            client.class.clone(),

        title:
            client.title.clone(),

        initial_class:
            client.initial_class.clone(),

        initial_title:
            client.initial_title.clone(),

        pid:
            client.pid,

        x:
            client.at[0],

        y:
            client.at[1],

        width:
            client.size[0],

        height:
            client.size[1],

        floating:
            client.floating,

        pinned:
            client.pinned,

        hidden:
            client.hidden,

        mapped:
            client.mapped,

        xwayland:
            client.xwayland,

        monitor_id:
            client.monitor,

        focused:
            !active_window.is_empty()
            && client.address
                == active_window,
    }
}


// ============================================================
// WORKSPACE INFO
// ============================================================

pub fn info() -> Result<WorkspaceState, String> {

    let hypr_workspaces:
        Vec<HyprWorkspace> =
        hyprctl_json(
            "workspaces"
        )?;


    let clients:
        Vec<HyprClient> =
        hyprctl_json(
            "clients"
        )?;


    let active_workspace:
        HyprActiveWorkspace =
        hyprctl_json(
            "activeworkspace"
        )?;


    let active_window:
        HyprActiveWindow =
        hyprctl_json(
            "activewindow"
        )
        .unwrap_or_default();


    let hypr_monitors:
        Vec<HyprMonitor> =
        hyprctl_json(
            "monitors"
        )?;


    // ========================================================
    // REGULAR WORKSPACES 1 - 10
    //
    // NEXA always returns all ten so the QML grid never shifts.
    // ========================================================

    let mut workspaces =
        Vec::with_capacity(10);


    for id in 1..=10 {

        let workspace =
            hypr_workspaces
                .iter()
                .find(|workspace| {
                    workspace.id == id
                });


        let mut windows:
            Vec<WorkspaceWindow> =
            clients
                .iter()
                .filter(|client| {
                    client.workspace.id
                        == id
                })
                .map(|client| {
                    make_window(
                        client,
                        &active_window.address,
                    )
                })
                .collect();


        windows.sort_by_key(
            |window| {
                (
                    window.y,
                    window.x,
                    window.pid,
                )
            }
        );


        workspaces.push(
            WorkspaceInfo {

                id,

                name:
                    workspace
                        .map(|workspace| {
                            workspace.name.clone()
                        })
                        .unwrap_or_else(|| {
                            id.to_string()
                        }),

                exists:
                    workspace.is_some(),

                active:
                    active_workspace.id
                        == id,

                monitor:
                    workspace
                        .map(|workspace| {
                            workspace.monitor.clone()
                        })
                        .unwrap_or_default(),

                windows,
            }
        );
    }


    // ========================================================
    // SPECIAL WORKSPACES
    // ========================================================

    let mut special_workspaces =
        Vec::new();


    for workspace in
        hypr_workspaces
            .iter()
            .filter(|workspace| {
                workspace.id < 0
                || workspace
                    .name
                    .starts_with(
                        "special:"
                    )
            })
    {

        let mut windows:
            Vec<WorkspaceWindow> =
            clients
                .iter()
                .filter(|client| {
                    client.workspace.id
                        == workspace.id
                })
                .map(|client| {
                    make_window(
                        client,
                        &active_window.address,
                    )
                })
                .collect();


        windows.sort_by_key(
            |window| {
                (
                    window.y,
                    window.x,
                    window.pid,
                )
            }
        );


        let display_name =
            workspace
                .name
                .strip_prefix(
                    "special:"
                )
                .unwrap_or(
                    &workspace.name
                )
                .to_string();


        special_workspaces.push(
            SpecialWorkspaceInfo {

                id:
                    workspace.id,

                name:
                    workspace.name.clone(),

                display_name,

                active:
                    active_workspace.id
                        == workspace.id,

                monitor:
                    workspace.monitor.clone(),

                windows,
            }
        );
    }


    special_workspaces.sort_by(
        |a, b| {

            a.display_name
                .to_lowercase()
                .cmp(
                    &b.display_name
                        .to_lowercase()
                )
        }
    );


    // ========================================================
    // MONITORS
    // ========================================================

    let monitors =
        hypr_monitors
            .into_iter()
            .map(|monitor| {

                MonitorInfo {

                    id:
                        monitor.id,

                    name:
                        monitor.name,

                    x:
                        monitor.x,

                    y:
                        monitor.y,

                    width:
                        monitor.width,

                    height:
                        monitor.height,

                    scale:
                        monitor.scale,

                    focused:
                        monitor.focused,
                }
            })
            .collect();


    Ok(
        WorkspaceState {

            active_workspace:
                active_workspace.id,

            active_window:
                active_window.address,

            workspaces,

            special_workspaces,

            monitors,
        }
    )
}


// ============================================================
// SWITCH REGULAR WORKSPACE
// ============================================================

pub fn switch_workspace(
    id: i32,
) -> Result<(), String> {

    if !(1..=10).contains(
        &id
    ) {
        return Err(
            "workspace must be between 1 and 10"
                .to_string()
        );
    }


    let expression =
        format!(
            "hl.dsp.focus({{ workspace = \"{}\" }})",
            id
        );


    hyprctl_dispatch(
        &expression
    )
}


// ============================================================
// FOCUS EXACT WINDOW
// ============================================================

pub fn focus_window(
    address: &str,
) -> Result<(), String> {

    let selector =
        lua_escape(
            &window_selector(
                address
            )?
        );


    let expression =
        format!(
            "hl.dsp.focus({{ window = \"{}\" }})",
            selector
        );


    hyprctl_dispatch(
        &expression
    )
}


// ============================================================
// MOVE EXACT WINDOW → REGULAR WORKSPACE
//
// follow = false:
//     move window but remain on current workspace.
//
// follow = true:
//     move window and follow it.
// ============================================================

pub fn move_window(
    address: &str,
    workspace_id: i32,
    follow: bool,
) -> Result<(), String> {

    if !(1..=10).contains(
        &workspace_id
    ) {
        return Err(
            "workspace must be between 1 and 10"
                .to_string()
        );
    }


    let selector =
        lua_escape(
            &window_selector(
                address
            )?
        );


    let expression =
        format!(
            "hl.dsp.window.move({{ workspace = \"{}\", follow = {}, window = \"{}\" }})",
            workspace_id,
            if follow {
                "true"
            } else {
                "false"
            },
            selector
        );


    hyprctl_dispatch(
        &expression
    )
}


// ============================================================
// MOVE EXACT WINDOW → SPECIAL WORKSPACE
//
// Accepts:
//     magic
//
// or:
//     special:magic
// ============================================================

pub fn move_window_to_special(
    address: &str,
    name: &str,
    follow: bool,
) -> Result<(), String> {

    let name =
        name
            .trim()
            .strip_prefix(
                "special:"
            )
            .unwrap_or(
                name.trim()
            );


    if name.is_empty() {
        return Err(
            "special workspace name is empty"
                .to_string()
        );
    }


    let selector =
        lua_escape(
            &window_selector(
                address
            )?
        );


    let workspace =
        lua_escape(
            &format!(
                "special:{}",
                name
            )
        );


    let expression =
        format!(
            "hl.dsp.window.move({{ workspace = \"{}\", follow = {}, window = \"{}\" }})",
            workspace,
            if follow {
                "true"
            } else {
                "false"
            },
            selector
        );


    hyprctl_dispatch(
        &expression
    )
}


// ============================================================
// TOGGLE SPECIAL WORKSPACE
// ============================================================

pub fn toggle_special(
    name: &str,
) -> Result<(), String> {

    let name =
        name
            .trim()
            .strip_prefix(
                "special:"
            )
            .unwrap_or(
                name.trim()
            );


    if name.is_empty() {
        return Err(
            "special workspace name is empty"
                .to_string()
        );
    }


    let name =
        lua_escape(
            name
        );


    let expression =
        format!(
            "hl.dsp.workspace.toggle_special(\"{}\")",
            name
        );


    hyprctl_dispatch(
        &expression
    )
}


// ============================================================
// CLOSE EXACT WINDOW
// ============================================================

pub fn close_window(
    address: &str,
) -> Result<(), String> {

    let selector =
        lua_escape(
            &window_selector(
                address
            )?
        );


    let expression =
        format!(
            "hl.dsp.window.close({{ window = \"{}\" }})",
            selector
        );


    hyprctl_dispatch(
        &expression
    )
}


// ============================================================
// SUCCESS JSON
// ============================================================

fn print_success(
    action: &str,
    value: serde_json::Value,
) {

    println!(
        "{}",
        serde_json::json!({
            "success": true,
            "action": action,
            "value": value
        })
    );
}


// ============================================================
// CLI HANDLER
// ============================================================

pub fn handle(
    args: &[String],
) -> Result<(), String> {

    let Some(command) =
        args.first()
    else {

        return Err(
            "usage: nexad workspace \
             <info|switch|focus|move|move-follow|move-special|move-special-follow|special|close>"
                .to_string()
        );
    };


    match command.as_str() {

        // ====================================================
        // INFO
        // ====================================================

        "info" => {

            let state =
                info()?;


            println!(
                "{}",
                serde_json::to_string(
                    &state
                )
                .map_err(|error| {
                    format!(
                        "failed to serialize workspace state: {error}"
                    )
                })?
            );


            Ok(())
        }


        // ====================================================
        // SWITCH
        // ====================================================

        "switch" => {

            let id =
                args
                    .get(1)
                    .ok_or_else(|| {
                        "missing workspace id"
                            .to_string()
                    })?
                    .parse::<i32>()
                    .map_err(|_| {
                        "invalid workspace id"
                            .to_string()
                    })?;


            switch_workspace(
                id
            )?;


            print_success(
                "switch",

                serde_json::json!({
                    "workspace": id
                }),
            );


            Ok(())
        }


        // ====================================================
        // FOCUS
        // ====================================================

        "focus" => {

            let address =
                args
                    .get(1)
                    .ok_or_else(|| {
                        "missing window address"
                            .to_string()
                    })?;


            focus_window(
                address
            )?;


            print_success(
                "focus",

                serde_json::json!({
                    "address": address
                }),
            );


            Ok(())
        }


        // ====================================================
        // MOVE → REGULAR
        // ====================================================

        "move"
        | "move-follow" => {

            let address =
                args
                    .get(1)
                    .ok_or_else(|| {
                        "missing window address"
                            .to_string()
                    })?;


            let workspace_id =
                args
                    .get(2)
                    .ok_or_else(|| {
                        "missing target workspace id"
                            .to_string()
                    })?
                    .parse::<i32>()
                    .map_err(|_| {
                        "invalid target workspace id"
                            .to_string()
                    })?;


            let follow =
                command
                == "move-follow";


            move_window(
                address,
                workspace_id,
                follow,
            )?;


            print_success(
                command,

                serde_json::json!({
                    "address": address,
                    "workspace": workspace_id,
                    "follow": follow
                }),
            );


            Ok(())
        }


        // ====================================================
        // MOVE → SPECIAL
        // ====================================================

        "move-special"
        | "move-special-follow" => {

            let address =
                args
                    .get(1)
                    .ok_or_else(|| {
                        "missing window address"
                            .to_string()
                    })?;


            let name =
                args
                    .get(2)
                    .ok_or_else(|| {
                        "missing special workspace name"
                            .to_string()
                    })?;


            let follow =
                command
                == "move-special-follow";


            move_window_to_special(
                address,
                name,
                follow,
            )?;


            let clean_name =
                name
                    .trim()
                    .strip_prefix(
                        "special:"
                    )
                    .unwrap_or(
                        name.trim()
                    );


            print_success(
                command,

                serde_json::json!({
                    "address": address,
                    "workspace":
                        format!(
                            "special:{}",
                            clean_name
                        ),
                    "follow": follow
                }),
            );


            Ok(())
        }


        // ====================================================
        // SPECIAL WORKSPACE TOGGLE
        // ====================================================

        "special" => {

            let name =
                args
                    .get(1)
                    .ok_or_else(|| {
                        "missing special workspace name"
                            .to_string()
                    })?;


            toggle_special(
                name
            )?;


            print_success(
                "special",

                serde_json::json!({
                    "name": name
                }),
            );


            Ok(())
        }


        // ====================================================
        // CLOSE WINDOW
        // ====================================================

        "close" => {

            let address =
                args
                    .get(1)
                    .ok_or_else(|| {
                        "missing window address"
                            .to_string()
                    })?;


            close_window(
                address
            )?;


            print_success(
                "close",

                serde_json::json!({
                    "address": address
                }),
            );


            Ok(())
        }


        // ====================================================
        // UNKNOWN
        // ====================================================

        _ => {

            Err(
                format!(
                    "unknown workspace command: {command}"
                )
            )
        }
    }
}
