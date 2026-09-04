-- Input, Touchpad, and Gestures

hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",
		repeat_rate = 25,
		repeat_delay = 300,
		follow_mouse = 1,
		sensitivity = 0,
		--	accel_profile = "flat",
		touchpad = {
			natural_scroll = true,
		},
	},
})

-- Three-finger horizontal swipe -> switch workspace
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down", action = "close" })
hl.gesture({ fingers = 3, direction = "up", action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "left", action = "float" })

-- Cursor settings (Hardware cursors enabled for smooth high-refresh rates)
hl.config({
	cursor = {
		no_hardware_cursors = false,
		enable_hyprcursor = true,
		min_refresh_rate = 144,
		hotspot_padding = 1,
	},
})
