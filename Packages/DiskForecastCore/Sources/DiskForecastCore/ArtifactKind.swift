import Foundation

/// Folders that a build or package manager recreates on demand.
public enum ArtifactKind: String, Sendable, CaseIterable, Codable {
    case nodeModules
    case nextBuild
    case rustTarget
    case swiftBuild
    case pythonVenv
    case gradleBuild
    case cocoaPods
    case turborepo
    case parcel
    case pytest
    case mypy
    case ruff
    case derivedData
    case svelteKit
    case astro
    case dist
    case mavenTarget
    case pythonBuild
    case plainVenv
    case tox
    case nox
    case gradleCache
    case dotnetBin
    case dotnetObj
    case zigCache
    case oldZigCache
    case railsCache
    case bundle
    case mixBuild

    /// The folder's name.
    public var folderName: String {
        switch self {
        case .nodeModules: "node_modules"
        case .nextBuild: ".next"
        case .rustTarget, .mavenTarget: "target"
        case .swiftBuild: ".build"
        case .pythonVenv: ".venv"
        case .gradleBuild, .pythonBuild: "build"
        case .cocoaPods: "Pods"
        case .turborepo: ".turbo"
        case .parcel: ".parcel-cache"
        case .pytest: ".pytest_cache"
        case .mypy: ".mypy_cache"
        case .ruff: ".ruff_cache"
        case .derivedData: "DerivedData"
        case .svelteKit: ".svelte-kit"
        case .astro: ".astro"
        case .dist: "dist"
        case .plainVenv: "venv"
        case .tox: ".tox"
        case .nox: ".nox"
        case .gradleCache: ".gradle"
        case .dotnetBin: "bin"
        case .dotnetObj: "obj"
        case .zigCache: ".zig-cache"
        case .oldZigCache: "zig-cache"
        case .railsCache: "cache"
        case .bundle: "bundle"
        case .mixBuild: "_build"
        }
    }

    /// What getting the folder back takes, cheapest first.
    public enum RestoreCost: String, Sendable, Comparable {
        /// The tool that made it makes it again the next time the project runs.
        case regenerates
        /// Someone has to run the build.
        case rebuild
        /// Dependencies have to be downloaded and installed again.
        case install

        public var phrase: String {
            switch self {
            case .regenerates: "comes back on the next run"
            case .rebuild: "needs a rebuild"
            case .install: "needs a reinstall"
            }
        }

        public static func < (one: RestoreCost, other: RestoreCost) -> Bool {
            let order: [RestoreCost] = [.regenerates, .rebuild, .install]
            return order.firstIndex(of: one)! < order.firstIndex(of: other)!
        }
    }

    public var restoreCost: RestoreCost {
        switch self {
        case .nextBuild, .turborepo, .parcel, .pytest, .mypy, .ruff, .derivedData, .svelteKit, .astro, .zigCache,
             .oldZigCache, .railsCache:
            .regenerates
        case .rustTarget, .mavenTarget, .swiftBuild, .gradleBuild, .pythonBuild, .dist, .dotnetBin, .dotnetObj,
             .mixBuild:
            .rebuild
        case .nodeModules, .pythonVenv, .plainVenv, .cocoaPods, .tox, .nox, .gradleCache, .bundle:
            .install
        }
    }

    /// The folder it sits in, for one that isn't directly beside its project file: Rails keeps
    /// its cache in `tmp/cache`, and Bundler installs into `vendor/bundle`.
    public var parentName: String? {
        switch self {
        case .railsCache: "tmp"
        case .bundle: "vendor"
        default: nil
        }
    }

    private static let python = ["pyproject.toml", "requirements.txt", "setup.py", "Pipfile"]
    private static let gradle = ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"]
    private static let dotnet = ["*.csproj", "*.fsproj", "*.vbproj"]

    /// Files or folders that must sit beside the folder for it to count, so a random `build` or
    /// `target` folder is never mistaken for one. One starting with `*` matches by its ending.
    public var markers: [String] {
        switch self {
        case .nodeModules, .nextBuild, .turborepo, .parcel, .svelteKit, .astro: ["package.json"]
        case .rustTarget: ["Cargo.toml"]
        case .mavenTarget: ["pom.xml"]
        case .swiftBuild: ["Package.swift"]
        case .derivedData: ["Package.swift", "*.xcodeproj", "*.xcworkspace"]
        case .pythonVenv, .plainVenv, .pytest, .mypy, .ruff: Self.python
        case .tox: Self.python + ["tox.ini"]
        case .nox: Self.python + ["noxfile.py"]
        case .pythonBuild: ["pyproject.toml", "setup.py"]
        case .dist: ["package.json", "pyproject.toml", "setup.py"]
        case .gradleBuild, .gradleCache: Self.gradle
        case .cocoaPods: ["Podfile"]
        case .dotnetBin, .dotnetObj: Self.dotnet
        case .zigCache, .oldZigCache: ["build.zig"]
        // Rails finds its root by config.ru. The rest of tmp holds pids, sockets, and the
        // development secret key, so only the cache counts.
        case .railsCache: ["config.ru"]
        case .bundle: ["Gemfile", "gems.rb"]
        case .mixBuild: ["mix.exs"]
        }
    }

    /// Whether only a repository that ignores the folder can vouch that it's build output. These
    /// names are common for things people make by hand or download prebuilt, where there may be
    /// nothing to rebuild from.
    public var needsRepository: Bool {
        switch self {
        case .dist, .pythonBuild, .dotnetBin, .dotnetObj: true
        default: false
        }
    }

    public var title: String {
        switch self {
        case .nodeModules: "node_modules"
        case .nextBuild: "Next.js builds"
        case .rustTarget: "Rust build folders"
        case .mavenTarget: "Maven build folders"
        case .swiftBuild: "Swift package builds"
        case .derivedData: "Xcode build folders"
        case .pythonVenv, .plainVenv: "Python virtual environments"
        case .pythonBuild: "Python builds"
        case .gradleBuild: "Gradle builds"
        case .gradleCache: "Gradle project caches"
        case .cocoaPods: "CocoaPods"
        case .turborepo: "Turborepo caches"
        case .parcel: "Parcel caches"
        case .pytest: "pytest caches"
        case .mypy: "mypy caches"
        case .ruff: "Ruff caches"
        case .svelteKit: "SvelteKit builds"
        case .astro: "Astro caches"
        case .dist: "dist folders"
        case .tox: "tox environments"
        case .nox: "nox environments"
        case .dotnetBin, .dotnetObj: ".NET build folders"
        case .zigCache, .oldZigCache: "Zig caches"
        case .railsCache: "Rails caches"
        case .bundle: "Bundler gems"
        case .mixBuild: "Mix builds"
        }
    }

    public var rebuildCommand: String {
        switch self {
        case .nodeModules: "npm install"
        case .nextBuild: "next build"
        case .rustTarget: "cargo build"
        case .mavenTarget: "mvn package"
        case .swiftBuild: "swift build"
        case .derivedData: "xcodebuild"
        case .pythonVenv, .plainVenv: "pip install"
        case .pythonBuild: "python -m build"
        case .gradleBuild, .gradleCache: "gradle build"
        case .cocoaPods: "pod install"
        case .turborepo: "turbo run build"
        case .parcel: "parcel build"
        case .pytest: "pytest"
        case .mypy: "mypy"
        case .ruff: "ruff check"
        case .svelteKit: "vite build"
        case .astro: "astro build"
        case .dist: "npm run build"
        case .tox: "tox"
        case .nox: "nox"
        case .dotnetBin, .dotnetObj: "dotnet build"
        case .zigCache, .oldZigCache: "zig build"
        case .railsCache: "rails server"
        case .bundle: "bundle install"
        case .mixBuild: "mix compile"
        }
    }

    private static let besideProject = allCases.filter { $0.parentName == nil }
    private static let folderNames = Set(besideProject.map(\.folderName))
    private static let oneLevelDown = allCases.filter { $0.parentName != nil }

    /// The kinds found in a folder, given the names of the folders and files directly inside it.
    /// A folder name two kinds share, like `target`, is found once, as the first whose marker is there.
    static func detect(directories: Set<String>, files: Set<String>) -> [ArtifactKind] {
        // This runs for every folder in a scan, so the cheap question comes first.
        guard !directories.isDisjoint(with: folderNames) else { return [] }
        let named = besideProject.filter { directories.contains($0.folderName) }
        let endings = Set(directories.union(files).compactMap { name in
            name.lastIndex(of: ".").map { String(name[$0...]) }
        })
        func isBeside(_ marker: String) -> Bool {
            marker.hasPrefix("*") ? endings.contains(String(marker.dropFirst())) : files.contains(marker)
        }
        var found: [ArtifactKind] = []
        for kind in named where kind.markers.contains(where: isBeside) {
            if !found.contains(where: { $0.folderName == kind.folderName }) { found.append(kind) }
        }
        return found
    }

    /// The kinds a project folder may hold one level down, given what's directly inside it. The
    /// folder they'd sit in is there and so is their project file; whether they are isn't known yet.
    static func expected(directories: Set<String>, files: Set<String>) -> [ArtifactKind] {
        oneLevelDown.filter { kind in
            kind.parentName.map(directories.contains) == true && kind.markers.contains(where: files.contains)
        }
    }
}
