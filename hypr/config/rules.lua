-- ============================================================
-- NEXA / Hyprland Window & Layer Rules
-- ============================================================
-- All window, modal, PiP, scratchpad, opacity & layer rules
-- are managed and validated by the compiled Rust subsystem
-- (nexad hypr rules sync).
--
-- To inspect or modify rules, see:
--   ~/.config/nexa/rust/src/hyprland/rules.rs
--
-- CLI manual sync:
--   nexad hypr rules sync
-- ============================================================

local nexad = (os.getenv("HOME") or "") .. "/.config/nexa/rust/target/release/nexad"
hl.exec_cmd(nexad .. " hypr rules sync")
