import SwiftUI

struct EditorPane: View {
    let store: TrainerStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Solution.swift", systemImage: "swift")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(store.sourceCode.split(separator: "\n", omittingEmptySubsequences: false).count) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Menu {
                    Button("Reset to starter code", role: .destructive) {
                        store.resetSolution()
                    }
                    Button("Copy reference solution") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(store.selectedChallenge.referenceSolution, forType: .string)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(.bar)

            CodeEditorView(text: Bindable(store).sourceCode)
        }
    }
}
