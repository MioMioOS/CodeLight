// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodeLightCrypto",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "CodeLightCrypto", targets: ["CodeLightCrypto"]),
    ],
    targets: [
        .target(name: "CodeLightCrypto"),
        .testTarget(name: "CodeLightCryptoTests", dependencies: ["CodeLightCrypto"]),
    ]
)
