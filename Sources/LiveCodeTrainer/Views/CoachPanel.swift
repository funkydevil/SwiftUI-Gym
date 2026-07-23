import SwiftUI

struct CoachPanel: View {
    let store: TrainerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                scoreHeader
                requirements
                evaluation
                hints
                reference
                followUps
            }
            .padding(14)
        }
        .background(.bar)
    }

    private var scoreHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Coach")
                    .font(.title3.bold())
                Text("Hints reduce the score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(store.score)")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(store.score >= 80 ? TrainerTheme.success : TrainerTheme.warning)
                .accessibilityLabel("Current score \(store.score)")
        }
    }

    private var requirements: some View {
        CoachSection(title: "Acceptance criteria", icon: "checklist") {
            ForEach(store.selectedChallenge.requirements) { requirement in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon(for: requirement))
                        .foregroundStyle(color(for: requirement))
                        .frame(width: 16)
                    Text(requirement.text)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var evaluation: some View {
        if let result = store.evaluation {
            CoachSection(title: "Latest run", icon: "terminal") {
                HStack {
                    statusIcon(result.typecheck.status)
                    Text(typecheckTitle(result.typecheck.status))
                        .font(.callout.weight(.semibold))
                    Spacer()
                    Text(result.typecheck.duration.formatted(.number.precision(.fractionLength(2))) + " s")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                ForEach(result.requirementChecks) { check in
                    Label(check.title, systemImage: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(check.passed ? TrainerTheme.success : TrainerTheme.danger)
                        .font(.callout)
                }

                if !result.typecheck.diagnostics.isEmpty {
                    Text(result.typecheck.diagnostics)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
                }
            }
        }
    }

    private var hints: some View {
        CoachSection(title: "Hints", icon: "lightbulb") {
            ForEach(store.selectedChallenge.hints) { hint in
                if store.revealedHintIDs.contains(hint.id) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(hint.title)
                            .font(.callout.weight(.semibold))
                        Text(hint.content)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } else {
                    Button {
                        store.reveal(hint)
                    } label: {
                        HStack {
                            Text("Reveal \(hint.title.lowercased())")
                            Spacer()
                            Text("−\(hint.scorePenalty)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var reference: some View {
        CoachSection(title: "Reference", icon: "book.closed") {
            Button(store.showReferenceSolution ? "Hide solution" : "Show solution (−20)") {
                store.toggleReferenceSolution()
            }
            .buttonStyle(.bordered)

            if store.showReferenceSolution {
                Text(store.selectedChallenge.referenceSolution)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
            }
        }
    }

    @ViewBuilder
    private var followUps: some View {
        if !store.selectedChallenge.followUpPrompts.isEmpty {
            CoachSection(title: "Interview follow-ups", icon: "person.wave.2") {
                ForEach(store.selectedChallenge.followUpPrompts, id: \.self) { prompt in
                    Text("• \(prompt)")
                        .font(.callout)
                }
            }
        }
    }

    private func icon(for requirement: ChallengeRequirement) -> String {
        guard let result = store.evaluation?.requirementChecks.first(where: { $0.id == requirement.id }) else {
            return "circle"
        }
        return result.passed ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private func color(for requirement: ChallengeRequirement) -> Color {
        guard let result = store.evaluation?.requirementChecks.first(where: { $0.id == requirement.id }) else {
            return .secondary
        }
        return result.passed ? TrainerTheme.success : TrainerTheme.danger
    }

    @ViewBuilder
    private func statusIcon(_ status: TypecheckStatus) -> some View {
        Image(systemName: status == .failed ? "xmark.octagon.fill" : "checkmark.seal.fill")
            .foregroundStyle(status == .failed ? TrainerTheme.danger : TrainerTheme.success)
    }

    private func typecheckTitle(_ status: TypecheckStatus) -> String {
        switch status {
        case .passed: "Compiler passed"
        case .failed: "Compiler errors"
        case .timedOut: "Compiler timed out"
        case .unavailable: "Compiler unavailable"
        case .skipped: "Syntax checks passed"
        }
    }
}

private struct CoachSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .trainerPanel()
    }
}
