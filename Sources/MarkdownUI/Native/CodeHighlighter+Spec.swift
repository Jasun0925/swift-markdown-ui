#if os(macOS)
  import Foundation

  extension CodeHighlighter {
    /// The words and delimiters of one language.
    struct Spec {
      var comments: [String]
      var strings: [String]
      var keywords: [String]
      var types: [String] = []

      static let hashComment = #"#[^\n]*"#
      static let slashComment = #"//[^\n]*"#
      static let blockComment = #"/\*[\s\S]*?\*/"#
      static let doubleQuoted = #""(?:\\.|[^"\\\n])*""#
      static let singleQuoted = #"'(?:\\.|[^'\\\n])*'"#
      static let backtick = #"`(?:\\.|[^`\\])*`"#

      static let generic = Spec(
        comments: [hashComment, slashComment, blockComment],
        strings: [doubleQuoted, singleQuoted],
        keywords: [])

      static let all: [String: Spec] = [
        "python": Spec(
          comments: [hashComment],
          strings: [#"(?:[rbfuRBFU]{1,2})?"""[\s\S]*?""""#, #"(?:[rbfuRBFU]{1,2})?'''[\s\S]*?'''"#,
                    #"(?:[rbfuRBFU]{1,2})?"# + doubleQuoted, #"(?:[rbfuRBFU]{1,2})?"# + singleQuoted],
          keywords: ["and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del",
                     "elif", "else", "except", "finally", "for", "from", "global", "if", "import", "in",
                     "is", "lambda", "nonlocal", "not", "or", "pass", "raise", "return", "try", "while",
                     "with", "yield", "None", "True", "False", "self", "match", "case"],
          types: ["int", "float", "str", "bool", "list", "dict", "set", "tuple", "bytes", "object",
                  "print", "len", "range", "super", "isinstance", "enumerate", "zip", "map", "open"]),
        "javascript": Spec(
          comments: [slashComment, blockComment],
          strings: [backtick, doubleQuoted, singleQuoted],
          keywords: javascriptKeywords,
          types: ["Array", "Object", "String", "Number", "Boolean", "Promise", "Map", "Set", "console",
                  "JSON", "Math", "Error"]),
        "typescript": Spec(
          comments: [slashComment, blockComment],
          strings: [backtick, doubleQuoted, singleQuoted],
          keywords: javascriptKeywords + ["interface", "type", "enum", "implements", "namespace",
                                          "declare", "readonly", "private", "public", "protected",
                                          "abstract", "keyof", "satisfies", "as"],
          types: ["string", "number", "boolean", "any", "unknown", "never", "void", "Array",
                  "Promise", "Record", "Partial", "Map", "Set"]),
        "swift": Spec(
          comments: [slashComment, blockComment],
          strings: [#""""[\s\S]*?""""#, doubleQuoted],
          keywords: ["actor", "as", "async", "await", "break", "case", "catch", "class", "continue",
                     "default", "defer", "do", "else", "enum", "extension", "fallthrough", "false",
                     "fileprivate", "for", "func", "guard", "if", "import", "in", "init", "inout",
                     "internal", "is", "let", "nil", "open", "private", "protocol", "public",
                     "repeat", "return", "self", "Self", "static", "struct", "super", "switch",
                     "throw", "throws", "true", "try", "typealias", "var", "where", "while", "some", "any"],
          types: ["Int", "Double", "Float", "String", "Bool", "Array", "Dictionary", "Set",
                  "Optional", "Character", "Void", "Error", "CGFloat"]),
        "shell": Spec(
          comments: [hashComment],
          strings: [doubleQuoted, singleQuoted],
          keywords: ["if", "then", "else", "elif", "fi", "for", "in", "do", "done", "while", "until",
                     "case", "esac", "function", "return", "export", "local", "set", "unset",
                     "source", "echo", "cd", "exit"]),
        "go": Spec(
          comments: [slashComment, blockComment],
          strings: [backtick, doubleQuoted, singleQuoted],
          keywords: ["break", "case", "chan", "const", "continue", "default", "defer", "else",
                     "fallthrough", "for", "func", "go", "goto", "if", "import", "interface", "map",
                     "package", "range", "return", "select", "struct", "switch", "type", "var",
                     "nil", "true", "false"],
          types: ["int", "int64", "int32", "uint", "float64", "string", "bool", "byte", "rune",
                  "error", "any"]),
        "rust": Spec(
          comments: [slashComment, blockComment],
          strings: [doubleQuoted],
          keywords: ["as", "async", "await", "break", "const", "continue", "crate", "else", "enum",
                     "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop", "match",
                     "mod", "move", "mut", "pub", "ref", "return", "self", "Self", "static",
                     "struct", "super", "trait", "true", "type", "unsafe", "use", "where", "while"],
          types: ["i32", "i64", "u8", "u32", "u64", "usize", "f32", "f64", "bool", "char", "str",
                  "String", "Vec", "Option", "Result", "Box", "Some", "None", "Ok", "Err"]),
        "java": Spec(
          comments: [slashComment, blockComment],
          strings: [doubleQuoted, singleQuoted],
          keywords: cFamilyKeywords + ["class", "interface", "extends", "implements", "new",
                                       "public", "private", "protected", "static", "final",
                                       "abstract", "import", "package", "throws", "throw", "try",
                                       "catch", "finally", "this", "super", "null", "true",
                                       "false", "var", "instanceof"],
          types: ["int", "long", "double", "float", "boolean", "char", "byte", "void", "String",
                  "Integer", "List", "Map", "Object"]),
        "c": Spec(
          comments: [slashComment, blockComment, #"#\s*\w+[^\n]*"#],
          strings: [doubleQuoted, singleQuoted],
          keywords: cFamilyKeywords + ["struct", "union", "enum", "typedef", "static", "extern",
                                       "const", "sizeof", "NULL"],
          types: ["int", "long", "short", "char", "float", "double", "void", "unsigned", "signed",
                  "size_t", "bool"]),
        "cpp": Spec(
          comments: [slashComment, blockComment, #"#\s*\w+[^\n]*"#],
          strings: [doubleQuoted, singleQuoted],
          keywords: cFamilyKeywords + ["class", "struct", "namespace", "template", "typename",
                                       "public", "private", "protected", "virtual", "override",
                                       "const", "static", "new", "delete", "this", "nullptr",
                                       "true", "false", "using", "auto", "constexpr"],
          types: ["int", "long", "char", "float", "double", "void", "bool", "std", "string",
                  "vector", "size_t"]),
        "sql": Spec(
          comments: [#"--[^\n]*"#, blockComment],
          strings: [singleQuoted],
          keywords: ["SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "INSERT", "INTO", "VALUES",
                     "UPDATE", "SET", "DELETE", "CREATE", "TABLE", "ALTER", "DROP", "JOIN", "LEFT",
                     "RIGHT", "INNER", "OUTER", "ON", "GROUP", "BY", "ORDER", "HAVING", "LIMIT",
                     "AS", "NULL", "IS", "IN", "PRIMARY", "KEY", "DISTINCT",
                     "select", "from", "where", "and", "or", "insert", "into", "values", "update",
                     "set", "delete", "create", "table", "join", "on", "group", "by", "order",
                     "limit", "as", "null"]),
        "json": Spec(
          comments: [],
          strings: [doubleQuoted],
          keywords: ["true", "false", "null"]),
        "yaml": Spec(
          comments: [hashComment],
          strings: [doubleQuoted, singleQuoted],
          keywords: ["true", "false", "null", "yes", "no"]),
      ]

      private static let javascriptKeywords = [
        "async", "await", "break", "case", "catch", "class", "const", "continue", "default",
        "delete", "do", "else", "export", "extends", "false", "finally", "for", "from", "function",
        "if", "import", "in", "instanceof", "let", "new", "null", "of", "return", "super",
        "switch", "this", "throw", "true", "try", "typeof", "undefined", "var", "void", "while",
        "yield",
      ]

      private static let cFamilyKeywords = [
        "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
        "return", "goto",
      ]
    }
  }
#endif
