#if os(macOS)
  import AppKit

  extension NativeMarkdownRenderer {
    /// A list. The marker sits in the indent, before a tab stop, so wrapped
    /// lines line up with the text instead of under the marker.
    func appendList(
      _ items: [(checked: Bool?, children: [BlockNode])],
      tight: Bool,
      context: Context,
      to out: NSMutableAttributedString,
      marker: (Int) -> String
    ) {
      let width = (style.fontSize * 1.6).rounded()
      for (index, item) in items.enumerated() {
        var inner = context
        inner.indent += width
        inner.tight = tight
        let label: String
        if let checked = item.checked {
          label = checked ? "☑" : "☐"
        } else {
          label = marker(index)
        }
        let start = out.length
        for child in item.children {
          append(child, context: &inner, to: out)
        }
        // The first line of the item's first block carries the marker.
        let markerText = NSMutableAttributedString(
          string: label + "\t",
          attributes: [
            .font: style.font(),
            .foregroundColor: style.secondaryColor,
          ])
        if start == out.length {
          appendLine(markerText, context: inner, to: out)
        } else {
          out.insert(markerText, at: start)
        }
        let paragraph = paragraphStyle(inner)
        paragraph.firstLineHeadIndent = context.indent
        paragraph.tabStops = [NSTextTab(textAlignment: .left, location: inner.indent)]
        paragraph.defaultTabInterval = width
        let firstLine = (out.string as NSString).paragraphRange(for: NSRange(location: start, length: 0))
        out.addAttribute(.paragraphStyle, value: paragraph, range: firstLine)
      }
      // The list as a whole gets normal space after it.
      if tight, out.length > 0 {
        let last = (out.string as NSString).paragraphRange(for: NSRange(location: out.length - 1, length: 0))
        if let current = out.attribute(.paragraphStyle, at: last.location, effectiveRange: nil)
          as? NSParagraphStyle, let copy = current.mutableCopy() as? NSMutableParagraphStyle
        {
          copy.paragraphSpacing = style.paragraphSpacing
          out.addAttribute(.paragraphStyle, value: copy, range: last)
        }
      }
    }

    /// A fenced block in a tinted box, in the code font. The box is a text
    /// block, so the code is selectable with the prose around it.
    func appendCode(_ content: String, language: String?, context: Context, to out: NSMutableAttributedString) {
      let box = NSTextBlock()
      box.backgroundColor = style.codeBackground
      box.setContentWidth(100, type: .percentageValueType)
      box.setWidth(10, type: .absoluteValueType, for: .padding)
      box.setWidth(context.indent, type: .absoluteValueType, for: .margin, edge: .minX)
      var inner = context
      inner.indent = 0
      inner.textBlocks = context.textBlocks + [box]
      let paragraph = paragraphStyle(inner, spacing: 0)
      paragraph.lineSpacing = 2
      var code = content
      if code.hasSuffix("\n") { code.removeLast() }
      if let language = language?.split(separator: " ").first, !language.isEmpty {
        let label = NSMutableAttributedString(
          string: String(language) + "\n",
          attributes: [.font: style.font(size: style.fontSize * 0.8), .foregroundColor: style.secondaryColor])
        label.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: label.length))
        out.append(label)
      }
      let body = NSMutableAttributedString(
        string: code + "\n",
        attributes: [.font: style.font(monospaced: true), .foregroundColor: style.textColor])
      body.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: body.length))
      out.append(body)
      appendSpacer(context: context, to: out)
    }

    /// A hairline across the column.
    func appendRule(context: Context, to out: NSMutableAttributedString) {
      let rule = NSTextBlock()
      rule.setContentWidth(100, type: .percentageValueType)
      rule.setWidth(0.5, type: .absoluteValueType, for: .border, edge: .maxY)
      rule.setBorderColor(style.separatorColor, for: .maxY)
      var inner = context
      inner.textBlocks = context.textBlocks + [rule]
      let paragraph = paragraphStyle(inner, spacing: 0)
      paragraph.maximumLineHeight = 1
      let line = NSMutableAttributedString(string: "\u{200B}", attributes: [.font: style.font(size: 1)])
      appendLine(line, paragraph: paragraph, to: out)
      appendSpacer(context: context, to: out)
    }

    /// An empty line that only adds the paragraph gap after a boxed block.
    func appendSpacer(context: Context, to out: NSMutableAttributedString) {
      let paragraph = paragraphStyle(context, spacing: 0)
      paragraph.maximumLineHeight = style.paragraphSpacing
      paragraph.minimumLineHeight = style.paragraphSpacing
      let gap = NSMutableAttributedString(string: "", attributes: [.font: style.font(size: 2)])
      appendLine(gap, paragraph: paragraph, to: out)
    }
  }
#endif
