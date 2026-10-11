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

  // Chinese inside formulas is drawn, not dropped
  check("Chinese \\text typesets", NativeMarkdownRendering.typesets("\\tau \\quad (\\text{低估})", display: true))
  let cases = "\\begin{cases} \\tau & \\text{if } y \\ge 0 \\quad (\\text{低估}) \\\\[4pt] \\tau - 1 & \\text{if } y < 0 \\quad (\\text{高估}) \\end{cases}"
  check("cases with \\\\[4pt] and Chinese typesets", NativeMarkdownRendering.typesets(cases, display: true))
  let caseCopy = MainActor.assumeIsolated { NativeMarkdownRendering.copiedText(render("$$\(cases)$$")) }
  check("copying the cases formula returns its TeX", caseCopy == "$$\(cases)$$")

  // Display formulas get their own centered paragraph
  let display = render("before\n$$a+b$$\nafter")
  var centered = false
  display.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: display.length)) { value, range, _ in
    if (value as? NSParagraphStyle)?.alignment == .center,
      display.attribute(.attachment, at: range.location, effectiveRange: nil) != nil
    {
      centered = true
    }
  }
  check("a display formula is a centered paragraph", centered)
  check("text around a display formula is kept", display.string.contains("before") && display.string.contains("after"))

  // Quotes draw a bar; code is highlighted and carries its source
  let quote = render("> quoted line\n> second\n\nafter")
  var quoteBars = 0
  quote.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: quote.length)) { value, _, _ in
    if let block = (value as? NSParagraphStyle)?.textBlocks.first, block.width(for: .border, edge: .minX) > 0 {
      quoteBars += 1
    }
  }
  check("quote paragraphs sit in a bordered block", quoteBars >= 1)

  let code = render("```python\n# note\nx = \"hi\"  # tail\nreturn 42\n```")
  func color(at needle: String) -> NSColor? {
    let range = (code.string as NSString).range(of: needle)
    return code.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
  }
  check("comments and strings get different colors", color(at: "# note") != color(at: "\"hi\""))
  check("a keyword is colored", color(at: "return") != color(at: "x ="))

  // \boxed and \underbrace labels typeset instead of falling back to source
  let boxedText = render("$$\\boxed{H(p, q) = -\\sum_i p_i \\log q_i}$$")
  check("\\boxed typesets", attachments(boxedText) == 1 && !boxedText.string.contains("boxed"))
  let braceLatex = "D = \\underbrace{-\\sum_i p_i \\log q_i}_{\\text{交叉熵 } H(p,q)} - \\underbrace{(-\\sum_i p_i \\log p_i)}_{H(p)}"
  check("underbrace with labels typesets", NativeMarkdownRendering.typesets(braceLatex, display: true))
  // The braced terms stay on the baseline: the formula is as deep as its
  // labels hang, and no taller above the baseline than its tallest term.
  if let plain = NativeMarkdownRendering.formulaMetrics("D = -\\sum_i p_i \\log q_i - (-\\sum_i p_i \\log p_i)", display: true),
    let braced = NativeMarkdownRendering.formulaMetrics(braceLatex, display: true)
  {
    check("braced terms keep the baseline", abs(braced.ascent - plain.ascent) <= 2)
    check("brace labels hang below the baseline", braced.descent > plain.descent + 8)
  } else {
    check("brace metrics are measurable", false)
  }

  // Inline code copies as the code alone
  let inlineCopy = MainActor.assumeIsolated { NativeMarkdownRendering.copiedText(render("use `*WithLogitsLoss` here")) }
  check("inline code copies without its padding", inlineCopy == "use *WithLogitsLoss here")

  // A table column is at least as wide as the formula in it
  let wide = render(
    "| a | b |\n|---|---|\n| $L_\\delta(e) = \\begin{cases} \\frac{1}{2}e^2 & |e| \\le \\delta \\\\ \\delta(|e| - \\frac{1}{2}\\delta) & |e| > \\delta \\end{cases}$ | text |\n")
  var formulaWidth: CGFloat = 0
  var columnShare: CGFloat = 0
  wide.enumerateAttribute(.attachment, in: NSRange(location: 0, length: wide.length)) { value, range, _ in
    guard let attachment = value as? NSTextAttachment else { return }
    formulaWidth = attachment.bounds.width
    let style = wide.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle
    if let cell = style?.textBlocks.last as? NSTextTableBlock {
      columnShare = cell.contentWidth
    }
  }
  check("a formula column is wide enough for its formula", columnShare / 100 * 760 >= formulaWidth)

  // A code block with no language: no label line, and no coloring
  let bare = render("```\nL = -log y_k + 1\n```")
  check("an unlabeled block starts with its code", bare.string.hasPrefix("L = -log"))
  var bareColors = Set<String>()
  bare.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: bare.length)) { value, _, _ in
    if let color = value as? NSColor { bareColors.insert(color.description) }
  }
  check("an unlabeled block is not highlighted", bareColors.count == 1)
  let labeled = render("```python\nx = 1\n```")
  check("a labeled block shows its language", labeled.string.hasPrefix("python\n"))

  // `\\[4pt]` must be rewritten even when the source typesets as written:
  // SwiftMath draws "[4pt]" as text rather than failing.
  let spaced = "\\begin{cases} -\\tau & y > 0 \\\\[4pt] \\tau - 1 & y < 0 \\end{cases}"
  check("\\\\[4pt] is rewritten before typesetting",
    NativeMarkdownRendering.preparedLatex(spaced).allSatisfy { !$0.contains("4pt") })

  // Constructs SwiftMath lacks, from a VAE answer
  check("\\xrightarrow with a label typesets",
    NativeMarkdownRendering.typesets("z \\sim p(z) \\xrightarrow{\\text{decoder}} x \\sim p_\\theta(x|z)"))
  check("\\xrightarrow inside a group typesets", NativeMarkdownRendering.typesets("{a \\xrightarrow{f} b}"))
  check("\\boxed after other terms typesets", NativeMarkdownRendering.typesets(
    "\\mathcal{L} = -\\text{ELBO} = \\boxed{-\\mathbb{E}_{z\\sim q_\\phi}\\big[\\log p_\\theta(x|z)\\big] + \\text{KL}}",
    display: true))
  check("\\dots typesets", NativeMarkdownRendering.typesets("\\mathbb{E}_{z_1\\dots z_k}"))
  let tableBar = NativeMarkdownRendering.formulas(in: "| a | $p(x\\|z)$ |\n|---|---|\n")
  check("\\| in a table row is a plain bar", tableBar.first?.latex == "p(x|z)")
  check("\\| outside a table stays a norm",
    NativeMarkdownRendering.formulas(in: "$q \\| p$").first?.latex == "q \\| p")
  // \boxed draws no frame: the formula is set as if it were not boxed.
  check("\\boxed is set without a frame",
    NativeMarkdownRendering.formulaWidth("a = \\boxed{x + y}") == NativeMarkdownRendering.formulaWidth("a = x + y"))
  // An underbrace inside \boxed is still drawn as a brace.
  if let boxedBrace = NativeMarkdownRendering.formulaMetrics("\\boxed{a = \\underbrace{b}_{c} + d}", display: true),
    let plain = NativeMarkdownRendering.formulaMetrics("a = b + d", display: true)
  {
    check("an underbrace inside \\boxed keeps its brace", boxedBrace.descent > plain.descent + 8)
  }
  // Modular arithmetic, from an ElGamal answer.
  for latex in [
    "r = g^k \\bmod p", "s = k^{-1}(H(m) - xr) \\bmod (p-1)", "g^{H(m)} \\equiv h^r \\cdot r^s \\pmod p",
    "a \\equiv b \\pmod{n}", "a \\mod p", "x \\pod{7}", "s = c_1^{\\,x} = g^{yx} \\bmod p",
    "\\boxed{m = c_2 \\cdot (c_1^{\\,x})^{-1} \\bmod p}",
  ] {
    check("\(latex) typesets", NativeMarkdownRendering.typesets(latex))
  }
  check("\\pmod keeps its argument",
    NativeMarkdownRendering.preparedLatex("a \\pmod{n}").first?.contains("mod}\\;n)") == true)
  check("\\bmod is not read inside another name",
    NativeMarkdownRendering.preparedLatex("\\bmodx").first == "\\bmodx")
  // A part that is only spacing, left after splitting at a brace.
  check("spacing next to a brace typesets", NativeMarkdownRendering.typesets(
    "\\boxed{\\;\\mathcal{L}(x) = \\underbrace{\\mathbb{E}_{q(z|x)}[\\log p(x|z)]}_{\\text{重构项}} \\;-\\; "
      + "\\underbrace{KL\\big(q(z|x)\\,\\|\\,p(z)\\big)}_{\\text{正则项}}\\;}", display: true))
  // `= \underbrace` keeps the space after `=` once the parts are laid out alone.
  if let spaced = NativeMarkdownRendering.formulaWidth("a = \\underbrace{x}"),
    let glued = NativeMarkdownRendering.formulaWidth("a="),
    let term = NativeMarkdownRendering.formulaWidth("x")
  {
    check("an operator before a brace keeps its space", spaced > glued + term + 2)
  }
  if let plain = NativeMarkdownRendering.formulaMetrics("x = y"),
    let arrow = NativeMarkdownRendering.formulaMetrics("x \\xrightarrow{a} y")
  {
    check("a labelled arrow keeps the baseline", abs(plain.descent - arrow.descent) < 1)
  }

  if let sample = ProcessInfo.processInfo.environment["SAMPLE"],
    let text = try? String(contentsOfFile: sample, encoding: .utf8)
  {
    let drawn = render(text)
    print("sample formulas:", NativeMarkdownRendering.formulas(in: text).count,
      "images:", attachments(drawn), "TeX left:", drawn.string.contains("\\"))
  }

  if let probe = ProcessInfo.processInfo.environment["PROBE"],
    let text = try? String(contentsOfFile: probe, encoding: .utf8)
  {
    for line in text.split(separator: "\n") where !line.isEmpty {
      let ok = NativeMarkdownRendering.typesets(String(line), display: true)
      let m = NativeMarkdownRendering.formulaMetrics(String(line), display: true)
      print(ok ? "OK  " : "FAIL", line, m.map { "a=\(Int($0.ascent)) d=\(Int($0.descent))" } ?? "")
      if !ok { print("     ->", NativeMarkdownRendering.preparedLatex(String(line))) }
    }
  }

  if let out = ProcessInfo.processInfo.environment["SNAPSHOT"] {
    let sample = """
      ## 1. 基本公式
      $$\\rho_\\tau(u) = u \\cdot (\\tau - \\mathbb{1}_{u<0})$$

      展开写：
      $$\(cases)$$

      其中 $\\tau \\in (0,1)$ 是目标分位点。

      > $\\tau = 0.9$ 时，低估的惩罚是高估的 **9 倍**。

      | 真实值 $y$ | 损失值 |
      |---|---|
      | 100 | $(1-0.9)\\times 20 = 2$ |

      $$\\frac{\\partial \\mathcal{L}_i}{\\partial \\hat{y}_i} = \(spaced)$$

      ```
      L = -log ŷ_k
      ```

      | Loss | $\\tau$ | What it predicts |
      |---|---|---|
      | MSE | none | Conditional mean $E[y \\mid x]$ |
      | Quantile Loss | $\\tau \\in (0,1)$ | Conditional $\\tau$-quantile $Q_\\tau[y \\mid x]$ |

      ```python
      # 同时预测下界、中位数、上界
      def quantile_loss(y_pred, y_true, tau=0.5):
          error = y_true - y_pred  # u = y - y_hat
          return torch.max(tau * error, (tau - 1) * error).mean()
      ```
      """
    let chosen = ProcessInfo.processInfo.environment["SAMPLE"]
      .flatMap { try? String(contentsOfFile: $0, encoding: .utf8) } ?? sample
    let png = MainActor.assumeIsolated { NativeMarkdownRendering.snapshot(chosen, width: 640, fontSize: CGFloat(Double(ProcessInfo.processInfo.environment["FONT"] ?? "14") ?? 14)) }
    try? png?.write(to: URL(fileURLWithPath: out))
    print("snapshot:", out)
  }

  print(failures == 0 ? "All checks passed" : "\(failures) check(s) failed")
  exit(failures == 0 ? 0 : 1)
#endif
