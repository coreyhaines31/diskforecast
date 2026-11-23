import Darwin
import Foundation

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

    public var reason: String {
        switch self {
        case .holdsCheckout(""): "is a git checkout itself"
        case .holdsCheckout(let inner): "holds a git checkout at \(inner)"
        case .tracked: "has files git tracks"
        case .notIgnored: "git doesn't ignore it"
        case .unchecked: "git couldn't check it"
        }
    }

    /// The reason as the end of a sentence that starts "it".
    var sentence: String {
        switch self {
        case .notIgnored: "isn't ignored by git"
        case .unchecked: "couldn't be checked with git"
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
            if kind == .swiftBuild, isRestorablePackage(checkout, buildFolder: folder, project: project) { continue }
            return .holdsCheckout(String(checkout.dropFirst(folder.count + 1)))
        }
        // Outside any repository git has no say, and nothing to protect.
        guard GitState.isInsideRepository(project) else { return nil }
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

    /// The folders at or under `folder`, down to `depth` levels, that hold a `.git`.
    static func checkouts(in folder: String, depth: Int) -> [String] {
        var found: [String] = []
        var info = stat()
        if lstat(folder + "/.git", &info) == 0 { found.append(folder) }
        guard depth > 0, let names = try? FileManager.default.contentsOfDirectory(atPath: folder) else { return found }
        for name in names where name != ".git" {
            let child = folder + "/" + name
            // Links aren't followed: what they lead to isn't in the folder.
            guard lstat(child, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else { continue }
            found += checkouts(in: child, depth: depth - 1)
        }
        return found
    }

    /// Whether a checkout is one Swift Package Manager cloned into `.build/checkouts` and can
    /// clone again: at the revision `Package.resolved` pins, with nothing changed.
    static func isRestorablePackage(_ checkout: String, buildFolder: String, project: String) -> Bool {
        guard (checkout as NSString).deletingLastPathComponent == buildFolder + "/checkouts",
              let head = GitState.head(at: checkout),
              pinnedRevisions(in: project + "/Package.resolved").contains(head)
        else { return false }
        return GitState.read(at: checkout)?.changed == 0
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
        entries.compactMap { entry in
            // One that's refused anyway is reported as that.
            guard let kind = entry.rebuildable, refusal(for: entry.path) == nil,
                  let hold = BuildFolderHold.recheck(folder: entry.path, kind: kind)
            else { return nil }
            return (entry.path, "Left alone: it \(hold.sentence).")
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
