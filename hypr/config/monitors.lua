-- ============================================================
-- MONITOR CONFIGURATIONS (Auto-switch Single Display)
-- ============================================================

local external = MONITOR_EXTERNAL or "HDMI-A-1"
local laptop   = MONITOR_LAPTOP or "eDP-1"
local ext_mode = MONITOR_EXTERNAL_MODE or "2560x1440@144"
local lap_mode = MONITOR_LAPTOP_MODE or "1920x1080@60"

-- ── Static monitor declarations ────────────────────────────────────────────
hl.monitor({
	output = external,
	mode = ext_mode,
	position = "0x0",
	scale = 1,
})

hl.monitor({
	output = laptop,
	mode = lap_mode,
	position = "2560x0",
	scale = 1,
})

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
			"hyprctl dispatch focusmonitor " .. laptop .. " && hyprctl dispatch moveworkspacetomonitor $(hyprctl activeworkspace -j | jq -r .id) "
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
