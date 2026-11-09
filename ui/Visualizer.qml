import QtQuick
import qs.Commons as Commons
import "../lib/Visualizer.js" as Visualizer

// The wave display in the Now playing view: `levels` (0..1 per band, from
// VisualizerModule) drawn in one of lib/Visualizer.js's styles, in the
// theme's foreground. A click asks for the next style (`stylePicked`); the
// owner saves it. While nothing plays it rests as a flat line.
Item {
  id: root

  property var levels: []
  property string style: "bars"
  property color foreground: Commons.Color.foreground
  property bool playing: false

  signal stylePicked(string style)

  readonly property string shownStyle: Visualizer.normalizeStyle(style)

  onLevelsChanged: canvas.requestPaint()
  onShownStyleChanged: canvas.requestPaint()
  onForegroundChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
  onPlayingChanged: canvas.requestPaint()

  Accessible.role: Accessible.Button
  Accessible.name: "Wave style: " + Visualizer.LABELS[shownStyle] + ". Click for the next."

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    onPaint: {
      let ctx = getContext("2d")
      ctx.reset()
      let w = width, h = height
      if (w <= 0 || h <= 0) return
      let lv = root.playing && root.levels && root.levels.length > 0 ? root.levels : []
      let n = lv.length > 0 ? lv.length : Visualizer.BARS
      function level(i) { return lv.length > 0 ? lv[i] : 0 }
      ctx.fillStyle = root.foreground
      ctx.strokeStyle = root.foreground

      let gap = Math.max(1, Math.round(w / n * 0.3))
      let bw = Math.max(1, (w - gap * (n - 1)) / n)
      let minH = Math.max(1, Math.round(h * 0.03))

      function roundRect(x, y, rw, rh, r) {
        r = Math.min(r, rw / 2, rh / 2)
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.arcTo(x + rw, y, x + rw, y + rh, r)
        ctx.arcTo(x + rw, y + rh, x, y + rh, r)
        ctx.arcTo(x, y + rh, x, y, r)
        ctx.arcTo(x, y, x + rw, y, r)
        ctx.closePath()
        ctx.fill()
      }

      if (root.shownStyle === "bars") {
        for (let i = 0; i < n; i++) {
          let bh = Math.max(minH, level(i) * h)
          roundRect(i * (bw + gap), h - bh, bw, bh, bw / 2)
        }
      } else if (root.shownStyle === "mirror") {
        for (let j = 0; j < n; j++) {
          let mh = Math.max(minH, level(j) * h)
          roundRect(j * (bw + gap), (h - mh) / 2, bw, mh, bw / 2)
        }
      } else if (root.shownStyle === "wave") {
        // A smooth line through the levels, mirrored about the middle, the
        // space between them filled faintly.
        let mid = h / 2
        let step = n > 1 ? w / (n - 1) : w
        function edge(sign) {
          ctx.moveTo(0, mid - sign * level(0) * mid)
          for (let k = 1; k < n; k++) {
            let px = (k - 1) * step, x = k * step
            let py = mid - sign * level(k - 1) * mid, y = mid - sign * level(k) * mid
            ctx.quadraticCurveTo(px, py, (px + x) / 2, (py + y) / 2)
          }
          ctx.lineTo(w, mid - sign * level(n - 1) * mid)
        }
        ctx.lineWidth = Math.max(1.5, h * 0.035)
        ctx.lineJoin = "round"
        ctx.beginPath(); edge(1); ctx.stroke()
        ctx.beginPath(); edge(-1); ctx.stroke()
        ctx.globalAlpha = 0.18
        ctx.beginPath(); edge(1)
        for (let b = n - 1; b >= 0; b--) ctx.lineTo(b * step, mid + level(b) * mid)
        ctx.closePath(); ctx.fill()
        ctx.globalAlpha = 1
      } else {
        // Dots: each band a column of round dots, lit up to its level, the
        // rest faint.
        let d = Math.max(2, Math.min(bw, h / 8))
        let rows = Math.max(3, Math.floor((h + d * 0.6) / (d * 1.6)))
        let pitch = rows > 1 ? (h - d) / (rows - 1) : 0
        for (let c = 0; c < n; c++) {
          let lit = Math.round(level(c) * rows)
          let cx = c * (bw + gap) + bw / 2
          for (let r = 0; r < rows; r++) {
            ctx.globalAlpha = r < Math.max(1, lit) ? 1 : 0.15
            ctx.beginPath()
            ctx.arc(cx, h - d / 2 - r * pitch, d / 2, 0, Math.PI * 2)
            ctx.fill()
          }
        }
        ctx.globalAlpha = 1
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.stylePicked(Visualizer.nextStyle(root.shownStyle))
  }
}
