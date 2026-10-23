import Foundation

/// The files running processes have open, and the programs they run from, so nothing an app is
/// still using goes to the Trash. A trashed cache an app keeps writing to stops Finder from
/// emptying the Trash.
public struct OpenFiles: Sendable {
    /// Each process's name and the paths it has open.
    let processes: [(name: String, paths: [String])]

    /// What every process this user can see has open right now.
    public static func current() -> OpenFiles {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return OpenFiles(processes: []) }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 64)
        let found = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        let own = getpid()
        let processes = pids.prefix(Int(max(found, 0))).compactMap { pid -> (String, [String])? in
            guard pid > 0, pid != own, let executable = executablePath(pid) else { return nil }
            return (name(pid, executable: executable), [executable] + openPaths(pid))
        }
        return OpenFiles(processes: processes)
    }

    /// The name of a program using `path` or something inside it, or nil when nothing is.
    public func user(of path: String) -> String? {
        let folder = path.hasSuffix("/") ? String(path.dropLast()) : path
        return processes.first { process in
            process.paths.contains { $0 == folder || $0.hasPrefix(folder + "/") }
        }?.name
    }

    private static func executablePath(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    /// The app a helper process belongs to, so "Cursor Helper (GPU)" reads as Cursor.
    private static func name(_ pid: pid_t, executable: String) -> String {
        if let app = executable.split(separator: "/").first(where: { $0.hasSuffix(".app") }) {
            return String(app.dropLast(4))
        }
        var buffer = [CChar](repeating: 0, count: 256)
        proc_name(pid, &buffer, UInt32(buffer.count))
        let name = String(cString: buffer)
        return name.isEmpty ? (executable as NSString).lastPathComponent : name
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
