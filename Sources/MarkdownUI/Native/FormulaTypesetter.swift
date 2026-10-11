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
      // A frame adds nothing to a formula, so `\boxed{x}` is set as `x`.
      let latex = unboxed(latex)
      if let pieces = BraceLayout.split(latex) {
        // Top-level `\underbrace`, `\overbrace`, `\boxed`, `\xrightarrow`:
        // SwiftMath has none of them. Each part is typeset on its own and
        // laid out on one baseline, with the brace, frame, or arrow drawn.
        result = BraceLayout.compose(pieces, display: display, fontSize: fontSize, color: color) {
          render(candidates($0)[0], display: $1, fontSize: $2, color: color)
        }
      } else {
        result = render(candidates(latex)[0], display: display, fontSize: fontSize, color: color)
      }
      cache.setObject(Box(result), forKey: key)
      return result
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
        ("dots", "ldots"), ("dotsc", "ldots"), ("dotsb", "cdots"), ("dotsm", "cdots"),
        ("dotsi", "cdots"), ("dotso", "ldots"),
      ]
      for (name, replacement) in renames {
        s = replacingCommand(s, name, with: replacement)
      }
      s = scriptArrows(s)
      s = modulo(s)
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

    /// `latex` with every `\boxed{...}` and `\fbox{...}` replaced by its
    /// body. After `^` or `_` the body keeps its braces so it stays one
    /// script; elsewhere the braces go too, so an `\underbrace` inside is
    /// still at the top level and gets its brace drawn.
    static func unboxed(_ latex: String) -> String {
      var s = latex
      for command in ["\\boxed", "\\fbox"] {
        while let range = s.range(of: command),
          let group = bracedGroup(in: s, from: range.upperBound)
        {
          let before = s[..<range.lowerBound].last(where: { $0 != " " })
          let script = before == "^" || before == "_"
          s.replaceSubrange(range.lowerBound..<group.end, with: script ? "{\(group.body)}" : group.body)
        }
      }
      return s
    }

    /// `\bmod`, `\mod`, `\pmod{p}`, `\pod{p}`, which SwiftMath lacks, as
    /// TeX sets them: `a \bmod p` is "a mod p" with a medium space either
    /// side, `\mod p` a wider one, `\pmod p` "(mod p)" after a quad.
    static func modulo(_ latex: String) -> String {
      var s = latex.replacingOccurrences(
        of: "\\\\bmod(?![A-Za-z])", with: "\\\\;\\\\mathrm{mod}\\\\;", options: .regularExpression)
      for (command, open, close) in [("pmod", "\\quad(\\mathrm{mod}\\;", ")"), ("pod", "\\quad(", ")")] {
        var from = s.startIndex
        while let range = s.range(of: "\\" + command, range: from..<s.endIndex) {
          // `\pmodx` is another command; skip it.
          if let next = s[range.upperBound...].first, next.isLetter {
            from = range.upperBound
            continue
          }
          // The argument: a `{group}`, else the next token.
          var rest = s[range.upperBound...].drop { $0 == " " }
          var argument = ""
          if let group = bracedGroup(in: s, from: rest.startIndex) {
            argument = group.body
            rest = s[group.end...]
          } else if rest.first == "\\" {
            let name = rest.dropFirst().prefix { $0.isLetter }
            argument = "\\" + (name.isEmpty ? String(rest.dropFirst().prefix(1)) : String(name))
            rest = rest.dropFirst(argument.count)
          } else if let first = rest.first {
            argument = String(first)
            rest = rest.dropFirst()
          }
          let head = String(s[..<range.lowerBound]) + open + argument + close
          s = head + String(rest)
          from = s.index(s.startIndex, offsetBy: head.count)
        }
      }
      return s.replacingOccurrences(
        of: "\\\\mod(?![A-Za-z])", with: "\\\\quad\\\\mathrm{mod}\\\\;", options: .regularExpression)
    }

    /// `\xrightarrow[b]{a}` inside a group, where `BraceLayout` cannot draw
    /// it: a long arrow with the labels as scripts, so they are kept.
    static func scriptArrows(_ latex: String) -> String {
      var s = latex
      for (command, arrow) in [("xrightarrow", "longrightarrow"), ("xleftarrow", "longleftarrow")] {
        while let range = s.range(of: "\\" + command) {
          let parsed = BraceLayout.arrowArguments(in: s, from: range.upperBound)
          var replacement = "\\" + arrow
          if let over = parsed?.over { replacement += "^{\\scriptstyle " + over + "}" }
          if let under = parsed?.under { replacement += "_{\\scriptstyle " + under + "}" }
          s.replaceSubrange(range.lowerBound..<(parsed?.end ?? range.upperBound), with: replacement)
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
