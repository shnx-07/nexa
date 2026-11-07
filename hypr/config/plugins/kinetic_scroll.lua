-- =============================================================================
-- Hyprland Plugin: Kinetic Touchpad Scroll (savonovv/hypr-kinetic-scroll)
-- =============================================================================
-- macOS/iOS-style inertial momentum scrolling for laptop touchpads.
-- Controlled visually via Nexa Quickshell Settings.
-- =============================================================================

-- Ensure plugin binary is loaded
if hl.plugin and hl.plugin.load then
	local user = os.getenv("USER") or "shnx"
	local cache = "/var/cache/hyprpm/" .. user
	pcall(hl.plugin.load, cache .. "/hypr-kinetic-scroll/hypr-kinetic-scroll.so")
end

hl.config({
	plugin = {
		["kinetic-scroll"] = {
			-- Friction & momentum decay per frame (higher = longer glide, e.g. 0.95)
			decel = 0.95,

			-- Cutoff threshold where momentum stops completely
			min_velocity = 0.5,

			-- Frame update rate in ms (10ms = 100 FPS physics tick)
			interval_ms = 10,

			-- Swipe impulse multiplier (higher = faster acceleration on flicks)
			delta_multiplier = 1.0,

			-- Bypass in browsers if native smooth scroll is preferred (0 = active, 1 = bypass)
			disable_in_browser = 0,

			-- Halt momentum immediately if mouse moves to another window (1 = enabled)
			stop_on_target_change = 1,

			-- Space-separated window classes excluded from inertia (e.g. games)
			disabled_classes = "",
		},
	},
})

