// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Voicegen",
    platforms: [.iOS(.v26)],
    products: [.library(name: "Voicegen", targets: ["Voicegen"])],
    dependencies: [
        .package(url: "https://github.com/iliasaz/chatterbox-coreml.git", branch: "main")
    ],
    targets: [
        .target(name: "Voicegen", dependencies: [
            .product(name: "ChatterboxCoreML", package: "chatterbox-coreml")
        ])
    ]
)
