-- ============================================================
-- WORKSPACE RULES
-- ============================================================

-- Persistent workspaces 1 through 5 on whichever monitor is currently active
for i = 1, (NUM_WORKSPACES or 5) do
	hl.workspace_rule({
		workspace = tostring(i),
		persistent = true,
		default = (i == 1),
	})
end

-- ============================================================
-- WORKSPACE TRANSITION ANIMATIONS
-- ============================================================
-- Orientation is controlled via WORKSPACE_ORIENTATION in variables.lua
if (WORKSPACE_ORIENTATION or "horizontal") == "vertical" then
	hl.config({
		animations = {
			animation = {
				"workspaces, 1, 5, default, slidevert",
				"workspacesIn, 1, 5, default, slidevert",
				"workspacesOut, 1, 5, default, slidevert",
			},
		},
	})
	if hl.animation then
		hl.animation({ leaf = "workspaces", enabled = true, speed = 5.0, bezier = "default", style = "slidevert" })
		hl.animation({ leaf = "workspacesIn", enabled = true, speed = 5.0, bezier = "default", style = "slidevert" })
		hl.animation({ leaf = "workspacesOut", enabled = true, speed = 5.0, bezier = "default", style = "slidevert" })
	end
else
	hl.config({
		animations = {
			animation = {
				"workspaces, 1, 5, default, slide",
				"workspacesIn, 1, 5, default, slide",
				"workspacesOut, 1, 5, default, slide",
			},
		},
	})
	if hl.animation then
		hl.animation({ leaf = "workspaces", enabled = true, speed = 5.0, bezier = "default", style = "slide" })
		hl.animation({ leaf = "workspacesIn", enabled = true, speed = 5.0, bezier = "default", style = "slide" })
		hl.animation({ leaf = "workspacesOut", enabled = true, speed = 5.0, bezier = "default", style = "slide" })
	end
end
