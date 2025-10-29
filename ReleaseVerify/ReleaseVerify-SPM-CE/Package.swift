// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReleaseVerify-SPM-CE",
    platforms: [
        .iOS(.v15), .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/couchbase/couchbase-lite-swift.git", exact: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ReleaseVerify-SPM-CE",
            dependencies: [
                .product(name: "CouchbaseLiteSwift", package: "couchbase-lite-swift")
            ]),
        .testTarget(
            name: "ReleaseVerify-SPM-CETests",
            dependencies: ["ReleaseVerify-SPM-CE"]),
    ]
)
