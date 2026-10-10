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

      let widths = Self.columnWidths(rows: rows, columns: columns)
      for (rowIndex, row) in rows.enumerated() {
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
          var state = baseState(context, size: style.tableFontSize, lineHeight: style.tableLineHeight)
          state.weight = isHeader ? .medium : nil
          let content = column < row.cells.count ? row.cells[column].content : []
          let text = context.inline.render(content, state: state)
          if text.length == 0 {
            // An empty cell still needs a character to hold its block.
            text.append(NSAttributedString(string: "\u{200B}", attributes: context.inline.attributes(state)))
          }
          appendLine(text, paragraph: paragraph, to: out)
        }
      }
      appendSpacer(context: context, to: out)
    }

    /// Each column's share of the table width, in percent, from the length
    /// of its longest cell. AppKit's automatic layout spreads leftover width
    /// evenly, so a column of short values ("none", "τ") was as wide as the
    /// one holding sentences. A floor keeps short columns readable and a
    /// ceiling stops one long cell from squeezing the rest.
    static func columnWidths(rows: [RawTableRow], columns: Int) -> [CGFloat] {
      var lengths = [CGFloat](repeating: 1, count: columns)
      for row in rows {
        for (index, cell) in row.cells.enumerated() where index < columns {
          let text = cell.content.renderPlainText()
          // A CJK character is about two Latin characters wide.
          let width = text.unicodeScalars.reduce(CGFloat(0)) { $0 + ($1.value > 0x2E80 ? 2 : 1) }
          lengths[index] = max(lengths[index], min(width, 60))
        }
      }
      let total = lengths.reduce(0, +)
      let floor = 100 / CGFloat(columns) * 0.5
      var shares = lengths.map { max($0 / total * 100, floor) }
      let scale = 100 / shares.reduce(0, +)
      shares = shares.map { ($0 * scale * 0.98).rounded(.down) }
      return shares
    }
  }
#endif
