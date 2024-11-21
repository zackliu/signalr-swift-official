// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SignalRClientDevSample",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(path: "../")
    ],
    targets: [
        .executableTarget(
            name: "SignalRClientDevSample",
            dependencies: ["SignalRClient"]
        )
    ]
)
