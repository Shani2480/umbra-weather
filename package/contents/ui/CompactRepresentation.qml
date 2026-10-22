import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Panel item: animated condition icon + temperature, both scaled to the panel
// thickness. Hovering opens HoverPopup; clicking toggles the expanded view.
MouseArea {
    id: compact

    property var weather: null
    property string errorText: ""
    property string tempText: "--°"
    property string iconStyle: "handdrawn"
    property bool pulsing: false
    property int conditionChangeSerial: 0   // bumped by main.qml when the condition category changes
    property bool animationsEnabled: true
    property bool expanded: false
    property int location: 0            // Plasmoid.location, for the popup placement

    signal toggleRequested()

    readonly property real hpad: Kirigami.Units.smallSpacing
    property bool hoverShown: false

    hoverEnabled: true
    implicitWidth: row.implicitWidth + hpad * 2
    implicitHeight: Kirigami.Units.iconSizes.medium
    Layout.minimumWidth: implicitWidth

    onContainsMouseChanged: {
        if (containsMouse) { hideTimer.stop(); showTimer.restart() }
        else { showTimer.stop(); hideTimer.restart() }
    }
    onClicked: {
        showTimer.stop()
        hoverShown = false
        toggleRequested()
    }

    // One soft tinted pulse behind the row when the condition category changes.
    onConditionChangeSerialChanged: if (animationsEnabled) changePulse.restart()

    Rectangle {
        id: changeBackground
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius
        color: weatherIcon.glowColor
        opacity: 0
    }
    SequentialAnimation {
        id: changePulse
        NumberAnimation { target: changeBackground; property: "opacity"; to: 0.3; duration: 300; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 2500 }
        NumberAnimation { target: changeBackground; property: "opacity"; to: 0; duration: 800; easing.type: Easing.InOutSine }
    }

    Timer { id: showTimer; interval: 300; onTriggered: compact.hoverShown = true }
    Timer { id: hideTimer; interval: 150; onTriggered: compact.hoverShown = false }

    HoverPopup {
        visualParent: compact
        location: compact.location
        weather: compact.weather
        message: compact.errorText
        iconStyle: compact.iconStyle
        shown: compact.hoverShown && !compact.expanded
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: compact.hpad
        anchors.rightMargin: compact.hpad
        spacing: 4

        WeatherIcon {
            id: weatherIcon
            // the full cell height in a system tray (26px); 80% of a thick panel
            Layout.preferredHeight: row.height < 30 ? row.height : Math.min(row.height * 0.8, 48)
            Layout.preferredWidth: Layout.preferredHeight
            Layout.alignment: Qt.AlignVCenter
            condition: compact.weather ? compact.weather.current.condition : "cloudy"
            code: compact.weather ? compact.weather.current.code : -1
            iconStyle: compact.iconStyle
            isDay: compact.weather ? compact.weather.current.isDay : true
            running: compact.containsMouse || compact.pulsing
        }
        PlasmaComponents3.Label {
            text: compact.tempText
            font.pixelSize: Math.max(13, Math.round(row.height * 0.45))
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
