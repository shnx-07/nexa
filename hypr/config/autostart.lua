-- ============================================================
-- NEXA / Hyprland Autostart Services & Daemons
-- ============================================================
-- All session daemons, single-instance verification, and staged
-- boot sequencing are managed by the compiled Rust subsystem
-- (nexad hypr autostart run).
--
-- To inspect or modify autostart services, see:
--   ~/.config/nexa/rust/src/hyprland/autostart.rs
--
-- Status & Health:
--   nexad hypr autostart status
-- ============================================================

local nexad = (os.getenv("HOME") or "") .. "/.config/nexa/rust/target/release/nexad"
hl.on("hyprland.start", function()
	hl.exec_cmd(nexad .. " hypr autostart run")
end)
