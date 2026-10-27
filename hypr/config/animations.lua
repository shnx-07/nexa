-- ==============================================================================
-- NEXA Hyprland Dynamic Animations
-- ==============================================================================
-- Animations and easing curves are managed live by the NEXA Rust Backend.
-- Configure or change profiles anytime in: Settings -> Motion & Physics
-- Or via CLI: nexad hypr animations profile <name>
-- ==============================================================================

local nexad = (os.getenv("HOME") or "") .. "/.config/nexa/rust/target/release/nexad"

-- Automatically sync active animation profile from motion.json on boot/reload
hl.exec_cmd(nexad .. " hypr animations sync")
