#if os(macOS)
  import Foundation
  import SwiftMath

  /// Lets SwiftMath draw text it would otherwise skip.
  ///
  /// SwiftMath's parser ignores every character outside printable ASCII
  /// (except a few accented letters and Cyrillic), so `\text{低估}` typesets
  /// as nothing. Each such run is registered as a custom symbol whose nucleus
  /// is the run itself, and the run in the source is replaced by that symbol's
  /// command. CoreText draws the nucleus with font fallback, so the Chinese
  /// reaches the image in the system's CJK font.
  enum TextAtoms {
    private static let lock = NSLock()
    private static var names: [String: String] = [:]

    /// `latex` with each non-ASCII run replaced by a registered command.
    static func substitute(_ latex: String) -> String {
      var out = ""
      var run = ""
      // A command name runs to the first non-letter. Wrapping it in braces
      // ends it without a space, which `\text{}` would draw as a gap.
      func flush() {
        guard !run.isEmpty else { return }
        out += "{\\" + command(for: run) + "}"
        run = ""
      }
      for scalar in latex.unicodeScalars {
        if scalar.value > 0x7E, !isHandledBySwiftMath(scalar) {
          run.unicodeScalars.append(scalar)
        } else {
          flush()
          out.unicodeScalars.append(scalar)
        }
      }
      flush()
      return out
    }

    /// Characters SwiftMath already maps itself: Cyrillic and the accented
    /// Latin letters it lists.
    private static func isHandledBySwiftMath(_ scalar: Unicode.Scalar) -> Bool {
      MTMathAtomFactory.atom(forCharacter: Character(scalar)) != nil
    }

    /// The command name for `text`, registering it on first use. Names are
    /// letters only, so the parser reads the whole name as one command.
    private static func command(for text: String) -> String {
      lock.lock()
      defer { lock.unlock() }
      if let name = names[text] { return name }
      let name = "hamsatext" + letters(names.count)
      let atom = MTMathAtomFactory.placeholder()
      atom.type = .ordinary
      atom.nucleus = text
      MTMathAtomFactory.add(latexSymbol: name, value: atom)
      names[text] = name
      return name
    }

    /// 0 → "a", 25 → "z", 26 → "ba", ...
    private static func letters(_ index: Int) -> String {
      var index = index
      var result = ""
      repeat {
        result = String(UnicodeScalar(UInt8(97 + index % 26))) + result
        index /= 26
      } while index > 0
      return result
    }
  }
#endif
