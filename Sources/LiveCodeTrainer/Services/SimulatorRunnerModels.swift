import Foundation

enum SimulatorRunStage: String, Codable, CaseIterable, Hashable, Sendable {
    case preparing
    case locatingSDK
    case compiling
    case locatingSimulator
    case installing
    case launching
    case capturingScreenshot
    case completed
}

struct SimulatorRunLog: Identifiable, Codable, Hashable, Sendable {
    enum Level: String, Codable, Hashable, Sendable {
        case info
        case output
        case warning
    }

    let id: UUID
    let stage: SimulatorRunStage
    let level: Level
    let message: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        stage: SimulatorRunStage,
        level: Level = .info,
        message: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.stage = stage
        self.level = level
        self.message = message
        self.timestamp = timestamp
    }
}

struct SimulatorDevice: Codable, Hashable, Sendable {
    let udid: String
    let name: String
    let runtimeIdentifier: String
    let deviceSetPath: String
}

struct SimulatorRunResult: Codable, Hashable, Sendable {
    let screenshotData: Data
    let device: SimulatorDevice
    let viewTypeName: String
    let bundleIdentifier: String
    let logs: [SimulatorRunLog]
    let duration: TimeInterval
}

struct SimulatorRunnerOptions: Hashable, Sendable {
    var minimumIOSVersion = "17.0"
    var compilationTimeout: TimeInterval = 30
    var commandTimeout: TimeInterval = 15
    var launchSettlingTime: TimeInterval = 1
    var maximumLogLength = 40_000

    static let `default` = SimulatorRunnerOptions()
}

struct SimulatorRunnerError: Error, LocalizedError, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case invalidSource
        case unavailable
        case commandFailed
        case timedOut
        case noBootedSimulator
        case invalidOutput
        case cancelled
    }

    let kind: Kind
    let stage: SimulatorRunStage
    let message: String
    let logs: [SimulatorRunLog]
    let commandOutput: String
    let exitCode: Int32?

    var errorDescription: String? { message }

    init(
        kind: Kind,
        stage: SimulatorRunStage,
        message: String,
        logs: [SimulatorRunLog],
        commandOutput: String = "",
        exitCode: Int32? = nil
    ) {
        self.kind = kind
        self.stage = stage
        self.message = message
        self.logs = logs
        self.commandOutput = commandOutput
        self.exitCode = exitCode
    }
}
