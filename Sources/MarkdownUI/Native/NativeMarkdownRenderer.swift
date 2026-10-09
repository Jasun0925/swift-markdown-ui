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
      paragraph.lineSpacing = style.lineSpacing
      paragraph.paragraphSpacing = spacing ?? (context.tight ? style.tightSpacing : style.paragraphSpacing)
      paragraph.textBlocks = context.textBlocks
      return paragraph
    }

    func append(_ block: BlockNode, context: inout Context, to out: NSMutableAttributedString) {
      switch block {
      case .paragraph(let content):
        appendLine(context.inline.render(content, state: baseState(context)), context: context, to: out)
      case .heading(let level, let content):
        let scale: [CGFloat] = [1.45, 1.28, 1.14, 1.04, 1.0, 0.95]
        var state = baseState(context, size: style.fontSize * scale[min(max(level, 1), 6) - 1])
        state.bold = true
        if level == 6 { state.color = style.secondaryColor }
        let paragraph = paragraphStyle(context, spacing: (style.fontSize * 0.4).rounded())
        paragraph.paragraphSpacingBefore = out.length > 0 ? (style.fontSize * 0.7).rounded() : 0
        appendLine(context.inline.render(content, state: state), paragraph: paragraph, to: out)
      case .blockquote(let children):
        var inner = context
        inner.indent += style.fontSize
        inner.quoteDepth += 1
        children.forEach { append($0, context: &inner, to: out) }
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

    func baseState(_ context: Context, size: CGFloat? = nil) -> NativeInlineState {
      NativeInlineState(
        size: size ?? style.fontSize,
        color: context.quoteDepth > 0 ? style.secondaryColor : style.textColor
      )
    }
  }
#endif
