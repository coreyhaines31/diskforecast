import Darwin
import Foundation

/// The full check made just before a listed copy is removed. Finding a copy only samples the
/// largest files; this reads every file in both folders and compares them byte for byte.
extension DuplicateFolders {
    enum Mismatch: Error, Equatable {
        /// A file, folder, or link differs, or one side has something the other doesn't.
        case differs
        /// The folder it matched is gone, or isn't a folder any more.
        case originalMissing
        /// Some files are only in iCloud, and reading them would download them.
        case notDownloaded
        /// Something couldn't be read, so the folders weren't fully compared.
        case incomplete

        /// Why the copy stays, naming the folder it was compared with as `original`, like "~/Desktop/Trip".
        func reason(comparedWith original: String) -> String {
            switch self {
            case .differs: "It isn't the same as \(original) any more, so it stays."
            case .originalMissing: "\(original), the folder it matched, is gone or has moved, so it stays."
            case .notDownloaded: "Some files here or in \(original) are only in iCloud, so they couldn't be "
                + "compared and it stays."
            case .incomplete: "Not every file could be compared with \(original), so it stays."
            }
        }
    }

    /// Nil when `copy` holds exactly what `original` does: the same files, folders, and links by
    /// path, with identical contents. Links are compared, never followed. Hard links and clones of
    /// each other are the same storage and aren't read. Slow for big folders, so run it off the main thread.
    static func mismatch(of copy: String, with original: String) -> Mismatch? {
        withoutDownloading { () -> Mismatch? in
            do throws(Mismatch) {
                try check(copy, against: original)
                return nil
            } catch {
                return error
            }
        }
    }

    /// Runs `body` with reads of files iCloud has evicted failing instead of downloading them.
    static func withoutDownloading<T>(_ body: () -> T) -> T {
        let materialize = IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES
        let previous = getiopolicy_np(materialize, IOPOL_SCOPE_THREAD)
        setiopolicy_np(materialize, IOPOL_SCOPE_THREAD, IOPOL_MATERIALIZE_DATALESS_FILES_OFF)
        defer {
            if previous >= 0 { setiopolicy_np(materialize, IOPOL_SCOPE_THREAD, previous) }
        }
        return body()
    }

    private struct Item {
        let path: String
        let info: stat
        var kind: mode_t { info.st_mode & S_IFMT }
    }

    private static func check(_ copy: String, against original: String) throws(Mismatch) {
        var info = stat()
        guard lstat(original, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else { throw .originalMissing }
        let (copyPath, originalPath) = (Trasher.resolved(copy), Trasher.resolved(original))
        guard copyPath != originalPath, !copyPath.hasPrefix(originalPath + "/"),
              !originalPath.hasPrefix(copyPath + "/")
        else { throw .incomplete }
        let copyItems = try items(under: copy)
        let originalItems = try items(under: original)
        guard copyItems.count == originalItems.count else { throw .differs }
        var pairs: [(copy: Item, original: Item)] = []
        for (relative, item) in copyItems {
            guard let other = originalItems[relative], other.kind == item.kind else { throw .differs }
            pairs.append((item, other))
        }
        for pair in pairs {
            try compare(pair.copy, pair.original)
        }
    }

    /// Everything under a folder, read from the disk now rather than from the scan, by its path
    /// inside the folder. The folder itself is under "".
    private static func items(under root: String) throws(Mismatch) -> [String: Item] {
        var found: [String: Item] = [:]
        var stack = [""]
        while let relative = stack.popLast() {
            let path = relative.isEmpty ? root : root + "/" + relative
            var info = stat()
            guard lstat(path, &info) == 0 else { throw .incomplete }
            if info.st_flags & UInt32(SF_DATALESS) != 0 { throw .notDownloaded }
            found[relative] = Item(path: path, info: info)
            guard info.st_mode & S_IFMT == S_IFDIR else { continue }
            guard found.count <= maximumFiles,
                  let names = try? FileManager.default.contentsOfDirectory(atPath: path)
            else { throw .incomplete }
            stack += names.map { relative.isEmpty ? $0 : relative + "/" + $0 }
        }
        return found
    }

    private static func compare(_ copy: Item, _ original: Item) throws(Mismatch) {
        switch copy.kind {
        case S_IFREG:
            guard copy.info.st_size == original.info.st_size else { throw .differs }
            if copy.info.st_dev == original.info.st_dev && copy.info.st_ino == original.info.st_ino { return }
            if let one = BulkReader.clone(of: copy.path), let two = BulkReader.clone(of: original.path),
               one.references > 1, one.id == two.id, copy.info.st_dev == original.info.st_dev { return }
            try compareBytes(copy.path, original.path, size: Int64(copy.info.st_size))
        case S_IFLNK:
            guard let one = linkTarget(copy.path), let two = linkTarget(original.path) else { throw .incomplete }
            guard one == two else { throw .differs }
        default:
            // Folders are compared by what's in them; anything else has no contents to compare.
            return
        }
    }

    private static func linkTarget(_ path: String) -> String? {
        try? FileManager.default.destinationOfSymbolicLink(atPath: path)
    }

    private static func compareBytes(_ first: String, _ second: String, size: Int64) throws(Mismatch) {
        let one = open(first, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        let two = open(second, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        defer {
            if one >= 0 { close(one) }
            if two >= 0 { close(two) }
        }
        guard one >= 0, two >= 0 else { throw .incomplete }
        // Don't fill the file cache with what's read once.
        _ = fcntl(one, F_NOCACHE, 1)
        _ = fcntl(two, F_NOCACHE, 1)
        let bufferOne = UnsafeMutableRawPointer.allocate(byteCount: chunkBytes, alignment: 16)
        let bufferTwo = UnsafeMutableRawPointer.allocate(byteCount: chunkBytes, alignment: 16)
        defer {
            bufferOne.deallocate()
            bufferTwo.deallocate()
        }
        var offset: Int64 = 0
        while offset < size {
            let length = Int(min(Int64(chunkBytes), size - offset))
            guard readFully(one, into: bufferOne, length, at: offset),
                  readFully(two, into: bufferTwo, length, at: offset)
            else { throw .incomplete }
            guard memcmp(bufferOne, bufferTwo, length) == 0 else { throw .differs }
            offset += Int64(length)
        }
        // Grown since it was listed: what's past the end wasn't compared.
        var byte: UInt8 = 0
        guard pread(one, &byte, 1, off_t(size)) == 0, pread(two, &byte, 1, off_t(size)) == 0 else { throw .differs }
    }

    private static func readFully(
        _ descriptor: Int32, into buffer: UnsafeMutableRawPointer, _ length: Int, at offset: Int64
    ) -> Bool {
        var done = 0
        while done < length {
            let read = pread(descriptor, buffer + done, length - done, off_t(offset) + off_t(done))
            if read < 0 && errno == EINTR { continue }
            guard read > 0 else { return false }
            done += read
        }
        return true
    }
}
