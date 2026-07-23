import Foundation

/// A lightweight, serializable requirement that can be checked without compiling
/// untrusted source code.
struct CodeRequirement: Identifiable, Codable, Hashable, Sendable {
    enum Rule: Codable, Hashable, Sendable {
        case contains(String)
        case doesNotContain(String)
        case matchesRegularExpression(String)
        case hasBalancedDelimiters
    }

    let id: String
    let title: String
    let rule: Rule
    let failureMessage: String

    init(
        id: String = UUID().uuidString,
        title: String,
        rule: Rule,
        failureMessage: String
    ) {
        self.id = id
        self.title = title
        self.rule = rule
        self.failureMessage = failureMessage
    }
}

struct RequirementCheckResult: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let passed: Bool
    let message: String?
}

enum TypecheckStatus: String, Codable, Hashable, Sendable {
    case passed
    case failed
    case timedOut
    case unavailable
    case skipped
}

struct TypecheckResult: Codable, Hashable, Sendable {
    let status: TypecheckStatus
    let diagnostics: String
    let exitCode: Int32?
    let duration: TimeInterval
}

struct CodeEvaluationResult: Codable, Hashable, Sendable {
    let requirementChecks: [RequirementCheckResult]
    let typecheck: TypecheckResult

    var passed: Bool {
        requirementChecks.allSatisfy(\.passed)
            && (typecheck.status == .passed || typecheck.status == .skipped)
    }
}

struct CodeEvaluationOptions: Hashable, Sendable {
    var typecheckTimeout: TimeInterval = 5
    var maximumSourceLength: Int = 200_000
    var maximumDiagnosticLength: Int = 32_000

    static let `default` = CodeEvaluationOptions()
}
