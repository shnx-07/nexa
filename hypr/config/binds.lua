-- ==============================================================================
-- NEXA & HYPRLAND MASTER KEYBINDINGS (binds.lua)
-- ==============================================================================
--
-- HOW TO CUSTOMIZE YOUR KEYBINDINGS:
--
-- 1. CHANGING SHORTCUTS:
--    Simply edit the key name (e.g. change "Return" to "Enter", or "X" to "Print").
--    Hit save, and Hyprland reloads it instantly (no compilation needed).
--
-- 2. ADDING A NEW APPLICATION SHORTCUT:
--    Add a line like:
--      hl.bind(MOD .. " + C", hl.dsp.exec_cmd("google-chrome-stable"))
--
-- 3. UNDERSTANDING 'nexad':
--    'nexad' is the fast Nexa Rust backend tool. It handles heavy operations
--    (instant scratchpads, Quickshell IPC, volume/brightness with 0ms lag).
--    You DO NOT need to touch Rust to change bindings—just change the key here!
-- ==============================================================================

local MOD = "SUPER"

-- Default application definitions (can also be changed in config/variables.lua)
local terminal = TERMINAL or "kitty"
local fileManager = FILE_MANAGER or "dolphin"
local browser = BROWSER or "zen-browser"
local music = MUSIC or "spotify"

-- Path to the compiled Nexa Rust backend binary
local nexad = (os.getenv("HOME") or "") .. "/.config/nexa/rust/target/release/nexad"

-- ==============================================================================
-- 1. TERMINAL & SCRATCHPAD (SUPER + Return / SUPER + SHIFT + Return)
-- ==============================================================================
-- Normal Tiled Terminal: Opens a regular terminal in current workspace (suppressed if scratchpad is open)
hl.bind(MOD .. " + Return", hl.dsp.exec_cmd(nexad .. " hypr terminal"))

-- Persistent Scratchpad Terminal:
-- Press once: opens/restores terminal in the center with immediate focus.
-- Press again: hides it away and instantly restores focus to previous window.
-- Powered by Rust state machine (zero race-condition timers).
hl.bind(MOD .. " + SHIFT + Return", hl.dsp.exec_cmd(nexad .. " hypr scratchpad terminal"))

-- Quick toggle float for currently active window
hl.bind(MOD .. " + SHIFT + T", hl.dsp.window.float({ action = "toggle" }))

-- ==============================================================================
-- 2. FILE MANAGER & SCRATCHPAD (SUPER + E)
-- ==============================================================================
-- Persistent Scratchpad File Manager (Dolphin):
-- Toggle floating file manager anywhere with instant focus memory.
-- Automatically slides away the terminal scratchpad (mutual exclusion).
hl.bind(MOD .. " + E", hl.dsp.exec_cmd(nexad .. " hypr scratchpad files"))

-- Standard application shortcuts
hl.bind(MOD .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(MOD .. " + M", hl.dsp.exec_cmd(music))

-- ==============================================================================
-- 3. NEXA DESKTOP UI & UTILITIES
-- ==============================================================================
-- Wallpaper Picker & Manager
hl.bind("SUPER + W", hl.dsp.global("nexa:wallpaper"))
hl.bind(MOD .. " + SHIFT + W", hl.dsp.exec_cmd(nexad .. " qs workspaceManager toggle"))

-- Dynamic Island Search & Command Palette
hl.bind(MOD .. " + SPACE", hl.dsp.exec_cmd(nexad .. " island search"))
hl.bind(MOD .. " + SHIFT + SPACE", hl.dsp.exec_cmd(nexad .. " island command"))

-- Application Launcher (Modal)
hl.bind(MOD .. " + A", hl.dsp.exec_cmd(nexad .. " qs appLauncher toggle"))

-- Screenshot & Snipping Tools
hl.bind(MOD .. " + X", hl.dsp.exec_cmd(nexad .. " screenshot capture"))
hl.bind(MOD .. " + SHIFT + S", hl.dsp.exec_cmd(nexad .. " snipping capture"))

-- Utility Dock & Lock Screen
hl.bind(MOD .. " + SHIFT + D", hl.dsp.global("shnx-shell:utility-dock"))
hl.bind("SUPER + L", hl.dsp.global("nexa:lock"))
hl.bind(MOD .. " + ALT + L", hl.dsp.exec_cmd(nexad .. " qs lockSettings toggle"))

-- Clipboard Manager & File Stash Shelf
hl.bind(MOD .. " + V", hl.dsp.exec_cmd(nexad .. " qs clipboard toggle"))
hl.bind(MOD .. " + SHIFT + F", hl.dsp.exec_cmd(nexad .. " qs fileShelf toggle"))

-- ==============================================================================
-- 4. WINDOW MANAGEMENT (Native Hyprland C++ - Instant 0ms)
-- ==============================================================================
-- Close & Kill
hl.bind(MOD .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(MOD .. " + SHIFT + X", hl.dsp.window.kill())

-- Window State
hl.bind(MOD .. " + F", hl.dsp.window.fullscreen(mode == 1))
hl.bind(MOD .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(MOD .. " + P", hl.dsp.window.pseudo())

-- Mouse Drag & Resize
hl.bind(MOD .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(MOD .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Focus Movement (Arrow keys)
hl.bind(MOD .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(MOD .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(MOD .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(MOD .. " + down", hl.dsp.focus({ direction = "down" }))

-- Move Window Position (SHIFT + Arrow keys)
hl.bind(MOD .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(MOD .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(MOD .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(MOD .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- ==============================================================================
-- 5. WORKSPACES (1 - 10)
-- ==============================================================================
-- Switch to Workspace (SUPER + 1..0) / Move window to Workspace (SUPER + SHIFT + 1..0)
for workspace = 1, 10 do
	local key = (workspace == 10) and 0 or workspace
	hl.bind(MOD .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
	hl.bind(MOD .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

-- Cycle Workspaces
hl.bind(MOD .. " + TAB", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(MOD .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(MOD .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(MOD .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Magic Special Workspace
hl.bind(MOD .. " + S", hl.dsp.workspace.toggle_special("magic"))

-- ==============================================================================
-- 6. SHOW DESKTOP / TOGGLE MINIMIZE ALL (SUPER + D)
-- ==============================================================================
-- Press once: hides all windows on current workspace to reveal wallpaper.
-- Press again: restores all windows back with original focus intact.
local hidden_desktop_workspace = nil
local hidden_desktop_windows = {}

hl.bind(MOD .. " + D", function()
	local active_ws = hl.get_active_workspace()
	if not active_ws or not active_ws.id then
		return
	end
	local current_ws_id = tostring(active_ws.id)

	-- If already minimized, restore all windows
	if hidden_desktop_workspace == current_ws_id then
		local last_addr = nil
		for _, addr in ipairs(hidden_desktop_windows) do
			hl.dispatch(hl.dsp.window.move({
				workspace = current_ws_id,
				window = "address:" .. tostring(addr),
				silent = true,
			}))
			last_addr = addr
		end
		if last_addr then
			hl.dispatch(hl.dsp.focus({ window = "address:" .. tostring(last_addr) }))
		end
		hidden_desktop_workspace = nil
		hidden_desktop_windows = {}
		return
	end

	-- If a different workspace was minimized, restore it in background first
	if hidden_desktop_workspace ~= nil and #hidden_desktop_windows > 0 then
		for _, addr in ipairs(hidden_desktop_windows) do
			hl.dispatch(hl.dsp.window.move({
				workspace = hidden_desktop_workspace,
				window = "address:" .. tostring(addr),
				silent = true,
			}))
		end
		hidden_desktop_workspace = nil
		hidden_desktop_windows = {}
	end

	-- Minimize current workspace windows to temporary stash workspace 99
	local wins = hl.get_windows() or {}
	local to_hide = {}
	for _, w in ipairs(wins) do
		if w.workspace and tostring(w.workspace.id) == current_ws_id then
			table.insert(to_hide, w.address)
		end
	end

	if #to_hide > 0 then
		hidden_desktop_workspace = current_ws_id
		hidden_desktop_windows = to_hide
		for _, addr in ipairs(to_hide) do
			hl.dispatch(hl.dsp.window.move({
				workspace = "99",
				window = "address:" .. tostring(addr),
				silent = true,
			}))
		end
		hl.dispatch(hl.dsp.focus({ workspace = current_ws_id }))
	end
end)

-- ==============================================================================
-- 7. HARDWARE KEYS & MEDIA CONTROLS
-- ==============================================================================
-- Volume & Mute Keys (repeating = true allows holding keys smoothly without lag)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(nexad .. " island volume-up"), { locked = true, repeating = true })
hl.bind("F3", hl.dsp.exec_cmd(nexad .. " island volume-up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(nexad .. " island volume-down"), { locked = true, repeating = true })
hl.bind("F2", hl.dsp.exec_cmd(nexad .. " island volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(nexad .. " island toggle-mute"), { locked = true, repeating = true })
hl.bind("F1", hl.dsp.exec_cmd(nexad .. " island toggle-mute"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(nexad .. " island toggle-mic-mute"), { locked = true, repeating = true })
hl.bind("F4", hl.dsp.exec_cmd(nexad .. " island toggle-mic-mute"), { locked = true, repeating = true })

-- Display Backlight Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(nexad .. " island brightness-up"), { locked = true, repeating = true })
hl.bind("F6", hl.dsp.exec_cmd(nexad .. " island brightness-up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(nexad .. " island brightness-down"), { locked = true, repeating = true })
hl.bind("F5", hl.dsp.exec_cmd(nexad .. " island brightness-down"), { locked = true, repeating = true })

-- Network / Airplane Mode
hl.bind("F8", hl.dsp.exec_cmd(nexad .. " island airplane"), { locked = true })
hl.bind("XF86WLAN", hl.dsp.exec_cmd(nexad .. " island airplane"), { locked = true })

-- Media Player Controls (via playerctl)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- ==============================================================================
-- 8. SYSTEM SESSION & POWER
-- ==============================================================================
hl.bind(MOD .. " + G", hl.dsp.exec_cmd("hyprctl dispatch workspaceopt allgaps toggle"))
hl.bind(MOD .. " + N", hl.dsp.exec_cmd(nexad .. " island control-center"))
hl.bind(MOD .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(MOD .. " + Escape", hl.dsp.exec_cmd(nexad .. " island power"))
hl.bind(MOD .. " + SHIFT + M", hl.dsp.exit())
hl.bind(MOD .. " + SHIFT + P", hl.dsp.exec_cmd("systemctl poweroff"))
hl.bind(MOD .. " + SHIFT + R", hl.dsp.exec_cmd("systemctl reboot"))
