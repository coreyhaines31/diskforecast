import Foundation

/// Deletes files and folders outright. It works one folder at a time through open folder handles,
/// so a path too long for Finder or FileManager (deep node_modules, nested worktrees) still goes.
enum Deleter {
    static func remove(_ path: String) throws {
        let parent = open((path as NSString).deletingLastPathComponent, O_RDONLY | O_DIRECTORY)
        guard parent >= 0 else { throw error(errno) }
        defer { close(parent) }
        try remove((path as NSString).lastPathComponent, in: parent)
    }

    private static func remove(_ name: String, in parent: Int32) throws {
        var info = stat()
        guard fstatat(parent, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else { throw error(errno) }
        if info.st_flags & UInt32(UF_IMMUTABLE | UF_APPEND) != 0 {
            // A locked file. Unlocking it is what Finder asks about before emptying.
            let locked = openat(parent, name, O_RDONLY | O_SYMLINK)
            if locked >= 0 {
                fchflags(locked, 0)
                close(locked)
            }
        }
        if info.st_mode & S_IFMT == S_IFDIR {
            let folder = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
            guard folder >= 0 else { throw error(errno) }
            defer { close(folder) }
            for child in try names(in: folder) {
                try remove(child, in: folder)
            }
            guard unlinkat(parent, name, AT_REMOVEDIR) == 0 else { throw error(errno) }
        } else {
            guard unlinkat(parent, name, 0) == 0 else { throw error(errno) }
        }
    }

    private static func names(in folder: Int32) throws -> [String] {
        let copy = dup(folder)
        guard copy >= 0, let directory = fdopendir(copy) else { throw error(errno) }
        defer { closedir(directory) }
        var names: [String] = []
        while let entry = readdir(directory) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) {
                String(cString: $0.bindMemory(to: CChar.self).baseAddress!)
            }
            if name != "." && name != ".." { names.append(name) }
        }
        return names
    }

    private static func error(_ code: Int32) -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: [
            NSLocalizedDescriptionKey: String(cString: strerror(code)) + "."
        ])
    }
}
