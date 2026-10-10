#if os(macOS)
  import Foundation

  extension CodeHighlighter {
    /// The regular expressions for one language, in priority order.
    struct Grammar {
      let passes: [(Token, NSRegularExpression)]

      private static var cache: [String: Grammar] = [:]
      private static let lock = NSLock()

      static func named(_ language: String) -> Grammar {
        let key = aliases[language] ?? language
        lock.lock()
        defer { lock.unlock() }
        if let hit = cache[key] { return hit }
        let grammar = make(Spec.all[key] ?? Spec.generic)
        cache[key] = grammar
        return grammar
      }

      private static let aliases: [String: String] = [
        "py": "python", "python3": "python",
        "js": "javascript", "jsx": "javascript", "mjs": "javascript", "node": "javascript",
        "ts": "typescript", "tsx": "typescript",
        "sh": "shell", "bash": "shell", "zsh": "shell", "console": "shell",
        "c++": "cpp", "cc": "cpp", "hpp": "cpp", "h": "c",
        "golang": "go", "rs": "rust", "kt": "kotlin", "yml": "yaml",
      ]

      private static func make(_ spec: Spec) -> Grammar {
        var passes: [(Token, NSRegularExpression)] = []
        func add(_ token: Token, _ pattern: String, _ options: NSRegularExpression.Options = []) {
          if let regex = try? NSRegularExpression(pattern: pattern, options: options) {
            passes.append((token, regex))
          }
        }
        for pattern in spec.comments { add(.comment, pattern) }
        for pattern in spec.strings { add(.string, pattern) }
        add(.number, #"\b(?:0[xX][0-9a-fA-F_]+|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?)\b"#)
        if !spec.keywords.isEmpty {
          add(.keyword, "\\b(?:" + spec.keywords.joined(separator: "|") + ")\\b")
        }
        if !spec.types.isEmpty {
          add(.type, "\\b(?:" + spec.types.joined(separator: "|") + ")\\b")
        }
        return Grammar(passes: passes)
      }
    }
  }
#endif
