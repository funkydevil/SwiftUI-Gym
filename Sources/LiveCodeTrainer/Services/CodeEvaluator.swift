import Foundation
import Darwin

/// Performs read-only checks and compiler typechecking. It never executes the
/// submitted program and passes compiler arguments directly, without a shell.
struct CodeEvaluator: Sendable {
    func evaluate(
        source: String,
        requirements: [CodeRequirement] = [],
        options: CodeEvaluationOptions = .default
    ) -> CodeEvaluationResult {
        let checks = requirements.map { check($0, in: source) }

        guard source.count <= options.maximumSourceLength else {
            return CodeEvaluationResult(
                requirementChecks: checks,
                typecheck: TypecheckResult(
                    status: .skipped,
                    diagnostics: "Source is too large to evaluate safely.",
                    exitCode: nil,
                    duration: 0
                )
            )
        }

        let typecheck = typecheckWithSwiftCompiler(source, options: options)

        return CodeEvaluationResult(
            requirementChecks: checks,
            typecheck: typecheck
        )
    }

    private func check(
        _ requirement: CodeRequirement,
        in source: String
    ) -> RequirementCheckResult {
        let passed: Bool

        switch requirement.rule {
        case let .contains(text):
            passed = source.contains(text)
        case let .doesNotContain(text):
            passed = !source.contains(text)
        case let .matchesRegularExpression(pattern):
            passed = regularExpression(pattern, matches: source)
        case .hasBalancedDelimiters:
            passed = delimiterError(in: source) == nil
        }

        return RequirementCheckResult(
            id: requirement.id,
            title: requirement.title,
            passed: passed,
            message: passed ? nil : requirement.failureMessage
        )
    }

    private func regularExpression(_ pattern: String, matches source: String) -> Bool {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            return false
        }

        let range = NSRange(source.startIndex..., in: source)
        return expression.firstMatch(in: source, range: range) != nil
    }

    private func typecheckWithSwiftCompiler(
        _ source: String,
        options: CodeEvaluationOptions
    ) -> TypecheckResult {
        let start = Date()
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("LiveCodeTrainer-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            return unavailableResult(error.localizedDescription, startedAt: start)
        }

        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        let sourceURL = temporaryDirectory.appendingPathComponent("Submission.swift")
        let stdoutURL = temporaryDirectory.appendingPathComponent("stdout.txt")
        let stderrURL = temporaryDirectory.appendingPathComponent("stderr.txt")

        do {
            try source.write(to: sourceURL, atomically: true, encoding: .utf8)
            _ = fileManager.createFile(atPath: stdoutURL.path, contents: nil)
            _ = fileManager.createFile(atPath: stderrURL.path, contents: nil)

            let stdout = try FileHandle(forWritingTo: stdoutURL)
            let stderr = try FileHandle(forWritingTo: stderrURL)
            defer {
                try? stdout.close()
                try? stderr.close()
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = [
                "swiftc",
                "-typecheck",
                "-parse-as-library",
                sourceURL.path
            ]
            process.currentDirectoryURL = temporaryDirectory
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()

            let deadline = Date().addingTimeInterval(max(0.1, options.typecheckTimeout))
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.01)
            }

            if process.isRunning {
                process.terminate()
                let terminationDeadline = Date().addingTimeInterval(0.5)
                while process.isRunning && Date() < terminationDeadline {
                    Thread.sleep(forTimeInterval: 0.01)
                }
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                    process.waitUntilExit()
                }

                return TypecheckResult(
                    status: .timedOut,
                    diagnostics: "Typechecking exceeded the time limit.",
                    exitCode: nil,
                    duration: Date().timeIntervalSince(start)
                )
            }

            process.waitUntilExit()
            try? stdout.synchronize()
            try? stderr.synchronize()

            let output = readDiagnostics(
                stdoutURL: stdoutURL,
                stderrURL: stderrURL,
                limit: options.maximumDiagnosticLength
            )

            return TypecheckResult(
                status: process.terminationStatus == 0 ? .passed : .failed,
                diagnostics: output,
                exitCode: process.terminationStatus,
                duration: Date().timeIntervalSince(start)
            )
        } catch {
            return unavailableResult(error.localizedDescription, startedAt: start)
        }
    }

    private func readDiagnostics(
        stdoutURL: URL,
        stderrURL: URL,
        limit: Int
    ) -> String {
        let stdout = (try? String(contentsOf: stdoutURL, encoding: .utf8)) ?? ""
        let stderr = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
        let combined = [stderr, stdout]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard combined.count > limit else { return combined }
        return String(combined.prefix(max(0, limit))) + "\n…diagnostics truncated"
    }

    private func unavailableResult(
        _ message: String,
        startedAt start: Date
    ) -> TypecheckResult {
        TypecheckResult(
            status: .unavailable,
            diagnostics: "Swift compiler is unavailable: \(message)",
            exitCode: nil,
            duration: Date().timeIntervalSince(start)
        )
    }

    /// Ignores comments and string literals while checking bracket balance.
    private func delimiterError(in source: String) -> String? {
        enum LexerState {
            case code
            case lineComment
            case blockComment(depth: Int)
            case string(escaped: Bool)
        }

        let matching: [Character: Character] = [")": "(", "]": "[", "}": "{"]
        let opening = Set(matching.values)
        var stack: [Character] = []
        var state = LexerState.code
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]
            let nextIndex = source.index(after: index)
            let next = nextIndex < source.endIndex ? source[nextIndex] : nil

            switch state {
            case .code:
                if character == "/", next == "/" {
                    state = .lineComment
                    index = source.index(after: nextIndex)
                    continue
                }
                if character == "/", next == "*" {
                    state = .blockComment(depth: 1)
                    index = source.index(after: nextIndex)
                    continue
                }
                if character == "\"" {
                    state = .string(escaped: false)
                } else if opening.contains(character) {
                    stack.append(character)
                } else if let expected = matching[character] {
                    guard stack.popLast() == expected else {
                        return "Unexpected closing delimiter “\(character)”."
                    }
                }
            case .lineComment:
                if character == "\n" {
                    state = .code
                }
            case let .blockComment(depth):
                if character == "/", next == "*" {
                    state = .blockComment(depth: depth + 1)
                    index = source.index(after: nextIndex)
                    continue
                }
                if character == "*", next == "/" {
                    state = depth == 1 ? .code : .blockComment(depth: depth - 1)
                    index = source.index(after: nextIndex)
                    continue
                }
            case let .string(escaped):
                if escaped {
                    state = .string(escaped: false)
                } else if character == "\\" {
                    state = .string(escaped: true)
                } else if character == "\"" {
                    state = .code
                }
            }

            index = nextIndex
        }

        switch state {
        case .blockComment:
            return "Unterminated block comment."
        case .string:
            return "Unterminated string literal."
        case .code, .lineComment:
            break
        }

        if let delimiter = stack.last {
            return "Unclosed delimiter “\(delimiter)”."
        }
        return nil
    }
}
