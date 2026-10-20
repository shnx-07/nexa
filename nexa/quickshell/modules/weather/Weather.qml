import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../theme" as Nexa
import "../../theme/components" as NexaUI

Item {
    id: root

    // Weather state
    property var weatherData: ({})
    property bool loading: false
    property string errorText: ""
    property int forecastMode: 0 // 0 = Daily, 1 = Hourly

    // Location editor state
    property bool locationEditorOpen: false
    property string locationQuery: ""
    property string locationStatus: ""
    property var locationResults: []
    property bool locationSearching: false

    onLocationEditorOpenChanged: {
        if (locationEditorOpen) cityInput.forceActiveFocus()
    }

    readonly property bool hasWeather: weatherData && weatherData.location !== undefined
        && weatherData.current !== undefined && weatherData.details !== undefined

    // Helpers
    function nexadPath() { return Quickshell.env("HOME") + "/.config/nexa/rust/target/release/nexad" }
    function temperature(v) { return (v === undefined || v === null) ? "--°" : Math.round(v) + "°" }
    function numberText(v) { return (v === undefined || v === null) ? "--" : Math.round(v).toString() }
    function locationText() {
        if (!hasWeather) return ""
        const name = weatherData.location.name || ""
        const country = weatherData.location.country || ""
        return (name && country) ? (name + ", " + country) : name
    }
    function dayName(d) { return d ? Qt.formatDate(new Date(d + "T00:00:00"), "ddd") : "" }
    function hourlyTime(v) {
        if (!v) return ""
        const parts = v.split("T")
        return parts.length < 2 ? v : parts[1]
    }
    function weatherIcon(name) {
        const icons = {
            "clear-day": "󰖙", "clear-night": "󰖔", "mostly-clear-day": "󰖙", "mostly-clear-night": "󰼱",
            "partly-cloudy-day": "󰖕", "partly-cloudy-night": "󰼱", "cloudy": "󰖐", "fog": "󰖑",
            "drizzle": "󰖗", "rain": "󰖖", "rain-showers": "󰖖", "freezing-rain": "󰙿",
            "snow": "󰖘", "snow-showers": "󰖘", "thunderstorm": "󰙾", "thunderstorm-hail": "󰙾"
        }
        return icons[name] || "󰖐"
    }

    // Backend Processes
    Process {
        id: weatherProcess
        command: [root.nexadPath(), "weather", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                const out = text.trim()
                if (!out) { root.errorText = "Weather backend returned no data"; return }
                try {
                    root.weatherData = JSON.parse(out)
                    root.errorText = ""
                } catch (e) {
                    root.errorText = "Unable to parse weather data"
                    console.warn("Weather JSON parse failed:", e)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const out = text.trim()
                if (out) { root.loading = false; root.errorText = out; console.warn("Weather backend:", out) }
            }
        }
    }

    Process {
        id: refreshProcess
        command: [root.nexadPath(), "weather", "refresh"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                const out = text.trim()
                if (!out) return
                try {
                    root.weatherData = JSON.parse(out)
                    root.errorText = ""
                } catch (e) {
                    root.errorText = "Unable to parse refreshed weather"
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const out = text.trim()
                if (out) { root.loading = false; root.errorText = out }
            }
        }
    }

    Process {
        id: locationAutoProcess
        command: [root.nexadPath(), "weather", "location", "auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return
                root.locationStatus = ""
                root.locationEditorOpen = false
                root.refreshWeather()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim()) root.locationStatus = text.trim() }
        }
    }

    Process {
        id: locationSetProcess
        property string requestedCity: ""
        command: [root.nexadPath(), "weather", "location", "set", requestedCity]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return
                root.locationStatus = ""
                root.locationEditorOpen = false
                root.locationQuery = ""
                root.refreshWeather()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim()) root.locationStatus = text.trim() }
        }
    }

    Process {
        id: locationSearchProcess
        property string query: ""
        command: [root.nexadPath(), "weather", "location", "search", query]
        stdout: StdioCollector {
            onStreamFinished: {
                root.locationSearching = false
                const out = text.trim()
                if (!out) { root.locationResults = []; return }
                try {
                    root.locationResults = JSON.parse(out)
                } catch (e) {
                    root.locationResults = []
                    console.warn("Location search parse failed:", e)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root.locationSearching = false
                if (text.trim()) root.locationStatus = text.trim()
            }
        }
    }

    Timer {
        id: locationSearchTimer
        interval: 350
        repeat: false
        onTriggered: root.searchLocation(root.locationQuery)
    }

    function searchLocation(query) {
        const clean = query.trim()
        if (clean.length < 2) { locationResults = []; return }
        if (locationSearchProcess.running) return
        locationSearching = true
        locationStatus = ""
        locationSearchProcess.query = clean
        locationSearchProcess.running = true
    }

    function useAutomaticLocation() {
        if (locationAutoProcess.running) return
        locationStatus = "Detecting location..."
        locationAutoProcess.running = true
    }

    function setManualLocation(city) {
        const clean = city.trim()
        if (!clean || locationSetProcess.running) return
        locationStatus = "Finding " + clean + "..."
        locationSetProcess.requestedCity = clean
        locationSetProcess.running = true
    }

    function loadWeather() {
        if (weatherProcess.running) return
        loading = true
        errorText = ""
        weatherProcess.running = true
    }

    function refreshWeather() {
        if (refreshProcess.running) return
        loading = true
        errorText = ""
        refreshProcess.running = true
    }

    Component.onCompleted: loadWeather()

    // Main Page UI
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // LEFT HALF — Current Weather + Scrollable Details
        NexaUI.NexaCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 12
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: root.hasWeather ? root.weatherIcon(root.weatherData.current.icon) : "󰖐"
                        color: Nexa.Theme.primary
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 52
                    }

                    ColumnLayout {
                        spacing: 2

                        Text {
                            text: root.hasWeather ? root.temperature(root.weatherData.current.temperature) : "--°"
                            color: Nexa.Theme.text
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 38
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: root.hasWeather
                                ? root.temperature(root.weatherData.current.min_temperature) + " / " + root.temperature(root.weatherData.current.max_temperature)
                                : "-- / --"
                            color: Nexa.Theme.primary
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 12
                        }

                        Text {
                            text: root.hasWeather ? root.weatherData.current.condition : (root.loading ? "Loading…" : "Unavailable")
                            color: Nexa.Theme.text
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            id: locationButton
                            height: 22
                            width: locationRow.implicitWidth + 14
                            radius: Nexa.Theme.radiusSm
                            color: locationMouse.containsMouse ? Nexa.Theme.hover : "transparent"

                            Row {
                                id: locationRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: "󰍎"
                                    color: Nexa.Theme.primary
                                    font.family: Nexa.Theme.iconFontFamily
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.locationText()
                                    color: locationMouse.containsMouse ? Nexa.Theme.text : Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.locationEditorOpen ? "󰅃" : "󰅀"
                                    color: Nexa.Theme.mutedText
                                    font.family: Nexa.Theme.iconFontFamily
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

                Rectangle { Layout.fillWidth: true; height: 1; color: Nexa.Theme.divider }

                Flickable {
                    id: detailsFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: detailsCol.implicitHeight
                    contentWidth: width
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        id: detailsScrollBar
                        policy: ScrollBar.AsNeeded
                        width: 4
                        anchors.right: parent.right
                        anchors.rightMargin: 1
                        visible: size < 1.0

                        contentItem: Rectangle {
                            implicitWidth: 3
                            radius: Nexa.Theme.radiusPill
                            color: detailsScrollBar.hovered ? Nexa.Theme.primary : Nexa.Theme.mutedText
                            opacity: (detailsScrollBar.active || detailsScrollBar.hovered) ? 0.6 : 0.0
                            Behavior on opacity { NumberAnimation { duration: Nexa.Theme.animationNormal } }
                            Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                        }
                        background: null
                    }

                    Column {
                        id: detailsCol
                        width: parent.width - (parent.contentHeight > parent.height ? (Nexa.Theme.spacingSm + 4) : 0)
                        spacing: 0
                        Behavior on width { NumberAnimation { duration: Nexa.Theme.animationFast } }

                        DetailItem {
                            icon: "󰔄"; label: "Temperature Min"
                            value: root.hasWeather ? root.temperature(root.weatherData.details.temperature_min) : "--"
                        }
                        DetailItem {
                            icon: "󰔅"; label: "Temperature Max"
                            value: root.hasWeather ? root.temperature(root.weatherData.details.temperature_max) : "--"
                        }
                        DetailItem {
                            icon: "󰖝"; label: "Wind"
                            value: root.hasWeather ? (root.numberText(root.weatherData.details.wind_speed) + " km/h " + root.weatherData.details.wind_direction) : "--"
                        }
                        DetailItem {
                            icon: "󰖛"; label: "Sunrise"
                            value: root.hasWeather ? root.weatherData.details.sunrise : "--"
                        }
                        DetailItem {
                            icon: "󰖚"; label: "Sunset"
                            value: root.hasWeather ? root.weatherData.details.sunset : "--"
                        }
                        DetailItem {
                            icon: "󰓁"; label: "Elevation"
                            value: root.hasWeather ? (root.numberText(root.weatherData.details.elevation) + " m") : "--"
                        }
                        DetailItem {
                            icon: "󰖨"; label: "UV Index"
                            value: root.hasWeather ? Number(root.weatherData.details.uv_index).toFixed(1) : "--"
                        }
                        DetailItem {
                            icon: "󰥔"; label: "Timezone"
                            value: root.hasWeather ? root.weatherData.details.timezone_abbreviation : "--"
                            last: true
                        }
                    }
                }
            }
        }

        // RIGHT HALF — Forecast
        NexaUI.NexaCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 12
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 130
                        height: 28
                        radius: Nexa.Theme.radiusSm
                        color: Nexa.Theme.surface
                        border.width: Nexa.Theme.borderThin
                        border.color: Nexa.Theme.border

                        RowLayout {
                            anchors.fill: parent
                            spacing: 0
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

                    Rectangle {
                        width: 28
                        height: 28
                        radius: Nexa.Theme.radiusSm
                        color: refreshMouse.containsMouse ? Nexa.Theme.hoverStrong : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            color: root.loading ? Nexa.Theme.primary : Nexa.Theme.mutedText
                            font.family: Nexa.Theme.iconFontFamily
                            font.pixelSize: Nexa.Theme.iconSm
                            rotation: root.loading ? 360 : 0
                            Behavior on rotation {
                                NumberAnimation { duration: Nexa.Theme.animationSlow; easing.type: Nexa.Theme.easingStandard }
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

                Rectangle { Layout.fillWidth: true; height: 1; color: Nexa.Theme.divider }

                Flickable {
                    id: forecastFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: root.forecastMode === 0 ? dailyCol.implicitHeight : hourlyCol.implicitHeight
                    contentWidth: width
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        id: forecastScrollBar
                        policy: ScrollBar.AsNeeded
                        width: 4
                        anchors.right: parent.right
                        anchors.rightMargin: 1
                        visible: size < 1.0

                        contentItem: Rectangle {
                            implicitWidth: 3
                            radius: Nexa.Theme.radiusPill
                            color: forecastScrollBar.hovered ? Nexa.Theme.primary : Nexa.Theme.mutedText
                            opacity: (forecastScrollBar.active || forecastScrollBar.hovered) ? 0.6 : 0.0
                            Behavior on opacity { NumberAnimation { duration: Nexa.Theme.animationNormal } }
                            Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                        }
                        background: null
                    }

                    Column {
                        id: dailyCol
                        width: parent.width - (parent.contentHeight > parent.height ? (Nexa.Theme.spacingSm + 4) : 0)
                        visible: root.forecastMode === 0
                        spacing: 0
                        Behavior on width { NumberAnimation { duration: Nexa.Theme.animationFast } }

                        Repeater {
                            model: root.hasWeather ? root.weatherData.daily : []
                            delegate: Item {
                                required property var modelData
                                width: dailyCol.width
                                height: 46

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 2
                                    anchors.rightMargin: 2
                                    spacing: 8

                                    Text {
                                        Layout.preferredWidth: 30
                                        text: root.dayName(modelData.date)
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSizeXs
                                        font.weight: Font.Medium
                                    }

                                    Text {
                                        Layout.preferredWidth: 22
                                        text: root.weatherIcon(modelData.icon)
                                        color: Nexa.Theme.primary
                                        font.family: Nexa.Theme.iconFontFamily
                                        font.pixelSize: Nexa.Theme.iconLg
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.temperature(modelData.min_temperature) + " / " + root.temperature(modelData.max_temperature)
                                            color: Nexa.Theme.text
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: Nexa.Theme.fontSizeXs
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.condition
                                            color: Nexa.Theme.mutedText
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: Nexa.Theme.fontSizeXs
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 34
                                        text: Math.round(modelData.precipitation_probability) + "%"
                                        horizontalAlignment: Text.AlignRight
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSizeXs
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: Nexa.Theme.divider
                                }
                            }
                        }
                    }

                    Column {
                        id: hourlyCol
                        width: parent.width - (parent.contentHeight > parent.height ? (Nexa.Theme.spacingSm + 4) : 0)
                        visible: root.forecastMode === 1
                        spacing: 0
                        Behavior on width { NumberAnimation { duration: Nexa.Theme.animationFast } }

                        Repeater {
                            model: root.hasWeather ? root.weatherData.hourly : []
                            delegate: Item {
                                required property var modelData
                                width: hourlyCol.width
                                height: 46

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 2
                                    anchors.rightMargin: 2
                                    spacing: 8

                                    Text {
                                        Layout.preferredWidth: 38
                                        text: root.hourlyTime(modelData.time)
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSizeXs
                                    }

                                    Text {
                                        Layout.preferredWidth: 22
                                        text: root.weatherIcon(modelData.icon)
                                        color: Nexa.Theme.primary
                                        font.family: Nexa.Theme.iconFontFamily
                                        font.pixelSize: Nexa.Theme.iconLg
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: root.temperature(modelData.temperature)
                                            color: Nexa.Theme.text
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: Nexa.Theme.fontSizeXs
                                            font.weight: Font.Medium
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.condition
                                            color: Nexa.Theme.mutedText
                                            font.family: Nexa.Theme.fontFamily
                                            font.pixelSize: Nexa.Theme.fontSizeXs
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 34
                                        text: Math.round(modelData.precipitation_probability) + "%"
                                        horizontalAlignment: Text.AlignRight
                                        color: Nexa.Theme.mutedText
                                        font.family: Nexa.Theme.fontFamily
                                        font.pixelSize: Nexa.Theme.fontSizeXs
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: Nexa.Theme.divider
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.errorText !== ""
                        anchors.centerIn: parent
                        text: root.errorText
                        wrapMode: Text.Wrap
                        width: parent.width
                        color: Nexa.Theme.error
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSizeXs
                    }
                }
            }
        }
    }

    // Dismissal backdrop when location editor is open
    MouseArea {
        anchors.fill: parent
        visible: root.locationEditorOpen
        z: 999
        hoverEnabled: false
        onClicked: root.locationEditorOpen = false
    }

    // Location Popup
    Rectangle {
        id: locationPopup
        visible: root.locationEditorOpen
        z: 1000
        width: 250
        x: 12
        y: locationButton ? Math.max(8, locationButton.mapToItem(root, 0, 0).y + locationButton.height + 6) : 90
        implicitHeight: locationLayout.implicitHeight + Nexa.Theme.spacingMd * 2
        height: Math.min(root.height - y - 10, implicitHeight)
        radius: Nexa.Theme.radiusMd
        color: Nexa.Theme.surfaceContainerHigh
        border.width: Nexa.Theme.borderThin
        border.color: Nexa.Theme.borderStrong

        Rectangle {
            anchors.fill: parent
            anchors.margins: parent.border.width
            radius: Math.max(0, parent.radius - parent.border.width)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Nexa.Theme.edgeHighlight }
                GradientStop { position: 0.5; color: "transparent" }
            }
        }

        ColumnLayout {
            id: locationLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Nexa.Theme.spacingMd
            spacing: Nexa.Theme.spacingSm

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Location"
                    color: Nexa.Theme.text
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeSm
                    font.weight: Nexa.Theme.fontWeightMedium
                }
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: Nexa.Theme.radiusSm
                    color: closeLocationMouse.containsMouse ? Nexa.Theme.hover : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: closeLocationMouse.containsMouse ? Nexa.Theme.text : Nexa.Theme.mutedText
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: Nexa.Theme.iconSm
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

            // Automatic Location Button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: Nexa.Theme.radiusSm
                color: autoMouse.containsMouse ? Nexa.Theme.hover : Nexa.Theme.surface
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 7
                    Text {
                        text: "󰑐"
                        color: Nexa.Theme.primary
                        font.family: Nexa.Theme.iconFontFamily
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Automatic location"
                        color: Nexa.Theme.text
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSizeXs
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

            // Manual City Input
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: Nexa.Theme.radiusSm
                color: Nexa.Theme.surface
                border.width: Nexa.Theme.borderThin
                border.color: cityInput.activeFocus ? Nexa.Theme.primary : Nexa.Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 5
                    spacing: 5

                    Text {
                        text: "󰍉"
                        color: Nexa.Theme.mutedText
                        font.family: Nexa.Theme.iconFontFamily
                    }

                    TextInput {
                        id: cityInput
                        Layout.fillWidth: true
                        text: root.locationQuery
                        color: Nexa.Theme.text
                        selectionColor: Nexa.Theme.primary
                        font.family: Nexa.Theme.fontFamily
                        font.pixelSize: Nexa.Theme.fontSizeXs
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
                        color: Nexa.Theme.primary
                        font.family: Nexa.Theme.iconFontFamily
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setManualLocation(cityInput.text)
                        }
                    }
                }

                Text {
                    visible: cityInput.text.length === 0 && !cityInput.activeFocus
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 30
                    text: "Enter city..."
                    color: Nexa.Theme.mutedText
                    font.family: Nexa.Theme.fontFamily
                    font.pixelSize: Nexa.Theme.fontSizeXs
                }
            }

            ListView {
                id: locationResultsList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(130, contentHeight)
                Layout.maximumHeight: 130
                visible: root.locationResults.length > 0
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
                        radius: Nexa.Theme.radiusPill
                        color: resultsScrollBar.hovered ? Nexa.Theme.primary : Nexa.Theme.mutedText
                        opacity: (resultsScrollBar.active || resultsScrollBar.hovered) ? 0.6 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Nexa.Theme.animationNormal } }
                        Behavior on color { ColorAnimation { duration: Nexa.Theme.animationFast } }
                    }
                    background: null
                }

                delegate: Rectangle {
                    required property var modelData
                    width: locationResultsList.width - (locationResultsList.contentHeight > locationResultsList.height ? 8 : 0)
                    Behavior on width { NumberAnimation { duration: Nexa.Theme.animationFast } }
                    height: 42
                    radius: Nexa.Theme.radiusSm
                    color: resultMouse.containsMouse ? Nexa.Theme.hover : "transparent"

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 1

                        Text {
                            text: modelData.name
                            color: Nexa.Theme.text
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: Nexa.Theme.fontSizeXs
                            font.weight: Nexa.Theme.fontWeightMedium
                            elide: Text.ElideRight
                        }

                        Text {
                            text: {
                                const parts = []
                                if (modelData.admin1) parts.push(modelData.admin1)
                                if (modelData.country) parts.push(modelData.country)
                                return parts.join(", ")
                            }
                            color: Nexa.Theme.mutedText
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: resultMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setManualLocation(modelData.name)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.locationStatus !== ""
                text: root.locationStatus
                color: Nexa.Theme.mutedText
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeXs
                elide: Text.ElideRight
            }
        }
    }

    // Detail Item component
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
                color: Nexa.Theme.primary
                font.family: Nexa.Theme.iconFontFamily
                font.pixelSize: Nexa.Theme.iconSm
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                text: parent.parent.label
                color: Nexa.Theme.mutedText
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeXs
                elide: Text.ElideRight
            }

            Text {
                text: parent.parent.value
                color: Nexa.Theme.text
                font.family: Nexa.Theme.fontFamily
                font.pixelSize: Nexa.Theme.fontSizeXs
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
            }
        }

        Rectangle {
            visible: !parent.last
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Nexa.Theme.divider
        }
    }

    // Forecast Button component
    component ForecastButton: Rectangle {
        property string text: ""
        property bool selected: false
        signal clicked()

        radius: Nexa.Theme.radiusSm
        color: selected ? Nexa.Theme.primary : buttonMouse.containsMouse ? Nexa.Theme.hover : "transparent"

        Text {
            anchors.centerIn: parent
            text: parent.text
            color: parent.selected ? Nexa.Theme.onPrimary : Nexa.Theme.mutedText
            font.family: Nexa.Theme.fontFamily
            font.pixelSize: Nexa.Theme.fontSizeXs
            font.weight: Nexa.Theme.fontWeightMedium
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
