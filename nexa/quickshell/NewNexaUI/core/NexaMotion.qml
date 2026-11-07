pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ============================================================
    // MOTION & SPRING PHYSICS (Dynamically watched from motion.json)
    // ============================================================
    property bool enabled: true
    property string physicsEngine: "fluid"
    property real physicsResponse: 0.44
    property real physicsDamping: 0.86
    property real animationSpeed: 1.0

    property bool springEnabled: physicsEngine === "fluid" && enabled
    property real springStiffness: 3.8
    property real springDamping: 0.28
    property real springMass: 1.0
    property string preset: "fluid"
    property string hyprAnimationProfile: "slidefade"

    // Backward-compatibility and convenience aliases
    readonly property alias islandSpringStiffness: root.springStiffness
    readonly property alias islandSpringDamping: root.springDamping
    readonly property alias islandSpringMass: root.springMass
    readonly property alias springPreset: root.preset
    readonly property alias motionSections: root.sections

    property var sections: ({
        "island": true,
        "popups": true,
        "clipboard": true,
        "settings": true,
        "wallpaper": true,
        "workspace": true,
        "sliders": true
    })

    function useSpring(sectionName) {
        if (!root.enabled || !root.springEnabled) return false;
        if (sectionName && root.sections && root.sections[sectionName] !== undefined) {
            return root.sections[sectionName];
        }
        return root.springEnabled;
    }

    property FileView _motionWatcher: FileView {
        path: Quickshell.env("HOME") + "/.config/nexa/config/motion.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text())
                if (data) {
                    if (data.enabled !== undefined) root.enabled = data.enabled
                    if (data.physicsEngine !== undefined) root.physicsEngine = data.physicsEngine
                    if (data.physicsResponse !== undefined) root.physicsResponse = data.physicsResponse
                    if (data.physicsDamping !== undefined) root.physicsDamping = data.physicsDamping
                    if (data.animationSpeed !== undefined) root.animationSpeed = data.animationSpeed
                    if (data.stiffness !== undefined) root.springStiffness = data.stiffness
                    if (data.damping !== undefined) root.springDamping = data.damping
                    if (data.mass !== undefined) root.springMass = data.mass
                    if (data.preset !== undefined) root.preset = data.preset
                    if (data.hyprAnimationProfile !== undefined) root.hyprAnimationProfile = data.hyprAnimationProfile
                    if (data.sections !== undefined) root.sections = data.sections
                }
            } catch (e) {}
        }
    }

    // Dynamic Scaled Durations (Auto-scales with animationSpeed setting)
    readonly property real effectiveSpeed: Math.max(0.2, root.animationSpeed)
    readonly property int durationInstant: Math.max(16, Math.round(100 / effectiveSpeed))
    readonly property int durationFast: Math.max(30, Math.round(200 / effectiveSpeed))
    readonly property int durationNormal: Math.max(50, Math.round(320 / effectiveSpeed))
    readonly property int durationSlow: Math.max(80, Math.round(480 / effectiveSpeed))
    readonly property int durationLayout: Math.max(100, Math.round(550 / effectiveSpeed))

    // Motion Spring Shortcuts
    readonly property real effectiveSpring: root.springStiffness
    readonly property real effectiveDamping: root.springDamping
    readonly property real effectiveMass: root.springMass

    // Motion Easing Curves
    readonly property int standardEasing: Easing.InOutQuad
    readonly property int decelerateEasing: Easing.OutCubic
    readonly property int accelerationEasing: Easing.InCubic
    readonly property int emphasizedEasing: Easing.OutCubic

    // Backward-compatible naming aliases
    readonly property int easingStandard: root.standardEasing
    readonly property int easingDecelerate: root.decelerateEasing
    readonly property int easingAccelerate: root.accelerationEasing
    readonly property int easingEmphasized: root.emphasizedEasing
    readonly property int exitEasing: root.accelerationEasing
    readonly property bool reducedMotion: !root.enabled

    // Interactive scale feedback
    readonly property real scalePress: 0.96
    readonly property real scaleHover: 1.02
    readonly property real scaleFocus: 1.025
    readonly property real scalePill: 1.04
    readonly property real pressScale: 0.96
    readonly property real hoverScale: 1.02

    // ============================================================
    // SECTION-AWARE PHYSICS HELPERS & TUNED DYNAMICS
    // ============================================================
    // Dynamic stiffness/damping resolvers per section
    function stiffnessFor(sectionName) {
        if (!root.enabled) return 8.0;
        if (!root.useSpring(sectionName)) return 8.0 * root.effectiveSpeed;
        return root.springStiffness * root.effectiveSpeed;
    }

    function dampingFor(sectionName) {
        if (!root.enabled || !root.useSpring(sectionName)) return 1.0; // Critically damped = 0 bounce
        return root.springDamping;
    }

    // Dynamic scaled duration helper for any base duration in ms
    function duration(baseMs) {
        return Math.max(16, Math.round(baseMs / root.effectiveSpeed));
    }

    // Tuned dynamics for Navigation / Tab selection / Arrow key movements
    readonly property real navSpringStiffness: stiffnessFor("settings")
    readonly property real navSpringDamping: dampingFor("settings")

    // Tuned dynamics for System Popups (WiFi, Battery, Bluetooth, Power)
    readonly property real popupSpringStiffness: stiffnessFor("popups")
    readonly property real popupSpringDamping: dampingFor("popups")

    // Tuned dynamics for Modals & Clipboard
    readonly property real modalSpringStiffness: stiffnessFor("clipboard")
    readonly property real modalSpringDamping: dampingFor("clipboard")

    // Tuned dynamics for Sliders & Toggles
    readonly property real controlSpringStiffness: stiffnessFor("sliders")
    readonly property real controlSpringDamping: dampingFor("sliders")

    // ============================================================
    // MOTION CONFIG PERSISTENCE & ACTIONS
    // ============================================================
    function _writeMotionJson(cfg) {
        const json = JSON.stringify(cfg, null, 2);
        Quickshell.execDetached([
            "sh", "-c",
            'mkdir -p "$HOME/.config/nexa/config" && printf "%s" "$1" > "$HOME/.config/nexa/config/motion.json"',
            "sh",
            json
        ]);
    }

    function savePhysicsEngine(engine, response, damping, presetName) {
        root.physicsEngine = engine;
        root.physicsResponse = response;
        root.physicsDamping = damping;
        root.springEnabled = (engine === "fluid" && root.enabled);
        if (presetName !== undefined && presetName !== "") {
            root.preset = presetName;
        }

        // Calculate dynamic stiffness and damping from response and damping
        root.springStiffness = Math.max(1.5, Math.min(12.0, +(0.74 / (response * response)).toFixed(2)));
        root.springDamping = Math.max(0.1, Math.min(1.0, +(damping * 0.33).toFixed(2)));

        const cfg = {
            "enabled": root.enabled,
            "physicsEngine": engine,
            "physicsResponse": response,
            "physicsDamping": damping,
            "animationSpeed": root.animationSpeed,
            "preset": root.preset,
            "hyprAnimationProfile": root.hyprAnimationProfile,
            "stiffness": root.springStiffness,
            "damping": root.springDamping,
            "mass": root.springMass,
            "sections": root.sections
        };
        root._writeMotionJson(cfg);
    }

    function saveMotionConfig(stiffness, damping, mass, presetName, isEnabled, newSections) {
        root.springStiffness = stiffness;
        root.springDamping = damping;
        root.springMass = mass;
        if (presetName !== undefined && presetName !== "") root.preset = presetName;
        if (isEnabled !== undefined) {
            root.enabled = isEnabled;
            root.springEnabled = (root.physicsEngine === "fluid" && isEnabled);
        }
        if (newSections !== undefined) root.sections = newSections;

        const cfg = {
            "enabled": root.enabled,
            "physicsEngine": root.physicsEngine,
            "physicsResponse": root.physicsResponse,
            "physicsDamping": root.physicsDamping,
            "animationSpeed": root.animationSpeed,
            "preset": root.preset,
            "hyprAnimationProfile": root.hyprAnimationProfile,
            "stiffness": stiffness,
            "damping": damping,
            "mass": mass,
            "sections": root.sections
        };
        root._writeMotionJson(cfg);
    }

    function setAnimationSpeed(speed) {
        root.animationSpeed = Math.max(0.2, Math.min(3.0, speed));
        const cfg = {
            "enabled": root.enabled,
            "physicsEngine": root.physicsEngine,
            "physicsResponse": root.physicsResponse,
            "physicsDamping": root.physicsDamping,
            "animationSpeed": root.animationSpeed,
            "preset": root.preset,
            "hyprAnimationProfile": root.hyprAnimationProfile,
            "stiffness": root.springStiffness,
            "damping": root.springDamping,
            "mass": root.springMass,
            "sections": root.sections
        };
        root._writeMotionJson(cfg);
    }

    function saveHyprAnimationProfile(profileId) {
        root.hyprAnimationProfile = profileId;
        const cfg = {
            "enabled": root.enabled,
            "physicsEngine": root.physicsEngine,
            "physicsResponse": root.physicsResponse,
            "physicsDamping": root.physicsDamping,
            "animationSpeed": root.animationSpeed,
            "preset": root.preset,
            "hyprAnimationProfile": profileId,
            "stiffness": root.springStiffness,
            "damping": root.springDamping,
            "mass": root.springMass,
            "sections": root.sections
        };
        root._writeMotionJson(cfg);
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad",
            "hypr",
            "animations",
            "profile",
            profileId
        ]);
    }
}
