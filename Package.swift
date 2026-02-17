// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrightnessControl",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BrightnessControl", targets: ["BrightnessControl"]),
        .library(name: "BrightnessControlCore", targets: ["BrightnessControlCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BrightnessControlCore",
            dependencies: [],
            path: "Sources/BrightnessControlCore"
        ),
        .executableTarget(
            name: "BrightnessControl",
            dependencies: ["BrightnessControlCore"],
            path: "Sources/BrightnessControl",
            exclude: ["Info.plist", "BrightnessControl.entitlements"],
            resources: [
                .copy("MainAppIcon.icns"),
                .copy("intro.txt")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/BrightnessControl/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "BrightnessControlTests",
            dependencies: ["BrightnessControlCore"],
            path: "Tests/BrightnessControlTests"
        )
    ]
)
