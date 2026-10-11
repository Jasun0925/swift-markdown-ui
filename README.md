# MarkdownUI

Display and customize Markdown text in SwiftUI.

> [!NOTE]
> A fork of [gonzalezreal/swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui),
> maintained by Chen Sun. The upstream `Markdown` view is unchanged. The fork adds
> [`NativeMarkdown`](#nativemarkdown-macos), a macOS renderer for chat answers with TeX math.
> Upstream is in [maintenance mode](https://github.com/gonzalezreal/swift-markdown-ui/discussions/437).

* [NativeMarkdown (macOS)](#nativemarkdown-macos)
* [Markdown view](#markdown-view)
* [Requirements](#requirements)
* [Installation](#installation)

## NativeMarkdown (macOS)

`NativeMarkdown` draws a whole document in one AppKit text view, so a selection runs from a
heading through a table to a code block, and Copy returns the text.

```swift
import MarkdownUI

NativeMarkdown(answer, fontSize: 14)
```

| Feature | Behavior |
|---|---|
| Math | `$…$` / `\(…\)` inline, `$$…$$` / `\[…\]` displayed, typeset with [SwiftMath](https://github.com/mgriebling/SwiftMath). Copy writes the TeX. |
| Parsing | Formulas are taken out before Markdown, so `_`, `*`, and `\|` inside them stay math. An unclosed `$` and prices like `$5` stay text. |
| Extra TeX | Chinese in `\text{}`, `\underbrace` / `\overbrace` with labels, `\xrightarrow`, `\bmod` / `\pmod`, `\dots`, `\tfrac`, `\operatorname`, `\\[4pt]`. `\boxed{}` is set without a frame. |
| Fallback | A formula that still fails is shown as its source. |
| Tables | `NSTextTable` cells, columns sized to their content. |
| Code | Fenced blocks with a Copy button. A named language is highlighted. |
| Layout | Spacing scales with the font size. The view sizes to its text and passes scrolling to its parent. |
| Safety | Raw HTML is shown as code, never run. Only `http`, `https`, and `mailto` links open. |

Checks run as an executable, because the Command Line Tools ship no XCTest:

```sh
swift run NativeMarkdownCheck
```

## Markdown view

The upstream SwiftUI view, for every platform. It follows the
[GitHub Flavored Markdown Spec](https://github.github.com/gfm/).

```swift
Markdown("**MarkdownUI** is a native Markdown renderer for SwiftUI.")
  .markdownTheme(.gitHub)
```

| To | Use |
|---|---|
| Pick a built-in theme | `.markdownTheme(.basic)`, `.gitHub`, or `.docC` |
| Change one text style | `.markdownTextStyle(\.code) { … }` |
| Change one block style | `.markdownBlockStyle(\.blockquote) { configuration in … }` |
| Write your own theme | `Theme().code { … }.paragraph { … }` |
| Build content in code | `Markdown { Heading(.level2) { "Title" } … }` |
| Parse once, show later | `Markdown(MarkdownContent(string))` |

The [upstream README](https://github.com/gonzalezreal/swift-markdown-ui#readme) and
[documentation](https://swiftpackageindex.com/gonzalezreal/swift-markdown-ui/main/documentation/markdownui)
cover each of these with examples. [Examples/Demo](Examples/Demo/) shows them in an app.

## Requirements

| | macOS | iOS | tvOS | watchOS |
|---|---|---|---|---|
| `Markdown` | 12.0 | 15.0 | 15.0 | 8.0 |
| Tables, multi-image paragraphs | 13.0 | 16.0 | 16.0 | 9.0 |
| `NativeMarkdown` | 12.0 (SwiftUI sizing needs 13.0) | none | none | none |

## Installation

```swift
.package(url: "https://github.com/Jasun0925/swift-markdown-ui", from: "2.5.3")
```

```swift
.target(name: "<target>", dependencies: [
  .product(name: "MarkdownUI", package: "swift-markdown-ui")
]),
```

In Xcode, choose **File ▸ Add Packages…** and enter the same URL. For upstream without
`NativeMarkdown`, use `https://github.com/gonzalezreal/swift-markdown-ui`.
