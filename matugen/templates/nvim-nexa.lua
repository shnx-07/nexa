-- Nexa theme for Neovim / LazyVim
-- Architecture: NexaUI Frame (Permanent System Match) + Switchable Code Syntax Palettes (Dark & Light tokens)

local matugen = {
  bg = "{{colors.background}}",
  fg = "{{colors.on_surface}}",
  surface = "{{colors.surface}}",
  surface_container = "{{colors.surface_container}}",
  surface_highest = "{{colors.surface_container_highest}}",
  primary = "{{colors.primary}}",
  on_primary = "{{colors.on_primary}}",
  primary_container = "{{colors.primary_container}}",
  on_primary_container = "{{colors.on_primary_container}}",
  secondary = "{{colors.secondary}}",
  tertiary = "{{colors.tertiary}}",
  error = "{{colors.error}}",
  outline = "{{colors.outline}}",
  outline_variant = "{{colors.outline_variant}}",
  muted = "{{colors.on_surface_variant}}",
}

-- Calculate luminance of matugen background to automatically select optimal code contrast
local function is_bg_light()
  local hex = matugen.bg
  if not hex or #hex < 7 then return false end
  local r = tonumber(hex:sub(2, 3), 16) or 0
  local g = tonumber(hex:sub(4, 5), 16) or 0
  local b = tonumber(hex:sub(6, 7), 16) or 0
  local lum = (0.299 * r + 0.587 * g + 0.114 * b)
  return lum > 140
end

-- ============================================================
-- CODE SYNTAX PRESETS (STRICTLY CODE TOKENS ONLY - ZERO UI/BG OVERRIDES)
-- ============================================================
local syntax_presets = {
  tokyonight = {
    dark = {
      keyword   = "#bb9af7",
      func      = "#7aa2f7",
      string    = "#9ece6a",
      number    = "#ff9e64",
      type      = "#e0af68",
      constant  = "#f7768e",
      property  = "#73daca",
      operator  = "#89ddff",
      comment   = "#636f88",
      special   = "#2ac3de",
      tag       = "#f7768e",
      attribute = "#e0af68",
      param     = "#e0af68",
    },
    light = {
      keyword   = "#7847bd",
      func      = "#2e5b82",
      string    = "#485e30",
      number    = "#965027",
      type      = "#8f5e15",
      constant  = "#8c4351",
      property  = "#0f4b6e",
      operator  = "#33635c",
      comment   = "#737887",
      special   = "#0f4b6e",
      tag       = "#8c4351",
      attribute = "#8f5e15",
      param     = "#8f5e15",
    },
  },
  catppuccin = {
    dark = { -- Mocha
      keyword   = "#cba6f7",
      func      = "#89b4fa",
      string    = "#a6e3a1",
      number    = "#fab387",
      type      = "#f9e2af",
      constant  = "#f38ba8",
      property  = "#94e2d5",
      operator  = "#89dceb",
      comment   = "#6c7086",
      special   = "#f5c2e7",
      tag       = "#cba6f7",
      attribute = "#f9e2af",
      param     = "#f9e2af",
    },
    light = { -- Latte
      keyword   = "#8839ef",
      func      = "#1e66f5",
      string    = "#40a02b",
      number    = "#fe640b",
      type      = "#df8e1d",
      constant  = "#d20f39",
      property  = "#179299",
      operator  = "#04a5e5",
      comment   = "#7c7f93",
      special   = "#ea76cb",
      tag       = "#8839ef",
      attribute = "#df8e1d",
      param     = "#df8e1d",
    },
  },
  gruvbox = {
    dark = {
      keyword   = "#fb4934",
      func      = "#8ec07c",
      string    = "#b8bb26",
      number    = "#fe8019",
      type      = "#fabd2f",
      constant  = "#d3869b",
      property  = "#83a598",
      operator  = "#fe8019",
      comment   = "#928374",
      special   = "#d79921",
      tag       = "#fb4934",
      attribute = "#fabd2f",
      param     = "#fabd2f",
    },
    light = {
      keyword   = "#9d0006",
      func      = "#427b58",
      string    = "#79740e",
      number    = "#af3a03",
      type      = "#b57614",
      constant  = "#8f3f71",
      property  = "#076678",
      operator  = "#af3a03",
      comment   = "#7c6f64",
      special   = "#af3a03",
      tag       = "#9d0006",
      attribute = "#b57614",
      param     = "#b57614",
    },
  },
  rosepine = {
    dark = { -- Main
      keyword   = "#ebbcba",
      func      = "#9ccfd8",
      string    = "#f6c177",
      number    = "#ea9a97",
      type      = "#c4a7e7",
      constant  = "#eb6f92",
      property  = "#9ccfd8",
      operator  = "#31748f",
      comment   = "#6e6a86",
      special   = "#c4a7e7",
      tag       = "#eb6f92",
      attribute = "#f6c177",
      param     = "#c4a7e7",
    },
    light = { -- Dawn
      keyword   = "#d7827e",
      func      = "#286983",
      string    = "#ea9d34",
      number    = "#b4637a",
      type      = "#907aa9",
      constant  = "#b4637a",
      property  = "#56949f",
      operator  = "#286983",
      comment   = "#797593",
      special   = "#907aa9",
      tag       = "#d7827e",
      attribute = "#ea9d34",
      param     = "#907aa9",
    },
  },
  nord = {
    dark = {
      keyword   = "#81a1c1",
      func      = "#88c0d0",
      string    = "#a3be8c",
      number    = "#d08770",
      type      = "#8fbcbb",
      constant  = "#bf616a",
      property  = "#d8dee9",
      operator  = "#81a1c1",
      comment   = "#616e88",
      special   = "#b48ead",
      tag       = "#bf616a",
      attribute = "#8fbcbb",
      param     = "#8fbcbb",
    },
    light = {
      keyword   = "#5e81ac",
      func      = "#3b6265",
      string    = "#437050",
      number    = "#a05a46",
      type      = "#4c566a",
      constant  = "#a9323d",
      property  = "#2e3440",
      operator  = "#5e81ac",
      comment   = "#6c7a96",
      special   = "#8f4e8b",
      tag       = "#a9323d",
      attribute = "#4c566a",
      param     = "#4c566a",
    },
  },
}

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "nexa"
vim.o.termguicolors = true

local hl = function(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- ============================================================
-- 1. NEXA UI FRAME & SURFACES (Always 100% matched to NexaUI)
-- ============================================================
hl("Normal", { fg = matugen.fg, bg = matugen.bg })
hl("NormalNC", { fg = matugen.muted, bg = matugen.bg })
hl("NormalFloat", { fg = matugen.fg, bg = matugen.surface_container })
hl("FloatBorder", { fg = matugen.primary, bg = matugen.surface_container })
hl("FloatTitle", { fg = matugen.primary, bold = true })
hl("CursorLine", { bg = matugen.surface_container })
hl("CursorLineNr", { fg = matugen.primary, bold = true })
hl("LineNr", { fg = matugen.outline_variant })
hl("Pmenu", { fg = matugen.fg, bg = matugen.surface_container })
hl("PmenuSel", { fg = matugen.on_primary, bg = matugen.primary, bold = true })
hl("PmenuSbar", { bg = matugen.surface_highest })
hl("PmenuThumb", { bg = matugen.outline })
hl("StatusLine", { fg = matugen.fg, bg = matugen.surface_highest })
hl("StatusLineNC", { fg = matugen.muted, bg = matugen.surface_container })
hl("Visual", { bg = matugen.primary_container, fg = matugen.on_primary_container })
hl("Search", { fg = matugen.on_primary, bg = matugen.primary })
hl("IncSearch", { fg = matugen.on_primary, bg = matugen.secondary })
hl("CurSearch", { fg = matugen.on_primary, bg = matugen.primary, bold = true })
hl("Directory", { fg = matugen.primary, bold = true })
hl("Title", { fg = matugen.primary, bold = true })
hl("VertSplit", { fg = matugen.outline_variant })
hl("WinSeparator", { fg = matugen.outline_variant })
hl("SignColumn", { bg = matugen.bg })
hl("FoldColumn", { fg = matugen.outline, bg = matugen.bg })
hl("Folded", { fg = matugen.muted, bg = matugen.surface_container })

-- Neo-tree / Explorer UI
hl("NeoTreeNormal", { fg = matugen.fg, bg = matugen.surface })
hl("NeoTreeNormalNC", { fg = matugen.muted, bg = matugen.surface })
hl("NeoTreeDirectoryIcon", { fg = matugen.primary })
hl("NeoTreeDirectoryName", { fg = matugen.fg, bold = true })
hl("NeoTreeFileName", { fg = matugen.fg })
hl("NeoTreeFileIcon", { fg = matugen.outline })
hl("NeoTreeCursorLine", { bg = matugen.surface_container })
hl("NeoTreeWinSeparator", { fg = matugen.outline_variant, bg = matugen.surface })

-- Telescope & Snacks UI
hl("TelescopeBorder", { fg = matugen.primary, bg = matugen.surface_container })
hl("TelescopePromptBorder", { fg = matugen.primary, bg = matugen.surface_container })
hl("TelescopePromptNormal", { fg = matugen.fg, bg = matugen.surface_container })
hl("TelescopeResultsNormal", { fg = matugen.fg, bg = matugen.surface })
hl("TelescopeSelection", { bg = matugen.primary_container, fg = matugen.on_primary_container })
hl("SnacksPickerBorder", { fg = matugen.primary, bg = matugen.surface_container })
hl("SnacksPickerTree", { fg = matugen.outline_variant })

-- Git Signs
hl("GitSignsAdd", { fg = matugen.secondary })
hl("GitSignsChange", { fg = matugen.tertiary })
hl("GitSignsDelete", { fg = matugen.error })

-- ============================================================
-- 2. APPLY SYNTAX (ONLY CHANGES CODE COLORS - NEVER TOUCHES UI/BG)
-- ============================================================
local function apply_syntax(preset_name, variant_override)
  local p_table = syntax_presets[preset_name] or syntax_presets["tokyonight"]
  local variant = variant_override or (is_bg_light() and "light" or "dark")
  local syn = p_table[variant] or p_table.dark or p_table

  -- Standard Syntax Tokens
  hl("Comment", { fg = syn.comment, italic = true })
  hl("Constant", { fg = syn.constant })
  hl("String", { fg = syn.string })
  hl("Character", { fg = syn.string })
  hl("Number", { fg = syn.number })
  hl("Boolean", { fg = syn.number, bold = true })
  hl("Float", { fg = syn.number })
  hl("Identifier", { fg = matugen.fg })
  hl("Function", { fg = syn.func, bold = true })
  hl("Statement", { fg = syn.keyword })
  hl("Conditional", { fg = syn.keyword, bold = true })
  hl("Repeat", { fg = syn.keyword, bold = true })
  hl("Label", { fg = syn.keyword })
  hl("Operator", { fg = syn.operator })
  hl("Keyword", { fg = syn.keyword, bold = true })
  hl("Exception", { fg = matugen.error, bold = true })
  hl("PreProc", { fg = syn.keyword })
  hl("Include", { fg = syn.keyword })
  hl("Define", { fg = syn.keyword })
  hl("Macro", { fg = syn.constant })
  hl("Type", { fg = syn.type, bold = true })
  hl("StorageClass", { fg = syn.keyword })
  hl("Structure", { fg = syn.type, bold = true })
  hl("Typedef", { fg = syn.type, bold = true })
  hl("Special", { fg = syn.special })
  hl("SpecialChar", { fg = syn.special })
  hl("Delimiter", { fg = syn.operator })
  hl("Underlined", { underline = true })
  hl("Error", { fg = matugen.error, bold = true })
  hl("Todo", { fg = syn.number, bold = true })

  -- Treesitter Highlighting
  hl("@comment", { link = "Comment" })
  hl("@comment.documentation", { fg = syn.comment, italic = true })

  hl("@string", { fg = syn.string })
  hl("@string.regex", { fg = syn.special })
  hl("@string.escape", { fg = syn.special, bold = true })
  hl("@string.special", { fg = syn.special })
  hl("@character", { fg = syn.string })
  hl("@number", { fg = syn.number })
  hl("@number.float", { fg = syn.number })
  hl("@boolean", { fg = syn.number, bold = true })

  hl("@function", { fg = syn.func, bold = true })
  hl("@function.builtin", { fg = syn.func, italic = true })
  hl("@function.call", { fg = syn.func })
  hl("@function.macro", { fg = syn.constant })
  hl("@function.method", { fg = syn.func })
  hl("@function.method.call", { fg = syn.func })
  hl("@constructor", { fg = syn.type, bold = true })

  hl("@keyword", { fg = syn.keyword, bold = true })
  hl("@keyword.coroutine", { fg = syn.keyword, bold = true })
  hl("@keyword.function", { fg = syn.keyword, bold = true })
  hl("@keyword.operator", { fg = syn.operator })
  hl("@keyword.import", { fg = syn.keyword, bold = true })
  hl("@keyword.type", { fg = syn.type, bold = true })
  hl("@keyword.modifier", { fg = syn.keyword })
  hl("@keyword.repeat", { fg = syn.keyword, bold = true })
  hl("@keyword.return", { fg = syn.keyword, bold = true })
  hl("@keyword.debug", { fg = matugen.error })
  hl("@keyword.exception", { fg = matugen.error, bold = true })
  hl("@keyword.conditional", { fg = syn.keyword, bold = true })
  hl("@keyword.directive", { fg = syn.keyword })

  hl("@type", { fg = syn.type, bold = true })
  hl("@type.builtin", { fg = syn.type, italic = true })
  hl("@type.definition", { fg = syn.type, bold = true })
  hl("@type.qualifier", { fg = syn.keyword })

  hl("@variable", { fg = matugen.fg })
  hl("@variable.builtin", { fg = syn.constant, italic = true })
  hl("@variable.parameter", { fg = syn.param, italic = true })
  hl("@variable.member", { fg = syn.property })
  hl("@property", { fg = syn.property })
  hl("@field", { fg = syn.property })

  hl("@constant", { fg = syn.constant })
  hl("@constant.builtin", { fg = syn.constant, bold = true })
  hl("@constant.macro", { fg = syn.constant })

  hl("@tag", { fg = syn.tag, bold = true })
  hl("@tag.attribute", { fg = syn.attribute })
  hl("@tag.delimiter", { fg = syn.operator })

  hl("@operator", { fg = syn.operator })
  hl("@punctuation.bracket", { fg = matugen.outline })
  hl("@punctuation.delimiter", { fg = matugen.outline })
  hl("@punctuation.special", { fg = syn.special })

  -- LSP Diagnostics
  hl("DiagnosticError", { fg = matugen.error })
  hl("DiagnosticWarn", { fg = syn.number })
  hl("DiagnosticInfo", { fg = syn.func })
  hl("DiagnosticHint", { fg = syn.property })

  hl("TelescopeMatching", { fg = syn.keyword, bold = true })
  hl("SnacksPickerMatch", { fg = syn.keyword, bold = true })
end

-- ============================================================
-- 3. STATE MANAGEMENT & USER COMMAND
-- ============================================================
local state_file = vim.fn.stdpath("state") .. "/nexa_code_syntax.txt"

local function parse_args(input_str)
  local clean = (input_str or ""):lower():gsub("[-_]", " ")
  local parts = {}
  for w in clean:gmatch("%S+") do
    table.insert(parts, w)
  end

  local preset = nil
  local variant = nil

  for _, p in ipairs(parts) do
    if p == "light" or p == "latte" or p == "day" or p == "dawn" then
      variant = "light"
    elseif p == "dark" or p == "mocha" or p == "night" or p == "main" then
      variant = "dark"
    elseif syntax_presets[p] then
      preset = p
    else
      for name, _ in pairs(syntax_presets) do
        if p:find(name) or name:find(p) then
          preset = name
          break
        end
      end
    end
  end

  preset = preset or "tokyonight"
  return preset, variant
end

local function load_saved()
  local preset = "tokyonight"
  local variant = nil

  if vim.g.nexa_syntax then
    preset, variant = parse_args(vim.g.nexa_syntax)
    return preset, variant
  end

  local f = io.open(state_file, "r")
  if f then
    local content = f:read("*l")
    f:close()
    if content and #content > 0 then
      preset, variant = parse_args(content)
      return preset, variant
    end
  end
  return preset, nil
end

local function save_state(preset, variant)
  local f = io.open(state_file, "w")
  if f then
    local val = preset .. (variant and (" " .. variant) or "")
    f:write(val)
    f:close()
  end
end

local active_preset, active_variant = load_saved()
vim.g.nexa_syntax = active_preset .. (active_variant and (" " .. active_variant) or "")
apply_syntax(active_preset, active_variant)

-- User Command: :NexaSyntax <preset> [light|dark]
vim.api.nvim_create_user_command("NexaSyntax", function(opts)
  local preset, variant = parse_args(opts.args)
  
  if syntax_presets[preset] then
    local eff_variant = variant or (is_bg_light() and "light" or "dark")
    vim.g.nexa_syntax = preset .. (variant and (" " .. variant) or "")
    save_state(preset, variant)
    apply_syntax(preset, eff_variant)
    vim.notify("Code syntax: " .. preset .. " [" .. eff_variant .. " tokens] (UI frame unchanged)", vim.log.levels.INFO)
  else
    vim.notify("Available syntax presets: tokyonight, catppuccin, gruvbox, rosepine, nord", vim.log.levels.WARN)
  end
end, {
  nargs = 1,
  complete = function(arg_lead, cmd_line, cursor_pos)
    local items = {
      "tokyonight", "tokyonight light", "tokyonight dark",
      "catppuccin", "catppuccin light", "catppuccin dark",
      "gruvbox", "gruvbox light", "gruvbox dark",
      "rosepine", "rosepine light", "rosepine dark",
      "nord", "nord light", "nord dark"
    }
    local matches = {}
    local lead = arg_lead:lower()
    for _, it in ipairs(items) do
      if it:find("^" .. lead) then
        table.insert(matches, it)
      end
    end
    return matches
  end,
  desc = "Switch code token colors (Normal background & UI remain 100% matched to NexaUI)",
})

return matugen
