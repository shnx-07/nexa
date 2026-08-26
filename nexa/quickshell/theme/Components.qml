pragma Singleton

import QtQuick
import QtQuick.Layouts

import "." as Nexa


QtObject {
    id: root


    // ============================================================
    // NEXA COMPONENTS
    //
    // Shared visual primitives for the whole shell.
    //
    // Theme.qml:
    //     owns colors, dimensions, timing and design tokens.
    //
    // Components.qml:
    //     owns reusable visual behavior built from those tokens.
    //
    // IMPORTANT:
    //     Keep backend/state logic OUT of this file.
    //
    // Components should know things such as:
    //     - hover
    //     - pressed
    //     - selected
    //     - animation
    //     - visual hierarchy
    //
    // They should NOT know things such as:
    //     - Wi-Fi state
    //     - Bluetooth commands
    //     - volume backend
    //     - weather backend
    //     - Rust processes
    //
    // Individual modules provide their own state and actions.
    // ============================================================



    // ============================================================
    // ANIMATED CARD
    //
    // Generic interactive card.
    //
    // Good for:
    //     Quick Settings tiles
    //     clickable information cards
    //     selectable options
    //     launcher items
    //
    // Not recommended for:
    //     entire large panels
    //     static layout containers
    // ============================================================

    component AnimatedCard: Rectangle {
        id: card


        // --------------------------------------------------------
        // STATE
        // --------------------------------------------------------

        property bool selected: false
        property bool interactive: true

        property bool hovered:
            interactive
            && cardMouse.containsMouse

        property bool pressedState:
            interactive
            && cardMouse.pressed


        // --------------------------------------------------------
        // APPEARANCE OVERRIDES
        //
        // Modules can override these when necessary without
        // replacing the interaction logic.
        // --------------------------------------------------------

        property color normalColor:
            Nexa.Theme.interactiveCard

        property color hoverColor:
            Nexa.Theme.interactiveCardHover

        property color pressedColor:
            Nexa.Theme.interactiveCardPressed

        property color selectedColor:
            Nexa.Theme.selectedSurface

        property color normalBorder:
            Nexa.Theme.border

        property color selectedBorder:
            Nexa.Theme.selectedBorder


        // --------------------------------------------------------
        // SIGNALS
        // --------------------------------------------------------

        signal clicked()
        signal rightClicked()


        // --------------------------------------------------------
        // VISUAL
        // --------------------------------------------------------

        radius:
            Nexa.Theme.radiusLg

        border.width:
            Nexa.Theme.borderThin

        border.color:
            selected
            ? selectedBorder
            : normalBorder


        color:
            selected
            ? selectedColor
            : pressedState
                ? pressedColor
                : hovered
                    ? hoverColor
                    : normalColor


        scale:
            pressedState
            ? Nexa.Theme.cardPressScale
            : hovered
                ? Nexa.Theme.cardHoverScale
                : Nexa.Theme.normalScale


        // --------------------------------------------------------
        // MOTION
        // --------------------------------------------------------

        Behavior on color {
            ColorAnimation {
                duration:
                    Nexa.Theme.motionInteraction
            }
        }


        Behavior on border.color {
            ColorAnimation {
                duration:
                    Nexa.Theme.motionInteraction
            }
        }


        Behavior on scale {
            NumberAnimation {
                duration:
                    Nexa.Theme.motionInteraction

                easing.type:
                    Nexa.Theme.easingStandard
            }
        }


        // --------------------------------------------------------
        // INPUT
        // --------------------------------------------------------

        MouseArea {
            id: cardMouse

            anchors.fill:
                parent

            enabled:
                card.interactive

            hoverEnabled:
                true

            acceptedButtons:
                Qt.LeftButton
                | Qt.RightButton

            cursorShape:
                card.interactive
                ? Qt.PointingHandCursor
                : Qt.ArrowCursor


            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    card.rightClicked()
                else
                    card.clicked()
            }
        }
    }



    // ============================================================
    // ANIMATED BUTTON
    //
    // Smaller and slightly more expressive than AnimatedCard.
    //
    // Good for:
    //     icon buttons
    //     action buttons
    //     small controls
    //     toolbar buttons
    // ============================================================

    component AnimatedButton: Rectangle {
        id: button


        property bool selected: false
        property bool interactive: true

        property bool hovered:
            interactive
            && buttonMouse.containsMouse

        property bool pressedState:
            interactive
            && buttonMouse.pressed


        property color normalColor:
            Nexa.Theme.buttonBackground

        property color hoverColor:
            Nexa.Theme.buttonBackgroundHover

        property color pressedColor:
            Nexa.Theme.buttonBackgroundPressed

        property color selectedColor:
            Nexa.Theme.selectedSurface


        signal clicked()


        radius:
            Nexa.Theme.radiusMd

        border.width:
            Nexa.Theme.borderThin

        border.color:
            selected
            ? Nexa.Theme.selectedBorder
            : Nexa.Theme.border


        color:
            selected
            ? selectedColor
            : pressedState
                ? pressedColor
                : hovered
                    ? hoverColor
                    : normalColor


        scale:
            pressedState
            ? Nexa.Theme.pressScale
            : hovered
                ? Nexa.Theme.hoverScale
                : Nexa.Theme.normalScale


        Behavior on color {
            ColorAnimation {
                duration:
                    Nexa.Theme.motionInteraction
            }
        }


        Behavior on border.color {
            ColorAnimation {
                duration:
                    Nexa.Theme.motionInteraction
            }
        }


        Behavior on scale {
            NumberAnimation {
                duration:
                    Nexa.Theme.motionInteraction

                easing.type:
                    Nexa.Theme.easingStandard
            }
        }


        MouseArea {
            id: buttonMouse

            anchors.fill:
                parent

            enabled:
                button.interactive

            hoverEnabled:
                true

            cursorShape:
                button.interactive
                ? Qt.PointingHandCursor
                : Qt.ArrowCursor

            onClicked:
                button.clicked()
        }
    }



    // ============================================================
    // ICON BUTTON
    //
    // Compact control with a Nerd Font icon.
    //
    // Example uses:
    //     refresh
    //     mute
    //     expand
    //     close
    //     settings
    // ============================================================

    component IconButton: Rectangle {
        id: iconButton


        property string icon: ""

        property bool selected: false
        property bool interactive: true

        property color iconColor:
            selected
            ? Nexa.Theme.primary
            : Nexa.Theme.mutedText

        property int iconSize:
            Nexa.Theme.iconSm


        signal clicked()


        implicitWidth:
            Nexa.Theme.controlHeightMd

        implicitHeight:
            Nexa.Theme.controlHeightMd


        radius:
            Nexa.Theme.radiusMd


        color:
            selected
            ? Nexa.Theme.selectedSurface
            : iconMouse.pressed
                ? Nexa.Theme.pressed
                : iconMouse.containsMouse
                    ? Nexa.Theme.hoverStrong
                    : "transparent"


        border.width:
            selected
            ? Nexa.Theme.borderThin
            : 0

        border.color:
            Nexa.Theme.selectedBorder


        scale:
            iconMouse.pressed
            ? Nexa.Theme.pressScale
            : iconMouse.containsMouse
                ? Nexa.Theme.hoverScale
                : Nexa.Theme.normalScale


        Text {
            anchors.centerIn:
                parent

            text:
                iconButton.icon

            color:
                iconButton.iconColor

            font.family:
                Nexa.Theme.iconFontFamily

            font.pixelSize:
                iconButton.iconSize
        }


        Behavior on color {
            ColorAnimation {
                duration:
                    Nexa.Theme.motionInteraction
            }
        }


        Behavior on scale {
            NumberAnimation {
                duration:
                    Nexa.Theme.motionInteraction

                easing.type:
                    Nexa.Theme.easingStandard
            }
        }


        MouseArea {
            id: iconMouse

            anchors.fill:
                parent

            enabled:
                iconButton.interactive

            hoverEnabled:
                true

            cursorShape:
                iconButton.interactive
                ? Qt.PointingHandCursor
                : Qt.ArrowCursor

            onClicked:
                iconButton.clicked()
        }
    }



    // ============================================================
    // SECTION TITLE
    //
    // Consistent heading used above sections/cards.
    // ============================================================

    component SectionTitle: RowLayout {
        id: sectionTitle


        property string icon: ""
        property string text: ""
        property string description: ""

        property color accentColor:
            Nexa.Theme.primary


        spacing:
            Nexa.Theme.spacingSm


        Text {
            visible:
                sectionTitle.icon !== ""

            text:
                sectionTitle.icon

            color:
                sectionTitle.accentColor

            font.family:
                Nexa.Theme.iconFontFamily

            font.pixelSize:
                Nexa.Theme.iconSm
        }


        ColumnLayout {
            Layout.fillWidth:
                true

            spacing:
                0


            Text {
                text:
                    sectionTitle.text

                color:
                    Nexa.Theme.text

                font.family:
                    Nexa.Theme.fontFamily

                font.pixelSize:
                    Nexa.Theme.fontSizeSm

                font.weight:
                    Nexa.Theme.fontWeightDemiBold
            }


            Text {
                visible:
                    sectionTitle.description !== ""

                text:
                    sectionTitle.description

                color:
                    Nexa.Theme.mutedText

                font.family:
                    Nexa.Theme.fontFamily

                font.pixelSize:
                    Nexa.Theme.fontSize2Xs
            }
        }
    }



    // ============================================================
    // STATUS DOT
    //
    // Small animated active/inactive indicator.
    //
    // Example:
    //     Wi-Fi connected
    //     Bluetooth active
    //     recording
    //     VPN connected
    // ============================================================

    component StatusDot: Rectangle {
        id: statusDot


        property bool active: false

        property color activeColor:
            Nexa.Theme.primary

        property color inactiveColor:
            Nexa.Theme.mutedText


        implicitWidth: 7
        implicitHeight: 7

        radius:
            width / 2


        color:
            active
            ? activeColor
            : inactiveColor


        opacity:
            active
            ? Nexa.Theme.opacityFull
            : Nexa.Theme.opacitySecondary


        scale:
            active
            ? 1.0
            : 0.85


        Behavior on color {
            ColorAnimation {
                duration:
                    Nexa.Theme.motionInteraction
            }
        }


        Behavior on opacity {
            NumberAnimation {
                duration:
                    Nexa.Theme.motionInteraction
            }
        }


        Behavior on scale {
            NumberAnimation {
                duration:
                    Nexa.Theme.motionSelection

                easing.type:
                    Nexa.Theme.easingEmphasized
            }
        }
    }



    // ============================================================
    // ACCENT ICON CONTAINER
    //
    // Tinted icon background used for sections such as brightness,
    // audio, weather and system information.
    //
    // The caller chooses which accent family is appropriate.
    // ============================================================

    component AccentIcon: Rectangle {
        id: accentIcon


        property string icon: ""

        property color accent:
            Nexa.Theme.primary

        property color backgroundColor:
            Nexa.Theme.primarySurface

        property int iconSize:
            Nexa.Theme.iconMd


        implicitWidth:
            Nexa.Theme.controlHeightLg

        implicitHeight:
            Nexa.Theme.controlHeightLg


        radius:
            Nexa.Theme.radiusMd

        color:
            backgroundColor


        Text {
            anchors.centerIn:
                parent

            text:
                accentIcon.icon

            color:
                accentIcon.accent

            font.family:
                Nexa.Theme.iconFontFamily

            font.pixelSize:
                accentIcon.iconSize
        }
    }



    // ============================================================
    // SEGMENTED CONTROL
    //
    // Two-option selector with a moving active indicator.
    //
    // Great for:
    //     Daily / Hourly
    //     Grid / List
    //     On / Auto
    //
    // index:
    //     0 = first option
    //     1 = second option
    // ============================================================

    component SegmentedControl: Rectangle {
        id: segmented


        property string firstText: "First"
        property string secondText: "Second"

        property int currentIndex: 0


        signal selected(int index)


        implicitWidth: 150

        implicitHeight:
            Nexa.Theme.controlHeightMd


        radius:
            Nexa.Theme.radiusMd

        color:
            Nexa.Theme.surfaceContainerHigh


        border.width:
            Nexa.Theme.borderThin

        border.color:
            Nexa.Theme.border


        // --------------------------------------------------------
        // MOVING ACTIVE SURFACE
        // --------------------------------------------------------

        Rectangle {
            id: selectedBackground

            x:
                segmented.currentIndex === 0
                ? 2
                : segmented.width / 2

            y: 2

            width:
                segmented.width / 2 - 2

            height:
                segmented.height - 4


            radius:
                Nexa.Theme.radiusSm

            color:
                Nexa.Theme.selectedSurface


            border.width:
                Nexa.Theme.borderThin

            border.color:
                Nexa.Theme.selectedBorder


            Behavior on x {
                NumberAnimation {
                    duration:
                        Nexa.Theme.motionSelection

                    easing.type:
                        Nexa.Theme.easingEnter
                }
            }
        }


        Row {
            anchors.fill:
                parent


            Item {
                width:
                    parent.width / 2

                height:
                    parent.height


                Text {
                    anchors.centerIn:
                        parent

                    text:
                        segmented.firstText

                    color:
                        segmented.currentIndex === 0
                        ? Nexa.Theme.primary
                        : Nexa.Theme.mutedText

                    font.family:
                        Nexa.Theme.fontFamily

                    font.pixelSize:
                        Nexa.Theme.fontSizeXs

                    font.weight:
                        Nexa.Theme.fontWeightMedium

                    Behavior on color {
                        ColorAnimation {
                            duration:
                                Nexa.Theme.motionInteraction
                        }
                    }
                }


                MouseArea {
                    anchors.fill:
                        parent

                    hoverEnabled:
                        true

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked: {
                        if (segmented.currentIndex !== 0) {
                            segmented.currentIndex = 0
                            segmented.selected(0)
                        }
                    }
                }
            }


            Item {
                width:
                    parent.width / 2

                height:
                    parent.height


                Text {
                    anchors.centerIn:
                        parent

                    text:
                        segmented.secondText

                    color:
                        segmented.currentIndex === 1
                        ? Nexa.Theme.primary
                        : Nexa.Theme.mutedText

                    font.family:
                        Nexa.Theme.fontFamily

                    font.pixelSize:
                        Nexa.Theme.fontSizeXs

                    font.weight:
                        Nexa.Theme.fontWeightMedium

                    Behavior on color {
                        ColorAnimation {
                            duration:
                                Nexa.Theme.motionInteraction
                        }
                    }
                }


                MouseArea {
                    anchors.fill:
                        parent

                    hoverEnabled:
                        true

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked: {
                        if (segmented.currentIndex !== 1) {
                            segmented.currentIndex = 1
                            segmented.selected(1)
                        }
                    }
                }
            }
        }
    }



    // ============================================================
    // DIVIDER
    //
    // Standard subtle divider.
    // ============================================================

    component Divider: Rectangle {
        implicitHeight: 1

        color:
            Nexa.Theme.divider
    }



    // ============================================================
    // ACTIVE INDICATOR
    //
    // Small accent pill useful under navigation icons/tabs.
    //
    // Animate x/y from the parent when moving it between controls.
    // ============================================================

    component ActiveIndicator: Rectangle {
        implicitWidth: 18
        implicitHeight: 3

        radius:
            Nexa.Theme.radiusPill

        color:
            Nexa.Theme.primary


        Behavior on x {
            NumberAnimation {
                duration:
                    Nexa.Theme.motionSelection

                easing.type:
                    Nexa.Theme.easingEnter
            }
        }


        Behavior on y {
            NumberAnimation {
                duration:
                    Nexa.Theme.motionSelection

                easing.type:
                    Nexa.Theme.easingEnter
            }
        }


        Behavior on width {
            NumberAnimation {
                duration:
                    Nexa.Theme.motionSelection

                easing.type:
                    Nexa.Theme.easingStandard
            }
        }
    }
}
