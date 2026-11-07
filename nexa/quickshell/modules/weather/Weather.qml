import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

import "../../NewNexaUI" as NexaUI


Item {
    id: root

    // ============================================================
    // WEATHER STATE
    // ============================================================

    property var weatherData: ({})
    property bool loading: false
    property string errorText: ""

    // 0 = Daily
    // 1 = Hourly
    property int forecastMode: 0

    // Location editor
    property bool locationEditorOpen: false
    property string locationQuery: ""
    property string locationStatus: ""
    property var locationResults: []
    property bool locationSearching: false

    onLocationEditorOpenChanged: {
        if (locationEditorOpen) {
            cityInput.forceActiveFocus()
        }
    }


    readonly property bool hasWeather:
        weatherData
        && weatherData.location !== undefined
        && weatherData.current !== undefined
        && weatherData.details !== undefined


    // ============================================================
    // HELPERS
    // ============================================================

    function nexadPath() {
        return Quickshell.env("HOME")
            + "/.config/nexa/rust/target/release/nexad"
    }


    function temperature(value) {
        if (value === undefined || value === null)
            return "--°"

        return Math.round(value) + "°"
    }


    function numberText(value) {
        if (value === undefined || value === null)
            return "--"

        return Math.round(value).toString()
    }


    function locationText() {
        if (!hasWeather)
            return ""

        const name =
            weatherData.location.name || ""

        const country =
            weatherData.location.country || ""

        if (name !== "" && country !== "")
            return name + ", " + country

        return name
    }


    function dayName(dateString) {
        if (!dateString)
            return ""

        const date =
            new Date(dateString + "T00:00:00")

        return Qt.formatDate(
            date,
            "ddd"
        )
    }


    function hourlyTime(value) {
        if (!value)
            return ""

        const parts =
            value.split("T")

        if (parts.length < 2)
            return value

        return parts[1]
    }


    function weatherIcon(iconName) {
        switch (iconName) {

        case "clear-day":
            return "󰖙"

        case "clear-night":
            return "󰖔"

        case "mostly-clear-day":
            return "󰖙"

        case "mostly-clear-night":
            return "󰼱"

        case "partly-cloudy-day":
            return "󰖕"

        case "partly-cloudy-night":
            return "󰼱"

        case "cloudy":
            return "󰖐"

        case "fog":
            return "󰖑"

        case "drizzle":
            return "󰖗"

        case "rain":
        case "rain-showers":
            return "󰖖"

        case "freezing-rain":
            return "󰙿"

        case "snow":
        case "snow-showers":
            return "󰖘"

        case "thunderstorm":
        case "thunderstorm-hail":
            return "󰙾"

        default:
            return "󰖐"
        }
    }


    // ============================================================
    // BACKEND
    // ============================================================

    Process {
        id: weatherProcess

        command: [
            root.nexadPath(),
            "weather",
            "info"
        ]

        stdout: StdioCollector {
            id: weatherStdout

            onStreamFinished: {
                root.loading = false

                const output =
                    text.trim()

                if (output === "") {
                    root.errorText =
                        "Weather backend returned no data"

                    return
                }

                try {
                    root.weatherData =
                        JSON.parse(output)

                    root.errorText = ""

                } catch (error) {
                    root.errorText =
                        "Unable to parse weather data"

                    console.warn(
                        "Weather JSON parse failed:",
                        error
                    )
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const output =
                    text.trim()

                if (output !== "") {
                    root.loading = false
                    root.errorText = output

                    console.warn(
                        "Weather backend:",
                        output
                    )
                }
            }
        }
    }


    Process {
        id: refreshProcess

        command: [
            root.nexadPath(),
            "weather",
            "refresh"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false

                const output =
                    text.trim()

                if (output === "")
                    return

                try {
                    root.weatherData =
                        JSON.parse(output)

                    root.errorText = ""

                } catch (error) {
                    root.errorText =
                        "Unable to parse refreshed weather"
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const output =
                    text.trim()

                if (output !== "") {
                    root.loading = false
                    root.errorText = output
                }
            }
        }
    }


    // ============================================================
    // LOCATION — AUTO
    // ============================================================

    Process {
        id: locationAutoProcess

        command: [
            root.nexadPath(),
            "weather",
            "location",
            "auto"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()

                if (output === "")
                    return

                root.locationStatus = ""
                root.locationEditorOpen = false

                // Location change clears backend cache,
                // so fetch fresh weather immediately.
                root.refreshWeather()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const output = text.trim()

                if (output !== "")
                    root.locationStatus = output
            }
        }
    }


    // ============================================================
    // LOCATION — MANUAL
    // ============================================================

    Process {
        id: locationSetProcess

        property string requestedCity: ""

        command: [
            root.nexadPath(),
            "weather",
            "location",
            "set",
            requestedCity
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()

                if (output === "")
                    return

                root.locationStatus = ""
                root.locationEditorOpen = false
                root.locationQuery = ""

                root.refreshWeather()
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const output = text.trim()

                if (output !== "")
                    root.locationStatus = output
            }
        }
    }


    Process {
        id: locationSearchProcess

        property string query: ""

        command: [
            root.nexadPath(),
            "weather",
            "location",
            "search",
            query
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.locationSearching = false

                const output = text.trim()

                if (output === "") {
                    root.locationResults = []
                    return
                }

                try {
                    root.locationResults = JSON.parse(output)
                } catch (error) {
                    root.locationResults = []
                    console.warn("Location search parse failed:", error)
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                root.locationSearching = false

                const output = text.trim()

                if (output !== "")
                    root.locationStatus = output
            }
        }
    }


    Timer {
        id: locationSearchTimer

        interval: 350
        repeat: false

        onTriggered:
            root.searchLocation(root.locationQuery)
    }


    function searchLocation(query) {
        const cleanQuery = query.trim()

        if (cleanQuery.length < 2) {
            locationResults = []
            return
        }

        if (locationSearchProcess.running)
            return

        locationSearching = true
        locationStatus = ""

        locationSearchProcess.query = cleanQuery
        locationSearchProcess.running = true
    }


    function useAutomaticLocation() {
        if (locationAutoProcess.running)
            return

        locationStatus = "Detecting location..."
        locationAutoProcess.running = true
    }


    function setManualLocation(city) {
        const cleanCity = city.trim()

        if (cleanCity === "")
            return

        if (locationSetProcess.running)
            return

        locationStatus = "Finding " + cleanCity + "..."

        locationSetProcess.requestedCity = cleanCity
        locationSetProcess.running = true
    }


    function loadWeather() {
        if (weatherProcess.running)
            return

        loading = true
        errorText = ""

        weatherProcess.running = true
    }


    function refreshWeather() {
        if (refreshProcess.running)
            return

        loading = true
        errorText = ""

        refreshProcess.running = true
    }


    Component.onCompleted:
        loadWeather()


    // ============================================================
    // PAGE
    // ============================================================

    RowLayout {
        anchors {
            fill: parent
            margins: 10
        }
        spacing: 8

        // ========================================================
        // LEFT HALF — Current Weather + Scrollable Details
        // ========================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true

            radius: NexaUI.NexaTokens.radiusLg
            color: NexaUI.NexaColors.surfaceContainer
            border.width: NexaUI.NexaTokens.borderThin
            border.color: NexaUI.NexaColors.border
            clip: true

            // Apple Tactile 4-stop Depth Micro-Gradient
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                antialiasing: true
                visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
                opacity: NexaUI.NexaOptics.gradientIntensity
                gradient: Gradient {
                    GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.045) }
                    GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.010) }
                    GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.000) }
                    GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.120) }
                }
            }

            // Top Chamfer Specular Highlight
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(0, parent.width - parent.radius * 1.6)
                height: 1
                visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
                opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.30) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // ── Current weather ──────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Big weather icon
                    Text {
                        text: root.hasWeather
                            ? root.weatherIcon(root.weatherData.current.icon)
                            : "󰖐"
                        color: NexaUI.NexaColors.primary
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 52
                    }

                    ColumnLayout {
                        spacing: 2

                        // Temperature
                        Text {
                            text: root.hasWeather
                                ? root.temperature(root.weatherData.current.temperature)
                                : "--°"
                            color: NexaUI.NexaColors.text
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 38
                            font.weight: NexaUI.NexaTypography.weightBold
                        }

                        // Min / Max
                        Text {
                            text: root.hasWeather
                                ? root.temperature(root.weatherData.current.min_temperature)
                                  + " / "
                                  + root.temperature(root.weatherData.current.max_temperature)
                                : "-- / --"
                            color: NexaUI.NexaColors.primary
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.sizeSm
                            font.weight: NexaUI.NexaTypography.weightMedium
                        }

                        // Condition
                        Text {
                            text: root.hasWeather
                                ? root.weatherData.current.condition
                                : root.loading ? "Loading…" : "Unavailable"
                            color: NexaUI.NexaColors.text
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.sizeSm
                            font.weight: NexaUI.NexaTypography.weightMedium
                        }

                        // Location button
                        Rectangle {
                            id: locationButton
                            height: 24
                            width: locationRow.implicitWidth + 16
                            radius: NexaUI.NexaTokens.radiusPill
                            color: locationMouse.containsMouse ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.onSurface, 0.08) : NexaUI.NexaColors.alpha(NexaUI.NexaColors.surfaceContainerLow, 0.6)
                            border.width: NexaUI.NexaTokens.borderThin
                            border.color: locationMouse.containsMouse ? NexaUI.NexaColors.primary : NexaUI.NexaColors.border

                            Row {
                                id: locationRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "󰍎"
                                    color: NexaUI.NexaColors.primary
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.locationText()
                                    color: locationMouse.containsMouse ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    font.weight: NexaUI.NexaTypography.weightMedium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.locationEditorOpen ? "󰅃" : "󰅀"
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: locationMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.locationEditorOpen = !root.locationEditorOpen
                            }
                        }
                    }
                }

                // ── Thin divider ─────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: NexaUI.NexaColors.border
                }

                Flickable {
                    id: detailsFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: detailsCol.implicitHeight
                    contentWidth: width
                    boundsBehavior: Flickable.StopAtBounds

                    NexaUI.NexaScroll {}

                    ScrollBar.vertical: ScrollBar {
                        id: detailsScrollBar
                        policy: ScrollBar.AsNeeded
                        width: 4
                        anchors.right: parent.right
                        anchors.rightMargin: 1
                        visible: size < 1.0

                        contentItem: Rectangle {
                            implicitWidth: 3
                            radius: NexaUI.NexaTokens.radiusPill
                            color: detailsScrollBar.hovered ? NexaUI.NexaColors.primary : NexaUI.NexaColors.alpha(NexaUI.NexaColors.onSurface, 0.38)
                            opacity: (detailsScrollBar.active || detailsScrollBar.hovered) ? 0.8 : 0.0

                            Behavior on opacity {
                                NumberAnimation { duration: NexaUI.NexaMotion.durationNormal }
                            }
                            Behavior on color {
                                ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                            }
                        }

                        background: null
                    }

                    Column {
                        id: detailsCol
                        width: parent.width - (parent.contentHeight > parent.height ? (NexaUI.NexaTokens.spacingSm + 4) : 0)
                        spacing: 0

                        Behavior on width {
                            NumberAnimation { duration: NexaUI.NexaMotion.durationFast }
                        }

                        // Helper component
                        component DetailItem: Item {
                            property string icon: ""
                            property string label: ""
                            property string value: ""
                            property bool last: false

                            width: parent.width
                            height: 28

                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                Text {
                                    Layout.preferredWidth: 20
                                    text: parent.parent.icon
                                    color: NexaUI.NexaColors.primary
                                    font.family: NexaUI.NexaTypography.familyIcon
                                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: parent.parent.label
                                    color: NexaUI.NexaColors.mutedText
                                    font.family: NexaUI.NexaTypography.familyBody
                                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: parent.parent.value
                                    color: NexaUI.NexaColors.text
                                    font.family: NexaUI.NexaTypography.familyMono
                                    font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    font.weight: NexaUI.NexaTypography.weightSemiBold
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            Rectangle {
                                visible: !parent.last
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: NexaUI.NexaColors.border
                            }
                        }

                        DetailItem {
                            icon: "󰔄"
                            label: "Temperature Min"
                            value: root.hasWeather ? root.temperature(root.weatherData.details.temperature_min) : "--"
                        }
                        DetailItem {
                            icon: "󰔅"
                            label: "Temperature Max"
                            value: root.hasWeather ? root.temperature(root.weatherData.details.temperature_max) : "--"
                        }
                        DetailItem {
                            icon: "󰖝"
                            label: "Wind"
                            value: root.hasWeather ? (root.numberText(root.weatherData.details.wind_speed) + " km/h " + root.weatherData.details.wind_direction) : "--"
                        }
                        DetailItem {
                            icon: "󰖛"
                            label: "Sunrise"
                            value: root.hasWeather ? root.weatherData.details.sunrise : "--"
                        }
                        DetailItem {
                            icon: "󰖚"
                            label: "Sunset"
                            value: root.hasWeather ? root.weatherData.details.sunset : "--"
                        }
                        DetailItem {
                            icon: "󰓁"
                            label: "Elevation"
                            value: root.hasWeather ? (root.numberText(root.weatherData.details.elevation) + " m") : "--"
                        }
                        DetailItem {
                            icon: "󰖨"
                            label: "UV Index"
                            value: root.hasWeather ? Number(root.weatherData.details.uv_index).toFixed(1) : "--"
                        }
                        DetailItem {
                            icon: "󰥔"
                            label: "Timezone"
                            value: root.hasWeather ? root.weatherData.details.timezone_abbreviation : "--"
                            last: true
                        }
                    }
                }
            }
        }


        // ========================================================
        // RIGHT HALF — Forecast (scrollable)
        // ========================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true

            radius: NexaUI.NexaTokens.radiusLg
            color: NexaUI.NexaColors.surfaceContainer
            border.width: NexaUI.NexaTokens.borderThin
            border.color: NexaUI.NexaColors.border
            clip: true

            // Apple Tactile 4-stop Depth Micro-Gradient
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                antialiasing: true
                visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
                opacity: NexaUI.NexaOptics.gradientIntensity
                gradient: Gradient {
                    GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.045) }
                    GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.010) }
                    GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.000) }
                    GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.120) }
                }
            }

            // Top Chamfer Specular Highlight
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(0, parent.width - parent.radius * 1.6)
                height: 1
                visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
                opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.30) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // ── Forecast header: toggle + refresh ────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Daily / Hourly pill toggle
                    Rectangle {
                        width: 136
                        height: 28
                        radius: NexaUI.NexaTokens.radiusPill
                        color: NexaUI.NexaColors.surfaceContainerLow
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: NexaUI.NexaColors.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 2
                            spacing: 2

                            ForecastButton {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: "Daily"
                                selected: root.forecastMode === 0
                                onClicked: root.forecastMode = 0
                            }
                            ForecastButton {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: "Hourly"
                                selected: root.forecastMode === 1
                                onClicked: root.forecastMode = 1
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Refresh button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: NexaUI.NexaTokens.radiusPill
                        color: refreshMouse.containsMouse ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.onSurface, 0.08) : "transparent"
                        border.width: NexaUI.NexaTokens.borderThin
                        border.color: refreshMouse.containsMouse ? NexaUI.NexaColors.border : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            color: root.loading ? NexaUI.NexaColors.primary : NexaUI.NexaColors.mutedText
                            font.family: NexaUI.NexaTypography.familyIcon
                            font.pixelSize: 14
                            rotation: root.loading ? 360 : 0

                            Behavior on rotation {
                                NumberAnimation { duration: NexaUI.NexaMotion.durationSlow; easing.type: NexaUI.NexaMotion.standardEasing }
                            }
                        }

                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refreshWeather()
                        }
                    }
                }

                // ── Thin divider ─────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: NexaUI.NexaColors.border
                }

                // ── Scrollable forecast list ──────────────────────
                Flickable {
                    id: forecastFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: forecastMode === 0 ? dailyCol.implicitHeight : hourlyCol.implicitHeight
                    contentWidth: width
                    boundsBehavior: Flickable.StopAtBounds

                    NexaUI.NexaScroll {}

                    ScrollBar.vertical: ScrollBar {
                        id: forecastScrollBar
                        policy: ScrollBar.AsNeeded
                        width: 4
                        anchors.right: parent.right
                        anchors.rightMargin: 1
                        visible: size < 1.0

                        contentItem: Rectangle {
                            implicitWidth: 3
                            radius: NexaUI.NexaTokens.radiusPill
                            color: forecastScrollBar.hovered ? NexaUI.NexaColors.primary : NexaUI.NexaColors.alpha(NexaUI.NexaColors.onSurface, 0.38)
                            opacity: (forecastScrollBar.active || forecastScrollBar.hovered) ? 0.8 : 0.0

                            Behavior on opacity {
                                NumberAnimation { duration: NexaUI.NexaMotion.durationNormal }
                            }
                            Behavior on color {
                                ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                            }
                        }

                        background: null
                    }

                    // DAILY
                    Column {
                        id: dailyCol
                        width: parent.width - (parent.contentHeight > parent.height ? (NexaUI.NexaTokens.spacingSm + 4) : 0)
                        visible: root.forecastMode === 0
                        spacing: 0

                        Behavior on width {
                            NumberAnimation { duration: NexaUI.NexaMotion.durationFast }
                        }

                        Repeater {
                            model: root.hasWeather ? root.weatherData.daily : []
                            delegate: Item {
                                required property var modelData
                                width: dailyCol.width
                                height: 46

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: 8

                                    // Day name
                                    Text {
                                        Layout.preferredWidth: 32
                                        text: root.dayName(modelData.date)
                                        color: NexaUI.NexaColors.text
                                        font.family: NexaUI.NexaTypography.familyBody
                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                        font.weight: NexaUI.NexaTypography.weightSemiBold
                                    }

                                    // Icon
                                    Text {
                                        Layout.preferredWidth: 22
                                        text: root.weatherIcon(modelData.icon)
                                        color: NexaUI.NexaColors.primary
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: 18
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    // Condition description
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: root.temperature(modelData.min_temperature) + " / " + root.temperature(modelData.max_temperature)
                                            color: NexaUI.NexaColors.text
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                                            font.weight: NexaUI.NexaTypography.weightMedium
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.condition
                                            color: NexaUI.NexaColors.mutedText
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Rain probability
                                    Text {
                                        Layout.preferredWidth: 34
                                        text: Math.round(modelData.precipitation_probability) + "%"
                                        horizontalAlignment: Text.AlignRight
                                        color: NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyMono
                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    }
                                }

                                // Divider
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: NexaUI.NexaColors.border
                                }
                            }
                        }
                    }

                    // HOURLY
                    Column {
                        id: hourlyCol
                        width: parent.width - (parent.contentHeight > parent.height ? (NexaUI.NexaTokens.spacingSm + 4) : 0)
                        visible: root.forecastMode === 1
                        spacing: 0

                        Behavior on width {
                            NumberAnimation { duration: NexaUI.NexaMotion.durationFast }
                        }

                        Repeater {
                            model: root.hasWeather ? root.weatherData.hourly : []
                            delegate: Item {
                                required property var modelData
                                width: hourlyCol.width
                                height: 46

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: 8

                                    Text {
                                        Layout.preferredWidth: 38
                                        text: root.hourlyTime(modelData.time)
                                        color: NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyMono
                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    }

                                    Text {
                                        Layout.preferredWidth: 22
                                        text: root.weatherIcon(modelData.icon)
                                        color: NexaUI.NexaColors.primary
                                        font.family: NexaUI.NexaTypography.familyIcon
                                        font.pixelSize: 18
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: root.temperature(modelData.temperature)
                                            color: NexaUI.NexaColors.text
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                                            font.weight: NexaUI.NexaTypography.weightMedium
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.condition
                                            color: NexaUI.NexaColors.mutedText
                                            font.family: NexaUI.NexaTypography.familyBody
                                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 34
                                        text: Math.round(modelData.precipitation_probability) + "%"
                                        horizontalAlignment: Text.AlignRight
                                        color: NexaUI.NexaColors.mutedText
                                        font.family: NexaUI.NexaTypography.familyMono
                                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: NexaUI.NexaColors.border
                                }
                            }
                        }
                    }

                    // Error text
                    Text {
                        visible: root.errorText !== ""
                        anchors.centerIn: parent
                        text: root.errorText
                        wrapMode: Text.Wrap
                        width: parent.width
                        color: NexaUI.NexaColors.error
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                    }
                }
            }
        }
    }


    // ============================================================
    // LOCATION EDITOR
    // ============================================================

    // Dismissal backdrop when location editor is open (click anywhere outside to close)
    MouseArea {
        anchors.fill: parent
        visible: root.locationEditorOpen
        z: 999
        hoverEnabled: false
        onClicked: root.locationEditorOpen = false
    }

    Rectangle {
        id: locationPopup

        visible:
            root.locationEditorOpen

        z: 1000

        width: 260
        x: 12
        y: locationButton ? Math.max(8, locationButton.mapToItem(root, 0, 0).y + locationButton.height + 6) : 90
        implicitHeight: locationLayout.implicitHeight + NexaUI.NexaTokens.spacingMd * 2
        height: Math.min(root.height - y - 10, implicitHeight)

        radius:
            NexaUI.NexaTokens.radiusMd

        color:
            NexaUI.NexaColors.surfaceContainerHigh

        border.width:
            NexaUI.NexaTokens.borderThin

        border.color:
            NexaUI.NexaColors.border

        // Apple Tactile 4-stop Depth Micro-Gradient
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            antialiasing: true
            visible: NexaUI.NexaOptics.surface3DGradient && NexaUI.NexaOptics.gradientIntensity > 0.01
            opacity: NexaUI.NexaOptics.gradientIntensity
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.045) }
                GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.010) }
                GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.000) }
                GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.120) }
            }
        }

        // Top Chamfer Specular Highlight
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(0, parent.width - parent.radius * 1.6)
            height: 1
            visible: NexaUI.NexaOptics.specularHighlight && NexaUI.NexaOptics.specularIntensity > 0.01
            opacity: Math.min(1.0, NexaUI.NexaOptics.specularIntensity / 0.28)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.30) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            id: locationLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: NexaUI.NexaTokens.spacingMd
            spacing: NexaUI.NexaTokens.spacingSm

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Location"
                    color: NexaUI.NexaColors.text
                    font.family: NexaUI.NexaTypography.familyBody
                    font.pixelSize: NexaUI.NexaTypography.sizeSm
                    font.weight: NexaUI.NexaTypography.weightSemiBold
                }

                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: NexaUI.NexaTokens.radiusPill
                    color: closeLocationMouse.containsMouse ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.onSurface, 0.08) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: closeLocationMouse.containsMouse ? NexaUI.NexaColors.text : NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyIcon
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: closeLocationMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.locationEditorOpen = false
                    }
                }
            }

            // --------------------------------------------------------
            // AUTO
            // --------------------------------------------------------

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30

                radius:
                    NexaUI.NexaTokens.radiusSm

                color:
                    autoMouse.containsMouse
                    ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.onSurface, 0.08)
                    : NexaUI.NexaColors.surfaceContainer

                border.width:
                    NexaUI.NexaTokens.borderThin

                border.color:
                    NexaUI.NexaColors.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 7

                    Text {
                        text: "󰑐"
                        color: NexaUI.NexaColors.primary
                        font.family: NexaUI.NexaTypography.familyIcon
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Automatic location"
                        color: NexaUI.NexaColors.text
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                        font.weight: NexaUI.NexaTypography.weightMedium
                    }
                }

                MouseArea {
                    id: autoMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.useAutomaticLocation()
                }
            }

            // --------------------------------------------------------
            // MANUAL CITY
            // --------------------------------------------------------

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: NexaUI.NexaTokens.radiusSm
                color: NexaUI.NexaColors.surfaceContainer

                border.width: NexaUI.NexaTokens.borderThin
                border.color: cityInput.activeFocus
                    ? NexaUI.NexaColors.primary
                    : NexaUI.NexaColors.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 5
                    spacing: 5

                    Text {
                        text: "󰍉"
                        color: NexaUI.NexaColors.mutedText
                        font.family: NexaUI.NexaTypography.familyIcon
                    }

                    TextInput {
                        id: cityInput
                        Layout.fillWidth: true
                        text: root.locationQuery
                        color: NexaUI.NexaColors.text
                        selectionColor: NexaUI.NexaColors.primary
                        font.family: NexaUI.NexaTypography.familyBody
                        font.pixelSize: NexaUI.NexaTypography.sizeXs
                        font.weight: NexaUI.NexaTypography.weightMedium
                        clip: true

                        onTextChanged: {
                            root.locationQuery = text
                            locationSearchTimer.restart()
                        }

                        Keys.onReturnPressed: root.setManualLocation(text)
                        Keys.onEscapePressed: root.locationEditorOpen = false
                    }

                    Text {
                        text: "󰄬"
                        color: NexaUI.NexaColors.primary
                        font.family: NexaUI.NexaTypography.familyIcon

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setManualLocation(cityInput.text)
                        }
                    }
                }

                Text {
                    visible:
                        cityInput.text.length === 0
                        && !cityInput.activeFocus

                    anchors.verticalCenter:
                        parent.verticalCenter

                    anchors.left:
                        parent.left

                    anchors.leftMargin: 30

                    text:
                        "Enter city..."

                    color:
                        NexaUI.NexaColors.mutedText

                    font.family:
                        NexaUI.NexaTypography.familyBody

                    font.pixelSize:
                        NexaUI.NexaTypography.sizeXs
                }
            }

            ListView {
                id: locationResultsList

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(130, contentHeight)
                Layout.maximumHeight: 130

                visible:
                    root.locationResults.length > 0

                clip: true
                spacing: 3
                model: root.locationResults

                ScrollBar.vertical: ScrollBar {
                    id: resultsScrollBar
                    policy: ScrollBar.AsNeeded
                    width: 4
                    anchors.right: parent.right
                    anchors.rightMargin: 1
                    visible: size < 1.0

                    contentItem: Rectangle {
                        implicitWidth: 3
                        radius: NexaUI.NexaTokens.radiusPill
                        color: resultsScrollBar.hovered ? NexaUI.NexaColors.primary : NexaUI.NexaColors.alpha(NexaUI.NexaColors.onSurface, 0.38)
                        opacity: (resultsScrollBar.active || resultsScrollBar.hovered) ? 0.8 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: NexaUI.NexaMotion.durationNormal }
                        }
                        Behavior on color {
                            ColorAnimation { duration: NexaUI.NexaMotion.durationFast }
                        }
                    }

                    background: null
                }

                delegate: Rectangle {
                    required property var modelData

                    width:
                        locationResultsList.width - (locationResultsList.contentHeight > locationResultsList.height ? 8 : 0)

                    Behavior on width {
                        NumberAnimation { duration: NexaUI.NexaMotion.durationFast }
                    }

                    height: 42
                    radius: NexaUI.NexaTokens.radiusSm
                    color:
                        resultMouse.containsMouse
                        ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.primary, 0.14)
                        : "transparent"

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 1

                        Text {
                            text: modelData.name
                            color: resultMouse.containsMouse ? NexaUI.NexaColors.primary : NexaUI.NexaColors.text
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: NexaUI.NexaTypography.sizeXs
                            font.weight: NexaUI.NexaTypography.weightSemiBold
                        }

                        Text {
                            width: parent.width
                            text: {
                                let parts = []
                                if (modelData.admin1) parts.push(modelData.admin1)
                                if (modelData.country) parts.push(modelData.country)
                                return parts.join(", ")
                            }
                            color: NexaUI.NexaColors.mutedText
                            font.family: NexaUI.NexaTypography.familyBody
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: resultMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.setManualLocation(modelData.name)
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.locationStatus !== ""
                text: root.locationStatus
                color: NexaUI.NexaColors.mutedText
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: NexaUI.NexaTypography.sizeXs
                elide: Text.ElideRight
            }
        }
    }

    // ============================================================
    // DETAIL ROW
    // ============================================================

    component WeatherDetailRow: Item {
        property string icon: ""
        property string label: ""
        property string value: ""
        property bool separatorVisible: true

        Layout.fillWidth: true
        Layout.preferredHeight: 30
        Layout.minimumHeight: 30
        Layout.maximumHeight: 30

        RowLayout {
            anchors.fill: parent
            spacing: NexaUI.NexaTokens.spacingSm

            Text {
                Layout.preferredWidth: 22
                text: parent.parent.icon
                color: NexaUI.NexaColors.primary
                font.family: NexaUI.NexaTypography.familyIcon
                font.pixelSize: NexaUI.NexaTypography.sizeSm
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                text: parent.parent.label
                color: NexaUI.NexaColors.mutedText
                font.family: NexaUI.NexaTypography.familyBody
                font.pixelSize: NexaUI.NexaTypography.sizeXs
            }

            Text {
                text: parent.parent.value
                color: NexaUI.NexaColors.text
                font.family: NexaUI.NexaTypography.familyMono
                font.pixelSize: NexaUI.NexaTypography.sizeXs
                font.weight: NexaUI.NexaTypography.weightSemiBold
            }
        }

        Rectangle {
            visible: parent.separatorVisible
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: NexaUI.NexaColors.border
        }
    }

    // ============================================================
    // FORECAST BUTTON
    // ============================================================

    component ForecastButton: Rectangle {
        property string text: ""
        property bool selected: false
        signal clicked()

        radius: NexaUI.NexaTokens.radiusPill
        color: selected
            ? NexaUI.NexaColors.primary
            : (buttonMouse.containsMouse ? NexaUI.NexaColors.alpha(NexaUI.NexaColors.onSurface, 0.08) : "transparent")

        Text {
            anchors.centerIn: parent
            text: parent.text
            color: parent.selected ? NexaUI.NexaColors.onPrimary : NexaUI.NexaColors.mutedText
            font.family: NexaUI.NexaTypography.familyBody
            font.pixelSize: NexaUI.NexaTypography.sizeXs
            font.weight: NexaUI.NexaTypography.weightSemiBold
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}


