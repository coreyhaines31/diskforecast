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

    func artifacts(_ scan: ScanResult, stale: Bool) -> [Candidate] {
        scan.artifacts
            .filter { ($0.projectModified < staleCutoff) == stale && heldBuildFolders[$0.path] == nil }
            .map { artifact in
                let project = (artifact.projectPath as NSString).lastPathComponent
                let age = Age.phrase(from: artifact.projectModified, to: now)
                return Candidate(
                    path: artifact.path, detail: "\(project) · last changed \(age)", rebuildable: artifact.kind
                )
            }
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
