// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ParakeetFinalOnStopPrototype",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            revision: "c7246f4dc78d05f75cdfc5a550cd72ced0c658bf"
        )
    ],
    targets: [
        .executableTarget(
            name: "ParakeetFinalOnStop",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ]
        )
    ]
)
