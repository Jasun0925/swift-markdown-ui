#if os(macOS)
  import Foundation

  /// One formula lifted out of the source before cmark parses it.
  struct ExtractedMath: Hashable {
    let latex: String
    let display: Bool
    /// The source exactly as written, delimiters included, so a copy
    /// returns what the model wrote.
    let source: String
  }

  /// Markdown has no math, and cmark reads `_`, `*`, and `|` inside a formula
  /// as emphasis and table cells. Each closed formula outside code is replaced
  /// by a placeholder token that cmark keeps as plain text; the renderer swaps
  /// the token back for the typeset formula. An opening delimiter without a
  /// close stays as text, so it cannot swallow the rest of the answer.
  enum MathExtraction {
    static let open: Character = "\u{E000}"
    static let close: Character = "\u{E001}"

    static func token(_ index: Int) -> String {
      "\(open)\(index)\(close)"
    }

    static func extract(_ source: String) -> (markdown: String, math: [ExtractedMath]) {
      var math: [ExtractedMath] = []
      var output = ""
      var prose = ""
      var fence: (marker: Character, count: Int)?
      let lines = source.replacingOccurrences(of: "\r\n", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: false)

      for (index, line) in lines.enumerated() {
        let text = String(line) + (index < lines.count - 1 ? "\n" : "")
        if let current = fence {
          output += text
          if let closing = fenceMarker(String(line)), closing.marker == current.marker,
            closing.count >= current.count, closing.rest.isEmpty
          {
            fence = nil
          }
        } else if let opening = fenceMarker(String(line)) {
          output += scanProse(prose, into: &math)
          prose = ""
          fence = (opening.marker, opening.count)
          output += text
        } else {
          prose += text
        }
      }
      output += scanProse(prose, into: &math)
      return (output, math)
    }

    /// Replaces closed formulas in prose, leaving inline code spans untouched.
    private static func scanProse(_ text: String, into math: inout [ExtractedMath]) -> String {
      let chars = Array(text)
      var output = ""
      var i = 0
      while i < chars.count {
        let c = chars[i]
        if c == "\\", i + 1 < chars.count, chars[i + 1] == "$" {
          output += "\\$"
          i += 2
          continue
        }
        if c == "`" {
          let end = codeSpanEnd(chars, from: i)
          output += String(chars[i..<end])
          i = end
          continue
        }
        if let found = formula(chars, at: i) {
          let source = String(chars[i..<found.end])
          // GFM reads `\|` in a table row as a literal pipe before anything
          // else sees the cell, so `$p(x\|z)$` in a table means `p(x|z)`.
          let latex = onTableRow(chars, at: i)
            ? found.latex.replacingOccurrences(of: "\\|", with: "|") : found.latex
          math.append(ExtractedMath(latex: latex, display: found.display, source: source))
          let token = token(math.count - 1)
          // Kept in place: a list item or a table cell stays one block. The
          // renderer gives a display formula its own centered line.
          output += token
          i = found.end
          continue
        }
        output.append(c)
        i += 1
      }
      return output
    }

    /// Whether the line holding `index` is a table row (starts with `|`).
    private static func onTableRow(_ chars: [Character], at index: Int) -> Bool {
      var start = index
      while start > 0, chars[start - 1] != "\n" { start -= 1 }
      var j = start
      while j < index, chars[j] == " " || chars[j] == "\t" { j += 1 }
      return j < index && chars[j] == "|"
    }

    /// The index after a backtick code span that starts at `start`, or just
    /// past the run when no closing run of the same length follows.
    private static func codeSpanEnd(_ chars: [Character], from start: Int) -> Int {
      var runEnd = start
      while runEnd < chars.count, chars[runEnd] == "`" { runEnd += 1 }
      let length = runEnd - start
      var j = runEnd
      while j < chars.count {
        guard chars[j] == "`" else { j += 1; continue }
        var k = j
        while k < chars.count, chars[k] == "`" { k += 1 }
        if k - j == length { return k }
        j = k
      }
      return runEnd
    }

    /// A closed formula starting at `i`. `$$`, `\[`, and `\(` may span lines;
    /// a single `$` must close on the same line, must not hug spaces, and
    /// must not be followed by a digit, so "$5 and $10" stays prose.
    private static func formula(_ chars: [Character], at i: Int)
      -> (latex: String, display: Bool, end: Int)?
    {
      func starts(_ s: String, at k: Int) -> Bool {
        let p = Array(s)
        guard k + p.count <= chars.count else { return false }
        return Array(chars[k..<(k + p.count)]) == p
      }
      func find(_ s: String, from k: Int, sameLine: Bool) -> Int? {
        var j = k
        while j < chars.count {
          if sameLine, chars[j] == "\n" { return nil }
          if chars[j] == "\\", !starts(s, at: j) { j += 2; continue }
          if starts(s, at: j) { return j }
          j += 1
        }
        return nil
      }
      for (left, right, display) in [("$$", "$$", true), ("\\[", "\\]", true), ("\\(", "\\)", false)] {
        guard starts(left, at: i), let close = find(right, from: i + left.count, sameLine: false) else {
          continue
        }
        let body = String(chars[(i + left.count)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        return (body, display, close + right.count)
      }
      guard chars[i] == "$", i + 1 < chars.count, chars[i + 1] != "$", !chars[i + 1].isWhitespace,
        let close = find("$", from: i + 1, sameLine: true), !chars[close - 1].isWhitespace
      else { return nil }
      if close + 1 < chars.count, chars[close + 1].isNumber { return nil }
      return (String(chars[(i + 1)..<close]), false, close + 1)
    }

    /// A fence line: up to three spaces, then three or more backticks or tildes.
    private static func fenceMarker(_ line: String) -> (marker: Character, count: Int, rest: String)? {
      let trimmed = line.drop { $0 == " " || $0 == "\t" }
      guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
      let run = trimmed.prefix { $0 == first }
      guard run.count >= 3 else { return nil }
      let rest = trimmed.dropFirst(run.count).trimmingCharacters(in: .whitespaces)
      if first == "`", rest.contains("`") { return nil }
      return (first, run.count, rest)
    }
  }
#endif
