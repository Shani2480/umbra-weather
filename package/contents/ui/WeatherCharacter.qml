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

    width: 54
    height: 36
    opacity: 0.32

    readonly property real ground: 28
    readonly property real padX: 10          // canvas headroom, see `art`
    readonly property real padY: 12
    readonly property bool wet: condition === "rain" || condition === "thunder"
    readonly property string pose: wet && windSpeed >= 22 ? "storm"
        : condition === "thunder" ? "thunder"
        : condition === "rain" ? "rain"
        : condition === "snow" ? "snow"
        : windSpeed >= 25 ? "windy"
        : condition === "clear" && !isNight ? "sunny"
        : condition === "clear" && isNight ? "night"
        : "calm"
    readonly property bool sheltered: pose === "rain" || pose === "thunder"
    readonly property bool leaning: pose === "storm" || pose === "windy"
    readonly property bool gusty: pose === "storm" || pose === "windy"

    // Where the person stands (centre x of the figure) and where the dog's box starts.
    readonly property real personX: leaning ? 14 : pose === "calm" ? 14 : 11
    readonly property real dogX: pose === "sunny" ? 30 : pose === "night" ? 22 : pose === "rain" ? 15
        : pose === "thunder" ? 13 : pose === "storm" ? 26 : pose === "windy" ? 28 : pose === "snow" ? 30 : 24

    // Animated pose parameters. Changing any of them repaints the canvas.
    property real phase: 0               // 0..2π, drives the scarf ripple and the leg swing
    property bool flipped: false         // umbrella inside-out (storm)
    property real tug: 0                 // 0..1 how far the arm has pulled the umbrella back down

    function flinch() { flinchAnim.restart() }
    function duck() { flinch() }

    onPoseChanged: { flipped = false; tug = 0; art.requestPaint(); dogArt.requestPaint() }
    onPhaseChanged: art.requestPaint()
    onFlippedChanged: art.requestPaint()
    onTugChanged: art.requestPaint()
    onColorChanged: { art.requestPaint(); dogArt.requestPaint() }

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
        transform: [
            Translate { x: person.jitter; y: person.bob },
            Rotation { origin.x: character.personX; origin.y: character.ground; angle: person.rock },
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
            running: character.running && character.pose === "storm"
            loops: Animation.Infinite
            NumberAnimation { to: 8; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { to: -5; duration: 600; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) person.rock = 0
        }
        // calm: a slow sway
        SequentialAnimation on rock {
            running: character.running && character.pose === "calm"
            loops: Animation.Infinite
            NumberAnimation { to: 2; duration: 2600; easing.type: Easing.InOutSine }
            NumberAnimation { to: -2; duration: 2600; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) person.rock = 0
        }
        // rain / windy / sunny: gentle breathing bob
        SequentialAnimation on bob {
            running: character.running && (character.sheltered || character.pose === "windy" || character.pose === "sunny")
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
            running: character.running && character.pose === "snow"
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
    NumberAnimation on phase {
        running: character.running && (character.pose === "windy" || character.pose === "sunny")
        from: 0; to: Math.PI * 2
        duration: character.pose === "windy" ? 420 : 2200
        loops: Animation.Infinite
    }

    // storm: every 4.5 s the canopy blows inside-out for 1.2 s while the arm tugs it back
    Timer {
        running: character.running && character.pose === "storm"
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
        transform: [
            Translate { y: dog.hop },
            Scale { id: dogFlinch; origin.x: 12; origin.y: 20; yScale: 1 },
            Scale { origin.x: 12; origin.y: 20; yScale: dog.breathe }
        ]
        onHeadTiltChanged: dogArt.requestPaint()

        // body pose for the dog
        readonly property string stance: character.pose === "sunny" || character.pose === "windy" ? "stand"
            : character.pose === "night" ? "curl"
            : character.pose === "storm" ? "crouch"
            : character.pose === "snow" ? "pounce"
            : "sit"
        onStanceChanged: dogArt.requestPaint()

        Canvas {
            id: dogArt
            x: -4; y: -4
            width: 32; height: 24
            renderStrategy: Canvas.Cooperative
            onPaint: character.paintDog(getContext("2d"))
        }

        // tail root and resting angle per stance (0 = pointing right along the ground)
        readonly property var tailSpec: stance === "stand" ? { x: 17, y: 9.5, a: -35 }
            : stance === "sit" ? { x: 18, y: 18.5, a: -10 }
            : stance === "crouch" ? { x: 17, y: 15.5, a: 0 }
            : stance === "pounce" ? { x: 19, y: 8, a: -60 }
            : null
        Rectangle {
            id: tail
            visible: dog.tailSpec !== null
            x: dog.tailSpec ? dog.tailSpec.x : 0
            y: dog.tailSpec ? dog.tailSpec.y - 1 : 0
            width: 6; height: 2; radius: 1
            color: character.color
            transformOrigin: Item.Left
            property real wag: 0
            rotation: (dog.tailSpec ? dog.tailSpec.a : 0) + wag
            // joyful: ±20° every 180 ms (sunny, snow)
            SequentialAnimation on wag {
                running: character.running && (character.pose === "sunny" || character.pose === "snow")
                loops: Animation.Infinite
                NumberAnimation { to: 20; duration: 180; easing.type: Easing.InOutSine }
                NumberAnimation { to: -20; duration: 180; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) tail.wag = 0
            }
            // relaxed: 600 ms cycle (calm)
            SequentialAnimation on wag {
                running: character.running && character.pose === "calm"
                loops: Animation.Infinite
                NumberAnimation { to: 14; duration: 300; easing.type: Easing.InOutSine }
                NumberAnimation { to: -14; duration: 300; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) tail.wag = 0
            }
            // slow and calm under the umbrella (rain, thunder)
            SequentialAnimation on wag {
                running: character.running && character.sheltered
                loops: Animation.Infinite
                NumberAnimation { to: 12; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: -8; duration: 900; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) tail.wag = 0
            }
            // blown flat and fluttering in the wind (storm, windy)
            SequentialAnimation on wag {
                running: character.running && character.gusty
                loops: Animation.Infinite
                NumberAnimation { to: 8; duration: 90 }
                NumberAnimation { to: -10; duration: 110 }
                NumberAnimation { to: 5; duration: 80 }
                NumberAnimation { to: -6; duration: 100 }
                onRunningChanged: if (!running) tail.wag = 0
            }
        }

        // floppy ear hanging from the back of the head; flutters back in the wind
        readonly property var earSpec: stance === "stand" ? { x: 4.5, y: 6 }
            : stance === "sit" ? { x: 5.5, y: 4 }
            : stance === "crouch" ? { x: 4, y: 10.5 }
            : stance === "pounce" ? { x: 5, y: 11 }
            : null
        Rectangle {
            id: ear
            visible: dog.earSpec !== null
            x: dog.earSpec ? dog.earSpec.x : 0
            y: dog.earSpec ? dog.earSpec.y : 0
            width: 2; height: 4.5; radius: 1
            color: character.color
            transformOrigin: Item.Top
            property real flutter: 0
            rotation: (character.gusty ? -60 : 0) + flutter
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
            running: character.running && character.pose === "sunny"
            loops: Animation.Infinite
            NumberAnimation { to: -4; duration: 300; easing.type: Easing.OutQuad }
            NumberAnimation { to: 0; duration: 300; easing.type: Easing.InQuad }
            PauseAnimation { duration: 300 }
            onRunningChanged: if (!running) dog.hop = 0
        }
        // snow: small excited hops in place
        SequentialAnimation on hop {
            running: character.running && character.pose === "snow"
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
            running: character.running && character.pose === "rain"
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
        y: character.ground - 6 - Math.sin(p * Math.PI) * 11
        SequentialAnimation on p {
            running: character.running && character.pose === "sunny"
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

    // night: tiny z's drifting up from the pair and fading out
    Repeater {
        model: character.pose === "night" ? [ { x: 16, y: 9, d: 0 }, { x: 30, y: 17, d: 1300 } ] : []
        Text {
            required property var modelData
            text: "z"
            color: character.color
            font.pixelSize: 7
            font.bold: true
            property real rise: 0
            x: modelData.x + rise * 5
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

        // umbrella held at (hx, hy), shaft tilted by `tiltDeg` (negative = into the wind, to the left)
        function umbrella(hx, hy, tiltDeg, inverted, r, shaft) {
            ctx.save()
            ctx.translate(hx, hy)
            ctx.rotate(tiltDeg * Math.PI / 180)
            line(ctx, 0, 0, 0, -shaft, 1.6)                           // shaft
            line(ctx, 0, 0, 1.6, 1.8, 1.6)                            // crook
            if (!inverted) {
                ctx.beginPath()
                ctx.arc(0, -shaft, r, Math.PI, Math.PI * 2)              // dome
                ctx.closePath(); ctx.fill()
                for (var i = -1; i <= 1; i++) {                          // scalloped rim
                    ctx.beginPath(); ctx.arc(i * r * 0.66, -shaft, r * 0.34, 0, Math.PI); ctx.fill()
                }
            } else {
                ctx.lineWidth = 2.4                                      // canopy blown inside-out: a bowl above the tip
                ctx.beginPath()
                ctx.arc(0, -shaft - 5, r * 0.75, Math.PI * 0.05, Math.PI * 0.95, true)
                ctx.stroke()
                line(ctx, 0, -shaft, 0, -shaft - 5, 1.6)
            }
            ctx.restore()
        }
        function scarf(nx, ny, len, amp) {                            // rippling tail trailing right in the wind
            ctx.lineWidth = 1.8
            ctx.beginPath(); ctx.moveTo(nx, ny)
            for (var x = 1; x <= len; x++) {
                var k = x / len
                ctx.lineTo(nx + x, ny + 1.5 * k + Math.sin(k * 7 - self.phase) * amp * k)
            }
            ctx.stroke()
        }
        function standing(headX, headY, armsFn) {
            dot(ctx, headX, headY, 3)                                  // head
            line(ctx, 18, headY + 3.5, 18, 19, 2.4)                    // torso
            line(ctx, 18, 19, 15, G, 2.2)                              // legs
            line(ctx, 18, 19, 21, G, 2.2)
            if (armsFn) armsFn()
        }
        function seated(headX, headY, swing, armsFn) {
            dot(ctx, headX, headY, 3)
            line(ctx, 18, headY + 3.5, 18, G, 2.4)                     // torso down to the seat
            if (armsFn) armsFn()
            else {
                line(ctx, 18, G - 7, 14, G, 1.8)                       // arms propped behind
                line(ctx, 18, G - 7, 22, G, 1.8)
            }
            // thighs forward over the edge, shins hanging and swinging
            var legs = [ { kx: 22, dx: 0 }, { kx: 24, dx: 1 } ]
            for (var i = 0; i < legs.length; i++) {
                var kx = legs[i].kx
                line(ctx, 18, G, kx, G + 1, 2.2)
                var a = (swing + (i === 0 ? 0 : -6)) * Math.PI / 180
                line(ctx, kx, G + 1, kx + Math.sin(a) * 7, G + 1 + Math.cos(a) * 7, 2.2)
            }
        }

        ctx.save()
        ctx.translate(dx, 0)
        switch (pose) {
        case "storm": {
            ctx.save()
            ctx.translate(18, G); ctx.rotate(-25 * Math.PI / 180); ctx.translate(-18, -G)
            standing(18, 5, function () {
                // arm reaches up and forward to the umbrella; while tugging it pulls back down
                var hx = 22 - self.tug * 2, hy = 15 + self.tug * 2
                line(ctx, 18, 11, hx, hy, 2)
                umbrella(hx, hy, -30 + self.tug * 12, self.flipped, 8, 8)
            })
            ctx.restore()
            break
        }
        case "rain":
        case "thunder":
            // seated, head tipped back watching the rain; the umbrella is held out
            // to the right so its wide dome covers the dog as well
            seated(19, G - 14.5, 0, function () {
                line(ctx, 18, G - 9, 38 - self.personX, G - 13, 2)            // arm up to the handle (card x = 20)
                line(ctx, 18, G - 8, 14, G, 1.8)                                  // other arm propped
            })
            umbrella(38 - self.personX, G - 13, 0, false, 13, 6)
            break
        case "snow":
            dot(ctx, 18, 5, 3)
            line(ctx, 18, 8.5, 18, 19, 3.6)                            // bundled torso
            ctx.beginPath(); ctx.ellipse(13.5, 7.2, 9, 3.2); ctx.fill() // wrapped scarf
            line(ctx, 14, 13, 22, 15.5, 2)                             // arms hugging the chest
            line(ctx, 22, 13, 14, 15.5, 2)
            line(ctx, 18, 19, 15, G, 2.2)
            line(ctx, 18, 19, 21, G, 2.2)
            break
        case "windy": {
            ctx.save()
            ctx.translate(18, G); ctx.rotate(-25 * Math.PI / 180); ctx.translate(-18, -G)
            standing(18, 5, function () {
                line(ctx, 18, 11, 14.5, 4.5, 2)                        // hand on the hat
                line(ctx, 13, 2.2, 23, 2.2, 1.6)                       // hat brim
                ctx.fillRect(15, -0.5, 6, 2.8)                         // crown
                line(ctx, 18, 11, 21.5, 16, 2)                         // other arm trailing
                scarf(18.5, 8.5, 15, 3)
            })
            ctx.restore()
            break
        }
        case "sunny":
            seated(18, G - 14, Math.sin(phase) * 8)
            line(ctx, 12, G - 17.5, 24, G - 17.5, 1.6)                 // sun hat
            ctx.fillRect(15, G - 20.5, 6, 3)
            break
        case "night":
            seated(19.5, G - 13, 0)                                    // head slumped forward, dozing
            break
        default:   // calm: seated on the edge, looking up
            seated(18.5, G - 14.5, 0)
            break
        }
        ctx.restore()

        if (pose === "snow") {                                         // snowman, in card coordinates
            dot(ctx, 25, G - 3, 3)
            dot(ctx, 25, G - 8.2, 2.3)
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
        switch (dog.stance) {
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

    Component.onCompleted: { art.requestPaint(); dogArt.requestPaint() }
}
