#if os(macOS)
  import AppKit

  extension NativeMarkdownRenderer {
    /// A GFM table as an `NSTextTable`. Each cell is one paragraph in its own
    /// table block; the layout gives every cell in a row the row's height, so
    /// a short cell beside a long one stays on its row.
    func appendTable(
      alignments: [RawTableColumnAlignment],
      rows: [RawTableRow],
      context: Context,
      to out: NSMutableAttributedString
    ) {
      let columns = max(alignments.count, rows.map(\.cells.count).max() ?? 0)
      guard columns > 0 else { return }
      let table = NSTextTable()
      table.numberOfColumns = columns
      table.layoutAlgorithm = .automaticLayoutAlgorithm
      table.collapsesBorders = true
      table.hidesEmptyCells = false
      table.setContentWidth(100, type: .percentageValueType)
      table.setWidth(context.indent, type: .absoluteValueType, for: .margin, edge: .minX)

      // Each cell is rendered once: its text is both what is measured for the
      // column widths and what is appended below.
      let rendered: [[NSMutableAttributedString]] = rows.enumerated().map { rowIndex, row in
        (0..<columns).map { column in
          var state = baseState(context, size: style.tableFontSize, lineHeight: style.tableLineHeight)
          state.weight = rowIndex == 0 ? .medium : nil
          let content = column < row.cells.count ? row.cells[column].content : []
          let text = context.inline.render(content, state: state)
          if text.length == 0 {
            // An empty cell still needs a character to hold its block.
            text.append(NSAttributedString(string: "\u{200B}", attributes: context.inline.attributes(state)))
          }
          return text
        }
      }
      let widths = Self.columnWidths(cells: rendered, columns: columns)
      table.layoutAlgorithm = .fixedLayoutAlgorithm
      for (rowIndex, _) in rows.enumerated() {
        let isHeader = rowIndex == 0
        for column in 0..<columns {
          let cell = NSTextTableBlock(
            table: table, startingRow: rowIndex, rowSpan: 1, startingColumn: column, columnSpan: 1)
          cell.setContentWidth(widths[column], type: .percentageValueType)
          // DSH: 10px 16px cells, the first and last column flush with the
          // text, a hairline under each row and a darker one under the head.
          cell.setWidth(10, type: .absoluteValueType, for: .padding, edge: .minY)
          cell.setWidth(10, type: .absoluteValueType, for: .padding, edge: .maxY)
          cell.setWidth(column == 0 ? 0 : 16, type: .absoluteValueType, for: .padding, edge: .minX)
          cell.setWidth(column == columns - 1 ? 0 : 16, type: .absoluteValueType, for: .padding, edge: .maxX)
          let isLast = rowIndex == rows.count - 1
          cell.setWidth(isLast && !isHeader ? 0 : 0.5, type: .absoluteValueType, for: .border, edge: .maxY)
          cell.setBorderColor(isHeader ? style.tableHeaderRule : style.tableRowRule, for: .maxY)
          cell.verticalAlignment = .middleAlignment

          var inner = context
          inner.indent = 0
          inner.textBlocks = context.textBlocks + [cell]
          let paragraph = paragraphStyle(inner, spacing: 0)
          Self.setLineHeight(style.tableLineHeight, fontSize: style.tableFontSize, on: paragraph)
          let alignment = column < alignments.count ? alignments[column] : .none
          switch alignment {
          case .center: paragraph.alignment = .center
          case .right: paragraph.alignment = .right
          default: paragraph.alignment = .natural
          }
          appendLine(rendered[rowIndex][column], paragraph: paragraph, to: out)
        }
      }
      appendSpacer(context: context, to: out)
    }

    /// Each column's share of the table width, in percent, from the rendered
    /// cells.
    ///
    /// A column is never narrower than its widest unbreakable piece, which is
    /// what a formula image is: a cell narrower than its formula draws the
    /// image over the next column. The rest of the width goes to columns in
    /// proportion to their text, so a column of short values is not as wide
    /// as one holding sentences. The width is a share of the table, so the
    /// shares are computed for a typical column and still hold when the
    /// window is narrower or wider.
    static func columnWidths(cells: [[NSAttributedString]], columns: Int) -> [CGFloat] {
      // The answer's text column, which a table fills.
      let tableWidth: CGFloat = NativeMarkdownStyle.readableWidth
      let padding: CGFloat = 32
      var minimum = [CGFloat](repeating: 24, count: columns)
      var natural = [CGFloat](repeating: 24, count: columns)
      for row in cells {
        for (index, text) in row.enumerated() where index < columns {
          minimum[index] = max(minimum[index], widestUnbreakable(text) + padding)
          natural[index] = max(natural[index], min(text.size().width, tableWidth * 0.6) + padding)
        }
      }
      // Start every column at its minimum, then share what is left by the
      // extra width each would like.
      var widths = minimum
      let spare = tableWidth - minimum.reduce(0, +)
      if spare > 0 {
        let wants = zip(natural, minimum).map { max(0, $0 - $1) }
        let totalWant = wants.reduce(0, +)
        if totalWant > 0 {
          for index in widths.indices {
            widths[index] += spare * wants[index] / totalWant
          }
        } else {
          widths = widths.map { $0 + spare / CGFloat(columns) }
        }
      }
      let total = widths.reduce(0, +)
      return widths.map { ($0 / total * 100 * 0.99).rounded(.down) }
    }

    /// The widest piece of `text` a line cannot break: a formula image or the
    /// longest word.
    static func widestUnbreakable(_ text: NSAttributedString) -> CGFloat {
      var widest: CGFloat = 0
      let full = NSRange(location: 0, length: text.length)
      text.enumerateAttribute(.attachment, in: full) { value, _, _ in
        if let attachment = value as? NSTextAttachment {
          widest = max(widest, attachment.bounds.width)
        }
      }
      let string = text.string as NSString
      string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: .byWords) { _, range, _, _ in
        widest = max(widest, text.attributedSubstring(from: range).size().width)
      }
      return ceil(widest)
    }
  }
#endif
