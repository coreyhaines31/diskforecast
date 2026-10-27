import Foundation

/// The files running processes have open, and the programs they run from, so nothing an app is
/// still using goes to the Trash. A trashed cache an app keeps writing to stops Finder from
/// emptying the Trash.
public struct OpenFiles: Sendable {
    public struct Program: Sendable {
        public let name: String
        let paths: [String]
        /// Where it runs, since when, and the terminal app it's in, for telling apart Claude Code
        /// sessions, which have no window of their own to quit.
        public var folder: String?
        public var started: Date?
        public var app: String?
        public var pid: pid_t = 0
        /// The app it belongs to, for quitting it.
        public var bundle: String?
    }

    let programs: [Program]

    init(programs: [Program]) {
        self.programs = programs
    }

    init(processes: [(name: String, paths: [String])]) {
        programs = processes.map { Program(name: $0.name, paths: $0.paths) }
    }

    /// What every process this user can see has open right now.
    public static func current() -> OpenFiles {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return OpenFiles(programs: []) }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 64)
        let found = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        let own = getpid()
        let programs = pids.prefix(Int(max(found, 0))).compactMap { pid -> Program? in
            guard pid > 0, pid != own, let executable = executablePath(pid) else { return nil }
            var program = Program(name: name(pid, executable: executable), paths: [executable] + openPaths(pid))
            program.pid = pid
            if let end = executable.range(of: ".app/") {
                program.bundle = String(executable[..<end.lowerBound]) + ".app"
            }
            if program.name == claudeCode {
                program.folder = workingFolder(pid)
                program.started = startTime(pid)
                program.app = hostApp(pid)
            }
            return program
        }
        return OpenFiles(programs: programs)
    }

    public static let claudeCode = "Claude Code"

    /// Whether `pid` is still a Claude Code session, checked again just before ending one.
    public static func isClaudeCode(_ pid: pid_t) -> Bool {
        pid > 0 && executablePath(pid).map { name(pid, executable: $0) == claudeCode } == true
    }

    /// The name of a program using `path` or something inside it, or nil when nothing is.
    public func user(of path: String) -> String? {
        users(of: path).first?.name
    }

    /// Every program using `path` or something inside it.
    public func users(of path: String) -> [Program] {
        let folder = path.hasSuffix("/") ? String(path.dropLast()) : path
        return programs.filter { program in
            program.paths.contains { $0 == folder || $0.hasPrefix(folder + "/") }
        }
    }

    private static func executablePath(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    /// The app a helper process belongs to, so "Cursor Helper (GPU)" reads as Cursor. Claude Code
    /// runs from a file named after its version, like 2.1.309.
    private static func name(_ pid: pid_t, executable: String) -> String {
        if executable.contains("/claude/versions/") { return claudeCode }
        if let app = executable.split(separator: "/").first(where: { $0.hasSuffix(".app") }) {
            return String(app.dropLast(4))
        }
        var buffer = [CChar](repeating: 0, count: 256)
        proc_name(pid, &buffer, UInt32(buffer.count))
        let name = String(cString: buffer)
        return name.isEmpty ? (executable as NSString).lastPathComponent : name
    }

    private static func workingFolder(_ pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafeBytes(of: info.pvi_cdir.vip_path) {
            String(cString: $0.bindMemory(to: CChar.self).baseAddress!)
        }
        return path.isEmpty ? nil : path
    }

    private static func startTime(_ pid: pid_t) -> Date? {
        bsdInfo(pid).map { Date(timeIntervalSince1970: TimeInterval($0.pbi_start_tvsec)) }
    }

    /// The app a process was started from, like the terminal a command runs in.
    private static func hostApp(_ pid: pid_t) -> String? {
        var current = pid
        for _ in 0..<10 {
            guard let parent = bsdInfo(current).map({ pid_t($0.pbi_ppid) }), parent > 1 else { return nil }
            if let app = executablePath(parent)?.split(separator: "/").first(where: { $0.hasSuffix(".app") }) {
                return String(app.dropLast(4))
            }
            current = parent
        }
        return nil
    }

    private static func bsdInfo(_ pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size ? info : nil
    }

    private static func openPaths(_ pid: pid_t) -> [String] {
        let size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard size > 0 else { return [] }
        let stride = MemoryLayout<proc_fdinfo>.stride
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(size) / stride + 16)
        let bytes = fds.withUnsafeMutableBytes {
            proc_pidinfo(pid, PROC_PIDLISTFDS, 0, $0.baseAddress, Int32($0.count))
        }
        return fds.prefix(Int(max(bytes, 0)) / stride).compactMap { descriptor in
            guard descriptor.proc_fdtype == UInt32(PROX_FDTYPE_VNODE) else { return nil }
            var info = vnode_fdinfowithpath()
            let read = proc_pidfdinfo(
                pid, descriptor.proc_fd, PROC_PIDFDVNODEPATHINFO, &info,
                Int32(MemoryLayout<vnode_fdinfowithpath>.size)
            )
            guard read > 0 else { return nil }
            let path = withUnsafeBytes(of: info.pvip.vip_path) {
                String(cString: $0.bindMemory(to: CChar.self).baseAddress!)
            }
            return path.isEmpty ? nil : path
        }
    }
}
