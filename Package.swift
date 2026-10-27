// swift-tools-version: 5.9
import PackageDescription

// The exact same domain sources also compile in the iOS app target.
let package = Package(
    name: "CountdownCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "CountdownCore", targets: ["CountdownCore"])],
    targets: [
        .target(name: "CountdownCore", path: "CountdownApp/Core"),
        .testTarget(name: "CountdownCoreTests", dependencies: ["CountdownCore"], path: "CountdownAppTests")
    ]
)
