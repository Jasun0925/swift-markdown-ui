#if os(macOS)
  import AppKit

  /// Builds one attributed string for a whole answer, so a single text view
  /// can hold it and a selection can run from a heading through a list and a
  /// table. Tables are `NSTextTable` blocks: every cell in a row shares the
  /// row's height, and the cells stay in the selection.
  struct NativeMarkdownRenderer {
    let style: NativeMarkdownStyle

    func render(_ source: String) -> NSAttributedString {
      let (markdown, math) = MathExtraction.extract(source)
      let blocks = [BlockNode](markdown: markdown)
      let inline = NativeInlineRenderer(style: style, math: math)
      let out = NSMutableAttributedString()
      var context = Context(inline: inline)
      for block in blocks {
        append(block, context: &context, to: out)
      }
      // The last block's trailing newline would leave an empty line.
      if out.string.hasSuffix("\n") {
        out.deleteCharacters(in: NSRange(location: out.length - 1, length: 1))
      }
      return out
    }

    /// Nesting state while blocks are walked.
    struct Context {
      let inline: NativeInlineRenderer
      var indent: CGFloat = 0
      var quoteDepth = 0
      var tight = false
      var textBlocks: [NSTextBlock] = []
    }

    func paragraphStyle(_ context: Context, spacing: CGFloat? = nil) -> NSMutableParagraphStyle {
      let paragraph = NSMutableParagraphStyle()
      paragraph.firstLineHeadIndent = context.indent
      paragraph.headIndent = context.indent
      Self.setLineHeight(style.bodyLineHeight, fontSize: style.fontSize, on: paragraph)
      paragraph.paragraphSpacing = spacing ?? (context.tight ? style.tightSpacing : style.paragraphSpacing)
      paragraph.textBlocks = context.textBlocks
      return paragraph
    }

    /// Lines at least `height` tall. TextKit adds a taller minimum above the
    /// glyphs, so text set with this also needs `baselineOffset(for:)` to sit
    /// in the middle of the line, the way CSS line-height centers it. A line
    /// holding a tall formula still grows to fit it.
    static func setLineHeight(_ height: CGFloat, fontSize: CGFloat, on paragraph: NSMutableParagraphStyle) {
      paragraph.lineSpacing = 0
      paragraph.minimumLineHeight = height
    }

    func append(_ block: BlockNode, context: inout Context, to out: NSMutableAttributedString) {
      switch block {
      case .paragraph(let content):
        appendParagraph(context.inline.render(content, state: baseState(context)), context: context, to: out)
      case .heading(let level, let content):
        let metrics = style.heading(level)
        var state = baseState(context, size: metrics.size, lineHeight: metrics.lineHeight)
        state.weight = metrics.weight
        if level == 6 { state.color = style.secondaryColor }
        let paragraph = paragraphStyle(context, spacing: metrics.below)
        Self.setLineHeight(metrics.lineHeight, fontSize: metrics.size, on: paragraph)
        // The heading's own space above replaces the gap the block before
        // it left, so two gaps do not stack.
        paragraph.paragraphSpacingBefore = out.length > 0 ? max(0, metrics.above - style.paragraphSpacing) : 0
        appendLine(context.inline.render(content, state: state), paragraph: paragraph, to: out)
      case .blockquote(let children):
        // One text block around every paragraph of the quote: its left border
        // is the bar, drawn the full height of the quote.
        let quote = NSTextBlock()
        quote.setContentWidth(100, type: .percentageValueType)
        quote.setWidth(3, type: .absoluteValueType, for: .border, edge: .minX)
        quote.setBorderColor(style.quoteBarColor, for: .minX)
        quote.setWidth(14, type: .absoluteValueType, for: .padding, edge: .minX)
        quote.setWidth(context.indent, type: .absoluteValueType, for: .margin, edge: .minX)
        var inner = context
        inner.indent = 0
        inner.quoteDepth += 1
        inner.textBlocks = context.textBlocks + [quote]
        let start = out.length
        children.forEach { append($0, context: &inner, to: out) }
        // The quote's last paragraph keeps its gap outside the bar, so the bar
        // ends with the text.
        Self.moveTrailingSpacingOutside(out, from: start, spacing: style.paragraphSpacing, context: context)
      case .bulletedList(let isTight, let items):
        appendList(items.map { (nil, $0.children) }, tight: isTight, context: context, to: out) { _ in "•" }
      case .numberedList(let isTight, let start, let items):
        appendList(items.map { (nil, $0.children) }, tight: isTight, context: context, to: out) {
          "\(start + $0)."
        }
      case .taskList(let isTight, let items):
        appendList(items.map { ($0.isCompleted, $0.children) }, tight: isTight, context: context, to: out) {
          _ in ""
        }
      case .codeBlock(let fenceInfo, let content):
        appendCode(content, language: fenceInfo, context: context, to: out)
      case .htmlBlock(let content):
        // Raw HTML from a model is shown, never run.
        appendCode(content, language: nil, context: context, to: out)
      case .table(let alignments, let rows):
        appendTable(alignments: alignments, rows: rows, context: context, to: out)
      case .thematicBreak:
        appendRule(context: context, to: out)
      }
    }

    /// A paragraph. Each display formula in it becomes a centered paragraph
    /// of its own, with the text before and after it as plain paragraphs.
    func appendParagraph(_ text: NSMutableAttributedString, context: Context, to out: NSMutableAttributedString) {
      let full = NSRange(location: 0, length: text.length)
      var pieces: [(NSAttributedString, Bool)] = []
      // A bare formula paragraph has no text to center against.
      var cursor = 0
      text.enumerateAttribute(.markdownDisplayMath, in: full) { value, range, _ in
        guard value != nil else { return }
        if range.location > cursor {
          pieces.append((text.attributedSubstring(from: NSRange(location: cursor, length: range.location - cursor)), false))
        }
        pieces.append((text.attributedSubstring(from: range), true))
        cursor = NSMaxRange(range)
      }
      if cursor < text.length {
        pieces.append((text.attributedSubstring(from: NSRange(location: cursor, length: text.length - cursor)), false))
      }
      for (piece, isMath) in pieces {
        let trimmed = Self.trimmingBreaks(piece)
        guard trimmed.length > 0 else { continue }
        let paragraph = paragraphStyle(context)
        if isMath {
          // KaTeX's display block: centered, with the paragraph gap around it.
          paragraph.alignment = .center
          paragraph.paragraphSpacingBefore = 4
          paragraph.paragraphSpacing = style.paragraphSpacing + 4
        }
        appendLine(trimmed, paragraph: paragraph, to: out)
      }
    }

    /// A boxed run of paragraphs (a quote) would draw its box through the
    /// last paragraph's trailing gap. That gap is zeroed and the space added
    /// as an empty paragraph after the box instead.
    static func moveTrailingSpacingOutside(
      _ out: NSMutableAttributedString, from start: Int, spacing: CGFloat, context: Context
    ) {
      guard out.length > start else { return }
      let string = out.string as NSString
      let last = string.paragraphRange(for: NSRange(location: out.length - 1, length: 0))
      if let current = out.attribute(.paragraphStyle, at: last.location, effectiveRange: nil) as? NSParagraphStyle,
        let copy = current.mutableCopy() as? NSMutableParagraphStyle
      {
        copy.paragraphSpacing = 0
        out.addAttribute(.paragraphStyle, value: copy, range: last)
      }
      let gap = NSMutableParagraphStyle()
      gap.textBlocks = context.textBlocks
      gap.minimumLineHeight = spacing
      gap.maximumLineHeight = spacing
      out.append(
        NSAttributedString(
          string: "\n", attributes: [.paragraphStyle: gap, .font: NSFont.systemFont(ofSize: 2)]))
    }

    /// Drops spaces and line breaks at either end of a split paragraph.
    static func trimmingBreaks(_ piece: NSAttributedString) -> NSMutableAttributedString {
      let text = NSMutableAttributedString(attributedString: piece)
      let blank: (Character) -> Bool = { $0 == " " || $0 == "\u{2028}" || $0 == "\n" }
      while let first = text.string.first, blank(first) {
        text.deleteCharacters(in: NSRange(location: 0, length: (String(first) as NSString).length))
      }
      while let last = text.string.last, blank(last) {
        let length = (String(last) as NSString).length
        text.deleteCharacters(in: NSRange(location: text.length - length, length: length))
      }
      return text
    }

    func appendLine(
      _ line: NSMutableAttributedString,
      context: Context? = nil,
      paragraph: NSParagraphStyle? = nil,
      to out: NSMutableAttributedString
    ) {
      let paragraph = paragraph ?? context.map { paragraphStyle($0) } ?? NSParagraphStyle.default
      line.append(NSAttributedString(string: "\n"))
      line.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: line.length))
      out.append(line)
    }

    func baseState(_ context: Context, size: CGFloat? = nil, lineHeight: CGFloat? = nil) -> NativeInlineState {
      NativeInlineState(
        size: size ?? style.fontSize,
        lineHeight: lineHeight ?? style.bodyLineHeight,
        color: context.quoteDepth > 0 ? style.secondaryColor : style.textColor
      )
    }
  }
#endif
