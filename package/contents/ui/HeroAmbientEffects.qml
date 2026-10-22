import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// Subtle, low-opacity ambient weather animations for the hero card. Sits
// behind the card's text and icons. Each effect lives in its own Loader, so a
// condition that is not showing costs nothing, and switching `running` off
// unloads every item, timer and animation at once.
Item {
    id: fx

    property string condition: "cloudy"   // clear / partly / cloudy / fog / rain / snow / thunder
    property bool isNight: false
    property real windSpeed: 0            // km/h
    property bool running: true
    property real cornerRadius: 10

    // 0..1 strength of the wind, saturating at 50 km/h. Drives the rain tilt
    // and fall speed, so wind and rain read as one weather system.
    readonly property real windFactor: Math.min(1.0, windSpeed / 50)
    readonly property bool windy: windSpeed >= 20
    // Wind blows left to right everywhere in the card: ribbons, debris and
    // the sideways drift of the rain all move in +x.
    signal lightning()

    visible: running

    // Clip the animated items to the card's rounded corners.
    layer.enabled: running
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: maskRect
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
    Rectangle {
        id: maskRect
        anchors.fill: parent
        radius: fx.cornerRadius
        visible: false
        layer.enabled: true
    }

    function rnd(a, b) { return a + Math.random() * (b - a) }

    // ---- clear day: warm sunlight breathing ----
    Loader {
        anchors.fill: parent
        active: fx.running && fx.condition === "clear" && !fx.isNight
        sourceComponent: Item {
            Repeater {
                model: [ { x: -0.12, y: -0.35, d: 1.05, ms: 5000 }, { x: 0.02, y: -0.10, d: 0.62, ms: 6500 } ]
                Rectangle {
                    required property var modelData
                    readonly property real d: fx.height * modelData.d
                    x: fx.width * modelData.x
                    y: fx.height * modelData.y
                    width: d; height: d; radius: d / 2
                    color: "#FFFFFF"
                    opacity: 0.08
                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.95; to: 1.15; duration: modelData.ms; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.15; to: 0.95; duration: modelData.ms; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

    // ---- clear night: crescent moon and twinkling stars ----
    Loader {
        anchors.fill: parent
        active: fx.running && fx.condition === "clear" && fx.isNight
        sourceComponent: Item {
            Canvas {   // crescent: a disc with a second disc cut out
                readonly property real r: Math.min(fx.height * 0.42, 60)
                x: fx.width * 0.70; y: -r * 0.35
                width: r * 2; height: r * 2
                opacity: 0.10
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = "#FFFFFF"
                    ctx.beginPath(); ctx.arc(r, r, r, 0, Math.PI * 2); ctx.fill()
                    ctx.globalCompositeOperation = "destination-out"
                    ctx.beginPath(); ctx.arc(r * 1.45, r * 0.75, r * 0.85, 0, Math.PI * 2); ctx.fill()
                }
            }
            Repeater {
                model: 14
                Rectangle {
                    required property int index
                    readonly property int size: index % 3 === 0 ? 3 : 2
                    x: fx.rnd(0.02, 0.98) * fx.width
                    y: fx.rnd(0.03, 0.70) * fx.height
                    width: size; height: size; radius: size / 2
                    color: "#FFFFFF"
                    opacity: 0.1
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 230 }
                        NumberAnimation { to: 0.45; duration: fx.rnd(1000, 2000); easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.1; duration: fx.rnd(1000, 2000); easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

    // ---- partly cloudy / cloudy: drifting cloud silhouettes ----
    Loader {
        anchors.fill: parent
        active: fx.running && (fx.condition === "partly" || fx.condition === "cloudy")
        sourceComponent: Item {
            Rectangle {   // sun or moon glow peeking from behind the clouds
                visible: fx.condition === "partly"
                readonly property real d: fx.height * 0.7
                x: fx.isNight ? fx.width * 0.72 : fx.width * -0.08
                y: -d * 0.30
                width: d; height: d; radius: d / 2
                color: "#FFFFFF"
                opacity: 0.10
            }
            Repeater {
                model: [ { y: 0.12, w: 0.34, h: 0.22, ms: 25000, ph: 0.0,  o: 0.09 },
                         { y: 0.45, w: 0.26, h: 0.18, ms: 31000, ph: 0.45, o: 0.07 },
                         { y: 0.72, w: 0.42, h: 0.24, ms: 35000, ph: 0.75, o: 0.06 } ]
                Rectangle {
                    required property var modelData
                    property real t: 0
                    readonly property real pw: fx.width * modelData.w
                    x: ((t + modelData.ph) % 1) * (fx.width + pw) - pw
                    y: fx.height * modelData.y
                    width: pw; height: fx.height * modelData.h; radius: height / 2
                    color: "#FFFFFF"
                    opacity: modelData.o
                    NumberAnimation on t { from: 0; to: 1; duration: modelData.ms; loops: Animation.Infinite }
                }
            }
        }
    }

    // ---- fog: slow horizontal mist bands ----
    Loader {
        anchors.fill: parent
        active: fx.running && fx.condition === "fog"
        sourceComponent: Item {
            Repeater {
                model: [ { y: 0.18, x: 0.05, w: 0.70, ph: 0 }, { y: 0.40, x: 0.25, w: 0.72, ph: 1 },
                         { y: 0.62, x: -0.05, w: 0.60, ph: 2 }, { y: 0.84, x: 0.30, w: 0.65, ph: 3 } ]
                Rectangle {
                    required property var modelData
                    property real sway: 0
                    x: fx.width * modelData.x + sway
                    y: fx.height * modelData.y
                    width: fx.width * modelData.w; height: 14; radius: 7
                    color: "#FFFFFF"
                    opacity: 0.09
                    SequentialAnimation on sway {
                        loops: Animation.Infinite
                        PauseAnimation { duration: modelData.ph * 900 }
                        NumberAnimation { from: -20; to: 20; duration: 4000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 20; to: -20; duration: 4000; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

    // ---- rain (also the base layer of a thunderstorm), driven by the wind ----
    Loader {
        anchors.fill: parent
        active: fx.running && (fx.condition === "rain" || fx.condition === "thunder")
        sourceComponent: Item {
            Repeater {   // streaks falling diagonally with the wind, each splashing where it lands
                model: 14
                Item {
                    id: dropItem
                    required property int index
                    readonly property real tilt: 12 + fx.windFactor * 30                     // degrees off vertical, up to 42
                    readonly property real speed: 1.0 + fx.windFactor * 0.8
                    readonly property real travel: fx.height + 16
                    readonly property real drift: travel * Math.tan(tilt * Math.PI / 180)   // sideways distance over one fall
                    readonly property real startX: fx.rnd(0, 1) * (fx.width + drift) - drift
                    readonly property real landFall: (fx.height - 8) / travel                // progress at which the streak reaches the bottom
                    readonly property int fallMs: fx.rnd(700, 1100)
                    property real fall: 0                                                   // 0 = above the card, 1 = below
                    property bool splashed: false
                    onFallChanged: {
                        if (fall >= landFall && !splashed) {
                            splashed = true
                            splash.x = streak.x + streak.width / 2                          // land where the streak is now
                            splashAnim.restart()
                        } else if (fall < landFall) {
                            splashed = false
                        }
                    }

                    Rectangle {
                        id: streak
                        x: dropItem.startX + dropItem.fall * dropItem.drift
                        y: -14 + dropItem.fall * dropItem.travel
                        width: 1.5
                        height: 12 + fx.windFactor * 6
                        radius: 1
                        rotation: -dropItem.tilt
                        color: "#B3E5FC"
                        opacity: 0.20
                    }
                    SequentialAnimation on fall {
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 70 }
                        NumberAnimation { from: 0; to: 1; duration: dropItem.fallMs / dropItem.speed; loops: Animation.Infinite }
                    }

                    Item {   // splash: a V-shaped tick that pops up and is carried along by the wind
                        id: splash
                        y: fx.height - 1
                        opacity: 0
                        property real p: 0   // 0..1 progress
                        transform: Translate {
                            x: splash.p * (2 + fx.windFactor * 8)
                            y: -Math.sin(splash.p * Math.PI) * 4
                        }
                        Repeater {
                            model: [ -1, 1 ]
                            Rectangle {
                                required property int modelData
                                x: -1; y: -4
                                width: 2; height: 4; radius: 1
                                color: "#B3E5FC"
                                transformOrigin: Item.Bottom
                                rotation: modelData * (28 + fx.windFactor * 10) + fx.windFactor * 12
                            }
                        }
                        ParallelAnimation {
                            id: splashAnim
                            NumberAnimation { target: splash; property: "p"; from: 0; to: 1; duration: 220; easing.type: Easing.OutQuad }
                            SequentialAnimation {
                                NumberAnimation { target: splash; property: "opacity"; from: 0; to: 0.32; duration: 40 }
                                NumberAnimation { target: splash; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InQuad }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- snow: drifting flakes, near and far ----
    Loader {
        anchors.fill: parent
        active: fx.running && fx.condition === "snow"
        sourceComponent: Item {
            Repeater {
                model: 16
                Rectangle {
                    required property int index
                    readonly property real size: 3 + (index % 4)          // 3..6 px, far to near
                    property real sway: 0
                    readonly property real baseX: fx.rnd(0.02, 0.98) * fx.width
                    x: baseX + sway
                    width: size; height: size; radius: size / 2
                    color: "#FFFFFF"
                    opacity: 0.15 + (size - 3) * 0.066                     // 0.15 .. 0.35
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 180 }
                        NumberAnimation { from: -8; to: fx.height + 4; duration: fx.rnd(3500, 5500); loops: Animation.Infinite }
                    }
                    SequentialAnimation on sway {
                        loops: Animation.Infinite
                        NumberAnimation { from: -6; to: 6; duration: fx.rnd(1200, 2200); easing.type: Easing.InOutSine }
                        NumberAnimation { from: 6; to: -6; duration: fx.rnd(1200, 2200); easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

    // ---- thunderstorm: lightning flash over the rain ----
    Loader {
        anchors.fill: parent
        active: fx.running && fx.condition === "thunder"
        sourceComponent: Rectangle {
            id: flash
            color: "#F3E5F5"
            opacity: 0
            Timer {
                interval: fx.rnd(6000, 13000)
                running: true
                repeat: true
                onTriggered: { fx.lightning(); flashAnim.restart(); interval = fx.rnd(6000, 13000) }
            }
            SequentialAnimation {
                id: flashAnim
                NumberAnimation { target: flash; property: "opacity"; to: 0.16; duration: 60 }
                NumberAnimation { target: flash; property: "opacity"; to: 0.03; duration: 50 }
                NumberAnimation { target: flash; property: "opacity"; to: 0.10; duration: 80 }
                NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 350 }
            }
        }
    }

    // ---- wind: flowing S-wave ribbons and tumbling debris sweeping left to right ----
    Loader {
        anchors.fill: parent
        active: fx.running && fx.windy
        sourceComponent: Item {
            // Three tapered ribbons. Each is a closed path (upper edge out,
            // lower edge back) so it narrows to a point at both ends, filled
            // with a gradient whose bright band travels along the ribbon.
            Repeater {
                model: [ { y: 0.22, w: 0.62, amp: 0.045, th: 2.2, ms: 2600, ph: 0.00 },
                         { y: 0.50, w: 0.50, amp: 0.060, th: 1.8, ms: 3100, ph: 0.38 },
                         { y: 0.76, w: 0.70, amp: 0.040, th: 2.6, ms: 2900, ph: 0.70 } ]
                Shape {
                    id: ribbon
                    required property var modelData
                    property real t: 0                                     // 0..1 sweep across the card
                    property real shimmer: 0                               // 0..1 position of the bright band
                    readonly property real rw: fx.width * modelData.w
                    readonly property real amp: fx.height * modelData.amp
                    readonly property real th: modelData.th
                    readonly property real mid: amp * 2 + th
                    x: -rw + ((t + modelData.ph) % 1) * (fx.width + rw)
                    y: fx.height * modelData.y - mid
                    width: rw; height: mid * 2
                    opacity: 0.14
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: -1
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0; x2: ribbon.rw; y2: 0
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: Math.max(0.01, ribbon.shimmer - 0.30); color: Qt.rgba(1, 1, 1, 0.35) }
                            GradientStop { position: ribbon.shimmer; color: "#FFFFFF" }
                            GradientStop { position: Math.min(0.99, ribbon.shimmer + 0.30); color: Qt.rgba(1, 1, 1, 0.35) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                        startX: 0; startY: ribbon.mid
                        // upper edge: an S-wave, offset up by the half thickness
                        PathQuad { x: ribbon.rw * 0.5; y: ribbon.mid - ribbon.th; controlX: ribbon.rw * 0.25; controlY: ribbon.mid - ribbon.amp * 2 - ribbon.th }
                        PathQuad { x: ribbon.rw; y: ribbon.mid; controlX: ribbon.rw * 0.75; controlY: ribbon.mid + ribbon.amp * 2 - ribbon.th }
                        // lower edge back to the start, offset down
                        PathQuad { x: ribbon.rw * 0.5; y: ribbon.mid + ribbon.th; controlX: ribbon.rw * 0.75; controlY: ribbon.mid + ribbon.amp * 2 + ribbon.th }
                        PathQuad { x: 0; y: ribbon.mid; controlX: ribbon.rw * 0.25; controlY: ribbon.mid - ribbon.amp * 2 + ribbon.th }
                    }
                    NumberAnimation on t { from: 0; to: 1; duration: modelData.ms * 2; loops: Animation.Infinite }
                    NumberAnimation on shimmer { from: 0; to: 1; duration: modelData.ms; loops: Animation.Infinite }
                }
            }
            // Debris: tiny leaves tumbling along a wave as they cross the card.
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    property real t: 0
                    readonly property real baseY: fx.rnd(0.10, 0.90) * fx.height
                    readonly property real wave: 6 + index * 2
                    x: -8 + t * (fx.width + 16)
                    y: baseY + Math.sin(t * Math.PI * 2 * 1.5 + index) * wave
                    width: 4; height: 2; radius: 1
                    color: "#FFFFFF"
                    opacity: 0.20
                    SequentialAnimation on t {
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 420 }
                        NumberAnimation { from: 0; to: 1; duration: fx.rnd(1500, 2300) / (0.8 + fx.windFactor); loops: Animation.Infinite }
                    }
                    RotationAnimator on rotation { from: 0; to: 360; duration: 700 + index * 150; loops: Animation.Infinite }
                }
            }
        }
    }
}
