-- ============================================================
-- MONITOR CONFIGURATIONS (Single Source of Truth)
-- Change display outputs, resolutions, and refresh rates HERE:
-- ============================================================

local external = "HDMI-A-1"
local ext_mode = "2560x1440@144"

local laptop = "eDP-1"
local lap_mode = "1920x1080@60"

local function is_hdmi_connected()
	local p = io.popen("cat /sys/class/drm/*HDMI*/status 2>/dev/null")
	if p then
		local out = p:read("*a")
		p:close()
		return out:find("connected") ~= nil
	end
	return false
end

-- ── Initial monitor declarations (Single display auto-switch) ───────────────
if is_hdmi_connected() then
	-- HDMI is connected: External monitor is the ONLY active display
	hl.monitor({
		output = external,
		mode = ext_mode,
		position = "0x0",
		scale = 1,
		disabled = false,
	})
	hl.monitor({
		output = laptop,
		disabled = true,
	})
else
	-- HDMI is not connected: Laptop display is the ONLY active display
	hl.monitor({
		output = laptop,
		mode = lap_mode,
		position = "0x0",
		scale = 1,
		disabled = false,
	})
	hl.monitor({
		output = external,
		disabled = true,
	})
end

-- ── Hot-plug events ────────────────────────────────────────────────────────
hl.on("monitor.added", function(monitor)
	local name = type(monitor) == "table" and (monitor.name or monitor.output) or tostring(monitor or "")
	if name:find("HDMI") or name:find(external) then
		-- Re-apply external monitor at fixed position with correct mode
		hl.monitor({
			output = name,
			mode = ext_mode,
			position = "0x0",
			scale = 1,
			disabled = false,
		})

		-- Move any workspaces currently on laptop screen over to external monitor
		hl.exec_cmd(
			"hyprctl dispatch focusmonitor "
				.. laptop
				.. " && hyprctl dispatch moveworkspacetomonitor $(hyprctl activeworkspace -j | jq -r .id) "
				.. name
		)

		-- Disable laptop display (Single display auto-switch)
		hl.monitor({
			output = laptop,
			disabled = true,
		})

		-- Focus external monitor
		hl.exec_cmd("hyprctl dispatch focusmonitor " .. name)

		hl.exec_cmd(
			"sleep 0.8 && ~/.config/nexa/scripts/nexa-restart.sh && ~/.config/nexa/scripts/restore-wallpaper.sh"
		)
	end
end)

hl.on("monitor.removed", function(monitor)
	local name = type(monitor) == "table" and (monitor.name or monitor.output) or tostring(monitor or "")
	if name:find("HDMI") or name:find(external) or name == "" then
		-- Re-enable laptop screen as the single active display
		hl.monitor({
			output = laptop,
			mode = lap_mode,
			position = "0x0",
			scale = 1,
			disabled = false,
		})

		hl.exec_cmd("hyprctl dispatch focusmonitor " .. laptop)

		hl.exec_cmd(
			"sleep 0.8 && ~/.config/nexa/scripts/nexa-restart.sh && ~/.config/nexa/scripts/restore-wallpaper.sh"
		)
	end
end)
