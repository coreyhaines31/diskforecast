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

    @Test func ignoresSnapshotNamesThatArentDates() {
        let output = "com.apple.TimeMachine.2026-10-05-101530; rm -rf ~.local\ncom.apple.TimeMachine..local"
        #expect(LocalSnapshots.parse(output).isEmpty)
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

    @Test func parsesSwapUsage() {
        let mebibyte: Int64 = 1_048_576
        let output = "vm.swapusage: total = 18432.00M  used = 16951.94M  free = 1480.06M  (encrypted)\n"
        let swap = Swap.parse(output)
        #expect(swap == SwapUsage(totalBytes: 18_432 * mebibyte, usedBytes: Int64(16_951.94 * Double(mebibyte))))
    }

    @Test func parsesSwapInGigabytes() {
        let mebibyte: Int64 = 1_048_576
        let swap = Swap.parse("total = 2.00G  used = 512.00M  free = 1.50G  (encrypted)")
        #expect(swap == SwapUsage(totalBytes: 2_048 * mebibyte, usedBytes: 512 * mebibyte))
    }

    @Test func parsesNoSwap() {
        let swap = Swap.parse("vm.swapusage: total = 0.00M  used = 0.00M  free = 0.00M  (encrypted)")
        #expect(swap == SwapUsage(totalBytes: 0, usedBytes: 0))
    }

    @Test func ignoresSwapOutputItCannotRead() {
        #expect(Swap.parse("") == nil)
        #expect(Swap.parse("sysctl: unknown oid 'vm.swapusage'") == nil)
        #expect(Swap.parse("total = lots  used = 1.00M") == nil)
        #expect(Swap.parse("total = 1.00X  used = 1.00M") == nil)
    }
}
