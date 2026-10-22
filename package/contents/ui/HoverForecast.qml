import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import "code/weather.js" as Weather

// Glass tooltip card: today's summary on top, a 3-hourly track underneath.
Rectangle {
    id: content

    property var weather: null
    property string message: ""
    property bool active: false
    property string iconStyle: "handdrawn"

    readonly property var slots: weather ? Weather.upcomingSlots(weather, 6, 3) : []
    readonly property color primary: "#FFFFFF"
    readonly property color secondary: "#9AA0A6"

    implicitWidth: 280
    implicitHeight: column.implicitHeight + 24
    radius: 10
    color: Qt.rgba(0x18 / 255, 0x1B / 255, 0x22 / 255, 0.9)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        PlasmaComponents3.Label {
            visible: !content.weather
            text: content.message !== "" ? content.message : i18n("Loading…")
            color: content.secondary
            font.pixelSize: 12
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

        // ---- current summary ----
        RowLayout {
            visible: !!content.weather
            spacing: 12
            Layout.fillWidth: true

            WeatherIcon {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                Layout.alignment: Qt.AlignVCenter
                condition: content.weather ? content.weather.current.condition : "cloudy"
                code: content.weather ? content.weather.current.code : -1
                iconStyle: content.iconStyle
                isDay: content.weather ? content.weather.current.isDay : true
                running: content.active
            }
            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: content.weather ? Math.round(content.weather.current.temp) + "°" : ""
                    color: content.primary
                    font.pixelSize: 26
                    font.bold: true
                }
                PlasmaComponents3.Label {
                    text: content.weather
                        ? content.weather.current.text + " • "
                          + i18n("Feels like %1°", Math.round(content.weather.current.feelsLike))
                        : ""
                    color: content.secondary
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    text: content.weather ? i18n("↑ %1°  ↓ %2°",
                                                 Math.round(content.weather.daily[0].max),
                                                 Math.round(content.weather.daily[0].min)) : ""
                    color: "#E0E0E0"
                    font.pixelSize: 12
                }
            }
        }

        Rectangle {
            visible: !!content.weather
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // ---- 3-hourly track ----
        RowLayout {
            id: track
            visible: !!content.weather
            spacing: 0
            Layout.fillWidth: true

            Repeater {
                model: content.slots
                ColumnLayout {
                    id: slot
                    required property var modelData
                    spacing: 3
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1

                    PlasmaComponents3.Label {
                        text: Qt.formatTime(slot.modelData.time, "HH:mm")
                        color: "#80868B"
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true   // lets the column stretch to its share of the row
                    }
                    WeatherIcon {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        Layout.alignment: Qt.AlignHCenter
                        condition: slot.modelData.condition
                        code: slot.modelData.code
                        iconStyle: content.iconStyle
                        isDay: slot.modelData.isDay
                    }
                    PlasmaComponents3.Label {
                        text: Math.round(slot.modelData.temp) + "°"
                        color: content.primary
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
