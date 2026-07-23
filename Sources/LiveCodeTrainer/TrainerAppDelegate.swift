import AppKit

final class TrainerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        DedicatedSimulatorManager.shared.shutdownSynchronously()
    }
}
