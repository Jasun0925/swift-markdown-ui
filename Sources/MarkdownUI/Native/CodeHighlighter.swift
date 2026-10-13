#if os(macOS)
  import AppKit

  /// Colors a fenced block by token class: comments, strings, numbers, and
  /// keywords. It is a scanner, not a parser, so it only claims what a lexer
  /// would agree on; anything else keeps the text color. A named language it
  /// does not know still gets strings, numbers, and `#` / `//` comments; a
  /// block with no language stays plain.
  struct CodeHighlighter {
    let style: NativeMarkdownStyle

    enum Token { case comment, string, number, keyword, type }

    func highlight(_ code: String, language: String) -> NSMutableAttributedString {
      let out = NSMutableAttributedString(
        string: code,
        attributes: [.font: style.font(monospaced: true), .foregroundColor: style.textColor])
      // A block with no language may not be code at all (output, a formula
      // written as text), so it is not colored as if it were.
      guard !language.isEmpty else { return out }
      // A diff is colored by the line, not by the language inside it. A
      // keyword scan would paint the Python on a `+` line and hide that the
      // whole line was added.
      if Self.diffLanguages.contains(language.lowercased()) {
        colorDiffLines(in: out, code: code)
        return out
      }
      let grammar = Grammar.named(language.lowercased())
      let ns = code as NSString
      var claimed = IndexSet()
      // Earlier passes win: a keyword inside a string or a comment stays
      // the string's or the comment's color.
      for (token, regex) in grammar.passes {
        regex.enumerateMatches(in: code, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
          guard let range = match?.range, range.length > 0 else { return }
          let span = range.location..<NSMaxRange(range)
          guard !claimed.intersects(integersIn: span) else { return }
          claimed.insert(integersIn: span)
          out.addAttribute(.foregroundColor, value: color(token), range: range)
        }
      }
      return out
    }

    private static let diffLanguages: Set<String> = ["diff", "patch", "udiff"]

    /// Colors one unified diff. `+` and `-` lines take the addition and
    /// deletion colors; `+++` and `---` name the files and stay plain, as
    /// does a context line with no marker.
    private func colorDiffLines(in out: NSMutableAttributedString, code: String) {
      let ns = code as NSString
      var start = 0
      while start < ns.length {
        let line = ns.lineRange(for: NSRange(location: start, length: 0))
        let next = NSMaxRange(line)
        if next <= start { break }
        let raw = ns.substring(with: line)
        let content = raw.hasSuffix("\n") ? String(raw.dropLast()) : raw
        let text = content.hasSuffix("\r") ? String(content.dropLast()) : content
        let range = NSRange(location: line.location, length: (text as NSString).length)
        if text.hasPrefix("@@") {
          out.addAttribute(.foregroundColor, value: style.secondaryColor, range: range)
        } else if text.hasPrefix("+"), !text.hasPrefix("+++") {
          out.addAttribute(.foregroundColor, value: style.diffAddedColor, range: range)
          out.addAttribute(.backgroundColor, value: style.diffAddedBackground, range: range)
        } else if text.hasPrefix("-"), !text.hasPrefix("---") {
          out.addAttribute(.foregroundColor, value: style.diffRemovedColor, range: range)
          out.addAttribute(.backgroundColor, value: style.diffRemovedBackground, range: range)
        }
        start = next
      }
    }

    private func color(_ token: Token) -> NSColor {
      switch token {
      case .comment: return style.codeColors.comment
      case .string: return style.codeColors.string
      case .number: return style.codeColors.number
      case .keyword: return style.codeColors.keyword
      case .type: return style.codeColors.type
      }
    }
  }
#endif
