import DiskForecastCore
import Foundation

extension SystemDataModel {
    /// The caches that their own tool should clear, for the tools installed here.
    func toolCachesRow() async -> SystemDataRow? {
        var details: [String] = []
        var fixes: [SystemDataFix] = []
        var total: Int64 = 0
        for cache in ToolCache.all {
            guard let tool = ToolCache.executable(named: cache.tool) else { continue }
            // Tools installed with npm are scripts that need node, which sits beside them.
            let path = ["PATH": (tool as NSString).deletingLastPathComponent + ":" + Shell.searchPath]
            let located = await Shell.run(tool, cache.pathArguments, environment: path)
            guard located.succeeded, let folder = ToolCache.path(fromOutput: located.text) else { continue }
            var bytes: Int64 = 0
            if FileManager.default.fileExists(atPath: folder) {
                bytes = await DiskScanner(options: .init(root: URL(filePath: folder))).scan().tree.totalSize
            }
            // Homebrew's cleanup also removes old versions outside this folder, even when the folder
            // is empty or gone; its dry run says how much.
            if let dryRun = cache.dryRunArguments {
                let preview = await Shell.run(tool, dryRun, environment: path)
                bytes = ToolCache.freedBytes(fromDryRun: preview.text) ?? bytes
            }
            guard bytes >= CleanupCatalog.minimumToolCacheBytes else { continue }
            total += bytes
            details.append("\(cache.name): \(Bytes.format(bytes)) · \(cache.kindNote)")
            fixes.append(SystemDataFix(title: cache.action, confirmation: cache.confirmation, command: cache.command) {
                await Shell.run(tool, cache.cleanArguments, environment: path, timeout: Shell.fixTimeout)
            })
        }
        guard !fixes.isEmpty else { return nil }
        return SystemDataRow(
            id: "tool-caches", title: "Package manager caches",
            explanation: "Downloads and builds that pnpm, uv, Go, and Homebrew keep, cleared with each tool's own "
                + "command. A prune removes only what nothing uses. A clear removes everything, and the next "
                + "install or build fetches it again.",
            bytes: total, details: details, fixes: fixes
        )
    }
}
