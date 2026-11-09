.pragma library

// In-hub keys (SPEC.md section 10): which tab a key leads to and where an
// arrow moves the focus. Pure, so it is tested without a window.

// Tab/Shift+Tab: the next or previous tab, wrapping. `tabs` are values.
function stepTab(tabs, current, direction) {
  if (!tabs || tabs.length === 0) return ""
  var i = tabs.indexOf(current)
  if (i < 0) return tabs[0]
  var n = tabs.length
  return tabs[((i + direction) % n + n) % n]
}

// 1–9: the nth tab, or "" when there is none.
function digitTab(tabs, text) {
  if (!tabs || typeof text !== "string" || !/^[1-9]$/.test(text)) return ""
  var i = Number(text) - 1
  return i < tabs.length ? tabs[i] : ""
}

// The index in `rects` closest to `rect`, or -1: where the focus goes when the
// control it was on has gone (a cancelled timer, a dismissed activity).
function nearest(rects, rect) {
  if (!rects || !rect) return -1
  var best = -1, bestDist = Infinity
  for (var i = 0; i < rects.length; i++) {
    var dx = (rects[i].x + rects[i].w / 2) - (rect.x + rect.w / 2)
    var dy = (rects[i].y + rects[i].h / 2) - (rect.y + rect.h / 2)
    var dist = dx * dx + dy * dy
    if (dist < bestDist) { bestDist = dist; best = i }
  }
  return best
}

// Arrows: the index in `rects` ([{x, y, w, h}], one coordinate space) to
// move to from `from` in direction (dx, dy), or `from` when nothing lies
// that way. With nothing focused (from < 0) the top-left one. Controls in the
// same row (for Left and Right) or column (for Up and Down) come first. Failing
// that, Left, Right and Down take the closest one that way, so a side column
// still reaches the transport below it; Up does not, so at the top of a column
// it stays and the hub goes on to the tab strip instead of another column.
function move(rects, from, dx, dy) {
  if (!rects || rects.length === 0) return -1
  if (from < 0 || from >= rects.length) {
    var first = 0
    for (var k = 1; k < rects.length; k++) {
      var a = rects[k], b = rects[first]
      if (a.y < b.y - 1 || (Math.abs(a.y - b.y) <= 1 && a.x < b.x)) first = k
    }
    return first
  }
  var near = closest(rects, from, dx, dy, true)
  if (near !== from || dy < 0) return near
  return closest(rects, from, dx, dy, false)
}

function closest(rects, from, dx, dy, aligned) {
  var cur = rects[from]
  var cx = cur.x + cur.w / 2, cy = cur.y + cur.h / 2
  var best = from, bestScore = Infinity
  for (var i = 0; i < rects.length; i++) {
    if (i === from) continue
    var r = rects[i]
    var rx = r.x + r.w / 2, ry = r.y + r.h / 2
    var along, side
    if (dx !== 0) {
      // Must start past the current one's centre in that direction.
      along = dx > 0 ? r.x + r.w / 2 - cx : cx - (r.x + r.w / 2)
      side = Math.abs(ry - cy)
      if (dx > 0 ? r.x + r.w <= cur.x + cur.w : r.x >= cur.x) continue
      if (aligned && (r.y >= cur.y + cur.h || r.y + r.h <= cur.y)) continue
    } else {
      along = dy > 0 ? ry - cy : cy - ry
      side = Math.abs(rx - cx)
      if (dy > 0 ? r.y + r.h <= cur.y + cur.h : r.y >= cur.y) continue
      if (aligned && (r.x >= cur.x + cur.w || r.x + r.w <= cur.x)) continue
    }
    if (along <= 0) continue
    var score = along + side * 2
    if (score < bestScore) { bestScore = score; best = i }
  }
  return best
}
