import Foundation
import Testing
@testable import LiveCodeTrainer

struct SwiftSyntaxHighlighterTests {
    @Test
    func classifiesCommonSwiftTokens() {
        let source = """
        import SwiftUI

        struct CounterView: View {
            @State private var count = 42
        }
        """

        let classified = classifiedTokens(in: source)

        #expect(classified["import"] == .keyword)
        #expect(classified["struct"] == .keyword)
        #expect(classified["CounterView"] == .type)
        #expect(classified["View"] == .type)
        #expect(classified["@State"] == .attribute)
        #expect(classified["private"] == .keyword)
        #expect(classified["42"] == .number)
    }

    @Test
    func commentMarkersInsideStringsStayStrings() {
        let source = """
        let url = "https://example.com/path"
        // A real comment
        """

        let tokens = tokenValues(in: source)

        #expect(tokens.contains {
            $0.value == "\"https://example.com/path\"" && $0.kind == .string
        })
        #expect(tokens.contains {
            $0.value == "// A real comment" && $0.kind == .comment
        })
    }

    @Test
    func supportsNestedBlockCommentsAndRawStrings() {
        let source = """
        /* outer /* nested */ done */
        let message = #"Use "quotes" here"#
        """

        let tokens = tokenValues(in: source)

        #expect(tokens.contains {
            $0.value == "/* outer /* nested */ done */" && $0.kind == .comment
        })
        #expect(tokens.contains {
            $0.value == "#\"Use \"quotes\" here\"#" && $0.kind == .string
        })
    }

    @Test
    func recognizesCompilerDirectivesAndOperators() {
        let source = """
        #if DEBUG
        let value = count + 1
        #endif
        """

        let tokens = tokenValues(in: source)

        #expect(tokens.contains { $0.value == "#if" && $0.kind == .directive })
        #expect(tokens.contains { $0.value == "+" && $0.kind == .operatorSymbol })
        #expect(tokens.contains { $0.value == "#endif" && $0.kind == .directive })
    }

    private func classifiedTokens(in source: String) -> [String: SwiftSyntaxKind] {
        Dictionary(
            uniqueKeysWithValues: tokenValues(in: source).map {
                ($0.value, $0.kind)
            }
        )
    }

    private func tokenValues(
        in source: String
    ) -> [(value: String, kind: SwiftSyntaxKind)] {
        let source = source as NSString
        return SwiftSyntaxHighlighter.tokens(in: source as String).map {
            (source.substring(with: $0.range), $0.kind)
        }
    }
}
