import SwiftUI

struct TrainerRootView: View {
    @State private var store = TrainerStore()

    var body: some View {
        HSplitView {
            ChallengeSidebar(store: store)
                .frame(minWidth: 220, idealWidth: 250, maxWidth: 300)

            VStack(spacing: 0) {
                SessionToolbar(store: store)
                VSplitView {
                    ChallengeBriefView(challenge: store.selectedChallenge)
                        .frame(minHeight: 170, idealHeight: 225)

                    EditorPane(store: store)
                        .frame(minHeight: 360)
                }
            }
            .frame(minWidth: 540)

            InspectorPanel(store: store)
                .frame(minWidth: 280, idealWidth: 330, maxWidth: 410)
        }
        .background(TrainerTheme.canvas)
        .onReceive(NotificationCenter.default.publisher(for: .runTrainerChecks)) { _ in
            Task { await store.runEvaluation() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .runSimulatorPreview)) { _ in
            Task { await store.runSimulatorPreview() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetTrainerSolution)) { _ in
            store.resetSolution()
        }
    }
}
