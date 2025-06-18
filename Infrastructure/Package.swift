// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Infrastructure",
    platforms: [                          // ← add this block
        .iOS("17.0")
    ],
    products: [
        .library(name: "Infrastructure", targets: ["Infrastructure"])
    ],
    dependencies: [                       // ← depend on the domain layer
        .package(path: "../DomainLogic"),
        .package(path: "../CoreModels")
    ],
    targets: [
        .target(
            name: "Infrastructure",
            dependencies: ["DomainLogic", "CoreModels"]),
        .testTarget(
            name: "InfrastructureTests",
            dependencies: ["Infrastructure", "DomainLogic", "CoreModels"])
    ]
)
