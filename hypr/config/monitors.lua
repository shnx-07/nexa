-- Monitor Configurations

hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "auto",
	scale = 1,
})

hl.monitor({
	output = "HDMI-A-1",
	mode = "2560x1440@144",
	position = "auto",
	scale = 1,
})

hl.on("monitor.added", function(monitor)
	if monitor.name == "HDMI-A-1" then
		hl.monitor({
			output = "eDP-1",
			disabled = true,
		})
	end
end)

hl.on("monitor.removed", function(monitor)
	if monitor.name == "HDMI-A-1" then
		hl.monitor({
			output = "eDP-1",
			mode = "preferred",
			position = "auto",
			scale = 1,
			disabled = false,
		})
	end
end)
