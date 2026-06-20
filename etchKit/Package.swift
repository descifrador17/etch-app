// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "etchKit",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(name: "etchKit", targets: ["etchKit"])
    ],
    targets: [
        .target(
            name: "etchKit",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "etchKitTests",
            dependencies: ["etchKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
