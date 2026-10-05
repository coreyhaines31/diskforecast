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
        }
    }

    /// Files that must sit beside the folder for it to count, so a random `build` or `target`
    /// folder is never mistaken for one.
    public var markers: [String] {
        switch self {
        case .nodeModules, .nextBuild: ["package.json"]
        case .rustTarget: ["Cargo.toml"]
        case .swiftBuild: ["Package.swift"]
        case .pythonVenv: ["pyproject.toml", "requirements.txt", "setup.py", "Pipfile"]
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
        }
    }

    /// The kinds found in a folder, given the names of the folders and files directly inside it.
    static func detect(directories: Set<String>, files: Set<String>) -> [ArtifactKind] {
        allCases.filter { kind in
            directories.contains(kind.folderName) && kind.markers.contains(where: files.contains)
        }
    }
}
