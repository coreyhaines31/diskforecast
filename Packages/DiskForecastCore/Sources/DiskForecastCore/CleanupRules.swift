import Foundation

struct CleanupRule {
    let id: String
    let title: String
    let explanation: String
    let group: CleanupGroup
    var action: CleanupAction = .trash
    var minimumBytes: Int64 = CleanupCatalog.minimumEntryBytes
    let candidates: (CleanupCatalog, ScanResult) -> [CleanupCatalog.Candidate]
}

extension CleanupCatalog {
    /// Most specific first, so a broad rule (like everything in Downloads) never lists what a
    /// specific one (like a disk image in Downloads) already explained.
    var rules: [CleanupRule] {
        [
            CleanupRule(
                id: "stale-builds", title: "Build folders in old projects",
                explanation: "node_modules, build, and package folders in projects you haven't changed in "
                    + "\(staleAfterDays)+ days. Reinstalling or rebuilding brings them back.",
                group: .safeToClear
            ) { catalog, scan in catalog.artifacts(scan, stale: true) },
            CleanupRule(
                id: "worktree-leftovers", title: "Leftover worktree data",
                explanation: "Git's records for worktrees whose folder is gone, including any submodule copies. "
                    + "git worktree prune removes the same thing.",
                group: .safeToClear
            ) { catalog, scan in catalog.leftoverWorktreeData(scan) },
            CleanupRule(
                id: "ollama", title: "Ollama models",
                explanation: "Local AI models downloaded by Ollama. Running ollama pull downloads one again, "
                    + "and ollama rm removes a single model.",
                group: .worthALook
            ) { catalog, _ in catalog.fixed([".ollama/models"]) },
            CleanupRule(
                id: "lm-studio", title: "LM Studio models",
                explanation: "Local AI models downloaded in LM Studio. You can download any of them again "
                    + "from LM Studio.",
                group: .worthALook
            ) { catalog, scan in
                [".lmstudio/models", ".cache/lm-studio/models"].flatMap { folder in
                    catalog.children(of: folder, in: scan).flatMap { publisher in
                        catalog.children(of: String(publisher.path.dropFirst(catalog.home.count + 1)), in: scan)
                    }
                }
            },
            CleanupRule(
                id: "huggingface", title: "Hugging Face models",
                explanation: "Models and datasets cached by Hugging Face tools. They download again the next time "
                    + "a script asks for them.",
                group: .worthALook
            ) { catalog, scan in catalog.children(of: ".cache/huggingface/hub", in: scan) { $0.hasPrefix(".") } },
            CleanupRule(
                id: "screen-recordings", title: "Screen recordings",
                explanation: "Screen and audio history that Screenpipe or Rewind records so you can search it. "
                    + "Moving it to the Trash erases that history, so quit the app first. Lowering the app's "
                    + "own retention setting keeps recent days instead.",
                group: .worthALook
            ) { catalog, _ in
                let apps = [
                    (".screenpipe/data", "Screenpipe"),
                    ("Library/Application Support/com.memoryvault.MemoryVault", "Rewind")
                ]
                return apps.map { CleanupCatalog.Candidate(path: catalog.path($0.0), name: $0.1) }
            },
            CleanupRule(
                id: "xcode-derived-data", title: "Xcode DerivedData",
                explanation: "Xcode's build products and indexes. Xcode rebuilds them the next time you build.",
                group: .safeToClear
            ) { catalog, scan in catalog.children(of: "Library/Developer/Xcode/DerivedData", in: scan) },
            CleanupRule(
                id: "device-support", title: "Xcode device support",
                explanation: "Debug symbols copied from devices you've plugged in. Xcode copies them again when you "
                    + "connect that device.",
                group: .safeToClear
            ) { catalog, scan in
                ["iOS DeviceSupport", "watchOS DeviceSupport", "tvOS DeviceSupport", "visionOS DeviceSupport"]
                    .flatMap { catalog.children(of: "Library/Developer/Xcode/" + $0, in: scan) }
            },
            CleanupRule(
                id: "simulator-caches", title: "Simulator caches",
                explanation: "Caches the iOS Simulator rebuilds on its own. Simulators and their apps aren't touched.",
                group: .safeToClear
            ) { catalog, _ in catalog.fixed(["Library/Developer/CoreSimulator/Caches"]) },
            CleanupRule(
                id: "xcode-archives", title: "Xcode archives",
                explanation: "Builds you archived for release. Keep the ones you still need to read crash reports for.",
                group: .worthALook
            ) { catalog, scan in catalog.children(of: "Library/Developer/Xcode/Archives", in: scan) },
            CleanupRule(
                id: "agent-leftovers", title: "Left behind by coding agents",
                explanation: "Tools coding agents download to do their work: packages npx runs, like MCP servers, "
                    + "browsers for Playwright, Puppeteer, and agent-browser, and older Claude Code versions. The "
                    + "newest browser and Claude Code stay, and anything still running is left alone. The rest "
                    + "downloads again when an agent needs it.",
                group: .safeToClear
            ) { catalog, scan in catalog.agentLeftovers(scan) },
            CleanupRule(
                id: "package-caches", title: "Package manager caches",
                explanation: "Downloads kept by npm, Bun, Cargo, Gradle, pip, and friends so installs are "
                    + "faster. They fill back up as you install packages.",
                group: .safeToClear
            ) { catalog, scan in
                // Not the pnpm store: projects share its files, so deleting it frees far less than its
                // size. pnpm store prune is the right tool.
                catalog.fixed([
                    ".npm/_cacache", ".bun/install/cache",
                    ".cargo/registry", ".gradle/caches", ".gradle/wrapper/dists"
                ]) + catalog.children(of: ".cache", in: scan) {
                    ["huggingface", "lm-studio", "puppeteer"].contains($0)
                }
            },
            CleanupRule(
                id: "disk-images", title: "Disk images and installers",
                explanation: "DMG, ISO, and PKG files. Once an app is installed, its installer is usually not needed.",
                group: .worthALook
            ) { catalog, scan in catalog.diskImages(scan) },
            CleanupRule(
                id: "docker", title: "Docker disk image",
                explanation: "Everything Docker stores: images, containers, and volumes, in one file. Reclaim "
                    + "space with Docker's own cleanup in System Data, not by deleting the file.",
                group: .worthALook, action: .useTool("docker")
            ) { catalog, _ in catalog.fixed(["Library/Containers/com.docker.docker/Data/vms"]) },
            CleanupRule(
                id: "virtual-machines", title: "Virtual machines",
                explanation: "Whole computers saved as files by Parallels, UTM, or VMware. Each is usually "
                    + "many gigabytes.",
                group: .worthALook
            ) { catalog, scan in
                ["Parallels", "Virtual Machines.localized", "Library/Containers/com.utmapp.UTM/Data/Documents"]
                    .flatMap { catalog.children(of: $0, in: scan) }
            },
            CleanupRule(
                id: "active-builds", title: "Build folders in active projects",
                explanation: "Build and package folders in projects you've changed recently. Safe to remove, but "
                    + "you'll wait for a reinstall or rebuild next time.",
                group: .worthALook
            ) { catalog, scan in catalog.artifacts(scan, stale: false) },
            CleanupRule(
                id: "git-worktrees", title: "Git worktrees",
                explanation: "Extra checkouts of a repository, often left behind by coding agents like Claude Code, "
                    + "Codex, and Conductor. Each shows changes and commits that exist only there; files git "
                    + "ignores, like .env, aren't counted. Its records in the repository go with it, as with git "
                    + "worktree remove; the branch and its commits stay.",
                group: .worthALook
            ) { catalog, scan in catalog.worktrees(scan) },
            CleanupRule(
                id: "orphaned-workspaces", title: "Editor data for deleted projects",
                explanation: "What VS Code, Cursor, and similar editors saved about projects that are no longer on "
                    + "your Mac, like open tabs and, in Cursor, chat history.",
                group: .worthALook
            ) { catalog, scan in catalog.orphanedWorkspaces(scan) },
            CleanupRule(
                id: "app-support-caches", title: "Editor and chat app caches",
                explanation: "Caches that VS Code, Cursor, Slack, Discord, Figma, and other apps built on web tech "
                    + "keep with their data. Settings, sign-ins, and history aren't touched. Quit the app first.",
                group: .safeToClear
            ) { catalog, scan in catalog.appSupportCaches(scan) },
            CleanupRule(
                id: "app-caches", title: "App caches",
                explanation: "Files apps keep to load things faster. Apps recreate what they need. macOS's own caches "
                    + "are left alone.",
                group: .safeToClear
            ) { catalog, scan in
                catalog.children(of: "Library/Caches", in: scan) {
                    $0.hasPrefix("com.apple.") || $0 == "CloudKit" || $0 == "ms-playwright"
                }
            },
            CleanupRule(
                id: "logs", title: "Logs",
                explanation: "Records apps write about what they did. Useful for troubleshooting, then rarely "
                    + "read again.",
                group: .safeToClear
            ) { catalog, scan in catalog.children(of: "Library/Logs", in: scan) },
            CleanupRule(
                id: "downloads", title: "Big downloads",
                explanation: "Large files and folders in Downloads. Most were needed once.",
                group: .worthALook, minimumBytes: CleanupCatalog.minimumDownloadBytes
            ) { catalog, scan in catalog.downloads(scan) }
        ]
    }
}
