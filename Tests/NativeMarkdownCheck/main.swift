// Checks for the native macOS renderer. `swift run NativeMarkdownCheck`
// prints each check and exits non-zero when one fails.

#if os(macOS)
  import AppKit
  import MarkdownUI

  var failures = 0

  func check(_ name: String, _ condition: Bool) {
    print(condition ? "PASS" : "FAIL", name)
    if !condition { failures += 1 }
  }

  func render(_ source: String) -> NSAttributedString {
    NativeMarkdownRendering.attributedString(source, fontSize: 14, isDark: false)
  }

  func attachments(_ text: NSAttributedString) -> Int {
    var count = 0
    text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, _, _ in
      if value != nil { count += 1 }
    }
    return count
  }

  // Formula extraction
  let both = NativeMarkdownRendering.formulas(in: "Energy $E=mc^2$ and\n\n$$a_1 + b_2$$\n")
  check("inline and display formulas are found", both.map(\.latex) == ["E=mc^2", "a_1 + b_2"])
  check("display flag", both.map(\.display) == [false, true])
  check("code spans and fences keep their dollars",
    NativeMarkdownRendering.formulas(in: "Use `$PATH`\n\n```sh\necho $HOME $USER\n```\n").isEmpty)
  check("prices stay text", NativeMarkdownRendering.formulas(in: "costs $5 and $10 today").isEmpty)
  check("an unclosed dollar stays text", NativeMarkdownRendering.formulas(in: "an unclosed $x and more").isEmpty)
  check("escaped dollars stay text", NativeMarkdownRendering.formulas(in: "escaped \\$x\\$ here").isEmpty)
  let slashes = NativeMarkdownRendering.formulas(in: "inline \\(a+b\\) and \\[c=d\\]")
  check("backslash delimiters", slashes.map(\.latex) == ["a+b", "c=d"] && slashes.map(\.display) == [false, true])

  // Rendering
  let bold = render("这是**粗体**。")
  let boldFont = bold.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
  check("bold beside Chinese renders without asterisks", bold.string == "这是粗体。")
  check("bold beside Chinese is bold", boldFont?.fontDescriptor.symbolicTraits.contains(.bold) == true)

  let underscores = render("$x_i$ and $y_i$ and _real emphasis_")
  check("underscores in formulas are not emphasis", attachments(underscores) == 2)

  let loss = render("Loss $\\mathcal{L} = \\frac{1}{N}\\sum_i (y_i - \\hat{y}_i)^2$ here")
  check("inline formula typesets", attachments(loss) == 1 && !loss.string.contains("\\frac"))

  let underbrace = render(
    "$$L_{total} = \\underbrace{\\tfrac{1}{N}\\sum\\ell(f(x_i;\\theta), y_i)}_{\\text{纯损失}} + \\underbrace{\\lambda\\,\\Omega(\\theta)}_{\\text{正则项}}$$"
  )
  check("underbrace with Chinese text typesets", attachments(underbrace) == 1)

  let table = render("| 损失 | 特点 |\n|---|---|\n| MSE | 对异常值敏感 |\n| MAE | 鲁棒 |\n")
  var tables = Set<ObjectIdentifier>()
  table.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: table.length)) { value, _, _ in
    for block in (value as? NSParagraphStyle)?.textBlocks ?? [] {
      if let cell = block as? NSTextTableBlock { tables.insert(ObjectIdentifier(cell.table)) }
    }
  }
  check("all table cells belong to one table", tables.count == 1)
  check("table text is present", table.string.contains("对异常值敏感"))

  let links = render("[a](javascript:alert(1)) [b](https://example.com)")
  let b = (links.string as NSString).range(of: "b")
  check("javascript links are not clickable", links.attribute(.link, at: 0, effectiveRange: nil) == nil)
  check("https links are clickable", links.attribute(.link, at: b.location, effectiveRange: nil) != nil)

  // Copy
  let copied = MainActor.assumeIsolated { NativeMarkdownRendering.copiedText(render("a $x^2$ b")) }
  check("copy writes formula source", copied == "a $x^2$ b")
  let twice = MainActor.assumeIsolated { NativeMarkdownRendering.copiedText(render("$x$$x$")) }
  check("two equal formulas copy twice", twice?.components(separatedBy: "$x$").count == 3)

  print(failures == 0 ? "All checks passed" : "\(failures) check(s) failed")
  exit(failures == 0 ? 0 : 1)
#endif
