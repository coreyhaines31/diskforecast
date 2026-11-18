@testable import DiskForecastCore
import Foundation
import Testing

struct TimedProcessTests {
    private func process(_ executable: String, _ arguments: [String]) -> (Process, Pipe) {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        return (process, pipe)
    }

    @Test func readsTheOutputOfAProcessThatFinishesInTime() throws {
        let (process, pipe) = process("/bin/echo", ["hello"])
        let result = try TimedProcess.run(process, output: pipe, timeout: 10)
        #expect(String(bytes: result.data, encoding: .utf8) == "hello\n")
        #expect(result.succeeded)
        #expect(!result.timedOut)
    }

    @Test func stopsAProcessThatRunsPastTheDeadline() throws {
        let (process, pipe) = process("/bin/sleep", ["30"])
        let started = Date()
        let result = try TimedProcess.run(process, output: pipe, timeout: 0.3)
        #expect(result.timedOut)
        #expect(!result.succeeded)
        #expect(!process.isRunning)
        #expect(Date().timeIntervalSince(started) < 10)
    }

    @Test func waitsAsLongAsItTakesWithoutATimeout() throws {
        let (process, pipe) = process("/bin/sleep", ["0.5"])
        let result = try TimedProcess.run(process, output: pipe, timeout: nil)
        #expect(result.succeeded)
        #expect(!result.timedOut)
    }

    @Test func reportsAFailedExitAsNotSucceeded() throws {
        let (process, pipe) = process("/usr/bin/false", [])
        let result = try TimedProcess.run(process, output: pipe, timeout: 10)
        #expect(!result.succeeded)
        #expect(!result.timedOut)
        #expect(result.status == 1)
    }

    @Test func throwsWhenTheProcessCannotStart() {
        let (process, pipe) = process("/nonexistent/tool", [])
        #expect(throws: (any Error).self) { try TimedProcess.run(process, output: pipe, timeout: 10) }
    }
}
