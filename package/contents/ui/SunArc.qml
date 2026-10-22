import QtQuick
import QtQuick.Shapes

// Semicircular sun trajectory with a glowing sun resting on the horizon:
// lower-left for sunrise, lower-right for sunset.
Item {
    id: arc

    property bool sunset: false
    property color sunColor: "#FFD54F"
    property color strokeColor: Qt.rgba(1, 1, 1, 0.3)

    readonly property real arcWidth: 32
    readonly property real arcHeight: 16
    readonly property real sunX: sunset ? (width + arcWidth) / 2 : (width - arcWidth) / 2
    readonly property real sunY: height - 4

    implicitWidth: 40
    implicitHeight: 24

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: arc.strokeColor
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: (arc.width - arc.arcWidth) / 2
            startY: arc.sunY
            PathArc {
                x: (arc.width + arc.arcWidth) / 2
                y: arc.sunY
                radiusX: arc.arcWidth / 2
                radiusY: arc.arcHeight
            }
        }
        ShapePath {   // horizon line
            strokeColor: Qt.rgba(1, 1, 1, 0.18)
            strokeWidth: 1
            fillColor: "transparent"
            startX: 0
            startY: arc.sunY
            PathLine { x: arc.width; y: arc.sunY }
        }
    }

    Rectangle {   // glow
        width: 16; height: 16; radius: 8
        x: arc.sunX - width / 2
        y: arc.sunY - height / 2
        color: arc.sunColor
        opacity: 0.3
    }
    Rectangle {   // sun; the sunset dot gets a white stroke for contrast on the orange side
        width: 8; height: 8; radius: 4
        x: arc.sunX - width / 2
        y: arc.sunY - height / 2
        color: arc.sunColor
        border.width: arc.sunset ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.9)
    }
}
