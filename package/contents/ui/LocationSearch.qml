import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "code/weather.js" as Weather

// Inline city search: a text field that queries Open-Meteo geocoding after a
// short pause and shows up to five suggestions underneath. Enter or a click
// picks one; Escape or losing focus dismisses.
FocusScope {
    id: search

    property var results: []
    property bool busy: false
    property int current: 0
    property bool pickWhenReady: false   // Enter was pressed before the results arrived
    property bool detecting: false
    property string detectError: ""
    // Open whenever the field has focus: the detect row is always available.
    readonly property bool open: field.activeFocus

    signal chosen(string name, real latitude, real longitude)
    signal dismissed()

    implicitHeight: field.implicitHeight
    implicitWidth: 220

    function begin() {
        field.text = ""
        results = []
        current = 0
        pickWhenReady = false
        detecting = false
        detectError = ""
        field.forceActiveFocus()
    }
    // Approximate location from the public IP address.
    function detect() {
        if (detecting) return
        detecting = true
        detectError = ""
        Weather.detectLocation(function (place) {
            detecting = false
            chosen(place.displayName, place.latitude, place.longitude)
        }, function (message) {
            detecting = false
            detectError = message
            field.forceActiveFocus()
        })
    }
    // Enter: pick the highlighted match, or the first match once the lookup
    // for the current text completes.
    function submit() {
        if (results.length > 0) { pick(current); return }
        pickWhenReady = true
        if (debounce.running) { debounce.stop(); debounce.triggered() }
    }
    function pick(i) {
        if (i < 0 || i >= results.length) return
        var r = results[i]
        chosen(r.country !== "" ? r.name + ", " + r.country : r.name, r.latitude, r.longitude)
    }

    onActiveFocusChanged: if (!activeFocus && !detecting) dismissed()

    Timer {
        id: debounce
        interval: 300
        onTriggered: {
            var q = field.text
            search.busy = true
            Weather.searchLocation(q, function (list) {
                if (q !== field.text) return      // stale reply
                search.results = list
                search.current = 0
                search.busy = false
                if (search.pickWhenReady) { search.pickWhenReady = false; search.pick(0) }
            })
        }
    }

    QQC2.TextField {
        id: field
        anchors.fill: parent
        focus: true
        placeholderText: i18n("Search city…")
        color: "#FFFFFF"
        placeholderTextColor: "#9AA0A6"
        font.pixelSize: 13
        leftPadding: 28
        rightPadding: 8
        topPadding: 4
        bottomPadding: 4
        selectByMouse: true
        background: Rectangle {
            radius: 6
            color: Qt.rgba(0, 0, 0, 0.25)
            border.width: 1
            border.color: field.activeFocus ? "#4FC3F7" : Qt.rgba(1, 1, 1, 0.15)
        }
        Kirigami.Icon {
            source: "search"
            isMask: true
            color: "#9AA0A6"
            width: 14; height: 14
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
        }
        onTextChanged: { search.results = []; search.pickWhenReady = false; debounce.restart() }
        Keys.onEscapePressed: search.dismissed()
        Keys.onDownPressed: if (search.results.length) search.current = (search.current + 1) % search.results.length
        Keys.onUpPressed: if (search.results.length) search.current = (search.current + search.results.length - 1) % search.results.length
        Keys.onReturnPressed: search.submit()
        Keys.onEnterPressed: search.submit()
    }

    Rectangle {   // suggestion dropdown
        id: dropdown
        visible: search.open
        anchors.top: field.bottom
        anchors.topMargin: 4
        width: Math.max(field.width, 240)
        height: list.contentHeight + 8
        z: 100
        radius: 8
        color: "#1F242C"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)

        Column {
            id: list
            anchors.fill: parent
            anchors.margins: 4
            readonly property real contentHeight: childrenRect.height

            Rectangle {   // "use my location" row
                id: detectRow
                width: list.width
                height: 30
                radius: 6
                color: detectMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    spacing: 6
                    Kirigami.Icon {
                        source: "mark-location"
                        isMask: true
                        color: "#4FC3F7"
                        width: 14; height: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    QQC2.Label {
                        anchors.verticalCenter: parent.verticalCenter
                        color: search.detectError !== "" ? "#EF9A9A" : "#4FC3F7"
                        font.pixelSize: 12
                        text: search.detecting ? i18n("Detecting your location…")
                            : search.detectError !== "" ? search.detectError
                            : i18n("Use my current location")
                    }
                }
                MouseArea {
                    id: detectMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: search.detect()
                }
            }
            Rectangle { width: list.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08); visible: stateLine.visible || search.results.length > 0 }
            QQC2.Label {   // state line while typing / when nothing matched
                id: stateLine
                visible: search.results.length === 0 && (search.busy || field.text.trim().length >= 2)
                width: parent.width
                padding: 8
                color: "#9AA0A6"
                font.pixelSize: 12
                text: search.busy ? i18n("Searching…") : i18n("No places found")
            }
            Repeater {
                model: search.results
                Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 30
                    radius: 6
                    color: index === search.current || rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    QQC2.Label {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        text: row.modelData.displayName
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: search.current = row.index
                        onClicked: search.pick(row.index)
                    }
                }
            }
        }
    }
}
