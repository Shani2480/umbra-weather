import QtQuick
import QtQuick.Window

// Run with:  qml6 preview/IconGallery.qml
Window {
    width: content.implicitWidth
    height: content.implicitHeight
    visible: true
    title: "Umbra Weather icon gallery"

    GalleryContent {
        id: content
        anchors.fill: parent
    }
}
