import Testing
@testable import LiveCodeTrainer

struct SimulatorRunnerTests {
    @Test
    func extractsViewTypeNameFromValidSource() {
        let source = """
        import SwiftUI

        struct ProfileCard: View {
            var body: some View {
                Text("Ada")
            }
        }
        """

        #expect(SimulatorRunner.extractViewTypeName(from: source) == "ProfileCard")
    }

    @Test
    func returnsNilWhenSourceDoesNotDeclareAView() {
        let source = """
        import SwiftUI

        struct Profile {
            let name: String
        }
        """

        #expect(SimulatorRunner.extractViewTypeName(from: source) == nil)
    }

    @Test
    func extractsFirstViewWhenSourceDeclaresMultipleViews() {
        let source = """
        import SwiftUI

        struct PrimaryView: View {
            var body: some View { Text("Primary") }
        }

        struct SecondaryView: View {
            var body: some View { Text("Secondary") }
        }
        """

        #expect(SimulatorRunner.extractViewTypeName(from: source) == "PrimaryView")
    }

    @Test
    func ignoresViewDeclarationsInsideComments() {
        let source = """
        import SwiftUI

        // struct LineCommentView: View {}
        /*
         struct BlockCommentView: View {
             var body: some View { EmptyView() }
         }
        */
        struct ActualView: View {
            var body: some View { Text("Actual") }
        }
        """

        #expect(SimulatorRunner.extractViewTypeName(from: source) == "ActualView")
    }
}
