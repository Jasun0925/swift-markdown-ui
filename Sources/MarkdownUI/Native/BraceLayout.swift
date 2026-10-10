#if os(macOS)
  import AppKit

  /// `\underbrace{term}_{label}` and `\overbrace{term}^{label}`, which
  /// SwiftMath cannot set.
  ///
  /// A formula with braces at its top level is cut into the parts between
  /// them and the braced terms. Each part is typeset alone, the parts are
  /// placed side by side on one baseline, and each brace is drawn as a curve
  /// under (or over) its term with the label set small beneath it — the way
  /// KaTeX lays them out. The term stays on the baseline, so the operators
  /// between the parts line up with the rest of the formula.
  enum BraceLayout {
    enum Piece: Equatable {
      case math(String)
      case brace(term: String, label: String?, under: Bool)
    }

    /// The parts of `latex`, or `nil` when it has no brace at its top level
    /// (outside every group, `\left…\right`, and environment).
    static func split(_ latex: String) -> [Piece]? {
      var pieces: [Piece] = []
      var text = ""
      var depth = 0
      var i = latex.startIndex
      var found = false
      while i < latex.endIndex {
        let c = latex[i]
        if c == "\\" {
          let name = commandName(in: latex, at: i)
          if depth == 0, name == "underbrace" || name == "overbrace",
            let parsed = parseBrace(in: latex, at: i, under: name == "underbrace")
          {
            if !text.trimmingCharacters(in: .whitespaces).isEmpty { pieces.append(.math(text)) }
            text = ""
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
      if !text.trimmingCharacters(in: .whitespaces).isEmpty { pieces.append(.math(text)) }
      return pieces
    }

    /// The letters of the command starting at the backslash at `index`, or
    /// the one symbol after it (`\{`, `\|`).
    private static func commandName(in s: String, at index: String.Index) -> String {
      var j = s.index(after: index)
      var name = ""
      while j < s.endIndex, s[j].isLetter {
        name.append(s[j])
        j = s.index(after: j)
      }
      if name.isEmpty, j < s.endIndex { return String(s[j]) }
      return name
    }

    private static func parseBrace(in s: String, at index: String.Index, under: Bool)
      -> (piece: Piece, end: String.Index)?
    {
      let afterName = s.index(index, offsetBy: 1 + (under ? "underbrace" : "overbrace").count)
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
