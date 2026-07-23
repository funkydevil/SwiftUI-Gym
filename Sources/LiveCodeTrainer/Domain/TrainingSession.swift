import Foundation

public enum TrainingMode: String, Codable, CaseIterable, Sendable {
    case learning
    case liveCoding
    case interview
}

public enum TrainingSessionStatus: String, Codable, Sendable {
    case ready
    case running
    case paused
    case submitted
    case completed
}

public struct RevealedHint: Codable, Hashable, Sendable {
    public let hintID: String
    public let revealedAt: Date

    public init(hintID: String, revealedAt: Date) {
        self.hintID = hintID
        self.revealedAt = revealedAt
    }
}

public struct RequirementResult: Identifiable, Codable, Hashable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        case notRun
        case passed
        case failed
        case needsReview
    }

    public var id: String { requirementID }
    public let requirementID: String
    public var outcome: Outcome
    public var message: String?

    public init(
        requirementID: String,
        outcome: Outcome = .notRun,
        message: String? = nil
    ) {
        self.requirementID = requirementID
        self.outcome = outcome
        self.message = message
    }
}

public struct TrainingSession: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let challengeID: ChallengeID
    public let mode: TrainingMode
    public let createdAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?
    public var status: TrainingSessionStatus
    public var sourceCode: String
    public var revealedHints: [RevealedHint]
    public var requirementResults: [RequirementResult]
    public var compilerOutput: String?
    public var score: Int?

    public init(
        id: UUID = UUID(),
        challengeID: ChallengeID,
        mode: TrainingMode,
        createdAt: Date = Date(),
        sourceCode: String
    ) {
        self.id = id
        self.challengeID = challengeID
        self.mode = mode
        self.createdAt = createdAt
        self.startedAt = nil
        self.finishedAt = nil
        self.status = .ready
        self.sourceCode = sourceCode
        self.revealedHints = []
        self.requirementResults = []
        self.compilerOutput = nil
        self.score = nil
    }
}

public struct ChallengeProgress: Identifiable, Codable, Hashable, Sendable {
    public var id: ChallengeID { challengeID }
    public let challengeID: ChallengeID
    public var attemptCount: Int
    public var bestScore: Int?
    public var fastestCompletionSeconds: TimeInterval?
    public var lastAttemptedAt: Date?
    public var isCompleted: Bool

    public init(
        challengeID: ChallengeID,
        attemptCount: Int = 0,
        bestScore: Int? = nil,
        fastestCompletionSeconds: TimeInterval? = nil,
        lastAttemptedAt: Date? = nil,
        isCompleted: Bool = false
    ) {
        self.challengeID = challengeID
        self.attemptCount = attemptCount
        self.bestScore = bestScore
        self.fastestCompletionSeconds = fastestCompletionSeconds
        self.lastAttemptedAt = lastAttemptedAt
        self.isCompleted = isCompleted
    }
}
