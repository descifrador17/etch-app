// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RecallKit",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(name: "RecallKit", targets: ["RecallKit"])
    ],
    targets: [
        .target(
            name: "RecallKit",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "RecallKitTests",
            dependencies: ["RecallKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
