// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XDRPlus",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "XDRPlus", targets: ["XDRPlus"]),
        .executable(name: "GammaProbe", targets: ["GammaProbe"])
    ],
    targets: [
        .executableTarget(
            name: "XDRPlus",
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "GammaProbe")
    ]
)
