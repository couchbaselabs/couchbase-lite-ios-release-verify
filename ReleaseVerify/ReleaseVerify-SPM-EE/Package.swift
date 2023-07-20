// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReleaseVerify-SPM-EE",
    // platforms specified for Helium as XCode 14.2 defaults to ios 11 and macos 10.13 which is incompatible with product being ios 11 and macos 10.14
    platforms: [
        .iOS(.v11), .macOS(.v10_14)
    ],
    dependencies: [
        .package(url: "https://github.com/couchbase/couchbase-lite-swift-ee", branch: "new-release")
    ],
    targets: [
        .executableTarget(
            name: "ReleaseVerify-SPM-EE",
            dependencies: [
                .product(name: "CouchbaseLiteSwift", package: "couchbase-lite-swift-ee")
            ]),
        .testTarget(
            name: "ReleaseVerify-SPM-EETests",
            dependencies: ["ReleaseVerify-SPM-EE"]),
    ]
)
