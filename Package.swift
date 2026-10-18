// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Ticker",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Ticker",
            path: "Sources/Ticker"
        )
    ]
)
