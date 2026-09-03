-- Monitor Configurations
-- eDP-1    : Internal laptop display  (1920x1080 @ 60Hz)
-- HDMI-A-1 : External monitor         (2560x1440 @ 144Hz, primary when connected)

-- ── Static monitor declarations ────────────────────────────────────────────
hl.monitor({
	output = "HDMI-A-1",
	mode = "2560x1440@144",
	position = "0x0",
	scale = 1,
})

hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "2560x0",
	scale = 1,
})

-- ── Hot-plug events ────────────────────────────────────────────────────────
hl.on("monitor.added", function(monitor)
	local name = type(monitor) == "table" and (monitor.name or monitor.output) or tostring(monitor or "")
	if name:find("HDMI") then
		-- Re-apply external monitor at fixed position with correct mode
		hl.monitor({
			output = name,
			mode = "2560x1440@144",
			position = "0x0",
			scale = 1,
		})

		-- Move any workspaces currently on eDP-1 over to the external monitor
		-- before disabling it, so nothing gets stranded on a dead output
		hl.exec_cmd(
			"hyprctl dispatch focusmonitor eDP-1 && hyprctl dispatch moveworkspacetomonitor $(hyprctl activeworkspace -j | jq -r .id) "
				.. name
		)

		-- Fully close/disable the laptop screen
		hl.monitor({
			output = "eDP-1",
			disabled = true,
		})

		-- External monitor is now the only display — focus it
		hl.exec_cmd("hyprctl dispatch focusmonitor " .. name)

		hl.exec_cmd(
			"sleep 0.8 && ~/.config/nexa/scripts/nexa-restart.sh && ~/.config/nexa/scripts/restore-wallpaper.sh"
		)
	end
end)

hl.on("monitor.removed", function(monitor)
	local name = type(monitor) == "table" and (monitor.name or monitor.output) or tostring(monitor or "")
	if name:find("HDMI") or name == "" then
		-- Re-enable laptop screen at origin, safely fall back
		hl.monitor({
			output = "eDP-1",
			mode = "preferred",
			position = "0x0",
			scale = 1,
			disabled = false,
		})

		hl.exec_cmd("hyprctl dispatch focusmonitor eDP-1")

		hl.exec_cmd(
			"sleep 0.8 && ~/.config/nexa/scripts/nexa-restart.sh && ~/.config/nexa/scripts/restore-wallpaper.sh"
		)
	end
end)
