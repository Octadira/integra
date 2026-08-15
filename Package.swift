// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Integra",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Integra", targets: ["Integra"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Integra",
            dependencies: [],
            path: "Sources/Integra"
        )
    ]
)
