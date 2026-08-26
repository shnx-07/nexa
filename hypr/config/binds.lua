-- Keybindings & Shortcuts

local MOD = "SUPER"

-- Applications
local terminal = "kitty"
local fileManager = "nemo"
local browser = "xdg-open https:// || firefox || zen-browser"
local music = "spotify"

hl.bind(MOD .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(MOD .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(MOD .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(MOD .. " + M", hl.dsp.exec_cmd(music))

-- ============================================================
-- NEXA
-- ============================================================

--wallpapers
hl.bind("SUPER + W", hl.dsp.global("nexa:wallpaper"))

hl.bind(MOD .. " + SHIFT + W", hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call workspaceManager toggle"))

-- Island Search / Command
hl.bind(MOD .. " + SPACE", hl.dsp.exec_cmd("~/.config/nexa/rust/target/release/nexad island search"))

hl.bind(MOD .. " + SHIFT + SPACE", hl.dsp.exec_cmd("~/.config/nexa/rust/target/release/nexad island command"))

-- App Launcher
hl.bind(MOD .. " + A", hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call appLauncher toggle"))

-- Screenshot
hl.bind(MOD .. " + X", hl.dsp.exec_cmd("~/.config/nexa/rust/target/release/nexad screenshot capture"))

-- Snipping Tool
hl.bind(MOD .. " + SHIFT + S", hl.dsp.exec_cmd("~/.config/nexa/rust/target/release/nexad snipping capture"))

-- Utility Dock
hl.bind(MOD .. " + SHIFT + D", hl.dsp.global("shnx-shell:utility-dock"))

-- LockSCreen
hl.bind("SUPER + L", hl.dsp.global("nexa:lock"))
-- Clipboard
hl.bind(MOD .. " + V", hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call clipboard toggle"))

-- Window Management
hl.bind(MOD .. " + Q", hl.dsp.window.close())
hl.bind(MOD .. " + F", hl.dsp.window.fullscreen(mode == 1))
hl.bind(MOD .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(MOD .. " + P", hl.dsp.window.pseudo())

-- Mouse Controls
hl.bind(MOD .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(MOD .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Focus (Vim HJKL + Arrow keys)
hl.bind(MOD .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(MOD .. " + j", hl.dsp.focus({ direction = "down" }))
hl.bind(MOD .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(MOD .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(MOD .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(MOD .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(MOD .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(MOD .. " + down", hl.dsp.focus({ direction = "down" }))

-- Move Window (SHIFT + Vim HJKL + Arrow keys)
hl.bind(MOD .. " + SHIFT + h", hl.dsp.window.move({ direction = "left" }))
hl.bind(MOD .. " + SHIFT + j", hl.dsp.window.move({ direction = "down" }))
hl.bind(MOD .. " + SHIFT + k", hl.dsp.window.move({ direction = "up" }))
hl.bind(MOD .. " + SHIFT + l", hl.dsp.window.move({ direction = "right" }))
hl.bind(MOD .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(MOD .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(MOD .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(MOD .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- Workspace Access (1-10)
for workspace = 1, 10 do
	local key = (workspace == 10) and 0 or workspace
	hl.bind(MOD .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
	hl.bind(MOD .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

-- Workspace Cycling
hl.bind(MOD .. " + TAB", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(MOD .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(MOD .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(MOD .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Special Workspace (Scratchpad)
hl.bind(MOD .. " + S", hl.dsp.workspace.toggle_special("magic"))

-- System Utilities
hl.bind(MOD .. " + G", hl.dsp.exec_cmd("hyprctl dispatch workspaceopt allgaps toggle"))
hl.bind(MOD .. " + N", hl.dsp.exec_cmd("swaync-client -t"))
hl.bind(MOD .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"))

-- Media & Brightness Keys
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Session Control
hl.bind(MOD .. " + Escape", hl.dsp.exec_cmd("wlogout || hyprshutdown"))
hl.bind(MOD .. " + SHIFT + M", hl.dsp.exit())
hl.bind(MOD .. " + SHIFT + P", hl.dsp.exec_cmd("systemctl poweroff"))
hl.bind(MOD .. " + SHIFT + R", hl.dsp.exec_cmd("systemctl reboot"))
