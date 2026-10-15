// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Macut",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Macut", targets: ["Macut"])],
    targets: [
        .target(name: "ClipboardCore"),
        .executableTarget(name: "Macut", dependencies: ["ClipboardCore"]),
        .executableTarget(name: "CoreChecks", dependencies: ["ClipboardCore"], path: "Tests/CoreChecks")
    ]
)
