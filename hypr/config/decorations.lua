-- Theme & Visual Decoration

colors = {
	bg0 = "#1e1e2e",
	bg1 = "#181825",
	fg = "#cdd6f4",
	accent = "#89b4fa",
	accent_alt = "#74c7ec",
}

local function load_dynamic_theme()
	local home = os.getenv("HOME") or "~"
	local cache = home .. "/.cache"
	local config = home .. "/.config/hypr"
	local paths = {
		config .. "/scheme/current.lua",
		cache .. "/hypr/colors.lua",
		cache .. "/wal/colors.lua",
		cache .. "/matugen/colors.lua",
	}
	for _, path in ipairs(paths) do
		local chunk = loadfile(path)
		if chunk then
			local ok, theme_colors = pcall(chunk)
			if ok and type(theme_colors) == "table" and theme_colors.active_border then
				return theme_colors
			end
		end
	end
	return nil
end

local default_theme = {
	active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
	inactive_border = "rgba(595959aa)",
	bell_border = "rgba(ff5555ee)",
}

THEME = {
	resolve = function(manual_theme)
		if manual_theme and type(manual_theme) == "table" and manual_theme.active_border then
			return manual_theme
		end
		return load_dynamic_theme() or default_theme
	end,
}

local visual_settings = {
	manual_theme = nil,
	font = {
		family = "SF Pro Display",
		sizes = { main = 11, bar = 10, launcher = 12, notification = 10, terminal = 11 },
	},
	gaps_in = 5,
	gaps_out = 10,
	border_size = 0,
	rounding = 10,
	rounding_power = 2,
	active_opacity = 1.0,
	-- ------------------------------------------------------------
	-- SHADOW (Window Drop Shadow & Depth)
	-- ------------------------------------------------------------
	shadow = {
		enabled = true,
		range = 40,
		render_power = 4,
		color = "rgba(000000aa)",
		color_inactive = "rgba(00000065)",
		offset = "0 8",
		scale = 1.0,
	},

	-- ------------------------------------------------------------
	-- BLUR
	-- ------------------------------------------------------------
	blur = {
		enabled = true,
		size = 3,
		passes = 1,
		vibrancy = 0.1696,
	},
}

local active_colors = THEME.resolve(visual_settings.manual_theme)

hl.config({
	general = {
		gaps_in = visual_settings.gaps_in,
		gaps_out = visual_settings.gaps_out,
		border_size = visual_settings.border_size,
		col = {
			active_border = active_colors.active_border,
			inactive_border = active_colors.inactive_border,
		},
		resize_on_border = true,
		allow_tearing = false,
		layout = "dwindle",
	},
	decoration = {
		rounding = visual_settings.rounding,
		rounding_power = visual_settings.rounding_power,
		active_opacity = visual_settings.active_opacity,
		inactive_opacity = visual_settings.inactive_opacity,
		shadow = visual_settings.shadow,
		blur = visual_settings.blur,
	},
	dwindle = {
		preserve_split = true,
	},
	master = {
		new_status = "master",
	},
	misc = {
		force_default_wallpaper = -1,
		disable_hyprland_logo = false,
		animate_manual_resizes = true,
		animate_mouse_windowdragging = true,
	},
})
