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