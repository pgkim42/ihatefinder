// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "IHateFinder",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "IHateFinder", targets: ["IHateFinder"])
    ],
    targets: [
        .target(
            name: "IHateFinderCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "IHateFinder",
            dependencies: ["IHateFinderCore"],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .testTarget(
            name: "IHateFinderCoreTests",
            dependencies: ["IHateFinderCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "IHateFinderTests",
            dependencies: ["IHateFinder", "IHateFinderCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
