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

    /// The folder's name.
    public var folderName: String {
        switch self {
        case .nodeModules: "node_modules"
        case .nextBuild: ".next"
        case .rustTarget: "target"
        case .swiftBuild: ".build"
        case .pythonVenv: ".venv"
        case .gradleBuild: "build"
        case .cocoaPods: "Pods"
        case .turborepo: ".turbo"
        case .parcel: ".parcel-cache"
        case .pytest: ".pytest_cache"
        case .mypy: ".mypy_cache"
        case .ruff: ".ruff_cache"
        }
    }

    /// Files that must sit beside the folder for it to count, so a random `build` or `target`
    /// folder is never mistaken for one.
    public var markers: [String] {
        switch self {
        case .nodeModules, .nextBuild, .turborepo, .parcel: ["package.json"]
        case .rustTarget: ["Cargo.toml"]
        case .swiftBuild: ["Package.swift"]
        case .pythonVenv, .pytest, .mypy, .ruff: ["pyproject.toml", "requirements.txt", "setup.py", "Pipfile"]
        case .gradleBuild: ["build.gradle", "build.gradle.kts"]
        case .cocoaPods: ["Podfile"]
        }
    }

    public var title: String {
        switch self {
        case .nodeModules: "node_modules"
        case .nextBuild: "Next.js builds"
        case .rustTarget: "Rust build folders"
        case .swiftBuild: "Swift package builds"
        case .pythonVenv: "Python virtual environments"
        case .gradleBuild: "Gradle builds"
        case .cocoaPods: "CocoaPods"
        case .turborepo: "Turborepo caches"
        case .parcel: "Parcel caches"
        case .pytest: "pytest caches"
        case .mypy: "mypy caches"
        case .ruff: "Ruff caches"
        }
    }

    public var rebuildCommand: String {
        switch self {
        case .nodeModules: "npm install"
        case .nextBuild: "next build"
        case .rustTarget: "cargo build"
        case .swiftBuild: "swift build"
        case .pythonVenv: "pip install"
        case .gradleBuild: "gradle build"
        case .cocoaPods: "pod install"
        case .turborepo: "turbo run build"
        case .parcel: "parcel build"
        case .pytest: "pytest"
        case .mypy: "mypy"
        case .ruff: "ruff check"
        }
    }

    /// The kinds found in a folder, given the names of the folders and files directly inside it.
    static func detect(directories: Set<String>, files: Set<String>) -> [ArtifactKind] {
        allCases.filter { kind in
            directories.contains(kind.folderName) && kind.markers.contains(where: files.contains)
        }
    }
}
