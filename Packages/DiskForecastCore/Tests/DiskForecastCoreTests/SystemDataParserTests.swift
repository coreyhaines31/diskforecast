@testable import DiskForecastCore
import Foundation
import Testing

struct SystemDataParserTests {
    private func sample(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "Samples/\(name)", withExtension: nil))
        return try Data(contentsOf: url)
    }

    @Test func parsesLocalSnapshots() {
        let output = """
        Snapshots for disk /:
        com.apple.TimeMachine.2026-10-04-221530.local
        com.apple.TimeMachine.2026-10-05-101530.local
        """
        #expect(LocalSnapshots.parse(output) == ["2026-10-04-221530", "2026-10-05-101530"])
        #expect(LocalSnapshots.parse("Snapshots for disk /:\n").isEmpty)
    }

    @Test func parsesSimulatorDevices() throws {
        let devices = Simulators.parseDevices(try sample("simctl-devices.json"))
        #expect(devices.count == 22)
        let biggest = try #require(devices.first)
        #expect(biggest.name == "iPhone 17 Pro")
        #expect(biggest.dataBytes == 4_055_474_176)
        #expect(biggest.runtime == "com.apple.CoreSimulator.SimRuntime.iOS-26-4")
        #expect(biggest.lastUsed != nil)
    }

    @Test func notesUnavailableSimulators() {
        let json = """
        {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-17-0": [
          {"name": "iPhone 15", "udid": "A", "isAvailable": false, "dataPathSize": 100,
           "availabilityError": "runtime profile not found"}
        ]}}
        """
        let devices = Simulators.parseDevices(Data(json.utf8))
        #expect(devices.map(\.isAvailable) == [false])
    }

    @Test func parsesSimulatorRuntimes() throws {
        let runtimes = Simulators.parseRuntimes(try sample("simctl-runtimes.json"))
        #expect(runtimes.map(\.title) == ["iOS 26.4", "iOS 26.2"])
        #expect(runtimes.first?.bytes == 8_485_747_282)
        #expect(runtimes.allSatisfy { $0.isDeletable })
    }

    @Test func parsesDockerUsage() throws {
        let data = try sample("docker-df.jsonl")
        let text = try #require(String(bytes: data, encoding: .utf8))
        let usage = Docker.parse(text)
        #expect(usage.map(\.type) == ["Images", "Containers", "Local Volumes", "Build Cache"])
        #expect(usage.first?.bytes == 27_430_000_000)
        #expect(usage.first?.reclaimableBytes == 15_380_000_000)
        #expect(usage[1].reclaimableBytes == 938_000)
    }

    @Test func readsDockerSizes() {
        #expect(Docker.bytes("0B") == 0)
        #expect(Docker.bytes("1.433GB (50%)") == 1_433_000_000)
        #expect(Docker.bytes("nonsense") == nil)
    }
}
