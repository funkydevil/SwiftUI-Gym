import AppKit
import SwiftUI

enum PreviewDisplayState: Equatable {
    case idle
    case building
    case success(imageData: Data)
    case error(diagnostics: String)
}

struct SimulatorPreviewView: View {
    let state: PreviewDisplayState
    let retry: () -> Void

    init(
        state: PreviewDisplayState,
        retry: @escaping () -> Void = {}
    ) {
        self.state = state
        self.retry = retry
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { proxy in
                deviceFrame
                    .frame(
                        width: deviceWidth(availableSize: proxy.size),
                        height: deviceHeight(availableSize: proxy.size)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
            }
        }
        .background(TrainerTheme.panel)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("iOS preview")
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label("iOS Preview", systemImage: "iphone")
                .font(.caption.weight(.semibold))

            Spacer()

            statusBadge
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(.bar)
    }

    private var deviceFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.black.opacity(0.95), .black.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.24), radius: 18, y: 8)

            screen
                .clipShape(RoundedRectangle(cornerRadius: 31, style: .continuous))
                .padding(7)

            VStack {
                Capsule()
                    .fill(.black.opacity(0.9))
                    .frame(width: 72, height: 20)
                    .padding(.top, 13)
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .aspectRatio(9 / 19.5, contentMode: .fit)
    }

    @ViewBuilder
    private var screen: some View {
        switch state {
        case .idle:
            placeholder(
                icon: "play.rectangle",
                title: "Preview is ready",
                message: "Run your solution to see it on an iPhone."
            )

        case .building:
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("Building preview…")
                    .font(.headline)
                Text("Compiling your SwiftUI view and launching Simulator.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))

        case let .success(imageData):
            if let image = NSImage(data: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .accessibilityLabel("Rendered SwiftUI preview")
            } else {
                invalidImageState
            }

        case let .error(diagnostics):
            errorState(diagnostics: diagnostics)
        }
    }

    private func placeholder(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(TrainerTheme.accent)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var invalidImageState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(TrainerTheme.warning)
            Text("Preview image is unavailable")
                .font(.headline)
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(TrainerTheme.accent)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func errorState(diagnostics: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(TrainerTheme.danger)

            Text("Preview failed")
                .font(.headline)

            ScrollView {
                Text(diagnostics.isEmpty ? "The build failed without diagnostics." : diagnostics)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxHeight: 180)
            .background(.black.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))

            Button("Try Again", systemImage: "arrow.clockwise", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(TrainerTheme.accent)
                .accessibilityHint("Builds the preview again")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch state {
        case .idle:
            badge(title: "Not run", icon: "circle", color: .secondary)
        case .building:
            badge(title: "Building", icon: "hammer.fill", color: TrainerTheme.warning)
        case .success:
            badge(title: "Live", icon: "checkmark.circle.fill", color: TrainerTheme.success)
        case .error:
            badge(title: "Failed", icon: "xmark.circle.fill", color: TrainerTheme.danger)
        }
    }

    private func badge(title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func deviceWidth(availableSize: CGSize) -> CGFloat {
        min(availableSize.width - 48, (availableSize.height - 48) * 9 / 19.5, 390)
    }

    private func deviceHeight(availableSize: CGSize) -> CGFloat {
        max(220, deviceWidth(availableSize: availableSize) * 19.5 / 9)
    }
}
