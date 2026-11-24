import Darwin
import Foundation
import os

/// Why a build folder isn't simply rebuildable: something in it exists nowhere else, or git
/// doesn't treat it as a build folder at all. Learned from mattt/plonge.
public enum BuildFolderHold: Sendable, Equatable {
    /// A git checkout sits at this path inside it, or is the folder itself when empty. Its
    /// commits and edits are invisible to the project's own repository.
    case holdsCheckout(String)
    /// The project's repository tracks files in it.
    case tracked
    /// The project's repository doesn't ignore it.
    case notIgnored
    /// It's in a repository and git couldn't say how it stands.
    case unchecked
    /// Its name is a common one for things made by hand or downloaded prebuilt, and no
    /// repository ignores it to say it's build output.
    case unvouched

    public var reason: String {
        switch self {
        case .holdsCheckout(""): "is a git checkout itself"
        case .holdsCheckout(let inner): "holds a git checkout at \(inner)"
        case .tracked: "has files git tracks"
        case .notIgnored: "git doesn't ignore it"
        case .unchecked: "git couldn't check it"
        case .unvouched: "no repository marks it as build output"
        }
    }

    /// The reason as the end of a sentence that starts "it".
    var sentence: String {
        switch self {
        case .notIgnored: "isn't ignored by git"
        case .unchecked: "couldn't be checked with git"
        case .unvouched: "isn't marked as build output by any repository"
        default: reason
        }
    }

    /// How deep the look before removing goes. Package managers put the checkouts they clone
    /// within a few folders of the top, and a full walk of every build folder would take minutes.
    static let recheckDepth = 4

    /// Checks a build folder of a given kind. `checkouts` are the folders in it that hold a
    /// `.git`, as the scan found them. Nil when a rebuild brings back everything in it.
    public static func check(folder: String, kind: ArtifactKind, checkouts: [String]) -> BuildFolderHold? {
        let project = (folder as NSString).deletingLastPathComponent
        for checkout in checkouts.sorted() where checkout == folder || checkout.hasPrefix(folder + "/") {
            if isRestorablePackage(checkout, kind: kind, buildFolder: folder, project: project) { continue }
            return .holdsCheckout(String(checkout.dropFirst(folder.count + 1)))
        }
        // Outside any repository git has no say, and nothing to protect. Without git installed
        // there's no one to ask, and holding every build folder back would help nobody. A name
        // like dist is the exception: only a repository can say it's build output.
        guard GitState.executable != nil, GitState.isInsideRepository(project) else {
            return kind.needsRepository ? .unvouched : nil
        }
        switch GitState.standing(of: (folder as NSString).lastPathComponent, in: project) {
        case .ignored: return nil
        case .tracked: return .tracked
        case .untracked: return .notIgnored
        case nil: return .unchecked
        }
    }

    /// Checks a build folder as it is now, finding the checkouts in it by looking
    /// `recheckDepth` folders deep. For right before it's removed, when the scan may be hours old.
    public static func recheck(folder: String, kind: ArtifactKind) -> BuildFolderHold? {
        check(folder: folder, kind: kind, checkouts: checkouts(in: folder, depth: recheckDepth))
    }

    /// The folders at or under `folder`, down to `depth` levels, that hold a `.git`. Links aren't
    /// followed: what they lead to isn't in the folder.
    static func checkouts(in folder: String, depth: Int) -> [String] {
        var info = stat()
        guard lstat(folder, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else { return [] }
        // The deepest level only needs the one name looked up, not the folder read.
        guard depth > 0 else { return lstat(folder + "/.git", &info) == 0 ? [folder] : [] }
        guard let directory = opendir(folder) else { return [] }
        var found: [String] = []
        var subfolders: [String] = []
        // readdir says what each entry is, which saves asking about every file in a big folder.
        while let entry = readdir(directory) {
            let name = withUnsafeBytes(of: &entry.pointee.d_name) { bytes in
                String(bytes: bytes.prefix(Int(entry.pointee.d_namlen)), encoding: .utf8) ?? ""
            }
            if name == ".git" {
                found.append(folder)
            } else if name != ".", name != "..", [DT_DIR, DT_UNKNOWN].contains(Int32(entry.pointee.d_type)) {
                subfolders.append(name)
            }
        }
        closedir(directory)
        for name in subfolders {
            found += checkouts(in: folder + "/" + name, depth: depth - 1)
        }
        return found
    }

    /// Whether a checkout is one Swift Package Manager cloned and can clone again: in the
    /// `checkouts` folder of a `.build` or of Xcode's `SourcePackages`, at a revision a
    /// `Package.resolved` of the project pins, with nothing changed.
    static func isRestorablePackage(
        _ checkout: String, kind: ArtifactKind, buildFolder: String, project: String
    ) -> Bool {
        let parent = (checkout as NSString).deletingLastPathComponent
        let inside = parent.dropFirst(buildFolder.count + 1).split(separator: "/")
        switch kind {
        case .swiftBuild: guard inside == ["checkouts"] else { return false }
        // Xcode keeps them in SourcePackages, straight in DerivedData or in a project's folder there.
        case .derivedData: guard inside.suffix(2) == ["SourcePackages", "checkouts"], inside.count <= 3
            else { return false }
        default: return false
        }
        guard let head = GitState.head(at: checkout), pinnedRevisions(forProject: project).contains(head)
        else { return false }
        return GitState.read(at: checkout)?.changed == 0
    }

    /// The revisions pinned by a project's `Package.resolved` files: its own, and the ones Xcode
    /// keeps inside a project or workspace.
    static func pinnedRevisions(forProject project: String) -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: project)) ?? []
        var files = [project + "/Package.resolved"]
        for name in names {
            let shared = "/xcshareddata/swiftpm/Package.resolved"
            if name.hasSuffix(".xcodeproj") { files.append(project + "/" + name + "/project.xcworkspace" + shared) }
            if name.hasSuffix(".xcworkspace") { files.append(project + "/" + name + shared) }
        }
        return files.reduce(into: Set<String>()) { $0.formUnion(pinnedRevisions(in: $1)) }
    }

    /// The revisions a `Package.resolved` pins, in either of its formats.
    static func pinnedRevisions(in file: String) -> Set<String> {
        guard let data = FileManager.default.contents(atPath: file),
              let resolved = try? JSONDecoder().decode(ResolvedPackages.self, from: data)
        else { return [] }
        return Set(((resolved.pins ?? []) + (resolved.object?.pins ?? [])).compactMap(\.state.revision))
    }
}

extension Trasher {
    /// The build folders among `entries` that were listed as rebuildable and no longer are, and
    /// why each stays. The list can be hours old, and a checkout may have been cloned in since.
    func heldBuildFolders(in entries: [CleanupEntry]) -> [(path: String, reason: String)] {
        // One that's refused anyway is reported as that.
        let folders = entries.filter { $0.rebuildable != nil && refusal(for: $0.path) == nil }
        // Each look reads a few levels of the folder and runs git once, so hundreds of them at
        // once would otherwise be a long silence before anything moves.
        let holds = OSAllocatedUnfairLock(initialState: [Int: BuildFolderHold]())
        DispatchQueue.concurrentPerform(iterations: folders.count) { index in
            guard let kind = folders[index].rebuildable,
                  let hold = BuildFolderHold.recheck(folder: folders[index].path, kind: kind)
            else { return }
            holds.withLock { $0[index] = hold }
        }
        let held = holds.withLock { $0 }
        return folders.indices.compactMap { index in
            held[index].map { (folders[index].path, "Left alone: it \($0.sentence).") }
        }
    }
}

/// `Package.resolved`: version 1 keeps its pins under `object`, later versions at the top.
private struct ResolvedPackages: Decodable {
    struct State: Decodable { let revision: String? }
    struct Pin: Decodable { let state: State }
    struct Object: Decodable { let pins: [Pin] }
    let pins: [Pin]?
    let object: Object?
}
