pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ============================================================
    // OPTICS & LIQUID GLASS PROPERTIES (Live watched from settings configs)
    // ============================================================
    property bool glassMode: false
    property bool specularHighlight: true
    property real specularIntensity: 0.28
    property bool surface3DGradient: true
    property real gradientIntensity: 1.0
    property bool contactShadow: true
    property real shadowBlurFactor: 0.75

    property string activeShader: "none"
    property real shaderSpeed: 1.0
    property real shaderIntensity: 1.0
    property real shaderOpacity: 0.85
    property real shaderContrastVeil: 0.30
    property var shaderPresets: ({})
    property real globalShaderTime: 0.0

    readonly property string activeShaderFile: {
        if (!root.activeShader || root.activeShader === "off" || root.activeShader === "none") return "";
        if (root.shaderPresets && root.shaderPresets[root.activeShader] && root.shaderPresets[root.activeShader].file) {
            return root.shaderPresets[root.activeShader].file;
        }
        return "theme/glass_liquid.frag.qsb";
    }

    readonly property url activeShaderUrl: {
        if (!activeShaderFile) return "";
        return Qt.resolvedUrl("../../shaders/" + activeShaderFile);
    }

    property var _shaderClock: FrameAnimation {
        running: root.activeShader !== "off" && root.activeShader !== "none"
        onTriggered: {
            root.globalShaderTime += frameTime * 1000.0;
        }
    }

    property FileView _glassWatcher: FileView {
        path: Quickshell.env("HOME") + "/.config/nexa/config/glass.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const txt = text().trim().toLowerCase()
                root.glassMode = (txt === "true" || txt === "1")
            } catch (e) {}
        }
    }

    property FileView _opticsWatcher: FileView {
        path: Quickshell.env("HOME") + "/.config/nexa/config/shapes.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text())
                if (data) {
                    if (data.specular_highlight !== undefined) root.specularHighlight = data.specular_highlight
                    if (data.specular_intensity !== undefined) root.specularIntensity = data.specular_intensity
                    if (data.surface_gradient !== undefined) root.surface3DGradient = data.surface_gradient
                    if (data.gradient_intensity !== undefined) root.gradientIntensity = data.gradient_intensity
                    if (data.contact_shadow !== undefined) root.contactShadow = data.contact_shadow
                    if (data.shadow_blur !== undefined) root.shadowBlurFactor = data.shadow_blur
                }
            } catch (e) {}
        }
    }

    property FileView _shadersWatcher: FileView {
        path: Quickshell.env("HOME") + "/.config/nexa/config/shaders.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text())
                if (data) {
                    if (data.active !== undefined) root.activeShader = data.active
                    else if (data.activeShader !== undefined) root.activeShader = data.activeShader
                    if (data.opacity !== undefined) root.shaderOpacity = data.opacity
                    if (data.speed !== undefined) root.shaderSpeed = data.speed
                    else if (data.shaderSpeed !== undefined) root.shaderSpeed = data.shaderSpeed
                    if (data.intensity !== undefined) root.shaderIntensity = data.intensity
                    else if (data.shaderIntensity !== undefined) root.shaderIntensity = data.shaderIntensity
                    if (data.contrast_veil !== undefined) root.shaderContrastVeil = data.contrast_veil
                    if (data.pause_when_hidden !== undefined) root.shaderPauseWhenHidden = data.pause_when_hidden
                    if (data.presets !== undefined) root.shaderPresets = data.presets
                }
            } catch (e) {}
        }
    }

    property bool shaderPauseWhenHidden: false

    Component.onCompleted: {
        _glassWatcher.reload();
        _opticsWatcher.reload();
        _shadersWatcher.reload();
    }

    function setGlassMode(enabled) {
        root.glassMode = enabled;
        Quickshell.execDetached([
            "sh", "-c",
            "mkdir -p \"$HOME/.config/nexa/config\" && printf '%s\\n' \"$1\" > \"$HOME/.config/nexa/config/glass.conf\" && if [ \"$1\" = \"true\" ]; then hyprpm enable hyprglass 2>/dev/null || true; else hyprpm disable hyprglass 2>/dev/null || true; fi; hyprpm reload 2>/dev/null || true; hyprctl reload 2>/dev/null || true",
            "sh", enabled ? "true" : "false"
        ]);
    }

    readonly property var shaderList: {
        const list = [];
        if (!root.shaderPresets) return list;
        const keys = Object.keys(root.shaderPresets);
        for (let i = 0; i < keys.length; ++i) {
            const k = keys[i];
            if (k === "off" || k === "none") continue;
            const item = root.shaderPresets[k];
            list.push({
                id: k,
                name: item.name || k,
                subtitle: item.subtitle || "Shader Effect",
                icon: item.icon || "󰄛",
                file: item.file || ""
            });
        }
        return list;
    }

    function shaderName(id) {
        if (!id || id === "off" || id === "none") return "Default (Off)";
        if (root.shaderPresets && root.shaderPresets[id] && root.shaderPresets[id].name) {
            return root.shaderPresets[id].name;
        }
        for (let i = 0; i < shaderList.length; i++) {
            if (shaderList[i].id === id) return shaderList[i].name;
        }
        return id;
    }

    property string _previousShader: "liquid_glass"

    function setShader(id) {
        root.activeShader = id;
        saveShaderConfig();
    }

    function toggleShader() {
        if (root.activeShader !== "off" && root.activeShader !== "none") {
            root._previousShader = root.activeShader;
            setShader("off");
        } else {
            setShader(root._previousShader || "liquid_glass");
        }
    }

    function saveShaderConfig() {
        const cfg = {
            "activeShader": root.activeShader,
            "active": root.activeShader,
            "opacity": root.shaderOpacity,
            "shaderSpeed": root.shaderSpeed,
            "speed": root.shaderSpeed,
            "shaderIntensity": root.shaderIntensity,
            "intensity": root.shaderIntensity,
            "contrast_veil": root.shaderContrastVeil,
            "pause_when_hidden": root.shaderPauseWhenHidden,
            "presets": root.shaderPresets
        };
        const json = JSON.stringify(cfg, null, 2);
        Quickshell.execDetached([
            "sh", "-c",
            'mkdir -p "$HOME/.config/nexa/config" && printf "%s" "$1" > "$HOME/.config/nexa/config/shaders.json"',
            "sh",
            json
        ]);
    }

    // Direct configuration save helper
    function saveOpticsConfig(specularOn, specularInt, gradientOn, gradientInt, shadowOn, shadowBlur) {
        root.specularHighlight = specularOn;
        root.specularIntensity = specularInt;
        root.surface3DGradient = gradientOn;
        root.gradientIntensity = gradientInt;
        root.contactShadow = shadowOn;
        root.shadowBlurFactor = shadowBlur;

        let existing = {};
        try {
            existing = JSON.parse(root._opticsWatcher.text() || "{}");
        } catch (e) {}

        existing.specular_highlight = specularOn;
        existing.specular_intensity = specularInt;
        existing.surface_gradient = gradientOn;
        existing.gradient_intensity = gradientInt;
        existing.contact_shadow = shadowOn;
        existing.shadow_blur = shadowBlur;

        const json = JSON.stringify(existing, null, 2);
        Quickshell.execDetached([
            "sh", "-c",
            'mkdir -p "$HOME/.config/nexa/config" && printf "%s" "$1" > "$HOME/.config/nexa/config/shapes.json"',
            "sh",
            json
        ]);
    }
}
