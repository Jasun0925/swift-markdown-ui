#if os(macOS)
  import Foundation

  /// Bold that CommonMark's flanking rules leave as literal `**`.
  ///
  /// In Chinese and Japanese text a model writes `在**离散对数问题（DLP）**的`:
  /// the closing `**` sits after punctuation and before a letter, so it may
  /// not close. It also writes `** Diffie-Hellman 密钥交换**`, with a space
  /// inside, so the opening may not open. cmark keeps both as text. After
  /// parsing, the `**` left in text are paired up in order within one line,
  /// and each pair becomes bold with the spaces inside it trimmed. A lone
  /// `**`, or a pair with nothing between it, stays text; code spans and
  /// formulas are separate nodes and are never touched.
  enum StrongRepair {
    private enum Item {
      case node(InlineNode)
      case marker
    }

    static func repair(_ inlines: [InlineNode]) -> [InlineNode] {
      // Children first, so bold inside a link or emphasis is repaired too.
      let nested = inlines.map { node -> InlineNode in
        var node = node
        if !node.children.isEmpty { node.children = repair(node.children) }
        return node
      }
      guard nested.contains(where: { if case .text(let t) = $0 { return t.contains("**") } else { return false } })
      else { return nested }

      var items: [Item] = []
      for node in nested {
        guard case .text(let text) = node, text.contains("**") else {
          items.append(.node(node))
          continue
        }
        let pieces = text.components(separatedBy: "**")
        for (index, piece) in pieces.enumerated() {
          if index > 0 { items.append(.marker) }
          if !piece.isEmpty { items.append(.node(.text(piece))) }
        }
      }

      var out: [InlineNode] = []
      var i = 0
      while i < items.count {
        guard case .marker = items[i] else {
          if case .node(let node) = items[i] { out.append(node) }
          i += 1
          continue
        }
        // The next marker on the same line closes this one.
        var j = i + 1
        var closing: Int?
        while j < items.count {
          if case .marker = items[j] { closing = j; break }
          if case .node(let node) = items[j], node == .softBreak || node == .lineBreak { break }
          j += 1
        }
        if let closing {
          let inside = trimmed(items[(i + 1)..<closing].compactMap { item -> InlineNode? in
            if case .node(let node) = item { return node } else { return nil }
          })
          if !inside.isEmpty {
            out.append(.strong(children: inside))
            i = closing + 1
            continue
          }
        }
        out.append(.text("**"))
        i += 1
      }
      return merged(out)
    }

    /// Drops spaces just inside the bold, which is what kept it from opening.
    private static func trimmed(_ nodes: [InlineNode]) -> [InlineNode] {
      var nodes = nodes
      if case .text(let first)? = nodes.first {
        let text = String(first.drop { $0 == " " })
        if text.isEmpty { nodes.removeFirst() } else { nodes[0] = .text(text) }
      }
      if case .text(let last)? = nodes.last {
        var text = last
        while text.last == " " { text.removeLast() }
        if text.isEmpty { nodes.removeLast() } else { nodes[nodes.count - 1] = .text(text) }
      }
      return nodes
    }

    /// Joins neighbouring text nodes back into one.
    private static func merged(_ nodes: [InlineNode]) -> [InlineNode] {
      var out: [InlineNode] = []
      for node in nodes {
        if case .text(let text) = node, case .text(let previous)? = out.last {
          out[out.count - 1] = .text(previous + text)
        } else {
          out.append(node)
        }
      }
      return out
    }
  }
#endif
