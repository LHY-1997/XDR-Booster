// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XDRLift",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "XDRLift", targets: ["XDRLift"]),
        .executable(name: "GammaProbe", targets: ["GammaProbe"])
    ],
    targets: [
        .executableTarget(
            name: "XDRLift",
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "GammaProbe")
    ]
)
