-- ==============================================================================
-- NEXA Hyprland Dynamic Animations
-- ==============================================================================
-- Animations and easing curves are managed live by the NEXA Rust Backend.
-- Configure or change profiles anytime in: Settings -> Motion & Physics
-- Or via CLI: nexad hypr animations profile <name>
-- ==============================================================================

local nexad = (os.getenv("HOME") or "") .. "/.config/nexa/rust/target/release/nexad"

-- Automatically sync active animation profile from motion.json on boot/reload
if WORKSPACE_ORIENTATION == "vertical" then
	hl.exec_cmd(
		nexad
			.. " hypr animations sync && hyprctl repl 'hl.animation({ leaf = \"workspaces\", enabled = true, speed = 5.0, bezier = \"default\", style = \"slidevert\" }); hl.animation({ leaf = \"workspacesIn\", enabled = true, speed = 5.0, bezier = \"default\", style = \"slidevert\" }); hl.animation({ leaf = \"workspacesOut\", enabled = true, speed = 5.0, bezier = \"default\", style = \"slidevert\" })'"
	)
else
	hl.exec_cmd(nexad .. " hypr animations sync")
end
