-- ============================================================
-- HYPRLAND GLOBAL VARIABLES & DEFAULT APPS
-- ============================================================

-- Default Applications
TERMINAL = "kitty"
FILE_MANAGER = "dolphin"
--FILE_MANAGER = "nemo"
BROWSER = "firefox"
EDITOR = "code"
CALCULATOR = "gnome-calculator"
MUSIC = "spotify"

-- Workspaces
NUM_WORKSPACES = 5

-- =============================================================================
-- WORKSPACE ORIENTATION & ANIMATION DIRECTION
-- =============================================================================
-- Controls whether workspaces transition vertically (up/down) or horizontally (left/right).
--   • "vertical"   - Workspaces slide up/down (slidevert)
--   • "horizontal" - Workspaces slide left/right (default / slidefade)
WORKSPACE_ORIENTATION = "horizontal"

-- =============================================================================
-- 1. HYPRGLASS (Liquid Glass, Frosted Blur & Refraction)
-- =============================================================================
-- Optical blur, chromatic aberration, edge refraction, and specular highlight.
-- Presets available (choose any for NEXA or GLOBAL):
--   • "crystal_clear"  - Zero blur, pure optical glass (razor-sharp wallpaper)
--   • "ios_2"          - Default iOS 2.0 liquid glass (balanced blur, edge refraction)
--   • "ios"            - iOS classic glass (airy translucent diffusion)
--   • "apple"          - Apple VisionOS glass (spacious optical blur with highlight rims)
--   • "frost_velvet"   - Nordic silky matte frosted glass (5 blur passes, low dispersion)
--   • "crystal_prism"  - Jewel optical crystal (1.25x refraction, vivid chromatic dispersion)
--   • "obsidian_tint"  - Midnight smoked dark glass with metallic silver rims
--   • "glass"          - Standard balanced liquid glass with natural depth
--   • "clear"          - Minimal blur, maximum optical transparency
--   • "contrasted"     - Deep darkened glass for high code legibility

HYPRGLASS_ENABLED = true -- Master toggle: true / false
HYPRGLASS_NEXA_PRESET = "crystal_clear" -- Preset for Nexa Shell (Top Bar, Island, Dock, Settings)
HYPRGLASS_GLOBAL_PRESET = "crystal_clear" -- Preset for all Desktop Windows (Terminal, Apps, etc.)

-- =============================================================================
-- 2. DYNAMIC CURSORS (Physics & Shake-to-Find)
-- =============================================================================
-- Physics behavior modes:
--   • "stretch"        - Stretch cursor shape based on velocity and direction
--   • "tilt"           - Tilt cursor based on horizontal velocity (air drag)
--   • "rotate"         - Rotate cursor along direction of movement
--   • "none"           - Standard static cursor

DYNAMIC_CURSORS_ENABLED = true -- Master toggle: true / false
DYNAMIC_CURSORS_MODE = "stretch" -- "stretch" | "tilt" | "rotate" | "none"

-- Stretch speed limit (px/s required to reach 2x cursor stretch):
-- Lower = more stretchy/reactive (e.g. 1500), Higher = subtle/stiff (e.g. 4500). Default: 3000
DYNAMIC_CURSORS_STRETCH_LIMIT = 3000

-- Shake to Find (macOS-style mouse cursor magnification when wiggled):
DYNAMIC_CURSORS_SHAKE_ENABLED = true -- Toggle shake magnification: true / false
DYNAMIC_CURSORS_SHAKE_BASE = 4.0 -- Initial magnification scale (range: 2.0 - 8.0, default: 4.0)
DYNAMIC_CURSORS_SHAKE_SENSITIVITY = 6.0 -- Sensitivity threshold (lower = triggers sooner, default: 6.0)

-- =============================================================================
-- 3. HYPRFOCUS (Active Window Focus Pulse Animation)
-- =============================================================================
-- Focus animation styles:
--   • "flash"          - Window dips opacity and springs back (Flashfocus-style)
--   • "shrink"         - Window briefly shrinks inward and pops back like an elastic snap

HYPRFOCUS_ENABLED = true -- Master toggle: true / false
HYPRFOCUS_ANIMATION = "flash" -- "flash" | "shrink"
HYPRFOCUS_FLASH_OPACITY = 0.8 -- Opacity during flash dip (0.1 = intense, 0.8 = subtle, default: 0.35)
HYPRFOCUS_SHRINK_SCALE = 0.88 -- Scale during shrink pop (0.75 = large bounce, 0.95 = tiny twitch, default: 0.88)

-- =============================================================================
-- 4. SCROLL OVERVIEW (Niri-Style Horizontal Ribbon)
-- =============================================================================
-- Toggled with SUPER + TAB (panning along workspace filmstrip)

SCROLLOVERVIEW_SCALE = 0.55 -- Overview thumbnail scale factor (range: 0.35 - 0.80, default: 0.55)
SCROLLOVERVIEW_GAP = 48 -- Gap in pixels between workspace cards (range: 16 - 96, default: 48)
SCROLLOVERVIEW_LAYOUT = "vertical" -- Ribbon orientation: "vertical" | "horizontal" (matches WORKSPACE_ORIENTATION)
SCROLLOVERVIEW_BLUR = true -- Blur wallpaper background under overview: true / false
