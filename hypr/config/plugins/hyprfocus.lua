-- =============================================================================
-- Hyprland Plugin: HyprFocus (Focus Animation on Active Window Change)
-- =============================================================================
-- Pulses / flashes the newly focused window so you instantly spot active focus.
-- =============================================================================

-- Ensure plugin binary is loaded
if hl.plugin and hl.plugin.load then
	local user = os.getenv("USER") or "shnx"
	local cache = "/var/cache/hyprpm/" .. user
	pcall(hl.plugin.load, cache .. "/hyprland-plugins/hyprfocus.so")
end

hl.config({
	plugin = {
		hyprfocus = {
			-- Master Toggle (Controlled via config/variables.lua)
			enable = (HYPRFOCUS_ENABLED ~= false),

			-- Focus animation type: "flash" or "shrink"
			keyboard_focus_animation = HYPRFOCUS_ANIMATION or "flash",
			mouse_focus_animation = HYPRFOCUS_ANIMATION or "flash",

			-- Visual Flash Opacity (0.0 = fully transparent pulse, 1.0 = solid)
			fade_opacity = HYPRFOCUS_FLASH_OPACITY or 0.35,

			-- Shrink Scale (e.g. 0.88 = window pulses to 88% size and springs back)
			shrink_percentage = HYPRFOCUS_SHRINK_SCALE or 0.88,

			-- Animate floating windows as well as tiled
			animate_floating = true,

			-- False = animate on every window switch (not just monitor switch)
			only_on_monitor_change = false,
		},
	},
})
