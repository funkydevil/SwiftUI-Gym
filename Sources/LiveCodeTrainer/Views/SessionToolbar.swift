import SwiftUI

struct SessionToolbar: View {
    let store: TrainerStore

    var body: some View {
        HStack(spacing: 12) {
            Picker("Mode", selection: Bindable(store).mode) {
                ForEach(TrainingMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 140)

            Spacer()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Label(format(store.elapsed(at: context.date)), systemImage: "timer")
                    .monospacedDigit()
                    .foregroundStyle(store.isTimerRunning ? TrainerTheme.warning : .secondary)
            }

            Button(store.isTimerRunning ? "Pause" : "Start") {
                store.toggleTimer()
            }

            Button {
                Task { await store.runEvaluation() }
            } label: {
                if store.isEvaluating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Run checks", systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(TrainerTheme.accent)
            .disabled(store.isEvaluating)
            .keyboardShortcut("r", modifiers: [.command])

            Button {
                Task { await store.runSimulatorPreview() }
            } label: {
                Label("Preview", systemImage: "iphone")
            }
            .disabled(store.previewState == .building)
            .keyboardShortcut("p", modifiers: [.command])
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(.bar)
    }

    private func format(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private extension TrainingMode {
    var title: String {
        switch self {
        case .learning: "Learning"
        case .liveCoding: "Live Coding"
        case .interview: "Interview"
        }
    }
}
