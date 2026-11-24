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
        }
    }

    private static let folderNames = Set(allCases.map(\.folderName))

    /// The kinds found in a folder, given the names of the folders and files directly inside it.
    /// A folder name two kinds share, like `target`, is found once, as the first whose marker is there.
    static func detect(directories: Set<String>, files: Set<String>) -> [ArtifactKind] {
        // This runs for every folder in a scan, so the cheap question comes first.
        guard !directories.isDisjoint(with: folderNames) else { return [] }
        let named = allCases.filter { directories.contains($0.folderName) }
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
}
