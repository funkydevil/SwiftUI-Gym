import Foundation

enum SwiftSyntaxKind: Hashable, Sendable {
    case keyword
    case type
    case string
    case number
    case comment
    case attribute
    case directive
    case operatorSymbol
}

struct SwiftSyntaxToken: Hashable, Sendable {
    let range: NSRange
    let kind: SwiftSyntaxKind
}

/// A lightweight lexer for editor coloring. It deliberately does not parse
/// Swift; it only identifies stable lexical regions without external packages.
enum SwiftSyntaxHighlighter {
    private static let keywords: Set<String> = [
        "actor", "any", "as", "associatedtype", "async", "await", "break",
        "case", "catch", "class", "continue", "convenience", "copy", "consume",
        "consuming", "default", "defer", "deinit", "didSet", "distributed", "do",
        "dynamic", "each", "else", "enum", "extension", "fallthrough", "false",
        "fileprivate", "final", "for", "func", "get", "guard", "if", "import",
        "indirect", "in", "infix", "init", "inout", "internal", "is", "isolated",
        "lazy", "let", "macro", "mutating", "nonisolated", "nonmutating", "nil",
        "open", "operator", "optional", "override", "package", "postfix",
        "precedencegroup", "prefix", "private", "protocol", "public", "repeat",
        "required", "rethrows", "return", "self", "set", "some", "static",
        "struct", "subscript", "super", "switch", "throws", "true", "try",
        "typealias", "unowned", "var", "weak", "where", "while", "willSet"
    ]

    private static let knownTypes: Set<String> = [
        "Any", "AnyObject", "Array", "Bool", "Character", "CGFloat", "Data",
        "Date", "Dictionary", "Double", "Error", "Float", "Int", "Never",
        "Optional", "Result", "Set", "String", "Substring", "Task", "UInt",
        "URL", "UUID", "View"
    ]

    private static let operatorCharacters = CharacterSet(
        charactersIn: "/=-+!*%<>&|^~?."
    )

    static func tokens(in source: String) -> [SwiftSyntaxToken] {
        let source = source as NSString
        let length = source.length
        var tokens: [SwiftSyntaxToken] = []
        var index = 0

        while index < length {
            let character = source.character(at: index)

            if isWhitespace(character) {
                index += 1
                continue
            }

            if matches("//", in: source, at: index) {
                let start = index
                index += 2
                while index < length, !isNewline(source.character(at: index)) {
                    index += 1
                }
                tokens.append(token(from: start, to: index, kind: .comment))
                continue
            }

            if matches("/*", in: source, at: index) {
                let start = index
                var depth = 1
                index += 2
                while index < length, depth > 0 {
                    if matches("/*", in: source, at: index) {
                        depth += 1
                        index += 2
                    } else if matches("*/", in: source, at: index) {
                        depth -= 1
                        index += 2
                    } else {
                        index += 1
                    }
                }
                tokens.append(token(from: start, to: index, kind: .comment))
                continue
            }

            if let stringEnd = endOfString(in: source, startingAt: index) {
                tokens.append(token(from: index, to: stringEnd, kind: .string))
                index = stringEnd
                continue
            }

            if character == ascii("@"), index + 1 < length,
               isIdentifierStart(source.character(at: index + 1)) {
                let start = index
                index = endOfIdentifier(in: source, startingAt: index + 1)
                tokens.append(token(from: start, to: index, kind: .attribute))
                continue
            }

            if character == ascii("#"), index + 1 < length,
               isIdentifierStart(source.character(at: index + 1)) {
                let start = index
                index = endOfIdentifier(in: source, startingAt: index + 1)
                tokens.append(token(from: start, to: index, kind: .directive))
                continue
            }

            if isDigit(character) {
                let start = index
                index += 1
                while index < length {
                    let current = source.character(at: index)
                    guard isDigit(current)
                        || isASCIILetter(current)
                        || current == ascii("_")
                        || current == ascii(".")
                    else {
                        break
                    }
                    index += 1
                }
                tokens.append(token(from: start, to: index, kind: .number))
                continue
            }

            if isIdentifierStart(character) {
                let start = index
                index = endOfIdentifier(in: source, startingAt: index)
                let value = source.substring(with: NSRange(location: start, length: index - start))

                if keywords.contains(value) {
                    tokens.append(token(from: start, to: index, kind: .keyword))
                } else if knownTypes.contains(value) || value.first?.isUppercase == true {
                    tokens.append(token(from: start, to: index, kind: .type))
                }
                continue
            }

            if let scalar = UnicodeScalar(character),
               operatorCharacters.contains(scalar) {
                let start = index
                index += 1
                while index < length,
                      let next = UnicodeScalar(source.character(at: index)),
                      operatorCharacters.contains(next) {
                    index += 1
                }
                tokens.append(token(from: start, to: index, kind: .operatorSymbol))
                continue
            }

            index += 1
        }

        return tokens
    }

    private static func endOfString(
        in source: NSString,
        startingAt start: Int
    ) -> Int? {
        let length = source.length
        var hashCount = 0
        while start + hashCount < length,
              source.character(at: start + hashCount) == ascii("#") {
            hashCount += 1
        }

        let quoteIndex = start + hashCount
        guard quoteIndex < length,
              source.character(at: quoteIndex) == ascii("\"")
        else {
            return nil
        }

        let isMultiline = matches("\"\"\"", in: source, at: quoteIndex)
        var index = quoteIndex + (isMultiline ? 3 : 1)

        while index < length {
            if !isMultiline, hashCount == 0,
               source.character(at: index) == ascii("\\") {
                index = min(index + 2, length)
                continue
            }

            let delimiter = isMultiline ? "\"\"\"" : "\""
            if matches(delimiter, in: source, at: index) {
                let quoteEnd = index + delimiter.utf16.count
                var matchedHashes = 0
                while matchedHashes < hashCount,
                      quoteEnd + matchedHashes < length,
                      source.character(at: quoteEnd + matchedHashes) == ascii("#") {
                    matchedHashes += 1
                }
                if matchedHashes == hashCount {
                    return quoteEnd + hashCount
                }
            }
            index += 1
        }

        return length
    }

    private static func endOfIdentifier(
        in source: NSString,
        startingAt start: Int
    ) -> Int {
        var index = start
        while index < source.length, isIdentifierBody(source.character(at: index)) {
            index += 1
        }
        return index
    }

    private static func matches(
        _ value: String,
        in source: NSString,
        at index: Int
    ) -> Bool {
        let count = value.utf16.count
        guard index + count <= source.length else {
            return false
        }
        return source.substring(
            with: NSRange(location: index, length: count)
        ) == value
    }

    private static func token(
        from start: Int,
        to end: Int,
        kind: SwiftSyntaxKind
    ) -> SwiftSyntaxToken {
        SwiftSyntaxToken(
            range: NSRange(location: start, length: max(end - start, 0)),
            kind: kind
        )
    }

    private static func ascii(_ character: Character) -> unichar {
        character.asciiValue.map(unichar.init) ?? 0
    }

    private static func isWhitespace(_ character: unichar) -> Bool {
        character == ascii(" ")
            || character == ascii("\t")
            || isNewline(character)
    }

    private static func isNewline(_ character: unichar) -> Bool {
        character == 10 || character == 13
    }

    private static func isDigit(_ character: unichar) -> Bool {
        character >= ascii("0") && character <= ascii("9")
    }

    private static func isASCIILetter(_ character: unichar) -> Bool {
        (character >= ascii("a") && character <= ascii("z"))
            || (character >= ascii("A") && character <= ascii("Z"))
    }

    private static func isIdentifierStart(_ character: unichar) -> Bool {
        isASCIILetter(character)
            || character == ascii("_")
            || character > 127
    }

    private static func isIdentifierBody(_ character: unichar) -> Bool {
        isIdentifierStart(character) || isDigit(character)
    }
}
