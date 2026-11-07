import QtQuick
import QtQuick.Layouts
import "../core" as Core

Rectangle {
    id: root

    // ============================================================
    // PROPERTIES & API
    // ============================================================
    property string text: ""
    property string icon: ""
    property string variant: (text.length === 0 && icon.length > 0) ? "icon" : "filled" // filled | tonal | outline | ghost | pill | icon
    property bool checkable: false
    property bool checked: false
    property bool selected: false
    property bool interactive: true
    enabled: interactive
    property bool loading: false
    property alias containsMouse: mouseArea.containsMouse
    property alias pressed: mouseArea.pressed
    readonly property bool hovered: interactive && mouseArea.containsMouse
    readonly property bool pressedState: interactive && mouseArea.pressed

    property int customRadius: -1
    property int customHeight: 0
    property int horizontalPadding: -1
    property int verticalPadding: -1
    property int iconSize: 0
    property color iconColor: "transparent"
    property string tooltip: ""
    property string alignment: "center" // "center" | "left" | "right"
    property alias cursorShape: mouseArea.cursorShape
    property alias acceptedButtons: mouseArea.acceptedButtons
    property alias mouseArea: mouseArea

    signal clicked()
    signal entered()
    signal exited()

    default property alias content: customContainer.data

    // Calculated layout metrics
    readonly property bool isIconOnly: variant === "icon" || (text.length === 0 && icon.length > 0)
    readonly property int effectiveHeight: customHeight > 0 ? customHeight : (isIconOnly ? Core.NexaTokens.controlHeightMd : (variant === "pill" ? 36 : 36))
    readonly property int effectiveRadius: {
        if (customRadius >= 0) return customRadius;
        if (isIconOnly) return Math.min(height / 2, Core.NexaTokens.radiusPill);
        if (variant === "pill") return Math.round(implicitHeight / 2);
        return Core.NexaTokens.radiusSm;
    }

    implicitWidth: {
        if (isIconOnly) return implicitHeight;
        var pad = horizontalPadding >= 0 ? (horizontalPadding * 2) : ((variant === "pill") ? 28 : 24);
        return Math.max(implicitHeight, contentRow.implicitWidth + pad);
    }
    implicitHeight: effectiveHeight
    radius: effectiveRadius
    antialiasing: true
    transformOrigin: Item.Center

    // ============================================================
    // VISUAL STYLING BY VARIANT
    // ============================================================
    readonly property bool isActive: (checkable && checked) || checked || selected
    readonly property bool isHovered: mouseArea.containsMouse && enabled
    readonly property bool isPressed: mouseArea.pressed && enabled

    // Background color
    color: {
        if (!enabled) return Core.NexaColors.alpha(Core.NexaColors.onSurface, 0.05);
        if (variant === "filled") {
            if (isPressed) return Core.NexaColors.pressOverlay(Core.NexaColors.primary);
            if (isHovered) return Core.NexaColors.alpha(Core.NexaColors.primary, 0.9);
            return Core.NexaColors.primary;
        } else if (variant === "tonal") {
            if (isActive) return Core.NexaColors.alpha(Core.NexaColors.primary, 0.18);
            if (isPressed) return Core.NexaColors.surfaceContainerHighest;
            if (isHovered) return Core.NexaColors.surfaceContainerHigh;
            return Core.NexaColors.surfaceContainer;
        } else if (variant === "outline") {
            if (isActive) return Core.NexaColors.alpha(Core.NexaColors.primary, 0.18);
            if (isPressed) return Core.NexaColors.alpha(Core.NexaColors.onSurface, 0.12);
            if (isHovered) return Core.NexaColors.alpha(Core.NexaColors.onSurface, 0.06);
            return "transparent";
        } else if (variant === "ghost") {
            if (isActive) return Core.NexaColors.alpha(Core.NexaColors.primary, 0.18);
            if (isPressed) return Core.NexaColors.alpha(Core.NexaColors.onSurface, 0.12);
            if (isHovered) return Core.NexaColors.alpha(Core.NexaColors.onSurface, 0.06);
            return "transparent";
        } else if (variant === "pill") {
            if (isActive) return Core.NexaColors.alpha(Core.NexaColors.primary, 0.22);
            if (isPressed) return Core.NexaColors.alpha(Core.NexaColors.onSurface, 0.14);
            if (isHovered) return Core.NexaColors.alpha(Core.NexaColors.onSurface, 0.08);
            return "transparent";
        } else if (variant === "icon") {
            if (isActive) return Core.NexaColors.primaryContainer;
            if (isPressed) return Core.NexaColors.surfaceContainerHighest;
            if (isHovered) return Core.NexaColors.surfaceContainerHigh;
            return "transparent";
        }
        return Core.NexaColors.surfaceContainer;
    }

    // Border styling
    border.width: {
        if (variant === "outline") return Core.NexaTokens.borderThin;
        if (variant === "pill") return isActive ? Core.NexaTokens.borderThin : 0;
        if (variant === "icon") return (isActive || isHovered) ? Core.NexaTokens.borderThin : 0;
        return 0;
    }
    border.color: {
        if (variant === "outline") {
            if (isActive) return Core.NexaColors.primary;
            if (isHovered) return Core.NexaColors.outline;
            return Core.NexaColors.outlineVariant;
        }
        if (variant === "pill") {
            if (isActive) return Core.NexaColors.alpha(Core.NexaColors.primary, 0.50);
            if (isHovered) return Core.NexaColors.borderStrong;
            return "transparent";
        }
        if (variant === "icon") {
            if (isActive) return Core.NexaColors.primary;
            if (isHovered) return Core.NexaColors.border;
            return "transparent";
        }
        return "transparent";
    }

    // Apple Tactile 4-stop Depth Micro-Gradient
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        visible: Core.NexaOptics.surface3DGradient && (root.variant === "filled" || root.isActive)
        opacity: Core.NexaOptics.gradientIntensity
        gradient: Gradient {
            GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.08) }
            GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.02) }
            GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.00) }
            GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.14) }
        }
    }

    // Specular top edge highlight for 3D depth (Layer 2 specular beam)
    Rectangle {
        id: specularChamfer
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.radius > 0 ? Math.max(0, parent.width - root.radius * 1.6) : parent.width
        height: 1
        visible: Core.NexaOptics.specularHighlight && (root.variant === "filled" || root.isActive || (root.isIconOnly && root.isHovered))
        opacity: Math.min(1.0, Core.NexaOptics.specularIntensity / 0.28)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.35) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ============================================================
    // CONTENT ITEM (Icon + Label)
    // ============================================================
    readonly property color contentColor: {
        if (!enabled) return Core.NexaColors.alpha(Core.NexaColors.onSurface, 0.38);
        if (variant === "pill" && root.isActive) return Core.NexaColors.primary;
        if (variant === "filled") return Core.NexaColors.onPrimary;
        if (variant === "icon") {
            if (root.iconColor !== "transparent" && String(root.iconColor) !== "#00000000") return root.iconColor;
            if (root.isActive) return Core.NexaColors.primary;
            if (root.isHovered) return Core.NexaColors.text;
            return Core.NexaColors.mutedText;
        }
        if (root.isActive) return Core.NexaColors.primary;
        if (root.isHovered) return Core.NexaColors.text;
        return Core.NexaColors.mutedText;
    }

    readonly property color effectiveIconColor: {
        if (root.iconColor !== "transparent" && String(root.iconColor) !== "#00000000") return root.iconColor;
        return root.contentColor;
    }

    Item {
        id: customContainer
        anchors.fill: parent
        z: 1
    }

    RowLayout {
        id: contentRow
        visible: customContainer.children.length === 0
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: alignment === "left" ? parent.left : undefined
        anchors.leftMargin: alignment === "left" ? 14 : 0
        anchors.horizontalCenter: alignment === "center" ? parent.horizontalCenter : undefined
        anchors.right: alignment === "right" ? parent.right : undefined
        anchors.rightMargin: alignment === "right" ? 14 : 0
        spacing: 8
        z: 1

        Text {
            id: iconItem
            visible: root.icon.length > 0 && !root.loading
            text: root.icon
            font.family: Core.NexaTypography.familyIcon
            font.pixelSize: root.iconSize > 0 ? root.iconSize : (root.isIconOnly ? Core.NexaTokens.iconSm : Core.NexaTypography.sizeMd)
            color: root.effectiveIconColor
            Layout.alignment: Qt.AlignVCenter

            Behavior on color {
                ColorAnimation { duration: Core.NexaMotion.durationInstant }
            }
        }

        Text {
            id: labelItem
            visible: root.text.length > 0 && !root.loading
            text: root.text
            font.family: Core.NexaTypography.familyBody
            font.pixelSize: Core.NexaTypography.sizeSm
            font.weight: root.isActive ? Core.NexaTypography.weightSemiBold : Core.NexaTypography.weightRegular
            color: root.contentColor
            Layout.alignment: Qt.AlignVCenter

            Behavior on color {
                ColorAnimation { duration: Core.NexaMotion.durationInstant }
            }
        }

        // Minimalist spinner for loading state
        Text {
            id: loadingSpinner
            visible: root.loading
            text: "󰑮"
            font.family: Core.NexaTypography.familyIcon
            font.pixelSize: Core.NexaTypography.sizeSm
            color: root.contentColor
            Layout.alignment: Qt.AlignVCenter

            RotationAnimator on rotation {
                running: root.loading
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 900
            }
        }
    }

    // ============================================================
    // BEHAVIORS & INTERACTION
    // ============================================================
    Behavior on color {
        ColorAnimation { duration: Core.NexaMotion.durationFast; easing.type: Easing.OutQuad }
    }
    Behavior on border.color {
        ColorAnimation { duration: Core.NexaMotion.durationFast; easing.type: Easing.OutQuad }
    }
    Behavior on scale {
        enabled: Core.NexaMotion.enabled
        SpringAnimation {
            spring: Core.NexaMotion.controlSpringStiffness * 3.5
            damping: Core.NexaMotion.controlSpringDamping
            mass: Core.NexaMotion.springMass
            epsilon: 0.002
        }
    }

    scale: isPressed ? Core.NexaMotion.scalePress : (isHovered ? Core.NexaMotion.scaleHover : 1.0)

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.checkable) root.checked = !root.checked;
            root.clicked();
        }
        onEntered: root.entered()
        onExited: root.exited()
    }
}
