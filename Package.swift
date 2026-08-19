// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Integra",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Integra", targets: ["Integra"]),
        .executable(name: "integra-mcp", targets: ["integra-mcp"]),
        .executable(name: "IntegraTestRunner", targets: ["IntegraTestRunner"]),
        .library(name: "IntegraCore", targets: ["IntegraCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "IntegraCore",
            dependencies: [],
            path: "Sources/IntegraCore"
        ),
        .executableTarget(
            name: "Integra",
            dependencies: ["IntegraCore"],
            path: "Sources/IntegraApp"
        ),
        .executableTarget(
            name: "integra-mcp",
            dependencies: ["IntegraCore"],
            path: "Sources/IntegraMCP"
        ),
        .executableTarget(
            name: "IntegraTestRunner",
            dependencies: ["IntegraCore"],
            path: "Tests/IntegraTestRunner"
        )
    ]
)
