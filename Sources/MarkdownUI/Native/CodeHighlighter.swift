#if os(macOS)
  import AppKit

  /// Colors a fenced block by token class: comments, strings, numbers, and
  /// keywords. It is a scanner, not a parser, so it only claims what a lexer
  /// would agree on; anything else keeps the text color. An unknown language
  /// still gets strings, numbers, and `#` / `//` comments.
  struct CodeHighlighter {
    let style: NativeMarkdownStyle

    enum Token { case comment, string, number, keyword, type }

    func highlight(_ code: String, language: String) -> NSMutableAttributedString {
      let out = NSMutableAttributedString(
        string: code,
        attributes: [.font: style.font(monospaced: true), .foregroundColor: style.textColor])
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
