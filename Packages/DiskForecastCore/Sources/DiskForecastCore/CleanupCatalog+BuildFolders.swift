import Foundation

extension CleanupCatalog {
    /// Checks every build folder the scan found. Each check in a repository runs git once.
    func holds(in scan: ScanResult) -> [String: BuildFolderHold] {
        var held: [String: BuildFolderHold] = [:]
        for artifact in scan.artifacts {
            let checkouts = scan.nestedRepositories.filter {
                $0 == artifact.path || $0.hasPrefix(artifact.path + "/")
            }
            held[artifact.path] = buildFolderHold(artifact, checkouts)
        }
        return held
    }

    func artifacts(_ scan: ScanResult, tier: BuildTier) -> [Candidate] {
        scan.artifacts
            .filter { heldBuildFolders[$0.path] == nil && self.tier(of: $0) == tier }
            .map { artifact in
                let project = (artifact.projectPath as NSString).lastPathComponent
                var when = "last changed \(Age.phrase(from: artifact.projectModified, to: now))"
                if tier == .quiet, let worked = lastWorkedIn[artifact.projectPath] {
                    when = "last commit or agent session \(Age.phrase(from: worked, to: now))"
                }
                return Candidate(
                    path: artifact.path,
                    detail: "\(project) · \(when) · \(artifact.kind.restoreCost.phrase)",
                    rebuildable: artifact.kind
                )
            }
    }

    /// Which list a build folder belongs on.
    enum BuildTier {
        /// In a project nobody has changed for a month.
        case stale
        /// In a recent project, but it makes itself again on the next run and nothing has written
        /// to it for a day.
        case idleOutput
        /// In a recent project where nobody has committed, checked out, or talked to a coding agent
        /// for a week, and nothing has written to the folder for a day.
        case quiet
        /// Everything else in a recent project.
        case active
    }

    /// How long output that regenerates has to sit unwritten before it's offered as safe to clear.
    static let idleOutputAfter: TimeInterval = 86_400

    /// How long a project has to go without a commit, checkout, or agent conversation to count as quiet.
    static let quietAfter: TimeInterval = 7 * 86_400

    func tier(of artifact: ArtifactFinding) -> BuildTier {
        if artifact.projectModified < staleCutoff { return .stale }
        let regenerates = artifact.kind.restoreCost == .regenerates
        // Reading a folder like node_modules to see when it was written is slow, so the cheap
        // question about the project comes first.
        if !regenerates {
            guard let worked = lastWorkedIn[artifact.projectPath], now.timeIntervalSince(worked) >= Self.quietAfter
            else { return .active }
        }
        guard let written = Self.lastWritten(artifact.path), now.timeIntervalSince(written) >= Self.idleOutputAfter
        else { return .active }
        return regenerates ? .idleOutput : .quiet
    }

    /// The newest modification date of the folder and the entries directly in it. A dev server or
    /// a build writes there as it works. Nil when it can't be read.
    static func lastWritten(_ path: String) -> Date? {
        let files = FileManager.default
        guard let names = try? files.contentsOfDirectory(atPath: path) else { return nil }
        let dates = ([path] + names.map { path + "/" + $0 }).compactMap {
            (try? files.attributesOfItem(atPath: $0))?[.modificationDate] as? Date
        }
        return dates.max()
    }

    /// Build folders that hold something a rebuild wouldn't bring back, each with what that is.
    func heldArtifacts(_ scan: ScanResult) -> [Candidate] {
        scan.artifacts.compactMap { artifact in
            guard let hold = heldBuildFolders[artifact.path] else { return nil }
            let project = (artifact.projectPath as NSString).lastPathComponent
            return Candidate(path: artifact.path, detail: "\(project) · \(hold.reason)")
        }
    }
}
