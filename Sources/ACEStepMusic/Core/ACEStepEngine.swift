//
//  ACEStepEngine.swift
//  ACEStepMusic
//
//  Created by David Sherlock on 2026.
//
//  ACE-Step 1.5 turbo (MIT, ACE Studio & StepFun) on MLX: songs with or
//  without vocals from a caption and lyrics, covers, repaints and
//  extensions, at 48 kHz stereo, entirely on this Mac. The weights load as
//  Hugging Face ships them (ACE-Step/Ace-Step1.5, pinned in
//  ``ACEStepModel``); nothing is converted or re-hosted.
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

    private var pipeline: ACEStepPipeline?
    private var loadSeconds = 0.0
    private let cancelFlag = OSAllocatedUnfairLock(initialState: false)

    /// The least memory the engine starts on at a precision: float32 peaks near
    /// 24 GB (measured), bfloat16 near 18 GB.
    public static func minimumMemory(for precision: ACEStepPrecision) -> UInt64 {
        precision == .float32 ? 32 << 30 : 24 << 30
    }

    public init(modelDirectory: URL, precision: ACEStepPrecision = .float32,
                physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
                bufferCacheLimit: Int? = 512 << 20, lora: LoRASpec? = nil) throws(ACEStepError) {
        let minimum = Self.minimumMemory(for: precision)
        guard physicalMemory >= minimum else {
            throw .insufficientMemory(physicalGB: Int(physicalMemory >> 30), requiredGB: Int(minimum >> 30))
        }
        self.modelDirectory = modelDirectory
        self.precision = precision
        self.bufferCacheLimit = bufferCacheLimit
        self.lora = lora
    }

    public var isReady: Bool { pipeline != nil }

    /// Loads every model (about 10 GB from disk, 17 GB in memory at float32).
    public func prepare(onProgress: (@Sendable (Double) -> Void)? = nil) async throws(ACEStepError) {
        guard pipeline == nil else { return }
        if let bufferCacheLimit { MLX.Memory.cacheLimit = bufferCacheLimit }
        let start = Date()
        let loaded = try await ACEStepPipeline(folder: modelDirectory, dtype: precision.dtype) { onProgress?($0) }
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
