-- =============================================================================
-- Hyprland Plugin: Scroll Overview (yayuuu/hyprland-scroll-overview)
-- =============================================================================
-- Niri-style smooth horizontal scrolling workspace overview & exposé.
-- Drag-and-drop window movement, keyboard selection, and fluid scale transitions.
-- Controlled visually via Nexa Quickshell Settings.
-- =============================================================================

-- Ensure plugin binary is loaded
if hl.plugin and hl.plugin.load then
	local user = os.getenv("USER") or "shnx"
	local cache = "/var/cache/hyprpm/" .. user
	pcall(hl.plugin.load, cache .. "/hyprland-scroll-overview/scrolloverview.so")
end

if hl.plugin and hl.plugin.scrolloverview then
	hl.config({
		plugin = {
			scrolloverview = {
				-- Swipe gesture max travel distance in px
				gesture_distance = 300,

				-- Preferred workspace overview thumbnail scale factor (0.3 - 0.8)
				scale = SCROLLOVERVIEW_SCALE or 0.55,

				-- Gap in pixels between workspaces in the overview strip
				workspace_gap = SCROLLOVERVIEW_GAP or 48,

				-- Layout ribbon orientation: "horizontal", "vertical", or "auto"
				layout = SCROLLOVERVIEW_LAYOUT or "horizontal",

				-- Wallpaper rendering: 0 = global only, 1 = per-workspace, 2 = both
				wallpaper = 2,

				-- Blur background wallpaper under the overview
				blur = (SCROLLOVERVIEW_BLUR ~= false),

				-- Allow dragging windows between multiple monitors
				cross_monitor_drag = true,

				-- Workspace thumbnail drop shadow
				shadow = {
					enabled = true,
					range = 40,
				},
			},
		},
	})

	-- -------------------------------------------------------------------------
	-- KEYBINDS
	-- -------------------------------------------------------------------------
	-- Bound in binds.lua (MOD + TAB) -> scrolloverview:overview toggle
end

