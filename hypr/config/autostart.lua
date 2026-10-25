-- Autostart Services & Daemons

hl.on("hyprland.start", function()
	-- NEXA / Quickshell
	hl.exec_cmd("env QS_NO_RELOAD_POPUP=1 QT_IMAGEIO_MAXALLOC=1024 QML_DISABLE_DISK_CACHE=0 QSG_RENDER_LOOP=threaded quickshell -p ~/.config/nexa/quickshell/shell.qml")

	-- Wallpaper restoration (skwd-paper auto-launches on demand)
	hl.exec_cmd("~/.config/nexa/scripts/restore-wallpaper.sh")

	hl.exec_cmd("playerctld daemon")

	hl.exec_cmd("systemctl --user start plasma-polkit-agent.service")

	-- Clipboard history daemon with image size safety (prevents memory spikes)
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")

	hl.exec_cmd("hyprpm reload")

	hl.exec_cmd("hypridle")
end)
