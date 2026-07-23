import Testing
@testable import LiveCodeTrainer

struct DedicatedSimulatorManagerTests {
    @Test
    func comparesDottedVersionsNumerically() {
        #expect(DedicatedSimulatorManager.compareVersions("18.10", "18.9") > 0)
        #expect(DedicatedSimulatorManager.compareVersions("18.0", "18") == 0)
        #expect(DedicatedSimulatorManager.compareVersions("17.6.1", "17.7") < 0)
    }

    @Test
    func selectsNewestAvailableIOSRuntime() {
        let runtimes = [
            Self.runtime("com.apple.CoreSimulator.SimRuntime.iOS-18-5", "18.5"),
            Self.runtime("com.apple.CoreSimulator.SimRuntime.iOS-18-6", "18.6"),
            Self.runtime(
                "com.apple.CoreSimulator.SimRuntime.iOS-26-0",
                "26.0",
                isAvailable: false
            ),
            Self.runtime(
                "com.apple.CoreSimulator.SimRuntime.watchOS-30-0",
                "30.0",
                platform: "watchOS"
            )
        ]

        let selected = DedicatedSimulatorManager.selectNewestRuntime(from: runtimes)

        #expect(selected?.identifier == "com.apple.CoreSimulator.SimRuntime.iOS-18-6")
    }

    @Test
    func selectsPreferredCompatibleIPhoneDeviceType() {
        let runtime = Self.runtime(
            "com.apple.CoreSimulator.SimRuntime.iOS-26-0",
            "26.0"
        )
        let deviceTypes = [
            Self.deviceType("iPhone 16 Pro"),
            Self.deviceType("iPhone 17"),
            Self.deviceType("Apple TV 4K", family: "Apple TV")
        ]

        let selected = DedicatedSimulatorManager.selectPreferredDeviceType(
            from: deviceTypes,
            for: runtime,
            preferredName: "iPhone 17"
        )

        #expect(selected?.name == "iPhone 17")
    }

    @Test
    func fallsBackToNewestCompatibleIPhoneDeviceType() {
        let runtime = Self.runtime(
            "com.apple.CoreSimulator.SimRuntime.iOS-26-0",
            "26.0"
        )
        let deviceTypes = [
            Self.deviceType("iPhone 9"),
            Self.deviceType("iPhone 16 Pro"),
            Self.deviceType("iPhone 18", minimumRuntime: "27.0"),
            Self.deviceType("Apple TV 4K", family: "Apple TV")
        ]

        let selected = DedicatedSimulatorManager.selectPreferredDeviceType(
            from: deviceTypes,
            for: runtime,
            preferredName: "iPhone 17"
        )

        #expect(selected?.name == "iPhone 16 Pro")
    }

    @Test
    func findsOnlyExactAvailableDedicatedDevice() {
        let dedicatedName = DedicatedSimulatorManager.deviceName
        let inventory = DedicatedSimulatorInventory(
            devices: [
                "com.apple.CoreSimulator.SimRuntime.iOS-18-6": [
                    Self.inventoryDevice(
                        udid: "foreign-suffix",
                        name: "\(dedicatedName) Copy"
                    ),
                    Self.inventoryDevice(
                        udid: "foreign-prefix",
                        name: "Other \(dedicatedName)"
                    ),
                    Self.inventoryDevice(
                        udid: "unavailable-exact",
                        name: dedicatedName,
                        isAvailable: false
                    )
                ],
                "com.apple.CoreSimulator.SimRuntime.iOS-18-5": [
                    Self.inventoryDevice(
                        udid: "dedicated-exact",
                        name: dedicatedName
                    )
                ]
            ],
            runtimes: [],
            devicetypes: []
        )

        let selected = DedicatedSimulatorManager.findDedicatedDevice(in: inventory)

        #expect(selected?.udid == "dedicated-exact")
        #expect(selected?.name == dedicatedName)
    }

    private static func runtime(
        _ identifier: String,
        _ version: String,
        isAvailable: Bool = true,
        platform: String? = "iOS"
    ) -> DedicatedSimulatorRuntime {
        DedicatedSimulatorRuntime(
            identifier: identifier,
            name: "\(platform ?? "iOS") \(version)",
            version: version,
            isAvailable: isAvailable,
            platform: platform
        )
    }

    private static func deviceType(
        _ name: String,
        family: String? = "iPhone",
        minimumRuntime: String? = nil,
        maximumRuntime: String? = nil
    ) -> DedicatedSimulatorDeviceType {
        DedicatedSimulatorDeviceType(
            identifier: "com.apple.CoreSimulator.SimDeviceType.\(name.replacingOccurrences(of: " ", with: "-"))",
            name: name,
            productFamily: family,
            minRuntimeVersion: minimumRuntime,
            maxRuntimeVersion: maximumRuntime
        )
    }

    private static func inventoryDevice(
        udid: String,
        name: String,
        isAvailable: Bool? = true
    ) -> DedicatedSimulatorInventory.Device {
        DedicatedSimulatorInventory.Device(
            udid: udid,
            name: name,
            state: "Shutdown",
            isAvailable: isAvailable,
            deviceTypeIdentifier: nil
        )
    }
}
