import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../package/contents/ui"

// All icon conditions, day and night, using the widget's real WeatherIcon.
Rectangle {
    id: gallery

    property bool dark: true
    property bool animate: true
    property int iconSize: 96
    property string style: "glass3d"

    readonly property var conditions: [
        { condition: "clear",   code: 0,  label: "Clear" },
        { condition: "partly",  code: 2,  label: "Partly cloudy" },
        { condition: "cloudy",  code: 3,  label: "Cloudy" },
        { condition: "fog",     code: 45, label: "Fog" },
        { condition: "rain",    code: 63, label: "Rain" },
        { condition: "snow",    code: 73, label: "Snow" },
        { condition: "thunder", code: 95, label: "Thunderstorm" }
    ]

    implicitWidth: 980
    implicitHeight: 520
    color: dark ? "#1f2327" : "#eff0f1"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            spacing: 20
            Label { text: "Icon style"; color: gallery.dark ? "#fcfcfc" : "#232629" }
            ComboBox {
                model: ["glass3d", "handdrawn", "white", "black", "solid-white", "solid-black"]
                onActivated: gallery.style = currentText
            }
            Label { text: "Animate"; color: gallery.dark ? "#fcfcfc" : "#232629" }
            Switch { checked: gallery.animate; onToggled: gallery.animate = checked }
            Label { text: "Dark background"; color: gallery.dark ? "#fcfcfc" : "#232629" }
            Switch { checked: gallery.dark; onToggled: gallery.dark = checked }
            Label { text: "Size"; color: gallery.dark ? "#fcfcfc" : "#232629" }
            Slider { from: 24; to: 140; value: gallery.iconSize; onMoved: gallery.iconSize = value }
        }

        Repeater {
            model: [true, false]
            RowLayout {
                id: dayRow
                required property bool modelData
                spacing: 16
                Label {
                    text: dayRow.modelData ? "Day" : "Night"
                    Layout.preferredWidth: 48
                    color: gallery.dark ? "#bdc3c7" : "#4d4d4d"
                }
                Repeater {
                    model: gallery.conditions
                    ColumnLayout {
                        id: cell
                        required property var modelData
                        spacing: 6
                        WeatherIcon {
                            Layout.preferredWidth: gallery.iconSize
                            Layout.preferredHeight: gallery.iconSize
                            Layout.alignment: Qt.AlignHCenter
                            condition: cell.modelData.condition
                            code: cell.modelData.code
                            isDay: dayRow.modelData
                            iconStyle: gallery.style
                            running: gallery.animate
                        }
                        Label {
                            text: cell.modelData.label
                            Layout.alignment: Qt.AlignHCenter
                            color: gallery.dark ? "#bdc3c7" : "#4d4d4d"
                        }
                    }
                }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
