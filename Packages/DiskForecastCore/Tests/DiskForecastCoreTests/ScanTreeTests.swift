@testable import DiskForecastCore
import Testing

struct ScanTreeTests {
    // /home
    //   Library (own 0)        -> Developer (own 0) -> Xcode 80, CoreSimulator 10
    //   Movies 30
    //   code 25 -> a 12, b 13
    let tree = ScanTree(
        rootPath: "/home",
        names: ["/home", "Library", "Movies", "code", "Developer", "a", "b", "Xcode", "CoreSimulator"],
        parents: [-1, 0, 0, 0, 1, 3, 3, 4, 4],
        children: [[1, 2, 3], [4], [], [5, 6], [7, 8], [], [], [], []],
        ownBytes: [0, 0, 30, 0, 0, 12, 13, 80, 10]
    )

    @Test func rollsSizesUp() {
        #expect(tree.totalSize == 145)
        #expect(tree.size(of: "/home/Library") == 90)
        #expect(tree.size(of: "/home/Library/Developer/Xcode") == 80)
        #expect(tree.size(of: "/home/nope") == nil)
        #expect(tree.size(of: "/elsewhere") == nil)
    }

    @Test func buildsPaths() {
        #expect(tree.path(of: 7) == "/home/Library/Developer/Xcode")
        #expect(tree.path(of: 0) == "/home")
    }

    @Test func topConsumersDescendIntoDominantFolders() {
        let paths = tree.topConsumers(limit: 3).map(tree.path(of:))
        #expect(paths == ["/home/Library/Developer/Xcode", "/home/Movies", "/home/code"])
    }
}
