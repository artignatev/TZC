// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TimeZoneNative",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TimeZoneNative", targets: ["TimeZoneNative"])
    ],
    targets: [
        .executableTarget(
            name: "TimeZoneNative"
        ),
        .testTarget(
            name: "TimeZoneNativeTests",
            dependencies: ["TimeZoneNative"]
        )
    ]
)
