import Darwin
import Foundation

/// Owns the isolated, headless Simulator used by SwiftUI Gym previews.
///
/// The device is persistent, but its process is not: `ensureBooted()` starts it
/// on demand and `shutdownSynchronously()` stops it during app termination.
final class DedicatedSimulatorManager: @unchecked Sendable {
    static let shared = DedicatedSimulatorManager()
    static let deviceName = "SwiftUI Gym Preview"
    private let operationLock = NSLock()

    struct Configuration: Hashable, Sendable {
        var deviceName = DedicatedSimulatorManager.deviceName
        var preferredDeviceTypeName = "iPhone 17"
        var commandTimeout: TimeInterval = 15
        var bootTimeout: TimeInterval = 90
        var shutdownTimeout: TimeInterval = 10
        // `simctl list -j` includes the complete runtime/device-type catalogue
        // and is already larger than 100 KB on current Xcode installations.
        var maximumOutputLength = 512_000
        var deviceSetPath: String

        static var `default`: Configuration {
            let fileManager = FileManager.default
            let applicationSupport = (
                try? fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
            ) ?? fileManager.temporaryDirectory

            return Configuration(
                deviceSetPath: applicationSupport
                    .appendingPathComponent("LiveCodeTrainer", isDirectory: true)
                    .appendingPathComponent("CoreSimulator", isDirectory: true)
                    .path
            )
        }
    }

    let configuration: Configuration

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    /// Finds or creates the dedicated device and waits until it is fully booted.
    /// This never launches Simulator.app.
    func ensureBooted() async throws -> DedicatedSimulatorDevice {
        let task = Task.detached(priority: .userInitiated) {
            try self.withExclusiveBootedDevice { $0 }
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    /// Serializes the complete install → launch → screenshot transaction.
    func withExclusiveBootedDevice<T>(
        _ operation: (DedicatedSimulatorDevice) throws -> T
    ) throws -> T {
        while !operationLock.lock(before: Date().addingTimeInterval(0.05)) {
            if Task.isCancelled {
                throw Self.managerError(.cancelled, "Simulator operation was cancelled.")
            }
        }
        defer { operationLock.unlock() }

        guard !Task.isCancelled else {
            throw Self.managerError(.cancelled, "Simulator operation was cancelled.")
        }
        let device = try Self.ensureBootedSynchronously(configuration: configuration)
        return try operation(device)
    }

    /// Bounded synchronous cleanup suitable for `applicationWillTerminate`.
    ///
    /// The device is rediscovered inside the isolated device set so cleanup also
    /// works after relaunches and never relies on in-memory lifecycle state.
    func shutdownSynchronously() {
        let configuration = configuration
        let acquiredLock = operationLock.lock(
            before: Date().addingTimeInterval(min(2, configuration.shutdownTimeout))
        )
        defer {
            if acquiredLock {
                operationLock.unlock()
            }
        }

        guard let listing = try? Self.runSimctl(
            ["list", "-j"],
            configuration: configuration,
            timeout: min(configuration.commandTimeout, configuration.shutdownTimeout)
        ), listing.exitCode == 0,
        let inventory = try? Self.decodeInventory(listing.stdout),
        let device = Self.findDedicatedDevice(
            in: inventory,
            named: configuration.deviceName
        ), device.state.lowercased() != "shutdown"
        else {
            return
        }

        _ = try? Self.runSimctl(
            ["shutdown", device.udid],
            configuration: configuration,
            timeout: configuration.shutdownTimeout
        )
    }
}

struct DedicatedSimulatorDevice: Codable, Hashable, Sendable {
    let udid: String
    let name: String
    let runtimeIdentifier: String
    let deviceSetPath: String
}

struct DedicatedSimulatorRuntime: Codable, Hashable, Sendable {
    let identifier: String
    let name: String
    let version: String
    let isAvailable: Bool
    let platform: String?
}

struct DedicatedSimulatorDeviceType: Codable, Hashable, Sendable {
    let identifier: String
    let name: String
    let productFamily: String?
    let minRuntimeVersion: String?
    let maxRuntimeVersion: String?

    private enum CodingKeys: String, CodingKey {
        case identifier
        case name
        case productFamily
        case minRuntimeVersion = "minRuntimeVersionString"
        case maxRuntimeVersion = "maxRuntimeVersionString"
    }
}

struct DedicatedSimulatorInventory: Codable, Hashable, Sendable {
    struct Device: Codable, Hashable, Sendable {
        let udid: String
        let name: String
        let state: String
        let isAvailable: Bool?
        let deviceTypeIdentifier: String?
    }

    let devices: [String: [Device]]
    let runtimes: [DedicatedSimulatorRuntime]
    let devicetypes: [DedicatedSimulatorDeviceType]
}

struct DedicatedSimulatorManagerError: Error, LocalizedError, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case unavailable
        case invalidOutput
        case commandFailed
        case timedOut
        case cancelled
    }

    let kind: Kind
    let message: String
    let commandOutput: String
    let exitCode: Int32?

    var errorDescription: String? { message }
}

extension DedicatedSimulatorManager {
    /// Pure selection helper exposed internally for unit tests.
    static func findDedicatedDevice(
        in inventory: DedicatedSimulatorInventory,
        named name: String = deviceName
    ) -> DedicatedSimulatorInventory.Device? {
        inventory.devices
            .sorted { compareVersions(runtimeVersion(from: $0.key), runtimeVersion(from: $1.key)) > 0 }
            .lazy
            .flatMap(\.value)
            .first { device in
                device.name == name && device.isAvailable != false
            }
    }

    /// Pure selection helper exposed internally for unit tests.
    static func selectNewestRuntime(
        from runtimes: [DedicatedSimulatorRuntime]
    ) -> DedicatedSimulatorRuntime? {
        runtimes
            .filter { runtime in
                runtime.isAvailable
                    && (
                        runtime.platform?.caseInsensitiveCompare("iOS") == .orderedSame
                            || runtime.identifier.contains(".iOS-")
                            || runtime.name.hasPrefix("iOS ")
                    )
            }
            .max { lhs, rhs in
                let versionOrder = compareVersions(lhs.version, rhs.version)
                if versionOrder != 0 {
                    return versionOrder < 0
                }
                return lhs.identifier < rhs.identifier
            }
    }

    /// Pure selection helper exposed internally for unit tests.
    static func selectPreferredDeviceType(
        from deviceTypes: [DedicatedSimulatorDeviceType],
        for runtime: DedicatedSimulatorRuntime,
        preferredName: String = "iPhone 17"
    ) -> DedicatedSimulatorDeviceType? {
        let compatible = deviceTypes.filter { type in
            let isIPhone = type.productFamily?.caseInsensitiveCompare("iPhone") == .orderedSame
                || type.name.hasPrefix("iPhone ")
                || type.identifier.localizedCaseInsensitiveContains("iPhone")
            guard isIPhone else { return false }

            if let minimum = type.minRuntimeVersion,
               compareVersions(runtime.version, minimum) < 0 {
                return false
            }
            if let maximum = type.maxRuntimeVersion,
               compareVersions(runtime.version, maximum) > 0 {
                return false
            }
            return true
        }

        if let preferred = compatible.first(where: {
            $0.name.caseInsensitiveCompare(preferredName) == .orderedSame
        }) {
            return preferred
        }

        return compatible.max { lhs, rhs in
            lhs.name.compare(
                rhs.name,
                options: [.caseInsensitive, .numeric]
            ) == .orderedAscending
        }
    }

    /// Pure dotted-version comparison helper exposed internally for unit tests.
    static func compareVersions(_ lhs: String, _ rhs: String) -> Int {
        let lhsParts = versionComponents(lhs)
        let rhsParts = versionComponents(rhs)
        let count = max(lhsParts.count, rhsParts.count)

        for index in 0..<count {
            let left = index < lhsParts.count ? lhsParts[index] : 0
            let right = index < rhsParts.count ? rhsParts[index] : 0
            if left != right {
                return left < right ? -1 : 1
            }
        }
        return 0
    }
}

private extension DedicatedSimulatorManager {
    struct CommandResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String

        var combinedOutput: String {
            [stderr, stdout]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
    }

    enum CommandExecutionError: Error {
        case launchFailed(String)
        case timedOut(String)
        case cancelled
    }

    static func ensureBootedSynchronously(
        configuration: Configuration
    ) throws -> DedicatedSimulatorDevice {
        do {
            try FileManager.default.createDirectory(
                atPath: configuration.deviceSetPath,
                withIntermediateDirectories: true
            )
        } catch {
            throw managerError(
                .unavailable,
                "Could not create the dedicated Simulator device set.",
                output: error.localizedDescription
            )
        }

        var inventory = try loadInventory(configuration: configuration)
        var device = findDedicatedDevice(
            in: inventory,
            named: configuration.deviceName
        )

        if device == nil {
            guard let runtime = selectNewestRuntime(from: inventory.runtimes) else {
                throw managerError(
                    .unavailable,
                    "No available iOS Simulator runtime is installed."
                )
            }
            guard let deviceType = selectPreferredDeviceType(
                from: inventory.devicetypes,
                for: runtime,
                preferredName: configuration.preferredDeviceTypeName
            ) else {
                throw managerError(
                    .unavailable,
                    "No compatible iPhone Simulator device type is installed."
                )
            }

            let creation = try checkedSimctl(
                [
                    "create",
                    configuration.deviceName,
                    deviceType.identifier,
                    runtime.identifier
                ],
                action: "create the dedicated Simulator",
                configuration: configuration,
                timeout: configuration.commandTimeout
            )
            let createdUDID = creation.stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard UUID(uuidString: createdUDID) != nil else {
                throw managerError(
                    .invalidOutput,
                    "simctl did not return a valid device UDID.",
                    output: creation.combinedOutput
                )
            }

            inventory = try loadInventory(configuration: configuration)
            device = inventory.devices
                .lazy
                .flatMap(\.value)
                .first { $0.udid == createdUDID }
        }

        guard let device,
              let runtimeIdentifier = inventory.devices.first(where: {
                  $0.value.contains(where: { $0.udid == device.udid })
              })?.key
        else {
            throw managerError(
                .invalidOutput,
                "The dedicated Simulator could not be found after creation."
            )
        }

        _ = try checkedSimctl(
            ["bootstatus", device.udid, "-b"],
            action: "wait for the dedicated Simulator to boot",
            configuration: configuration,
            timeout: configuration.bootTimeout
        )

        return DedicatedSimulatorDevice(
            udid: device.udid,
            name: device.name,
            runtimeIdentifier: runtimeIdentifier,
            deviceSetPath: configuration.deviceSetPath
        )
    }

    static func loadInventory(
        configuration: Configuration
    ) throws -> DedicatedSimulatorInventory {
        let result = try checkedSimctl(
            ["list", "-j"],
            action: "inspect the dedicated Simulator device set",
            configuration: configuration,
            timeout: configuration.commandTimeout
        )
        do {
            return try decodeInventory(result.stdout)
        } catch {
            throw managerError(
                .invalidOutput,
                "Could not decode the Simulator inventory.",
                output: error.localizedDescription
            )
        }
    }

    static func decodeInventory(_ output: String) throws -> DedicatedSimulatorInventory {
        try JSONDecoder().decode(
            DedicatedSimulatorInventory.self,
            from: Data(output.utf8)
        )
    }

    static func checkedSimctl(
        _ arguments: [String],
        action: String,
        configuration: Configuration,
        timeout: TimeInterval
    ) throws -> CommandResult {
        do {
            let result = try runSimctl(
                arguments,
                configuration: configuration,
                timeout: timeout
            )
            guard result.exitCode == 0 else {
                throw managerError(
                    .commandFailed,
                    "Could not \(action).",
                    output: result.combinedOutput,
                    exitCode: result.exitCode
                )
            }
            return result
        } catch let error as DedicatedSimulatorManagerError {
            throw error
        } catch CommandExecutionError.cancelled {
            throw managerError(.cancelled, "Simulator operation was cancelled.")
        } catch let CommandExecutionError.timedOut(message) {
            throw managerError(.timedOut, message)
        } catch let CommandExecutionError.launchFailed(message) {
            throw managerError(
                .unavailable,
                "Could not launch simctl.",
                output: message
            )
        } catch {
            throw managerError(
                .unavailable,
                "Simulator operation failed.",
                output: error.localizedDescription
            )
        }
    }

    static func runSimctl(
        _ arguments: [String],
        configuration: Configuration,
        timeout: TimeInterval
    ) throws -> CommandResult {
        try execute(
            executable: "/usr/bin/xcrun",
            arguments: [
                "simctl",
                "--set",
                configuration.deviceSetPath
            ] + arguments,
            timeout: timeout,
            maximumOutputLength: configuration.maximumOutputLength
        )
    }

    static func execute(
        executable: String,
        arguments: [String],
        timeout: TimeInterval,
        maximumOutputLength: Int
    ) throws -> CommandResult {
        let fileManager = FileManager.default
        let outputDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("DedicatedSimulator-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: outputDirectory) }

        let stdoutURL = outputDirectory.appendingPathComponent("stdout")
        let stderrURL = outputDirectory.appendingPathComponent("stderr")
        _ = fileManager.createFile(atPath: stdoutURL.path, contents: nil)
        _ = fileManager.createFile(atPath: stderrURL.path, contents: nil)

        let stdoutHandle: FileHandle
        let stderrHandle: FileHandle
        do {
            stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
            stderrHandle = try FileHandle(forWritingTo: stderrURL)
        } catch {
            throw CommandExecutionError.launchFailed(error.localizedDescription)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        do {
            try process.run()
        } catch {
            try? stdoutHandle.close()
            try? stderrHandle.close()
            throw CommandExecutionError.launchFailed(error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(max(0.1, timeout))
        while process.isRunning && Date() < deadline {
            if Task.isCancelled {
                terminate(process)
                try? stdoutHandle.close()
                try? stderrHandle.close()
                throw CommandExecutionError.cancelled
            }
            Thread.sleep(forTimeInterval: 0.01)
        }

        if process.isRunning {
            terminate(process)
            try? stdoutHandle.close()
            try? stderrHandle.close()
            throw CommandExecutionError.timedOut(
                "simctl exceeded its \(String(format: "%.1f", max(0.1, timeout)))-second timeout."
            )
        }

        process.waitUntilExit()
        try? stdoutHandle.synchronize()
        try? stderrHandle.synchronize()
        try? stdoutHandle.close()
        try? stderrHandle.close()

        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: readOutput(at: stdoutURL, limit: maximumOutputLength),
            stderr: readOutput(at: stderrURL, limit: maximumOutputLength)
        )
    }

    static func terminate(_ process: Process) {
        process.terminate()
        let deadline = Date().addingTimeInterval(0.5)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        process.waitUntilExit()
    }

    static func readOutput(at url: URL, limit: Int) -> String {
        let output = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        guard output.count > limit else { return output }
        return String(output.prefix(max(0, limit))) + "\n…output truncated"
    }

    static func runtimeVersion(from identifier: String) -> String {
        guard let range = identifier.range(of: "iOS-") else { return "0" }
        return identifier[range.upperBound...].replacingOccurrences(of: "-", with: ".")
    }

    static func versionComponents(_ version: String) -> [Int] {
        version
            .split(separator: ".", omittingEmptySubsequences: false)
            .map { component in
                Int(component.prefix { $0.isNumber }) ?? 0
            }
    }

    static func managerError(
        _ kind: DedicatedSimulatorManagerError.Kind,
        _ message: String,
        output: String = "",
        exitCode: Int32? = nil
    ) -> DedicatedSimulatorManagerError {
        DedicatedSimulatorManagerError(
            kind: kind,
            message: message,
            commandOutput: output,
            exitCode: exitCode
        )
    }
}
