use super::hypr_command;

/// Returns the complete, pre-compiled Lua batch script containing all Nexa Hyprland rules.
pub fn generate_rules_lua() -> &'static str {
    r#"
-- 1. Base System & Compatibility Rules
hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "fix-xwayland-drags", match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }, no_focus = true })
hl.window_rule({ name = "move-hyprland-run", match = { class = "hyprland-run" }, move = "20 monitor_h-120", float = true })
hl.window_rule({ match = { float = true }, center = true, persistent_size = true })

-- 2. Picture-in-Picture (Dual match title + initial_title)
hl.window_rule({ match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, float = true, keep_aspect_ratio = true, size = { "max(monitor_w, monitor_h)*0.25", "min(monitor_w, monitor_h)*0.25" }, pin = true })
hl.window_rule({ match = { initial_title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, float = true, keep_aspect_ratio = true, size = { "max(monitor_w, monitor_h)*0.25", "min(monitor_w, monitor_h)*0.25" }, pin = true })

-- 3. Universal Modals & Web Popups
hl.window_rule({ match = { modal = true }, float = true, center = true })
hl.window_rule({ match = { class = "^(chrome-.*|chromium-.*|brave-.*)$" }, float = true, center = true, size = { "monitor_w*0.55", "monitor_h*0.65" } })
hl.window_rule({ match = { initial_class = "^(chrome-.*|chromium-.*|brave-.*)$" }, float = true, center = true, size = { "monitor_w*0.55", "monitor_h*0.65" } })

-- 4. Common Dialogs, File Pickers, Modals & OAuth
local modalMatches = {
    { title = "^(Open|Authentication Required|Add Folder to Workspace|Choose Files|Save As|Confirm to replace files|File Operation Progress)$" },
    { initial_title = "^(Open File|Save As|Choose Files|Open)$" },
    { class = "^([Xx]dg-desktop-portal-gtk)$" },
    { initial_class = "^([Xx]dg-desktop-portal-gtk)$" },
    { title = "^(File Upload|Choose wallpaper|Library)(.*)$" },
    { class = "^(.*dialog.*)$" },
    { title = "^(.*dialog.*)$" },
    { class = "^(hyprland-share-picker)$" },
    { class = "^(firefox|zen.*|google-chrome|chromium|Brave-browser)$", title = "^(Extension: .*|Library|Page Info|Password Required|Sign in.*|Log in.*|.*OAuth.*|DevTools.*|Print)$" },
    { class = "^(firefox|zen.*)$", title = "^(About Mozilla Firefox|Opening .*)$" },
}
for _, m in ipairs(modalMatches) do
    hl.window_rule({ match = m, float = true, center = true })
end

-- 5. Utility Windows (Settings, Audio, Bluetooth, Network)
local floatApps = {
    { class = "^(kvantummanager|qt[56]ct|nwg-look)$" },
    { class = "^(org.pulseaudio.pavucontrol|blueman-manager|nm-applet|nm-connection-editor)$" },
    { class = "^(.*[Cc]alc.*)$" },
    { class = "^(org\\.kde\\.keditfiletype)$" },
    { class = "^(.*satty.*)$", title = "^(Satty)$" },
    { title = "^(Winetricks.*|Protontricks.*)$" },
}
for _, m in ipairs(floatApps) do
    hl.window_rule({ match = m, float = true })
end

-- 6. Gaming & Steam Workspace Rules
local gamingApps = "^(steam_app.*|gamescope)$"
local gamingWorkspace = "name:gaming"
hl.window_rule({ match = { content = "game" }, workspace = gamingWorkspace })
hl.window_rule({ match = { xdg_tag = "^(.*game.*)$" }, workspace = gamingWorkspace, fullscreen_state = 2, content = "game", sync_fullscreen = true })
hl.window_rule({ match = { class = gamingApps }, workspace = gamingWorkspace })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List)$" }, float = true })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Launching\\.{3})$" }, float = true, center = true, workspace = gamingWorkspace })

-- 7. Opacity Overrides (100% Solid Opacity for Video & Terminal)
local terminals = "^(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal|wezterm)$"
hl.window_rule({ match = { class = "^(firefox|zen.*)$" }, opacity = "1.0 override" })
hl.window_rule({ match = { class = terminals }, opacity = "1.0 override" })
hl.window_rule({ match = { class = "^(mpv|org.kde.haruna|.*plex.*|org\\.kde\\.gwenview|.*vlc.*)$" }, opacity = "1.0 override" })

-- 8. Terminal Floating & Scratchpad Geometry
hl.window_rule({
    name = "terminal-floating-geometry",
    match = { class = terminals, float = true },
    center = true,
    size = { "monitor_w*0.55", "monitor_h*0.52" },
})
hl.window_rule({
    name = "terminal-scratchpad-geometry",
    match = { workspace = "special:terminal", class = terminals },
    float = true,
    center = true,
    size = { "monitor_w*0.55", "monitor_h*0.52" },
})

-- 9. File Manager Floating & Scratchpad Geometry
local fileManagerApps = "^(org\\.kde\\.dolphin|dolphin|nemo|Nemo|thunar|Thunar|nautilus|[Yy]azi.*)$"
hl.window_rule({
    name = "files-scratchpad-geometry",
    match = { workspace = "special:files", class = fileManagerApps },
    float = true,
    center = true,
    size = { "monitor_w*0.55", "monitor_h*0.55" },
})
hl.window_rule({
    name = "files-scratchpad-geometry-initial",
    match = { workspace = "special:files", initial_class = fileManagerApps },
    float = true,
    center = true,
    size = { "monitor_w*0.55", "monitor_h*0.55" },
})
hl.window_rule({
    name = "files-floating-geometry",
    match = { class = fileManagerApps, float = true },
    center = true,
    size = { "monitor_w*0.55", "monitor_h*0.55" },
})

-- Yazi File Manager (Opens Floating & Centered just like Dolphin)
hl.window_rule({ match = { class = "^([Yy]azi.*)$" }, float = true, center = true, size = { "monitor_w*0.55", "monitor_h*0.55" } })
hl.window_rule({ match = { initial_class = "^([Yy]azi.*)$" }, float = true, center = true, size = { "monitor_w*0.55", "monitor_h*0.55" } })
hl.window_rule({ match = { title = "^(.*[Yy]azi.*)$" }, float = true, center = true, size = { "monitor_w*0.55", "monitor_h*0.55" } })
hl.window_rule({ match = { initial_title = "^(.*[Yy]azi.*)$" }, float = true, center = true, size = { "monitor_w*0.55", "monitor_h*0.55" } })
hl.window_rule({ match = { class = terminals, title = "^(.*[Yy]azi.*)$" }, float = true, center = true, size = { "monitor_w*0.55", "monitor_h*0.55" } })
hl.window_rule({ match = { class = terminals, initial_title = "^(.*[Yy]azi.*)$" }, float = true, center = true, size = { "monitor_w*0.55", "monitor_h*0.55" } })

-- 10. Specific Application Floating & Sizing Rules
hl.window_rule({ match = { class = "^(.*\\.exe)$" }, float = true, center = true, fullscreen_state = 0 })
hl.window_rule({ match = { class = "^(.*[Ll]auncher.*)$" }, float = true })
hl.window_rule({ match = { class = "^(vesktop|discord)$" } })
hl.window_rule({ match = { class = "^(.*[Cc]alc.*)$" }, float = true, size = { "max(monitor_w, monitor_h)*0.17", "min(monitor_w, monitor_h)*0.43" } })
hl.window_rule({ match = { class = "^(org\\.kde\\.keditfiletype)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.kde\\.ark)$" }, size = { "max(monitor_w, monitor_h)*0.40", "min(monitor_w, monitor_h)*0.40" } })
hl.window_rule({ match = { class = "^(.*satty.*)$", title = "^(Satty)$" }, min_size = { "max(monitor_w, monitor_h)*0.35", "min(monitor_w, monitor_h)*0.35" }, float = true })
hl.window_rule({ match = { class = "^(dev\\.)?(noctalia\\.Noctalia(\\.Settings)?)$" }, float = true, size = { "monitor_w*0.70", "monitor_h*0.70" } })

-- 11. Layer Rules (Nexa Power Menu Blur)
hl.layer_rule({ match = { namespace = "shnx-power-menu" }, blur = true, ignore_alpha = 0.15 })
"#
}

/// Injects all compiled window & layer rules directly into the Hyprland compositor
/// via direct UNIX domain socket IPC.
pub fn sync_rules() -> Result<(), String> {
    let script = generate_rules_lua();

    // Clean and compact lines with proper newline separation for Lua blocks
    let clean_script: String = script
        .lines()
        .map(|l| l.trim())
        .filter(|l| !l.is_empty() && !l.starts_with("--"))
        .collect::<Vec<&str>>()
        .join("\n");

    let cmd = format!("eval {clean_script}");
    let resp = hypr_command(&cmd)?;

    if resp != "ok" && !resp.is_empty() {
        eprintln!("[NEXA Rules] sync response: {resp}");
    } else {
        println!("[NEXA Rules] Successfully synced all window & layer rules to Hyprland compositor.");
    }

    Ok(())
}

/// Prints a summary of the active rule catalog managed by Rust.
pub fn print_rules_summary() {
    println!("\nNEXA Compiled Hyprland Rules Catalog:\n");
    println!("  1. System & Compatibility    (Maximize suppress, XWayland drag fix, hyprland-run)");
    println!("  2. Picture-in-Picture       (Dual title matching, 16:9 ratio, auto-pin)");
    println!("  3. Universal Modals          (modal=true, browser popups, OAuth, devtools)");
    println!("  4. Common Dialogs            (File pickers, GTK portals, share pickers, logins)");
    println!("  5. Utility Windows           (Pavucontrol, Blueman, NM, Kvantum, Qt5/6ct, Calc)");
    println!("  6. Gaming & Steam            (Routing to 'gaming' workspace, Friends list float)");
    println!("  7. Opacity Overrides         (100% solid opacity for video players & terminals)");
    println!("  8. Scratchpad Geometry       (Special:terminal 55%x52%, special:files 55%x55%)");
    println!("  9. Specific App Sizing       (Satty, Ark, Noctalia, Yazi centered & sized)");
    println!(" 10. Layer Rules               (shnx-power-menu blur & alpha)\n");
    println!("Usage: nexad hypr rules sync\n");
}
