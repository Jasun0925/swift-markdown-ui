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

    private enum Stroke {
      case brace(CGRect, under: Bool)
      case arrow(CGRect, left: Bool)
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
      var strokes: [Stroke] = []
      var x: CGFloat = 0
      for (index, piece) in pieces.enumerated() {
        switch piece {
        case .math(let latex):
          // A part that is only spacing (`\;` after a brace) typesets to an
          // empty image, which SwiftMath reports as a failure. Advance by
          // the space it asks for instead.
          if let space = spacingWidth(latex, fontSize: fontSize * (display ? 1.2 : 1.1)) {
            x += space
            continue
          }
          guard let part = render(latex, display, fontSize) else { return nil }
          // A part typeset alone has no neighbour, so an `=` or `+` at its
          // edge gets no space on that side. Add the space TeX puts between
          // an operator and the term next to it (about 5mu).
          let space = (fontSize * (display ? 1.2 : 1.1) * 0.28).rounded()
          if index > 0, startsWithOperator(latex) { x += space }
          placed.append(Placed(image: part.image, bottom: -part.descent, x: x))
          x += part.image.size.width
          if index < pieces.count - 1, endsWithOperator(latex) { x += space }
        case .brace(let term, let label, let under):
          guard let body = render(term, display, fontSize) else { return nil }
          let note = label.flatMap { render($0, false, fontSize * 0.72) }
          if label != nil, note == nil { return nil }
          let width = max(body.image.size.width, note?.image.size.width ?? 0)
          let bodyX = x + (width - body.image.size.width) / 2
          let bodyBottom = -body.descent
          let bodyTop = bodyBottom + body.image.size.height
          placed.append(Placed(image: body.image, bottom: bodyBottom, x: bodyX))
          let braceY = under ? bodyBottom - gap - braceHeight : bodyTop + gap
          strokes.append(.brace(
            CGRect(x: bodyX, y: braceY, width: body.image.size.width, height: braceHeight), under: under))
          if let note {
            let noteX = x + (width - note.image.size.width) / 2
            let noteBottom = under ? braceY - gap - note.image.size.height : braceY + braceHeight + gap
            placed.append(Placed(image: note.image, bottom: noteBottom, x: noteX))
          }
          x += width
        case .arrow(let over, let under, let left):
          let small = fontSize * 0.72
          let top = over.flatMap { render($0, false, small) }
          let bottom = under.flatMap { render($0, false, small) }
          if over != nil, top == nil { return nil }
          if under != nil, bottom == nil { return nil }
          let side = (fontSize * 0.3).rounded()
          let labelWidth = max(top?.image.size.width ?? 0, bottom?.image.size.width ?? 0)
          let width = max(labelWidth + side * 2, fontSize * 1.6)
          // The math axis, where `=` and `→` sit, a quarter em above the baseline.
          let axis = (fontSize * (display ? 1.2 : 1.1) * 0.25).rounded()
          let head = (fontSize * 0.3).rounded()
          strokes.append(.arrow(CGRect(x: x, y: axis - head / 2, width: width, height: head), left: left))
          if let top {
            let labelX = x + (width - top.image.size.width) / 2
            placed.append(Placed(image: top.image, bottom: axis + head / 2 + gap / 2, x: labelX))
          }
          if let bottom {
            let labelX = x + (width - bottom.image.size.width) / 2
            let labelBottom = axis - head / 2 - gap / 2 - bottom.image.size.height
            placed.append(Placed(image: bottom.image, bottom: labelBottom, x: labelX))
          }
          x += width
        }
      }
      return draw(placed, strokes: strokes, width: x, color: color)
    }

    /// The width of `latex` when it holds nothing but TeX spacing, else `nil`.
    /// Widths are in mu (1/18 em) the way TeX defines them.
    static func spacingWidth(_ latex: String, fontSize: CGFloat) -> CGFloat? {
      let spaces: [(String, CGFloat)] = [
        ("\\qquad", 36), ("\\quad", 18), ("\\;", 5), ("\\:", 4), ("\\>", 4),
        ("\\,", 3), ("\\!", -3), ("~", 6), ("\\ ", 6),
      ]
      var rest = latex
      var mu: CGFloat = 0
      while true {
        rest = String(rest.drop { $0 == " " || $0 == "\n" })
        if rest.isEmpty { break }
        guard let (command, width) = spaces.first(where: { rest.hasPrefix($0.0) }) else { return nil }
        rest.removeFirst(command.count)
        mu += width
      }
      return max(0, mu) * fontSize / 18
    }

    private static let operatorCommands = [
      "le", "leq", "ge", "geq", "ne", "neq", "approx", "sim", "simeq", "equiv", "propto",
      "cdot", "times", "pm", "mp", "to", "rightarrow", "leftarrow", "Rightarrow", "iff",
    ]

    static func endsWithOperator(_ latex: String) -> Bool {
      let text = latex.trimmingCharacters(in: .whitespaces)
      if let last = text.last, "=+-<>".contains(last) { return true }
      return operatorCommands.contains { text.hasSuffix("\\" + $0) }
    }

    static func startsWithOperator(_ latex: String) -> Bool {
      let text = latex.trimmingCharacters(in: .whitespaces)
      if let first = text.first, "=+-<>".contains(first) { return true }
      return operatorCommands.contains { name in
        text.hasPrefix("\\" + name) && !(text.dropFirst(name.count + 1).first?.isLetter ?? false)
      }
    }

    /// Coordinates are relative to the baseline; the image's descent is how
    /// far below it the lowest part reaches.
    private static func draw(_ placed: [Placed], strokes: [Stroke], width: CGFloat, color: NSColor)
      -> TypesetFormula
    {
      let rects = strokes.map { stroke -> CGRect in
        switch stroke {
        case .brace(let rect, _), .arrow(let rect, _): return rect
        }
      }
      let lowest = min(placed.map(\.bottom).min() ?? 0, rects.map(\.minY).min() ?? 0)
      let highest = max(
        placed.map { $0.bottom + $0.image.size.height }.max() ?? 0, rects.map(\.maxY).max() ?? 0)
      let image = NSImage(size: CGSize(width: ceil(width), height: ceil(highest - lowest)), flipped: false) { _ in
        for part in placed {
          part.image.draw(in: CGRect(
            x: part.x, y: part.bottom - lowest, width: part.image.size.width, height: part.image.size.height))
        }
        color.setStroke()
        for stroke in strokes {
          switch stroke {
          case .brace(let rect, let under):
            curlyBrace(in: rect.offsetBy(dx: 0, dy: -lowest), pointingDown: under).stroke()
          case .arrow(let rect, let left):
            arrow(in: rect.offsetBy(dx: 0, dy: -lowest), pointingLeft: left).stroke()
          }
        }
        return true
      }
      return TypesetFormula(image: image, descent: -lowest)
    }
  }
#endif
