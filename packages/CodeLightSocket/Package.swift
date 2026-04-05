// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodeLightSocket",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "CodeLightSocket", targets: ["CodeLightSocket"]),
    ],
    dependencies: [
        .package(url: "https://github.com/socketio/socket.io-client-swift.git", from: "16.1.1"),
        .package(path: "../CodeLightProtocol"),
        .package(path: "../CodeLightCrypto"),
    ],
    targets: [
        .target(
            name: "CodeLightSocket",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift"),
                "CodeLightProtocol",
                "CodeLightCrypto",
            ]
        ),
        .testTarget(name: "CodeLightSocketTests", dependencies: ["CodeLightSocket"]),
    ]
)
