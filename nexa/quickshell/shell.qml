//@ pragma IconTheme "breeze-dark"
import Quickshell
import Quickshell.Io
import "wallpaper" as Wallpaper
import "bar"
import "island"
import "modules/clipboard" as Clipboard
import "modules/lockscreen" as LockScreenModule
import "panel" as Panel
import "modules/workspace" as WorkspaceModule
ShellRoot {

    Process {
        id: notificationDaemonStartup

        command: [
            "sh",
            "-c",
            "busctl --user status org.freedesktop.Notifications >/dev/null 2>&1 "
            + "|| exec \"$HOME/.config/nexa/rust/target/release/nexad\" notifications daemon"
        ]

        running: true
    }
   
    WorkspaceModule.WorkspaceManager {
        id: workspaceManager
    }
    

    TopBar {}

    Island {}

    Panel.SidePanel {}

    Wallpaper.WallpaperView {
        id: wallpaperView
    }

    Clipboard.Clipboard {
        id: clipboard
    }

    LockScreenModule.LockScreen {}
}
