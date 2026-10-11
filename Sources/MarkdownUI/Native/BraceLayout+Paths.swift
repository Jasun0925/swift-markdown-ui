#if os(macOS)
  import AppKit

  extension BraceLayout {
    /// A horizontal curly brace filling `rect`. Pointing down, its ends curl
    /// up toward the term above and its tip points at the label below.
    static func curlyBrace(in rect: CGRect, pointingDown: Bool) -> NSBezierPath {
      let path = NSBezierPath()
      let (outer, inner) = pointingDown ? (rect.maxY, rect.minY) : (rect.minY, rect.maxY)
      let mid = (outer + inner) / 2
      let r = min(rect.height / 2, rect.width / 4)
      let centre = rect.midX
      path.move(to: CGPoint(x: rect.minX, y: outer))
      path.curve(to: CGPoint(x: rect.minX + r, y: mid),
                 controlPoint1: CGPoint(x: rect.minX, y: mid), controlPoint2: CGPoint(x: rect.minX, y: mid))
      path.line(to: CGPoint(x: centre - r, y: mid))
      path.curve(to: CGPoint(x: centre, y: inner),
                 controlPoint1: CGPoint(x: centre, y: mid), controlPoint2: CGPoint(x: centre, y: mid))
      path.curve(to: CGPoint(x: centre + r, y: mid),
                 controlPoint1: CGPoint(x: centre, y: mid), controlPoint2: CGPoint(x: centre, y: mid))
      path.line(to: CGPoint(x: rect.maxX - r, y: mid))
      path.curve(to: CGPoint(x: rect.maxX, y: outer),
                 controlPoint1: CGPoint(x: rect.maxX, y: mid), controlPoint2: CGPoint(x: rect.maxX, y: mid))
      path.lineWidth = 1
      path.lineCapStyle = .round
      return path
    }

    /// A shaft across `rect` at its middle, with an open head at one end.
    static func arrow(in rect: CGRect, pointingLeft: Bool) -> NSBezierPath {
      let path = NSBezierPath()
      let y = rect.midY
      let half = rect.height / 2
      let (tail, tip) = pointingLeft ? (rect.maxX, rect.minX) : (rect.minX, rect.maxX)
      let back = pointingLeft ? tip + half * 1.4 : tip - half * 1.4
      path.move(to: CGPoint(x: tail, y: y))
      path.line(to: CGPoint(x: tip, y: y))
      path.move(to: CGPoint(x: back, y: y + half))
      path.curve(to: CGPoint(x: tip, y: y),
                 controlPoint1: CGPoint(x: back + (tip - back) * 0.5, y: y + half * 0.4),
                 controlPoint2: CGPoint(x: tip, y: y))
      path.curve(to: CGPoint(x: back, y: y - half),
                 controlPoint1: CGPoint(x: tip, y: y),
                 controlPoint2: CGPoint(x: back + (tip - back) * 0.5, y: y - half * 0.4))
      path.lineWidth = 0.9
      path.lineCapStyle = .round
      return path
    }
  }
#endif
