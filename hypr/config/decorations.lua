-- ============================================================
-- NEXA / Hyprland Visual Decorations & Shapes
-- ============================================================
-- All window geometry, radii, borders, drop shadows, blur, and
-- dimming are managed by the compiled Rust subsystem
-- (nexad hypr decorations sync).
--
-- To inspect or modify decorations, see:
--   ~/.config/nexa/rust/src/hyprland/decorations.rs
--
-- CLI manual sync:
--   nexad hypr decorations sync
-- ============================================================

local nexad = (os.getenv("HOME") or "") .. "/.config/nexa/rust/target/release/nexad"
hl.exec_cmd(nexad .. " hypr decorations sync")
