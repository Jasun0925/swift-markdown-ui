#if os(macOS)
  import AppKit

  /// The text view behind `NativeMarkdown`. It never scrolls itself: its
  /// height is the text's height, and the wheel goes to the enclosing
  /// conversation. A copy writes the source of formulas instead of the
  /// attachment character.
  final class NativeMarkdownTextView: NSTextView {
    static func make() -> NativeMarkdownTextView {
      // TextKit 1: `NSTextTable` blocks lay out only with the classic stack.
      let storage = NSTextStorage()
      let layout = NSLayoutManager()
      storage.addLayoutManager(layout)
      let container = NSTextContainer(size: CGSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
      container.widthTracksTextView = true
      container.lineFragmentPadding = 0
      layout.addTextContainer(container)
      let view = NativeMarkdownTextView(frame: .zero, textContainer: container)
      view.isEditable = false
      view.isSelectable = true
      view.drawsBackground = false
      view.isRichText = true
      view.textContainerInset = .zero
      view.isVerticallyResizable = false
      view.isHorizontallyResizable = false
      view.autoresizingMask = [.width]
      view.linkTextAttributes = [.foregroundColor: NSColor.linkColor, .cursor: NSCursor.pointingHand]
      return view
    }

    override var intrinsicContentSize: NSSize {
      NSSize(width: NSView.noIntrinsicMetric, height: measuredHeight(for: bounds.width))
    }

    /// The laid-out height of the text at `width`.
    func measuredHeight(for width: CGFloat) -> CGFloat {
      guard let layout = layoutManager, let container = textContainer, width > 0 else { return 0 }
      if container.size.width != width {
        container.size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
      }
      layout.ensureLayout(for: container)
      return ceil(layout.usedRect(for: container).height)
    }

    override func setFrameSize(_ newSize: NSSize) {
      let widthChanged = newSize.width != frame.width
      super.setFrameSize(newSize)
      if widthChanged { invalidateIntrinsicContentSize() }
    }

    override func scrollWheel(with event: NSEvent) {
      if let outer = enclosingScrollView {
        outer.scrollWheel(with: event)
      } else {
        nextResponder?.scrollWheel(with: event)
      }
    }

    override func copy(_ sender: Any?) {
      guard let plain = copiedString() else { return }
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(plain, forType: .string)
    }

    /// The selection as plain text, with formulas written as their TeX.
    func copiedString() -> String? {
      guard let storage = textStorage else { return nil }
      let ranges = selectedRanges.map(\.rangeValue).filter { $0.length > 0 }
      guard !ranges.isEmpty else { return nil }
      var plain = ""
      for range in ranges {
        storage.enumerateAttribute(.markdownSource, in: range) { value, run, _ in
          if let source = value as? MarkdownSource {
            // A formula run, written once as the TeX the model wrote.
            plain += source.text
          } else {
            plain += (storage.string as NSString).substring(with: run)
          }
        }
      }
      return plain.replacingOccurrences(of: "\u{2028}", with: "\n")
        .replacingOccurrences(of: "\u{200B}", with: "")
    }
  }
#endif
