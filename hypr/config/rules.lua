-- ============================================================
-- NEXA / Hyprland Window & Layer Rules
-- ============================================================

-- ------------------------------------------------------------
-- Base System & Compatibility Rules
-- ------------------------------------------------------------

-- Suppress maximize requests from apps
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Fix drag issues with XWayland surfaces
hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

-- Hyprland-run placement
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})

-- Generic floating positioning
hl.window_rule({
	match = { float = true },
	center = true,
	persistent_size = true,
})

-- ------------------------------------------------------------
-- Picture-in-Picture (Auto-Float & Pin)
-- ------------------------------------------------------------

hl.window_rule({
	match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
	float = true,
	keep_aspect_ratio = true,
	size = { "max(monitor_w, monitor_h)*0.25", "min(monitor_w, monitor_h)*0.25" },
	pin = true,
})

-- ------------------------------------------------------------
-- Common Dialogs & Modals (Auto-Float)
-- ------------------------------------------------------------

local modalMatches = {
	{ title = "^(Open|Authentication Required|Add Folder to Workspace|Choose Files|Save As|Confirm to replace files|File Operation Progress)$" },
	{ initial_title = "^(Open File)$" },
	{ class = "^([Xx]dg-desktop-portal-gtk)$" },
	{ title = "^(File Upload|Choose wallpaper|Library)(.*)$" },
	{ class = "^(.*dialog.*)$" },
	{ title = "^(.*dialog.*)$" },
	{ class = "^(hyprland-share-picker)$" },
}
for _, m in ipairs(modalMatches) do
	hl.window_rule({ match = m, float = true })
end

-- ------------------------------------------------------------
-- Utility Windows (Settings, Audio, Bluetooth, Network)
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
-- Gaming & Steam Workspace Rules
-- ------------------------------------------------------------

local gamingApps = "^(steam_app.*|gamescope)$"
local gamingWorkspace = "name:gaming"

hl.window_rule({ match = { content = "game" }, workspace = gamingWorkspace })
hl.window_rule({ match = { xdg_tag = "^(.*game.*)$" }, workspace = gamingWorkspace, fullscreen_state = 2, content = "game", sync_fullscreen = true })
hl.window_rule({ match = { class = gamingApps }, workspace = gamingWorkspace })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List)$" }, float = true })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Launching\\.{3})$" }, float = true, center = true, workspace = gamingWorkspace })

-- ------------------------------------------------------------
-- Opacity Overrides (100% Solid Opacity for Video & Terminal)
-- ------------------------------------------------------------

local terminals = "^(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal|wezterm)$"
hl.window_rule({ match = { class = "^(firefox|zen.*)$" }, opacity = "1.0 override" })
hl.window_rule({ match = { class = terminals }, opacity = "1.0 override" })
hl.window_rule({ match = { class = "^(mpv|org.kde.haruna|.*plex.*|org\\.kde\\.gwenview|.*vlc.*)$" }, opacity = "1.0 override" })

-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- Specific Application Floating & Sizing Rules
-- ------------------------------------------------------------

hl.window_rule({ match = { class = "^(.*\\.exe)$" }, float = true, center = true, fullscreen_state = 0 })
hl.window_rule({ match = { class = "^(.*[Ll]auncher.*)$" }, float = true })
hl.window_rule({ match = { class = "^(vesktop|discord)$" } })
hl.window_rule({ match = { class = "^(.*[Cc]alc.*)$" }, float = true, size = { "max(monitor_w, monitor_h)*0.17", "min(monitor_w, monitor_h)*0.43" } })
hl.window_rule({ match = { class = "^(org\\.kde\\.keditfiletype)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.kde\\.ark)$" }, size = { "max(monitor_w, monitor_h)*0.40", "min(monitor_w, monitor_h)*0.40" } })
hl.window_rule({ match = { class = "^(.*satty.*)$", title = "^(Satty)$" }, min_size = { "max(monitor_w, monitor_h)*0.35", "min(monitor_w, monitor_h)*0.35" }, float = true })
hl.window_rule({ match = { class = "^(dev\\.)?(noctalia\\.Noctalia(\\.Settings)?)$" }, float = true, size = { "monitor_w*0.70", "monitor_h*0.70" } })
hl.window_rule({
	match = {
		class = "^(org\\.kde\\.dolphin)$",
		title = "negative:^(Moving.*|Create New.*|Extract.*|Compress.*|Copying.*|Progress.*|Configure.*|Properties.*|Choose\\sApplication.*)$",
	},
	float = true,
	size = { "max(monitor_w, monitor_h)*0.50", "min(monitor_w, monitor_h)*0.55" },
	move = {
		"max(20, min(cursor_x - (window_w*0.50), monitor_w - window_w + 20))",
		"max(20, min(cursor_y - 50, monitor_h - window_h + 20))",
	},
})

-- Layer Rules
-- ------------------------------------------------------------

hl.layer_rule({
	match = {
		namespace = "shnx-power-menu",
	},
	blur = true,
	ignore_alpha = 0.15,
})
