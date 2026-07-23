import Testing
@testable import LiveCodeTrainer

struct CodeEvaluatorTests {
    @Test
    func staticRequirementsReportPassAndFailure() {
        let requirements = [
            CodeRequirement(
                id: "view",
                title: "View",
                rule: .contains("struct Card"),
                failureMessage: "Missing Card"
            ),
            CodeRequirement(
                id: "state",
                title: "State",
                rule: .contains("@State"),
                failureMessage: "Missing state"
            )
        ]

        let result = CodeEvaluator().evaluate(
            source: "struct Card {}",
            requirements: requirements
        )

        #expect(result.requirementChecks[0].passed)
        #expect(!result.requirementChecks[1].passed)
    }

    @Test
    func swiftUISourceIsTypecheckedWithoutExecution() {
        let source = """
        import SwiftUI
        struct Card: View {
            var body: some View { Text("Hello") }
        }
        """

        let result = CodeEvaluator().evaluate(source: source)
        #expect(result.typecheck.status == .passed)
        #expect(result.passed)
    }

    @Test
    func unbalancedSwiftUISourceFails() {
        let source = """
        import SwiftUI
        struct Card: View {
            var body: some View { Text("Hello")
        """

        let result = CodeEvaluator().evaluate(source: source)
        #expect(result.typecheck.status == .failed)
        #expect(!result.passed)
    }
}
