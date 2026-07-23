import Foundation

/// A stable identifier used by persisted attempts and deep links.
public struct ChallengeID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

public enum ChallengeDifficulty: String, Codable, CaseIterable, Sendable {
    case beginner
    case intermediate
    case advanced
}

public enum ChallengeCategory: String, Codable, CaseIterable, Sendable {
    case layout
    case stateManagement
    case lists
    case forms
    case concurrency
    case navigation
    case animation
    case accessibility
}

public struct ChallengeHint: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case direction
        case apiReminder
        case codeFragment
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let content: String
    /// Suggested score deduction on a 0...100 scale.
    public let scorePenalty: Int

    public init(
        id: String,
        kind: Kind,
        title: String,
        content: String,
        scorePenalty: Int
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.content = content
        self.scorePenalty = scorePenalty
    }
}

/// A human-readable acceptance criterion. `verification` lets a future runner
/// decide whether it can check the criterion automatically.
public struct ChallengeRequirement: Identifiable, Codable, Hashable, Sendable {
    public enum Verification: String, Codable, Sendable {
        case compilation
        case sourceInspection
        case interaction
        case snapshot
        case manualReview
    }

    public let id: String
    public let text: String
    public let verification: Verification

    public init(id: String, text: String, verification: Verification) {
        self.id = id
        self.text = text
        self.verification = verification
    }
}

public struct SwiftUIChallenge: Identifiable, Codable, Hashable, Sendable {
    public var id: ChallengeID
    public var title: String
    public var summary: String
    public var brief: String
    public var difficulty: ChallengeDifficulty
    public var categories: Set<ChallengeCategory>
    public var estimatedMinutes: Int
    public var starterCode: String
    public var referenceSolution: String
    public var requirements: [ChallengeRequirement]
    public var hints: [ChallengeHint]
    public var followUpPrompts: [String]

    public init(
        id: ChallengeID,
        title: String,
        summary: String,
        brief: String,
        difficulty: ChallengeDifficulty,
        categories: Set<ChallengeCategory>,
        estimatedMinutes: Int,
        starterCode: String,
        referenceSolution: String,
        requirements: [ChallengeRequirement],
        hints: [ChallengeHint],
        followUpPrompts: [String] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.brief = brief
        self.difficulty = difficulty
        self.categories = categories
        self.estimatedMinutes = estimatedMinutes
        self.starterCode = starterCode
        self.referenceSolution = referenceSolution
        self.requirements = requirements
        self.hints = hints
        self.followUpPrompts = followUpPrompts
    }
}
