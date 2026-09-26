-- ============================================================
-- MONITOR CONFIGURATIONS (Managed by nexad display engine)
-- Base fallbacks for Hyprland initialization
-- Dynamic switching, profiles, and OSD are handled by nexad daemon
-- ============================================================

-- Primary internal laptop display default
hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "0x0",
	scale = 1,
})

-- Universal fallback for any connected external monitor
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = 1,
})
