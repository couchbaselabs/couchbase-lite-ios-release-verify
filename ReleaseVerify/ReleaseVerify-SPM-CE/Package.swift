// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReleaseVerify-SPM-CE",
    dependencies: [
        .package(url: "https://github.com/couchbase/couchbase-lite-ios.git", exact: "3.0.2")
    ],
    targets: [
        .executableTarget(
            name: "ReleaseVerify-SPM-CE",
            dependencies: [
                .product(name: "CouchbaseLiteSwift", package: "couchbase-lite-ios")
            ]),
        .testTarget(
            name: "ReleaseVerify-SPM-CETests",
            dependencies: ["ReleaseVerify-SPM-CE"]),
    ]
)
