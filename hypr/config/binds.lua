-- Keybindings & Shortcuts

local MOD = "SUPER"

-- Applications
local terminal = TERMINAL or "kitty"
local fileManager = FILE_MANAGER or "dolphin"
local browser = BROWSER or "firefox"
local music = MUSIC or "spotify"

-- ============================================================
-- Terminal & Floating Scratchpad Controls (Universal Terminal Support)
-- ============================================================
-- 1. Normal Tiled Terminal
hl.bind(MOD .. " + Return", hl.dsp.exec_cmd(terminal))

-- 2. Toggle Float for Active Terminal (Only if focus is on that terminal)
hl.bind(MOD .. " + SHIFT + T", function()
	local win = hl.get_active_window()
	if win and win.class and win.class ~= "" then
		local lower = tostring(win.class):lower()
		if lower:find("kitty") or lower:find("alacritty") or lower:find("ghostty")
			or lower:find("konsole") or lower:find("wezterm") or lower:find("terminal")
			or lower:find("foot") then
			hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
			hl.dispatch(hl.dsp.window.center())
		end
	end
end)

-- 3. Scratchpad Terminal (Persistent compact floating window across any workspace)
-- - Press once: opens/restores in the middle of screen with full history & immediate focus
-- - Press again: hides it away and restores focus back to previous active window
local previous_window_addr = nil

hl.bind(MOD .. " + SHIFT + Return", function()
	local active_special = hl.get_active_special_workspace()
	local is_open = active_special and (tostring(active_special.name or active_special):find("terminal") ~= nil)

	if is_open then
		-- A. Close / Hide the scratchpad terminal
		hl.dispatch(hl.dsp.workspace.toggle_special("terminal"))

		-- B. Restore focus back to previous window
		if previous_window_addr then
			hl.dispatch(hl.dsp.focus({ window = "address:" .. tostring(previous_window_addr) }))
			previous_window_addr = nil
		end
		return
	end

	-- OPENING SCRATCHPAD:
	-- 1. Remember the currently focused window
	local cur_win = hl.get_active_window()
	if cur_win and cur_win.address then
		previous_window_addr = cur_win.address
	end

	-- 2. Check if a terminal window is already created in special:terminal
	local wins = hl.get_windows() or {}
	local scratch_win = nil
	for _, w in ipairs(wins) do
		if w.workspace and w.workspace.name == "special:terminal" then
			scratch_win = w
			break
		end
	end

	-- 3. If not running yet, launch it on special:terminal
	if not scratch_win then
		hl.exec_cmd("[workspace special:terminal] " .. (terminal or "kitty"))

		-- On initial launch, the window maps asynchronously (~80-200ms).
		-- Schedule focus checks so it grabs focus immediately without requiring a mouse click.
		for _, delay in ipairs({ 80, 160, 260, 400 }) do
			hl.timer(function()
				local current_wins = hl.get_windows() or {}
				for _, w in ipairs(current_wins) do
					if w.workspace and w.workspace.name == "special:terminal" then
						hl.dispatch(hl.dsp.focus({ window = "address:" .. tostring(w.address) }))
						break
					end
				end
			end, { timeout = delay, type = "oneshot" })
		end
	end

	-- 4. Toggle special workspace into view
	hl.dispatch(hl.dsp.workspace.toggle_special("terminal"))

	-- 5. Focus the scratchpad terminal immediately if already mapped
	if scratch_win then
		hl.dispatch(hl.dsp.focus({ window = "address:" .. tostring(scratch_win.address) }))
	end
end)

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
hl.bind(MOD .. " + SHIFT + Q", hl.dsp.window.kill())
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
hl.bind(MOD .. " + N", hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland toggleControlCenter"))
hl.bind(MOD .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"))

-- Media & Brightness Keys
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland volumeUp"),
	{ locked = true, repeating = true }
)
hl.bind(
	"F3",
	hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland volumeUp"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland volumeDown"),
	{ locked = true, repeating = true }
)
hl.bind(
	"F2",
	hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland volumeDown"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland toggleMute"),
	{ locked = true, repeating = true }
)
hl.bind(
	"F1",
	hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland toggleMute"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland toggleMicMute"),
	{ locked = true, repeating = true }
)
hl.bind(
	"F4",
	hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland toggleMicMute"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland brightnessUp"),
	{ locked = true, repeating = true }
)
hl.bind(
	"F6",
	hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland brightnessUp"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland brightnessDown"),
	{ locked = true, repeating = true }
)
hl.bind(
	"F5",
	hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland brightnessDown"),
	{ locked = true, repeating = true }
)
hl.bind(
	"F8",
	hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland toggleAirplane"),
	{ locked = true }
)
hl.bind(
	"XF86WLAN",
	hl.dsp.exec_cmd("qs -p ~/.config/nexa/quickshell ipc call nexaIsland toggleAirplane"),
	{ locked = true }
)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Session Control
hl.bind(MOD .. " + Escape", hl.dsp.exec_cmd("wlogout || hyprshutdown"))
hl.bind(MOD .. " + SHIFT + M", hl.dsp.exit())
hl.bind(MOD .. " + SHIFT + P", hl.dsp.exec_cmd("systemctl poweroff"))
hl.bind(MOD .. " + SHIFT + R", hl.dsp.exec_cmd("systemctl reboot"))
