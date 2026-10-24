import QtQuick

// A minimalist monochrome silhouette duo, a person and a small dog, that react
// to the weather. The pair rests on the top edge of the hourly strip: the
// ground line is y = ground (28) and the lower 8 px hang over the strip so a
// seated pose can dangle its legs. The wind blows left to right, like the
// ambient effects behind the card, so leaning is to the left and anything
// loose (scarf, ears, tail, coat) trails to the right.
//
// Both figures are articulated skeletons: the person has a head, neck, hip,
// two-segment arms (shoulder, elbow, hand) and legs (hip, knee, ankle, toe);
// the dog has a bezier spine, a two-segment neck, four two-segment legs, a
// three-segment bezier tail and a floppy two-segment ear. Poses are written
// as targets (where a hand or paw should be) and solved with a two-bone IK,
// so lowering the hips bends the knees and a hand reaching for something
// bends the elbow. Everything is drawn on one canvas, repainted about 30
// times a second from a clock while `running`, so every motion is a function
// of time: no pose is a tween between keyframes, and poses blend by mixing
// solved joints (walking <-> resting, idle <-> micro-action, trick, hover).
//
// Scenes, in priority order:
//   storm    rain/thunder, wind >= 22: braced into gusts, the umbrella flips inside-out and is
//            tugged back twice; the dog crouches behind their legs, ears streaming
//   thunder  calm thunderstorm: huddled under one umbrella; a flash makes both flinch, then
//            the person bends down and strokes the dog until it settles
//   rain     calm rain: sitting under the umbrella, drops bouncing and splashing off it; the
//            person reaches a palm out to check the rain, the dog paws at a puddle
//   snow     bundled up, blowing a cloud of breath or sipping the mug; the dog pounces into a
//            snowdrift and comes up with snow on its nose
//   windy    dry wind >= 25: hand on hat, scarf and coat tails streaming; a leaf tumbles past
//            and the dog snaps at it
//   sunny    clear day: a fetch loop, the person throwing the ball, the dog bowing, springing
//            after it and trotting it back
//   night    clear night: knees drawn up, nodding off; the dog curled up and dreaming; z's
//   gaze     clear night, every half minute or so: sitting back to stargaze by a telescope
//   calm     cloudy / partly / fog: leaning back on one hand, scratching the dog's ear
//
// `temperature` adds props: a steaming mug at 10° or below (calm, snow), a
// campfire at 2° or below in dry weather (always in the snow); clear nights
// bring a lantern (dozing) or a telescope (stargazing); calm rain a puddle.
// Props scale with `propScale * (1 - walkBlend)`.
//
// Every 14 to 25 s (never at night) the pair wanders a short way along the
// track between `minTrackX` and `maxTrackX`: usually a stroll at 13 px/s on
// an articulated gait, the dog trotting ahead on a slack leash, now and then
// a fade-out and reappearance. Turning round is never a flip: `facingScale`
// eases through edge-on while the pair dips into the step and the heads
// lead the turn. The host sets `homeX` and the track; it must not bind `x`.
//
// Interactions: hovering makes the dog perk up to face the viewer with a
// frantic wag while the person waves; a click runs the treat trick (toss,
// crouch, leap with a mid-air spin, catch, land, two hearts). Left alone,
// every 12 to 22 s the dog shakes off (rain, snow), stretches, sniffs along
// the ground or chases a butterfly (a firefly at night).
Item {
    id: character

    property string condition: "cloudy"
    property bool isNight: false
    property real windSpeed: 0           // km/h
    property real temperature: 15        // °C of the day shown; chooses the mug and campfire props
    property bool running: true
    property color color: "#FFFFFF"

    // Roaming track, in the parent's coordinates, and where to start.
    property bool roaming: true
    property real minTrackX: 0
    property real maxTrackX: 0
    property real homeX: (minTrackX + maxTrackX) / 2
    property bool isWalking: false
    property int facingDirection: 1       // 1 = facing right, -1 = facing left
    property real walkPhase: 0            // 0..2π per stride while walking
    // 0 = fully in the idle pose, 1 = fully walking; eased, so poses blend
    property real walkBlend: isWalking ? 1.0 : 0.0
    Behavior on walkBlend {
        NumberAnimation {
            duration: character.isWalking ? 220 : 380       // quick to stand up into a walk, gentle to settle down
            easing.type: character.isWalking ? Easing.OutQuad : Easing.InOutCubic
        }
    }
    onWalkBlendChanged: dirty()
    readonly property real minHop: 45     // one stroll covers between minHop and maxHop
    readonly property real maxHop: 110

    width: 54
    height: 36
    opacity: 0.32

    readonly property real ground: 28
    readonly property real padX: 12          // canvas headroom, see `art`
    readonly property real padY: 14

    // =====================================================================
    // Scene selection
    // =====================================================================
    readonly property bool wetWeather: condition === "rain" || condition === "thunder"
    readonly property string targetScene: wetWeather && windSpeed >= 22 ? "windyRain"
        : condition === "thunder" ? "thunder"
        : condition === "rain" ? "rain"
        : condition === "snow" ? "snow"
        : windSpeed >= 25 ? "windyDry"
        : condition === "clear" && !isNight ? "sunnyPlay"
        : condition === "clear" && isNight ? (nightMode === "gaze" ? "stargaze" : "sleep")
        : "calm"
    property string nightMode: "doze"                 // clear nights alternate between dozing and stargazing
    property string renderedScene: "calm"            // set from targetScene by the transition (or at once when not running)
    property real transitionScaleY: 1.0               // the pair crouching towards the ground line
    property real transitionOffsetY: 0.0
    property real transitionOpacity: 0.32             // relative to the resting 0.32
    property real umbrellaOpenProgress: umbrellaScene(renderedScene) ? 1.0 : 0.0   // 0 = closed stick, 1 = full dome
    property real propScale: 1.0                      // props anchored at the ground
    function umbrellaScene(scene) { return scene === "rain" || scene === "windyRain" || scene === "thunder" }

    // Short pose names used by the drawing code: one per rendered scene.
    readonly property string pose: renderedScene === "windyRain" ? "storm"
        : renderedScene === "windyDry" ? "windy"
        : renderedScene === "sunnyPlay" ? "sunny"
        : renderedScene === "sleep" ? "night"
        : renderedScene === "stargaze" ? "gaze"
        : renderedScene
    readonly property bool nightScene: pose === "night" || pose === "gaze"
    readonly property bool dozing: pose === "night"
    readonly property bool wet: pose === "storm" || pose === "rain" || pose === "thunder"
    readonly property bool sheltered: pose === "rain" || pose === "thunder"
    readonly property bool leaning: pose === "storm" || pose === "windy"
    readonly property bool gusty: pose === "storm" || pose === "windy"
    // The scene is drawn facing right and mirrored to face left. In a gale the
    // idle poses lean into the wind (which blows to the right), so they are
    // never mirrored; a walk is, with the lean re-applied in world space.
    readonly property bool mirror: facingDirection < 0 && (isWalking || !gusty)
    // The mirror is never applied in one frame: `facingScale` eases between
    // 1 and -1, so the pair turns on the spot. Through the turn they dip
    // into the step, the heads lead, and the head and torso keep a minimum
    // width, so edge-on they read as a rounded back rather than a line.
    property real facingScale: mirror ? -1 : 1
    Behavior on facingScale {
        enabled: character.running
        NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
    }
    onFacingScaleChanged: dirty()

    // Where the person stands (centre x of the figure) and where the dog's box starts.
    // Both slide between their idle spot and their walking spot with the blend.
    readonly property real idlePersonX: leaning ? 14 : 11
    readonly property real idleDogX: pose === "sunny" ? 30 : pose === "night" ? 22 : pose === "gaze" ? 26 : pose === "rain" ? 15
        : pose === "thunder" ? 14 : pose === "storm" ? 26 : pose === "windy" ? 28 : pose === "snow" ? 30 : 16
    readonly property real personX: idlePersonX + (12 - idlePersonX) * walkBlend
    readonly property real dogX: idleDogX + (27 - idleDogX) * walkBlend

    function dirty() { art.requestPaint() }
    onPoseChanged: dirty()
    onUmbrellaOpenProgressChanged: dirty()
    onPropScaleChanged: dirty()
    onWalkPhaseChanged: dirty()
    onColorChanged: dirty()
    onTemperatureChanged: dirty()
    onRunningChanged: if (!running) { walkAnim.stop(); fadeAnim.stop(); fadeOpacity = 1; cancelInteractions(); if (sceneChangeAnimation.running) { sceneChangeAnimation.stop(); applySceneNow() } }

    // =====================================================================
    // Clock: every motion is a function of these
    // =====================================================================
    property real clock: 0               // seconds, pauses with `running`
    property real idlePhase: 0           // clock * π: 2π every 2 s
    property real sceneClock0: 0         // when the rendered scene began
    readonly property real sceneTime: clock - sceneClock0
    property real flashClock: -100       // last lightning flash (thunder startle)
    property double lastTick: 0
    Timer {
        interval: 33
        repeat: true
        running: character.running && character.visible
        onTriggered: {
            var now = Date.now()
            if (character.lastTick > 0) character.clock += Math.min(0.1, (now - character.lastTick) / 1000)
            character.lastTick = now
            character.idlePhase = character.clock * Math.PI
            art.requestPaint()
        }
        onRunningChanged: character.lastTick = 0
    }
    function flinch() { flashClock = clock; dirty() }
    function duck() { flinch() }

    // =====================================================================
    // Scene transitions
    // =====================================================================
    onTargetSceneChanged: {
        if (targetScene === renderedScene) return
        if (!running) { applySceneNow(); return }
        if (walkAnim.running) walkAnim.stop()
        if (fadeAnim.running) { fadeAnim.stop(); fadeOpacity = 1 }
        isWalking = false
        cancelInteractions()
        sceneChangeAnimation.restart()
    }
    function applySceneNow() {
        cancelInteractions()
        renderedScene = targetScene
        resetSceneCounters()
        transitionScaleY = 1; transitionOffsetY = 0; transitionOpacity = 0.32
        umbrellaOpenProgress = umbrellaScene(renderedScene) ? 1 : 0
        propScale = 1
    }
    function resetSceneCounters() { sceneClock0 = clock; walkPhase = 0; dirty() }
    SequentialAnimation {
        id: sceneChangeAnimation
        // 1. anticipation: crouch towards the ground, fold the umbrella, props shrink away
        ParallelAnimation {
            NumberAnimation { target: character; property: "transitionScaleY"; to: 0.75; duration: 150; easing.type: Easing.InQuad }
            NumberAnimation { target: character; property: "transitionOffsetY"; to: 3; duration: 150; easing.type: Easing.InQuad }
            NumberAnimation { target: character; property: "transitionOpacity"; to: 0.06; duration: 150; easing.type: Easing.InQuad }
            NumberAnimation { target: character; property: "propScale"; to: 0; duration: 150; easing.type: Easing.InQuad }
            NumberAnimation { target: character; property: "umbrellaOpenProgress"; to: 0; duration: 150; easing.type: Easing.InQuad }
        }
        // 2. swap: draw the new scene while nearly invisible
        ScriptAction {
            script: {
                character.renderedScene = character.targetScene
                character.resetSceneCounters()
                umbrellaOpen.to = character.umbrellaScene(character.renderedScene) ? 1 : 0
                umbrellaOpen.restart()
            }
        }
        // 3. settle: stand up with a little overshoot, props pop up from the ground
        ParallelAnimation {
            NumberAnimation { target: character; property: "transitionScaleY"; to: 1; duration: 240; easing.type: Easing.OutBack }
            NumberAnimation { target: character; property: "transitionOffsetY"; to: 0; duration: 240; easing.type: Easing.OutBack }
            NumberAnimation { target: character; property: "transitionOpacity"; to: 0.32; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: character; property: "propScale"; from: 0; to: 1; duration: 280; easing.type: Easing.OutBack }
        }
    }
    NumberAnimation {
        id: umbrellaOpen
        target: character; property: "umbrellaOpenProgress"
        duration: 260; easing.type: Easing.OutBack
    }

    // =====================================================================
    // Roaming
    // =====================================================================
    property bool roamed: false
    Binding {
        target: character; property: "x"
        value: character.clampX(character.homeX)
        when: !character.roamed && character.maxTrackX > character.minTrackX
        restoreMode: Binding.RestoreNone
    }
    function clampX(v) { return Math.max(minTrackX, Math.min(maxTrackX, v)) }
    function keepOnTrack() {
        if (!roamed || maxTrackX <= minTrackX) return
        if (walkAnim.running) walkAnim.stop()
        x = clampX(x)
    }
    onMinTrackXChanged: keepOnTrack()
    onMaxTrackXChanged: keepOnTrack()

    Timer {
        id: roamTimer
        running: character.running && character.roaming && !character.nightScene
                 && !character.isWalking && !fadeAnim.running && !sceneChangeAnimation.running
                 && !character.busy && !character.isHovered
        repeat: true
        interval: 14000 + Math.random() * 11000
        onTriggered: { interval = 14000 + Math.random() * 11000; character.roam() }
    }
    // Public: stroll to a fresh spot right now, as a reaction to new weather
    // data or the hourly strip advancing.
    function triggerRoam() {
        if (!visible || !running || !roaming || nightScene) return
        if (isWalking || fadeAnim.running || sceneChangeAnimation.running || busy) return
        roamTimer.interval = 14000 + Math.random() * 11000
        roamTimer.restart()
        roam(undefined, false)
    }
    // Public: walk (never fade) to a given x on the track.
    function startWalkTo(targetX) { roam(targetX, false) }

    function roam(target, fade) {
        if (target === undefined) {
            var canLeft = x - minHop >= minTrackX
            var canRight = x + minHop <= maxTrackX
            if (!canLeft && !canRight) return
            var dir = canLeft && canRight ? (Math.random() < 0.5 ? -1 : 1) : canLeft ? -1 : 1
            target = x + dir * (minHop + Math.random() * (maxHop - minHop))
        }
        if (fade === undefined) fade = Math.random() < 0.2
        target = clampX(target)
        if (target === x) return
        cancelInteractions()
        roamed = true
        facingDirection = target > x ? 1 : -1
        if (fade) {
            fadeAnim.targetX = target
            fadeAnim.restart()
        } else {
            walkAnim.to = target
            walkAnim.duration = Math.max(2500, Math.abs(target - x) * 75)   // a leisurely 13 px/s
            isWalking = true
            walkAnim.restart()
        }
    }
    NumberAnimation {
        id: walkAnim
        target: character; property: "x"
        easing.type: Easing.InOutSine
        onRunningChanged: if (!running) character.isWalking = false
    }
    property real fadeOpacity: 1
    SequentialAnimation {
        id: fadeAnim
        property real targetX: 0
        NumberAnimation { target: character; property: "fadeOpacity"; to: 0; duration: 300; easing.type: Easing.InQuad }
        ScriptAction { script: character.x = fadeAnim.targetX }
        NumberAnimation { target: character; property: "fadeOpacity"; to: 1; duration: 300; easing.type: Easing.OutQuad }
    }
    // one unhurried stride per cycle
    NumberAnimation on walkPhase {
        running: character.running && character.isWalking
        from: 0; to: Math.PI * 2
        duration: 1000
        loops: Animation.Infinite
    }

    // =====================================================================
    // Interactions: hover greeting, the treat trick, idle micro-behaviours
    // =====================================================================
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        enabled: character.running
        onClicked: character.playTrick()
    }
    property bool isHovered: mouseArea.containsMouse
    readonly property bool greeting: isHovered && running && pose !== "storm" && !dozing
    property real waveBlend: greeting ? 1 : 0                          // the person's arm raised in a wave, the dog perked up
    Behavior on waveBlend { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }
    onWaveBlendChanged: dirty()
    readonly property bool busy: tricking || activeMicroAction !== "none"

    // Click: pocket, toss, crouch, leap and spin, catch, land, hearts.
    readonly property bool tricking: trickAnimation.running
    property real trickProgress: 0
    NumberAnimation {
        id: trickAnimation
        target: character; property: "trickProgress"
        from: 0; to: 1
        duration: 2400
    }
    onTrickProgressChanged: dirty()
    function playTrick() {
        if (!running || isWalking || walkBlend > 0 || tricking || sceneChangeAnimation.running || fadeAnim.running) return
        if (pose === "storm" || dozing) return
        if (microAnim.running) microAnim.stop()
        trickAnimation.restart()
    }

    // Idle micro-actions: every 12 to 22 s of rest, one in-character thing for 2.5 s.
    property string activeMicroAction: "none"                        // "shakeOff" | "stretch" | "sniff" | "chaseBug"
    property real microPhase: 0
    NumberAnimation {
        id: microAnim
        target: character; property: "microPhase"
        from: 0; to: 1
        duration: 2500
        onRunningChanged: if (!running) character.activeMicroAction = "none"
    }
    onMicroPhaseChanged: dirty()
    onActiveMicroActionChanged: dirty()
    Timer {
        id: microActionTimer
        running: character.running && !character.isWalking && character.walkBlend === 0 && !character.isHovered
                 && !character.tricking && character.activeMicroAction === "none"
                 && !sceneChangeAnimation.running && !fadeAnim.running
        repeat: true
        interval: 12000 + Math.random() * 10000
        onTriggered: { interval = 12000 + Math.random() * 10000; character.startMicroAction() }
    }
    function microCandidates() {
        var s = renderedScene, out = []
        var wetScene = s === "rain" || s === "windyRain" || s === "thunder"
        var easy = s === "calm" || s === "sunnyPlay" || s === "stargaze"
        if (s === "rain" || s === "windyRain" || s === "snow") out.push("shakeOff")
        if (easy) out.push("stretch")
        if (!wetScene && s !== "sleep") out.push("sniff")
        if (easy) out.push("chaseBug")
        return out
    }
    // Public: start a micro-action now; without a name, a random one that fits the scene.
    function startMicroAction(name) {
        if (name === undefined) {
            var c = microCandidates()
            if (c.length === 0) return
            name = c[Math.floor(Math.random() * c.length)]
        }
        activeMicroAction = name
        microAnim.restart()
    }
    function cancelInteractions() {
        if (trickAnimation.running) { trickAnimation.stop(); trickProgress = 0 }
        if (microAnim.running) microAnim.stop()
        activeMicroAction = "none"
    }

    // Clear nights: doze for 30 to 60 s, then sit up and stargaze for as long, and so on.
    Timer {
        running: character.running && (character.renderedScene === "sleep" || character.renderedScene === "stargaze") && !sceneChangeAnimation.running
        repeat: true
        interval: 30000 + Math.random() * 30000
        onTriggered: { interval = 30000 + Math.random() * 30000; character.nightMode = character.nightMode === "gaze" ? "doze" : "gaze" }
    }

    readonly property bool holdingMug: temperature <= 10 && (pose === "calm" || pose === "snow")
    readonly property bool campfire: pose === "snow" || (temperature <= 2 && !wet)

    // =====================================================================
    // The canvas, crouching from the ground line through a scene change
    // =====================================================================
    Item {
        id: scene
        anchors.fill: parent
        opacity: character.fadeOpacity * (character.transitionOpacity / 0.32)
        transform: [
            Scale { origin.y: character.ground; yScale: character.transitionScaleY },
            Translate { y: character.transitionOffsetY }
        ]
        Canvas {   // oversized so a raised umbrella, a tossed ball or a passing leaf is not clipped
            id: art
            x: -character.padX; y: -character.padY
            width: character.width + character.padX * 2
            height: character.height + character.padY
            renderStrategy: Canvas.Cooperative
            onPaint: character.paintScene(getContext("2d"))
        }
    }

    // =====================================================================
    // Maths
    // =====================================================================
    function clamp01(v) { return Math.max(0, Math.min(1, v)) }
    function smooth(v) { v = clamp01(v); return v * v * (3 - 2 * v) }
    // 1 inside [a, b], eased ramps of width r either side, 0 beyond
    function win(u, a, b, r) {
        if (u < a - r || u > b + r) return 0
        if (u < a) return smooth((u - (a - r)) / r)
        if (u > b) return smooth((b + r - u) / r)
        return 1
    }
    function lerp(a, b, w) { return a + (b - a) * w }
    // numbers, arrays or objects, element-wise; strings and the like snap
    function mix(a, c, w) {
        if (w <= 0) return a
        if (w >= 1) return c
        if (typeof a === "number") return a + (c - a) * w
        if (Array.isArray(a)) { var o = []; for (var i = 0; i < a.length; i++) o.push(mix(a[i], c[i], w)); return o }
        if (typeof a === "object" && a !== null) {
            var r = {}, k
            for (k in a) r[k] = (k in c) ? mix(a[k], c[k], w) : (typeof a[k] === "number" ? a[k] * (1 - w) : a[k])
            for (k in c) if (!(k in a)) r[k] = typeof c[k] === "number" ? c[k] * w : c[k]
            return r
        }
        return w < 0.5 ? a : c
    }
    // Two-bone IK: root (rx, ry) to target (tx, ty) with segments l1 and l2;
    // `bend` (+1 / -1) picks which side the joint goes. Out of reach, the
    // chain straightens towards the target. Returns [jointX, jointY, endX, endY].
    function ik(rx, ry, tx, ty, l1, l2, bend) {
        var dx = tx - rx, dy = ty - ry, d = Math.sqrt(dx * dx + dy * dy)
        if (d < 0.001) { dx = 0; dy = 1; d = 0.001 }
        var ux = dx / d, uy = dy / d
        var reach = l1 + l2 - 0.02
        if (d > reach) { d = reach; tx = rx + ux * d; ty = ry + uy * d }
        d = Math.max(Math.abs(l1 - l2) + 0.02, d)
        var a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
        var h = Math.sqrt(Math.max(0, l1 * l1 - a * a))
        return [rx + ux * a - uy * h * bend, ry + uy * a + ux * h * bend, tx, ty]
    }

    // =====================================================================
    // Drawing
    // =====================================================================
    function paintScene(ctx) {
        ctx.reset()
        ctx.translate(padX, padY)
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.strokeStyle = color
        ctx.fillStyle = color
        var self = character, G = ground, t = clock, st = sceneTime, ip = idlePhase
        var fs = facingScale, afs = Math.abs(fs), cx = width / 2
        var turning = afs < 0.95
        var turnDip = turning ? 1.2 * (1 - afs) : 0                   // knees give as they step into the turn
        var lead = turning ? facingDirection * 1.5 * (1 - afs) : 0    // heads lead the turn (world px)
        var b = clamp01(walkBlend), idleW = 1 - b
        var ps = propScale * idleW                                     // prop scale, anchored at the ground
        var dx = personX - 18                                          // person's local frame -> card
        var pro = (pose === "sunny") ? (st % 4) / 4 : 0                // fetch loop phase
        var gust = clamp01(0.5 + 0.5 * Math.sin(ip * 0.8) + 0.3 * Math.sin(ip * 2.3) + 0.3) / 1.3
        var startle = pose === "thunder" ? clamp01((t - flashClock) / 1.8) : 1   // 0 just flashed, 1 settled
        var hunch = pose === "thunder" ? (1 - win(startle, 0.3, 2, 0.2)) : pose === "storm" ? (1 - clamp01((t - flashClock) / 0.25)) : 0
        var stroke = pose === "thunder" ? win(startle, 0.3, 0.85, 0.12) : 0

        // ------------------------------------------------------------------
        // Pen: every point goes through `map` (card coords -> canvas)
        // ------------------------------------------------------------------
        function sceneMap(x, y) { return [cx + (x - cx) * fs, y] }
        var map = sceneMap
        var xs = Math.max(afs, 0.55)                                   // horizontal radius factor for round things: never a line
        var leadX = 0                                                  // world x nudge, used for the heads
        function L(ax, ay, bx, by, w) {
            var a = map(ax, ay), c = map(bx, by)
            ctx.lineWidth = w
            ctx.beginPath(); ctx.moveTo(a[0] + leadX, a[1]); ctx.lineTo(c[0] + leadX, c[1]); ctx.stroke()
        }
        function Pl(pts, w, alpha) {                                   // polyline
            ctx.lineWidth = w
            if (alpha !== undefined) ctx.globalAlpha = alpha
            ctx.beginPath()
            for (var i = 0; i < pts.length; i++) { var p = map(pts[i][0], pts[i][1]); if (i === 0) ctx.moveTo(p[0], p[1]); else ctx.lineTo(p[0], p[1]) }
            ctx.stroke()
            if (alpha !== undefined) ctx.globalAlpha = 1
        }
        function D(x, y, r) {                                          // filled dot, an ellipse under the turn
            var p = map(x, y)
            ctx.beginPath(); ctx.ellipse(p[0] + leadX - r * xs, p[1] - r, r * 2 * xs, r * 2); ctx.fill()
        }
        function E(x, y, w, h) {                                       // filled ellipse (x, y top-left, card coords)
            var a = map(x, y), c = map(x + w, y)
            var l = Math.min(a[0], c[0]), ww = Math.max(0.6, Math.abs(c[0] - a[0]))
            ctx.beginPath(); ctx.ellipse(l, a[1], ww, h); ctx.fill()
        }
        function Q(ax, ay, qx, qy, bx, by, w) {                        // quadratic bezier stroke
            var a = map(ax, ay), q = map(qx, qy), c = map(bx, by)
            ctx.lineWidth = w
            ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.quadraticCurveTo(q[0], q[1], c[0], c[1]); ctx.stroke()
        }
        function C(ax, ay, x1, y1, x2, y2, bx, by, w) {                // cubic bezier stroke
            var a = map(ax, ay), p1 = map(x1, y1), p2 = map(x2, y2), c = map(bx, by)
            ctx.lineWidth = w
            ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.bezierCurveTo(p1[0], p1[1], p2[0], p2[1], c[0], c[1]); ctx.stroke()
        }
        function Poly(pts) {                                           // filled polygon
            ctx.beginPath()
            for (var i = 0; i < pts.length; i++) { var p = map(pts[i][0], pts[i][1]); if (i === 0) ctx.moveTo(p[0], p[1]); else ctx.lineTo(p[0], p[1]) }
            ctx.closePath(); ctx.fill()
        }
        function Ring(x, y, rx, ry, w, alpha) {                        // stroked ellipse outline
            var p = map(x, y)
            ctx.globalAlpha = alpha; ctx.lineWidth = w
            ctx.beginPath(); ctx.ellipse(p[0] - rx * xs, p[1] - ry, rx * 2 * xs, ry * 2); ctx.stroke()
            ctx.globalAlpha = 1
        }
        function Txt(s, x, y, size, alpha) {
            var p = map(x, y)
            ctx.globalAlpha = alpha
            ctx.font = "bold " + size + "px sans-serif"
            ctx.fillText(s, p[0], p[1])
            ctx.globalAlpha = 1
        }
        function Halo(x, y, r, alpha) {                                // soft radial glow
            var p = map(x, y)
            var g = ctx.createRadialGradient(p[0], p[1], 0, p[0], p[1], r)
            g.addColorStop(0, Qt.rgba(self.color.r, self.color.g, self.color.b, alpha))
            g.addColorStop(1, Qt.rgba(self.color.r, self.color.g, self.color.b, 0))
            ctx.fillStyle = g
            ctx.beginPath(); ctx.arc(p[0], p[1], r, 0, Math.PI * 2); ctx.fill()
            ctx.fillStyle = self.color
        }
        function Heart(x, y, s, alpha) {
            ctx.globalAlpha = alpha
            D(x - s * 0.27, y - s * 0.12, s * 0.3)
            D(x + s * 0.27, y - s * 0.12, s * 0.3)
            Poly([[x - s * 0.55, y - s * 0.02], [x + s * 0.55, y - s * 0.02], [x, y + s * 0.55]])
            ctx.globalAlpha = 1
        }

        // ------------------------------------------------------------------
        // Person: skeleton builder (local frame, 36 wide, centred on x = 18)
        // ------------------------------------------------------------------
        var THIGH = 4.8, SHIN = 4.8, UPPER = 4.1, FORE = 4.1
        // o: { hip, neck, head, legs: [{ankle, toe?, bend?} x2], arms: [{hand, bend?, shoulder?} x2], torsoW?, hem?, coat?, headR? }
        function human(o) {
            var hip = [o.hip[0], o.hip[1] + turnDip], neck = [o.neck[0], o.neck[1] + turnDip], head = [o.head[0], o.head[1] + turnDip]
            var legs = [], arms = [], i, r
            for (i = 0; i < 2; i++) {
                var l = o.legs[i]
                r = ik(hip[0], hip[1], l.ankle[0], l.ankle[1], THIGH, SHIN, l.bend === undefined ? -1 : l.bend)
                legs.push([hip[0], hip[1], r[0], r[1], r[2], r[3], l.toe ? l.toe[0] : r[2] + 1.7, l.toe ? l.toe[1] : r[3] + 1])
            }
            var sh = [neck[0], neck[1] + 1]
            for (i = 0; i < 2; i++) {
                var a = o.arms[i], s = a.shoulder || sh
                r = ik(s[0], s[1], a.hand[0], a.hand[1], UPPER, FORE, a.bend === undefined ? 1 : a.bend)
                arms.push([s[0], s[1], r[0], r[1], r[2], r[3]])
            }
            return { head: head, headR: o.headR || 3, neck: neck, hip: hip, legs: legs, arms: arms,
                     torsoW: o.torsoW || 2.4, hem: o.hem || 0, coat: o.coat || 0 }
        }
        // seated on the edge: thighs forward, shins hanging; `sw` are shin swing angles (deg, + = forward)
        function seatedLegs(sw0, sw1) {
            function leg(kx, a) {
                a *= Math.PI / 180
                var ankle = [kx + Math.sin(a) * 4.6, G + 0.6 + Math.cos(a) * 4.6]
                return { ankle: ankle, toe: [ankle[0] + 1.5 + Math.sin(a) * 0.4, ankle[1] + 0.6], bend: -1 }
            }
            return [leg(22.4, sw0), leg(23.6, sw1 - 4)]
        }
        function standingLegs(fx0, fx1) {
            return [{ ankle: [fx0, G - 1], toe: [fx0 + 1.8, G], bend: -1 }, { ankle: [fx1, G - 1], toe: [fx1 + 1.8, G], bend: -1 }]
        }
        function braced(hipX, leanRad, neckLen) {                      // hip, neck and head leaning into the wind (to the left)
            var hip = [hipX, 19.3]
            var neck = [hip[0] - Math.sin(leanRad) * neckLen, hip[1] - Math.cos(leanRad) * neckLen]
            var head = [neck[0] - Math.sin(leanRad) * 4.4, neck[1] - Math.cos(leanRad) * 4.4]
            return { hip: hip, neck: neck, head: head }
        }

        // ------------------------------------------------------------------
        // Dog: skeleton builder (24 x 20 box, ground at y = 20, facing left)
        // ------------------------------------------------------------------
        var DUP = 4.5, DLOW = 4
        // o: { neck, rump, arch?, head, headAng?, jaw?, legs: [{root, paw, bend?} x4], tail: [x, y, deg], ear: [x, y, rad], bodyW?, flip?, dx?, dy?, curl?, spin?, neckBend? }
        function dog(o) {
            var legs = []
            for (var i = 0; i < 4; i++) {
                var l = o.legs[i]
                var r = ik(l.root[0], l.root[1], l.paw[0], l.paw[1], DUP, DLOW, l.bend === undefined ? -1 : l.bend)
                legs.push([l.root[0], l.root[1], r[0], r[1], r[2], r[3]])
            }
            var nm = ik(o.neck[0], o.neck[1], o.head[0], o.head[1], 2.4, 2.4, o.neckBend === undefined ? 1 : o.neckBend)
            return { neck: o.neck, rump: o.rump, arch: o.arch || 0, neckMid: [nm[0], nm[1]], head: o.head, headR: o.headR || 3,
                     headAng: o.headAng || 0, jaw: o.jaw || 0, legs: legs, tail: o.tail, ear: o.ear, bodyW: o.bodyW || 5.5,
                     flip: o.flip === undefined ? 1 : o.flip, dx: o.dx || 0, dy: o.dy || 0, curl: o.curl || 0, spin: o.spin || 0,
                     perk: 0, nose: 0 }
        }
        function legSet(roots, paws) {
            var out = []
            for (var i = 0; i < 4; i++) out.push({ root: roots[i], paw: paws[i] })
            return out
        }
        var STAND_ROOTS = [[6.5, 12.5], [8.5, 12.5], [14, 12.5], [16, 12.5]]
        function dogStand() {
            return { neck: [6, 9.5], rump: [16.5, 10], head: [3.5, 7.5], legs: legSet(STAND_ROOTS, [[6, 20], [8.5, 20], [14, 20], [16.5, 20]]),
                     tail: [17.5, 9.5, -35], ear: [4.5, 5.5, 0] }
        }
        function dogSit() {
            return { neck: [7, 9], rump: [15, 15.5], bodyW: 4.6, head: [5, 6.5],
                     legs: legSet([[8, 11], [11, 12], [15, 16], [15.5, 16.5]], [[8, 20], [11, 20], [12, 19.8], [13, 19.8]]),
                     tail: [18, 18.5, -10], ear: [5.5, 4, 0] }
        }
        function dogCrouch() {
            return { neck: [6, 14.5], rump: [16, 14.5], bodyW: 4.5, head: [3.5, 13],
                     legs: legSet([[6, 16], [8, 16], [14, 16], [16, 16]], [[5.5, 20], [8.5, 20], [14, 20], [16.5, 20]]),
                     tail: [17, 15.5, 0], ear: [4, 10.5, 0] }
        }
        function dogBow() {                                            // play bow: front down, rear up, tail up
            return { neck: [7, 15], rump: [16, 11], bodyW: 4.6, head: [4.5, 13.5],
                     legs: legSet([[7, 16], [9, 16], [16, 14], [18, 14]], [[3, 20], [7, 20], [17, 20], [19, 20]]),
                     tail: [19, 8, -80], ear: [5, 11, 0] }
        }
        function dogRearUp() {                                         // front paws lifted high
            return { neck: [7, 8], rump: [16, 13], bodyW: 5, head: [4, 5.5], headAng: -0.3,
                     legs: legSet([[7, 11], [9, 11], [14, 15], [16, 15]], [[4, 15], [6.5, 15.5], [14, 20], [16.5, 20]]),
                     tail: [18.5, 12, -50], ear: [5, 3.5, 0] }
        }
        function dogDive() {                                           // nose down into the snow
            return { neck: [7, 13], rump: [16, 11.5], bodyW: 4.8, head: [2.5, 17], headAng: 1.1,
                     legs: legSet([[7, 15], [9, 15], [16, 14], [18, 14]], [[3.5, 20], [7, 20], [17, 20], [19, 20]]),
                     tail: [19, 9, -60], ear: [3.5, 14, -0.6] }
        }
        function dogRearStretch() {                                    // hind legs stretched out behind
            return { neck: [6, 10], rump: [15, 13], bodyW: 5, head: [3.5, 8],
                     legs: legSet([[6.5, 12.5], [8.5, 12.5], [15, 14.5], [16.5, 14.5]], [[6, 20], [8.5, 20], [20, 20], [21.5, 20]]),
                     tail: [17, 12, -20], ear: [4.5, 6, 0] }
        }
        function dogSniff() {                                          // neck down, nose on the ground
            return { neck: [6.5, 11], rump: [16.5, 10], head: [3, 15.5], headAng: 0.95,
                     legs: legSet([[7, 13.5], [9.5, 13.5], [14, 12.5], [16, 12.5]], [[6, 20], [9, 20], [14, 20], [16.5, 20]]),
                     tail: [17.5, 9.5, -25], ear: [4.5, 12.5, -0.9] }
        }
        function dogCurl() {
            return { neck: [8, 14], rump: [17, 15], bodyW: 5, head: [6, 14], curl: 1,
                     legs: legSet([[10, 17], [11, 17], [15, 17], [16, 17]], [[12, 19.5], [13, 19.5], [15, 19.5], [16, 19.5]]),
                     tail: [18, 15, 0], ear: [7, 11, 0] }
        }
        // trot: diagonal pairs with a 0.3 rad offset so all four legs read
        function dogTrot(ph) {
            var o = dogStand()
            var offs = [0, Math.PI + 0.3, Math.PI, 0.3]                 // FL, FR, BL, BR
            for (var i = 0; i < 4; i++) {
                var s = Math.sin(ph + offs[i])
                var rx = STAND_ROOTS[i][0]
                o.legs[i] = { root: STAND_ROOTS[i], paw: [rx - 0.5 - s * 2.2, 20 - Math.max(0, s) * 2.2] }
            }
            o.arch = Math.sin(ph * 2) * 0.7
            o.head = [3.5, 7.5 + Math.sin(ph * 2) * 1.1]
            o.ear = [4.5, 5.5 + Math.sin(ph * 2) * 1.1, Math.sin(ph * 2 - 0.5) * 0.35]
            o.dy = -Math.abs(Math.sin(ph + 0.8)) * 0.5
            o.flip = -1
            return o
        }
        function shiftBody(o, ox, oy) {                                // move the body and head, paws stay planted (crouch)
            o.neck = [o.neck[0] + ox, o.neck[1] + oy]; o.rump = [o.rump[0] + ox, o.rump[1] + oy]; o.head = [o.head[0] + ox, o.head[1] + oy]
            o.tail = [o.tail[0] + ox, o.tail[1] + oy, o.tail[2]]; o.ear = [o.ear[0] + ox, o.ear[1] + oy, o.ear[2]]
            for (var i = 0; i < 4; i++) o.legs[i] = { root: [o.legs[i].root[0] + ox, o.legs[i].root[1] + oy], paw: o.legs[i].paw, bend: o.legs[i].bend }
            return o
        }

        // ------------------------------------------------------------------
        // Scene poses
        // ------------------------------------------------------------------
        // Person: returns { pose, umb, hat, scarfWind, coatTail, palm, mugHand, puff, ball }
        function humanIdle() {
            var r = { hat: 0, scarfWind: 0, coatTail: 0, umb: null, palm: 0, mugHand: 1, shiver: 0 }
            var hip, neck, head, legs, arms, o
            switch (pose) {
            case "calm": {
                var swayX = Math.sin(t * 1.2) * 0.4
                hip = [18, G - 0.5]; neck = [19.4 + swayX, G - 11.3]; head = [20 + swayX, G - 14.6]
                legs = seatedLegs(Math.sin(ip * 0.35) * 10, Math.sin(ip * 0.45 + 1) * 10)
                // front hand scratching behind the dog's ear (the dog sits at 14, head at box (5, 6.5))
                var earCard = [self.idleDogX + 6.5, G - 20 + 4.4]
                arms = [ { hand: [13.5, G - 0.3], bend: 1 },
                         { hand: [earCard[0] - dx + Math.sin(ip * 6) * 0.6, earCard[1] + 0.2 + Math.abs(Math.cos(ip * 6)) * 0.4], bend: 1 } ]
                break
            }
            case "sunny": {
                var lb = 0.5 + 0.5 * Math.sin(st * 0.5)                // leaning back onto one hand, and forward again
                hip = [18, G - 0.5]; neck = [18 - 2.2 * lb, G - 11.2]; head = [18.3 - 2.8 * lb, G - 14.5]
                legs = seatedLegs(Math.sin(ip) * 9, -4)
                var u = pro, th
                if (u < 0.1) th = mix([22, G - 6.5], [15, G - 16], smooth(u / 0.1))            // wind up: back and high
                else if (u < 0.2) th = mix([15, G - 16], [26, G - 14.5], smooth((u - 0.1) / 0.1))   // throw
                else if (u < 0.5) th = mix([26, G - 14.5], [22, G - 6.5], smooth((u - 0.2) / 0.3))   // arm comes down to the lap
                else if (u < 0.9) th = [22, G - 6.5]
                else { var k3 = Math.sin((u - 0.9) / 0.1 * Math.PI); th = [22 + 2.5 * k3, G - 6.5 + 6.5 * k3] }   // reach down for the ball
                arms = [ { hand: [13, G - 0.3], bend: 1 }, { hand: th, bend: 1 } ]
                r.hat = 1
                break
            }
            case "night": {
                var u6 = st % 6, nod
                if (u6 < 3) nod = 1 - Math.cos(u6 / 3 * Math.PI / 2)                         // nodding off, ever faster
                else if (u6 < 3.6) nod = 1 - 0.5 * smooth((u6 - 3) / 0.6)                    // a half perk-up
                else if (u6 < 5.6) nod = 0.5 + 0.5 * (1 - Math.cos((u6 - 3.6) / 2 * Math.PI / 2))
                else nod = 1 - smooth((u6 - 5.6) / 0.4)
                hip = [18, G - 0.5]; neck = [18.2 + nod * 0.8, G - 11 + nod * 0.8]; head = [18.8 + nod * 1.8, G - 14.2 + nod * 2.4]
                legs = [ { ankle: [22.3, G - 1.2], toe: [24, G - 0.2], bend: -1 }, { ankle: [23, G - 1], toe: [24.6, G], bend: -1 } ]   // knees drawn up
                arms = [ { hand: [22.3, G - 5.8], bend: 1 }, { hand: [22.8, G - 5.2], bend: 1 } ]                                       // wrapped round them
                break
            }
            case "gaze": {
                hip = [18, G - 0.5]; neck = [15.6, G - 11]; head = [15, G - 15]
                legs = seatedLegs(Math.sin(ip * 0.3) * 4, 0)
                arms = [ { hand: [12.5, G - 0.3], bend: 1 }, { hand: [14.5, G - 0.3], bend: 1 } ]
                break
            }
            case "rain":
            case "thunder": {
                var sy = pose === "thunder" ? 0.8 : 0
                hip = [18, G - 0.5]
                neck = [18.4 + stroke * 3.5, G - 11.2 + hunch * 1.6 + sy + stroke * 3]
                head = [19 + stroke * 4.5, G - 14.4 + hunch * 1.8 + sy + stroke * 4]
                legs = seatedLegs(0, 0)
                var grip = [25, G - 12 + hunch * 3 + stroke * 1.5]
                var free
                if (stroke > 0) {                                      // stroking the dog's back, three passes
                    var sx = 28 + 2.5 * Math.sin((startle - 0.3) / 0.55 * Math.PI * 3)
                    free = mix([15.5, G - 2], [sx, 17.6], stroke)
                } else if (pose === "rain") {                          // a palm out past the rim now and then
                    var u8 = st % 8, hw = win(u8, 5.4, 6.6, 0.4)
                    free = mix([15.5, G - 2], [9.5, G - 10.5], hw)
                    r.palm = hw
                    r.splash = win(u8, 5.95, 6.25, 0.08)
                } else free = [15.5, G - 2]
                arms = [ { hand: free, bend: 1 }, { hand: grip, bend: 1 } ]
                var drops = canopyDrops()
                r.umb = { x: grip[0], y: grip[1], tilt: 0, r: 14, shaft: 6, flip: 0, bounce: 1, recoil: drops.recoil }
                r.drops = drops
                break
            }
            case "storm": {
                var fl = flipState()
                var lean = 0.28 + 0.22 * gust - fl.tug * 0.12
                o = braced(17.2, lean, 9.8)
                hip = o.hip; neck = o.neck; head = o.head
                neck[1] += hunch * 1.2; head[1] += hunch * 1.4
                legs = [ { ankle: [13.3, G - 1], toe: [15, G], bend: -1 }, { ankle: [22.6, G - 1], toe: [24.3, G], bend: -1 } ]
                var gr = [neck[0] + 4 - fl.tug * 2, neck[1] + 4.5 + fl.tug * 2]
                arms = [ { hand: fl.k > 0 ? [gr[0] + 0.4, gr[1] + 0.9] : [neck[0] - 1.5, neck[1] + 7.2], bend: 1 }, { hand: gr, bend: 1 } ]
                r.umb = { x: gr[0], y: gr[1], tilt: -30 + fl.tug * 14, r: 8, shaft: 8, flip: fl.k, bounce: fl.bounce, recoil: 0 }
                r.scarfWind = 0.6 + gust * 0.6; r.coatTail = 0.6 + gust * 0.6
                break
            }
            case "windy": {
                var lean2 = 0.2 + 0.14 * gust
                o = braced(17.5, lean2, 9.8)
                hip = o.hip; neck = o.neck; head = o.head
                legs = [ { ankle: [14, G - 1], toe: [15.7, G], bend: -1 }, { ankle: [21.5, G - 1], toe: [23.2, G], bend: -1 } ]
                arms = [ { hand: [head[0] - 0.8, head[1] - 5.2], bend: 1 }, { hand: [neck[0] + 1.8, neck[1] + 7.4], bend: 1 } ]
                r.hat = 1; r.scarfWind = 0.5 + gust * 0.5; r.coatTail = 0.5 + gust * 0.5
                break
            }
            case "snow": {
                var cyc = st % 5, idx = Math.floor(st / 5)
                var raise = win(cyc, 0.5, 1.4, 0.4)
                var sip = self.holdingMug && idx % 2 === 0
                hip = [18, 19]; neck = [18, 9.5]; head = [18, 5]
                legs = standingLegs(15.3, 20.3)
                var hug0 = [21, 15], hug1 = [15.2, 15.5]
                if (sip) arms = [ { hand: hug0, bend: 1 }, { hand: mix(hug1, [20.6, 7.4], raise), bend: 1 } ]
                else { arms = [ { hand: mix(hug0, [19.6, 7.6], raise), bend: 1 }, { hand: mix(hug1, [20.6, 8], raise), bend: 1 } ]; r.puff = clamp01((cyc - 0.9) / 1.2) }
                r.mugHand = 1
                r.coat = 1
                r.shiver = win(t % 1.8, 1.25, 1.55, 0.05) * Math.sin(t * 75)
                break
            }
            default:
                hip = [18, 19]; neck = [18, 9.5]; head = [18, 5]
                legs = standingLegs(15.5, 20.5)
                arms = [ { hand: [17, 18], bend: 1 }, { hand: [19, 18], bend: 1 } ]
            }
            r.pose = human({ hip: hip, neck: neck, head: head, legs: legs, arms: arms,
                             torsoW: pose === "snow" ? 3.6 : 2.4, coat: pose === "snow" ? 1 : 0 })
            if (r.umb) { r.umb.x = r.pose.arms[1][4]; r.umb.y = r.pose.arms[1][5] }   // the umbrella rides on the solved hand
            return r
        }
        // Rain: drops landing on the canopy, each with a recoil and a splash
        function canopyDrops() {
            var slots = [ { x: -7, off: 0 }, { x: 6, off: 0.65 } ], period = 1.4, recoil = 0, list = []
            for (var i = 0; i < slots.length; i++) {
                var u = (st + slots[i].off) % period
                var fall = u / 0.5
                if (fall < 1) list.push({ x: slots[i].x, fall: fall, splash: 0 })
                else {
                    var sp = (u - 0.5) / 0.28
                    recoil += 0.8 * Math.exp(-(u - 0.5) * 11)
                    if (sp < 1) list.push({ x: slots[i].x, fall: 1, splash: sp })
                }
            }
            return { list: list, recoil: Math.min(0.8, recoil) }
        }
        // Storm: every 4.5 s the canopy blows inside-out for 1.6 s, is tugged twice and snaps back
        function flipState() {
            var u = st % 4.5
            var k = win(u, 1.1, 2.5, 0.12)
            var tug = win(u, 1.5, 1.6, 0.14) + win(u, 2.0, 2.1, 0.14)
            var bounce = 1
            if (u > 2.62 && u < 3.3) { var e = u - 2.62; bounce = 1 + 0.2 * Math.sin(e * Math.PI * 2 / 0.35) * Math.exp(-e * 5) }
            return { k: k, tug: Math.min(1, tug), bounce: bounce }
        }
        function humanWalk() {
            var wp = self.walkPhase, s = Math.sin(wp)
            var bob = -Math.abs(s) * 0.6, sway = s * 0.3
            var windLean = self.gusty ? fs : 0                         // leaning into the wind whichever way they go
            var hip = [18 - sway, 19 + bob]
            var neck = [18.6 + sway - 2.2 * windLean, 9.6 + bob]
            var head = [19 - 3.2 * windLean, 5 + bob + Math.sin(wp * 2 - 0.4) * 0.7]
            var legs = []
            for (var i = 0; i < 2; i++) {
                var p = wp + i * Math.PI, ss = Math.sin(p), cc = Math.cos(p)
                var lift = Math.max(0, ss) * 2.8                       // foot clears the ground on the forward swing
                var heel = Math.max(0, -ss) * Math.max(0, cc) * 1.3    // heel rises, rolling onto the toe at push-off
                var fx = 18 + ss * 2.5
                legs.push({ ankle: [fx, G - 1 - lift - heel], toe: [fx + 1.7, G - lift + (lift > 0.2 ? 0.4 : 0)], bend: -1 })
            }
            var arms = [ { hand: [18.3 - s * 2.2, 17.3], bend: 1 },
                         self.wet ? { hand: [21, 13.5], bend: 1 } : { hand: [18.3 + s * 2.2, 17.3], bend: 1 } ]
            return human({ hip: hip, neck: neck, head: head, legs: legs, arms: arms, hem: 1,
                           torsoW: pose === "snow" ? 3.6 : 2.4, coat: pose === "snow" ? 1 : 0 })
        }

        // Dog: returns the pose spec for the scene, plus wag rate/amplitude
        function dogIdle() {
            var o, r = { wagAmp: 14, wagRate: Math.PI * 2 / 0.6, earA: 0, earFlutter: 0, snowCap: 0 }
            switch (pose) {
            case "calm": {
                o = dogSit()
                o.head = [4.6, 6.2]; o.headAng = -0.12                 // leaning into the hand
                var th = win(st % 4, 1, 2, 0.2)                        // the happy hind-leg thump
                o.legs[2] = { root: [15, 16], paw: [12 + Math.sin(ip * 12) * 0.9 * th, 19.8 - Math.abs(Math.sin(ip * 12)) * 2 * th] }
                r.wagAmp = 14 + 8 * th; r.wagRate = Math.PI * 2 / (0.6 - 0.3 * th)
                break
            }
            case "sunny": {                                            // fetch: bow, spring after the ball, trot it back
                var u = pro
                r.wagAmp = 20; r.wagRate = Math.PI * 2 / 0.36
                if (u < 0.2) { o = dogBow(); o.tail = [19, 8, -80] }
                else if (u < 0.3) o = mix(dogBow(), dogStand(), smooth((u - 0.2) / 0.1))
                else if (u < 0.5) {
                    var k = smooth((u - 0.3) / 0.2)
                    o = dogBow(); o.flip = -1; o.dx = 12 * k; o.dy = -7 * Math.sin(k * Math.PI)
                    o.legs[0] = { root: [7, 16], paw: [2, 18 - 2 * k] }; o.legs[1] = { root: [9, 16], paw: [5, 18.5 - 2 * k] }
                    o.head = [4.5, 12.5]; o.headAng = -0.4
                } else if (u < 0.58) {
                    var k2 = Math.sin((u - 0.5) / 0.08 * Math.PI)
                    o = shiftBody(dogStand(), 0, 1.4 * k2); o.flip = -1; o.dx = 12
                } else if (u < 0.9) {
                    var k3 = (u - 0.58) / 0.32
                    o = dogTrot(st * Math.PI * 2 * 1.6); o.flip = 1; o.dx = 12 - 12 * smooth(k3)
                    if (k3 < 0.15) o.flip = mix(-1, 1, k3 / 0.15)
                } else {
                    var k4 = (u - 0.9) / 0.1
                    o = mix(dogStand(), dogSit(), smooth(k4)); o.head = [4.5, 7.5 + 6 * Math.sin(k4 * Math.PI)]; o.headAng = 0.6 * Math.sin(k4 * Math.PI)
                }
                break
            }
            case "night": {
                o = dogCurl()
                r.wagAmp = 0
                break
            }
            case "gaze":
                o = dogSit(); o.head = [4.6, 6]; o.headAng = -0.3
                break
            case "rain":
            case "thunder": {
                o = dogSit(); o.flip = -1                               // facing away from the person, towards the puddle
                o.headAng = Math.sin(st * 1.5) * 0.22
                r.wagAmp = 10; r.wagRate = Math.PI * 2 / 1.8
                if (pose === "rain") {
                    var u5 = st % 5, tapU = clamp01((u5 - 3.2) / 0.9)   // a paw into the puddle
                    if (tapU > 0 && tapU < 1) {
                        var out = win(tapU, 0.3, 0.7, 0.3)
                        var tapY = tapU > 0.3 && tapU < 0.7 ? Math.abs(Math.sin((tapU - 0.3) / 0.4 * Math.PI * 2)) * 1.6 : 0
                        o.legs[0] = { root: [8, 11], paw: [8 - 5.5 * out, 20 - out * (1.8 - tapY)] }
                        r.tap = out
                    }
                } else {
                    var scr = 1 - win(startle, 0.25, 2, 0.2)           // scrambling against the ankles
                    o.dx = -2.2 * scr; o.tail = [18, 18.5, 35 * scr - 10]; o = shiftBody(o, 0, 0.8 * scr)
                    r.wagAmp = 10 * (1 - scr)
                }
                break
            }
            case "storm":
                o = dogCrouch()
                r.wagAmp = 8; r.wagRate = Math.PI * 2 / 0.19
                r.earA = 1.35; r.earFlutter = 0.3 * (0.5 + gust)
                break
            case "windy": {
                o = dogStand()
                r.wagAmp = 8; r.wagRate = Math.PI * 2 / 0.19
                r.earA = 1.0; r.earFlutter = 0.25 * (0.5 + gust)
                var lf = leafState()
                if (lf.snap > 0) { o.dy = -3.2 * lf.snap; o.head = [3.5, 6.5]; o.headAng = -0.5 * lf.snap; o.jaw = lf.snap
                                   o.legs[0].paw = [6, 20 - 2 * lf.snap]; o.legs[1].paw = [8.5, 20 - 2 * lf.snap] }
                break
            }
            case "snow": {                                             // pounce cycle into the snowdrift
                var u35 = (st % 3.5) / 3.5
                r.wagAmp = 20; r.wagRate = Math.PI * 2 / 0.36
                if (u35 < 0.25) o = mix(dogStand(), dogRearUp(), win(u35, 0.12, 0.25, 0.12))
                else if (u35 < 0.45) { var kd = smooth((u35 - 0.25) / 0.2); o = mix(dogRearUp(), dogDive(), kd); o.dx = -1.5 * kd }
                else if (u35 < 0.6) { o = dogDive(); o.dx = -1.5 }
                else if (u35 < 0.75) { var ku = smooth((u35 - 0.6) / 0.15); o = mix(dogDive(), dogStand(), ku); o.dx = -1.5 * (1 - ku); r.snowCap = ku }
                else if (u35 < 0.9) { o = dogStand(); var ks = (u35 - 0.75) / 0.15; o.head = [3.5 + Math.sin(ks * 40) * 1.2, 7.5]; r.snowCap = 1 - ks; r.capFly = ks }
                else o = dogStand()
                break
            }
            default:
                o = dogStand()
            }
            r.o = o
            return r
        }
        function leafState() {                                         // a leaf tumbling past the dog's nose every 6 s
            var u = (st % 6) / 1.6
            if (u >= 1) return { v: -1, snap: 0 }
            return { v: u, snap: win(u, 0.5, 0.62, 0.1) }
        }

        // ------------------------------------------------------------------
        // Overlays: hover, micro-actions, trick
        // ------------------------------------------------------------------
        var tp = self.tricking ? self.trickProgress : -1
        var mp = self.microPhase, ma = self.activeMicroAction
        var micro = ma !== "none" ? win(mp, 0.25, 0.75, 0.25) : 0
        var wave = self.waveBlend

        // Person
        var hi = humanIdle(), hp = hi.pose
        var sh = [hp.neck[0], hp.neck[1] + 1]
        function reArm(i, hand, bend) {
            var r = ik(sh[0], sh[1], hand[0], hand[1], UPPER, FORE, bend === undefined ? 1 : bend)
            return [sh[0], sh[1], r[0], r[1], r[2], r[3]]
        }
        var mugHand = self.holdingMug ? hi.mugHand : -1
        if (self.holdingMug && pose === "calm") hp.arms[1] = mix(hp.arms[1], reArm(1, [23.5, sh[1] + 4.5]), 1)   // calm: the front hand cradles the cup
        if (wave > 0) {                                                // a friendly wave from the free arm, out past the head
            var wi = mugHand === 1 || pose === "calm" ? 0 : 1
            var wa = (wi === 0 ? -1 : 1) * (50 + Math.sin(ip * 4) * 20) * Math.PI / 180
            hp.arms[wi] = mix(hp.arms[wi], reArm(wi, [sh[0] + Math.sin(wa) * 8, sh[1] - Math.cos(wa) * 8], wi === 0 ? -1 : 1), wave)
        }
        if (ma === "stretch") {                                        // both arms up in a V past the head
            var stw = win(mp, 0.3, 0.6, 0.3), sway = Math.sin(ip) * 0.5
            hp.arms[0] = mix(hp.arms[0], reArm(0, [sh[0] - 4.2 + sway, sh[1] - 7.2], 1), stw)
            hp.arms[1] = mix(hp.arms[1], reArm(1, [sh[0] + 4.2 + sway, sh[1] - 7.2], 1), stw)
        }
        if (tp >= 0) {                                                 // reach into the pocket, toss, lean to watch
            var pk = win(tp, 0.06, 0.12, 0.06), ts = win(tp, 0.2, 0.26, 0.06)
            var tossHand = mix([hp.hip[0] + 1.6, hp.hip[1] + 0.8], [sh[0] + 6, sh[1] - 4.5], ts)
            var tw = Math.max(pk, ts) * (1 - win(tp, 0.5, 2, 0.15))
            hp.arms[1] = mix(hp.arms[1], reArm(1, tossHand, 1), tw)
            var leanT = win(tp, 0.1, 0.25, 0.1) * 0.9
            hp.neck[0] += leanT; hp.head[0] += leanT * 1.6; hp.head[1] += leanT * 0.4
        }
        var hw = humanWalk()
        var hb = mix(hp, hw, b)
        var umbW = self.wet ? { x: 21, y: 13.5, tilt: pose === "storm" ? -25 * fs : 10, r: 9, shaft: 9, flip: 0, bounce: 1, recoil: 0 } : null
        var umb = hi.umb && umbW ? mix(hi.umb, umbW, b) : null
        var shiver = (hi.shiver || 0) * idleW

        // Dog
        var di = dogIdle(), ds = di.o
        var dw = dogTrot(self.walkPhase)
        var wagAmp = mix(di.wagAmp, 20, b), wagRate = mix(di.wagRate, Math.PI * 2 / 0.36, b)
        if (self.greeting) { wagAmp = mix(wagAmp, 22, wave); wagRate = mix(wagRate, Math.PI * 2 / 0.18, wave) }
        var earA = mix(di.earA, 0, b), earFl = mix(di.earFlutter, 0, b)
        var dpose = dog(ds)
        var droplets = [], puffs = [], rings = [], bug = null
        if (ma === "shakeOff") {                                       // a wave travelling head -> shoulders -> hips -> tail
            var ph = mp * 50, amp = 1.5 * micro
            dpose.head = [dpose.head[0] + Math.sin(ph) * amp, dpose.head[1]]
            dpose.neckMid = [dpose.neckMid[0] + Math.sin(ph - 0.4) * amp, dpose.neckMid[1]]
            dpose.neck = [dpose.neck[0] + Math.sin(ph - 0.8) * amp, dpose.neck[1]]
            dpose.rump = [dpose.rump[0] + Math.sin(ph - 1.6) * amp, dpose.rump[1]]
            dpose.tail = [dpose.tail[0] + Math.sin(ph - 2.4) * amp, dpose.tail[1], dpose.tail[2]]
            dpose.ear = [dpose.ear[0] + Math.sin(ph - 0.3) * amp, dpose.ear[1], dpose.ear[2]]
            for (var k = 0; k < 6; k++) {                              // six droplets flung out on gravity arcs
                var born = 0.22 + k * 0.05, age = (mp - born) * 2.5    // seconds since launch
                if (age > 0) {
                    var ang = -Math.PI * 0.95 + k * Math.PI * 0.18, sp = 16 + (k % 3) * 4
                    droplets.push({ x: 11 + Math.cos(ang) * sp * age, y: 9 + Math.sin(ang) * sp * age + 40 * age * age, a: 1 - clamp01(age / 0.8) })
                }
            }
        } else if (ma === "stretch") {                                 // bow, hold with a yawn, then stretch the hind legs
            var wBow = win(mp, 0.3, 0.55, 0.3) * (1 - win(mp, 0.72, 2, 0.17))
            var wRear = win(mp, 0.72, 0.85, 0.17)
            var bow = dogBow(); bow.jaw = win(mp, 0.4, 0.5, 0.08)
            dpose = mix(dpose, dog(bow), wBow)
            dpose = mix(dpose, dog(dogRearStretch()), wRear)
            wagAmp = mix(wagAmp, 24, wBow); wagRate = mix(wagRate, Math.PI * 2 / 0.3, wBow)
        } else if (ma === "sniff") {                                   // nose down, four creeping steps along the ground
            var sn = dogSniff()
            sn.headAng += Math.sin(t * 30) * 0.05 * win(mp, 0.3, 0.7, 0.1)   // nose twitch
            var steps = 0
            for (var sk = 0; sk < 4; sk++) steps += smooth((mp - (0.2 + sk * 0.15)) / 0.08)
            var back = mp > 0.82 ? 1 - smooth((mp - 0.82) / 0.18) : 1
            sn.dx = -1.6 * steps * back
            var shuffle = Math.sin(mp * 60) * 0.7 * win(mp, 0.2, 0.68, 0.05)
            sn.legs[0].paw = [6 - shuffle, 20]; sn.legs[1].paw = [9 + shuffle, 20]
            dpose = mix(dpose, dog(sn), micro)
            earA = mix(earA, -0.9, micro)
            for (var pk2 = 0; pk2 < 2; pk2++) {                        // a scent puff at the nose
                var pa = (mp - (0.32 + pk2 * 0.3)) / 0.12
                if (pa > 0 && pa < 1) rings.push({ box: true, x: 1 - pa * 1.5, y: 16.5 - pa * 1.5, r: 0.6 + pa * 1.6, a: 0.6 * (1 - pa) })
            }
        } else if (ma === "chaseBug") {                                // head follows the bug overhead, then a hop after it
            var bt = -0.42 * Math.sin(Math.PI * clamp01((mp - 0.1) / 0.75))
            var hop = mp > 0.45 && mp < 0.65 ? -3 * Math.sin((mp - 0.45) / 0.2 * Math.PI) : 0
            dpose.headAng += bt; dpose.dy += hop; dpose.dx += -hop * 0.6
            bug = { x: -4 + (self.width + 8) * mp, y: 8 + Math.sin(mp * Math.PI * 4) * 3 }
        }
        var hearts = [], treat = null
        if (tp >= 0) {                                                 // the treat trick
            var crouch = win(tp, 0.2, 0.3, 0.08) * (1 - win(tp, 0.34, 2, 0.05)) + win(tp, 0.72, 0.78, 0.06) * (1 - win(tp, 0.84, 2, 0.08))
            var leapK = tp > 0.3 && tp < 0.72 ? Math.sin((tp - 0.3) / 0.42 * Math.PI) : 0
            var spin = Math.PI * 2 * smooth((tp - 0.4) / 0.24)
            var cr = shiftBody(dogStand(), 0, 2.2)
            var tuck = dogStand()
            for (var li = 0; li < 4; li++) tuck.legs[li] = { root: STAND_ROOTS[li], paw: [STAND_ROOTS[li][0] + (li < 2 ? -1 : 1), 16.5] }
            tuck.jaw = win(tp, 0.52, 0.58, 0.04)
            tuck.headAng = -0.35
            dpose = mix(dpose, dog(cr), crouch)
            dpose = mix(dpose, dog(tuck), leapK)
            dpose.dy += -11 * leapK
            dpose.spin = spin * (fs < 0 ? -1 : 1) * (dpose.flip < 0 ? -1 : 1)
            var treatU = (tp - 0.24) / 0.32
            if (treatU > 0 && treatU < 1) {
                var from = [hb.arms[1][4] + dx, hb.arms[1][5]], to = [self.dogX + 12 + (dpose.head[0] - 4 - 12) * dpose.flip, G - 20 + dpose.head[1] - 11]
                treat = [lerp(from[0], to[0], treatU), lerp(from[1], to[1], treatU) - Math.sin(treatU * Math.PI) * 9]
            }
            for (var hk = 0; hk < 2; hk++) {
                var hu = (tp - 0.6 - hk * 0.1) / 0.4
                if (hu > 0 && hu < 1) hearts.push({ x: self.dogX + 6 + hk * 5 + Math.sin(hu * Math.PI * 2 + hk) * 1.5, y: G - 24 - hu * 10, a: 1 - hu })
            }
        }
        var dmix = mix(dpose, dog(dw), b)
        dmix.perk = wave

        // ------------------------------------------------------------------
        // Draw: props, dog, person, umbrella, effects
        // ------------------------------------------------------------------
        ctx.globalAlpha = 1
        // ground props
        if (ps > 0.01) {
            if (pose === "snow") {
                D(4, G - 3 * ps, 3 * ps); D(4, G - 8.2 * ps, 2.3 * ps)                       // snowman
                E(29, G - 2.4 * ps, 8, 2.4 * ps + 0.4)                                    // snowdrift
            }
            if (self.campfire) campfire(pose === "snow" ? 18 : (self.idlePersonX + 8 + self.idleDogX) / 2, ps)
            if (pose === "gaze") telescope(4, ps)
            if (pose === "night") lantern(4, ps)
            if (pose === "rain") {                                     // a flat puddle beside the dog
                ctx.globalAlpha = 0.22
                E(42 - 7 * ps, G - 1.5, 14 * ps, 2 * ps)
                ctx.globalAlpha = 1
            }
        }

        // leash on a walk: a slack catenary from the lowered hand to the dog's collar
        if (b > 0.1) {
            var hand = [hb.arms[0][4] + dx, hb.arms[0][5]]
            var collar = dogCard(dmix, dmix.neck[0], dmix.neck[1] + 1)
            var mid = [(hand[0] + collar[0]) / 2, Math.max(hand[1], collar[1]) + 3 + Math.sin(self.walkPhase * 2) * 0.6]
            ctx.globalAlpha = 0.22 * clamp01((b - 0.1) / 0.3)
            Q(hand[0], hand[1], mid[0], mid[1], collar[0], collar[1], 0.7)
            ctx.globalAlpha = 1
        }

        drawDog(dmix, wagAmp, wagRate, earA, earFl, di)
        drawHuman(hb, hi, shiver)
        if (umb) umbrella(umb)

        // effects, in card coordinates
        if (bug) {
            if (self.isNight) {
                var gl = 0.5 + 0.5 * Math.sin(ip * 2)
                ctx.globalAlpha = 0.1 + 0.12 * gl; D(bug.x, bug.y, 3)
                ctx.globalAlpha = 0.45 + 0.55 * gl; D(bug.x, bug.y, 1)
                ctx.globalAlpha = 1
            } else {
                var beat = 0.25 + 0.75 * (0.5 + 0.5 * Math.sin(ip * 6))
                L(bug.x - 0.4, bug.y, bug.x - 0.4 - 1.6 * beat, bug.y - 0.6 * beat, 1.3)
                L(bug.x + 0.4, bug.y, bug.x + 0.4 + 1.6 * beat, bug.y - 0.6 * beat, 1.3)
            }
        }
        for (var dr = 0; dr < droplets.length; dr++) {
            var dd = droplets[dr], pt = dogCard(dmix, dd.x, dd.y)
            if (pt[1] < G && dd.a > 0) { ctx.globalAlpha = dd.a; D(pt[0], pt[1], 1.1); ctx.globalAlpha = 1 }
        }
        for (var rg = 0; rg < rings.length; rg++) {
            var rr = rings[rg], rp = rr.box ? dogCard(dmix, rr.x, rr.y) : [rr.x, rr.y]
            Ring(rp[0], rp[1], rr.r, rr.box ? rr.r : rr.r * 0.22, 0.6, rr.a)
        }
        if (treat) D(treat[0], treat[1], 1)
        for (var hh = 0; hh < hearts.length; hh++) Heart(hearts[hh].x, hearts[hh].y, 4.2, hearts[hh].a)
        if (pose === "night") zees()
        if (pose === "sunny" && idleW > 0.01) ball()
        if (pose === "rain") puddleRipples(di)
        if (pose === "windy") leaf()
        if (pose === "snow" && hi.puff > 0 && hi.puff < 1) {          // a cloud of breath
            var pu = hi.puff
            ctx.globalAlpha = 0.5 * (1 - pu) * idleW
            D(hb.head[0] + dx + 3.5 + pu * 1.5, hb.head[1] + 0.5 - pu * 4, 0.5 + 2 * pu)
            ctx.globalAlpha = 1
        }
        if (di.capFly > 0) {                                           // the snow shaken off the nose
            var cf = di.capFly, np = dogCard(dmix, -1, 8)
            ctx.globalAlpha = 1 - cf
            D(np[0] - cf * 5, np[1] - Math.sin(cf * Math.PI) * 3 + cf * cf * 4, 0.9)
            ctx.globalAlpha = 1
        }
        if (hi.splash > 0) {                                           // a drop landing on the outstretched palm
            var palm = [hb.arms[0][4] + dx, hb.arms[0][5]]
            ctx.globalAlpha = hi.splash
            D(palm[0] - 1.2, palm[1] - 1.6, 0.6); D(palm[0] + 1.3, palm[1] - 1.9, 0.6)
            ctx.globalAlpha = 1
        }
        ctx.globalAlpha = 1

        // ------------------------------------------------------------------
        // Draw helpers
        // ------------------------------------------------------------------
        function dogCard(d, x, y) {                                    // dog box coords -> card coords (flip, offsets)
            return [self.dogX + d.dx + 12 + (x - 12) * d.flip, G - 20 + d.dy + y]
        }
        function drawHuman(p, extras, jitter) {
            map = function (x, y) { return sceneMap(x + dx + jitter, y) }
            var neck = p.neck, hip = p.hip, head = p.head, i
            if (p.coat > 0) {                                          // puffy coat
                ctx.globalAlpha = p.coat
                Poly([[neck[0] - 2.7, neck[1] + 0.6], [neck[0] + 2.7, neck[1] + 0.6], [hip[0] + 3.3, hip[1] + 1.8], [hip[0] - 3.3, hip[1] + 1.8]])
                D(neck[0], neck[1] + 1.6, 2.7)
                ctx.globalAlpha = 1
            }
            L(neck[0], neck[1], hip[0], hip[1], Math.max(p.torsoW * xs, p.torsoW * 0.55))
            if (p.hem > 0.01) {                                        // flared jacket hem, rippling with the stride
                var rip = Math.sin(self.walkPhase * 2) * 0.4 * b
                ctx.globalAlpha = p.hem
                Poly([[hip[0] - 2.2, hip[1] - 1.4], [hip[0] + 2.2, hip[1] - 1.4], [hip[0] + 3.1 + rip, hip[1] + 2.2], [hip[0] - 3.1 - rip, hip[1] + 2.2]])
                ctx.globalAlpha = 1
            }
            for (i = 0; i < 2; i++) {
                var lg = p.legs[i]
                L(lg[0], lg[1], lg[2], lg[3], 2.2); L(lg[2], lg[3], lg[4], lg[5], 2.1); L(lg[4], lg[5], lg[6], lg[7], 1.8)
            }
            for (i = 0; i < 2; i++) {
                var ar = p.arms[i]
                L(ar[0], ar[1], ar[2], ar[3], 2); L(ar[2], ar[3], ar[4], ar[5], 1.9)
            }
            if (extras.palm > 0.5) L(p.arms[0][4] - 1.3, p.arms[0][5], p.arms[0][4] + 1.5, p.arms[0][5] - 0.2, 1.4)   // palm flat
            leadX = lead; D(head[0], head[1], p.headR); leadX = 0
            if (pose === "snow") E(head[0] - 4.5, head[1] + 0.6, 9, 3.2)   // wrapped scarf
            if (extras.hat * idleW > 0.01) {
                ctx.globalAlpha = extras.hat * idleW
                L(head[0] - 5, head[1] - 2.8, head[0] + 5, head[1] - 2.8, 1.6)
                Poly([[head[0] - 3, head[1] - 2.8], [head[0] + 3, head[1] - 2.8], [head[0] + 3, head[1] - 5.6], [head[0] - 3, head[1] - 5.6]])
                ctx.globalAlpha = 1
            }
            // scarf: streaming downwind at rest (windy, storm), trailing behind on a walk
            if (extras.scarfWind * idleW > 0.01) ribbon(neck[0] + 0.5, neck[1] + 0.5, 15, 1, 2 + 2.5 * extras.scarfWind, 1.8, extras.scarfWind * idleW)
            if (pose === "windy" && b > 0.01) ribbon(neck[0] - 0.5, neck[1] + 0.5, 12, -1, 2, 1.8, b)
            if (extras.coatTail * idleW > 0.01) {                      // coat tails whipping back from the hip
                ribbon(hip[0] + 0.5, hip[1] - 0.5, 7, 1, 1.2 + 2 * extras.coatTail, 1.6, extras.coatTail * idleW)
                ribbon(hip[0] + 0.5, hip[1] + 1.2, 6, 1, 1 + 2 * extras.coatTail, 1.4, extras.coatTail * idleW)
            }
            if (self.holdingMug && ps > 0.01) mug(p.arms[1][4], p.arms[1][5], ps)
            map = sceneMap
        }
        // a strip streaming from (nx, ny) in direction dir, waving in a multi-node sine
        function ribbon(nx, ny, len, dir, amp, w, alpha) {
            var pts = []
            for (var x = 0; x <= len; x++) {
                var k = x / len
                pts.push([nx + x * dir, ny + 1.5 * k + Math.sin(k * 7 - ip * 3.5 - self.walkPhase) * amp * k])
            }
            Pl(pts, w, alpha)
        }
        function mug(hx, hy, s) {                                      // 3 x 4 cup resting on the hand, two wisps of steam
            Poly([[hx - 1.5 * s, hy - 4 * s], [hx + 1.5 * s, hy - 4 * s], [hx + 1.5 * s, hy], [hx - 1.5 * s, hy]])
            for (var w = -1; w <= 1; w += 2) {
                for (var k = 0; k < 5; k++) {                          // each wisp rises 5 px and fades out
                    ctx.globalAlpha = 0.7 * (1 - k / 5)
                    L(hx + (w * 0.8 + Math.sin(k * 1.3 + ip * 1.3 + w) * 0.6) * s, hy - (4.6 + k) * s,
                      hx + (w * 0.8 + Math.sin((k + 1) * 1.3 + ip * 1.3 + w) * 0.6) * s, hy - (5.6 + k) * s, 0.8)
                }
            }
            ctx.globalAlpha = 1
        }
        // umbrella held at (x, y) in the person's local frame; shaft tilted by
        // `tilt` degrees (negative = into the wind). The canopy opens with
        // umbrellaOpenProgress; `flip` blows it into a V-cup of bent ribs,
        // `bounce` is the elastic snap back, `recoil` a drop landing on it.
        function umbrella(u) {
            var open = Math.max(0, self.umbrellaOpenProgress)
            var hx = u.x + dx + shiver, hy = u.y
            var rad = u.tilt * Math.PI / 180, ux = Math.sin(rad), uy = -Math.cos(rad)   // along the shaft, upwards
            function along(s, side) { return [hx + ux * s - uy * side, hy + uy * s + ux * side] }   // s up the shaft, side across
            var tip = along(u.shaft, 0)
            L(hx, hy, tip[0], tip[1], 1.6)                               // shaft
            var hook = along(-1.4, 1.2); L(hx, hy, hook[0], hook[1], 1.6)   // curved handle hook
            var hook2 = along(-1.6, 2.4); L(hook[0], hook[1], hook2[0], hook2[1], 1.4)
            if (open <= 0.02) {                                        // furled along the shaft
                var f = along(u.shaft + u.r * 0.6, 0); L(tip[0], tip[1], f[0], f[1], 2.4)
                return
            }
            var r = u.r * open * u.bounce, k = u.flip, rc = u.recoil
            var top = along(u.shaft - rc, 0)
            if (k < 1) {                                               // dome with a scalloped rim
                ctx.globalAlpha = 1 - k
                // dome: a half disc around the tip, perpendicular to the shaft
                ctx.beginPath()
                for (var i = 0; i <= 14; i++) {
                    var an = Math.PI + Math.PI * i / 14, sd = Math.cos(an) * r, up = -Math.sin(an) * r
                    var p = map(top[0] - uy * sd + ux * up, top[1] + ux * sd + uy * up)
                    if (i === 0) ctx.moveTo(p[0], p[1]); else ctx.lineTo(p[0], p[1])
                }
                ctx.closePath(); ctx.fill()
                for (i = -1; i <= 1; i++) { var sc = along(u.shaft - rc, i * r * 0.66); D(sc[0], sc[1], r * 0.34) }
                ctx.globalAlpha = 1
            }
            if (k > 0) {                                               // blown inside-out: ribs bent up into a V-cup
                ctx.globalAlpha = k
                var cup = along(u.shaft + 4.5 * k, 0)
                L(tip[0], tip[1], cup[0], cup[1], 1.6)
                for (var side = -1; side <= 1; side += 2) {
                    var rim = along(u.shaft + 1 + 5.5 * k, side * r * 0.95)
                    var ctl = along(u.shaft - 1, side * r * 0.5)
                    Q(cup[0], cup[1], ctl[0], ctl[1], rim[0], rim[1], 2.2)
                    var rib = along(u.shaft + 2 + 3.5 * k, side * r * 0.5)
                    L(cup[0], cup[1], rib[0], rib[1], 1.2)
                }
                ctx.globalAlpha = 1
            }
            // drops landing on the canopy, each with a splash
            if (hi.drops && idleW > 0.01) {
                ctx.globalAlpha = idleW
                var list = hi.drops.list
                for (var di2 = 0; di2 < list.length; di2++) {
                    var d = list[di2], side2 = d.x, lx = top[0] - uy * side2 + ux * 0
                    var surf = top[1] - Math.sqrt(Math.max(0, r * r - side2 * side2)) * 0.98 + rc
                    if (d.fall < 1) D(lx, surf - 7 + 7 * d.fall * d.fall, 1)
                    else {
                        var s3 = d.splash
                        ctx.globalAlpha = idleW * (1 - s3)
                        D(lx - 2 * s3, surf - 2.5 * s3 + s3 * s3 * 3, 0.6)
                        D(lx + 2.2 * s3, surf - 2.2 * s3 + s3 * s3 * 3, 0.6)
                        D(lx + 0.3 * s3, surf - 3 * s3 + s3 * s3 * 3.5, 0.55)
                        ctx.globalAlpha = idleW
                    }
                }
                ctx.globalAlpha = 1
            }
        }
        function drawDog(d, wAmp, wRate, eA, eFl, extras) {
            var bx = self.dogX + d.dx, by = G - 20 + d.dy
            var cs = Math.cos(d.spin), sn = Math.sin(d.spin)
            map = function (x, y) {
                var rx = 12 + (x - 12) * cs - (y - 12) * sn, ry = 12 + (x - 12) * sn + (y - 12) * cs
                return sceneMap(bx + 12 + (rx - 12) * d.flip, by + ry)
            }
            var savedXs = xs
            xs = Math.max(afs * Math.abs(d.flip), 0.5)
            var open = 1 - d.curl
            if (open > 0.01) {
                ctx.globalAlpha = open
                var mx = (d.neck[0] + d.rump[0]) / 2, my = (d.neck[1] + d.rump[1]) / 2 - 1.3 - d.arch
                Q(d.neck[0], d.neck[1], mx, my, d.rump[0], d.rump[1], Math.max(d.bodyW * 0.5, d.bodyW * xs))
                D(d.rump[0], d.rump[1], d.bodyW / 2 + 0.3)
                L(d.neck[0], d.neck[1], d.neckMid[0], d.neckMid[1], 3.4)
                L(d.neckMid[0], d.neckMid[1], d.head[0], d.head[1], 3.2)
                // legs: upper, lower, paw
                for (var i = 0; i < 4; i++) {
                    var lg = d.legs[i]
                    L(lg[0], lg[1], lg[2], lg[3], 1.9); L(lg[2], lg[3], lg[4], lg[5], 1.7); D(lg[4], lg[5], 0.95)
                }
                // head with a snout; perked up it lifts and the snout shrinks to a nose facing the viewer
                var r = d.headR, hx = d.head[0], hy = d.head[1] - 1.5 * d.perk
                leadX = lead; D(hx, hy, r); leadX = 0
                var a = d.headAng, len = (r + 1) - (r - 1) * d.perk
                var sx = hx - Math.cos(a) * (r - 0.6) * (1 - d.perk), sy = hy + Math.sin(a) * (r - 0.6) * (1 - d.perk) + 0.8 * d.perk
                var ex = sx - Math.cos(a) * len, ey = sy + Math.sin(a) * len
                L(sx, sy, ex, ey, 2)
                if (d.jaw > 0.02) L(sx + 0.3, sy + 0.9, ex + 0.6 + Math.sin(a) * 1.2 * d.jaw, ey + 1.6 * d.jaw, 1.5)   // lower jaw
                if (extras.snowCap > 0) { ctx.globalAlpha = open * extras.snowCap; D(ex - 0.3, ey - 1.2, 0.9); ctx.globalAlpha = open }
                // tail: three bezier segments, the tip trailing the base through the wag
                var base = (d.tail[2] + wAmp * Math.sin(t * wRate)) * Math.PI / 180
                var mid = (d.tail[2] + wAmp * Math.sin(t * wRate - 0.8)) * Math.PI / 180
                var tipA = (d.tail[2] + wAmp * Math.sin(t * wRate - 1.6)) * Math.PI / 180
                var p0 = [d.tail[0], d.tail[1]]
                var p1 = [p0[0] + Math.cos(base) * 2.3, p0[1] + Math.sin(base) * 2.3]
                var p2 = [p1[0] + Math.cos(mid) * 2.3, p1[1] + Math.sin(mid) * 2.3]
                var p3 = [p2[0] + Math.cos(tipA) * 2, p2[1] + Math.sin(tipA) * 2]
                C(p0[0], p0[1], p1[0], p1[1], p2[0], p2[1], p3[0], p3[1], 1.9)
                // ear: two segments hanging from the back of the head; angle 0 = down, + = swept back
                var ea = d.ear[2] + eA + Math.sin(t * 30) * eFl
                var e0 = [d.ear[0], d.ear[1] - 1.5 * d.perk]
                var e1 = [e0[0] + Math.sin(ea) * 2.4, e0[1] + Math.cos(ea) * 2.4]
                var ea2 = ea + Math.sin(t * 30 - 0.6) * eFl + Math.sin(self.walkPhase * 2 - 0.9) * 0.3 * b
                var e2 = [e1[0] + Math.sin(ea2) * 2.2, e1[1] + Math.cos(ea2) * 2.2]
                L(e0[0], e0[1], e1[0], e1[1], 2); L(e1[0], e1[1], e2[0], e2[1], 1.8)
                ctx.globalAlpha = 1
            }
            if (d.curl > 0.01) {                                       // curled up asleep
                ctx.globalAlpha = d.curl
                var br = 1 + Math.sin(t * Math.PI * 2 / 2.8) * 0.07     // breathing
                E(3, 12.5 + 3.5 * (1 - br), 18, 7.5 * br)
                D(6.5, 14, 2.8)                                        // head tucked in
                C(19, 15, 17, 7, 9, 6.5, 4, 12.5, 1.6)                 // tail curled over the nose
                var tw = win(t % 6, 4.2, 4.5, 0.08) * Math.sin(t * 50)  // a dreaming paw twitch
                L(14.5, 19.2, 17 + tw * 0.8, 19.4 - Math.abs(tw) * 0.8, 1.6)
                ctx.globalAlpha = 1
            }
            xs = savedXs
            map = sceneMap
        }
        function ball() {                                              // sunny: the ball through the fetch loop
            var u = pro, p
            var hand = [hb.arms[1][4] + dx, hb.arms[1][5]]
            var landing = [46, G - 1.5]
            if (u < 0.2) p = [hand[0] + 0.8, hand[1] - 0.6]
            else if (u < 0.5) { var v = (u - 0.2) / 0.3; p = [lerp(hand[0], landing[0], v), lerp(hand[1], landing[1], v) - Math.sin(v * Math.PI) * 11] }
            else if (u < 0.6) { var v2 = (u - 0.5) / 0.1; p = [landing[0] + 2.5 * v2, landing[1] - Math.sin(v2 * Math.PI) * 3] }
            else if (u < 0.9) p = dogCard(dmix, dmix.head[0] - 4.2, dmix.head[1] + 0.8)
            else p = [self.personX + 12, G - 1.5]
            D(p[0], p[1], 1.5 * ps)
        }
        function zees() {                                              // three z's drifting up an S-curve, growing and fading
            var ox = hb.head[0] + dx + 2, oy = hb.head[1] - 3
            for (var i = 0; i < 3; i++) {
                var zu = ((st + i * 0.9) % 2.7) / 2.7
                var al = (zu < 0.15 ? zu / 0.15 : 1 - (zu - 0.15) / 0.85) * ps
                Txt("z", ox + Math.sin(zu * Math.PI * 2) * 3 + zu * 4, oy - zu * 13, 3 + 3 * zu, al)
            }
        }
        function puddleRipples(extras) {                               // drops and paw taps rippling the puddle
            var evts = []
            for (var i = 0; i < 2; i++) {
                var u = ((st + i * 0.9) % 1.8) / 0.9
                if (u < 1) evts.push({ x: 38 + ((i * 7 + Math.floor((st + i * 0.9) / 1.8) * 5) % 9), u: u })
            }
            if (extras.tap > 0.9) {
                var tu = ((st - 3.2) % 5 - 0.27) / 0.4
                if (tu > 0 && tu < 1) evts.push({ x: 36.5, u: tu })
            }
            for (var e = 0; e < evts.length; e++) {
                var ev = evts[e]
                if (ev.u < 0.3 && extras.tap <= 0.9) { ctx.globalAlpha = ps; D(ev.x, G - 1.5 - (1 - ev.u / 0.3) * 22, 0.75); ctx.globalAlpha = 1 }
                var ru = clamp01((ev.u - 0.3) / 0.7)
                if (ru > 0) { Ring(ev.x, G - 1.2, (1 + ru * 6) * ps, (0.5 + ru * 1.2) * ps, 0.6, (1 - ru) * 0.8 * ps); if (ru > 0.3) Ring(ev.x, G - 1.2, (1 + (ru - 0.3) * 5) * ps, (0.4 + (ru - 0.3) * 1) * ps, 0.5, (1 - ru) * 0.6 * ps) }
            }
        }
        function leaf() {                                              // windy: a leaf tumbling past the dog's nose
            var lf = leafState()
            if (lf.v < 0) return
            var x = -6 + 66 * lf.v, y = 13 + Math.sin(lf.v * 9) * 2.5 - Math.sin(lf.v * Math.PI) * 3
            var rot = lf.v * 18, c = Math.cos(rot) * 1.5, s = Math.sin(rot) * 1.5
            L(x - c, y - s, x + c, y + s, 2.2)                           // a tumbling leaf
        }
        function campfire(x, s) {                                      // three logs, two flickering flames, a warm glow
            Halo(x, G - 2, 11 * s, 0.14 + Math.sin(ip * 1.5) * 0.03)
            L(x - 3 * s, G - 0.8 * s, x + 3 * s, G - 0.8 * s, 1.4)
            L(x - 3 * s, G - 0.8 * s, x + 0.6 * s, G - 5.2 * s, 1.4)
            L(x + 3 * s, G - 0.8 * s, x - 0.6 * s, G - 5.2 * s, 1.4)
            function flame(fx, fy, w, h) {
                Poly([[fx - w / 2, fy], [fx + w / 2, fy], [fx + Math.sin(ip * 2.5 + fx) * 0.4 * s, fy - h]])
            }
            flame(x - 0.8 * s, G - 2.2 * s, 2.4 * s, 4 * s * (1 + Math.sin(ip * 3.5) * 0.3))
            flame(x + 1.2 * s, G - 2.6 * s, 1.8 * s, 3 * s * (1 + Math.sin(ip * 4.5 + 2) * 0.3))
        }
        function telescope(x, s) {                                     // 8 px tripod telescope aimed at the sky
            L(x, G - 4.5 * s, x - 2.8 * s, G, 1.2); L(x, G - 4.5 * s, x + 0.6 * s, G, 1.2); L(x, G - 4.5 * s, x + 2.8 * s, G, 1.2)
            L(x - 2.2 * s, G - 3.2 * s, x + 3.2 * s, G - 8 * s, 2.6)
        }
        function lantern(x, s) {                                       // small lantern with a soft halo
            Halo(x, G - 2.5 * s, 8 * s, 0.15)
            Poly([[x - 1.5 * s, G - 4.5 * s], [x + 1.5 * s, G - 4.5 * s], [x + 1.5 * s, G - 0.5 * s], [x - 1.5 * s, G - 0.5 * s]])
            Q(x - 1.3 * s, G - 4.6 * s, x, G - 6.6 * s, x + 1.3 * s, G - 4.6 * s, 0.8)
        }
    }

    Component.onCompleted: { renderedScene = targetScene; dirty() }
}
