#if os(macOS)
  import AppKit

  extension BraceLayout {
    /// One typeset part placed in the composed image.
    private struct Placed {
      let image: NSImage
      /// Bottom of the image relative to the shared baseline (negative is below).
      let bottom: CGFloat
      let x: CGFloat
    }

    /// `pieces` set side by side on one baseline. `render` typesets one part
    /// (latex, display, font size). Returns `nil` when any part fails, so
    /// the caller shows the formula's source rather than a formula with a
    /// hole in it.
    static func compose(
      _ pieces: [Piece],
      display: Bool,
      fontSize: CGFloat,
      color: NSColor,
      render: (String, Bool, CGFloat) -> TypesetFormula?
    ) -> TypesetFormula? {
      let gap = (fontSize * 0.15).rounded()
      let braceHeight = (fontSize * 0.45).rounded()
      var placed: [Placed] = []
      var braces: [(x: CGFloat, width: CGFloat, y: CGFloat, under: Bool)] = []
      var x: CGFloat = 0
      for piece in pieces {
        switch piece {
        case .math(let latex):
          guard let part = render(latex, display, fontSize) else { return nil }
          placed.append(Placed(image: part.image, bottom: -part.descent, x: x))
          x += part.image.size.width
        case .brace(let term, let label, let under):
          guard let body = render(term, display, fontSize) else { return nil }
          let note = label.flatMap { render($0, false, fontSize * 0.72) }
          if label != nil, note == nil { return nil }
          let width = max(body.image.size.width, note?.image.size.width ?? 0)
          let bodyX = x + (width - body.image.size.width) / 2
          let bodyBottom = -body.descent
          let bodyTop = bodyBottom + body.image.size.height
          placed.append(Placed(image: body.image, bottom: bodyBottom, x: bodyX))
          // The brace runs the width of the term, just past its ink.
          let braceY = under ? bodyBottom - gap - braceHeight : bodyTop + gap
          braces.append((bodyX, body.image.size.width, braceY, under))
          if let note {
            let noteX = x + (width - note.image.size.width) / 2
            let noteBottom = under
              ? braceY - gap - note.image.size.height
              : braceY + braceHeight + gap
            placed.append(Placed(image: note.image, bottom: noteBottom, x: noteX))
          }
          x += width
        }
      }
      return draw(placed, braces: braces, width: x, braceHeight: braceHeight, color: color)
    }

    private static func draw(
      _ placed: [Placed],
      braces: [(x: CGFloat, width: CGFloat, y: CGFloat, under: Bool)],
      width: CGFloat,
      braceHeight: CGFloat,
      color: NSColor
    ) -> TypesetFormula {
      let lowest = min(placed.map(\.bottom).min() ?? 0, braces.map(\.y).min() ?? 0)
      let highest = max(
        placed.map { $0.bottom + $0.image.size.height }.max() ?? 0,
        braces.map { $0.y + braceHeight }.max() ?? 0)
      let size = CGSize(width: ceil(width), height: ceil(highest - lowest))
      let image = NSImage(size: size, flipped: false) { _ in
        for part in placed {
          part.image.draw(in: CGRect(
            x: part.x, y: part.bottom - lowest, width: part.image.size.width, height: part.image.size.height))
        }
        color.setStroke()
        for brace in braces {
          let path = curlyBrace(
            in: CGRect(x: brace.x, y: brace.y - lowest, width: brace.width, height: braceHeight),
            pointingDown: brace.under)
          path.lineWidth = 1
          path.lineCapStyle = .round
          path.stroke()
        }
        return true
      }
      return TypesetFormula(image: image, descent: -lowest)
    }

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
                 controlPoint1: CGPoint(x: rect.minX, y: mid),
                 controlPoint2: CGPoint(x: rect.minX, y: mid))
      path.line(to: CGPoint(x: centre - r, y: mid))
      path.curve(to: CGPoint(x: centre, y: inner),
                 controlPoint1: CGPoint(x: centre, y: mid),
                 controlPoint2: CGPoint(x: centre, y: mid))
      path.curve(to: CGPoint(x: centre + r, y: mid),
                 controlPoint1: CGPoint(x: centre, y: mid),
                 controlPoint2: CGPoint(x: centre, y: mid))
      path.line(to: CGPoint(x: rect.maxX - r, y: mid))
      path.curve(to: CGPoint(x: rect.maxX, y: outer),
                 controlPoint1: CGPoint(x: rect.maxX, y: mid),
                 controlPoint2: CGPoint(x: rect.maxX, y: mid))
      return path
    }
  }
#endif
