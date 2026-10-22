import QtQuick
import org.kde.plasma.core as PlasmaCore

// Floating tooltip window that fades in/out. The window stays mapped until
// the fade-out has finished. It draws its own glass surface (HoverForecast)
// instead of the theme's tooltip background.
PlasmaCore.Dialog {
    id: popup

    property var weather: null
    property string message: ""
    property bool shown: false
    property string iconStyle: "handdrawn"

    type: PlasmaCore.Dialog.Tooltip
    flags: Qt.WindowDoesNotAcceptFocus | Qt.ToolTip
    backgroundHints: PlasmaCore.Dialog.NoBackground
    hideOnWindowDeactivate: false
    visible: shown || content.opacity > 0.01

    mainItem: HoverForecast {
        id: content
        weather: popup.weather
        message: popup.message
        active: popup.shown
        iconStyle: popup.iconStyle
        opacity: popup.shown ? 1 : 0
        scale: popup.shown ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }
}
