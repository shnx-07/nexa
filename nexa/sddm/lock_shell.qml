import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import QtMultimedia
import "../quickshell/modules/sddm/shim"

ShellRoot {
    id: shellRoot

    property string activeTheme: Quickshell.env("QS_THEME") || "nier-automata"
    property string themePath: Quickshell.env("QS_THEME_PATH") || (Quickshell.shellDir + "/themes/" + activeTheme)

    readonly property var sddm: sddmShim.sddm
    readonly property var config: sddmShim.config
    readonly property var userModel: sddmShim.userModel
    readonly property var sessionModel: sddmShim.sessionModel
    readonly property bool isWayland: Quickshell.env("XDG_SESSION_TYPE") === "wayland"
    property bool authenticated: false
    property bool sessionLocked: true
    property bool isTesting: Quickshell.env("QS_TESTING") === "1"

    SddmShim {
        id: sddmShim
        themePath: shellRoot.themePath
    }

    Component.onCompleted: {
        // Pre-arm Hyprland lock restore if running on Hyprland
        if (Quickshell.env("XDG_CURRENT_DESKTOP") === "Hyprland" || Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== "") {
            Quickshell.execDetached(["hyprctl", "keyword", "misc:allow_session_lock_restore", "1"]);
        }
    }

    Connections {
        target: sddmShim.sddm
        function onLoginSucceeded() {
            shellRoot.authenticated = true
            Quickshell.execDetached(["loginctl", "unlock-session"]);

            // Dynamic exit delay
            let delay = 250;
            if (activeTheme.includes("clockwork") && sddmShim.config.enableWindup === "true") {
                delay = 500;
            }
            quitTimer.interval = delay;
            quitTimer.start();
        }
    }

    Timer {
        id: quitTimer
        interval: 300
        onTriggered: {
            shellRoot.sessionLocked = false;
            // Delay exit slightly to ensure compositor releases lock surface cleanly
            exitDelayTimer.start();
        }
    }

    Timer {
        id: exitDelayTimer
        interval: 150
        onTriggered: Qt.quit()
    }

    Component {
        id: themeComponent
        Loader {
            anchors.fill: parent
            source: "file://" + shellRoot.themePath + "/Main.qml"
            
            onLoaded: {
                if (item) {
                    item.forceActiveFocus();
                }
            }
            onStatusChanged: {
                if (status === Loader.Error) {
                    console.error("FAILED to load theme:", source);
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. TESTING / PREVIEW MODE (LayerShell Overlay - 100% crash-proof)
    // ─────────────────────────────────────────────────────────────────────────
    Loader {
        id: previewLoader
        active: shellRoot.isTesting && shellRoot.isWayland
        sourceComponent: Component {
            Variants {
                model: Quickshell.screens
                delegate: PanelWindow {
                    id: previewWindow
                    required property ShellScreen modelData
                    screen: modelData

                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.namespace: "quickshell:sddm-preview"
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                    exclusionMode: ExclusionMode.Ignore
                    anchors.top: true
                    anchors.bottom: true
                    anchors.left: true
                    anchors.right: true
                    color: "black"

                    Shortcut {
                        sequence: "Escape"
                        onActivated: Qt.quit()
                    }

                    Loader {
                        anchors.fill: parent
                        sourceComponent: themeComponent
                    }

                    // Top Banner: Preview Mode Header
                    Rectangle {
                        id: banner
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 18
                        height: 38
                        width: bannerRow.implicitWidth + 36
                        radius: 19
                        color: Qt.rgba(0.08, 0.09, 0.11, 0.90)
                        border.width: 1
                        border.color: shellRoot.authenticated ? "#4ade80" : Qt.rgba(1, 1, 1, 0.18)
                        z: 999999

                        RowLayout {
                            id: bannerRow
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                text: shellRoot.authenticated ? "󰄬" : "󱓞"
                                font.family: "Material Symbols Outlined, Symbols Nerd Font Mono, monospace"
                                font.pixelSize: 18
                                color: shellRoot.authenticated ? "#4ade80" : "#38bdf8"
                            }

                            Text {
                                text: shellRoot.authenticated 
                                    ? "Authenticated! Unlocking..." 
                                    : ("SDDM Preview: " + shellRoot.activeTheme + " • Press [Esc] to exit")
                                color: "white"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. REAL WAYLAND SESSION LOCK (Active ONLY when isTesting is false)
    // ─────────────────────────────────────────────────────────────────────────
    Loader {
        id: waylandLockLoader
        active: !shellRoot.isTesting && shellRoot.isWayland
        sourceComponent: Component {
            WlSessionLock {
                id: lock
                locked: shellRoot.sessionLocked
                surface: Component {
                    WlSessionLockSurface {
                        color: "black"
                        
                        // Absorb unhandled gestures
                        PinchHandler { target: null }
                        WheelHandler { target: null }
                        
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.AllButtons
                            hoverEnabled: true
                            onWheel: (wheel) => { wheel.accepted = true }
                        }

                        Loader {
                            anchors.fill: parent
                            sourceComponent: themeComponent
                        }
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. X11 FALLBACK WINDOW
    // ─────────────────────────────────────────────────────────────────────────
    Loader {
        id: x11Loader
        active: !shellRoot.isWayland
        sourceComponent: Component {
            Variants {
                model: Quickshell.screens
                delegate: Window {
                    id: window
                    required property var modelData
                    screen: modelData
                    width: isTesting ? 1280 : screen.width
                    height: isTesting ? 720 : screen.height
                    visible: shellRoot.sessionLocked
                    visibility: isTesting ? Window.Windowed : Window.FullScreen
                    
                    Shortcut {
                        sequence: "Escape"
                        onActivated: {
                            if (shellRoot.isTesting) Qt.quit();
                        }
                    }

                    onClosing: (close) => {
                        close.accepted = shellRoot.authenticated || shellRoot.isTesting;
                    }
                    
                    flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint | Qt.MaximizeUsingFullscreenGeometryHint
                    color: "black"

                    Loader {
                        anchors.fill: parent
                        sourceComponent: themeComponent
                    }
                }
            }
        }
    }
}
