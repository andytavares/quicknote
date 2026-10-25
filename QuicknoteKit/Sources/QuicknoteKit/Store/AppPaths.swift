import Foundation

/// Where Quicknote keeps its files. Everything lives under `root`, so "Delete everything" removes one folder.
public struct AppPaths: Sendable, Equatable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    /// `~/Library/Application Support/Quicknote`.
    public static var live: AppPaths {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return AppPaths(root: support.appending(path: "Quicknote", directoryHint: .isDirectory))
    }

    public var database: URL { root.appending(path: "quicknote.sqlite") }
    public var attachments: URL { root.appending(path: "Attachments", directoryHint: .isDirectory) }

    public func createDirectories() throws {
        try FileManager.default.createDirectory(at: attachments, withIntermediateDirectories: true)
    }
}
