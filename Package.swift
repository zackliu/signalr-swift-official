// swift-tools-version: 5.4
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
