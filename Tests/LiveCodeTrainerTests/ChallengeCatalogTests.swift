import Testing
@testable import LiveCodeTrainer

struct ChallengeCatalogTests {
    @Test
    func catalogContainsUniqueCompleteChallenges() {
        let challenges = ChallengeCatalog.all
        #expect(challenges.count >= 6)
        #expect(Set(challenges.map(\.id)).count == challenges.count)
        #expect(challenges.allSatisfy { !$0.starterCode.isEmpty })
        #expect(challenges.allSatisfy { !$0.referenceSolution.isEmpty })
        #expect(challenges.allSatisfy { !$0.requirements.isEmpty })
    }

    @Test
    func referenceSolutionsTypecheck() {
        for challenge in ChallengeCatalog.all {
            let result = CodeEvaluator().evaluate(source: challenge.referenceSolution)
            if result.typecheck.status != .passed {
                print("\(challenge.title): \(result.typecheck.diagnostics)")
            }
            #expect(result.typecheck.status == .passed)
        }
    }
}
