import Foundation

@testable import QuicknoteKit

/// A throwaway `AppPaths` plus a scratch folder; call `remove()` when the test ends.
struct TemporaryPaths {
    let paths: AppPaths
    let scratch: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "quicknote-\(UUID().uuidString)")
        paths = AppPaths(root: base.appending(path: "root"))
        scratch = base.appending(path: "scratch")
        try paths.createDirectories()
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    func makeFile(named name: String, contents: String = "hello") throws -> URL {
        let url = scratch.appending(path: name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func remove() {
        try? FileManager.default.removeItem(at: scratch.deletingLastPathComponent())
    }
}
