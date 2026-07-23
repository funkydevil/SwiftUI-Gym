import SwiftUI

struct ChallengeSidebar: View {
    let store: TrainerStore
    @State private var difficulty: ChallengeDifficulty?

    private var filteredChallenges: [SwiftUIChallenge] {
        guard let difficulty else { return store.challenges }
        return store.challenges.filter { $0.difficulty == difficulty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SwiftUI Gym")
                    .font(.title2.bold())
                Text("Live coding practice")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            Picker("Difficulty", selection: $difficulty) {
                Text("All").tag(ChallengeDifficulty?.none)
                ForEach(ChallengeDifficulty.allCases, id: \.self) { level in
                    Text(level.title).tag(Optional(level))
                }
            }
            .labelsHidden()
            .padding(.horizontal, 12)

            List(filteredChallenges, selection: Binding(
                get: { store.selectedChallengeID },
                set: { id in
                    if let challenge = store.challenges.first(where: { $0.id == id }) {
                        store.select(challenge)
                    }
                }
            )) { challenge in
                ChallengeRow(challenge: challenge)
                    .tag(challenge.id)
            }
            .listStyle(.sidebar)
        }
        .background(.bar)
    }
}

private struct ChallengeRow: View {
    let challenge: SwiftUIChallenge

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(challenge.title)
                .font(.headline)
                .lineLimit(2)
            HStack(spacing: 6) {
                Text(challenge.difficulty.title)
                Text("•")
                Label("\(challenge.estimatedMinutes) min", systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }
}

extension ChallengeDifficulty {
    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }
}
