// swift-tools-version:5.6

import PackageDescription

let package = Package(
  name: "swift-markdown-ui",
  platforms: [
    .macOS(.v12),
    .iOS(.v15),
    .tvOS(.v15),
    .macCatalyst(.v15),
    .watchOS(.v8),
  ],
  products: [
    .library(
      name: "MarkdownUI",
      targets: ["MarkdownUI"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/gonzalezreal/NetworkImage", from: "6.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.10.0"),
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
        .product(name: "NetworkImage", package: "NetworkImage"),
        .product(name: "SwiftMath", package: "SwiftMath", condition: .when(platforms: [.macOS])),
      ]
    ),
    // Checks for the native macOS renderer. An executable rather than a test
    // target: the upstream snapshot tests need XCTest, which the Command Line
    // Tools do not ship. Run with `swift run NativeMarkdownCheck`.
    .executableTarget(
      name: "NativeMarkdownCheck",
      dependencies: ["MarkdownUI"],
      path: "Tests/NativeMarkdownCheck"
    ),
    .testTarget(
      name: "MarkdownUITests",
      dependencies: [
        "MarkdownUI",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      exclude: ["__Snapshots__"]
    ),
  ]
)
