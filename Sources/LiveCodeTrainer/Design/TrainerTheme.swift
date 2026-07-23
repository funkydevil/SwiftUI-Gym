import SwiftUI

enum TrainerTheme {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let panel = Color(nsColor: .controlBackgroundColor)
    static let editor = Color(nsColor: .textBackgroundColor)
    static let accent = Color(red: 0.42, green: 0.36, blue: 0.95)
    static let success = Color(red: 0.22, green: 0.68, blue: 0.42)
    static let warning = Color(red: 0.95, green: 0.62, blue: 0.20)
    static let danger = Color(red: 0.92, green: 0.32, blue: 0.35)

    static let cornerRadius: CGFloat = 12
}

struct PanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(TrainerTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: TrainerTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TrainerTheme.cornerRadius, style: .continuous)
                    .stroke(.separator.opacity(0.65), lineWidth: 1)
            }
    }
}

extension View {
    func trainerPanel() -> some View {
        modifier(PanelStyle())
    }
}
