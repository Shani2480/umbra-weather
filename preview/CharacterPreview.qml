import QtQuick
import QtQuick.Window
import "../package/contents/ui"

// Run with:  qml6 preview/CharacterPreview.qml
// Every scene of the silhouette pair on its own strip, roaming as in the widget.
// Click a strip to cycle it through the scenes and watch the transition.
Window {
    width: 440; height: 600
    visible: true
    title: "Umbra Weather character"
    color: "#1b2a3a"

    Column {
        x: 10; y: 10; spacing: 4
        Repeater {
            model: [
                { c: "rain",    n: false, w: 5,  l: "rain" },
                { c: "rain",    n: false, w: 30, l: "storm" },
                { c: "snow",    n: false, w: 0,  l: "snow" },
                { c: "clear",   n: false, w: 0,  l: "sunny" },
                { c: "cloudy",  n: false, w: 0,  l: "calm" },
                { c: "cloudy",  n: false, w: 30, l: "windy" },
                { c: "thunder", n: false, w: 0,  l: "thunder" },
                { c: "clear",   n: true,  w: 0,  l: "night (asleep, never roams)" }
            ]
            Item {
                id: row
                required property var modelData
                width: 420; height: 68
                Rectangle { y: 40; width: 420; height: 28; radius: 8; color: Qt.rgba(0, 0, 0, 0.18) }
                Text { x: 4; y: 44; text: row.modelData.l; color: "#9AA0A6"; font.pixelSize: 9 }
                readonly property var scenes: [
                    { c: "rain", n: false, w: 5 }, { c: "rain", n: false, w: 30 }, { c: "snow", n: false, w: 0 },
                    { c: "clear", n: false, w: 0 }, { c: "cloudy", n: false, w: 0 }, { c: "cloudy", n: false, w: 30 },
                    { c: "thunder", n: false, w: 0 }, { c: "clear", n: true, w: 0 }
                ]
                property var current: modelData
                WeatherCharacter {
                    y: 40 - ground
                    opacity: 0.9
                    minTrackX: 16
                    maxTrackX: Math.max(20, 420 - width - 16)
                    homeX: 120
                    condition: row.current.c
                    isNight: row.current.n
                    windSpeed: row.current.w
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var i = 0
                        while (i < row.scenes.length && (row.scenes[i].c !== row.current.c || row.scenes[i].n !== row.current.n || row.scenes[i].w !== row.current.w)) i++
                        row.current = row.scenes[(i + 1) % row.scenes.length]
                    }
                }
            }
        }
    }
}
