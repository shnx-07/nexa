-- ============================================================
-- MONITOR CONFIGURATIONS (Clean Auto-Switch Single Display)
-- When HDMI connects -> HDMI is primary at 0x0, laptop disabled
-- When HDMI disconnects -> Laptop is primary at 0x0, HDMI disabled
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
		for line in out:gmatch("[^\r\n]+") do
			-- Strictly match whole word "connected", never "disconnected"
			if line:match("^%s*connected%s*$") then
				return true
			end
		end
	end
	return false
end

-- ── Startup / Reload Declarations ───────────────────────────
if is_hdmi_connected() then
	-- HDMI is plugged in: External monitor is primary at 0x0, laptop screen off
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
	-- HDMI is unplugged: Laptop screen is primary at 0x0, HDMI disabled
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

-- ── Dynamic Hot-Plug Events ─────────────────────────────────
hl.on("monitor.added", function(monitor)
	local name = type(monitor) == "table" and (monitor.name or monitor.output) or tostring(monitor or "")
	if name:find("HDMI") or name:find(external) then
		-- 1. Enable external monitor as primary display at 0x0
		hl.monitor({
			output = name,
			mode = ext_mode,
			position = "0x0",
			scale = 1,
			disabled = false,
		})

		-- 2. Disable laptop screen (Hyprland natively migrates all workspaces/windows)
		hl.monitor({
			output = laptop,
			disabled = true,
		})

		-- 3. Restart Nexa cleanly and refresh wallpaper on external display
		hl.exec_cmd(
			"sleep 0.6 && ~/.config/nexa/scripts/nexa-restart.sh && ~/.config/nexa/scripts/restore-wallpaper.sh"
		)
	end
end)

hl.on("monitor.removed", function(monitor)
	local name = type(monitor) == "table" and (monitor.name or monitor.output) or tostring(monitor or "")
	if name:find("HDMI") or name:find(external) or name == "" then
		-- 1. Re-enable laptop screen as primary display at 0x0
		hl.monitor({
			output = laptop,
			mode = lap_mode,
			position = "0x0",
			scale = 1,
			disabled = false,
		})

		-- 2. Explicitly disable external monitor
		hl.monitor({
			output = external,
			disabled = true,
		})

		-- 3. Restart Nexa cleanly and refresh wallpaper on laptop screen
		hl.exec_cmd(
			"sleep 0.6 && ~/.config/nexa/scripts/nexa-restart.sh && ~/.config/nexa/scripts/restore-wallpaper.sh"
		)
	end
end)


