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

      for (rowIndex, row) in rows.enumerated() {
        let isHeader = rowIndex == 0
        for column in 0..<columns {
          let cell = NSTextTableBlock(
            table: table, startingRow: rowIndex, rowSpan: 1, startingColumn: column, columnSpan: 1)
          cell.setWidth(8, type: .absoluteValueType, for: .padding, edge: .minY)
          cell.setWidth(8, type: .absoluteValueType, for: .padding, edge: .maxY)
          cell.setWidth(column == 0 ? 0 : 10, type: .absoluteValueType, for: .padding, edge: .minX)
          cell.setWidth(10, type: .absoluteValueType, for: .padding, edge: .maxX)
          cell.setWidth(isHeader ? 1 : 0.5, type: .absoluteValueType, for: .border, edge: .maxY)
          cell.setBorderColor(style.separatorColor, for: .maxY)
          cell.verticalAlignment = .topAlignment
          if isHeader { cell.backgroundColor = style.tableHeaderBackground }

          var inner = context
          inner.indent = 0
          inner.textBlocks = context.textBlocks + [cell]
          let paragraph = paragraphStyle(inner, spacing: 0)
          let alignment = column < alignments.count ? alignments[column] : .none
          switch alignment {
          case .center: paragraph.alignment = .center
          case .right: paragraph.alignment = .right
          default: paragraph.alignment = .natural
          }
          var state = baseState(context)
          state.bold = isHeader
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
  }
#endif
