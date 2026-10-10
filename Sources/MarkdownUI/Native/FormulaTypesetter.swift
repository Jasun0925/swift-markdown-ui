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
      for candidate in candidates(latex) {
        if let formula = render(candidate, display: display, fontSize: fontSize, color: color) {
          result = formula
          break
        }
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

    /// Commands SwiftMath lacks, mapped to ones it has. `\underbrace{x}_{y}`
    /// keeps `x` and its `_{y}` label as a subscript; the brace is lost.
    static func rewrite(_ latex: String) -> String {
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
      var s = latex
      for (name, replacement) in renames {
        s = replacingCommand(s, name, with: replacement)
      }
      // `\\[4pt]` is a row break with extra space; SwiftMath reads only `\\`.
      s = s.replacingOccurrences(
        of: "\\\\\\\\\\s*\\[[^\\]]*\\]", with: "\\\\\\\\", options: .regularExpression)
      return s
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
