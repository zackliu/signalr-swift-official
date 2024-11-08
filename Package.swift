// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SignalRClient",
    products: [
        .library(name: "SignalRClient", targets: ["SignalRClient"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SignalRClient"
        ),
        .testTarget(name: "SignalRClientTests", dependencies: ["SignalRClient"]),
    ]
)
