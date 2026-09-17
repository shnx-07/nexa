-- ============================================================
-- Hyprland Plugins Configuration
-- ============================================================

-- ------------------------------------------------------------
-- HYPRGLASS (Liquid Glass Effect)
-- Frosted blur, edge refraction, chromatic aberration, specular
-- highlights on transparent windows & layers.
-- ------------------------------------------------------------
if hl.plugin and hl.plugin.hyprglass then
	local hg = hl.plugin.hyprglass

	-- Convert "#RRGGBB" + alpha (0.0 - 1.0) -> RRGGBBAA
	local function tint(hex, alpha)
		hex = hex:gsub("#", "")
		local rgb = tonumber(hex, 16)

		if not rgb then
			return 0x8899AA22
		end

		local a = math.floor(math.max(0, math.min(1, alpha)) * 255 + 0.5)

		return rgb * 256 + a
	end

	-- =========================================================
	-- CLEAR
	-- =========================================================

	hg.preset("clear", {
		glass_opacity = 1.0,
		blur_strength = 2.0,
		blur_iterations = 3,

		dark = {
			brightness = 1.0,
		},

		light = {
			brightness = 1.15,
		},
	})

	-- =========================================================
	-- CONTRASTED
	-- =========================================================

	hg.preset("contrasted", {
		inherits = "high_contrast",

		contrast = 1.2,
		adaptive_dim = 0.7,

		dark = {
			tint_color = 0x02142A99,
		},
	})

	-- =========================================================
	-- GLASS
	-- Stronger glass / colorful glass
	-- =========================================================

	hg.preset("glass", {
		glass_opacity = 0.92,

		blur_strength = 2.5,
		blur_iterations = 4,

		refraction_strength = 0.85,
		chromatic_aberration = 0.65,

		fresnel_strength = 0.85,
		specular_strength = 0.9,

		edge_thickness = 0.08,

		tint_color = tint("#2e1e2e", 0.12),

		lens_distortion = 0.65,

		brightness = 1.05,
		contrast = 1.05,
		saturation = 0.95,
		vibrancy = 0.25,
		vibrancy_darkness = 0.15,

		adaptive_boost = 0.15,

		dark = {
			brightness = 0.92,
			contrast = 0.98,
			saturation = 0.88,
			vibrancy = 0.18,
		},

		light = {
			brightness = 1.08,
			contrast = 0.98,
			saturation = 0.92,
			vibrancy = 0.15,
		},
	})

	-- =========================================================
	-- APPLE / macOS LIQUID GLASS
	--
	-- Clean, translucent, soft highlights.
	-- Low chromatic aberration.
	-- Subtle refraction.
	-- No aggressive darkening.
	-- =========================================================

	hg.preset("apple", {
		glass_opacity = 0.88,

		blur_strength = 2.8,
		blur_iterations = 4,

		-- Optical glass
		refraction_strength = 0.72,
		lens_distortion = 0.42,

		-- Very subtle color separation
		chromatic_aberration = 0.22,

		-- Soft luminous rim
		fresnel_strength = 0.68,
		specular_strength = 0.72,

		-- Thin glass edge
		edge_thickness = 0.055,

		-- Very subtle cool-white tint
		tint_color = tint("#DCE7F5", 0.055),

		-- Dark mode
		dark = {
			brightness = 0.94,
			contrast = 0.94,
			saturation = 0.86,

			vibrancy = 0.14,
			vibrancy_darkness = 0.08,

			-- Keep backgrounds from becoming too dark
			adaptive_dim = 0.12,
		},

		-- Light mode
		light = {
			brightness = 1.08,
			contrast = 0.94,
			saturation = 0.90,

			vibrancy = 0.10,
			vibrancy_darkness = 0.05,

			-- Slightly lift dark backgrounds
			adaptive_boost = 0.10,
		},
	})

	-- =========================================================
	-- iOS / LIQUID GLASS
	--
	-- Brighter and clearer than the Apple preset.
	-- =========================================================

	hg.preset("ios", {
		-- =====================================================
		-- iOS LIQUID GLASS
		-- =====================================================

		-- Don't make the background too opaque.
		glass_opacity = 0.82,

		-- Less blur = background remains recognizable
		blur_strength = 1.25,
		blur_iterations = 3,

		-- =====================================================
		-- REFRACTION
		-- =====================================================

		-- Strong edge displacement
		refraction_strength = 1.0,

		-- Keep rainbow/fringing subtle
		chromatic_aberration = 0.08,

		-- Wider optical bezel
		edge_thickness = 0.12,

		-- =====================================================
		-- CENTER LENS
		-- =====================================================

		-- This is the important one for the "iOS lens" look.
		lens_distortion = 1.0,

		-- =====================================================
		-- LIGHTING
		-- =====================================================

		fresnel_strength = 0.55,
		specular_strength = 0.45,

		-- Almost invisible cool glass tint
		tint_color = tint("#E8F1FF", 0.035),

		-- =====================================================
		-- DARK
		-- =====================================================

		dark = {
			brightness = 0.98,
			contrast = 0.96,
			saturation = 0.94,

			vibrancy = 0.10,
			vibrancy_darkness = 0.03,

			adaptive_dim = 0.03,
		},

		-- =====================================================
		-- LIGHT
		-- =====================================================

		light = {
			brightness = 1.06,
			contrast = 0.96,
			saturation = 0.96,

			vibrancy = 0.08,
			vibrancy_darkness = 0.02,

			adaptive_boost = 0.06,
		},
	})

	hg.preset("ios_2", {
		-- =====================================================
		-- CLEAR iOS LIQUID GLASS
		-- =====================================================

		-- High transparency
		glass_opacity = 0.90,

		-- Keep wallpaper sharp/visible
		blur_strength = 0.8,
		blur_iterations = 2,

		-- =====================================================
		-- OPTICAL REFRACTION
		-- =====================================================

		refraction_strength = 0.95,
		lens_distortion = 0.85,

		-- Very little rainbow coloration
		chromatic_aberration = 0.06,

		-- Thin optical edge
		edge_thickness = 0.09,

		-- =====================================================
		-- LIGHT
		-- =====================================================

		fresnel_strength = 0.35,
		specular_strength = 0.30,

		-- Almost completely transparent / neutral
		tint_color = tint("#FFFFFF", 0.015),

		-- =====================================================
		-- DARK THEME
		-- DO NOT DARKEN THE BACKGROUND
		-- =====================================================

		dark = {
			brightness = 1.0,
			contrast = 1.0,
			saturation = 1.0,

			vibrancy = 0.0,
			vibrancy_darkness = 0.0,

			adaptive_dim = 0.0,
		},

		-- =====================================================
		-- LIGHT THEME
		-- =====================================================

		light = {
			brightness = 1.0,
			contrast = 1.0,
			saturation = 1.0,

			vibrancy = 0.0,
			vibrancy_darkness = 0.0,

			adaptive_boost = 0.0,
		},
	})

	-- =========================================================
	-- GLOBAL CONFIG
	-- =========================================================

	hg.config({
		enabled = true,

		default_theme = "dark",

		-- Apple-style windows by default
		default_preset = "ios_2",

		layers = {
			enabled = true,
		},
	})

	-- =========================================================
	-- LAYER SURFACES
	-- =========================================================

	-- Quickshell UI gets the brighter iOS glass
	hg.layer("quickshell", {
		preset = "ios_2",
		mask_threshold = 0.03,
	})

	-- Don't apply glass to awww daemon
	hg.layer("awww-daemon", {
		exclude = true,
	})
end

-- ------------------------------------------------------------
-- DYNAMIC CURSORS (VirtCode)
-- Realistic physics: stretch, tilt, rotate, and shake to find
-- ------------------------------------------------------------
hl.config({
	plugin = {
		dynamic_cursors = {

			-- enables the plugin
			enabled = true,

			-- sets the cursor behaviour, supports these values:
			-- tilt    - tilt the cursor based on x-velocity
			-- rotate  - rotate the cursor based on movement direction
			-- stretch - stretch the cursor shape based on direction and velocity
			-- none    - do not change the cursor's behaviour
			mode = "stretch",

			-- minimum angle difference in degrees after which the shape is changed
			-- smaller values are smoother, but more expensive for hw cursors
			threshold = 2,

			-- for mode = "rotate"
			rotate = {

				-- length in px of the simulated stick used to rotate the cursor
				-- most realistic if this is your actual cursor size
				length = 20,

				-- clockwise offset applied to the angle in degrees
				-- this will apply to ALL shapes
				offset = 0.0,
			},

			-- for mode = "tilt"
			tilt = {

				-- controls how powerful the tilt is, the lower, the more power
				-- this value controls at which speed (px/s) the full tilt is reached
				limit = 5000,

				-- relationship between speed and tilt, supports these values:
				-- linear             - a linear function is used
				-- quadratic          - a quadratic function is used (most realistic to actual air drag)
				-- negative_quadratic - negative version of the quadratic one, feels more aggressive
				-- see `activation` in `src/mode/utils.cpp` for how exactly the calculation is done
				activation = "negative_quadratic",

				-- time window (ms) over which the speed is calculated
				-- higher values will make slow motions smoother but more delayed
				window = 100,

				-- full tilt for each side (°)
				full = 60,
			},

			-- for mode = "stretch"
			stretch = {

				-- controls how much the cursor is stretched
				-- this value controls at which speed (px/s) the full stretch is reached
				-- the full stretch being twice the original length
				limit = 3000,

				-- relationship between speed and stretch amount, supports these values:
				-- linear             - a linear function is used
				-- quadratic          - a quadratic function is used
				-- negative_quadratic - negative version of the quadratic one, feels more aggressive
				-- see `activation` in `src/mode/utils.cpp` for how exactly the calculation is done
				activation = "quadratic",

				-- time window (ms) over which the speed is calculated
				-- higher values will make slow motions smoother but more delayed
				window = 100,
			},

			-- configure shake to find
			-- magnifies the cursor if its is being shaken
			shake = {

				-- enables shake to find
				enabled = true,

				-- controls how soon a shake is detected
				-- lower values mean sooner
				threshold = 6.0,

				-- magnification level immediately after shake start
				base = 4.0,
				-- magnification increase per second when continuing to shake
				speed = 4.0,
				-- how much the speed is influenced by the current shake intensity
				influence = 0.0,

				-- maximal magnification the cursor can reach
				-- values below 1 disable the limit (e.g. 0)
				limit = 0.0,

				-- time in milliseconds the cursor will stay magnified after a shake has ended
				timeout = 2000,

				-- show cursor behaviour `tilt`, `rotate`, etc. while shaking
				effects = false,

				-- enable ipc events for shake
				-- see the `ipc` section below
				ipc = false,
			},

			-- use hyprcursor to get a higher resolution texture when the cursor is magnified
			-- see the `hyprcursor` section below
			hyprcursor = {

				-- use nearest-neighbour (pixelated) scaling when magnifying beyond texture size
				-- this will also have effect without hyprcursor support being enabled
				-- 0 - never use pixelated scaling
				-- 1 - use pixelated when no highres image
				-- 2 - always use pixelated scaling
				nearest = 1,

				-- enable dedicated hyprcursor support
				enabled = true,

				-- resolution in pixels to load the magnified shapes at
				-- be warned that loading a very high-resolution image will take a long time and might impact memory consumption
				-- -1 means we use [normal cursor size] * [shake:base option]
				resolution = -1,

				-- shape to use when clientside cursors are being magnified
				-- see the shape-name property of shape rules for possible names
				-- specifying clientside will use the actual shape, but will be pixelated
				fallback = "clientside",
			},
		},
	},
})
