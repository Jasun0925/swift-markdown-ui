#if os(macOS)
  import AppKit

  extension NSAttributedString.Key {
    /// The source a rendered run stands for, written in place of the run
    /// when the selection is copied: the TeX of a formula attachment.
    static let markdownSource = NSAttributedString.Key("MarkdownUI.NativeSource")
  }

  /// The value of `.markdownSource`. A reference type, so two formulas with
  /// the same TeX side by side stay two runs and copy twice.
  final class MarkdownSource: NSObject {
    let text: String
    init(_ text: String) { self.text = text }
  }

  /// Fonts, colors, and spacing for the native renderer.
  ///
  /// Text colors are dynamic system colors, so the text view redraws them for
  /// its own appearance. Formulas are images, so they take `mathColor`, which
  /// is fixed for one appearance; the view renders again when that changes.
  struct NativeMarkdownStyle: Hashable {
    let fontSize: CGFloat
    let isDark: Bool

    var textColor: NSColor { .labelColor }
    var secondaryColor: NSColor { .secondaryLabelColor }
    var linkColor: NSColor { .linkColor }
    var separatorColor: NSColor { .separatorColor }

    var codeBackground: NSColor {
      Self.dynamic(light: NSColor(white: 0, alpha: 0.045), dark: NSColor(white: 1, alpha: 0.07))
    }

    var inlineCodeBackground: NSColor {
      Self.dynamic(light: NSColor(white: 0, alpha: 0.07), dark: NSColor(white: 1, alpha: 0.11))
    }

    var tableHeaderBackground: NSColor {
      Self.dynamic(light: NSColor(white: 0, alpha: 0.035), dark: NSColor(white: 1, alpha: 0.06))
    }

    var mathColor: NSColor {
      isDark ? NSColor(white: 0.9, alpha: 1) : NSColor(white: 0.12, alpha: 1)
    }

    /// Space after a paragraph.
    var paragraphSpacing: CGFloat { (fontSize * 0.65).rounded() }
    /// Extra leading between the lines of one paragraph.
    var lineSpacing: CGFloat { (fontSize * 0.22).rounded() }
    /// Space after an item of a tight list.
    var tightSpacing: CGFloat { (fontSize * 0.25).rounded() }

    func font(
      size: CGFloat? = nil,
      bold: Bool = false,
      italic: Bool = false,
      monospaced: Bool = false
    ) -> NSFont {
      let size = size ?? fontSize
      var font: NSFont
      if monospaced {
        font = .monospacedSystemFont(ofSize: size * 0.92, weight: bold ? .semibold : .regular)
      } else {
        font = .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
      }
      if italic {
        font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
      }
      return font
    }

    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
      NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
      }
    }
  }
#endif
