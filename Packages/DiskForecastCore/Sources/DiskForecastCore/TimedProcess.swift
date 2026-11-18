import Foundation
import os

/// Runs a process to the end, stopping it once it runs past a deadline, so a hung tool can't hang
/// whatever is waiting on it.
public enum TimedProcess {
    public struct Result: Sendable {
        public let data: Data
        public let status: Int32
        /// It ran past the deadline and was stopped.
        public let timedOut: Bool
        /// It exited on its own with status 0.
        public let succeeded: Bool
    }

    /// Starts `process`, reads `output` until it closes, and waits for the process to exit. With a
    /// `timeout`, terminates it once that many seconds pass. Blocks, so call it off the main thread.
    public static func run(_ process: Process, output: Pipe, timeout: TimeInterval?) throws -> Result {
        try process.run()
        let fired = OSAllocatedUnfairLock(initialState: false)
        let deadline = timeout.map { seconds in
            let item = DispatchWorkItem { [process] in
                fired.withLock { $0 = true }
                process.terminate()
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + seconds, execute: item)
            return item
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        deadline?.cancel()
        let exited = process.terminationReason == .exit
        return Result(
            data: data, status: process.terminationStatus,
            // The deadline can fire just after a process finished on its own; that isn't a timeout.
            timedOut: fired.withLock { $0 } && !exited,
            succeeded: exited && process.terminationStatus == 0
        )
    }
}
