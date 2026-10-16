//
//  ACEStepEngine.swift
//  ACEStepMusic
//
//  Created by David Sherlock on 2026.
//
//  ACE-Step 1.5 turbo (MIT, ACE Studio & StepFun) on MLX: songs with or
//  without vocals from a caption and lyrics, covers, repaints and
//  extensions, at 48 kHz stereo, entirely on this Mac. The weights load as
//  Hugging Face ships them (ACE-Step/Ace-Step1.5, fetched from the identical
//  copy pinned in ``ACEStepModel``); nothing is converted.
//

import Foundation
import MLX
import MusicGeneration
import os

/// ACE-Step 1.5 on the GPU.
///
/// ```swift
/// let engine = ACEStepEngine(modelDirectory: folder)
/// try await engine.prepare()
/// let songs = try await engine.generate(SongRequest(caption: "uplifting trance, 138 BPM", instrumental: true))
/// ```
public actor ACEStepEngine {

    /// The folder holding acestep-v15-turbo/, vae/, Qwen3-Embedding-0.6B/ and acestep-5Hz-lm-1.7B/.
    public nonisolated let modelDirectory: URL

    /// The DiT's and text encoder's compute type: float32 (upstream's, the default) or bfloat16.
    public nonisolated let precision: ACEStepPrecision

    /// MLX's cache of freed buffers is held to this many bytes once loaded.
    public nonisolated let bufferCacheLimit: Int?

    /// A LoRA adapter folded into the DiT at load, if any.
    public nonisolated let lora: LoRASpec?

    /// How the models load: ``ModelTier/full`` (parity) or ``ModelTier/lite`` (16 GB Macs).
    public nonisolated let tier: ModelTier

    /// The exact load settings (from the tier and precision, or given directly).
    public nonisolated let loadOptions: ACEStepLoadOptions

    private var pipeline: ACEStepPipeline?
    private var loadSeconds = 0.0
    private let cancelFlag = OSAllocatedUnfairLock(initialState: false)

    /// The least memory the engine starts on: float32 peaks near 24 GB
    /// (measured), bfloat16 near 18 GB; the lite tier fits a 16 GB Mac.
    public static func minimumMemory(for precision: ACEStepPrecision, tier: ModelTier = .full) -> UInt64 {
        if tier == .lite { return 16 << 30 }
        return precision == .float32 ? 32 << 30 : 24 << 30
    }

    /// The tier `auto` resolves to on a Mac with `physicalMemory` bytes: full
    /// at the requested precision when it fits, else lite.
    public static func automaticTier(precision: ACEStepPrecision = .float32,
                                     physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) -> ModelTier {
        physicalMemory >= minimumMemory(for: precision) ? .full : .lite
    }

    public init(modelDirectory: URL, precision: ACEStepPrecision = .float32, tier: ModelTier = .full,
                physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
                bufferCacheLimit: Int? = 512 << 20, lora: LoRASpec? = nil) throws(ACEStepError) {
        let minimum = Self.minimumMemory(for: precision, tier: tier)
        guard physicalMemory >= minimum else {
            throw .insufficientMemory(physicalGB: Int(physicalMemory >> 30), requiredGB: Int(minimum >> 30))
        }
        self.modelDirectory = modelDirectory
        self.precision = tier == .lite ? .bfloat16 : precision
        self.tier = tier
        self.loadOptions = .tier(tier, precision: precision)
        self.bufferCacheLimit = bufferCacheLimit
        self.lora = lora
    }

    /// An engine with explicit load settings and no memory check: for probes measuring variants.
    public init(modelDirectory: URL, loadOptions: ACEStepLoadOptions, bufferCacheLimit: Int? = 512 << 20) {
        self.modelDirectory = modelDirectory
        self.precision = loadOptions.precision
        self.tier = loadOptions.plannerBits == nil && loadOptions.vaePrecision == .float32 ? .full : .lite
        self.loadOptions = loadOptions
        self.bufferCacheLimit = bufferCacheLimit
        self.lora = nil
    }

    public var isReady: Bool { pipeline != nil }

    /// Loads every model (about 10 GB from disk, 17 GB in memory at float32).
    public func prepare(onProgress: (@Sendable (Double) -> Void)? = nil) async throws(ACEStepError) {
        guard pipeline == nil else { return }
        if let bufferCacheLimit { MLX.Memory.cacheLimit = bufferCacheLimit }
        let start = Date()
        let loaded = try await ACEStepPipeline(folder: modelDirectory, options: loadOptions) { onProgress?($0) }
        if let lora { try LoRAMerge.merge(lora, into: loaded.network.decoder) }
        pipeline = loaded
        loadSeconds = Date().timeIntervalSince(start)
    }

    /// Makes the request's songs (`batchSize` of them).
    public func generate(_ request: SongRequest,
                         onProgress: (@Sendable (SongProgress) -> Void)? = nil) async throws(ACEStepError) -> [GeneratedSong] {
        try await prepare()
        guard let pipeline else { throw .modelMissing("the models did not load") }
        cancelFlag.withLock { $0 = false }
        let flag = cancelFlag
        var songs = try pipeline.generate(request, progress: onProgress) { flag.withLock { $0 } }
        for i in songs.indices { songs[i].timings.load = loadSeconds }
        return songs
    }

    /// Stops the generation in progress at the next diffusion step.
    public nonisolated func cancel() { cancelFlag.withLock { $0 = true } }

    /// Peak GPU memory since the last reset, in bytes.
    public func peakMemory() -> Int { MLX.Memory.peakMemory }

    public func resetPeakMemory() { MLX.Memory.peakMemory = 0 }
}

/// Compute precision for the DiT and the text encoder.
public enum ACEStepPrecision: String, Sendable, Codable, CaseIterable {
    /// float32 — what upstream runs on Apple silicon; the parity reference.
    case float32
    /// bfloat16 — the checkpoint's own type: half the memory.
    case bfloat16

    var dtype: DType { self == .float32 ? .float32 : .bfloat16 }
}
