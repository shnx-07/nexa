-- Autostart Services & Daemons

hl.on("hyprland.start", function()
	-- NEXA / Quickshell
	hl.exec_cmd("quickshell -p ~/.config/nexa/quickshell/shell.qml")

	-- Wallpaper daemon
	hl.exec_cmd("awww-daemon")

	-- give awww a moment to create its socket, then restore
	hl.exec_cmd("sleep 1 && ~/.config/nexa/scripts/restore-wallpaper.sh")

	hl.exec_cmd("playerctld daemon")

	hl.exec_cmd("systemctl --user start plasma-polkit-agent.service")

	hl.exec_cmd("wl-paste --type text --watch cliphist store")

	hl.exec_cmd("wl-paste --type image --watch cliphist store")

	hl.exec_cmd("hyprpm reload")

	hl.exec_cmd("hypridle")
end)
