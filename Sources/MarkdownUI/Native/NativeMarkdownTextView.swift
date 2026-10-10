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
      needsLayout = true
    }

    override func layout() {
      super.layout()
      placeCopyButtons()
    }

    /// The tint behind inline code: a rounded rect around the glyphs on each
    /// line the code spans, drawn under the text.
    override func drawBackground(in rect: NSRect) {
      super.drawBackground(in: rect)
      guard let storage = textStorage, let layout = layoutManager, let container = textContainer else { return }
      let tint = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
          ? NSColor(white: 1, alpha: 0.11) : NSColor(white: 0, alpha: 0.06)
      }
      let border = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
          ? NSColor(white: 1, alpha: 0.14) : NSColor(white: 0, alpha: 0.08)
      }
      storage.enumerateAttribute(.markdownInlineCode, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
        guard value != nil, let font = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont else { return }
        let raise = storage.attribute(.baselineOffset, at: range.location, effectiveRange: nil) as? CGFloat ?? 0
        let glyphs = layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        layout.enumerateEnclosingRects(
          forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: container
        ) { lineRect, _ in
          // Where the glyphs are drawn. `location(forGlyphAt:)` is the
          // baseline within the line fragment and already includes the run's
          // baseline offset, so it is not subtracted again. The chip is
          // centered on the code font's cap-to-descender box, so its tint
          // sits evenly around the letters.
          _ = raise
          let glyph = layout.glyphIndex(for: CGPoint(x: lineRect.midX, y: lineRect.midY), in: container)
          let fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
          let baseline = fragment.minY + layout.location(forGlyphAt: glyph).y
          // A fixed box for every chip, from the tallest and lowest ink a
          // line of code has: brackets reach above the caps and below the
          // descenders. Taking it from the font rather than the chip's own
          // letters keeps `eps` and `log(0)` the same height.
          let probe = Self.bracketBounds(font)
          let inkTop = baseline - max(font.capHeight, probe.maxY)
          let inkBottom = baseline - min(font.descender, probe.minY)
          let padding: CGFloat = 3
          let top = inkTop - padding
          let height = inkBottom - inkTop + padding * 2
          let chip = CGRect(x: lineRect.minX, y: top, width: lineRect.width, height: height)
            .offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y)
          guard chip.intersects(rect) else { return }
          let path = NSBezierPath(roundedRect: chip, xRadius: 5, yRadius: 5)
          tint.setFill()
          path.fill()
          border.setStroke()
          path.lineWidth = 0.5
          path.stroke()
        }
      }
    }

    /// Called after the text changes, so the buttons match the new blocks.
    func textDidReplace() {
      copyButtons.forEach { $0.removeFromSuperview() }
      copyButtons.removeAll()
      needsLayout = true
    }

    private var copyButtons: [CodeCopyButton] = []

    /// The ink box of "(" and ")" in `font`, which spans a code line's full
    /// height: above the caps and below the descenders. Cached per font.
    private static var bracketInk: [NSFont: CGRect] = [:]

    static func bracketBounds(_ font: NSFont) -> CGRect {
      if let hit = bracketInk[font] { return hit }
      var characters: [UniChar] = [0x28, 0x29]
      var glyphs = [CGGlyph](repeating: 0, count: 2)
      CTFontGetGlyphsForCharacters(font, &characters, &glyphs, 2)
      let box = CTFontGetBoundingRectsForGlyphs(font, .horizontal, glyphs, nil, 2)
      bracketInk[font] = box
      return box
    }

    /// One Copy button per fenced block, at the right end of its label line.
    private func placeCopyButtons() {
      guard let storage = textStorage, let layout = layoutManager, let container = textContainer else { return }
      var blocks: [(MarkdownCodeBlock, NSRange)] = []
      storage.enumerateAttribute(
        .markdownCodeBlock, in: NSRange(location: 0, length: storage.length)
      ) { value, range, _ in
        if let block = value as? MarkdownCodeBlock { blocks.append((block, range)) }
      }
      while copyButtons.count < blocks.count {
        let button = CodeCopyButton()
        addSubview(button)
        copyButtons.append(button)
      }
      while copyButtons.count > blocks.count {
        copyButtons.removeLast().removeFromSuperview()
      }
      layout.ensureLayout(for: container)
      for (button, (block, range)) in zip(copyButtons, blocks) {
        button.code = block.code
        let glyphs = layout.glyphRange(forCharacterRange: NSRange(location: range.location, length: 1), actualCharacterRange: nil)
        let line = layout.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
        // The box's right edge, past its padding: with a label line the button
        // ends that line, and without one it sits in the padding kept for it.
        var right = line.maxX
        if let paragraph = storage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle,
          let box = paragraph.textBlocks.last
        {
          let blockRange = storage.range(of: box, at: range.location)
          let frame = layout.boundsRect(for: box, glyphRange: layout.glyphRange(forCharacterRange: blockRange, actualCharacterRange: nil))
          right = frame.maxX - 10
        }
        let size = button.fittingSize
        button.frame = CGRect(
          x: right - size.width,
          y: line.minY + (line.height - size.height) / 2,
          width: size.width,
          height: size.height
        )
      }
    }

    /// NSTextView sets the I-beam on every mouse move over its bounds, which
    /// overrides the Copy buttons' own cursor rects. Over a button the hand
    /// is set instead.
    override func mouseMoved(with event: NSEvent) {
      if isOverCopyButton(event) {
        NSCursor.pointingHand.set()
        return
      }
      super.mouseMoved(with: event)
    }

    override func cursorUpdate(with event: NSEvent) {
      if isOverCopyButton(event) {
        NSCursor.pointingHand.set()
        return
      }
      super.cursorUpdate(with: event)
    }

    private func isOverCopyButton(_ event: NSEvent) -> Bool {
      let point = convert(event.locationInWindow, from: nil)
      return copyButtons.contains { !$0.isHidden && $0.frame.contains(point) }
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
            // A formula run, or the padding of an inline code chip (empty),
            // written as what the model wrote.
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

  extension NSAttributedString {
    /// The character range `block` spans around `location`: the run of
    /// paragraphs whose text blocks include it.
    func range(of block: NSTextBlock, at location: Int) -> NSRange {
      let string = self.string as NSString
      func contains(_ index: Int) -> Bool {
        guard index >= 0, index < length,
          let style = attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle
        else { return false }
        return style.textBlocks.contains { $0 === block }
      }
      var start = string.paragraphRange(for: NSRange(location: location, length: 0)).location
      while start > 0, contains(start - 1) {
        start = string.paragraphRange(for: NSRange(location: start - 1, length: 0)).location
      }
      var end = NSMaxRange(string.paragraphRange(for: NSRange(location: location, length: 0)))
      while end < length, contains(end) {
        end = NSMaxRange(string.paragraphRange(for: NSRange(location: end, length: 0)))
      }
      return NSRange(location: start, length: end - start)
    }
  }

  /// "Copy" on a code block. Writes the block's exact source and says
  /// "Copied" for a moment.
  final class CodeCopyButton: NSButton {
    var code = ""
    private var resetWork: DispatchWorkItem?

    init() {
      super.init(frame: .zero)
      isBordered = false
      bezelStyle = .inline
      setButtonType(.momentaryChange)
      font = .systemFont(ofSize: 11)
      contentTintColor = .secondaryLabelColor
      image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
      imagePosition = .imageLeading
      imageScaling = .scaleProportionallyDown
      title = Self.copyTitle
      toolTip = Self.copyTitle
      setAccessibilityLabel("Copy code")
      target = self
      action = #selector(copyCode)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private static let copyTitle = "Copy"

    override func resetCursorRects() {
      addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
      super.updateTrackingAreas()
      trackingAreas.forEach(removeTrackingArea)
      addTrackingArea(
        NSTrackingArea(
          rect: .zero, options: [.cursorUpdate, .activeInActiveApp, .inVisibleRect], owner: self))
    }

    override func cursorUpdate(with event: NSEvent) {
      NSCursor.pointingHand.set()
    }

    @objc private func copyCode() {
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(code, forType: .string)
      title = "Copied"
      image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
      resetWork?.cancel()
      let work = DispatchWorkItem { [weak self] in
        self?.title = Self.copyTitle
        self?.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
      }
      resetWork = work
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }
  }
#endif
