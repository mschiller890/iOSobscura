// swift-tools-version: 6.0

import PackageDescription
import Foundation

// The installed Darwin SDK here was built from an Xcode carrying iOS SDK 27.0
// (checked: SDKSettings.json under the xtool darwin.artifactbundle reports
// Version 27.0). Apple decides whether an app gets the current design language
// (Liquid Glass) from the SDK version baked into the binary's LC_BUILD_VERSION
// load command, not from the deployment target and not from the OS the app
// runs on. clang derives that field from `-platform_version`, which SwiftPM
// does not emit on its own from `platforms:` below, so without this flag the
// linker lets ld64 default it to the deployment target's OS version and the
// app ends up looking like an iOS 17 app on a current phone. Passing
// `-Xlinker -sdk-version` alone does not reach LC_BUILD_VERSION either; only
// `-platform_version` does.
let iOSSDKVersion = "27.0"
let iOSDeploymentTarget = "17.0"

let package = Package(
    name: "iOSobscura",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "iOSobscura",
            targets: ["iOSobscura"]
        ),
    ],
    dependencies: [
        // Pure-Foundation model/networking/HTML-parsing code, kept as its
        // own package (Packages/ObscuraCore) specifically so `swift test`
        // run there builds and runs on Linux - see that package's manifest.
        .package(path: "Packages/ObscuraCore"),
    ],
    targets: [
        .target(
            name: "iOSobscura",
            dependencies: [.product(name: "ObscuraCore", package: "ObscuraCore")],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-platform_version",
                    "-Xlinker", "ios",
                    "-Xlinker", iOSDeploymentTarget,
                    "-Xlinker", iOSSDKVersion,
                ])
            ]
        ),
    ]
)
