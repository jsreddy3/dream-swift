// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Configuration",
    platforms: [.iOS("17.0")],
    products: [.library(name: "Configuration", targets: ["Configuration"])],
    targets: [.target(name: "Configuration")]
)
