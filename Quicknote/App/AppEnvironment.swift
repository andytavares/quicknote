import Foundation
import QuicknoteKit

/// Shared app-wide state, created once at launch.
final class AppEnvironment {
    private static var shared: AppEnvironment?

    let paths: AppPaths
    let database: AppDatabase

    init(paths: AppPaths, database: AppDatabase) {
        self.paths = paths
        self.database = database
    }

    static func start() throws {
        let paths = AppPaths.live
        shared = AppEnvironment(paths: paths, database: try .onDisk(paths: paths))
    }

    /// The environment for the running app. Tests install their own with `use(_:)`.
    static var current: AppEnvironment {
        guard let shared else { preconditionFailure("AppEnvironment.start() must run before features use it") }
        return shared
    }

    static func use(_ environment: AppEnvironment) {
        shared = environment
    }

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
