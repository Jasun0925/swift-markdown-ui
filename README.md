# MarkdownUI (NativeMarkdown fork)

A macOS Markdown renderer for chat answers, with TeX math.

> [!NOTE]
> A fork of [gonzalezreal/swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui),
> maintained by Chen Sun. It keeps upstream's cmark-gfm parser and replaces the SwiftUI
> `Markdown` view, its themes, and its iOS/tvOS/watchOS support with `NativeMarkdown`.
> For the SwiftUI view, use upstream.

## NativeMarkdown

`NativeMarkdown` draws a whole document in one AppKit text view, so a selection runs from a
heading through a table to a code block, and Copy returns the text.

```swift
import MarkdownUI

NativeMarkdown(answer, fontSize: 14, imageDirectory: workspaceURL)
```

| Feature | Behavior |
|---|---|
| Math | `$…$` / `\(…\)` inline, `$$…$$` / `\[…\]` displayed, typeset with [SwiftMath](https://github.com/mgriebling/SwiftMath). Copy writes the TeX. |
| Parsing | Formulas are taken out before Markdown, so `_`, `*`, and `\|` inside them stay math. An unclosed `$` and prices like `$5` stay text. |
| Extra TeX | Chinese in `\text{}`, `\underbrace` / `\overbrace` with labels, `\xrightarrow`, `\bmod` / `\pmod`, `\dots`, `\tfrac`, `\operatorname`, `\\[4pt]`. `\boxed{}` is set without a frame. |
| Fallback | A formula that still fails is shown as its source. |
| Images | `![alt](path)` is read from `imageDirectory`: only image files inside it, never through `../` or a symlink out, never from the web. Wide images fit the column. |
| Tables | `NSTextTable` cells, columns sized to their content. |
| Code | Fenced blocks with a Copy button. A named language is highlighted. |
| Layout | Spacing scales with the font size. The view sizes to its text and passes scrolling to its parent. |
| Safety | Raw HTML is shown as code, never run. Only `http`, `https`, and `mailto` links open. |

## Requirements

macOS 12 or later; the SwiftUI sizing `NativeMarkdown` uses needs macOS 13.

## Installation

```swift
.package(url: "https://github.com/Jasun0925/swift-markdown-ui", from: "3.0.0")
```

```swift
.target(name: "<target>", dependencies: [
  .product(name: "MarkdownUI", package: "swift-markdown-ui")
]),
```

## Checks

The Command Line Tools ship no XCTest, so the checks are an executable:

```sh
swift run NativeMarkdownCheck
```
