import QtQuick
import QtQuick.Window
import "../package/contents/ui"

// Run with:  qml6 preview/CharacterPreview.qml
// Every scene of the silhouette pair on its own strip, roaming as in the widget.
// Click a strip to cycle it through the scenes and watch the transition; hover
// the pair to be greeted, click it for the treat trick. Temperatures are
// chosen so the mug (<= 10°) and campfire (<= 2°) show up on some strips.
Window {
    width: 440; height: 600
    visible: true
    title: "Umbra Weather character"
    color: "#1b2a3a"

    Column {
        x: 10; y: 10; spacing: 4
        Repeater {
            model: [
                { c: "rain",    n: false, w: 5,  t: 12, l: "rain" },
                { c: "rain",    n: false, w: 30, t: 9,  l: "storm" },
                { c: "snow",    n: false, w: 0,  t: -3, l: "snow" },
                { c: "clear",   n: false, w: 0,  t: 24, l: "sunny" },
                { c: "cloudy",  n: false, w: 0,  t: 6,  l: "calm, 6° (mug)" },
                { c: "cloudy",  n: false, w: 30, t: 1,  l: "windy, 1° (campfire)" },
                { c: "thunder", n: false, w: 0,  t: 15, l: "thunder" },
                { c: "clear",   n: true,  w: 0,  t: 8,  l: "night (dozing / stargazing, never roams)" }
            ]
            Item {
                id: row
                required property var modelData
                width: 420; height: 68
                Rectangle { y: 40; width: 420; height: 28; radius: 8; color: Qt.rgba(0, 0, 0, 0.18) }
                Text { x: 4; y: 44; text: row.modelData.l; color: "#9AA0A6"; font.pixelSize: 9 }
                readonly property var scenes: [
                    { c: "rain", n: false, w: 5, t: 12 }, { c: "rain", n: false, w: 30, t: 9 }, { c: "snow", n: false, w: 0, t: -3 },
                    { c: "clear", n: false, w: 0, t: 24 }, { c: "cloudy", n: false, w: 0, t: 6 }, { c: "cloudy", n: false, w: 30, t: 1 },
                    { c: "thunder", n: false, w: 0, t: 15 }, { c: "clear", n: true, w: 0, t: 8 }
                ]
                property var current: modelData
                MouseArea {   // below the pair, so a click on the pair pets it and a click elsewhere cycles the scene
                    anchors.fill: parent
                    onClicked: {
                        var i = 0
                        while (i < row.scenes.length && (row.scenes[i].c !== row.current.c || row.scenes[i].n !== row.current.n || row.scenes[i].w !== row.current.w)) i++
                        row.current = row.scenes[(i + 1) % row.scenes.length]
                    }
                }
                WeatherCharacter {
                    y: 40 - ground
                    opacity: 0.9
                    minTrackX: 16
                    maxTrackX: Math.max(20, 420 - width - 16)
                    homeX: 120
                    condition: row.current.c
                    isNight: row.current.n
                    windSpeed: row.current.w
                    temperature: row.current.t
                }
            }
        }
    }
}
