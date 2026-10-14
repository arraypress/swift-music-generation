// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MusicGeneration",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // Core: the request, styles, recipes and audio files. No model, no
        // runtime, no dependencies — anything that describes a song.
        .library(name: "MusicGeneration", targets: ["MusicGeneration"]),
        // ACE-Step 1.5 turbo (MIT) on MLX: the 5 Hz planner LM, the DiT with
        // its lyric and timbre encoders, and the Oobleck VAE.
        .library(name: "ACEStepMusic", targets: ["ACEStepMusic"]),
    ],
    dependencies: [
        // 0.32: the Python reference runs mlx 0.32.3; swift-tts measured layer drift on 0.31.6.
        .package(url: "https://github.com/ml-explore/mlx-swift.git", .upToNextMajor(from: "0.32.3")),
        // Qwen3 for the planner LM and the text encoder.
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", .upToNextMajor(from: "3.32.3")),
        .package(url: "https://github.com/huggingface/swift-transformers.git", .upToNextMajor(from: "1.1.6")),
    ],
    targets: [
        .target(name: "MusicGeneration"),
        .target(
            name: "ACEStepMusic",
            dependencies: [
                "MusicGeneration",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXFast", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "Hub", package: "swift-transformers"),
            ]
        ),
        .testTarget(name: "MusicGenerationTests", dependencies: ["MusicGeneration"]),
        .testTarget(
            name: "ACEStepMusicTests",
            dependencies: [
                "ACEStepMusic", "MusicGeneration",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
