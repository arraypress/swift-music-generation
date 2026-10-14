//
//  YuE2Engine.swift
//  YuE2Music
//
//  Created by David Sherlock on 2026.
//
//  YuE2-3B (Multimodal Art Projection, CC BY-NC 4.0) on MLX: a song from
//  style tags and lyrics, optionally through a planned (or supplied) ABC
//  score, at 48 kHz stereo. Opt-in: the engine refuses to start unless it is
//  handed ``YuE2Licence/version`` — naming the licence is accepting it.
//

import Foundation
import MLX
import MLXRandom
import MusicGeneration
import os

/// YuE2 on the GPU.
///
/// ```swift
/// let engine = try YuE2Engine(modelDirectory: folder, licence: YuE2Licence.version)
/// let songs = try await engine.generate(SongRequest(caption: "uplifting trance", lyrics: words))
/// ```
public actor YuE2Engine {

    /// The folder holding YuE2-3B/ and YuE2-Vae/ (and YuE2-Vae-legacy/ if fetched).
    public nonisolated let modelDirectory: URL

    /// MLX's cache of freed buffers is held to this many bytes once loaded.
    public nonisolated let bufferCacheLimit: Int?

    private var pipeline: YuE2Pipeline?
    private var loadSeconds = 0.0
    private let cancelFlag = OSAllocatedUnfairLock(initialState: false)

    /// The least memory the engine starts on (bfloat16 weights 7.3 GB, peak measured in the README).
    public static let minimumMemory: UInt64 = 24 << 30

    /// - Parameter licence: Must be ``YuE2Licence/version``: naming it is accepting it.
    /// - Throws: ``YuE2Error/licenceNotAccepted(expected:)`` or ``YuE2Error/insufficientMemory(physicalGB:requiredGB:)``.
    public init(modelDirectory: URL, licence: String,
                physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
                bufferCacheLimit: Int? = 512 << 20) throws(YuE2Error) {
        guard licence == YuE2Licence.version else { throw .licenceNotAccepted(expected: YuE2Licence.version) }
        guard physicalMemory >= Self.minimumMemory else {
            throw .insufficientMemory(physicalGB: Int(physicalMemory >> 30), requiredGB: Int(Self.minimumMemory >> 30))
        }
        self.modelDirectory = modelDirectory
        self.bufferCacheLimit = bufferCacheLimit
    }

    public var isReady: Bool { pipeline != nil }

    /// Loads the transformer (7.3 GB) and a decoder.
    public func prepare(decoder: YuE2Decoder = .standard) async throws(YuE2Error) {
        if let pipeline { _ = try pipeline.decoder(decoder); return }
        if let bufferCacheLimit { MLX.Memory.cacheLimit = bufferCacheLimit }
        let start = Date()
        pipeline = try YuE2Pipeline(folder: modelDirectory, decoder: decoder)
        loadSeconds = Date().timeIntervalSince(start)
    }

    /// Makes the request's songs (`batchSize` of them, seeds counting up from the first).
    public func generate(_ request: SongRequest,
                         onProgress: (@Sendable (SongProgress) -> Void)? = nil) async throws(YuE2Error) -> [GeneratedSong] {
        let options = request.yue ?? YuE2Options()
        try await prepare(decoder: options.decoder)
        guard let pipeline else { throw .modelMissing("the model did not load") }
        cancelFlag.withLock { $0 = false }
        let flag = cancelFlag
        let cancelled = { flag.withLock { $0 } }
        let first = request.seed ?? UInt32.random(in: 0 ... UInt32.max)
        var songs: [GeneratedSong] = []
        for item in 0 ..< max(1, request.batchSize) {
            var one = request
            one.seed = first &+ UInt32(item)
            var song = try YuE2Generation.run(one, options: options, pipeline: pipeline, item: item,
                                              cancelled: cancelled, progress: onProgress)
            song.timings.load = loadSeconds
            songs.append(song)
        }
        return songs
    }

    /// Only the score (upstream's `--stage plan`): the ABC YuE2 would follow, for editing and
    /// rendering later with ``MusicGeneration/YuE2Options/score``. Needs planning full or melody.
    public func planScore(_ request: SongRequest,
                          onProgress: (@Sendable (SongProgress) -> Void)? = nil) async throws(YuE2Error) -> (score: String, truncated: Bool) {
        let options = request.yue ?? YuE2Options()
        guard options.planning != .off else { throw .invalidRequest("a score needs planning full or melody") }
        try await prepare(decoder: options.decoder)
        guard let pipeline else { throw .modelMissing("the model did not load") }
        cancelFlag.withLock { $0 = false }
        let flag = cancelFlag
        var one = request
        if one.seed == nil { one.seed = UInt32.random(in: 0 ... UInt32.max) }
        return try YuE2Generation.score(one, options: options, pipeline: pipeline, item: 0,
                                        cancelled: { flag.withLock { $0 } }, progress: onProgress)
    }

    /// Stops the generation in progress at the next token or step.
    public nonisolated func cancel() { cancelFlag.withLock { $0 = true } }

    /// Peak GPU memory since the last reset, in bytes.
    public func peakMemory() -> Int { MLX.Memory.peakMemory }

    public func resetPeakMemory() { MLX.Memory.peakMemory = 0 }
}

/// One song through the four stages.
enum YuE2Generation {

    static func run(_ request: SongRequest, options o: YuE2Options, pipeline p: YuE2Pipeline, item: Int,
                    cancelled: () -> Bool, progress: (@Sendable (SongProgress) -> Void)?) throws(YuE2Error) -> GeneratedSong {
        let abc = YuE2Prompt.abcSettings(o)
        let semantic = YuE2Prompt.semanticSettings(o, duration: request.duration)
        try YuE2Prompt.validate(o, [abc, semantic])
        let style = YuE2Prompt.style(request), lyrics = YuE2Prompt.lyrics(request)
        let seed = UInt64(request.seed ?? 0)
        var timings = SongTimings()
        let start = Date()

        // 1. The score.
        var scoreIDs: [Int] = []
        var score: String?
        if o.planning != .off {
            if let given = o.score {
                scoreIDs = p.tokenizer.encode(given)
                score = given
            } else {
                let planned = try plan(style: style, lyrics: lyrics, options: o, settings: abc, seed: seed, pipeline: p, item: item,
                                       cancelled: cancelled, progress: progress)
                scoreIDs = planned.ids
                score = p.tokenizer.decode(planned.ids)
            }
        }
        timings.planning = Date().timeIntervalSince(start)

        // 2. The song tokens.
        let codesStart = Date()
        let prefix = YuE2Protocol.prefix(style: style, lyrics: lyrics, cot: o.planning,
                                         abcIDs: o.planning == .off ? nil : scoreIDs, tokenizer: p.tokenizer)
        let guidance = o.effectiveGuidance
        let negative = guidance != 1 ? YuE2Protocol.negative(cot: o.planning, abcIDs: scoreIDs, tokenizer: p.tokenizer) : nil
        var count = 0
        let tokens = try p.generate(prefix: prefix, negative: negative, guidance: Float(guidance), settings: semantic,
                                    seed: seed, phase: .semantic, legacy: o.planning == .off, cancelled: cancelled) { _ in
            count += 1
            progress?(SongProgress(stage: .codes, fraction: min(1, Double(count) / Double(semantic.maxTokens)), item: item))
        }
        let codec = tokens.ids.map { $0 - YuE2Protocol.codecOffset }
        guard !codec.isEmpty else { throw .generationFailed("the model wrote no song tokens") }
        timings.codes = Date().timeIntervalSince(codesStart)

        // 3. Acoustic latents (one noise draw for the whole song, as upstream).
        let narStart = Date()
        let noise = MLXRandom.normal([codec.count, YuE2Pipeline.latentChannels], key: MLXRandom.key(seed))
        let latents = try p.synthesize(prefix: prefix, codec: codec, noise: noise, steps: o.odeSteps,
                                       cancelled: cancelled) { fraction in
            progress?(SongProgress(stage: .diffusion, fraction: fraction, item: item))
        }
        timings.diffusion = Date().timeIntervalSince(narStart)

        // 4. Audio.
        let decodeStart = Date()
        var channels = try p.decode(latents, decoder: o.decoder, core: o.decoderTileFrames, cancelled: cancelled) { fraction in
            progress?(SongProgress(stage: .decoding, fraction: fraction, item: item))
        }
        channels = SongFinishing.finish(channels, sampleRate: 48_000, normalize: request.normalize, db: request.normalizationDB,
                                        fadeIn: request.fadeIn, fadeOut: request.fadeOut)
        timings.decoding = Date().timeIntervalSince(decodeStart)
        timings.total = Date().timeIntervalSince(start)

        var resolved = request
        resolved.engine = .yue2
        resolved.yue = o
        return GeneratedSong(audio: SongAudio(channels: channels, sampleRate: 48_000), resolved: resolved,
                             plan: score.map { SongPlan(score: $0) }, audioCodes: codec, timings: timings,
                             truncated: tokens.truncated)
    }

    /// The score alone.
    static func score(_ request: SongRequest, options o: YuE2Options, pipeline p: YuE2Pipeline, item: Int,
                      cancelled: () -> Bool, progress: (@Sendable (SongProgress) -> Void)?) throws(YuE2Error) -> (score: String, truncated: Bool) {
        let abc = YuE2Prompt.abcSettings(o)
        try YuE2Prompt.validate(o, [abc])
        if let given = o.score { return (given, false) }
        let planned = try plan(style: YuE2Prompt.style(request), lyrics: YuE2Prompt.lyrics(request), options: o, settings: abc,
                               seed: UInt64(request.seed ?? 0), pipeline: p, item: item, cancelled: cancelled, progress: progress)
        return (p.tokenizer.decode(planned.ids), planned.truncated)
    }

    static func plan(style: String, lyrics: String, options o: YuE2Options, settings: YuE2SamplingSettings, seed: UInt64,
                     pipeline p: YuE2Pipeline, item: Int, cancelled: () -> Bool,
                     progress: (@Sendable (SongProgress) -> Void)?) throws(YuE2Error) -> YuE2Pipeline.Tokens {
        let prefix = YuE2Protocol.prefix(style: style, lyrics: lyrics, cot: o.planning, abcIDs: nil, tokenizer: p.tokenizer)
        var count = 0
        return try p.generate(prefix: prefix, negative: nil, guidance: 1, settings: settings, seed: seed, phase: .abc,
                              legacy: false, cancelled: cancelled) { _ in
            count += 1
            progress?(SongProgress(stage: .planning, fraction: min(1, Double(count) / Double(settings.maxTokens)), item: item))
        }
    }
}
