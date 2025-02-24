// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReleaseVerify-SPM-EE",
    platforms: [
        .iOS(.v12), .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/couchbase/couchbase-lite-swift-ee", from: "3.2.1"),
        .package(url: "https://github.com/couchbase/couchbase-lite-vector-search-spm.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "ReleaseVerify-SPM-EE",
            dependencies: [
                .product(name: "CouchbaseLiteSwift", package: "couchbase-lite-swift-ee"),
                .product(name: "CouchbaseLiteVectorSearch", package: "couchbase-lite-vector-search-spm")
            ]),
        .testTarget(
            name: "ReleaseVerify-SPM-EETests",
            dependencies: ["ReleaseVerify-SPM-EE"]),
    ]
)
