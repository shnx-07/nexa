-- =============================================================================
-- Hyprland Plugin: HyprGlass (Liquid Glass Effect)
-- =============================================================================
-- Optical blur, edge refraction, chromatic aberration, and specular highlights
-- on transparent windows and Wayland layer surfaces.
-- =============================================================================

-- Ensure plugin binary is loaded
if hl.plugin and hl.plugin.load then
	local user = os.getenv("USER") or "shnx"
	local cache = "/var/cache/hyprpm/" .. user
	pcall(hl.plugin.load, cache .. "/HyprGlass/hyprglass.so")
end

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

	-- =========================================================================
	-- PRESETS
	-- =========================================================================

	-- 1. CLEAR (Minimal blur, maximum transparency)
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

	-- 2. CONTRASTED (Darkened glass for readability)
	hg.preset("contrasted", {
		inherits = "high_contrast",

		contrast = 1.2,
		adaptive_dim = 0.7,

		dark = {
			tint_color = 0x02142A99,
		},
	})

	-- 3. GLASS (Vibrant colorful glass)
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

	-- 4. APPLE / macOS LIQUID GLASS (Clean, translucent, soft luminous highlights)
	hg.preset("apple", {
		glass_opacity = 0.88,

		blur_strength = 2.8,
		blur_iterations = 4,

		refraction_strength = 0.72,
		lens_distortion = 0.42,

		chromatic_aberration = 0.22,

		fresnel_strength = 0.68,
		specular_strength = 0.72,

		edge_thickness = 0.055,

		tint_color = tint("#DCE7F5", 0.055),

		dark = {
			brightness = 0.94,
			contrast = 0.94,
			saturation = 0.86,

			vibrancy = 0.14,
			vibrancy_darkness = 0.08,

			adaptive_dim = 0.12,
		},

		light = {
			brightness = 1.08,
			contrast = 0.94,
			saturation = 0.90,

			vibrancy = 0.10,
			vibrancy_darkness = 0.05,

			adaptive_boost = 0.10,
		},
	})

	-- 5. iOS LIQUID GLASS (Brighter and clearer than Apple preset)
	hg.preset("ios", {
		glass_opacity = 0.82,

		blur_strength = 1.25,
		blur_iterations = 3,

		refraction_strength = 1.0,
		chromatic_aberration = 0.08,
		edge_thickness = 0.12,
		lens_distortion = 1.0,

		fresnel_strength = 0.55,
		specular_strength = 0.45,

		tint_color = tint("#E8F1FF", 0.035),

		dark = {
			brightness = 0.98,
			contrast = 0.96,
			saturation = 0.94,

			vibrancy = 0.10,
			vibrancy_darkness = 0.03,

			adaptive_dim = 0.03,
		},

		light = {
			brightness = 1.06,
			contrast = 0.96,
			saturation = 0.96,

			vibrancy = 0.08,
			vibrancy_darkness = 0.02,

			adaptive_boost = 0.06,
		},
	})

	-- 6. iOS 2 (CLEAR iOS GLASS - High transparency, wallpaper remains sharp)
	hg.preset("ios_2", {
		glass_opacity = 0.90,

		blur_strength = 0.8,
		blur_iterations = 2,

		refraction_strength = 0.95,
		lens_distortion = 0.85,

		chromatic_aberration = 0.06,
		edge_thickness = 0.09,

		fresnel_strength = 0.35,
		specular_strength = 0.30,

		tint_color = tint("#FFFFFF", 0.015),

		dark = {
			brightness = 1.0,
			contrast = 1.0,
			saturation = 1.0,

			vibrancy = 0.0,
			vibrancy_darkness = 0.0,
			adaptive_dim = 0.0,
		},

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
	-- 7. FROST VELVET (Nordic Silky Frosted Glass)
	-- Deep matte diffusion, ultra-smooth background blur, zero rainbow fringing.
	-- Ideal for distraction-free text clarity in terminals and editors.
	-- =========================================================
	hg.preset("frost_velvet", {
		glass_opacity = 0.94,

		blur_strength = 3.2,
		blur_iterations = 5,

		-- Soft, natural light bending
		refraction_strength = 0.45,
		lens_distortion = 0.25,

		-- Virtually zero color fringing for pure monochrome/neutral clarity
		chromatic_aberration = 0.02,

		-- Soft, satin edge highlight
		fresnel_strength = 0.42,
		specular_strength = 0.38,
		edge_thickness = 0.065,

		tint_color = tint("#FFFFFF", 0.02),

		dark = {
			brightness = 0.96,
			contrast = 0.98,
			saturation = 0.92,
			vibrancy = 0.08,
			vibrancy_darkness = 0.04,
			adaptive_dim = 0.08,
		},

		light = {
			brightness = 1.06,
			contrast = 0.96,
			saturation = 0.94,
			vibrancy = 0.06,
			adaptive_boost = 0.06,
		},
	})

	-- =========================================================
	-- 8. CRYSTAL PRISM (Hyper-Refractive Prismatic Crystal)
	-- Jewel-like optical glass: prominent chromatic dispersion and
	-- sharp, luminous jewel edge refractions.
	-- =========================================================
	hg.preset("crystal_prism", {
		glass_opacity = 0.86,

		blur_strength = 1.6,
		blur_iterations = 3,

		-- Strong optical light bending
		refraction_strength = 1.25,
		lens_distortion = 0.95,

		-- Prismatic rainbow separation at outer window bevels
		chromatic_aberration = 0.48,

		-- Brilliant specular gleam and crisp jewel rim
		fresnel_strength = 0.88,
		specular_strength = 0.92,
		edge_thickness = 0.11,

		tint_color = tint("#E0F0FF", 0.04),

		dark = {
			brightness = 1.02,
			contrast = 1.04,
			saturation = 0.98,
			vibrancy = 0.22,
			vibrancy_darkness = 0.10,
			adaptive_dim = 0.05,
		},

		light = {
			brightness = 1.10,
			contrast = 1.02,
			saturation = 0.96,
			vibrancy = 0.18,
			adaptive_boost = 0.10,
		},
	})

	-- =========================================================
	-- 9. OBSIDIAN TINT (Smoked Midnight Glass)
	-- Deep smoked obsidian glass aesthetic with silver rim highlights.
	-- Tames bright wallpapers while maintaining optical transparency.
	-- =========================================================
	hg.preset("obsidian_tint", {
		glass_opacity = 0.85,

		blur_strength = 2.4,
		blur_iterations = 4,

		refraction_strength = 0.65,
		lens_distortion = 0.40,

		chromatic_aberration = 0.08,

		-- Sharp silver metallic edge rim against dark smoked glass
		fresnel_strength = 0.78,
		specular_strength = 0.82,
		edge_thickness = 0.075,

		-- Dark smoked charcoal tint
		tint_color = tint("#0E121B", 0.32),

		dark = {
			brightness = 0.90,
			contrast = 1.08,
			saturation = 0.92,
			vibrancy = 0.22,
			vibrancy_darkness = 0.12,
			adaptive_dim = 0.18,
		},

		light = {
			brightness = 1.04,
			contrast = 1.02,
			saturation = 0.90,
			vibrancy = 0.12,
			adaptive_boost = 0.08,
		},
	})

	-- =========================================================
	-- 10. CRYSTAL CLEAR (Zero Blur, Pure Optical Transparency)
	-- Razor-sharp wallpaper visibility with realistic refraction,
	-- specular edge reflection, and clean glass shine.
	-- =========================================================
	hg.preset("crystal_clear", {
		glass_opacity = 0.98,

		-- Pure crystal clarity: zero background blur passes
		blur_strength = 0.0,
		blur_iterations = 0,

		-- Optical light bending & lens physics
		refraction_strength = 0.85,
		lens_distortion = 0.45,

		-- Crisp prismatic edges with subtle dispersion
		chromatic_aberration = 0.08,

		-- Realistic edge specular gleam & fresnel rim
		fresnel_strength = 0.75,
		specular_strength = 0.80,
		edge_thickness = 0.065,

		-- Clear neutral optical tint
		tint_color = tint("#FFFFFF", 0.01),

		dark = {
			brightness = 1.0,
			contrast = 1.0,
			saturation = 1.0,
			vibrancy = 0.0,
			vibrancy_darkness = 0.0,
			adaptive_dim = 0.0,
		},

		light = {
			brightness = 1.0,
			contrast = 1.0,
			saturation = 1.0,
			vibrancy = 0.0,
			vibrancy_darkness = 0.0,
			adaptive_boost = 0.0,
		},
	})

	-- =========================================================================
	-- GLOBAL CONFIGURATION (Controlled via config/variables.lua)
	-- =========================================================================
	local user_enabled = (HYPRGLASS_ENABLED ~= false)
	local user_global_preset = HYPRGLASS_GLOBAL_PRESET or "ios_2"
	local user_nexa_preset = HYPRGLASS_NEXA_PRESET or "ios_2"

	hg.config({
		enabled = user_enabled,
		default_theme = "dark",
		default_preset = user_global_preset,

		layers = {
			enabled = true,
		},
	})

	-- =========================================================================
	-- LAYER SURFACES
	-- =========================================================================
	local function is_nexa_glass_mode()
		local home = os.getenv("HOME") or ""
		local f = io.open(home .. "/.config/nexa/config/glass.conf", "r")
		if f then
			local content = f:read("*all")
			f:close()
			if content then
				content = content:gsub("%s+", ""):lower()
				return (content == "true" or content == "1")
			end
		end
		return false
	end

	if is_nexa_glass_mode() then
		-- Quickshell UI gets the configured Nexa glass preset in transparent/glass mode
		hg.layer("quickshell", {
			preset = user_nexa_preset,
			mask_threshold = 0.03,
		})
	else
		-- In solid color mode, exclude Quickshell from HyprGlass refraction
		-- so corner anti-aliasing does not refract or reflect light from windows below
		hg.layer("quickshell", {
			exclude = true,
		})
	end

	-- Exclude wallpaper daemons from glass refraction
	hg.layer("skwd-paper", {
		exclude = true,
	})
	hg.layer("awww-daemon", {
		exclude = true,
	})
end

