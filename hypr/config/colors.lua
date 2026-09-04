-- NEXA / Matugen generated Hyprland theme & colors

-- Legacy / Fallback Cachy palette
CACHYLGREEN = "rgba(82dcccff)"
CACHYMGREEN = "rgba(00aa84ff)"
CACHYDGREEN = "rgba(007d6fff)"
CACHYLBLUE  = "rgba(01ccffff)"
CACHYMBLUE  = "rgba(182545ff)"
CACHYDBLUE  = "rgba(111826ff)"
CACHYWHITE  = "rgba(ffffffff)"
CACHYGREY   = "rgba(ddddddff)"
CACHYGRAY   = "rgba(798bb2ff)"

local primary = "#ffb599"
local secondary = "#f0bc95"
local background = "#20181a"
local surface = "#20181a"
local outline = "#84626a"
local outline_variant = "#422e33"
local error = "#f0757f"

local function to_rgba(hex, alpha)
    local h = tostring(hex or ""):gsub("#", "")
    return "rgba(" .. h .. (alpha or "ff") .. ")"
end

return {
    primary = primary,
    secondary = secondary,
    surface = surface,
    background = background,
    outline = outline,
    outline_variant = outline_variant,
    error = error,

    active_border = {
        colors = {
            to_rgba(primary, "ee"),
            to_rgba(secondary, "ee"),
        },
        angle = 45,
    },
    inactive_border = to_rgba(outline_variant, "55"),
    bell_border = to_rgba(error, "ee"),
}
