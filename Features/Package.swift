// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Features",
    platforms: [                    // ← tell SPM what you target
        .iOS("17.0")
    ],
    products: [
        .library(name: "Features", targets: ["Features"])
    ],
    dependencies: [
        .package(path: "../DomainLogic"),    // use-case layer
        .package(path: "../Infrastructure")  // concrete actors
    ],
    targets: [
        .target(
            name: "Features",
            dependencies: [
                "DomainLogic",
                "Infrastructure"
            ]),
        .testTarget(
            name: "FeaturesTests",
            dependencies: ["Features"])
    ]
)
