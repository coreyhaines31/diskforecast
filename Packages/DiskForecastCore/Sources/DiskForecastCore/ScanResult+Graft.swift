import Foundation

extension ScanResult {
    /// This scan with a separate scan of one of its skipped folders attached where it belongs.
    /// Lets folders that macOS asks permission for be scanned on their own, so waiting on a
    /// permission prompt never holds up the rest.
    public func grafting(_ branch: ScanResult) -> ScanResult {
        let branchRoot = branch.tree.rootPath
        let parentPath = (branchRoot as NSString).deletingLastPathComponent
        guard tree.node(at: branchRoot) == nil, let parent = tree.node(at: parentPath) else { return self }

        let offset = Int32(tree.names.count)
        var names = tree.names
        var parents = tree.parents
        var children = tree.children
        var ownBytes = tree.ownBytes
        names.append((branchRoot as NSString).lastPathComponent)
        names.append(contentsOf: branch.tree.names.dropFirst())
        parents.append(Int32(parent))
        parents.append(contentsOf: branch.tree.parents.dropFirst().map { $0 + offset })
        children[parent].append(offset)
        children.append(contentsOf: branch.tree.children.map { $0.map { $0 + offset } })
        ownBytes.append(contentsOf: branch.tree.ownBytes)

        let grafted = ScanTree(
            rootPath: tree.rootPath, names: names, parents: parents, children: children, ownBytes: ownBytes
        )
        let movedArtifacts = branch.artifacts.map { artifact in
            ArtifactFinding(
                kind: artifact.kind, path: artifact.path,
                projectModified: artifact.projectModified, node: artifact.node + Int(offset)
            )
        }
        return ScanResult(
            tree: grafted,
            fileCount: fileCount + branch.fileCount,
            largestFiles: Array((largestFiles + branch.largestFiles).sorted { $0.bytes > $1.bytes }
                .prefix(max(largestFiles.count, branch.largestFiles.count))),
            diskImages: (diskImages + branch.diskImages).sorted { $0.bytes > $1.bytes },
            artifacts: (artifacts + movedArtifacts).sorted { $0.path < $1.path },
            deniedCount: deniedCount + branch.deniedCount,
            deniedSamples: deniedSamples + branch.deniedSamples,
            skippedPaths: skippedPaths.filter { $0 != branchRoot } + branch.skippedPaths,
            duration: duration
        )
    }
}
