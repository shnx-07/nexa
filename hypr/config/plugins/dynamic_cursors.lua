-- =============================================================================
-- Hyprland Plugin: Dynamic Cursors (VirtCode)
-- =============================================================================
-- Realistic physics: stretch, tilt, rotate, and shake-to-find magnification.
-- =============================================================================

-- Ensure plugin binary is loaded
if hl.plugin and hl.plugin.load then
	local user = os.getenv("USER") or "shnx"
	local cache = "/var/cache/hyprpm/" .. user
	pcall(hl.plugin.load, cache .. "/dynamic-cursors/dynamic-cursors.so")
end

if hl.plugin and hl.plugin.dynamic_cursors then
	hl.config({
		plugin = {
			dynamic_cursors = {

				-- Master enable toggle (Controlled via config/variables.lua)
				enabled = (DYNAMIC_CURSORS_ENABLED ~= false),

				-- Cursor physics behaviour: "stretch", "tilt", "rotate", "none"
				mode = DYNAMIC_CURSORS_MODE or "stretch",

				-- Minimum angle delta in degrees before changing shape
				threshold = 2,

				-- -------------------------------------------------------------
				-- 1. ROTATE MODE
				-- -------------------------------------------------------------
				rotate = {
					-- Simulated stick length in px used for rotation angle
					length = 20,
					-- Clockwise offset applied to angle in degrees
					offset = 0.0,
				},

				-- -------------------------------------------------------------
				-- 2. TILT MODE
				-- -------------------------------------------------------------
				tilt = {
					-- Speed (px/s) at which full tilt is achieved (lower = more reactive)
					limit = 5000,

					-- Relationship between speed and tilt:
					-- "linear", "quadratic" (air drag), "negative_quadratic" (aggressive)
					activation = "negative_quadratic",

					-- Rolling time window in ms to calculate speed
					window = 100,

					-- Full tilt angle in degrees for each side
					full = 60,
				},

				-- -------------------------------------------------------------
				-- 3. STRETCH MODE
				-- -------------------------------------------------------------
				stretch = {
					-- Speed (px/s) at which 2x length is reached
					limit = DYNAMIC_CURSORS_STRETCH_LIMIT or 3000,

					-- Relationship between speed and stretch:
					-- "linear", "quadratic", "negative_quadratic"
					activation = "quadratic",

					-- Rolling time window in ms
					window = 100,
				},

				-- -------------------------------------------------------------
				-- 4. SHAKE TO FIND
				-- -------------------------------------------------------------
				shake = {
					-- Master shake toggle
					enabled = (DYNAMIC_CURSORS_SHAKE_ENABLED ~= false),

					-- Sensitivity threshold (lower = triggers sooner)
					threshold = DYNAMIC_CURSORS_SHAKE_SENSITIVITY or 6.0,

					-- Base magnification scale immediately upon detection
					base = DYNAMIC_CURSORS_SHAKE_BASE or 4.0,

					-- Magnification growth per second while shaking continues
					speed = 4.0,

					-- Speed influence based on shake intensity
					influence = 0.0,

					-- Max magnification (0 = unlimited)
					limit = 0.0,

					-- Duration in ms to stay magnified after shake stops
					timeout = 2000,

					-- Whether to show tilt/rotate behaviors while shaking
					effects = false,

					-- Emit IPC event on shake
					ipc = false,
				},

				-- -------------------------------------------------------------
				-- 5. HYPRCURSOR HIGH-RES TEXTURES
				-- -------------------------------------------------------------
				hyprcursor = {
					-- Nearest-neighbour scaling behavior when magnified beyond texture size:
					-- 0 = never pixelate, 1 = pixelate when no high-res, 2 = always pixelate
					nearest = 1,

					enabled = true,

					-- -1 = use [normal cursor size] * [shake:base]
					resolution = -1,

					-- Fallback shape for clientside cursors
					fallback = "clientside",
				},
			},
		},
	})
end

