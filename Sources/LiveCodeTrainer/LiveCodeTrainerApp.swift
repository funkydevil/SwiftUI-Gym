import SwiftUI

@main
struct LiveCodeTrainerApp: App {
    @NSApplicationDelegateAdaptor(TrainerAppDelegate.self)
    private var appDelegate

    var body: some Scene {
        WindowGroup {
            TrainerRootView()
                .frame(minWidth: 1_100, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            TrainerCommands()
        }
    }
}

private struct TrainerCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Run checks") {
                NotificationCenter.default.post(name: .runTrainerChecks, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command])

            Button("Run iOS preview") {
                NotificationCenter.default.post(name: .runSimulatorPreview, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command])

            Button("Reset solution") {
                NotificationCenter.default.post(name: .resetTrainerSolution, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}

extension Notification.Name {
    static let runTrainerChecks = Notification.Name("LiveCodeTrainer.runChecks")
    static let runSimulatorPreview = Notification.Name("LiveCodeTrainer.runSimulatorPreview")
    static let resetTrainerSolution = Notification.Name("LiveCodeTrainer.resetSolution")
}
