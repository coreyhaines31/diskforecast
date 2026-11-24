@testable import DiskForecastCore
import Foundation
import Testing

struct BuildFolderHoldTests {
    let fixture: GitFixture
    var project: String { fixture.main }

    init() throws {
        fixture = try GitFixture()
    }

    private func write(_ path: String, _ text: String = "x") throws {
        let url = URL(filePath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    private func check(
        _ name: String, kind: ArtifactKind = .nodeModules, in project: String? = nil
    ) -> BuildFolderHold? {
        BuildFolderHold.recheck(folder: (project ?? self.project) + "/" + name, kind: kind)
    }

    @Test func anIgnoredFolderIsRebuildable() throws {
        try write(project + "/.gitignore", "node_modules\n")
        try write(project + "/node_modules/pkg/index.js")
        #expect(check("node_modules") == nil)
    }

    @Test func aCacheThatIgnoresItselfIsRebuildable() throws {
        // Ruff, pytest, and mypy write a .gitignore of "*" into their cache.
        try write(project + "/.ruff_cache/.gitignore", "*\n")
        try write(project + "/.ruff_cache/0.6.0/123")
        #expect(check(".ruff_cache", kind: .ruff) == nil)
    }

    @Test func aFolderGitDoesNotIgnoreIsHeld() throws {
        try write(project + "/dist/app.js")
        #expect(check("dist") == .notIgnored)
    }

    @Test func aFolderWithTrackedFilesIsHeld() throws {
        try write(project + "/.gitignore", "build\n")
        try write(project + "/build/release-notes.md")
        try fixture.git(["add", "-f", "build/release-notes.md"], in: project)
        try write(project + "/build/output.o")
        #expect(check("build", kind: .gradleBuild) == .tracked)
    }

    @Test func aFolderOutsideAnyRepositoryIsRebuildable() throws {
        let loose = fixture.base.path + "/loose"
        try write(loose + "/node_modules/pkg/index.js")
        #expect(check("node_modules", in: loose) == nil)
    }

    @Test func aCommonNameNeedsARepositoryToVouchForIt() throws {
        let loose = fixture.base.path + "/downloaded-library"
        try write(loose + "/dist/library.min.js")
        #expect(check("dist", kind: .dist, in: loose) == .unvouched)
        #expect(check("bin", kind: .dotnetBin, in: loose) == .unvouched)
        try write(project + "/.gitignore", "dist\n")
        try write(project + "/dist/app.js")
        #expect(check("dist", kind: .dist) == nil)
    }

    @Test func aMixBuildWithAReleaseIsHeld() throws {
        try write(project + "/.gitignore", "_build\n")
        try write(project + "/_build/dev/lib/app/ebin/app.beam")
        #expect(check("_build", kind: .mixBuild) == nil)
        try write(project + "/_build/prod/rel/app/releases/COOKIE")
        #expect(check("_build", kind: .mixBuild) == .holdsRelease("prod"))
        #expect(BuildFolderHold.holdsRelease("prod").reason == "holds a release at prod/rel")
    }

    @Test func looksFurtherDownForTheGemsBundlerClones() throws {
        try write(project + "/.gitignore", "vendor/bundle\n")
        try write(project + "/vendor/bundle/ruby/3.3.0/bundler/gems/forked/.git/HEAD")
        let hold = BuildFolderHold.recheck(folder: project + "/vendor/bundle", kind: .bundle)
        #expect(hold == .holdsCheckout("ruby/3.3.0/bundler/gems/forked"))
    }

    @Test func aRailsCacheGitIgnoresIsRebuildable() throws {
        try write(project + "/.gitignore", "/tmp/*\n")
        try write(project + "/tmp/cache/bootsnap/load-path-cache")
        #expect(BuildFolderHold.recheck(folder: project + "/tmp/cache", kind: .railsCache) == nil)
    }

    @Test func aCheckoutInsideIsHeldEvenWhenTheFolderIsIgnored() throws {
        try write(project + "/.gitignore", ".venv\n")
        try write(project + "/.venv/src/forked-lib/.git/HEAD")
        #expect(check(".venv", kind: .pythonVenv) == .holdsCheckout("src/forked-lib"))
        #expect(BuildFolderHold.holdsCheckout("src/forked-lib").reason == "holds a git checkout at src/forked-lib")
    }

    @Test func aFolderThatIsItselfACheckoutIsHeld() throws {
        try write(project + "/.gitignore", "dist\n")
        try write(project + "/dist/.git", "gitdir: ../.git/worktrees/pages\n")
        #expect(check("dist") == .holdsCheckout(""))
    }

    @Test func theLookBeforeRemovingStopsAfterAFewLevels() throws {
        let folder = project + "/node_modules"
        try write(folder + "/a/b/c/.git/HEAD")
        try write(folder + "/a/b/c/d/e/.git/HEAD")
        #expect(BuildFolderHold.checkouts(in: folder, depth: 4) == [folder + "/a/b/c"])
    }

    @Test func checkoutsAreNotLookedForThroughLinks() throws {
        let folder = project + "/node_modules"
        try write(fixture.base.path + "/elsewhere/.git/HEAD")
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            atPath: folder + "/linked", withDestinationPath: fixture.base.path + "/elsewhere"
        )
        #expect(BuildFolderHold.checkouts(in: folder, depth: 4).isEmpty)
    }

    // MARK: Swift packages

    /// A package whose `.build/checkouts/dep` is a clone at the revision `Package.resolved` pins.
    private func package() throws -> (project: String, checkout: String) {
        let package = fixture.base.path + "/package"
        let checkout = package + "/.build/checkouts/dep"
        try write(package + "/Package.swift")
        try fixture.git(["init", "-q"], in: package)
        try write(package + "/.gitignore", ".build\n")
        try write(package + "/.build/checkouts/.keep")
        try fixture.git(["clone", "-q", fixture.main, checkout], in: package)
        let head = try #require(GitState.head(at: checkout))
        try write(package + "/Package.resolved", """
        {"pins": [{"identity": "dep", "state": {"revision": "\(head)", "version": "1.0.0"}}], "version": 2}
        """)
        return (package, checkout)
    }

    @Test func anUntouchedPackageCheckoutIsRebuildable() throws {
        let package = try package()
        #expect(check(".build", kind: .swiftBuild, in: package.project) == nil)
    }

    @Test func anEditedPackageCheckoutIsHeld() throws {
        let package = try package()
        try write(package.checkout + "/README.md", "edited")
        #expect(check(".build", kind: .swiftBuild, in: package.project) == .holdsCheckout("checkouts/dep"))
    }

    @Test func aPackageCheckoutWithItsOwnCommitsIsHeld() throws {
        let package = try package()
        try fixture.commit(in: package.checkout)
        #expect(check(".build", kind: .swiftBuild, in: package.project) == .holdsCheckout("checkouts/dep"))
    }

    @Test func aCheckoutElsewhereInASwiftBuildIsHeld() throws {
        let package = try package()
        try write(package.project + "/.build/scratch/.git/HEAD")
        #expect(check(".build", kind: .swiftBuild, in: package.project) == .holdsCheckout("scratch"))
    }

    @Test func anUntouchedXcodePackageCheckoutIsRebuildable() throws {
        let app = fixture.base.path + "/app"
        let checkout = app + "/DerivedData/App-abc/SourcePackages/checkouts/dep"
        try fixture.git(["init", "-q", app], in: fixture.base.path)
        try write(app + "/.gitignore", "DerivedData\n")
        try write(app + "/DerivedData/App-abc/SourcePackages/checkouts/.keep")
        try fixture.git(["clone", "-q", fixture.main, checkout], in: app)
        let head = try #require(GitState.head(at: checkout))
        try write(app + "/App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved", """
        {"pins": [{"identity": "dep", "state": {"revision": "\(head)"}}], "version": 2}
        """)
        #expect(check("DerivedData", kind: .derivedData, in: app) == nil)
        try write(checkout + "/README.md", "edited")
        let held = BuildFolderHold.holdsCheckout("App-abc/SourcePackages/checkouts/dep")
        #expect(check("DerivedData", kind: .derivedData, in: app) == held)
    }

    @Test func readsTheOlderPackageResolvedFormat() throws {
        let file = fixture.base.path + "/Package.resolved"
        try write(file, #"{"object": {"pins": [{"state": {"revision": "abc"}}]}, "version": 1}"#)
        #expect(BuildFolderHold.pinnedRevisions(in: file) == ["abc"])
    }
}
