import SwiftUI

struct InspectorPanel: View {
    let store: TrainerStore

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector", selection: Bindable(store).inspectorSection) {
                ForEach(TrainerInspectorSection.allCases, id: \.self) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)
            .background(.bar)

            switch store.inspectorSection {
            case .coach:
                CoachPanel(store: store)
            case .preview:
                SimulatorPreviewView(state: store.previewState) {
                    Task { await store.runSimulatorPreview() }
                }
            }
        }
    }
}

private extension TrainerInspectorSection {
    var title: String {
        switch self {
        case .coach: "Coach"
        case .preview: "Preview"
        }
    }

    var icon: String {
        switch self {
        case .coach: "checklist"
        case .preview: "iphone"
        }
    }
}
