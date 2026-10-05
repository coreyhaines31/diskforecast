import Darwin
import Foundation

/// Reads a directory's entries and their attributes with `getattrlistbulk`, many per system call.
/// Each worker thread owns one reader and its buffer.
final class BulkReader {
    enum EntryType {
        case file, directory, symlink, other

        init(objectType: UInt32) {
            switch objectType {
            case UInt32(VREG.rawValue): self = .file
            case UInt32(VDIR.rawValue): self = .directory
            case UInt32(VLNK.rawValue): self = .symlink
            default: self = .other
            }
        }
    }

    struct Entry {
        var name = ""
        var type = EntryType.other
        var device: Int32 = 0
        var modified: TimeInterval = 0
        var fileID: UInt64 = 0
        var linkCount: UInt32 = 1
        var allocatedBytes: Int64 = 0
        var cloneID: UInt64 = 0
        var cloneReferences: UInt32 = 0
    }

    // From <sys/attr.h>, spelled out so they're all the same unsigned type.
    private static let cmnReturnedAttrs: UInt32 = 0x8000_0000
    private static let cmnName: UInt32 = 0x0000_0001
    private static let cmnDevID: UInt32 = 0x0000_0002
    private static let cmnObjType: UInt32 = 0x0000_0008
    private static let cmnModTime: UInt32 = 0x0000_0400
    private static let cmnFileID: UInt32 = 0x0200_0000
    private static let cmnError: UInt32 = 0x2000_0000
    private static let dirMountStatus: UInt32 = 0x0000_0004
    private static let fileLinkCount: UInt32 = 0x0000_0001
    private static let fileAllocSize: UInt32 = 0x0000_0004
    private static let extPrivateSize: UInt32 = 0x0000_0008
    private static let extCloneID: UInt32 = 0x0000_0100
    private static let extCloneRefCount: UInt32 = 0x0000_1000
    private static let optionCommonExtended: UInt64 = 0x0000_0020
    private static let mountPoint: UInt32 = 0x0000_0001
    private static let attributeSetSize = 20

    private let capacity = 256 * 1024
    private let buffer: UnsafeMutableRawPointer

    init() {
        buffer = UnsafeMutableRawPointer.allocate(byteCount: capacity, alignment: 16)
    }

    func deallocate() {
        buffer.deallocate()
    }

    /// Calls `body` for each entry of the open directory, skipping entries that report an error.
    /// A directory that's the mount point of another volume comes back with a device of -1.
    func read(_ descriptor: Int32, _ body: (Entry) -> Void) {
        var request = attrlist()
        request.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        request.commonattr = Self.cmnReturnedAttrs | Self.cmnName | Self.cmnDevID | Self.cmnObjType
            | Self.cmnModTime | Self.cmnFileID | Self.cmnError
        request.dirattr = Self.dirMountStatus
        request.fileattr = Self.fileLinkCount | Self.fileAllocSize
        request.forkattr = Self.extCloneID | Self.extCloneRefCount

        while true {
            let count = getattrlistbulk(descriptor, &request, buffer, capacity, Self.optionCommonExtended)
            guard count >= 1 else { return }
            var entryStart = buffer
            for _ in 0..<count {
                let length = Int(entryStart.loadUnaligned(as: UInt32.self))
                if let entry = parse(entryStart) {
                    body(entry)
                }
                entryStart += length
            }
        }
    }

    /// Walks the packed attributes of one entry. Each attribute is present only when its bit is
    /// set in the entry's returned set, in the order common, directory, file, extended.
    private struct Cursor {
        var position: UnsafeMutableRawPointer

        mutating func take<T>(_ type: T.Type, size: Int = MemoryLayout<T>.size) -> T {
            defer { position += size }
            return position.loadUnaligned(as: T.self)
        }
    }

    private func parse(_ start: UnsafeMutableRawPointer) -> Entry? {
        var cursor = Cursor(position: start + 4)
        let common = (cursor.position).loadUnaligned(as: UInt32.self)
        let directory = (cursor.position + 8).loadUnaligned(as: UInt32.self)
        let file = (cursor.position + 12).loadUnaligned(as: UInt32.self)
        let extended = (cursor.position + 16).loadUnaligned(as: UInt32.self)
        cursor.position += Self.attributeSetSize

        var entry = Entry()
        guard parseCommon(common, &cursor, into: &entry) else { return nil }
        if directory & Self.dirMountStatus != 0, cursor.take(UInt32.self) & Self.mountPoint != 0 {
            entry.device = -1
            return entry
        }
        if file & Self.fileLinkCount != 0 { entry.linkCount = cursor.take(UInt32.self) }
        if file & Self.fileAllocSize != 0 { entry.allocatedBytes = cursor.take(Int64.self) }
        if extended & Self.extCloneID != 0 { entry.cloneID = cursor.take(UInt64.self) }
        if extended & Self.extCloneRefCount != 0 { entry.cloneReferences = cursor.take(UInt32.self) }
        return entry
    }

    /// Fills in the common attributes; false when the entry reported an error.
    private func parseCommon(_ common: UInt32, _ cursor: inout Cursor, into entry: inout Entry) -> Bool {
        if common & Self.cmnName != 0 {
            let reference = cursor.position
            let offset = Int(cursor.take(Int32.self, size: 8))
            entry.name = String(cString: (reference + offset).assumingMemoryBound(to: CChar.self))
        }
        if common & Self.cmnDevID != 0 { entry.device = cursor.take(Int32.self) }
        if common & Self.cmnObjType != 0 { entry.type = EntryType(objectType: cursor.take(UInt32.self)) }
        if common & Self.cmnModTime != 0 {
            let seconds = cursor.take(Int.self)
            let nanoseconds = cursor.take(Int.self)
            entry.modified = TimeInterval(seconds) + TimeInterval(nanoseconds) / 1e9
        }
        if common & Self.cmnFileID != 0 { entry.fileID = cursor.take(UInt64.self) }
        if common & Self.cmnError != 0, cursor.take(UInt32.self) != 0 { return false }
        return true
    }

    /// The bytes of a cloned file that it doesn't share with its clones.
    static func privateSize(of path: String) -> Int64? {
        var request = attrlist()
        request.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        request.forkattr = extPrivateSize
        var result = (length: UInt32(0), size: Int64(0))
        let status = withUnsafeMutableBytes(of: &result) { raw in
            let options = UInt32(FSOPT_NOFOLLOW) | UInt32(optionCommonExtended)
            return getattrlist(path, &request, raw.baseAddress, raw.count, options)
        }
        guard status == 0 else { return nil }
        return withUnsafeBytes(of: &result) { $0.loadUnaligned(fromByteOffset: 4, as: Int64.self) }
    }
}
