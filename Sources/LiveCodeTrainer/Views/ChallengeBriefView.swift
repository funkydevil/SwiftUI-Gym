import SwiftUI

struct ChallengeBriefView: View {
    let challenge: SwiftUIChallenge

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.title)
                            .font(.title2.bold())
                        Text(challenge.summary)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    DifficultyBadge(difficulty: challenge.difficulty)
                }

                Text(challenge.brief)
                    .textSelection(.enabled)

                FlowLayout(spacing: 6) {
                    ForEach(challenge.categories.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) {
                        Text($0.title)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(TrainerTheme.canvas)
    }
}

private struct DifficultyBadge: View {
    let difficulty: ChallengeDifficulty

    var body: some View {
        Text(difficulty.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch difficulty {
        case .beginner: TrainerTheme.success
        case .intermediate: TrainerTheme.warning
        case .advanced: TrainerTheme.danger
        }
    }
}

private extension ChallengeCategory {
    var title: String {
        switch self {
        case .layout: "Layout"
        case .stateManagement: "State"
        case .lists: "Lists"
        case .forms: "Forms"
        case .concurrency: "Concurrency"
        case .navigation: "Navigation"
        case .animation: "Animation"
        case .accessibility: "Accessibility"
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: proposal.height), subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return (CGSize(width: min(x, maxWidth), height: y + lineHeight), points)
    }
}
