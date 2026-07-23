import Foundation
import Darwin

struct SimulatorRunner: Sendable {
    func run(
        source: String,
        options: SimulatorRunnerOptions = .default
    ) async throws -> SimulatorRunResult {
        let task = Task.detached(priority: .userInitiated) {
            try Self.runSynchronously(source: source, options: options)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    static func extractViewTypeName(from source: String) -> String? {
        let searchableSource = sourceMaskingCommentsAndStrings(source)
        let pattern = #"\bstruct\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>{}]*>)?\s*:\s*[^{;]*\bView\b"#

        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: searchableSource,
                range: NSRange(searchableSource.startIndex..., in: searchableSource)
              ),
              let nameRange = Range(match.range(at: 1), in: searchableSource)
        else {
            return nil
        }

        return String(searchableSource[nameRange])
    }

    private static func runSynchronously(
        source: String,
        options: SimulatorRunnerOptions
    ) throws -> SimulatorRunResult {
        let startedAt = Date()
        var logs: [SimulatorRunLog] = []

        func append(
            _ stage: SimulatorRunStage,
            _ message: String,
            level: SimulatorRunLog.Level = .info
        ) {
            logs.append(SimulatorRunLog(stage: stage, level: level, message: message))
        }

        guard !Task.isCancelled else {
            throw runnerError(
                kind: .cancelled,
                stage: .preparing,
                message: "Simulator preview was cancelled.",
                logs: logs
            )
        }

        guard let viewTypeName = extractViewTypeName(from: source) else {
            throw runnerError(
                kind: .invalidSource,
                stage: .preparing,
                message: "No SwiftUI view was found. Declare a struct that conforms to View.",
                logs: logs
            )
        }
        append(.preparing, "Found SwiftUI view \(viewTypeName).")

        let fileManager = FileManager.default
        let workingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("LiveCodePreview-\(UUID().uuidString)", isDirectory: true)
        let appURL = workingDirectory.appendingPathComponent("LiveCodePreview.app", isDirectory: true)
        let executableURL = appURL.appendingPathComponent("LiveCodePreview")
        let submissionURL = workingDirectory.appendingPathComponent("Submission.swift")
        let hostURL = workingDirectory.appendingPathComponent("PreviewHost.swift")
        let screenshotURL = workingDirectory.appendingPathComponent("Screenshot.png")
        let bundleIdentifier = "dev.livecodetrainer.preview"

        do {
            try fileManager.createDirectory(
                at: appURL,
                withIntermediateDirectories: true
            )
            try source.write(to: submissionURL, atomically: true, encoding: .utf8)
            try hostSource(viewTypeName: viewTypeName)
                .write(to: hostURL, atomically: true, encoding: .utf8)
            try writeInfoPlist(
                to: appURL.appendingPathComponent("Info.plist"),
                bundleIdentifier: bundleIdentifier,
                minimumIOSVersion: options.minimumIOSVersion
            )
        } catch {
            throw runnerError(
                kind: .unavailable,
                stage: .preparing,
                message: "Could not prepare the preview app: \(error.localizedDescription)",
                logs: logs
            )
        }
        defer { try? fileManager.removeItem(at: workingDirectory) }
        append(.preparing, "Created an isolated preview app wrapper.")

        let sdkResult: CommandResult
        do {
            sdkResult = try execute(
                executable: "/usr/bin/xcrun",
                arguments: ["--sdk", "iphonesimulator", "--show-sdk-path"],
                currentDirectory: workingDirectory,
                timeout: options.commandTimeout,
                maximumOutputLength: options.maximumLogLength
            )
        } catch {
            throw commandError(
                error,
                stage: .locatingSDK,
                action: "locate the iOS Simulator SDK",
                logs: logs
            )
        }
        let sdkPath = sdkResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sdkResult.exitCode == 0, !sdkPath.isEmpty else {
            throw failedCommandError(
                stage: .locatingSDK,
                action: "locate the iOS Simulator SDK",
                result: sdkResult,
                logs: logs
            )
        }
        append(.locatingSDK, "Using iOS Simulator SDK at \(sdkPath).")

        let compileArguments = [
            "--sdk", "iphonesimulator",
            "swiftc",
            "-sdk", sdkPath,
            "-target", "arm64-apple-ios\(options.minimumIOSVersion)-simulator",
            "-parse-as-library",
            "-emit-executable",
            submissionURL.path,
            hostURL.path,
            "-o", executableURL.path
        ]
        let compileResult: CommandResult
        do {
            compileResult = try execute(
                executable: "/usr/bin/xcrun",
                arguments: compileArguments,
                currentDirectory: workingDirectory,
                timeout: options.compilationTimeout,
                maximumOutputLength: options.maximumLogLength
            )
        } catch {
            throw commandError(
                error,
                stage: .compiling,
                action: "compile the SwiftUI preview",
                logs: logs
            )
        }
        guard compileResult.exitCode == 0 else {
            throw failedCommandError(
                stage: .compiling,
                action: "compile the SwiftUI preview",
                result: compileResult,
                logs: logs
            )
        }
        append(.compiling, "Compiled the preview app successfully.")
        appendOutput(compileResult.combinedOutput, stage: .compiling, to: &logs)

        guard !Task.isCancelled else {
            throw runnerError(
                kind: .cancelled,
                stage: .locatingSimulator,
                message: "Simulator preview was cancelled.",
                logs: logs
            )
        }

        do {
            return try DedicatedSimulatorManager.shared.withExclusiveBootedDevice { dedicatedDevice in
                let device = SimulatorDevice(
                    udid: dedicatedDevice.udid,
                    name: dedicatedDevice.name,
                    runtimeIdentifier: dedicatedDevice.runtimeIdentifier,
                    deviceSetPath: dedicatedDevice.deviceSetPath
                )
                append(.locatingSimulator, "Using hidden dedicated \(device.name) (\(device.udid)).")

                try runSimctl(
                    ["install", device.udid, appURL.path],
                    deviceSetPath: device.deviceSetPath,
                    stage: .installing,
                    action: "install the preview app",
                    workingDirectory: workingDirectory,
                    options: options,
                    logs: &logs
                )
                append(.installing, "Installed the preview app.")

                try runSimctl(
                    ["launch", device.udid, bundleIdentifier],
                    deviceSetPath: device.deviceSetPath,
                    stage: .launching,
                    action: "launch the preview app",
                    workingDirectory: workingDirectory,
                    options: options,
                    logs: &logs
                )
                append(.launching, "Launched the preview app.")

                let settlingTime = min(max(0, options.launchSettlingTime), 5)
                let settlingDeadline = Date().addingTimeInterval(settlingTime)
                while Date() < settlingDeadline {
                    guard !Task.isCancelled else {
                        throw runnerError(
                            kind: .cancelled,
                            stage: .capturingScreenshot,
                            message: "Simulator preview was cancelled.",
                            logs: logs
                        )
                    }
                    Thread.sleep(
                        forTimeInterval: max(
                            0.001,
                            min(0.05, settlingDeadline.timeIntervalSinceNow)
                        )
                    )
                }

                try runSimctl(
                    ["io", device.udid, "screenshot", screenshotURL.path],
                    deviceSetPath: device.deviceSetPath,
                    stage: .capturingScreenshot,
                    action: "capture the Simulator screenshot",
                    workingDirectory: workingDirectory,
                    options: options,
                    logs: &logs
                )

                let screenshotData: Data
                do {
                    screenshotData = try Data(contentsOf: screenshotURL)
                } catch {
                    throw runnerError(
                        kind: .invalidOutput,
                        stage: .capturingScreenshot,
                        message: "Simulator reported success but did not produce a readable screenshot.",
                        logs: logs
                    )
                }
                guard !screenshotData.isEmpty else {
                    throw runnerError(
                        kind: .invalidOutput,
                        stage: .capturingScreenshot,
                        message: "Simulator produced an empty screenshot.",
                        logs: logs
                    )
                }
                append(.capturingScreenshot, "Captured the Simulator screenshot.")
                append(.completed, "Preview completed.")

                return SimulatorRunResult(
                    screenshotData: screenshotData,
                    device: device,
                    viewTypeName: viewTypeName,
                    bundleIdentifier: bundleIdentifier,
                    logs: logs,
                    duration: Date().timeIntervalSince(startedAt)
                )
            }
        } catch let error as DedicatedSimulatorManagerError {
            throw runnerError(
                kind: error.kind == .timedOut ? .timedOut : .unavailable,
                stage: .locatingSimulator,
                message: error.message,
                logs: logs,
                commandOutput: error.commandOutput,
                exitCode: error.exitCode
            )
        }
    }

    private static func hostSource(viewTypeName: String) -> String {
        """
        import SwiftUI

        @main
        struct LiveCodePreviewHost: App {
            var body: some Scene {
                WindowGroup {
                    \(viewTypeName)()
                }
            }
        }
        """
    }

    private static func writeInfoPlist(
        to url: URL,
        bundleIdentifier: String,
        minimumIOSVersion: String
    ) throws {
        let plist: [String: Any] = [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleDisplayName": "Live Code Preview",
            "CFBundleExecutable": "LiveCodePreview",
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": "LiveCodePreview",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0",
            "CFBundleSupportedPlatforms": ["iPhoneSimulator"],
            "CFBundleVersion": "1",
            "DTPlatformName": "iphonesimulator",
            "LSRequiresIPhoneOS": true,
            "MinimumOSVersion": minimumIOSVersion,
            "UIApplicationSupportsIndirectInputEvents": true,
            "UILaunchScreen": [:],
            "UIDeviceFamily": [1, 2]
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: url, options: .atomic)
    }

    private static func runSimctl(
        _ arguments: [String],
        deviceSetPath: String,
        stage: SimulatorRunStage,
        action: String,
        workingDirectory: URL,
        options: SimulatorRunnerOptions,
        logs: inout [SimulatorRunLog]
    ) throws {
        let result: CommandResult
        do {
            result = try execute(
                executable: "/usr/bin/xcrun",
                arguments: ["simctl", "--set", deviceSetPath] + arguments,
                currentDirectory: workingDirectory,
                timeout: options.commandTimeout,
                maximumOutputLength: options.maximumLogLength
            )
        } catch {
            throw commandError(error, stage: stage, action: action, logs: logs)
        }
        guard result.exitCode == 0 else {
            throw failedCommandError(
                stage: stage,
                action: action,
                result: result,
                logs: logs
            )
        }
        appendOutput(result.combinedOutput, stage: stage, to: &logs)
    }

    private struct CommandResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String

        var combinedOutput: String {
            [stderr, stdout]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
    }

    private enum CommandExecutionError: Error {
        case launchFailed(String)
        case timedOut(String)
    }

    private static func execute(
        executable: String,
        arguments: [String],
        currentDirectory: URL,
        timeout: TimeInterval,
        maximumOutputLength: Int
    ) throws -> CommandResult {
        let fileManager = FileManager.default
        let stdoutURL = currentDirectory
            .appendingPathComponent("command-\(UUID().uuidString)-stdout.txt")
        let stderrURL = currentDirectory
            .appendingPathComponent("command-\(UUID().uuidString)-stderr.txt")
        _ = fileManager.createFile(atPath: stdoutURL.path, contents: nil)
        _ = fileManager.createFile(atPath: stderrURL.path, contents: nil)
        defer {
            try? fileManager.removeItem(at: stdoutURL)
            try? fileManager.removeItem(at: stderrURL)
        }

        do {
            let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
            let stderrHandle = try FileHandle(forWritingTo: stderrURL)
            defer {
                try? stdoutHandle.close()
                try? stderrHandle.close()
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.currentDirectoryURL = currentDirectory
            process.standardOutput = stdoutHandle
            process.standardError = stderrHandle

            do {
                try process.run()
            } catch {
                throw CommandExecutionError.launchFailed(error.localizedDescription)
            }

            let deadline = Date().addingTimeInterval(max(0.1, timeout))
            while process.isRunning && Date() < deadline {
                if Task.isCancelled {
                    terminate(process)
                    throw CommandExecutionError.timedOut("Command was cancelled.")
                }
                Thread.sleep(forTimeInterval: 0.01)
            }

            if process.isRunning {
                terminate(process)
                throw CommandExecutionError.timedOut(
                    "Command exceeded its \(String(format: "%.1f", max(0.1, timeout)))-second timeout."
                )
            }

            process.waitUntilExit()
            try? stdoutHandle.synchronize()
            try? stderrHandle.synchronize()

            return CommandResult(
                exitCode: process.terminationStatus,
                stdout: readOutput(at: stdoutURL, limit: maximumOutputLength),
                stderr: readOutput(at: stderrURL, limit: maximumOutputLength)
            )
        } catch let error as CommandExecutionError {
            throw error
        } catch {
            throw CommandExecutionError.launchFailed(error.localizedDescription)
        }
    }

    private static func terminate(_ process: Process) {
        process.terminate()
        let deadline = Date().addingTimeInterval(0.5)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
            process.waitUntilExit()
        }
    }

    private static func readOutput(at url: URL, limit: Int) -> String {
        let output = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        guard output.count > limit else { return output }
        return String(output.prefix(max(0, limit))) + "\n…output truncated"
    }

    private static func failedCommandError(
        stage: SimulatorRunStage,
        action: String,
        result: CommandResult,
        logs: [SimulatorRunLog]
    ) -> SimulatorRunnerError {
        let output = result.combinedOutput
        var updatedLogs = logs
        appendOutput(output, stage: stage, level: .warning, to: &updatedLogs)
        return runnerError(
            kind: .commandFailed,
            stage: stage,
            message: "Could not \(action).",
            logs: updatedLogs,
            commandOutput: output,
            exitCode: result.exitCode
        )
    }

    private static func commandError(
        _ error: Error,
        stage: SimulatorRunStage,
        action: String,
        logs: [SimulatorRunLog]
    ) -> SimulatorRunnerError {
        let kind: SimulatorRunnerError.Kind
        let detail: String
        switch error {
        case let CommandExecutionError.timedOut(message):
            kind = message == "Command was cancelled." ? .cancelled : .timedOut
            detail = message
        case let CommandExecutionError.launchFailed(message):
            kind = .unavailable
            detail = message
        default:
            kind = .unavailable
            detail = error.localizedDescription
        }
        var updatedLogs = logs
        updatedLogs.append(
            SimulatorRunLog(stage: stage, level: .warning, message: detail)
        )
        return runnerError(
            kind: kind,
            stage: stage,
            message: "Could not \(action): \(detail)",
            logs: updatedLogs,
            commandOutput: detail
        )
    }

    private static func runnerError(
        kind: SimulatorRunnerError.Kind,
        stage: SimulatorRunStage,
        message: String,
        logs: [SimulatorRunLog],
        commandOutput: String = "",
        exitCode: Int32? = nil
    ) -> SimulatorRunnerError {
        SimulatorRunnerError(
            kind: kind,
            stage: stage,
            message: message,
            logs: logs,
            commandOutput: commandOutput,
            exitCode: exitCode
        )
    }

    private static func appendOutput(
        _ output: String,
        stage: SimulatorRunStage,
        level: SimulatorRunLog.Level = .output,
        to logs: inout [SimulatorRunLog]
    ) {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        logs.append(SimulatorRunLog(stage: stage, level: level, message: trimmed))
    }

    private static func sourceMaskingCommentsAndStrings(_ source: String) -> String {
        enum State {
            case code
            case lineComment
            case blockComment(depth: Int)
            case string(escaped: Bool)
        }

        var result = Array(source)
        var state = State.code
        var index = result.startIndex

        while index < result.endIndex {
            let character = result[index]
            let nextIndex = result.index(after: index)
            let next = nextIndex < result.endIndex ? result[nextIndex] : nil

            switch state {
            case .code:
                if character == "/", next == "/" {
                    result[index] = " "
                    result[nextIndex] = " "
                    state = .lineComment
                    index = result.index(after: nextIndex)
                    continue
                }
                if character == "/", next == "*" {
                    result[index] = " "
                    result[nextIndex] = " "
                    state = .blockComment(depth: 1)
                    index = result.index(after: nextIndex)
                    continue
                }
                if character == "\"" {
                    result[index] = " "
                    state = .string(escaped: false)
                }
            case .lineComment:
                if character == "\n" {
                    state = .code
                } else {
                    result[index] = " "
                }
            case let .blockComment(depth):
                if character == "/", next == "*" {
                    result[index] = " "
                    result[nextIndex] = " "
                    state = .blockComment(depth: depth + 1)
                    index = result.index(after: nextIndex)
                    continue
                }
                if character == "*", next == "/" {
                    result[index] = " "
                    result[nextIndex] = " "
                    state = depth == 1 ? .code : .blockComment(depth: depth - 1)
                    index = result.index(after: nextIndex)
                    continue
                }
                if character != "\n" {
                    result[index] = " "
                }
            case let .string(escaped):
                if character != "\n" {
                    result[index] = " "
                }
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
        return String(result)
    }
}
