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
        // YuE2-3B (weights CC BY-NC 4.0 + an individual-creator permission; companies need a licence) on MLX: score planning,
        // 25 Hz song tokens and flow-matched latents. Opt-in: the engine
        // refuses to start until its licence version is named.
        .library(name: "YuE2Music", targets: ["YuE2Music"]),
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
        // Networks the engines share (the Oobleck VAE), package-internal.
        .target(
            name: "MusicNetworks",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
            ]
        ),
        .target(
            name: "ACEStepMusic",
            dependencies: [
                "MusicGeneration", "MusicNetworks",
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
        .target(
            name: "YuE2Music",
            dependencies: [
                "MusicGeneration", "MusicNetworks",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXFast", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ]
        ),
        .testTarget(
            name: "YuE2MusicTests",
            dependencies: [
                "YuE2Music", "MusicGeneration",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
            ],
            resources: [.copy("Fixtures")]
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
