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

	local function tint(c, alpha)
		return tonumber(c:match("%x%x%x%x%x%x"), 16) * 256 + math.floor(alpha * 255 + 0.5)
	end

	-- Presets
	hg.preset("clear", {
		glass_opacity = 0.8,
		blur_strength = 1.0,
		dark = { brightness = 0.82 },
		light = { brightness = 1.2 },
	})

	hg.preset("contrasted", {
		inherits = "high_contrast",
		contrast = 1.2,
		adaptive_dim = 1.0,
		dark = { tint_color = 0x02142aa9 },
	})

	hg.preset("glass", {
		blur_strength = 1.5,
		blur_iterations = 3,
		chromatic_aberration = 0.8,
		fresnel_strength = 0.8,
		edge_thickness = 0.08,
		tint_color = tint("#1e1e2e", 0.12),
		lens_distortion = 0.9,
		brightness = 1.0,
		contrast = 1.7,
		saturation = 1,
		vibrancy = 0.8,
		vibrancy_darkness = 1,
		adaptive_boost = 0.5,
	})

	hg.preset("apple", {
		blur_strength = 2.2,
		blur_iterations = 3,
		refraction_strength = 0.55,
		chromatic_aberration = 0.3,
		fresnel_strength = 0.5,
		specular_strength = 0.75,
		edge_thickness = 0.05,
		lens_distortion = 0.3,
		dark = {
			brightness = 0.82,
			contrast = 0.90,
			saturation = 0.80,
			vibrancy = 0.15,
			adaptive_dim = 0.4,
		},
		light = {
			brightness = 1.12,
			contrast = 0.92,
			saturation = 0.85,
			vibrancy = 0.12,
			adaptive_boost = 0.4,
		},
	})

	-- iOS 26: Crystal Clear Glass (Ultra-transparent, bright luminous pass-through, sharp specular rim, ZERO darkening)
	hg.preset("ios26", {
		glass_opacity = 0.55,
		blur_strength = 0.8,
		blur_iterations = 2,
		refraction_strength = 0.45,
		chromatic_aberration = 0.15,
		fresnel_strength = 0.85,
		specular_strength = 0.9,
		edge_thickness = 0.05,
		tint_color = tint("#4a9eff", 0.15),
		lens_distortion = 0.15,
		brightness = 1.08,
		contrast = 1.0,
		saturation = 1.15,
		vibrancy = 0.4,
		adaptive_boost = 0.4,
		dark = {
			brightness = 1.05,
			contrast = 1.0,
			saturation = 1.15,
			vibrancy = 0.35,
			adaptive_dim = 0.0,
		},
		light = {
			brightness = 1.15,
			contrast = 1.0,
			saturation = 1.15,
			vibrancy = 0.35,
			adaptive_boost = 0.35,
		},
	})

	-- Global Config
	hg.config({
		enabled = true,
		default_theme = "dark",
		default_preset = "ios26",
		layers = { enabled = true },
	})

	hg.layer("quickshell", { preset = "ios26" })
	hg.layer("awww-daemon", { exclude = true })
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

			-- sets the cursor behaviour, supports: "tilt", "rotate", "stretch", "none"
			mode = "stretch",

			-- minimum angle difference in degrees after which the shape is changed
			threshold = 2,

			-- for mode = "rotate"
			rotate = {
				length = 20,
				offset = 0.0,
			},

			-- for mode = "tilt"
			tilt = {
				limit = 5000,
				activation = "negative_quadratic",
				window = 100,
				full = 60,
			},

			-- for mode = "stretch"
			stretch = {
				limit = 3000,
				activation = "quadratic",
				window = 100,
			},

			-- configure shake to find
			shake = {
				enabled = true,
				threshold = 6.0,
				base = 4.0,
				speed = 4.0,
				influence = 0.0,
				limit = 0.0,
				timeout = 2000,
				effects = false,
				ipc = false,
			},

			-- use hyprcursor to get a higher resolution texture when the cursor is magnified
			hyprcursor = {
				nearest = 1,
				enabled = true,
				resolution = -1,
				fallback = "clientside",
			},
		},
	},
})
