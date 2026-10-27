// swift-tools-version: 6.0

import PackageDescription

// Deliberately its own package, not just another target of the app's
// Package.swift. A second target in the same package still has to be built
// by `swift test` to discover tests, and the app target imports SwiftUI,
// which does not exist on Linux at all - so any test target living beside
// it could never actually run here. Splitting ObscuraCore out as a local
// path dependency means `swift test` run from *this* directory builds only
// Foundation-only code and genuinely executes, on this machine, right now.
let package = Package(
    name: "ObscuraCore",
    products: [
        .library(name: "ObscuraCore", targets: ["ObscuraCore"]),
    ],
    targets: [
        .target(name: "ObscuraCore"),
        .testTarget(name: "ObscuraCoreTests", dependencies: ["ObscuraCore"]),
        // `swift run ObscuraCoreSelfTest` - see that target's doc comment
        // for why it exists alongside the XCTest suite above.
        .executableTarget(name: "ObscuraCoreSelfTest", dependencies: ["ObscuraCore"]),
    ]
)
