// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrightnessControl",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BrightnessControl", targets: ["BrightnessControl"])
    ],
    dependencies: [
        // External display control often requires DDC/CI
        // We can try to use a package if available, or implement basic IOKit calls.
        // For now, let's keep it simple.
    ],
    targets: [
        .executableTarget(
            name: "BrightnessControl",
            dependencies: [],
            path: "Sources/BrightnessControl",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/BrightnessControl/Info.plist"
                ])
            ]
        )
    ]
)
