// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReleaseVerify-SPM-EE",
    dependencies: [
        .package(url: "https://github.com/couchbase/couchbase-lite-swift-ee", exact: "3.0.12")
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
