#if os(macOS)
  import AppKit

  /// Constructs SwiftMath cannot set, laid out around it: `\underbrace`,
  /// `\overbrace`, `\xrightarrow` and `\xleftarrow`.
  ///
  /// A formula with one of these at its top level is cut into the parts
  /// between them and the constructs themselves. Each part is typeset alone,
  /// the parts are placed side by side on one baseline, and the brace or
  /// arrow is drawn around its part, the way KaTeX lays them out. The terms
  /// stay on the baseline, so the operators between the parts line up.
  enum BraceLayout {
    enum Piece: Equatable {
      case math(String)
      case brace(term: String, label: String?, under: Bool)
      case arrow(over: String?, under: String?, left: Bool)
    }

    private static let handled: Set<String> = [
      "underbrace", "overbrace", "xrightarrow", "xleftarrow",
    ]

    /// The parts of `latex`, or `nil` when it has none of these constructs at
    /// its top level (outside every group, `\left…\right`, and environment).
    static func split(_ latex: String) -> [Piece]? {
      var pieces: [Piece] = []
      var text = ""
      var depth = 0
      var i = latex.startIndex
      var found = false
      func flush() {
        if !text.trimmingCharacters(in: .whitespaces).isEmpty { pieces.append(.math(text)) }
        text = ""
      }
      while i < latex.endIndex {
        let c = latex[i]
        if c == "\\" {
          let name = commandName(in: latex, at: i)
          if depth == 0, handled.contains(name), let parsed = parse(name, in: latex, at: i) {
            flush()
            pieces.append(parsed.piece)
            i = parsed.end
            found = true
            continue
          }
          switch name {
          case "left", "begin": depth += 1
          case "right", "end": depth -= 1
          default: break
          }
          let end = latex.index(i, offsetBy: 1 + max(name.count, 1), limitedBy: latex.endIndex) ?? latex.endIndex
          text += latex[i..<end]
          i = end
          continue
        }
        if c == "{" { depth += 1 }
        if c == "}" { depth -= 1 }
        text.append(c)
        i = latex.index(after: i)
      }
      guard found else { return nil }
      flush()
      return pieces
    }

    /// The letters of the command starting at the backslash at `index`, or
    /// the one symbol after it (`\{`, `\|`).
    static func commandName(in s: String, at index: String.Index) -> String {
      var j = s.index(after: index)
      var name = ""
      while j < s.endIndex, s[j].isLetter {
        name.append(s[j])
        j = s.index(after: j)
      }
      if name.isEmpty, j < s.endIndex { return String(s[j]) }
      return name
    }

    private static func parse(_ name: String, in s: String, at index: String.Index)
      -> (piece: Piece, end: String.Index)?
    {
      let afterName = s.index(index, offsetBy: 1 + name.count)
      switch name {
      case "xrightarrow", "xleftarrow":
        guard let arrow = arrowArguments(in: s, from: afterName) else { return nil }
        return (.arrow(over: arrow.over, under: arrow.under, left: name == "xleftarrow"), arrow.end)
      default:
        return parseBrace(in: s, from: afterName, under: name == "underbrace")
      }
    }

    /// `[below]{above}` after `\xrightarrow`. Empty labels are `nil`.
    static func arrowArguments(in s: String, from index: String.Index)
      -> (over: String?, under: String?, end: String.Index)?
    {
      var i = index
      while i < s.endIndex, s[i] == " " { i = s.index(after: i) }
      var under: String?
      if i < s.endIndex, s[i] == "[" {
        guard let close = s[i...].firstIndex(of: "]") else { return nil }
        under = String(s[s.index(after: i)..<close])
        i = s.index(after: close)
      }
      guard let over = FormulaTypesetter.bracedGroup(in: s, from: i) else { return nil }
      func label(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return text
      }
      return (label(over.body), label(under), over.end)
    }

    private static func parseBrace(in s: String, from afterName: String.Index, under: Bool)
      -> (piece: Piece, end: String.Index)?
    {
      guard let term = FormulaTypesetter.bracedGroup(in: s, from: afterName) else { return nil }
      var rest = term.end
      while rest < s.endIndex, s[rest] == " " { rest = s.index(after: rest) }
      var label: String?
      if rest < s.endIndex, s[rest] == (under ? "_" : "^") {
        let afterMark = s.index(after: rest)
        if let group = FormulaTypesetter.bracedGroup(in: s, from: afterMark) {
          label = group.body
          rest = group.end
        } else if afterMark < s.endIndex {
          label = String(s[afterMark])
          rest = s.index(after: afterMark)
        }
      } else {
        rest = term.end
      }
      return (.brace(term: term.body, label: label, under: under), rest)
    }
  }
#endif
