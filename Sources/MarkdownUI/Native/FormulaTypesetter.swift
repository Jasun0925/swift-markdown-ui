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
  /// ones it has, then with non-Latin `\text{}` dropped (the math font has no
  /// CJK glyphs). When every attempt fails the caller keeps the source text.
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

    /// The source, then progressively softer rewrites of it.
    static func candidates(_ latex: String) -> [String] {
      let rewritten = rewrite(latex)
      let latinOnly = dropNonLatinText(rewritten)
      var seen = Set<String>()
      return [latex, rewritten, latinOnly].filter { seen.insert($0).inserted }
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

    /// `\text{...}` that is not plain Latin becomes empty: SwiftMath's math
    /// fonts have no CJK glyphs and fail the formula instead.
    static func dropNonLatinText(_ s: String) -> String {
      s.replacingOccurrences(
        of: "\\\\(text|mbox|textrm|mathrm)\\{[^{}]*[^\\x00-\\x7F][^{}]*\\}",
        with: "",
        options: .regularExpression
      )
    }

    private static func render(_ latex: String, display: Bool, fontSize: CGFloat, color: NSColor)
      -> TypesetFormula?
    {
      var math = MathImage(
        latex: latex,
        fontSize: display ? fontSize * 1.12 : fontSize,
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
