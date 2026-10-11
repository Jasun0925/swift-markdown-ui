// swift-tools-version:5.6

import PackageDescription

let package = Package(
  name: "swift-markdown-ui",
  // `NativeMarkdown` is AppKit, so this fork builds for macOS only. The
  // upstream SwiftUI `Markdown` view, its themes, and its iOS/tvOS/watchOS
  // support were removed; use gonzalezreal/swift-markdown-ui for those.
  platforms: [
    .macOS(.v12)
  ],
  products: [
    .library(
      name: "MarkdownUI",
      targets: ["MarkdownUI"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-cmark", from: "0.4.0"),
    // Typesets TeX for the native macOS renderer (`NativeMarkdown`).
    .package(url: "https://github.com/mgriebling/SwiftMath", from: "1.7.3"),
  ],
  targets: [
    .target(
      name: "MarkdownUI",
      dependencies: [
        .product(name: "cmark-gfm", package: "swift-cmark"),
        .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
        .product(name: "SwiftMath", package: "SwiftMath"),
      ]
    ),
    // Checks for the native macOS renderer. An executable rather than a test
    // target, because the Command Line Tools ship no XCTest. Run with
    // `swift run NativeMarkdownCheck`.
    .executableTarget(
      name: "NativeMarkdownCheck",
      dependencies: ["MarkdownUI"],
      path: "Tests/NativeMarkdownCheck"
    ),
  ]
)
