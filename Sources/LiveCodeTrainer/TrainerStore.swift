import Foundation
import Observation

enum TrainerInspectorSection: String, CaseIterable {
    case coach
    case preview
}

@MainActor
@Observable
final class TrainerStore {
    private(set) var challenges = ChallengeCatalog.all
    var selectedChallengeID: ChallengeID
    var mode: TrainingMode = .liveCoding
    var sourceCode: String
    var revealedHintIDs: Set<String> = []
    var evaluation: CodeEvaluationResult?
    var isEvaluating = false
    var inspectorSection: TrainerInspectorSection = .coach
    var previewState: PreviewDisplayState = .idle
    private(set) var lastSimulatorRun: SimulatorRunResult?
    var showReferenceSolution = false
    private(set) var hasRevealedReference = false
    var sessionStartedAt: Date?
    var accumulatedSeconds: TimeInterval = 0
    var isTimerRunning = false

    private var drafts: [ChallengeID: String] = [:]

    init() {
        let initial = ChallengeCatalog.all[0]
        selectedChallengeID = initial.id
        sourceCode = initial.starterCode
    }

    var selectedChallenge: SwiftUIChallenge {
        challenges.first { $0.id == selectedChallengeID } ?? challenges[0]
    }

    var score: Int {
        let penalty = selectedChallenge.hints
            .filter { revealedHintIDs.contains($0.id) }
            .reduce(0) { $0 + $1.scorePenalty }
        return max(0, 100 - penalty - (hasRevealedReference ? 20 : 0))
    }

    func select(_ challenge: SwiftUIChallenge) {
        guard challenge.id != selectedChallengeID else { return }
        drafts[selectedChallengeID] = sourceCode
        selectedChallengeID = challenge.id
        sourceCode = drafts[challenge.id] ?? challenge.starterCode
        revealedHintIDs = []
        evaluation = nil
        previewState = .idle
        lastSimulatorRun = nil
        showReferenceSolution = false
        hasRevealedReference = false
        resetTimer()
    }

    func reveal(_ hint: ChallengeHint) {
        revealedHintIDs.insert(hint.id)
    }

    func toggleTimer() {
        if isTimerRunning {
            pauseTimer()
        } else {
            sessionStartedAt = Date()
            isTimerRunning = true
        }
    }

    func elapsed(at date: Date = Date()) -> TimeInterval {
        accumulatedSeconds + (isTimerRunning ? date.timeIntervalSince(sessionStartedAt ?? date) : 0)
    }

    func resetSolution() {
        sourceCode = selectedChallenge.starterCode
        evaluation = nil
        showReferenceSolution = false
    }

    func toggleReferenceSolution() {
        if !showReferenceSolution {
            hasRevealedReference = true
        }
        showReferenceSolution.toggle()
    }

    func resetTimer() {
        accumulatedSeconds = 0
        sessionStartedAt = nil
        isTimerRunning = false
    }

    func runEvaluation() async {
        guard !isEvaluating else { return }
        isEvaluating = true
        let source = sourceCode
        let requirements = EvaluationRequirementFactory.make(for: selectedChallenge)

        let result = await Task.detached(priority: .userInitiated) {
            CodeEvaluator().evaluate(source: source, requirements: requirements)
        }.value

        evaluation = result
        isEvaluating = false
    }

    func runSimulatorPreview() async {
        guard previewState != .building else { return }
        inspectorSection = .preview
        previewState = .building
        let source = sourceCode

        do {
            let result = try await SimulatorRunner().run(source: source)
            lastSimulatorRun = result
            previewState = .success(imageData: result.screenshotData)
        } catch let error as SimulatorRunnerError {
            let diagnostics = [error.message, error.commandOutput]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
            previewState = .error(diagnostics: diagnostics)
        } catch {
            previewState = .error(diagnostics: error.localizedDescription)
        }
    }

    private func pauseTimer() {
        accumulatedSeconds = elapsed()
        sessionStartedAt = nil
        isTimerRunning = false
    }
}

private enum EvaluationRequirementFactory {
    static func make(for challenge: SwiftUIChallenge) -> [CodeRequirement] {
        var rules: [CodeRequirement] = [
            CodeRequirement(
                id: "balanced",
                title: "Balanced delimiters",
                rule: .hasBalancedDelimiters,
                failureMessage: "Check brackets, braces, comments, and string literals."
            ),
            CodeRequirement(
                id: "view",
                title: "Declares a SwiftUI View",
                rule: .matchesRegularExpression(#"struct\s+\w+\s*:\s*View"#),
                failureMessage: "Declare a type that conforms to View."
            )
        ]

        let mappedTokens: [(String, String, String)] = switch challenge.id.rawValue {
        case "profile-card":
            [("layout", "Uses stack layout", #"\b(VStack|HStack|Grid)\b"#)]
        case "follow-button-state":
            [("state", "Owns local state", #"@State\b"#), ("toggle", "Toggles state", #"\.toggle\s*\("#)]
        case "editable-grocery-list":
            [("list", "Uses List", #"\bList\b"#), ("delete", "Supports deletion", #"\.onDelete\b"#)]
        case "validated-sign-up-form":
            [("secure", "Uses SecureField", #"\bSecureField\b"#), ("disabled", "Disables invalid submission", #"\.disabled\b"#)]
        case "async-user-directory":
            [("task", "Starts async work", #"\.task\b"#), ("await", "Awaits the loader", #"\bawait\b"#)]
        case "typed-navigation":
            [("navigation", "Uses NavigationStack", #"\bNavigationStack\b"#), ("destination", "Defines a destination", #"\.navigationDestination\b"#)]
        case "expandable-card":
            [("animation", "Animates state changes", #"\b(withAnimation|animation)\b"#)]
        case "accessible-stepper":
            [("accessibility", "Adds accessibility behavior", #"\.accessibility\w*\b"#)]
        default:
            []
        }

        rules.append(contentsOf: mappedTokens.map { id, title, pattern in
            CodeRequirement(
                id: id,
                title: title,
                rule: .matchesRegularExpression(pattern),
                failureMessage: "The expected implementation detail was not found yet."
            )
        })
        return rules
    }
}
