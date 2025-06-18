// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DomainLogic",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DomainLogic",
            targets: ["DomainLogic"]),
    ],
    dependencies: [
        .package(path: "../CoreModels")
    ],
    targets: [
        .target(
            name: "DomainLogic",
            dependencies: ["CoreModels"]),       // ← exposes the module to the compiler
        .testTarget(
            name: "DomainLogicTests",
            dependencies: ["DomainLogic", "CoreModels"])
    ]
)
