// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "QuicknoteKit",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "QuicknoteKit", targets: ["QuicknoteKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", exact: "7.11.1")
    ],
    targets: [
        .target(
            name: "QuicknoteKit",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .testTarget(name: "QuicknoteKitTests", dependencies: ["QuicknoteKit"]),
    ]
)
