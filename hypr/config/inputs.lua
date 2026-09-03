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
		accel_profile = "flat",
		touchpad = {
			natural_scroll = true,
		},
	},
})

-- Three-finger horizontal swipe -> switch workspace
hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})
