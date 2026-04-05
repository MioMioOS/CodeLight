// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodeLightProtocol",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "CodeLightProtocol", targets: ["CodeLightProtocol"]),
    ],
    targets: [
        .target(name: "CodeLightProtocol"),
        .testTarget(name: "CodeLightProtocolTests", dependencies: ["CodeLightProtocol"]),
    ]
)
