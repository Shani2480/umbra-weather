import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "code/weather.js" as Weather

PlasmoidItem {
    id: root

    property var weather: null          // parsed Open-Meteo data, see code/weather.js
    property string errorText: ""
    property bool pulsing: false        // periodic "attention" animation
    property string lastCondition: ""   // condition category of the previous fetch
    property int conditionChangeSerial: 0   // bumped when the category changes; the panel pulses on it
    property bool pinned: false         // keep the expanded view open on focus loss
    property bool forecastCollapsed: false

    readonly property bool hasData: weather !== null
    // Panels report Horizontal/Vertical; the desktop canvas reports Planar with
    // a Desktop/Floating location. On the desktop the card is shown directly.
    readonly property bool onDesktop: Plasmoid.location === PlasmaCore.Types.Desktop
                                   || Plasmoid.location === PlasmaCore.Types.Floating
                                   || Plasmoid.formFactor === PlasmaCore.Types.Planar
                                   || Plasmoid.formFactor === PlasmaCore.Types.MediaCenter
    readonly property string tempText: hasData ? Math.round(weather.current.temp) + "°" : "--°"

    preferredRepresentation: onDesktop ? fullRepresentation : compactRepresentation
    // Both popups draw their own glass surfaces (FullView, HoverForecast).
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    hideOnWindowDeactivate: !pinned
    // The built-in tooltip is replaced by HoverPopup
    toolTipMainText: ""
    toolTipSubText: ""

    function refresh() {
        Weather.fetchWeather(Plasmoid.configuration.latitude, Plasmoid.configuration.longitude,
            { temperature: Plasmoid.configuration.temperatureUnit, wind: Plasmoid.configuration.windSpeedUnit },
            function (data) {
                var condition = data.current.condition
                // Pulse only on a category change, not on the first fetch after login.
                if (root.lastCondition !== "" && condition !== root.lastCondition) {
                    root.conditionChangeSerial++
                    root.pulsing = true
                    pulseStop.restart()
                }
                root.lastCondition = condition
                root.weather = data
                root.errorText = ""
            },
            function (err) {
                root.errorText = i18n("Weather unavailable (%1)", err)
                retryTimer.restart()
            })
    }

    Component.onCompleted: refresh()

    // Coalesce the two coordinate changes of a location pick into one fetch.
    Timer { id: refreshDebounce; interval: 100; onTriggered: root.refresh() }
    Connections {
        target: Plasmoid.configuration
        function onLatitudeChanged() { refreshDebounce.restart() }
        function onLongitudeChanged() { refreshDebounce.restart() }
        function onTemperatureUnitChanged() { refreshDebounce.restart() }
        function onWindSpeedUnitChanged() { refreshDebounce.restart() }
    }

    Timer {
        interval: Plasmoid.configuration.updateIntervalMinutes * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: retryTimer
        interval: 60 * 1000
        onTriggered: root.refresh()
    }

    // Play the icon animation for a few seconds every 5 minutes.
    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: { root.pulsing = true; pulseStop.restart() }
    }
    Timer {
        id: pulseStop
        interval: 8000
        onTriggered: root.pulsing = false
    }

    compactRepresentation: CompactRepresentation {
        weather: root.weather
        errorText: root.errorText
        tempText: root.tempText
        iconStyle: Plasmoid.configuration.iconStyle
        pulsing: root.pulsing
        conditionChangeSerial: root.conditionChangeSerial
        animationsEnabled: Plasmoid.configuration.enableBackgroundAnimations
        expanded: root.expanded
        location: Plasmoid.location
        onToggleRequested: root.expanded = !root.expanded
    }

    fullRepresentation: FullView {
        weather: root.weather
        errorText: root.errorText
        locationName: Plasmoid.configuration.locationName.trim()
        iconStyle: Plasmoid.configuration.iconStyle
        desktopMode: root.onDesktop
        translucent: Plasmoid.configuration.translucentDesktopBackground
        ambientAnimations: Plasmoid.configuration.enableBackgroundAnimations
        showCharacter: Plasmoid.configuration.showWeatherCharacter
        active: root.onDesktop || root.expanded
        pinned: root.pinned
        forecastCollapsed: root.forecastCollapsed
        onRefreshRequested: root.refresh()
        onCloseRequested: root.expanded = false
        onConfigureRequested: Plasmoid.internalAction("configure").trigger()
        onPinRequested: root.pinned = !root.pinned
        onMinimizeRequested: root.forecastCollapsed = !root.forecastCollapsed
        onLocationChosen: (name, latitude, longitude) => {
            Plasmoid.configuration.locationName = name
            Plasmoid.configuration.latitude = latitude
            Plasmoid.configuration.longitude = longitude
        }
    }
}
