pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// A concave corner: an r × r square, minus the quarter circle centred on the
// corner opposite `corner`, so what is left hugs `corner` and its curve
// joins two straight edges smoothly. Where the hub's card meets the cap or
// the bar, it turns a right angle into a curve.
//
// `corner` is the filled one: "topLeft", "topRight", "bottomLeft" or
// "bottomRight". The curve gets a stroke of `strokeWidth` in `strokeColor`
// (none at 0), so a bordered surface's outline runs on round it.
Item {
  id: root

  property string corner: "topRight"
  property real r: 0
  property color fill: "transparent"
  property color strokeColor: "transparent"
  property real strokeWidth: 0

  width: r
  height: r
  visible: r > 0.5

  // Drawn for the top-right corner, then mirrored into place.
  readonly property bool flipX: corner === "topLeft" || corner === "bottomLeft"
  readonly property bool flipY: corner === "bottomLeft" || corner === "bottomRight"
  transform: Scale {
    origin.x: root.r / 2
    origin.y: root.r / 2
    xScale: root.flipX ? -1 : 1
    yScale: root.flipY ? -1 : 1
  }

  // Room past the square on every side: the stroke runs outside it (see
  // below), and a Shape draws only inside its own bounds.
  readonly property real pad: Math.max(2, strokeWidth * 2)

  Shape {
    x: -root.pad
    y: -root.pad
    width: root.r + root.pad * 2
    height: root.r + root.pad * 2
    preferredRendererType: Shape.CurveRenderer

    // The filled sliver: top-right corner, along the top edge, the curve
    // (centred bottom-left) down to the right edge, and back.
    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillColor: root.fill
      startX: root.pad + root.r; startY: root.pad
      PathLine { x: root.pad; y: root.pad }
      PathArc { x: root.pad + root.r; y: root.pad + root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
      PathLine { x: root.pad + root.r; y: root.pad }
    }

    // The outline along the curve. The joined surfaces draw their borders
    // inside their own edges, which here is the filled side of the curve, so
    // the stroke runs half its width further out from the centre; it carries
    // on straight for `pad` past each end, over those borders, so no seam
    // shows where they meet.
    ShapePath {
      strokeWidth: root.strokeWidth
      strokeColor: root.strokeWidth > 0 ? root.strokeColor : "transparent"
      fillColor: "transparent"
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.RoundJoin
      startX: 0; startY: root.pad - root.strokeWidth / 2
      PathLine { x: root.pad; y: root.pad - root.strokeWidth / 2 }
      PathArc {
        x: root.pad + root.r + root.strokeWidth / 2; y: root.pad + root.r
        radiusX: root.r + root.strokeWidth / 2; radiusY: root.r + root.strokeWidth / 2
        direction: PathArc.Clockwise
      }
      PathLine { x: root.pad + root.r + root.strokeWidth / 2; y: root.pad * 2 + root.r }
    }
  }
}
