import QtQuick
import QtQuick.Window
import "../package/contents/ui"
import "../package/contents/ui/code/weather.js" as Weather

// Run with:  qml6 preview/CardTiers.qml
// The desktop card at its three tiers (full, mid, miniature) on fixture
// weather, so the layout and the roaming pair can be checked without a
// running shell. The temperature labels need a GPU for their shadows and
// stay blank when rendered offscreen.
Window {
    id: root
    width: 520; height: 960
    visible: true
    title: "Umbra Weather card tiers"
    color: "#3a2a4a"

    function fixture(code, isDay) {
        var now = new Date(); now.setMinutes(0, 0, 0)
        var hourly = [], daily = [], codes = [0, 2, 3, 61, 71]
        for (var i = 0; i < 48; i++) {
            var t = new Date(now.getTime() + i * 3600000)
            hourly.push({ time: t, temp: 12 + (i % 5), code: codes[i % 5], condition: Weather.category(codes[i % 5]),
                          isDay: t.getHours() > 7 && t.getHours() < 19 })
        }
        for (var j = 0; j < 8; j++) {
            var d = new Date(now.getTime() + j * 86400000); d.setHours(0, 0, 0, 0)
            daily.push({ date: d, code: 61, condition: "rain", text: "Rain", max: 13 + j, min: 7,
                         sunrise: new Date(d.getTime() + 8 * 3600000), sunset: new Date(d.getTime() + 18.5 * 3600000),
                         uv: 2, rain: 60, wind: 12, precipSum: 3 })
        }
        return { current: { temp: 12, feelsLike: 10, humidity: 80, wind: 9, windDir: 220, pressure: 1012, cloudCover: 40,
                            precipitation: 0, isDay: isDay, code: code, condition: Weather.category(code), text: Weather.describe(code) },
                 hourly: hourly, daily: daily, utcOffsetSeconds: -new Date().getTimezoneOffset() * 60, tempUnit: "°C", windUnit: "km/h", precipUnit: "mm", fetchedAt: new Date() }
    }
    property var wx: fixture(0, true)

    Column {
        x: 10; y: 10; spacing: 12
        Repeater {
            model: [ { w: 480, h: 368, l: "full" }, { w: 480, h: 290, l: "mid" }, { w: 240, h: 150, l: "miniature" } ]
            Item {
                id: slot
                required property var modelData
                width: 500; height: modelData.h + 16
                Text { text: slot.modelData.l; color: "#ddd"; font.pixelSize: 10 }
                FullView {
                    y: 14
                    width: slot.modelData.w; height: slot.modelData.h
                    desktopMode: true
                    active: true
                    locationName: "Dongen"
                    weather: root.wx
                    currentFeelsLike: 10
                    Component.onCompleted: console.log(slot.modelData.l + ":", "mini", isMiniMode, "mid", isMidMode, "full", isFullMode)
                }
            }
        }
    }
}
