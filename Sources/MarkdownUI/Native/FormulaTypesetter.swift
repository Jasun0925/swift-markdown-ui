#if os(macOS)
  import AppKit
  import SwiftMath

  /// A typeset formula: the image and the depth below the text baseline.
  struct TypesetFormula {
    let image: NSImage
    let descent: CGFloat
  }

  /// Turns TeX into an image through SwiftMath.
  ///
  /// SwiftMath fails a whole formula on one command it does not know. The
  /// source is tried as written, then with the commands it lacks rewritten to
  /// ones it has. Chinese and other non-ASCII text is drawn through text atoms
  /// (`TextAtoms`). When every attempt fails the caller keeps the source text.
  enum FormulaTypesetter {
    private static let cache = NSCache<NSString, Box>()

    private final class Box {
      let value: TypesetFormula?
      init(_ value: TypesetFormula?) { self.value = value }
    }

    static func typeset(_ latex: String, display: Bool, fontSize: CGFloat, color: NSColor)
      -> TypesetFormula?
    {
      let key = "\(display)|\(fontSize)|\(color.description)|\(latex)" as NSString
      if let hit = cache.object(forKey: key) { return hit.value }
      var result: TypesetFormula?
      // `\boxed{...}` around the whole formula: SwiftMath has no box, so the
      // inside is typeset and the frame is drawn around its image.
      let (inside, boxed) = unwrapBoxed(latex)
      if let pieces = BraceLayout.split(inside) {
        // Top-level `\underbrace` / `\overbrace`: each part is typeset on
        // its own and laid out on one baseline, with the brace and its label
        // drawn under (or over) the term.
        result = BraceLayout.compose(pieces, display: display, fontSize: fontSize, color: color) {
          render(candidates($0)[0], display: $1, fontSize: $2, color: color)
        }
      } else {
        for candidate in candidates(inside) {
          if let formula = render(candidate, display: display, fontSize: fontSize, color: color) {
            result = formula
            break
          }
        }
      }
      if boxed, let inner = result {
        result = framed(inner, color: color, fontSize: fontSize)
      }
      cache.setObject(Box(result), forKey: key)
      return result
    }

    /// The body of `\boxed{...}` (or `\fbox{...}`) when it is the whole
    /// formula, and whether it was boxed.
    static func unwrapBoxed(_ latex: String) -> (String, Bool) {
      let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
      for command in ["\\boxed", "\\fbox"] where trimmed.hasPrefix(command) {
        let after = trimmed.index(trimmed.startIndex, offsetBy: command.count)
        if let group = bracedGroup(in: trimmed, from: after),
          trimmed[group.end...].trimmingCharacters(in: .whitespaces).isEmpty
        {
          return (group.body, true)
        }
      }
      return (latex, false)
    }

    /// `formula` inside a thin rectangle with padding, the way `\boxed` sets.
    private static func framed(_ formula: TypesetFormula, color: NSColor, fontSize: CGFloat) -> TypesetFormula {
      let pad = (fontSize * 0.3).rounded()
      let inner = formula.image.size
      let size = CGSize(width: inner.width + pad * 2, height: inner.height + pad * 2)
      let image = NSImage(size: size, flipped: false) { bounds in
        formula.image.draw(in: CGRect(x: pad, y: pad, width: inner.width, height: inner.height))
        color.setStroke()
        let frame = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        frame.lineWidth = 0.8
        frame.stroke()
        return true
      }
      return TypesetFormula(image: image, descent: formula.descent + pad)
    }

    /// What SwiftMath is given: the source with non-ASCII runs turned into
    /// text atoms and its unsupported syntax rewritten.
    ///
    /// The rewrite is not a fallback. SwiftMath does not fail on everything
    /// it misreads: `\\[4pt]` typesets "[4pt]" as text with no error, so a
    /// source that "worked" can still be wrong. Nothing the model wrote is
    /// dropped: a formula that still fails is shown as its source.
    static func candidates(_ latex: String) -> [String] {
      [TextAtoms.substitute(rewrite(latex))]
    }

    /// Commands SwiftMath lacks, mapped to ones it has.
    static func rewrite(_ latex: String) -> String {
      var s = stackBraceLabels(latex)
      let renames: [(String, String)] = [
        ("underbrace", ""), ("overbrace", ""),
        ("tfrac", "frac"), ("dfrac", "frac"),
        ("bigl", ""), ("bigr", ""), ("Bigl", ""), ("Bigr", ""),
        ("biggl", ""), ("biggr", ""), ("Biggl", ""), ("Biggr", ""),
        ("big", ""), ("Big", ""), ("bigg", ""), ("Bigg", ""),
        ("lVert", "|"), ("rVert", "|"), ("lvert", "|"), ("rvert", "|"),
        ("boldsymbol", "mathbf"), ("bm", "mathbf"),
        ("operatorname*", "mathrm"), ("operatorname", "mathrm"),
        ("limits", ""), ("nolimits", ""), (":", ">"),
      ]
      for (name, replacement) in renames {
        s = replacingCommand(s, name, with: replacement)
      }
      // `\\[4pt]` is a row break with extra space; SwiftMath reads only `\\`.
      s = s.replacingOccurrences(
        of: "\\\\\\\\\\s*\\[[^\\]]*\\]", with: "\\\\\\\\", options: .regularExpression)
      return s
    }

    /// A brace nested inside a group, which `BraceLayout` cannot split out:
    /// `\underbrace{x}_{y}` becomes a one-column stack with the label set
    /// small under the term, and `\overbrace{x}^{y}` the same with it above.
    /// The stack is centered on the math axis, so it sits a little high, but
    /// the label is kept. A brace with no label keeps the term.
    static func stackBraceLabels(_ latex: String) -> String {
      var s = latex
      for (command, mark, under) in [("underbrace", "_", true), ("overbrace", "^", false)] {
        while let range = s.range(of: "\\" + command) {
          guard let term = bracedGroup(in: s, from: range.upperBound) else { break }
          var rest = term.end
          while rest < s.endIndex, s[rest] == " " { rest = s.index(after: rest) }
          var label: String?
          if rest < s.endIndex, String(s[rest]) == mark {
            let afterMark = s.index(after: rest)
            if let group = bracedGroup(in: s, from: afterMark) {
              label = group.body
              rest = group.end
            } else if afterMark < s.endIndex {
              label = String(s[afterMark])
              rest = s.index(after: afterMark)
            }
          } else {
            rest = term.end
          }
          let replacement: String
          if let label {
            let small = "\\scriptstyle " + label
            replacement = under
              ? "\\begin{matrix} \(term.body) \\\\ \(small) \\end{matrix}"
              : "\\begin{matrix} \(small) \\\\ \(term.body) \\end{matrix}"
          } else {
            replacement = "{" + term.body + "}"
          }
          s.replaceSubrange(range.lowerBound..<rest, with: replacement)
        }
      }
      return s
    }

    /// The `{...}` group starting at `index` (after spaces), with nested
    /// braces matched.
    static func bracedGroup(in s: String, from index: String.Index) -> (body: String, end: String.Index)? {
      var i = index
      while i < s.endIndex, s[i] == " " { i = s.index(after: i) }
      guard i < s.endIndex, s[i] == "{" else { return nil }
      var depth = 0
      var j = i
      while j < s.endIndex {
        let c = s[j]
        if c == "\\" {
          j = s.index(after: j)
          if j < s.endIndex { j = s.index(after: j) }
          continue
        }
        if c == "{" { depth += 1 }
        if c == "}" {
          depth -= 1
          if depth == 0 {
            return (String(s[s.index(after: i)..<j]), s.index(after: j))
          }
        }
        j = s.index(after: j)
      }
      return nil
    }

    /// Replaces `\name` only where the command name ends, so `\big` does not
    /// eat the start of `\bigcup`. An empty replacement drops the command.
    static func replacingCommand(_ s: String, _ name: String, with replacement: String) -> String {
      let pattern = "\\\\" + NSRegularExpression.escapedPattern(for: name)
        + (name.last?.isLetter == true ? "(?![A-Za-z])" : "")
      let template = replacement.isEmpty
        ? "" : "\\\\" + NSRegularExpression.escapedTemplate(for: replacement)
      return s.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
    }


    private static func render(_ latex: String, display: Bool, fontSize: CGFloat, color: NSColor)
      -> TypesetFormula?
    {
      // Latin Modern's x-height is smaller than the system font's, so a
      // formula at the text's point size reads a size too small beside it.
      var math = MathImage(
        latex: latex,
        fontSize: fontSize * (display ? 1.2 : 1.1),
        textColor: color,
        labelMode: display ? .display : .text,
        textAlignment: .left
      )
      let (error, image, layout) = math.asImage()
      guard error == nil, let image, let layout, image.size.width > 0 else { return nil }
      return TypesetFormula(image: image, descent: layout.descent)
    }
  }
#endif
