import QtQuick

// A minimalist monochrome silhouette duo, a person and a small dog, that react
// to the weather. The pair rests on the top edge of the hourly strip: the
// ground line is y = ground (28) and the lower 8 px hang over the strip so a
// seated pose can dangle its legs. The wind blows left to right, like the
// ambient effects behind the card, so leaning is to the left and anything
// loose (scarf, ears, tail) trails to the right.
//
// Scenes, in priority order:
//   storm    rain/thunder, wind >= 22: person leans into the wind and the umbrella flips inside-out
//            now and then; the dog crouches behind their legs
//   thunder  calm thunderstorm: both huddle under one umbrella and flinch at every lightning flash
//   rain     calm rain: both sit under one umbrella watching the rain; drops bounce off the dome
//   snow     person bundled up beside a tiny snowman; the dog pounces at it
//   windy    dry wind >= 25: hand on hat, scarf and the dog's ears rippling back
//   sunny    clear day: person sits in a sun hat; the dog bounces after a ball
//   night    clear night: both doze, breathing slowly, z's floating up
//   calm     cloudy / partly / fog: both sit on the edge, swaying a little
//
// Every 14 to 25 s (never at night, when both are asleep) the pair wanders a
// short way (40 to 110 px) along the track between `minTrackX` and `maxTrackX`:
// usually they stroll there at a leisurely 13 px/s, legs swinging and the dog
// trotting ahead, facing the way they go; now and then they just fade out and
// reappear further along. The host
// sets `homeX` for the spot they start from and the track for the edge they
// roam; it must not bind `x` itself, since walking drives it.
//
// Walking and resting never snap: `walkBlend` eases between the walking
// skeleton and the scene's idle pose (the person sits down or stands up, the
// dog turns and crossfades), so the pair settles gently when a stroll ends.
//
// Weather changes are buffered: `targetScene` follows the live props, while
// the drawing reads `renderedScene`. When they differ the pair crouches and
// folds its props (umbrella shut, snowman / ball / z's shrink to the ground),
// the scene swaps, and they stand back up with the new props unfurling.
//
// The person is drawn on one canvas, the dog on another; wag, flutter, hop,
// flinch and breathing are transforms, so only the scarf ripple, the leg swing
// and the dog's head tilt repaint a canvas. Everything stops when `running`
// is false.
Item {
    id: character

    property string condition: "cloudy"
    property bool isNight: false
    property real windSpeed: 0           // km/h
    property bool running: true
    property color color: "#FFFFFF"

    // Roaming track, in the parent's coordinates, and where to start.
    property bool roaming: true
    property real minTrackX: 0
    property real maxTrackX: 0
    property real homeX: (minTrackX + maxTrackX) / 2
    property bool isWalking: false
    property int facingDirection: 1       // 1 = facing right, -1 = facing left
    property real walkPhase: 0            // 0..2π per stride while walking: legs, arms, bob and the dog's trot
    // 0 = fully in the idle pose, 1 = fully walking; eased, so poses blend
    property real walkBlend: isWalking ? 1.0 : 0.0
    Behavior on walkBlend {
        NumberAnimation {
            duration: character.isWalking ? 220 : 380       // quick to stand up into a walk, gentle to settle down
            easing.type: character.isWalking ? Easing.OutQuad : Easing.InOutCubic
        }
    }
    onWalkBlendChanged: { art.requestPaint(); dogArt.requestPaint() }
    readonly property real minHop: 45     // one stroll covers between minHop and maxHop
    readonly property real maxHop: 110

    width: 54
    height: 36
    opacity: 0.32

    readonly property real ground: 28
    readonly property real padX: 10          // canvas headroom, see `art`
    readonly property real padY: 12
    // What the live weather asks for, in priority order, and what is drawn.
    readonly property bool wetWeather: condition === "rain" || condition === "thunder"
    readonly property string targetScene: wetWeather && windSpeed >= 22 ? "windyRain"
        : condition === "thunder" ? "thunder"
        : condition === "rain" ? "rain"
        : condition === "snow" ? "snow"
        : windSpeed >= 25 ? "windyDry"
        : condition === "clear" && !isNight ? "sunnyPlay"
        : condition === "clear" && isNight ? "sleep"
        : "calm"
    property string renderedScene: "calm"            // set from targetScene by the transition (or at once when not running)
    property real transitionScaleY: 1.0               // the pair crouching towards the ground line
    property real transitionOffsetY: 0.0
    property real transitionOpacity: 0.32             // relative to the resting 0.32
    property real umbrellaOpenProgress: umbrellaScene(renderedScene) ? 1.0 : 0.0   // 0 = closed stick, 1 = full dome
    property real propScale: 1.0                      // snowman, ball and z's, anchored at the ground
    function umbrellaScene(scene) { return scene === "rain" || scene === "windyRain" || scene === "thunder" }

    // Short pose names used by the drawing code: one per rendered scene.
    readonly property string pose: renderedScene === "windyRain" ? "storm"
        : renderedScene === "windyDry" ? "windy"
        : renderedScene === "sunnyPlay" ? "sunny"
        : renderedScene === "sleep" ? "night"
        : renderedScene
    readonly property bool wet: pose === "storm" || pose === "rain" || pose === "thunder"
    readonly property bool sheltered: pose === "rain" || pose === "thunder"
    readonly property bool leaning: pose === "storm" || pose === "windy"
    readonly property bool gusty: pose === "storm" || pose === "windy"
    // The scene is drawn facing right and mirrored to face left. In a gale the
    // idle poses lean into the wind (which blows to the right), so they are
    // never mirrored; a walk is, with the lean re-applied in world space.
    readonly property bool mirror: facingDirection < 0 && (isWalking || !gusty)

    // Where the person stands (centre x of the figure) and where the dog's box starts.
    // Both slide between their idle spot and their walking spot with the blend.
    readonly property real idlePersonX: leaning ? 14 : pose === "calm" ? 14 : 11
    readonly property real idleDogX: pose === "sunny" ? 30 : pose === "night" ? 22 : pose === "rain" ? 15
        : pose === "thunder" ? 13 : pose === "storm" ? 26 : pose === "windy" ? 28 : pose === "snow" ? 30 : 24
    readonly property real personX: idlePersonX + (12 - idlePersonX) * walkBlend
    readonly property real dogX: idleDogX + (27 - idleDogX) * walkBlend

    // Animated pose parameters. Changing any of them repaints the canvas.
    property real phase: 0               // 0..2π, drives the scarf ripple and the leg swing
    property bool flipped: false         // umbrella inside-out (storm)
    property real tug: 0                 // 0..1 how far the arm has pulled the umbrella back down

    function flinch() { flinchAnim.restart() }
    function duck() { flinch() }

    onPoseChanged: { flipped = false; tug = 0; art.requestPaint(); dogArt.requestPaint() }
    onUmbrellaOpenProgressChanged: art.requestPaint()
    onPropScaleChanged: art.requestPaint()
    onIsWalkingChanged: { art.requestPaint(); dogArt.requestPaint() }   // walkPhase keeps its value, so the legs ease out of mid-stride
    onWalkPhaseChanged: { art.requestPaint(); dogArt.requestPaint() }
    onPhaseChanged: art.requestPaint()
    onFlippedChanged: art.requestPaint()
    onTugChanged: art.requestPaint()
    onColorChanged: { art.requestPaint(); dogArt.requestPaint() }
    onRunningChanged: if (!running) { walkAnim.stop(); fadeAnim.stop(); fadeOpacity = 1; if (sceneChangeAnimation.running) { sceneChangeAnimation.stop(); applySceneNow() } }

    // =====================================================================
    // Scene transitions
    // =====================================================================
    onTargetSceneChanged: {
        if (targetScene === renderedScene) return
        if (!running) { applySceneNow(); return }
        // roaming waits: a walk in progress ends here, a fade is cut short
        if (walkAnim.running) walkAnim.stop()
        if (fadeAnim.running) { fadeAnim.stop(); fadeOpacity = 1 }
        isWalking = false
        sceneChangeAnimation.restart()
    }
    // Instant swap, used when animations are off or interrupted.
    function applySceneNow() {
        renderedScene = targetScene
        resetSceneCounters()
        transitionScaleY = 1; transitionOffsetY = 0; transitionOpacity = 0.32
        umbrellaOpenProgress = umbrellaScene(renderedScene) ? 1 : 0
        propScale = 1
    }
    // Pose-specific counters start the new idle animation from frame 0.
    function resetSceneCounters() {
        phase = 0; walkPhase = 0; flipped = false; tug = 0
        person.rock = 0; person.bob = 0; person.jitter = 0; person.breathe = 1
        dog.hop = 0; dog.huddle = 0; dog.breathe = 1; dog.headTilt = 0
        art.requestPaint(); dogArt.requestPaint()
    }
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
        // 2. swap: draw the new scene while nearly invisible; the umbrella
        //    unfurls (if the new scene has one) alongside the stand-up
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
    // Until the first move, x follows the host's homeX (clamped to the track);
    // without a track the host's own x stands.
    property bool roamed: false
    Binding {
        target: character; property: "x"
        value: character.clampX(character.homeX)
        when: !character.roamed && character.maxTrackX > character.minTrackX
        restoreMode: Binding.RestoreNone
    }
    function clampX(v) { return Math.max(minTrackX, Math.min(maxTrackX, v)) }
    // A resized track interrupts a walk and pulls the pair back onto it.
    function keepOnTrack() {
        if (!roamed || maxTrackX <= minTrackX) return
        if (walkAnim.running) walkAnim.stop()
        x = clampX(x)
    }
    onMinTrackXChanged: keepOnTrack()
    onMaxTrackXChanged: keepOnTrack()

    Timer {
        id: roamTimer
        running: character.running && character.roaming && character.pose !== "night"
                 && !character.isWalking && !fadeAnim.running && !sceneChangeAnimation.running
        repeat: true
        interval: 14000 + Math.random() * 11000
        onTriggered: { interval = 14000 + Math.random() * 11000; character.roam() }
    }
    // Public: stroll to a fresh spot right now, as a reaction to new weather
    // data or the hourly strip advancing. Nothing happens while hidden,
    // stopped, asleep, or already on the move; the idle timer restarts so it
    // does not fire again straight after.
    function triggerRoam() {
        if (!visible || !running || !roaming || pose === "night") return
        if (isWalking || fadeAnim.running || sceneChangeAnimation.running) return
        roamTimer.interval = 14000 + Math.random() * 11000
        roamTimer.restart()
        roam(undefined, false)
    }
    // Public: walk (never fade) to a given x on the track.
    function startWalkTo(targetX) { roam(targetX, false) }

    // Pick a short hop (minHop..maxHop) to whichever side has room, then
    // stroll there (4 times out of 5) or fade out and reappear. Both choices
    // can be forced, which the preview harness uses.
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
    property real fadeOpacity: 1          // roaming fade-teleport and the walk/rest dip
    SequentialAnimation {
        id: fadeAnim
        property real targetX: 0
        NumberAnimation { target: character; property: "fadeOpacity"; to: 0; duration: 300; easing.type: Easing.InQuad }
        ScriptAction { script: character.x = fadeAnim.targetX }
        NumberAnimation { target: character; property: "fadeOpacity"; to: 1; duration: 300; easing.type: Easing.OutQuad }
    }
    // one unhurried stride per cycle: both legs swing once, the body bobs twice
    NumberAnimation on walkPhase {
        running: character.running && character.isWalking
        from: 0; to: Math.PI * 2
        duration: 1000
        loops: Animation.Infinite
    }

    // =====================================================================
    // Scene: everything that faces a direction, mirrored to face left
    // =====================================================================
    Item {
        id: scene
        anchors.fill: parent
        opacity: character.fadeOpacity * (character.transitionOpacity / 0.32)
        transform: [
            Scale { origin.x: character.width / 2; xScale: character.mirror ? -1 : 1 },
            Scale { origin.y: character.ground; yScale: character.transitionScaleY },     // crouch from the ground line
            Translate { y: character.transitionOffsetY }
        ]

        // =====================================================================
        // Person
        // =====================================================================
        Item {
            id: person
            anchors.fill: parent
            property real rock: 0
            property real bob: 0
            property real jitter: 0
            property real breathe: 1
            property real stepBob: -Math.abs(Math.sin(character.walkPhase)) * 0.6 * character.walkBlend
            // walking in a gale: lean into the wind (to the left on screen) whichever way they go
            property real walkLean: character.gusty ? (character.mirror ? 12 : -12) * character.walkBlend : 0
            transform: [
                Translate { x: person.jitter; y: person.bob + person.stepBob },
                Rotation { origin.x: character.personX; origin.y: character.ground; angle: person.rock + person.walkLean },
                Scale { id: personFlinch; origin.x: character.personX; origin.y: character.ground; yScale: 1 },
                Scale { origin.x: character.personX; origin.y: character.ground; yScale: person.breathe }
            ]

            Canvas {   // oversized so a raised umbrella or a leaning figure is not clipped; paint() shifts the origin back
                id: art
                x: -character.padX; y: -character.padY
                width: character.width + character.padX * 2
                height: character.height + character.padY
                renderStrategy: Canvas.Cooperative
                onPaint: character.paintPerson(getContext("2d"))
            }

            // storm: rocking against the gusts
            SequentialAnimation on rock {
                running: character.running && !character.isWalking && character.pose === "storm"
                loops: Animation.Infinite
                NumberAnimation { to: 8; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: -5; duration: 600; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) person.rock = 0
            }
            // calm: a slow sway
            SequentialAnimation on rock {
                running: character.running && !character.isWalking && character.pose === "calm"
                loops: Animation.Infinite
                NumberAnimation { to: 2; duration: 2600; easing.type: Easing.InOutSine }
                NumberAnimation { to: -2; duration: 2600; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) person.rock = 0
            }
            // rain / windy / sunny: gentle breathing bob
            SequentialAnimation on bob {
                running: character.running && !character.isWalking && (character.sheltered || character.pose === "windy" || character.pose === "sunny")
                loops: Animation.Infinite
                NumberAnimation { to: -1; duration: 1400; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 1400; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) person.bob = 0
            }
            // night: slow, peaceful breathing
            SequentialAnimation on breathe {
                running: character.running && character.pose === "night"
                loops: Animation.Infinite
                NumberAnimation { to: 1.04; duration: 2800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 2800; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) person.breathe = 1
            }
            // snow: shiver in short bursts
            SequentialAnimation on jitter {
                running: character.running && !character.isWalking && character.pose === "snow"
                loops: Animation.Infinite
                PauseAnimation { duration: 1800 }
                NumberAnimation { to: 1; duration: 80 }
                NumberAnimation { to: -1; duration: 80 }
                NumberAnimation { to: 1; duration: 80 }
                NumberAnimation { to: -1; duration: 80 }
                NumberAnimation { to: 1; duration: 80 }
                NumberAnimation { to: 0; duration: 80 }
                onRunningChanged: if (!running) person.jitter = 0
            }
        }

        // continuous phase for the scarf ripple (fast) and the leg swing (slow)
        NumberAnimation {
            target: character; property: "phase"
            running: character.running && (character.pose === "windy" || character.pose === "sunny")
            from: 0; to: Math.PI * 2
            duration: character.pose === "windy" ? 420 : 2200
            loops: Animation.Infinite
        }

        // storm: every 4.5 s the canopy blows inside-out for 1.2 s while the arm tugs it back
        Timer {
            running: character.running && !character.isWalking && character.pose === "storm"
            interval: 4500
            repeat: true
            onTriggered: flipAnim.restart()
        }
        SequentialAnimation {
            id: flipAnim
            ScriptAction { script: { character.flipped = true; character.tug = 0 } }
            NumberAnimation { target: character; property: "tug"; to: 1; duration: 1200; easing.type: Easing.InOutQuad }
            ScriptAction { script: { character.flipped = false; character.tug = 0 } }
        }

        // thunder (and the lightning flash in a storm): both flinch, the dog presses in closer
        SequentialAnimation {
            id: flinchAnim
            ParallelAnimation {
                NumberAnimation { target: personFlinch; property: "yScale"; to: 0.85; duration: 60; easing.type: Easing.OutQuad }
                NumberAnimation { target: dogFlinch; property: "yScale"; to: 0.85; duration: 60; easing.type: Easing.OutQuad }
                NumberAnimation { target: dog; property: "huddle"; to: -2; duration: 60 }
            }
            PauseAnimation { duration: 130 }
            ParallelAnimation {
                NumberAnimation { target: personFlinch; property: "yScale"; to: 1; duration: 60; easing.type: Easing.InOutQuad }
                NumberAnimation { target: dogFlinch; property: "yScale"; to: 1; duration: 60; easing.type: Easing.InOutQuad }
                NumberAnimation { target: dog; property: "huddle"; to: 0; duration: 600; easing.type: Easing.InOutQuad }
            }
        }

        // =====================================================================
        // Dog: a 24 x 20 box whose bottom edge is the ground, facing left
        // =====================================================================
        Item {
            id: dog
            x: character.dogX + huddle
            y: character.ground - 20
            width: 24; height: 20
            property real hop: 0
            property real huddle: 0
            property real breathe: 1
            property real headTilt: 0        // degrees, rain scene
            readonly property bool trotting: stance === "trot"
            readonly property real blend: character.walkBlend
            property real trotBob: -Math.abs(Math.sin(character.walkPhase + 0.8)) * 0.5 * blend
            transform: [
                Translate { y: dog.hop + dog.trotBob },
                Scale { id: dogFlinch; origin.x: 12; origin.y: 20; yScale: 1 },
                Scale { origin.x: 12; origin.y: 20; yScale: dog.breathe },
                Scale { origin.x: 12; xScale: 1 - 2 * dog.blend }          // drawn facing left; turns round to trot facing forward
            ]
            onHeadTiltChanged: dogArt.requestPaint()

            // body pose for the dog: the scene's idle stance, or trotting on a walk
            readonly property string idleStance: character.pose === "sunny" || character.pose === "windy" ? "stand"
                : character.pose === "night" ? "curl"
                : character.pose === "storm" ? "crouch"
                : character.pose === "snow" ? "pounce"
                : "sit"
            readonly property string stance: character.isWalking ? "trot" : idleStance
            onStanceChanged: dogArt.requestPaint()
            onIdleStanceChanged: dogArt.requestPaint()

            Canvas {
                id: dogArt
                x: -4; y: -4
                width: 32; height: 24
                renderStrategy: Canvas.Cooperative
                onPaint: character.paintDog(getContext("2d"))
            }

            // tail root and resting angle per stance (0 = pointing right along the
            // ground), eased between the idle stance and the trot with the blend
            function tailFor(st) {
                return st === "stand" ? { x: 17, y: 9.5, a: -35 }
                    : st === "trot" ? { x: 17, y: 9.5, a: -70 }
                    : st === "sit" ? { x: 18, y: 18.5, a: -10 }
                    : st === "crouch" ? { x: 17, y: 15.5, a: 0 }
                    : st === "pounce" ? { x: 19, y: 8, a: -60 }
                    : null
            }
            function mixSpec(a, b, t) {
                if (!a && !b) return null
                if (!a) a = b
                if (!b) b = a
                var out = {}
                for (var k in a) out[k] = a[k] + (b[k] - a[k]) * t
                return out
            }
            readonly property var idleTail: tailFor(idleStance)
            readonly property var tailSpec: mixSpec(idleTail, tailFor("trot"), blend)
            Rectangle {
                id: tail
                visible: dog.tailSpec !== null
                opacity: dog.idleTail ? 1 : dog.blend                   // a curled-up dog grows its tail as it gets up
                x: dog.tailSpec ? dog.tailSpec.x : 0
                y: dog.tailSpec ? dog.tailSpec.y - 1 : 0
                width: 6; height: 2; radius: 1
                color: character.color
                transformOrigin: Item.Left
                property real wag: 0
                rotation: (dog.tailSpec ? dog.tailSpec.a : 0) + wag
                // joyful: ±20° every 180 ms (sunny, snow, trotting)
                SequentialAnimation on wag {
                    running: character.running && (dog.trotting || character.pose === "sunny" || character.pose === "snow")
                    loops: Animation.Infinite
                    NumberAnimation { to: 20; duration: 180; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -20; duration: 180; easing.type: Easing.InOutSine }
                    onRunningChanged: if (!running) tail.wag = 0
                }
                // relaxed: 600 ms cycle (calm)
                SequentialAnimation on wag {
                    running: character.running && !character.isWalking && character.pose === "calm"
                    loops: Animation.Infinite
                    NumberAnimation { to: 14; duration: 300; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -14; duration: 300; easing.type: Easing.InOutSine }
                    onRunningChanged: if (!running) tail.wag = 0
                }
                // slow and calm under the umbrella (rain, thunder)
                SequentialAnimation on wag {
                    running: character.running && !dog.trotting && character.sheltered
                    loops: Animation.Infinite
                    NumberAnimation { to: 12; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -8; duration: 900; easing.type: Easing.InOutSine }
                    onRunningChanged: if (!running) tail.wag = 0
                }
                // blown flat and fluttering in the wind (storm, windy)
                SequentialAnimation on wag {
                    running: character.running && !dog.trotting && character.gusty
                    loops: Animation.Infinite
                    NumberAnimation { to: 8; duration: 90 }
                    NumberAnimation { to: -10; duration: 110 }
                    NumberAnimation { to: 5; duration: 80 }
                    NumberAnimation { to: -6; duration: 100 }
                    onRunningChanged: if (!running) tail.wag = 0
                }
            }

            // floppy ear hanging from the back of the head; flutters back in the wind
            function earFor(st) {
                return st === "stand" || st === "trot" ? { x: 4.5, y: 6 }
                    : st === "sit" ? { x: 5.5, y: 4 }
                    : st === "crouch" ? { x: 4, y: 10.5 }
                    : st === "pounce" ? { x: 5, y: 11 }
                    : null
            }
            readonly property var idleEar: earFor(idleStance)
            readonly property var earSpec: mixSpec(idleEar, earFor("trot"), blend)
            Rectangle {
                id: ear
                visible: dog.earSpec !== null
                opacity: dog.idleEar ? 1 : dog.blend
                x: dog.earSpec ? dog.earSpec.x : 0
                y: dog.earSpec ? dog.earSpec.y : 0
                width: 2; height: 4.5; radius: 1
                color: character.color
                transformOrigin: Item.Top
                property real flutter: 0
                rotation: (character.gusty && !dog.trotting ? -60 : 0) + flutter
                SequentialAnimation on flutter {
                    running: character.running && character.gusty
                    loops: Animation.Infinite
                    NumberAnimation { to: 14; duration: 90 }
                    NumberAnimation { to: -12; duration: 100 }
                    NumberAnimation { to: 10; duration: 80 }
                    NumberAnimation { to: -8; duration: 110 }
                    onRunningChanged: if (!running) ear.flutter = 0
                }
            }

            // sunny: joyful play-bounce
            SequentialAnimation on hop {
                running: character.running && !character.isWalking && character.pose === "sunny"
                loops: Animation.Infinite
                NumberAnimation { to: -4; duration: 300; easing.type: Easing.OutQuad }
                NumberAnimation { to: 0; duration: 300; easing.type: Easing.InQuad }
                PauseAnimation { duration: 300 }
                onRunningChanged: if (!running) dog.hop = 0
            }
            // snow: small excited hops in place
            SequentialAnimation on hop {
                running: character.running && !character.isWalking && character.pose === "snow"
                loops: Animation.Infinite
                NumberAnimation { to: -2.5; duration: 160; easing.type: Easing.OutQuad }
                NumberAnimation { to: 0; duration: 160; easing.type: Easing.InQuad }
                PauseAnimation { duration: 380 }
                onRunningChanged: if (!running) dog.hop = 0
            }
            // night: breathing in time with the person
            SequentialAnimation on breathe {
                running: character.running && character.pose === "night"
                loops: Animation.Infinite
                NumberAnimation { to: 1.04; duration: 2800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 2800; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) dog.breathe = 1
            }
            // rain: a curious head tilt every 3 s
            SequentialAnimation on headTilt {
                running: character.running && !character.isWalking && character.pose === "rain"
                loops: Animation.Infinite
                PauseAnimation { duration: 3000 }
                NumberAnimation { to: 14; duration: 260; easing.type: Easing.OutQuad }
                PauseAnimation { duration: 700 }
                NumberAnimation { to: 0; duration: 320; easing.type: Easing.InOutQuad }
                onRunningChanged: if (!running) dog.headTilt = 0
            }
        }

        // sunny: a tiny ball arcing between the two
        Rectangle {
            visible: character.pose === "sunny"
            width: 3; height: 3; radius: 1.5
            color: character.color
            property real p: 0               // 0..1 along the arc, person -> dog
            x: 19 + p * 10
            y: character.ground - height - (3 + Math.sin(p * Math.PI) * 11) * character.propScale
            transformOrigin: Item.Bottom
            scale: character.propScale
            SequentialAnimation on p {
                running: character.running && !character.isWalking && character.pose === "sunny"
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 1; duration: 900 }
                NumberAnimation { from: 1; to: 0; duration: 900 }
            }
        }

        // rain / thunder: two droplets bouncing off the top of the shared umbrella
        Repeater {
            model: character.sheltered ? [ { x: 16, y0: -5.5, d: 0 }, { x: 24, y0: -5.5, d: 420 } ] : []
            Rectangle {
                required property var modelData
                x: modelData.x
                width: 2; height: 2; radius: 1
                color: character.color
                property real hop: 0
                y: modelData.y0 - Math.sin(hop * Math.PI) * 5
                opacity: 1 - hop * 0.8
                SequentialAnimation on hop {
                    running: character.running
                    loops: Animation.Infinite
                    PauseAnimation { duration: modelData.d }
                    NumberAnimation { from: 0; to: 1; duration: 520; easing.type: Easing.OutQuad }
                    PauseAnimation { duration: 380 }
                }
            }
        }
    }

    // night: tiny z's drifting up from the pair and fading out
    Repeater {
        model: character.pose === "night" ? [ { x: 16, y: 9, d: 0 }, { x: 30, y: 17, d: 1300 } ] : []
        Text {
            required property var modelData
            text: "z"
            color: character.color
            font.pixelSize: 7
            font.bold: true
            scale: character.propScale
            property real rise: 0
            x: (character.mirror ? character.width - 5 - modelData.x : modelData.x) + rise * 5
            y: modelData.y - rise * 11
            opacity: rise < 0.15 ? rise / 0.15 : 1 - (rise - 0.15) / 0.85
            SequentialAnimation on rise {
                running: character.running
                loops: Animation.Infinite
                PauseAnimation { duration: modelData.d }
                NumberAnimation { from: 0; to: 1; duration: 2200; easing.type: Easing.OutQuad }
            }
        }
    }

    // =====================================================================
    // Drawing
    // =====================================================================
    function setup(ctx) {
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.strokeStyle = color
        ctx.fillStyle = color
    }
    function line(ctx, ax, ay, bx, by, w) {
        ctx.lineWidth = w
        ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(bx, by); ctx.stroke()
    }
    function dot(ctx, cx, cy, r) {
        ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill()
    }
    function pill(ctx, x, y, w, h) {
        ctx.beginPath(); ctx.roundedRect(x, y, w, h, h / 2, h / 2); ctx.fill()
    }

    // The person is drawn in a 36-wide local frame centred on x = 18, then
    // shifted so that centre lands on personX.
    function paintPerson(ctx) {
        ctx.reset()
        ctx.translate(padX, padY)
        setup(ctx)
        var G = ground
        var dx = personX - 18
        var self = character

        // umbrella held at (hx, hy), shaft tilted by `tiltDeg` (negative = into the
        // wind, to the left); the canopy opens with umbrellaOpenProgress, from a
        // closed stick to the full dome
        function umbrella(hx, hy, tiltDeg, inverted, r, shaft) {
            var open = Math.max(0, self.umbrellaOpenProgress)
            ctx.save()
            ctx.translate(hx, hy)
            ctx.rotate(tiltDeg * Math.PI / 180)
            line(ctx, 0, 0, 0, -shaft, 1.6)                           // shaft
            line(ctx, 0, 0, 1.6, 1.8, 1.6)                            // crook
            if (open <= 0.02) {
                line(ctx, 0, -shaft, 0, -shaft - r * 0.6, 2.4)         // furled canopy along the shaft
            } else if (!inverted) {
                ctx.save()
                ctx.translate(0, -shaft); ctx.scale(open, open)         // canopy width and curve grow together
                ctx.beginPath()
                ctx.arc(0, 0, r, Math.PI, Math.PI * 2)                   // dome
                ctx.closePath(); ctx.fill()
                for (var i = -1; i <= 1; i++) {                          // scalloped rim
                    ctx.beginPath(); ctx.arc(i * r * 0.66, 0, r * 0.34, 0, Math.PI); ctx.fill()
                }
                ctx.restore()
            } else {
                ctx.lineWidth = 2.4                                      // canopy blown inside-out: a bowl above the tip
                ctx.beginPath()
                ctx.arc(0, -shaft - 5 * open, r * 0.75 * open, Math.PI * 0.05, Math.PI * 0.95, true)
                ctx.stroke()
                line(ctx, 0, -shaft, 0, -shaft - 5 * open, 1.6)
            }
            ctx.restore()
        }
        function scarf(nx, ny, len, amp) {                            // rippling tail trailing in the wind (len < 0: to the left)
            var dir = len < 0 ? -1 : 1, n = Math.abs(len)
            ctx.lineWidth = 1.8
            ctx.beginPath(); ctx.moveTo(nx, ny)
            for (var x = 1; x <= n; x++) {
                var k = x / n
                ctx.lineTo(nx + x * dir, ny + 1.5 * k + Math.sin(k * 7 - self.phase - self.walkPhase) * amp * k)
            }
            ctx.stroke()
        }
        function hat(headY) {                                          // brim and crown riding on the head
            line(ctx, 13, headY - 2.8, 23, headY - 2.8, 1.6)
            ctx.fillRect(15, headY - 5.5, 6, 2.8)
        }

        // Each pose is a skeleton: head, torso top, hip (where the legs
        // start), two legs as [kneeX, kneeY, footX, footY], two arms as
        // [ax, ay, bx, by], a lean in degrees about the feet and a torso
        // width. The idle skeleton and the walking skeleton are blended
        // with walkBlend, so sitting down and standing up are continuous.
        function seatedBody(headX, headY, swing) {
            var legs = [], kxs = [22, 24]
            for (var i = 0; i < 2; i++) {                              // thighs forward over the edge, shins hanging and swinging
                var a = (swing + (i === 0 ? 0 : -6)) * Math.PI / 180
                legs.push([kxs[i], G + 1, kxs[i] + Math.sin(a) * 7, G + 1 + Math.cos(a) * 7])
            }
            return { head: [headX, headY], top: headY + 3.5, hip: [18, G], legs: legs,
                     arms: [[18, G - 7, 14, G], [18, G - 7, 22, G]], lean: 0, torso: 2.4 }   // arms propped behind
        }
        function standingBody(lean, arms, torso) {
            return { head: [18, 5], top: 8.5, hip: [18, 19], legs: [[16.5, 23.5, 15, G], [19.5, 23.5, 21, G]],
                     arms: arms, lean: lean, torso: torso || 2.4 }
        }
        var idle, umbIdle = null
        switch (pose) {
        case "storm": {
            // arm reaches up and forward to the umbrella; while tugging it pulls back down
            var hx = 22 - self.tug * 2, hy = 15 + self.tug * 2
            idle = standingBody(-25, [[18, 11, hx, hy], [18, 11, 16.5, 17]])
            umbIdle = { x: hx, y: hy, tilt: -30 + self.tug * 12, r: 8, shaft: 8 }
            break
        }
        case "rain":
        case "thunder":
            // seated, head tipped back watching the rain; the umbrella is held out
            // to the right so its wide dome covers the dog as well (card x = 20)
            idle = seatedBody(19, G - 14.5, 0)
            idle.arms = [[18, G - 9, 38 - self.idlePersonX, G - 13], [18, G - 8, 14, G]]
            umbIdle = { x: 38 - self.idlePersonX, y: G - 13, tilt: 0, r: 13, shaft: 6 }
            break
        case "snow":
            idle = standingBody(0, [[14, 13, 22, 15.5], [22, 13, 14, 15.5]], 3.6)   // bundled up, arms hugging the chest
            break
        case "windy":
            idle = standingBody(-25, [[18, 11, 14.5, 4.5], [18, 11, 21.5, 16]])    // hand on the hat, other arm trailing
            break
        case "sunny":
            idle = seatedBody(18, G - 14, Math.sin(phase) * 8)
            break
        case "night":
            idle = seatedBody(19.5, G - 13, 0)                           // head slumped forward, dozing
            break
        default:                                                       // calm: seated on the edge, looking up
            idle = seatedBody(18.5, G - 14.5, 0)
            break
        }

        // walking: facing right, short calm steps, the forward foot lifting,
        // arms counter-swinging; the leading hand holds the umbrella up
        var sw = Math.sin(self.walkPhase)
        var walk = { head: [18.5, 5], top: 8.5, hip: [18, 19],
                     legs: [[18 + sw * 1.25, 23.5 - Math.max(0, sw) * 0.5, 18 + sw * 2.5, G - Math.max(0, sw)],
                            [18 - sw * 1.25, 23.5 - Math.max(0, -sw) * 0.5, 18 - sw * 2.5, G - Math.max(0, -sw)]],
                     arms: [[18, 11, 18 - sw * 2, 17], self.wet ? [18, 11, 21, 13.5] : [18, 11, 18 + sw * 2, 17]],
                     lean: 0, torso: pose === "snow" ? 3.6 : 2.4 }
        var umbWalk = self.wet ? { x: 21, y: 13.5, tilt: pose === "storm" ? (self.mirror ? 25 : -25) : 10, r: 9, shaft: 9 } : null

        var b = Math.max(0, Math.min(1, self.walkBlend))
        function mix(a, c) {                                           // numbers, arrays or objects, element-wise
            if (b <= 0) return a
            if (b >= 1) return c
            if (typeof a === "number") return a + (c - a) * b
            if (Array.isArray(a)) { var o = []; for (var i = 0; i < a.length; i++) o.push(mix(a[i], c[i])); return o }
            var r = {}; for (var k in a) r[k] = mix(a[k], c[k]); return r
        }
        var body = mix(idle, walk)
        var umb = umbIdle && umbWalk ? mix(umbIdle, umbWalk) : null

        ctx.save()
        ctx.translate(dx, 0)
        if (body.lean !== 0) { ctx.translate(18, G); ctx.rotate(body.lean * Math.PI / 180); ctx.translate(-18, -G) }
        dot(ctx, body.head[0], body.head[1], 3)                                   // head
        line(ctx, 18, body.top, body.hip[0], body.hip[1], body.torso)             // torso
        if (pose === "snow") { ctx.beginPath(); ctx.ellipse(13.5, body.head[1] + 2.2, 9, 3.2); ctx.fill() }   // wrapped scarf
        for (var li = 0; li < 2; li++) {
            var leg = body.legs[li]
            line(ctx, body.hip[0], body.hip[1], leg[0], leg[1], 2.2)
            line(ctx, leg[0], leg[1], leg[2], leg[3], 2.2)
        }
        for (var ai = 0; ai < 2; ai++) {
            var arm = body.arms[ai]
            line(ctx, arm[0], arm[1], arm[2], arm[3], 2)
        }
        if (umb) umbrella(umb.x, umb.y, umb.tilt, self.flipped, umb.r, umb.shaft)
        if (pose === "sunny" || pose === "windy") hat(body.head[1])
        if (pose === "windy") {                                        // the scarf streams out to the right at rest, behind on a walk
            if (b < 1) { ctx.globalAlpha = 1 - b; scarf(18.5, 8.5, 15, 3) }
            if (b > 0) { ctx.globalAlpha = b; scarf(17.5, 8.5, -12, 2) }
            ctx.globalAlpha = 1
        }
        ctx.restore()

        if (pose === "snow" && propScale > 0) {                        // snowman, in card coordinates, growing up from the ground
            var ps = propScale
            dot(ctx, 25, G - 3 * ps, 3 * ps)
            dot(ctx, 25, G - 8.2 * ps, 2.3 * ps)
        }
    }

    // The dog is drawn in its own 24 x 20 box (ground at y = 20), facing left.
    function paintDog(ctx) {
        ctx.reset()
        ctx.translate(4, 4)
        setup(ctx)
        var tilt = dog.headTilt * Math.PI / 180
        function head(cx, cy, r) {                                     // head with a short snout to the left
            ctx.save()
            ctx.translate(cx, cy); ctx.rotate(-tilt)
            dot(ctx, 0, 0, r)
            pill(ctx, -r - 1.5, -0.2, r + 1, 2)
            ctx.restore()
        }
        var b = Math.max(0, Math.min(1, walkBlend))
        if (b < 1) { ctx.globalAlpha = 1 - b; stance(dog.idleStance) }
        if (b > 0) { ctx.globalAlpha = b; stance("trot") }
        ctx.globalAlpha = 1

        function stance(st) {
        switch (st) {
        case "trot": {                                                 // diagonal leg pairs swing together
            var sw = Math.sin(character.walkPhase)
            pill(ctx, 4, 9, 13, 5.5)                                   // body
            head(3.5, 7.5, 3)                                          // head up, happy
            line(ctx, 6, 13, 6 - sw * 1.2, 20 - Math.max(0, -sw) * 0.6, 1.8)
            line(ctx, 9, 13, 9 + sw * 1.2, 20 - Math.max(0, sw) * 0.6, 1.8)
            line(ctx, 13, 13, 13 - sw * 1.2, 20 - Math.max(0, -sw) * 0.6, 1.8)
            line(ctx, 16, 13, 16 + sw * 1.2, 20 - Math.max(0, sw) * 0.6, 1.8)
            break
        }
        case "stand":
            pill(ctx, 4, 9, 13, 5.5)                                   // body
            head(4, 8.5, 3)
            line(ctx, 6, 13, 6, 20, 1.8)                               // legs
            line(ctx, 9, 13, 9, 20, 1.8)
            line(ctx, 13, 13, 13, 20, 1.8)
            line(ctx, 16, 13, 16, 20, 1.8)
            break
        case "sit":
            dot(ctx, 15, 16, 3.8)                                      // haunch
            line(ctx, 15, 16, 7, 9, 4.5)                               // chest rising to the head
            head(5, 6.5, 3)
            line(ctx, 8, 11, 8, 20, 1.8)                               // front legs
            line(ctx, 11, 12, 11, 20, 1.8)
            break
        case "curl":
            ctx.beginPath(); ctx.ellipse(3, 13, 18, 7); ctx.fill()     // curled up
            dot(ctx, 7, 13.5, 2.8)                                     // head tucked in
            break
        case "crouch":
            pill(ctx, 4, 14, 13, 4.5)                                  // low body
            head(3.5, 13, 2.8)
            line(ctx, 6, 18, 6, 20, 1.8)
            line(ctx, 15, 18, 15, 20, 1.8)
            break
        case "pounce":
            dot(ctx, 16, 11, 3.5)                                      // rear up
            line(ctx, 16, 11, 7, 15, 4.5)                              // back sloping down to the chest
            head(4.5, 13.5, 2.8)
            line(ctx, 6, 16, 3, 20, 1.8)                               // front legs stretched forward
            line(ctx, 9, 16, 7, 20, 1.8)
            line(ctx, 16, 14, 17, 20, 1.8)                             // rear legs
            line(ctx, 18, 14, 19, 20, 1.8)
            break
        }
        }
    }

    Component.onCompleted: { renderedScene = targetScene; art.requestPaint(); dogArt.requestPaint() }
}
