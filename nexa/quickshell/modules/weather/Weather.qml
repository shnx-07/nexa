import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "../../theme" as Nexa


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
        anchors.fill: parent

        spacing:
            Nexa.Theme.spacingSm


        // ========================================================
        // LEFT SIDE
        // ========================================================

        ColumnLayout {
            Layout.preferredWidth: 205
            Layout.minimumWidth: 205
            Layout.maximumWidth: 205

            Layout.fillHeight: true

            spacing:
                Nexa.Theme.spacingSm


            // ====================================================
            // CURRENT WEATHER
            // ====================================================

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 160

                radius:
                    Nexa.Theme.radiusLg

                color:
                    Nexa.Theme.cardBackground

                border.width:
                    Nexa.Theme.borderThin

                border.color:
                    Nexa.Theme.border


                RowLayout {
                    anchors.centerIn: parent
                    spacing: 18

                    Text {
                        text:
                            root.hasWeather
                            ? root.weatherIcon(root.weatherData.current.icon)
                            : ""

                        color: Nexa.Theme.primary
                        font.family: Nexa.Theme.iconFontFamily
                        font.pixelSize: 62
                    }

                    ColumnLayout {
                        spacing: 3

                        Text {
                            text:
                                root.hasWeather
                                ? root.temperature(root.weatherData.current.temperature)
                                : "--°"

                            color: Nexa.Theme.text
                            font.family: Nexa.Theme.fontFamily
                            font.pixelSize: 44
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text:
                                root.hasWeather
                                ? root.temperature(root.weatherData.current.min_temperature)
                                    + " / "
                                    + root.temperature(root.weatherData.current.max_temperature)
                                : "-- / --"

                            color: Nexa.Theme.primary
                            font.pixelSize: 13
                        }

                        Text {
                            text:
                                root.hasWeather
                                ? root.weatherData.current.condition
                                : root.loading
                                    ? "Loading weather..."
                                    : "Weather unavailable"

                            color: Nexa.Theme.text
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            id: locationButton

                            Layout.preferredHeight: 25
                            Layout.minimumWidth: locationRow.implicitWidth + 14

                            radius: Nexa.Theme.radiusSm

                            color:
                                locationMouse.containsMouse
                                ? Nexa.Theme.hover
                                : "transparent"


                            RowLayout {
                                id: locationRow

                                anchors.centerIn: parent

                                spacing: 5


                                Text {
                                    text: ""

                                    color: Nexa.Theme.primary

                                    font.family:
                                        Nexa.Theme.iconFontFamily

                                    font.pixelSize: 12
                                }


                                Text {
                                    text:
                                        root.locationText()

                                    color:
                                        locationMouse.containsMouse
                                        ? Nexa.Theme.text
                                        : Nexa.Theme.mutedText

                                    font.family:
                                        Nexa.Theme.fontFamily

                                    font.pixelSize: 11
                                }


                                Text {
                                    text:
                                        root.locationEditorOpen
                                        ? ""
                                        : ""

                                    color:
                                        Nexa.Theme.mutedText

                                    font.family:
                                        Nexa.Theme.iconFontFamily

                                    font.pixelSize: 10
                                }
                            }


                            MouseArea {
                                id: locationMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked:
                                    root.locationEditorOpen =
                                        !root.locationEditorOpen
                            }
                        }
                    }
                }
            }


            // ====================================================
            // DETAILS
            // ====================================================

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true

                radius:
                    Nexa.Theme.radiusLg

                color:
                    Nexa.Theme.cardBackground

                border.width:
                    Nexa.Theme.borderThin

                border.color:
                    Nexa.Theme.border


                ColumnLayout {
                    anchors.fill: parent

                    anchors.margins:
                        Nexa.Theme.spacingMd

                    spacing: 0


                    WeatherDetailRow {
                        icon: "󰔄"
                        label: "Temperature Min"

                        value:
                            root.hasWeather
                            ? root.temperature(
                                root.weatherData.details.temperature_min
                            )
                            : "--"
                    }


                    WeatherDetailRow {
                        icon: "󰔅"
                        label: "Temperature Max"

                        value:
                            root.hasWeather
                            ? root.temperature(
                                root.weatherData.details.temperature_max
                            )
                            : "--"
                    }


                    WeatherDetailRow {
                        icon: "󰖝"
                        label: "Wind"

                        value:
                            root.hasWeather
                            ? (
                                root.numberText(
                                    root.weatherData.details.wind_speed
                                )
                                + " km/h "
                                + root.weatherData.details.wind_direction
                            )
                            : "--"
                    }


                    WeatherDetailRow {
                        icon: "󰖛"
                        label: "Sunrise"

                        value:
                            root.hasWeather
                            ? root.weatherData.details.sunrise
                            : "--"
                    }


                    WeatherDetailRow {
                        icon: "󰖚"
                        label: "Sunset"

                        value:
                            root.hasWeather
                            ? root.weatherData.details.sunset
                            : "--"
                    }


                    WeatherDetailRow {
                        icon: "󰓁"
                        label: "Elevation"

                        value:
                            root.hasWeather
                            ? (
                                root.numberText(
                                    root.weatherData.details.elevation
                                )
                                + " m"
                            )
                            : "--"
                    }


                    WeatherDetailRow {
                        icon: "󰖨"
                        label: "UV Index"

                        value:
                            root.hasWeather
                            ? Number(
                                root.weatherData.details.uv_index
                            ).toFixed(1)
                            : "--"
                    }


                    WeatherDetailRow {
                        icon: "󰥔"
                        label: "Timezone"

                        value:
                            root.hasWeather
                            ? root.weatherData.details.timezone_abbreviation
                            : "--"

                        separatorVisible:
                            false
                    }
                }
            }
        }


        // ========================================================
        // FORECAST CARD
        // ========================================================

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true

            radius:
                Nexa.Theme.radiusLg

            color:
                Nexa.Theme.cardBackground

            border.width:
                Nexa.Theme.borderThin

            border.color:
                Nexa.Theme.border


            ColumnLayout {
                anchors.fill: parent

                anchors.margins:
                    Nexa.Theme.spacingMd

                spacing:
                    Nexa.Theme.spacingSm


                // =================================================
                // HEADER
                // =================================================

                RowLayout {
                    Layout.fillWidth: true

                    spacing:
                        Nexa.Theme.spacingXs


                    Rectangle {
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 32

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

                                onClicked:
                                    root.forecastMode = 0
                            }

                            ForecastButton {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                text: "Hourly"
                                selected: root.forecastMode === 1

                                onClicked:
                                    root.forecastMode = 1
                            }
                        }
                    }


                    Item {
                        Layout.fillWidth: true
                    }


                    Rectangle {
                        Layout.preferredWidth:
                            Nexa.Theme.controlHeightSm

                        Layout.preferredHeight:
                            Nexa.Theme.controlHeightSm

                        radius:
                            Nexa.Theme.radiusSm

                        color:
                            refreshMouse.containsMouse
                            ? Nexa.Theme.hoverStrong
                            : "transparent"


                        Text {
                            anchors.centerIn: parent

                            text:
                                "󰑐"

                            color:
                                root.loading
                                ? Nexa.Theme.primary
                                : Nexa.Theme.mutedText

                            font.family:
                                Nexa.Theme.iconFontFamily

                            font.pixelSize:
                                Nexa.Theme.iconSm

                            rotation:
                                root.loading
                                ? 360
                                : 0


                            Behavior on rotation {
                                NumberAnimation {
                                    duration:
                                        Nexa.Theme.animationSlow

                                    easing.type:
                                        Nexa.Theme.easingStandard
                                }
                            }
                        }


                        MouseArea {
                            id: refreshMouse

                            anchors.fill: parent

                            hoverEnabled: true

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked:
                                root.refreshWeather()
                        }
                    }
                }


                // =================================================
                // DAILY
                // =================================================

                ListView {
                    id: dailyList

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    visible:
                        root.forecastMode === 0

                    clip: true

                    model:
                        root.hasWeather
                        ? root.weatherData.daily
                        : []


                    delegate: Item {
                        required property var modelData

                        width:
                            dailyList.width

                        height: 62


                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 2
                            anchors.rightMargin: 2

                            spacing: 4


                            Text {
                                Layout.preferredWidth: 26

                                text:
                                    root.dayName(
                                        modelData.date
                                    )

                                color:
                                    Nexa.Theme.mutedText

                                font.family:
                                    Nexa.Theme.fontFamily

                                font.pixelSize:
                                    Nexa.Theme.fontSizeXs
                            }


                            Text {
                                Layout.preferredWidth: 24

                                text:
                                    root.weatherIcon(
                                        modelData.icon
                                    )

                                color:
                                    Nexa.Theme.primary

                                font.family:
                                    Nexa.Theme.iconFontFamily

                                font.pixelSize:
                                    Nexa.Theme.iconLg

                                horizontalAlignment:
                                    Text.AlignHCenter
                            }


                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0

                                spacing: Nexa.Theme.spacing2Xs

                                Text {
                                    Layout.fillWidth: true

                                    text:
                                        root.temperature(modelData.min_temperature)
                                        + " / "
                                        + root.temperature(modelData.max_temperature)

                                    color: Nexa.Theme.text

                                    font.family: Nexa.Theme.fontFamily
                                    font.pixelSize: Nexa.Theme.fontSizeXs
                                    font.weight: Nexa.Theme.fontWeightMedium

                                    elide: Text.ElideRight
                                }


                                Text {
                                    Layout.fillWidth: true

                                    text:
                                        modelData.condition

                                    color:
                                        Nexa.Theme.mutedText

                                    font.family:
                                        Nexa.Theme.fontFamily

                                    font.pixelSize:
                                        Nexa.Theme.fontSizeXs

                                    elide:
                                        Text.ElideRight
                                }
                            }


                            Text {
                                Layout.preferredWidth: 28
                                Layout.maximumWidth: 28

                                text:
                                    Math.round(modelData.precipitation_probability)
                                    + "%"

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

                            color:
                                Nexa.Theme.divider
                        }
                    }
                }


                // =================================================
                // HOURLY
                // =================================================

                ListView {
                    id: hourlyList

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    visible:
                        root.forecastMode === 1

                    clip: true

                    model:
                        root.hasWeather
                        ? root.weatherData.hourly
                        : []


                    delegate: Item {
                        required property var modelData

                        width:
                            hourlyList.width

                        height: 60


                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 2
                            anchors.rightMargin: 2

                            spacing: 4


                            Text {
                                Layout.preferredWidth: 34

                                text:
                                    root.hourlyTime(
                                        modelData.time
                                    )

                                color:
                                    Nexa.Theme.mutedText

                                font.family:
                                    Nexa.Theme.fontFamily

                                font.pixelSize:
                                    Nexa.Theme.fontSizeXs
                            }


                            Text {
                                Layout.preferredWidth: 24

                                text:
                                    root.weatherIcon(
                                        modelData.icon
                                    )

                                color:
                                    Nexa.Theme.primary

                                font.family:
                                    Nexa.Theme.iconFontFamily

                                font.pixelSize:
                                    Nexa.Theme.iconLg

                                horizontalAlignment:
                                    Text.AlignHCenter
                            }


                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0

                                spacing:
                                    Nexa.Theme.spacing2Xs


                                Text {
                                    text:
                                        root.temperature(
                                            modelData.temperature
                                        )

                                    color:
                                        Nexa.Theme.text

                                    font.family:
                                        Nexa.Theme.fontFamily

                                    font.pixelSize:
                                        Nexa.Theme.fontSizeSm

                                    font.weight:
                                        Nexa.Theme.fontWeightMedium
                                }


                                Text {
                                    Layout.fillWidth: true

                                    text:
                                        modelData.condition

                                    color:
                                        Nexa.Theme.mutedText

                                    font.family:
                                        Nexa.Theme.fontFamily

                                    font.pixelSize:
                                        Nexa.Theme.fontSizeXs

                                    elide:
                                        Text.ElideRight
                                }
                            }


                            Text {
                                Layout.preferredWidth: 28
                                Layout.maximumWidth: 28
                                horizontalAlignment: Text.AlignRight

                                text:
                                    Math.round(modelData.precipitation_probability)
                                    + "%"

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

                            color:
                                Nexa.Theme.divider
                        }
                    }
                }


                Text {
                    Layout.fillWidth: true

                    visible:
                        root.errorText !== ""

                    text:
                        root.errorText

                    wrapMode:
                        Text.Wrap

                    color:
                        Nexa.Theme.error

                    font.family:
                        Nexa.Theme.fontFamily

                    font.pixelSize:
                        Nexa.Theme.fontSizeXs
                }
            }
        }
    }


    // ============================================================
    // LOCATION EDITOR
    // ============================================================

    Rectangle {
        id: locationPopup

        visible:
            root.locationEditorOpen

        z: 1000

        width: 220
        height: 300

        x: 8
        y: 125

        radius:
            Nexa.Theme.radiusLg

        color:
            Nexa.Theme.cardBackground

        border.width:
            Nexa.Theme.borderThin

        border.color:
            Nexa.Theme.border


        ColumnLayout {
            anchors.fill: parent

            anchors.margins:
                Nexa.Theme.spacingMd

            spacing:
                Nexa.Theme.spacingSm


            RowLayout {
                Layout.fillWidth: true


                Text {
                    Layout.fillWidth: true

                    text: "Location"

                    color:
                        Nexa.Theme.text

                    font.family:
                        Nexa.Theme.fontFamily

                    font.pixelSize:
                        Nexa.Theme.fontSizeSm

                    font.weight:
                        Nexa.Theme.fontWeightMedium
                }


                Text {
                    text: ""

                    color:
                        Nexa.Theme.mutedText

                    font.family:
                        Nexa.Theme.iconFontFamily


                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            root.locationEditorOpen = false
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
                    Nexa.Theme.radiusSm

                color:
                    autoMouse.containsMouse
                    ? Nexa.Theme.hover
                    : Nexa.Theme.surface


                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8

                    spacing: 7


                    Text {
                        text: ""

                        color:
                            Nexa.Theme.primary

                        font.family:
                            Nexa.Theme.iconFontFamily
                    }


                    Text {
                        Layout.fillWidth: true

                        text: "Automatic location"

                        color:
                            Nexa.Theme.text

                        font.family:
                            Nexa.Theme.fontFamily

                        font.pixelSize:
                            Nexa.Theme.fontSizeXs
                    }
                }


                MouseArea {
                    id: autoMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked:
                        root.useAutomaticLocation()
                }
            }


            // --------------------------------------------------------
            // MANUAL CITY
            // --------------------------------------------------------

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                radius:
                    Nexa.Theme.radiusSm

                color:
                    Nexa.Theme.surface

                border.width:
                    Nexa.Theme.borderThin

                border.color:
                    cityInput.activeFocus
                    ? Nexa.Theme.primary
                    : Nexa.Theme.border


                RowLayout {
                    anchors.fill: parent

                    anchors.leftMargin: 8
                    anchors.rightMargin: 5

                    spacing: 5


                    Text {
                        text: ""

                        color:
                            Nexa.Theme.mutedText

                        font.family:
                            Nexa.Theme.iconFontFamily
                    }


                    TextInput {
                        id: cityInput

                        Layout.fillWidth: true

                        text:
                            root.locationQuery

                        color:
                            Nexa.Theme.text

                        selectionColor:
                            Nexa.Theme.primary

                        font.family:
                            Nexa.Theme.fontFamily

                        font.pixelSize:
                            Nexa.Theme.fontSizeXs

                        clip: true


                        onTextChanged: {
                            root.locationQuery = text

                            locationSearchTimer.restart()
                        }


                        Keys.onReturnPressed:
                            root.setManualLocation(text)
                    }


                    Text {
                        text: ""

                        color:
                            Nexa.Theme.primary

                        font.family:
                            Nexa.Theme.iconFontFamily


                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked:
                                root.setManualLocation(
                                    cityInput.text
                                )
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
                        Nexa.Theme.mutedText

                    font.family:
                        Nexa.Theme.fontFamily

                    font.pixelSize:
                        Nexa.Theme.fontSizeXs
                }
            }


            ListView {
                id: locationResultsList

                Layout.fillWidth: true
                Layout.fillHeight: true

                visible:
                    root.locationResults.length > 0

                clip: true

                spacing: 3

                model:
                    root.locationResults

                delegate: Rectangle {
                    required property var modelData

                    width:
                        locationResultsList.width

                    height: 42

                    radius:
                        Nexa.Theme.radiusSm

                    color:
                        resultMouse.containsMouse
                        ? Nexa.Theme.hover
                        : "transparent"


                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        spacing: 1


                        Text {
                            text:
                                modelData.name

                            color:
                                Nexa.Theme.text

                            font.family:
                                Nexa.Theme.fontFamily

                            font.pixelSize:
                                Nexa.Theme.fontSizeXs

                            font.weight:
                                Nexa.Theme.fontWeightMedium
                        }


                        Text {
                            width: parent.width

                            text: {
                                let parts = []

                                if (modelData.admin1)
                                    parts.push(modelData.admin1)

                                if (modelData.country)
                                    parts.push(modelData.country)

                                return parts.join(", ")
                            }

                            color:
                                Nexa.Theme.mutedText

                            font.family:
                                Nexa.Theme.fontFamily

                            font.pixelSize:
                                10

                            elide:
                                Text.ElideRight
                        }
                    }


                    MouseArea {
                        id: resultMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            root.setManualLocation(
                                modelData.name
                            )
                        }
                    }
                }
            }


            Text {
                Layout.fillWidth: true

                visible:
                    root.locationStatus !== ""

                text:
                    root.locationStatus

                color:
                    Nexa.Theme.mutedText

                font.family:
                    Nexa.Theme.fontFamily

                font.pixelSize:
                    Nexa.Theme.fontSizeXs

                elide:
                    Text.ElideRight
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
        Layout.preferredHeight: 34
        Layout.minimumHeight: 34
        Layout.maximumHeight: 34


        RowLayout {
            anchors.fill: parent

            spacing:
                Nexa.Theme.spacingSm


            Text {
                Layout.preferredWidth:
                    Nexa.Theme.iconLg

                text:
                    parent.parent.icon

                color:
                    Nexa.Theme.primary

                font.family:
                    Nexa.Theme.iconFontFamily

                font.pixelSize:
                    Nexa.Theme.iconSm

                horizontalAlignment:
                    Text.AlignHCenter
            }


            Text {
                Layout.fillWidth: true

                text:
                    parent.parent.label

                color:
                    Nexa.Theme.mutedText

                font.family:
                    Nexa.Theme.fontFamily

                font.pixelSize:
                    Nexa.Theme.fontSizeXs
            }


            Text {
                text:
                    parent.parent.value

                color:
                    Nexa.Theme.text

                font.family:
                    Nexa.Theme.fontFamily

                font.pixelSize:
                    Nexa.Theme.fontSizeXs

                font.weight:
                    Nexa.Theme.fontWeightMedium
            }
        }


        Rectangle {
            visible:
                parent.separatorVisible

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            height: 1

            color:
                Nexa.Theme.divider
        }
    }


    // ============================================================
    // FORECAST BUTTON
    // ============================================================

    component ForecastButton: Rectangle {
        property string text: ""
        property bool selected: false

        signal clicked()

        radius: Nexa.Theme.radiusSm

        color:
            selected
            ? Nexa.Theme.primary
            : buttonMouse.containsMouse
                ? Nexa.Theme.hover
                : "transparent"

        Text {
            anchors.centerIn: parent

            text: parent.text

            color:
                parent.selected
                ? Nexa.Theme.onPrimary
                : Nexa.Theme.mutedText

            font.family: Nexa.Theme.fontFamily
            font.pixelSize: Nexa.Theme.fontSizeXs
            font.weight: Nexa.Theme.fontWeightMedium
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked:
                parent.clicked()
        }
    }
}


