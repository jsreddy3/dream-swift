// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Infrastructure",
    platforms: [
        .iOS("17.0"),
    ],
    products: [
        .library(name: "Infrastructure", targets: ["Infrastructure"])
    ],
    dependencies: [
        .package(path: "../DomainLogic"),
        .package(path: "../CoreModels"),
        .package(path: "../Configuration"),
        .package(
                    url: "https://github.com/google/GoogleSignIn-iOS.git",
                    from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "Infrastructure",
            dependencies: ["DomainLogic", "CoreModels", "Configuration", .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")]),
//        .testTarget(
//            name: "InfrastructureTests",
//            dependencies: ["Infrastructure", "DomainLogic", "CoreModels"])
    ]
)
