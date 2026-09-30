// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GuitarCore",
    platforms: [
        .visionOS(.v2),
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "MusicTheory", targets: ["MusicTheory"]),
        .library(name: "FretboardKit", targets: ["FretboardKit"]),
        .library(name: "AudioAnalysis", targets: ["AudioAnalysis"]),
    ],
    targets: [
        .target(name: "MusicTheory"),
        .target(name: "FretboardKit", dependencies: ["MusicTheory"]),
        .target(name: "AudioAnalysis", dependencies: ["MusicTheory"]),
        .testTarget(name: "MusicTheoryTests", dependencies: ["MusicTheory"]),
        .testTarget(name: "FretboardKitTests", dependencies: ["FretboardKit"]),
        .testTarget(name: "AudioAnalysisTests", dependencies: ["AudioAnalysis"]),
    ]
)
