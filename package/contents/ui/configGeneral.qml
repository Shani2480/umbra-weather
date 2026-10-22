import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "code/weather.js" as Weather

KCM.SimpleKCM {
    id: page

    property alias cfg_updateIntervalMinutes: intervalSpin.value
    property alias cfg_translucentDesktopBackground: translucentCheck.checked
    property alias cfg_enableBackgroundAnimations: animationsCheck.checked
    property alias cfg_showWeatherCharacter: characterCheck.checked
    property alias cfg_locationName: nameField.text
    property alias cfg_latitude: latSpin.realValue
    property alias cfg_longitude: lonSpin.realValue
    property string cfg_iconStyle
    property string cfg_iconStyleDefault
    property string cfg_temperatureUnit
    property string cfg_temperatureUnitDefault
    property string cfg_windSpeedUnit
    property string cfg_windSpeedUnitDefault

    // Geocoding state for the location field. Typing a place name looks it up
    // on Open-Meteo; the first match sets the coordinates straight away so
    // "type a city, press Apply" is enough, and the list below lets the user
    // pick a different match.
    property var results: []
    property bool busy: false
    property string resolvedName: ""      // display name of the match whose coordinates are in use
    property string lastQuery: ""
    property bool detecting: false
    property string detectError: ""

    function detect() {
        page.detecting = true
        page.detectError = ""
        Weather.detectLocation(function (place) {
            page.detecting = false
            page.results = []
            page.lastQuery = ""
            latSpin.realValue = place.latitude
            lonSpin.realValue = place.longitude
            nameField.text = place.displayName
            page.resolvedName = i18n("%1 (approximate, from your IP address)", place.displayName)
        }, function (message) {
            page.detecting = false
            page.detectError = message
        })
    }

    function lookup(query) {
        var q = query.trim()
        page.lastQuery = q
        if (q.length < 2) { page.results = []; page.busy = false; return }
        page.busy = true
        Weather.searchLocation(q, function (list) {
            if (q !== page.lastQuery) return          // stale reply
            page.results = list
            page.busy = false
            if (list.length > 0) page.use(0, false)
            else page.resolvedName = ""
        })
    }
    // Take the coordinates of match i; with rename, also replace the typed text.
    function use(i, rename) {
        if (i < 0 || i >= results.length) return
        var r = results[i]
        latSpin.realValue = r.latitude
        lonSpin.realValue = r.longitude
        page.resolvedName = r.displayName
        if (rename) nameField.text = r.country !== "" ? r.name + ", " + r.country : r.name
    }

    Timer { id: debounce; interval: 350; onTriggered: { page.detectError = ""; page.lookup(nameField.text) } }

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: i18n("Location:")
            spacing: Kirigami.Units.smallSpacing
            QQC2.TextField {
                id: nameField
                placeholderText: i18n("Type a city name…")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                // only user edits search; the initial load from config does not
                onTextEdited: debounce.restart()
                Keys.onReturnPressed: { debounce.stop(); page.lookup(text) }
                Keys.onEnterPressed: { debounce.stop(); page.lookup(text) }
            }
            QQC2.ToolButton {
                icon.name: "mark-location"
                text: i18n("Detect")
                enabled: !page.detecting
                QQC2.ToolTip.text: i18n("Approximate location from your internet connection")
                QQC2.ToolTip.visible: hovered
                onClicked: page.detect()
            }
        }
        QQC2.Label {
            visible: text !== ""
            Layout.preferredWidth: nameField.Layout.preferredWidth
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: page.detecting ? i18n("Detecting your location…")
                : page.detectError !== "" ? page.detectError
                : page.busy ? i18n("Searching…")
                : page.results.length === 0 && page.lastQuery.length >= 2 ? i18n("No places found for “%1”. Coordinates unchanged.", page.lastQuery)
                : page.resolvedName !== "" ? i18n("Using: %1", page.resolvedName)
                : ""
        }
        ColumnLayout {
            visible: page.results.length > 1
            spacing: 0
            Layout.preferredWidth: nameField.Layout.preferredWidth
            Repeater {
                model: page.results
                QQC2.ItemDelegate {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    text: modelData.displayName
                    highlighted: modelData.displayName === page.resolvedName
                    onClicked: page.use(index, true)
                }
            }
        }
        Item { Kirigami.FormData.isSection: true }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Temperature:")
            textRole: "text"
            valueRole: "value"
            model: [ { text: i18n("Celsius (°C)"), value: "celsius" }, { text: i18n("Fahrenheit (°F)"), value: "fahrenheit" } ]
            currentIndex: Math.max(0, indexOfValue(page.cfg_temperatureUnit))
            onActivated: page.cfg_temperatureUnit = currentValue
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Wind speed:")
            textRole: "text"
            valueRole: "value"
            model: [ { text: i18n("km/h"), value: "kmh" }, { text: i18n("mph"), value: "mph" },
                     { text: i18n("m/s"), value: "ms" }, { text: i18n("Knots"), value: "kn" } ]
            currentIndex: Math.max(0, indexOfValue(page.cfg_windSpeedUnit))
            onActivated: page.cfg_windSpeedUnit = currentValue
        }
        Item { Kirigami.FormData.isSection: true }
        QQC2.SpinBox {
            id: latSpin
            Kirigami.FormData.label: i18n("Latitude:")
            property real realValue
            from: -900000; to: 900000
            stepSize: 100
            value: Math.round(realValue * 10000)
            onValueModified: realValue = value / 10000
            textFromValue: (v) => (v / 10000).toFixed(4)
            valueFromText: (t) => Math.round(parseFloat(t) * 10000)
        }
        QQC2.SpinBox {
            id: lonSpin
            Kirigami.FormData.label: i18n("Longitude:")
            property real realValue
            from: -1800000; to: 1800000
            stepSize: 100
            value: Math.round(realValue * 10000)
            onValueModified: realValue = value / 10000
            textFromValue: (v) => (v / 10000).toFixed(4)
            valueFromText: (t) => Math.round(parseFloat(t) * 10000)
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Icon style:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Glass 3D (volumetric)"), value: "glass3d" },
                { text: i18n("Hand-drawn (animated)"), value: "handdrawn" },
                { text: i18n("Weather Underground, white"), value: "white" },
                { text: i18n("Weather Underground, black"), value: "black" },
                { text: i18n("Weather Underground, solid white"), value: "solid-white" },
                { text: i18n("Weather Underground, solid black"), value: "solid-black" }
            ]
            currentIndex: indexOfValue(page.cfg_iconStyle)
            onActivated: page.cfg_iconStyle = currentValue
        }
        QQC2.SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: i18n("Update every (min):")
            from: 5; to: 180
        }
        QQC2.CheckBox {
            id: translucentCheck
            Kirigami.FormData.label: i18n("On the desktop:")
            text: i18n("Translucent card background")
        }
        QQC2.CheckBox {
            id: animationsCheck
            Kirigami.FormData.label: i18n("Hero card:")
            text: i18n("Enable subtle background weather animations")
        }
        QQC2.CheckBox {
            id: characterCheck
            text: i18n("Show interactive weather character in today's forecast")
            enabled: animationsCheck.checked
        }
    }
}
