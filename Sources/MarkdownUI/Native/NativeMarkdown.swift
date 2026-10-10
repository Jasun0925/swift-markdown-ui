#if os(macOS)
  import AppKit
  import SwiftUI

  /// Markdown drawn as one AppKit text view.
  ///
  /// Unlike `Markdown`, which draws each block as its own SwiftUI `Text`, the
  /// whole document is one selection: a drag runs across headings,
  /// paragraphs, lists, tables, and code, and Copy returns it as text. Inline
  /// `$…$` / `\(…\)` and display `$$…$$` / `\[…\]` math is typeset with
  /// SwiftMath; a formula SwiftMath cannot set stays as its source. Copying a
  /// formula writes its TeX.
  ///
  /// The view does not scroll. It takes the height of its text and passes the
  /// scroll wheel to the scroll view it sits in.
  /// The pieces `NativeMarkdown` is made of, for callers that host the text
  /// view themselves and for the package's checks.
  public enum NativeMarkdownRendering {
    /// The attributed text `NativeMarkdown` would show for `source`.
    public static func attributedString(_ source: String, fontSize: CGFloat, isDark: Bool) -> NSAttributedString {
      NativeMarkdownRenderer(style: NativeMarkdownStyle(fontSize: fontSize, isDark: isDark)).render(source)
    }

    /// The formulas found in `source`, as TeX, in order.
    public static func formulas(in source: String) -> [(latex: String, display: Bool)] {
      MathExtraction.extract(source).math.map { ($0.latex, $0.display) }
    }

    /// The text a copy of the whole of `text` writes: formulas as their TeX.
    @MainActor public static func copiedText(_ text: NSAttributedString) -> String? {
      let view = NativeMarkdownTextView.make()
      view.textStorage?.setAttributedString(text)
      view.setSelectedRange(NSRange(location: 0, length: text.length))
      return view.copiedString()
    }

    /// The TeX handed to SwiftMath for `latex`, in the order it is tried.
    public static func preparedLatex(_ latex: String) -> [String] {
      FormulaTypesetter.candidates(latex)
    }

    /// Whether `latex` typesets without falling back to its source.
    public static func typesets(_ latex: String, display: Bool = false) -> Bool {
      FormulaTypesetter.typeset(latex, display: display, fontSize: 14, color: .black) != nil
    }

    /// `source` drawn at `width` into a PNG, as the text view would show it.
    /// For checking layout by eye; the copy buttons are subviews and drawn too.
    @MainActor public static func snapshot(_ source: String, width: CGFloat, fontSize: CGFloat = 14, isDark: Bool = false) -> Data? {
      let view = NativeMarkdownTextView.make()
      view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
      view.textStorage?.setAttributedString(attributedString(source, fontSize: fontSize, isDark: isDark))
      view.textDidReplace()
      let height = view.measuredHeight(for: width)
      view.frame = CGRect(x: 0, y: 0, width: width, height: height)
      view.layoutSubtreeIfNeeded()
      let host = NSView(frame: view.frame.insetBy(dx: -16, dy: -16).offsetBy(dx: 16, dy: 16))
      host.wantsLayer = true
      host.layer?.backgroundColor = (isDark ? NSColor(white: 0.12, alpha: 1) : NSColor.white).cgColor
      view.frame.origin = CGPoint(x: 16, y: 16)
      host.addSubview(view)
      host.appearance = view.appearance
      guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
      host.cacheDisplay(in: host.bounds, to: rep)
      return rep.representation(using: .png, properties: [:])
    }
  }

  public struct NativeMarkdown: View {
    private let source: String
    private let fontSize: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    public init(_ source: String, fontSize: CGFloat = 14) {
      self.source = source
      self.fontSize = fontSize
    }

    public var body: some View {
      NativeMarkdownRepresentable(
        source: source,
        style: NativeMarkdownStyle(fontSize: fontSize, isDark: colorScheme == .dark)
      )
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  struct NativeMarkdownRepresentable: NSViewRepresentable {
    let source: String
    let style: NativeMarkdownStyle

    final class Coordinator {
      var source: String?
      var style: NativeMarkdownStyle?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NativeMarkdownTextView {
      let view = NativeMarkdownTextView.make()
      view.setContentHuggingPriority(.defaultLow, for: .horizontal)
      view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      return view
    }

    func updateNSView(_ view: NativeMarkdownTextView, context: Context) {
      let coordinator = context.coordinator
      guard coordinator.source != source || coordinator.style != style else { return }
      coordinator.source = source
      coordinator.style = style
      let rendered = NativeMarkdownRenderer(style: style).render(source)
      view.textStorage?.setAttributedString(rendered)
      view.textDidReplace()
      view.invalidateIntrinsicContentSize()
    }

    @available(macOS 13.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NativeMarkdownTextView, context: Context) -> CGSize? {
      guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
      return CGSize(width: width, height: nsView.measuredHeight(for: width))
    }
  }
#endif
