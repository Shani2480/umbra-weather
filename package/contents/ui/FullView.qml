import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "code/weather.js" as Weather

// Expanded view. In a panel popup it is a content-sized glass card with a 48px
// header (condition icon, pin, location, actions), a gradient hero card and a
// row of seven daily cards. On the desktop (desktopMode) it fills the applet,
// drops the window controls and resizes fluidly: below 420px wide it shows 4
// days, and the hero gains its solar cards and then its hourly strip only when
// the height can hold them. Every row keeps its minimum height, so the hero
// and the 7-day row are always sequential, never squeezed into each other.
// Shrunk below 340x260 the card switches to the miniature view: the hero alone,
// with the icon, temperature, condition and feels-like scaled to the footprint.
Rectangle {
    id: view

    property var weather: null
    property string errorText: ""
    property int currentFeelsLike: 0        // rounded, in the configured unit (see main.qml)
    property string locationName: ""
    property string iconStyle: "handdrawn"
    property bool active: false
    property bool pinned: false
    property bool forecastCollapsed: false
    property bool desktopMode: false
    property bool translucent: true
    property bool ambientAnimations: true   // subtle weather animation behind the hero text
    property bool showCharacter: true       // silhouette figure on the hourly strip (needs ambientAnimations)

    signal refreshRequested()
    signal closeRequested()
    signal configureRequested()
    signal pinRequested()
    signal minimizeRequested()
    signal locationChosen(string name, real latitude, real longitude)

    // Desktop: clicking the hero flips the card over to a details side.
    property bool flipped: false
    property real flipAngle: flipped ? 180 : 0
    Behavior on flipAngle { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
    transform: Rotation {
        origin.x: view.width / 2
        origin.y: view.height / 2
        axis { x: 0; y: 1; z: 0 }
        angle: view.flipAngle
    }

    // Detail values for the selected day (today uses the live observation).
    readonly property var cur: weather ? weather.current : null
    function detailValue(key, compact) {
        if (!weather || !sel) return ""
        switch (key) {
        case "feels":    return selToday ? Math.round(cur.feelsLike) + "°" : i18n("%1° / %2°", Math.round(sel.max), Math.round(sel.min))
        case "humidity": return selToday ? Math.round(cur.humidity) + "%" : ""
        case "wind":     return selToday ? Math.round(cur.wind) + " " + weather.windUnit + (compact ? "" : " " + Weather.compass(cur.windDir))
                                         : Math.round(sel.wind) + " " + weather.windUnit
        case "pressure": return selToday ? Math.round(cur.pressure) + " hPa" : ""
        case "uv":       return sel.uv === undefined || sel.uv === null ? "" : Math.round(sel.uv) + ""
        case "rain":     return sel.rain === undefined || sel.rain === null ? "" : Math.round(sel.rain) + "%"
        case "precip":   return sel.precipSum === undefined || sel.precipSum === null ? "" : (Math.round(sel.precipSum * 10) / 10) + " " + weather.precipUnit
        case "cloud":    return selToday ? Math.round(cur.cloudCover) + "%" : ""
        }
        return ""
    }
    readonly property string updatedText: weather ? i18n("Updated %1", Qt.formatTime(weather.fetchedAt, "HH:mm")) : ""
    readonly property var detailKeys: [
        { key: "feels",    label: i18n("Feels like"),  shortLabel: i18n("Feels"), dayLabel: i18n("High / Low"), shortDayLabel: i18n("Hi / Lo"), accent: "#FFB74D" },
        { key: "humidity", label: i18n("Humidity"),    accent: "#4FC3F7" },
        { key: "wind",     label: i18n("Wind"),        dayLabel: i18n("Wind max"),   accent: "#80CBC4" },
        { key: "pressure", label: i18n("Pressure"),    accent: "#B39DDB" },
        { key: "uv",       label: i18n("UV index"),    shortLabel: i18n("UV"), accent: "#FFD54F" },
        { key: "rain",     label: i18n("Rain chance"), shortLabel: i18n("Rain"), accent: "#64B5F6" },
        { key: "precip",   label: i18n("Precipitation"), accent: "#7FA7E8" },
        { key: "cloud",    label: i18n("Cloud cover"), accent: "#B0BEC5" }
    ]

    // Tinted card with a small glyph by the label and a faint large glyph
    // behind the value. Used by the popup strip and the desktop back side.
    component DetailTile: Rectangle {
        id: tile
        property var detail
        property real valueSize: 13
        property real watermark: 0.9      // watermark glyph size, as a fraction of the tile height
        property bool compact: false      // narrow popup tiles: short labels, no label glyph
        function labelText() {
            if (!detail) return ""
            if (!view.selToday && detail.dayLabel) return compact && detail.shortDayLabel ? detail.shortDayLabel : detail.dayLabel
            if (compact && detail.key === "wind" && view.cur) return detail.label + " " + Weather.compass(view.cur.windDir)
            return compact && detail.shortLabel ? detail.shortLabel : detail.label
        }
        readonly property color accent: detail ? detail.accent : "#FFFFFF"
        readonly property string value: detail ? view.detailValue(detail.key, compact) : ""
        visible: value !== ""
        radius: 8
        clip: true
        color: Qt.rgba(accent.r, accent.g, accent.b, 0.13)
        border.width: 1
        border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.28)
        implicitHeight: 46

        DetailGlyph {   // watermark
            anchors.right: parent.right
            anchors.rightMargin: -tile.height * 0.12
            anchors.verticalCenter: parent.verticalCenter
            width: tile.height * tile.watermark; height: width
            kind: tile.detail ? tile.detail.key : "feels"
            color: tile.accent
            opacity: 0.16
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 6
            spacing: 1
            Item { Layout.fillHeight: true }
            RowLayout {
                spacing: 4
                Layout.fillWidth: true
                DetailGlyph {
                    visible: !tile.compact
                    Layout.preferredWidth: 13; Layout.preferredHeight: 13
                    kind: tile.detail ? tile.detail.key : "feels"
                    color: tile.accent
                }
                ShadowLabel {
                    text: tile.labelText()
                    color: Qt.lighter(tile.accent, 1.15)
                    font.pixelSize: 10
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: tile.compact ? 0.2 : 0.4
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            ShadowLabel {
                text: tile.value
                color: view.primary
                font.pixelSize: tile.valueSize
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Item { Layout.fillHeight: true }
        }
    }

    // inline location search, opened by clicking the location text
    property bool searching: false
    onActiveChanged: if (!active) { searching = false; flipped = false }
    function openSearch() { searching = true; Qt.callLater(function () { locationSearch.begin() }) }

    // selected forecast day (0 = today) drives the hero card
    property int selectedIndex: 0
    property int pendingIndex: 0
    property real heroShift: 0          // vertical offset of the hero contents during a day swap

    readonly property bool narrow: desktopMode && width < 420
    // Miniature view: a single hero card once the desktop widget is resized to
    // a small footprint. The popup is content-sized and never qualifies.
    readonly property bool isMiniMode: desktopMode && (width < 340 || height < 260)
    readonly property bool showSolarCards: !isMiniMode && width >= 400
    readonly property int miniMinWidth: 200
    readonly property int miniMinHeight: 130
    onIsMiniModeChanged: if (isMiniMode) { flipped = false; searching = false; selectedIndex = 0; pendingIndex = 0 }

    // Breakpoint transitions. Sections never snap in and out: each one follows
    // a 0..1 progress that drives its layout size and opacity.
    property real miniProgress: isMiniMode ? 1.0 : 0.0          // regular rows -> miniature tile
    Behavior on miniProgress { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    property real hourlyVisibility: showTrack ? 1.0 : 0.0
    Behavior on hourlyVisibility { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    property real weeklyVisibility: isMiniMode ? 0.0 : 1.0
    Behavior on weeklyVisibility { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    property real solarVisibility: showSolar ? 1.0 : 0.0
    Behavior on solarVisibility { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    // Hero height floor, eased between the tiers and the miniature tile but
    // never above what fits beside the (collapsing) 7-day row.
    property real heroMinHeight: isMiniMode ? 56 : Math.ceil(heroNeed)
    Behavior on heroMinHeight { enabled: view.desktopMode; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    readonly property real heroRoom: height - chrome - gridMin * weeklyVisibility
    readonly property real heroFloor: desktopMode ? Math.max(56, Math.min(heroMinHeight, heroRoom)) : heroMinHeight

    // Vertical budget (desktop). Each hero tier needs this much height; the
    // 7-day row may shrink from gridPref to gridMin before a tier is dropped.
    readonly property int gridPref: desktopMode ? 105 : 110
    readonly property int gridMin: desktopMode ? 84 : 110
    readonly property real hpad: desktopMode ? 8 : 16
    readonly property real chrome: pad * 2 + column.spacing
    // popup-only details strip under the metrics
    readonly property real detailsExtra: detailsStrip.visible ? heroContent.spacing + detailsStrip.Layout.topMargin + detailsStrip.implicitHeight : 0
    readonly property real heroCompact: hpad * 2 + titleLabel.implicitHeight + heroContent.spacing + metricsRow.implicitHeight + detailsExtra
    readonly property real heroSolar: detailsExtra + hpad * 2 + titleLabel.implicitHeight + heroContent.spacing
                                    + Math.max(metricsRow.implicitHeight, solarColumn.implicitHeight)
    readonly property real heroTrack: Math.max(210, heroSolar + heroContent.spacing + hourlyWell.implicitHeight)
    readonly property bool showSolar: !desktopMode || (showSolarCards && height >= heroSolar + gridMin + chrome)
    readonly property bool showTrack: desktopMode && !isMiniMode && heroSlots.length > 0 && height >= heroTrack + gridMin + chrome
    readonly property real heroNeed: showTrack ? heroTrack : showSolar ? heroSolar : heroCompact
    readonly property var days: weather ? weather.daily.slice(0, narrow ? 4 : 7) : []
    readonly property var sel: weather && selectedIndex < weather.daily.length ? weather.daily[selectedIndex] : null
    property date tick: new Date()
    // wall-clock time at the location (see Weather.localNow)
    readonly property date now: Weather.localNow(weather, tick)
    // Hero background: today follows the live solar phase and current
    // conditions; another selected day uses its own condition in daylight.
    readonly property string solarPhase: weather ? Weather.solarPhase(weather.daily[0], now) : "day"
    readonly property string heroCondition: !sel ? "cloudy" : selToday ? weather.current.condition : sel.condition
    readonly property var heroStops: Weather.heroPalette(heroCondition, selToday ? solarPhase : "day")
    readonly property bool selToday: selectedIndex === 0
    readonly property var heroSlots: !weather || !sel ? []
        : selToday ? Weather.upcomingSlots(weather, 6, 3)
                   : Weather.daySlots(weather, sel.date, [6, 9, 12, 15, 18, 21])

    // palette
    readonly property color primary: "#FFFFFF"
    readonly property color secondary: "#9AA0A6"
    readonly property color accentWarm: "#FF8A65"
    readonly property color accentCool: "#4FC3F7"
    readonly property color low: "#78909C"
    readonly property real pad: desktopMode ? 8 : Kirigami.Units.largeSpacing

    function fmtTime(d) {
        return Qt.formatTime(d, "HH:mm")
    }
    function dayTitle(d, isToday) {
        var s = Qt.locale().dayName(d.getDay(), Locale.ShortFormat) + " " + d.getDate() + " "
              + Qt.locale().monthName(d.getMonth(), Locale.ShortFormat)
        return isToday ? i18n("Today · %1", s) : s
    }
    function selectDay(i) {
        if (i === selectedIndex || heroSwap.running) return
        pendingIndex = i
        heroSwap.restart()
    }
    onWeatherChanged: if (!weather || selectedIndex >= weather.daily.length) selectedIndex = 0

    Timer {   // keeps the solar phase current while the view is showing
        interval: 60 * 1000
        running: view.active
        repeat: true
        triggeredOnStart: true
        onTriggered: view.tick = new Date()
    }

    // Day swap: the hero contents (title, icon, temperature, condition, solar
    // cards and hourly strip) exit together, the data switches, then they enter.
    SequentialAnimation {
        id: heroSwap
        ParallelAnimation {
            NumberAnimation { target: heroContent; property: "opacity"; to: 0.15; duration: 120; easing.type: Easing.InQuad }
            NumberAnimation { target: view; property: "heroShift"; to: 5; duration: 120; easing.type: Easing.InQuad }
        }
        ScriptAction { script: view.selectedIndex = view.pendingIndex }
        ParallelAnimation {
            NumberAnimation { target: heroContent; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: view; property: "heroShift"; to: 0; duration: 220; easing.type: Easing.OutCubic }
        }
    }

    // Popup: content-sized. Desktop: filled by the applet, resizable via the handle.
    implicitWidth: desktopMode ? 480 : 460
    implicitHeight: desktopMode ? 260 : column.implicitHeight + pad * 2
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.minimumWidth: desktopMode ? miniMinWidth : implicitWidth
    Layout.minimumHeight: desktopMode ? miniMinHeight : implicitHeight

    radius: 12
    color: !desktopMode ? Qt.rgba(0x16 / 255, 0x19 / 255, 0x1E / 255, 0.85)
         : translucent ? Qt.rgba(22 / 255, 25 / 255, 30 / 255, 0.55) : "#16191E"
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

    // Label with a soft drop shadow on the desktop, where the wallpaper shows through.
    component ShadowLabel: PlasmaComponents3.Label {
        padding: view.desktopMode ? 3 : 0
        layer.enabled: view.desktopMode
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.6
            shadowBlur: 0.4
            blurMax: 8
            shadowVerticalOffset: 1
        }
    }

    // Flat icon button: 6px hover highlight, white mask icon.
    component HeaderButton: QQC2.AbstractButton {
        id: hb
        property string iconName
        property string tip
        implicitWidth: 28
        implicitHeight: 28
        hoverEnabled: true
        Accessible.name: tip
        background: Rectangle {
            radius: 6
            color: hb.checked ? Qt.rgba(1, 1, 1, 0.10)
                 : (hb.hovered || hb.down) ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
        }
        contentItem: Item {
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 16; height: 16
                source: hb.iconName
                isMask: true
                color: hb.checked ? view.accentCool : view.primary
                opacity: hb.checked || hb.hovered ? 1 : 0.8
            }
        }
        PlasmaComponents3.ToolTip.text: tip
        PlasmaComponents3.ToolTip.visible: hovered && tip !== ""
        PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
    }

    // Sunrise / sunset mini card inside the hero.
    component SolarCard: Rectangle {
        id: sc
        property string label
        property date time
        property bool sunset: false
        implicitWidth: 136
        implicitHeight: 44
        Layout.minimumHeight: implicitHeight
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 6
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: sc.label
                    color: "#E0E0E0"
                    font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.5
                }
                PlasmaComponents3.Label {
                    text: view.fmtTime(sc.time)
                    color: view.primary
                    font.pixelSize: 13
                    font.bold: true
                    font.features: { "tnum": 1 }
                }
            }
            SunArc {
                sunset: sc.sunset
                sunColor: sc.sunset ? "#FFAB91" : "#FFD54F"
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    LocationSearch {
        id: locationSearch
        visible: view.searching
        parent: view.desktopMode ? heroTitleSlot : headerTitleSlot
        anchors.fill: parent
        onChosen: (name, latitude, longitude) => { view.searching = false; view.locationChosen(name, latitude, longitude) }
        onDismissed: view.searching = false
    }

    // Back side of the desktop card: a grid of detail tiles. Pre-rotated 180°
    // so it reads correctly once the whole card has turned over.
    Item {
        id: backPanel
        visible: view.flipAngle >= 90
        anchors.fill: parent
        anchors.margins: view.pad
        transform: Rotation {
            origin.x: backPanel.width / 2
            origin.y: backPanel.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: 180
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: view.flipped = false
        }
        ColumnLayout {
            anchors.fill: parent
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                ShadowLabel {
                    text: (view.locationName !== "" ? view.locationName + " · " : "") + i18n("Details")
                    color: "#E0E0E0"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                ShadowLabel {
                    text: view.updatedText
                    color: "#B0BEC5"
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: view.narrow ? 2 : 4
                rowSpacing: 6
                columnSpacing: 6
                Repeater {
                    model: view.detailKeys
                    DetailTile {
                        required property var modelData
                        detail: modelData
                        valueSize: 15
                        watermark: 0.95
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 44
                    }
                }
            }
            ShadowLabel {
                text: view.selToday && view.cur ? view.cur.text + " · " + i18n("Click to flip back") : i18n("Click to flip back")
                color: "#9AA0A6"
                font.pixelSize: 10
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    ColumnLayout {
        id: column
        visible: view.flipAngle < 90
        anchors.fill: parent
        anchors.margins: view.pad
        spacing: 8

        // ---- header (panel popup only) ----
        RowLayout {
            visible: !view.desktopMode
            z: 5
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.minimumHeight: 48
            spacing: 4

            WeatherIcon {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 2
                condition: view.weather ? view.weather.current.condition : "cloudy"
                code: view.weather ? view.weather.current.code : -1
                isDay: view.weather ? view.weather.current.isDay : true
                iconStyle: view.iconStyle
                running: view.active
            }
            HeaderButton {
                iconName: "window-pin"
                tip: view.pinned ? i18n("Unpin") : i18n("Keep open")
                checkable: true
                checked: view.pinned
                onClicked: view.pinRequested()
            }
            Item {
                id: headerTitleSlot
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.preferredHeight: 28
                z: 5
                PlasmaComponents3.Label {
                    anchors.fill: parent
                    visible: !view.searching
                    text: view.locationName
                    color: view.primary
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.openSearch()
                        PlasmaComponents3.ToolTip.text: i18n("Change location")
                        PlasmaComponents3.ToolTip.visible: containsMouse
                        PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                        hoverEnabled: true
                    }
                }
            }
            HeaderButton {
                iconName: "view-refresh"
                tip: i18n("Refresh")
                onClicked: view.refreshRequested()
            }
            HeaderButton {
                iconName: "configure"
                tip: i18n("Settings")
                onClicked: view.configureRequested()
            }
            HeaderButton {
                iconName: view.forecastCollapsed ? "window-restore" : "window-minimize"
                tip: view.forecastCollapsed ? i18n("Show forecast") : i18n("Minimize")
                onClicked: view.minimizeRequested()
            }
            HeaderButton {
                iconName: "window-close"
                tip: i18n("Close")
                onClicked: view.closeRequested()
            }
        }

        ShadowLabel {
            visible: !view.weather
            text: view.errorText !== "" ? view.errorText : i18n("Loading…")
            color: view.secondary
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: view.desktopMode
            Layout.margins: view.desktopMode ? 0 : Kirigami.Units.gridUnit * 2
            verticalAlignment: Text.AlignVCenter
        }

        // ---- hero card ----
        Rectangle {
            id: hero
            visible: !!view.weather
            z: 3
            Layout.fillWidth: true
            Layout.fillHeight: view.desktopMode
            Layout.preferredHeight: view.heroFloor
            Layout.minimumHeight: view.heroFloor
            radius: 10
            clip: true
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.15)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0; color: view.heroStops[0]
                    Behavior on color { ColorAnimation { duration: 1200; easing.type: Easing.InOutQuad } }
                }
                GradientStop {
                    position: 0.5; color: view.heroStops[1]
                    Behavior on color { ColorAnimation { duration: 1200; easing.type: Easing.InOutQuad } }
                }
                GradientStop {
                    position: 1.0; color: view.heroStops[2]
                    Behavior on color { ColorAnimation { duration: 1200; easing.type: Easing.InOutQuad } }
                }
            }

            readonly property real hpad: view.hpad

            HeroAmbientEffects {   // behind everything else in the card
                id: ambient
                anchors.fill: parent
                z: 0
                cornerRadius: hero.radius
                running: view.ambientAnimations && view.active && hero.visible && !view.flipped
                condition: view.heroCondition
                isNight: view.selToday && view.weather ? !view.weather.current.isDay : false
                windSpeed: !view.weather || !view.sel ? 0 : view.selToday ? view.weather.current.wind : (view.sel.wind || 0)
            }

            MouseArea {   // desktop: hover reveals refresh, click flips to the details side
                id: heroMouse
                anchors.fill: parent
                hoverEnabled: view.desktopMode
                acceptedButtons: view.desktopMode && !view.isMiniMode ? Qt.LeftButton : Qt.NoButton
                cursorShape: acceptedButtons !== Qt.NoButton ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: view.flipped = true
            }

            ColumnLayout {
                id: heroContent
                anchors.fill: parent
                anchors.margins: hero.hpad
                spacing: 4
                transform: Translate { y: view.heroShift }

                // top row: "Dongen · Today · Wed 21 Oct" (location only on the desktop)
                Item {
                    id: heroTitleSlot
                    visible: view.searching
                    z: 5
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    Layout.minimumHeight: 28
                    Layout.rightMargin: view.desktopMode ? 32 : 0
                }
                ShadowLabel {
                    id: titleLabel
                    visible: !view.searching && view.miniProgress < 1
                    opacity: 1 - view.miniProgress
                    Layout.minimumHeight: implicitHeight
                    MouseArea {
                        anchors.fill: parent
                        enabled: view.desktopMode
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: view.openSearch()
                    }
                    text: (view.desktopMode && view.locationName !== "" ? view.locationName + " · " : "")
                        + (view.sel ? view.dayTitle(view.sel.date, view.selToday) : "")
                    color: "#E0E0E0"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: view.desktopMode ? 0.8 : 0.5
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.rightMargin: view.desktopMode ? 32 : 0   // room for the hover refresh button
                }

                // middle row: metrics on the left, solar cards on the right
                RowLayout {
                    id: metricsRow
                    visible: view.miniProgress < 1
                    opacity: 1 - view.miniProgress
                    spacing: 12
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: implicitHeight

                    // primary icon for the day the hero shows (today = current observation)
                    WeatherIcon {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        Layout.alignment: Qt.AlignVCenter
                        condition: !view.sel ? "cloudy" : view.selToday ? view.weather.current.condition : view.sel.condition
                        code: !view.sel ? -1 : view.selToday ? view.weather.current.code : view.sel.code
                        isDay: !view.sel || !view.selToday ? true : view.weather.current.isDay
                        iconStyle: view.iconStyle
                        running: view.active
                    }
                    ShadowLabel {
                        text: view.sel ? Math.round(view.selToday ? view.weather.current.temp : view.sel.max) + "°" : ""
                        color: view.primary
                        font.pixelSize: 38
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: -4
                    }
                    ColumnLayout {
                        id: descColumn
                        spacing: 0
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        ShadowLabel {
                            text: view.sel ? (view.selToday ? view.weather.current.text : view.sel.text) : ""
                            color: view.primary
                            font.pixelSize: view.desktopMode ? 16 : 14
                            font.weight: view.desktopMode ? Font.DemiBold : Font.Medium
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        ShadowLabel {
                            text: view.sel ? i18n("H: %1°  L: %2°", Math.round(view.sel.max), Math.round(view.sel.min)) : ""
                            color: "#E0E0E0"
                            font.pixelSize: 12
                        }
                    }

                    ColumnLayout {
                        id: solarColumn
                        visible: view.solarVisibility > 0
                        opacity: view.solarVisibility
                        clip: view.solarVisibility < 1
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: implicitWidth * view.solarVisibility
                        Layout.maximumWidth: implicitWidth * view.solarVisibility
                        SolarCard {
                            label: i18n("Sunrise")
                            time: view.sel ? view.sel.sunrise : new Date()
                        }
                        SolarCard {
                            label: i18n("Sunset")
                            time: view.sel ? view.sel.sunset : new Date()
                            sunset: true
                        }
                    }
                }

                // bottom row: hourly progression of the selected day (desktop, when there is room)
                // popup: today's details (or the selected day's) as a strip of tiles
                ColumnLayout {
                    id: detailsStrip
                    visible: !view.desktopMode && !!view.weather
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 3
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: view.detailKeys.filter(function (d) { return ["feels", "humidity", "wind", "uv", "rain"].indexOf(d.key) >= 0 })
                            DetailTile {
                                required property var modelData
                                detail: modelData
                                compact: true
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                            }
                        }
                    }
                    PlasmaComponents3.Label {
                        text: view.updatedText
                        color: "#9AA0A6"
                        font.pixelSize: 10
                        font.features: { "tnum": 1 }
                        Layout.alignment: Qt.AlignRight
                    }
                }

                Rectangle {
                    id: hourlyWell
                    visible: view.hourlyVisibility > 0
                    opacity: view.hourlyVisibility
                    Layout.fillWidth: true
                    Layout.minimumHeight: implicitHeight * view.hourlyVisibility
                    Layout.preferredHeight: implicitHeight * view.hourlyVisibility
                    Layout.maximumHeight: implicitHeight * view.hourlyVisibility
                    implicitHeight: track.implicitHeight + 12
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.18)

                    // Silhouette figure resting on the strip's top edge, in the
                    // gap between the temperature text and the solar cards.
                    WeatherCharacter {
                        id: figure
                        z: 1
                        visible: view.showCharacter && view.ambientAnimations
                        anchors.bottom: parent.top
                        anchors.bottomMargin: -8                          // seated legs dangle over the edge
                        x: Math.max(0, Math.min(parent.width - width,
                               metricsRow.x + descColumn.x + descColumn.width / 2 - width / 2))
                        condition: ambient.condition
                        isNight: ambient.isNight
                        windSpeed: ambient.windSpeed
                        running: ambient.running && visible
                        Connections {
                            target: ambient
                            function onLightning() { figure.duck() }
                        }
                    }

                    Item {   // clips the strip while it collapses; the figure above stays outside
                        anchors.fill: parent
                        clip: true
                        RowLayout {
                            id: track
                            x: 6; y: 6
                            width: parent.width - 12
                            spacing: 0
                            Repeater {
                                model: view.heroSlots
                                ColumnLayout {
                                    id: hs
                                    required property var modelData
                                    spacing: 1
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    PlasmaComponents3.Label {
                                        text: Qt.formatTime(hs.modelData.time, "HH:mm")
                                        color: "#E0E0E0"
                                        font.pixelSize: 10
                                        font.features: { "tnum": 1 }
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                    }
                                    WeatherIcon {
                                        Layout.preferredWidth: 18
                                        Layout.preferredHeight: 18
                                        Layout.alignment: Qt.AlignHCenter
                                        condition: hs.modelData.condition
                                        code: hs.modelData.code
                                        iconStyle: view.iconStyle
                                        isDay: hs.modelData.isDay
                                    }
                                    PlasmaComponents3.Label {
                                        text: Math.round(hs.modelData.temp) + "°"
                                        color: view.primary
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Miniature view: icon beside the temperature, condition and
            // feels-like, crossfaded over the regular rows. Lines are added
            // as the card grows taller.
            RowLayout {
                id: miniContent
                visible: view.miniProgress > 0
                opacity: view.miniProgress
                z: 2
                anchors.fill: parent
                anchors.margins: hero.hpad
                spacing: 8
                readonly property real iconSize: Math.max(28, Math.min(64, hero.height * 0.55, hero.width * 0.3))
                readonly property real tempSize: Math.max(22, Math.min(40, hero.height * 0.28))
                readonly property bool showFeels: hero.height >= 96
                readonly property bool showLocation: hero.height >= 124 && view.locationName !== ""

                WeatherIcon {
                    Layout.preferredWidth: miniContent.iconSize
                    Layout.preferredHeight: miniContent.iconSize
                    Layout.alignment: Qt.AlignVCenter
                    condition: view.cur ? view.cur.condition : "cloudy"
                    code: view.cur ? view.cur.code : -1
                    isDay: view.cur ? view.cur.isDay : true
                    iconStyle: view.iconStyle
                    running: view.active
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    ShadowLabel {   // location, click to change
                        visible: miniContent.showLocation && !view.searching
                        text: view.locationName
                        color: "#E0E0E0"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.6
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.rightMargin: 28   // room for the hover refresh button
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.openSearch()
                        }
                    }
                    ShadowLabel {
                        text: view.cur ? Math.round(view.cur.temp) + "°" : "--°"
                        color: view.primary
                        font.pixelSize: miniContent.tempSize
                        font.bold: true
                        Layout.leftMargin: -2
                    }
                    ShadowLabel {
                        text: view.cur ? view.cur.text : ""
                        color: view.primary
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    ShadowLabel {
                        visible: miniContent.showFeels
                        text: i18n("Feels like %1°", view.currentFeelsLike)
                        color: "#E0E0E0"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            HeaderButton {   // discreet refresh, top-right, shown while hovering the hero
                visible: view.desktopMode
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 4
                iconName: "view-refresh"
                tip: i18n("Refresh")
                opacity: heroMouse.containsMouse || hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                onClicked: view.refreshRequested()
            }
        }

        // ---- forecast grid: 7 days, or 4 when the desktop widget is narrow ----
        RowLayout {
            id: grid
            visible: !!view.weather && !view.forecastCollapsed && view.weeklyVisibility > 0
            opacity: view.weeklyVisibility
            clip: view.weeklyVisibility < 1
            Layout.fillWidth: true
            Layout.preferredHeight: view.gridPref * view.weeklyVisibility
            Layout.minimumHeight: view.gridMin * view.weeklyVisibility
            Layout.maximumHeight: view.weeklyVisibility < 1 ? view.gridPref * view.weeklyVisibility : Number.POSITIVE_INFINITY
            spacing: 6

            Repeater {
                model: view.days

                Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === view.selectedIndex

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 52

                    // selection lifts the card slightly, growing from its bottom edge
                    transformOrigin: Item.Bottom
                    scale: selected ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                    Rectangle {   // soft glow around the selected card
                        anchors.fill: card
                        anchors.margins: -2
                        radius: card.radius + 2
                        color: "transparent"
                        border.width: 2
                        border.color: "#29B6F6"
                        opacity: cell.selected ? 0.25 : 0
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    }
                    Rectangle {
                        id: card
                        anchors.fill: parent
                        radius: 8
                        color: cell.selected ? "#242D38" : "#1F242C"
                        gradient: cell.selected ? selectedFill : null
                        border.width: cell.selected ? 1.5 : 1
                        border.color: cell.selected ? "#29B6F6" : Qt.rgba(1, 1, 1, 0.05)
                        Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        Behavior on border.width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                        Gradient {
                            id: selectedFill
                            GradientStop { position: 0; color: "#2A3542" }
                            GradientStop { position: 1; color: "#242D38" }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: card.height >= 100 ? 6 : 4

                            PlasmaComponents3.Label {
                                text: Qt.locale().dayName(cell.modelData.date.getDay(), Locale.ShortFormat)
                                color: cell.selected ? view.primary : "#B0BEC5"
                                font.pixelSize: 12
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            WeatherIcon {
                                Layout.preferredWidth: card.height >= 100 ? 32 : 28
                                Layout.preferredHeight: Layout.preferredWidth
                                Layout.alignment: Qt.AlignHCenter
                                condition: cell.modelData.condition
                                code: cell.modelData.code
                                iconStyle: view.iconStyle
                            }
                            RowLayout {
                                spacing: 0
                                Layout.alignment: Qt.AlignHCenter
                                PlasmaComponents3.Label {
                                    text: Math.round(cell.modelData.max) + "°"
                                    color: view.primary
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }
                                PlasmaComponents3.Label {
                                    text: " / "
                                    color: view.low
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }
                                PlasmaComponents3.Label {
                                    text: Math.round(cell.modelData.min) + "°"
                                    color: view.low
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        Rectangle {   // hover brightness
                            anchors.fill: parent
                            radius: parent.radius
                            color: Qt.rgba(1, 1, 1, 0.03)
                            opacity: cellMouse.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.selectDay(cell.index)
                        }
                    }
                }
            }
        }
    }
}
