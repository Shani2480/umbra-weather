import QtQuick

// Line glyphs for the detail tiles (feels like, humidity, wind, pressure,
// UV index, rain chance, precipitation, cloud cover). Drawn on a Canvas so
// they stay crisp from 14px labels up to the large tile watermarks, and so
// they share one stroke style regardless of the icon theme.
Canvas {
    id: glyph

    property string kind: "feels"
    property color color: "#FFFFFF"

    onKindChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var s = Math.min(width, height)
        ctx.translate((width - s) / 2, (height - s) / 2)
        ctx.lineWidth = Math.max(1, s * 0.09)
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.strokeStyle = glyph.color
        ctx.fillStyle = glyph.color
        var k = glyph.kind
        if (k === "feels") thermometer(ctx, s)
        else if (k === "humidity") droplet(ctx, s, s / 2, s / 2, s * 0.36)
        else if (k === "wind") wind(ctx, s)
        else if (k === "pressure") gauge(ctx, s)
        else if (k === "uv") sun(ctx, s)
        else if (k === "rain") { cloud(ctx, s, 0.78, 0.40); drops(ctx, s, 0.62) }
        else if (k === "precip") precip(ctx, s)
        else cloud(ctx, s, 0.9, 0.52)
    }

    function thermometer(ctx, s) {
        var x = s * 0.5, top = s * 0.14, bulbY = s * 0.74, r = s * 0.14, w = s * 0.12
        ctx.beginPath()
        ctx.moveTo(x - w, top + w); ctx.arc(x, top + w, w, Math.PI, 0)
        ctx.lineTo(x + w, bulbY - r * 0.7)
        ctx.arc(x, bulbY, r, -Math.PI * 0.25, Math.PI * 1.25)
        ctx.closePath(); ctx.stroke()
        ctx.beginPath(); ctx.arc(x, bulbY, r * 0.5, 0, Math.PI * 2); ctx.fill()
        ctx.beginPath(); ctx.moveTo(x, bulbY - r * 0.5); ctx.lineTo(x, s * 0.42); ctx.stroke()
    }
    function droplet(ctx, s, cx, cy, r) {
        ctx.beginPath()
        ctx.moveTo(cx, cy - r * 1.15)
        ctx.bezierCurveTo(cx + r * 0.1, cy - r * 0.55, cx + r, cy - r * 0.15, cx + r, cy + r * 0.3)
        ctx.arc(cx, cy + r * 0.3, r, 0, Math.PI, false)
        ctx.bezierCurveTo(cx - r, cy - r * 0.15, cx - r * 0.1, cy - r * 0.55, cx, cy - r * 1.15)
        ctx.closePath(); ctx.stroke()
    }
    function wind(ctx, s) {
        var rows = [ { y: 0.30, x0: 0.12, x1: 0.62, curl: -1 }, { y: 0.50, x0: 0.12, x1: 0.80, curl: 1 }, { y: 0.70, x0: 0.22, x1: 0.58, curl: 1 } ]
        for (var i = 0; i < rows.length; i++) {
            var r = rows[i], y = s * r.y, x1 = s * r.x1, cr = s * 0.09
            ctx.beginPath()
            ctx.moveTo(s * r.x0, y); ctx.lineTo(x1, y)
            ctx.arc(x1, y + cr * r.curl, cr, -Math.PI / 2 * r.curl, Math.PI / 2 * r.curl, r.curl < 0)
            ctx.stroke()
        }
    }
    function gauge(ctx, s) {
        var cx = s * 0.5, cy = s * 0.58, r = s * 0.36
        ctx.beginPath(); ctx.arc(cx, cy, r, Math.PI * 0.8, Math.PI * 2.2); ctx.stroke()
        ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + r * 0.55, cy - r * 0.55); ctx.stroke()
        ctx.beginPath(); ctx.arc(cx, cy, s * 0.06, 0, Math.PI * 2); ctx.fill()
    }
    function sun(ctx, s) {
        var cx = s / 2, cy = s / 2, r = s * 0.18
        ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()
        for (var i = 0; i < 8; i++) {
            var a = i * Math.PI / 4
            ctx.beginPath()
            ctx.moveTo(cx + Math.cos(a) * r * 1.6, cy + Math.sin(a) * r * 1.6)
            ctx.lineTo(cx + Math.cos(a) * r * 2.3, cy + Math.sin(a) * r * 2.3)
            ctx.stroke()
        }
    }
    function cloud(ctx, s, w, cy) {
        var cw = s * w, x = (s - cw) / 2, y = s * cy
        var r1 = cw * 0.22, r2 = cw * 0.30
        ctx.beginPath()
        ctx.moveTo(x + r1, y + r1 * 0.9)
        ctx.arc(x + r1, y, r1, Math.PI * 0.5, Math.PI * 1.5)
        ctx.arc(x + cw * 0.46, y - r2 * 0.45, r2, Math.PI * 1.15, Math.PI * 1.95)
        ctx.arc(x + cw - r1, y, r1, Math.PI * 1.5, Math.PI * 0.5)
        ctx.closePath(); ctx.stroke()
    }
    function drops(ctx, s, y) {
        for (var i = 0; i < 3; i++) {
            var x = s * (0.34 + i * 0.16)
            ctx.beginPath(); ctx.moveTo(x, s * y); ctx.lineTo(x - s * 0.05, s * (y + 0.17)); ctx.stroke()
        }
    }
    function precip(ctx, s) {
        droplet(ctx, s, s * 0.34, s * 0.42, s * 0.17)
        droplet(ctx, s, s * 0.64, s * 0.62, s * 0.17)
    }
}
