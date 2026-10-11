#if os(macOS)
  import AppKit

  /// The running style while inlines are walked.
  struct NativeInlineState {
    var size: CGFloat
    /// The line height the paragraph sets, so the text can be raised to the
    /// middle of it. `nil` leaves the text on the natural baseline.
    var lineHeight: CGFloat? = nil
    /// An explicit weight; `nil` follows `bold`.
    var weight: NSFont.Weight? = nil
    var bold = false
    var italic = false
    var monospaced = false
    var strikethrough = false
    var color: NSColor
    var link: URL?
  }

  /// Renders cmark inlines into AppKit attributed text. Formula tokens left by
  /// `MathExtraction` become image attachments that sit on the baseline.
  struct NativeInlineRenderer {
    let style: NativeMarkdownStyle
    let math: [ExtractedMath]

    func render(_ inlines: [InlineNode], state: NativeInlineState) -> NSMutableAttributedString {
      let out = NSMutableAttributedString()
      for inline in StrongRepair.repair(inlines) {
        append(inline, state: state, to: out)
      }
      return out
    }

    private func append(_ inline: InlineNode, state: NativeInlineState, to out: NSMutableAttributedString) {
      var state = state
      switch inline {
      case .text(let text):
        appendText(text, state: state, to: out)
      case .softBreak:
        out.append(NSAttributedString(string: " ", attributes: attributes(state)))
      case .lineBreak:
        out.append(NSAttributedString(string: "\u{2028}", attributes: attributes(state)))
      case .code(let code):
        // A chip: 0.875em of the code font on a tint the size of the glyphs.
        // The tint is drawn by the text view (`markdownInlineCode`), not as a
        // background color, which fills the whole line height and made the
        // chip taller than the text around it.
        let font = NSFont.monospacedSystemFont(ofSize: state.size * 0.875, weight: .regular)
        var attrs = attributes(state)
        attrs[.font] = font
        attrs[.markdownInlineCode] = true
        if let lineHeight = state.lineHeight {
          attrs[.baselineOffset] = NativeMarkdownStyle.baselineOffset(
            for: style.font(size: state.size), lineHeight: lineHeight)
        }
        // Thin spaces give the chip room on both sides. Each carries an
        // empty source, so a copy writes the code alone.
        var pad = attrs
        func padding() -> NSAttributedString {
          pad[.markdownSource] = MarkdownSource("")
          return NSAttributedString(string: "\u{2009}", attributes: pad)
        }
        out.append(padding())
        out.append(NSAttributedString(string: code, attributes: attrs))
        out.append(padding())
      case .html(let html):
        let isBreak = HTMLTag(html)?.name.lowercased() == "br"
        out.append(NSAttributedString(string: isBreak ? "\u{2028}" : html, attributes: attributes(state)))
      case .emphasis(let children):
        state.italic = true
        children.forEach { append($0, state: state, to: out) }
      case .strong(let children):
        state.bold = true
        children.forEach { append($0, state: state, to: out) }
      case .strikethrough(let children):
        state.strikethrough = true
        children.forEach { append($0, state: state, to: out) }
      case .link(let destination, let children):
        state.link = Self.safeURL(destination)
        if state.link != nil { state.color = style.linkColor }
        children.forEach { append($0, state: state, to: out) }
      case .image(let source, let children):
        let alt = children.renderPlainText()
        if appendLocalImage(source, alt: alt, state: state, to: out) { break }
        // A web image, or a local one that cannot be shown: the alt text,
        // linked to the picture when it is on the web.
        state.link = Self.safeURL(source)
        if state.link != nil { state.color = style.linkColor }
        appendText(alt.isEmpty ? source : alt, state: state, to: out)
      }
    }

    /// Plain text, with each formula token swapped for its formula.
    private func appendText(_ text: String, state: NativeInlineState, to out: NSMutableAttributedString) {
      var rest = Substring(text)
      while let open = rest.firstIndex(of: MathExtraction.open) {
        out.append(NSAttributedString(string: String(rest[..<open]), attributes: attributes(state)))
        let afterOpen = rest.index(after: open)
        guard let close = rest[afterOpen...].firstIndex(of: MathExtraction.close),
          let index = Int(rest[afterOpen..<close]), math.indices.contains(index)
        else {
          rest = rest[afterOpen...]
          continue
        }
        appendFormula(math[index], state: state, to: out)
        rest = rest[rest.index(after: close)...]
      }
      out.append(NSAttributedString(string: String(rest), attributes: attributes(state)))
    }
  }

  extension NativeInlineRenderer {
    func attributes(_ state: NativeInlineState) -> [NSAttributedString.Key: Any] {
      let font = style.font(
        size: state.size, weight: state.weight ?? (state.bold ? .semibold : .regular),
        italic: state.italic, monospaced: state.monospaced)
      var attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: state.color,
      ]
      if let lineHeight = state.lineHeight {
        attrs[.baselineOffset] = NativeMarkdownStyle.baselineOffset(for: font, lineHeight: lineHeight)
      }
      if state.strikethrough {
        attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
      }
      if let link = state.link {
        attrs[.link] = link
      }
      return attrs
    }

    /// A formula as an image attachment, lowered by its descent so its
    /// baseline meets the text's. A formula that will not typeset stays as
    /// its source, in the code font, so nothing the model wrote is lost.
    func appendFormula(_ formula: ExtractedMath, state: NativeInlineState, to out: NSMutableAttributedString) {
      guard
        let typeset = FormulaTypesetter.typeset(
          formula.latex, display: formula.display, fontSize: state.size, color: style.mathColor)
      else {
        var fallback = state
        fallback.monospaced = true
        out.append(NSAttributedString(string: formula.source, attributes: attributes(fallback)))
        return
      }
      let attachment = NSTextAttachment()
      attachment.image = typeset.image
      // Inline math rides the text's raised baseline. A display formula is
      // its own line, which grows to the formula's height.
      let raise: CGFloat
      if !formula.display, let lineHeight = state.lineHeight {
        raise = NativeMarkdownStyle.baselineOffset(for: style.font(size: state.size), lineHeight: lineHeight)
      } else {
        raise = 0
      }
      attachment.bounds = CGRect(
        x: 0, y: raise - typeset.descent, width: typeset.image.size.width, height: typeset.image.size.height)
      let piece = NSMutableAttributedString(attachment: attachment)
      var attrs = attributes(state)
      // The raise is in the attachment's bounds; a baseline offset on top
      // would lift it twice.
      attrs[.baselineOffset] = nil
      attrs[.markdownSource] = MarkdownSource(formula.source)
      piece.addAttributes(attrs, range: NSRange(location: 0, length: piece.length))
      if formula.display {
        // The block renderer gives a marked display formula a paragraph of
        // its own, with space above and below.
        piece.addAttribute(.markdownDisplayMath, value: true, range: NSRange(location: 0, length: piece.length))
      }
      out.append(piece)
    }

    /// A picture from `style.imageDirectory`, set on the line at its own size
    /// (no wider than the column). Copy writes `![alt](source)`. Returns
    /// `false` when there is no folder, or the file is outside it, missing,
    /// too large, or not an image.
    func appendLocalImage(_ source: String, alt: String, state: NativeInlineState, to out: NSMutableAttributedString) -> Bool {
      guard let directory = style.imageDirectory,
        let file = LocalImages.file(for: source, in: directory),
        let image = LocalImages.image(at: file)
      else { return false }
      let attachment = NSTextAttachment()
      attachment.image = image
      let size = LocalImages.displaySize(of: image, maxWidth: NativeMarkdownStyle.readableWidth)
      attachment.bounds = CGRect(origin: .zero, size: size)
      let piece = NSMutableAttributedString(attachment: attachment)
      var attrs = attributes(state)
      attrs[.baselineOffset] = nil
      attrs[.markdownSource] = MarkdownSource("![\(alt)](\(source))")
      if !alt.isEmpty { attrs[.toolTip] = alt }
      piece.addAttributes(attrs, range: NSRange(location: 0, length: piece.length))
      // A picture wider than a few words gets its own line; a small icon
      // stays inline with the text.
      if size.width > 120 || size.height > state.size * 3 {
        piece.addAttribute(.markdownDisplayMath, value: true, range: NSRange(location: 0, length: piece.length))
      }
      out.append(piece)
      return true
    }

    /// Only web and mail links become clickable; `javascript:` and file
    /// links stay text.
    static func safeURL(_ destination: String) -> URL? {
      guard let url = URL(string: destination), let scheme = url.scheme?.lowercased(),
        ["http", "https", "mailto"].contains(scheme)
      else { return nil }
      return url
    }
  }
#endif
