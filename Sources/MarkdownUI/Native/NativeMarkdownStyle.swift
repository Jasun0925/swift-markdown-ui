#if os(macOS)
  import AppKit

  extension NSAttributedString.Key {
    /// The source a rendered run stands for, written in place of the run
    /// when the selection is copied: the TeX of a formula attachment.
    static let markdownSource = NSAttributedString.Key("MarkdownUI.NativeSource")
    /// Marks a display formula, which the block renderer sets on its own line.
    static let markdownDisplayMath = NSAttributedString.Key("MarkdownUI.NativeDisplayMath")
    /// Marks a fenced code block's text, label included; the value is a
    /// `MarkdownCodeBlock` holding its exact source for the Copy button.
    static let markdownCodeBlock = NSAttributedString.Key("MarkdownUI.NativeCodeBlock")
  }

  /// One fenced code block, as copied by its Copy button.
  final class MarkdownCodeBlock: NSObject {
    let code: String
    init(_ code: String) { self.code = code }
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

    /// Code block fill, lighter than before so the block reads as a panel
    /// rather than a gray slab.
    var codeBlockBackground: NSColor {
      Self.dynamic(light: NSColor(srgbRed: 0.965, green: 0.969, blue: 0.976, alpha: 1),
                   dark: NSColor(white: 1, alpha: 0.06))
    }

    /// The table's header rule and row rules: the header is darker, rows
    /// are a hairline.
    var tableHeaderRule: NSColor {
      Self.dynamic(light: NSColor(white: 0, alpha: 0.16), dark: NSColor(white: 1, alpha: 0.2))
    }
    var tableRowRule: NSColor {
      Self.dynamic(light: NSColor(white: 0, alpha: 0.08), dark: NSColor(white: 1, alpha: 0.1))
    }

    /// Token colors for fenced code, close to Xcode's default themes.
    struct CodeColors {
      let comment: NSColor
      let string: NSColor
      let number: NSColor
      let keyword: NSColor
      let type: NSColor
    }

    var codeColors: CodeColors {
      func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
        NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
      }
      return CodeColors(
        comment: Self.dynamic(light: rgb(93, 108, 121), dark: rgb(127, 140, 152)),
        string: Self.dynamic(light: rgb(196, 26, 22), dark: rgb(252, 106, 93)),
        number: Self.dynamic(light: rgb(28, 0, 207), dark: rgb(208, 191, 105)),
        keyword: Self.dynamic(light: rgb(155, 35, 147), dark: rgb(252, 95, 163)),
        type: Self.dynamic(light: rgb(11, 79, 121), dark: rgb(93, 216, 255))
      )
    }

    var quoteBarColor: NSColor {
      Self.dynamic(light: NSColor(white: 0, alpha: 0.18), dark: NSColor(white: 1, alpha: 0.24))
    }

    var mathColor: NSColor {
      isDark ? NSColor(white: 0.9, alpha: 1) : NSColor(white: 0.12, alpha: 1)
    }

    // Measurements follow the DeepSeek Harness markdown sheet, which is set
    // for 14px text and moves every size by the same delta when the reader
    // changes the font size. `delta` is that offset, so 14 matches DSH.

    /// The reader's font size minus the 14px the measurements are set for.
    var delta: CGFloat { fontSize - 14 }

    /// Body line height: 24px at 14px text.
    var bodyLineHeight: CGFloat { 24 + delta }
    /// Space between paragraphs, lists, tables, and code blocks.
    var paragraphSpacing: CGFloat { 16 }
    /// Space between two items of a list.
    var tightSpacing: CGFloat { 6 }

    /// Size, weight, line height, and space above and below one heading level.
    func heading(_ level: Int) -> (size: CGFloat, weight: NSFont.Weight, lineHeight: CGFloat, above: CGFloat, below: CGFloat) {
      switch level {
      case 1: return (21 + delta, .bold, 30 + delta, 32, 16)
      case 2: return (19 + delta, .bold, 28 + delta, 32, 16)
      case 3: return (18 + delta, .bold, 26 + delta, 32, 16)
      case 4: return (fontSize, .semibold, bodyLineHeight, 16, 16)
      default: return (fontSize, .semibold, bodyLineHeight, 16, 8)
      }
    }

    /// Table text: one size below the body, 22px lines.
    var tableFontSize: CGFloat { fontSize - 1 }
    var tableLineHeight: CGFloat { 22 + delta }

    /// Code text: 12px with 19px lines at 14px body text.
    var codeFontSize: CGFloat { 12 + delta }
    var codeLineHeight: CGFloat { 19 + delta }

    /// The widest an answer's text column gets. Longer lines are hard to
    /// follow back to their start.
    static let readableWidth: CGFloat = 760

    func font(
      size: CGFloat? = nil,
      bold: Bool = false,
      weight: NSFont.Weight? = nil,
      italic: Bool = false,
      monospaced: Bool = false
    ) -> NSFont {
      let size = size ?? fontSize
      let weight = weight ?? (bold ? .semibold : .regular)
      var font: NSFont
      if monospaced {
        font = .monospacedSystemFont(ofSize: size * 0.88, weight: weight == .regular ? .regular : .semibold)
      } else {
        font = .systemFont(ofSize: size, weight: weight)
      }
      if italic {
        font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
      }
      return font
    }

    /// How far to raise `font`'s glyphs so they sit in the middle of a line
    /// `lineHeight` tall. TextKit puts the extra height of a minimum line
    /// height above the text; CSS splits it evenly. Raising by half the
    /// extra matches CSS.
    static func baselineOffset(for font: NSFont, lineHeight: CGFloat) -> CGFloat {
      let natural = font.ascender - font.descender + font.leading
      return max(0, ((lineHeight - natural) / 2).rounded())
    }

    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
      NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
      }
    }
  }
#endif
