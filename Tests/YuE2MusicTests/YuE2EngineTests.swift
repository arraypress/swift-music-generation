//
//  YuE2EngineTests.swift
//  YuE2MusicTests
//
//  Created by David Sherlock on 2026.
//
//  One whole song through the engine, timed. Opt-in:
//
//      YUE2_MODEL=<folder> YUE2_E2E=<output folder> swift test --filter YuE2EngineTests
//

import Foundation
import MLX
import MusicGeneration
import XCTest
@testable import YuE2Music

final class YuE2EngineTests: XCTestCase {

    func testSongEndToEnd() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let model = env["YUE2_MODEL"], let out = env["YUE2_E2E"] else { throw XCTSkip("set YUE2_MODEL and YUE2_E2E") }
        let engine = try YuE2Engine(modelDirectory: URL(fileURLWithPath: model), licence: YuE2Licence.version)
        var start = Date()
        try await engine.prepare()
        print(String(format: "YUE2E2E load %.1f s", Date().timeIntervalSince(start)))
        for planning in [YuE2Planning.off, .full] {
            var r = SongRequest(caption: "hip-hop, 90 BPM, confident male rapper, boom-bap drums")
            r.lyrics = "[verse]\nWoke up early with the city on my mind\nEvery block I walk I leave the doubt behind"
            r.seed = 7
            r.duration = 12
            var o = YuE2Options()
            o.planning = planning
            o.abcMaxTokens = 400
            r.yue = o
            await engine.resetPeakMemory()
            start = Date()
            let song = try await engine.generate(r)[0]
            let t = song.timings
            print(String(format: "YUE2E2E %@ %.1f s audio in %.1f s (score %.1f, tokens %.1f, NAR %.1f, decode %.1f), peak %.1f GB",
                         planning.rawValue, song.audio.seconds, Date().timeIntervalSince(start), t.planning, t.codes,
                         t.diffusion, t.decoding, Double(await engine.peakMemory()) / 1e9))
            try AudioFiles.write(song.audio, to: URL(fileURLWithPath: out).appendingPathComponent("e2e-\(planning.rawValue).wav"),
                                 format: .wav, sampleRate: nil)
        }
    }
}

final class YuE2SpeedTests: XCTestCase {

    /// Where an AR step's time goes: the forward pass alone, and the sampling alone.
    func testStepBreakdown() throws {
        let env = ProcessInfo.processInfo.environment
        guard let model = env["YUE2_MODEL"], env["YUE2_SPEED"] != nil else { throw XCTSkip("set YUE2_MODEL and YUE2_SPEED") }
        let p = try YuE2Pipeline(folder: URL(fileURLWithPath: model), decoder: .standard)
        let caches = p.newCaches()
        var logits = p.arLogits(Array(repeating: 1000, count: 300), caches: caches, offset: 0)
        MLX.eval(logits)
        var start = Date()
        for i in 0 ..< 100 {
            logits = p.arLogits([1000 + i], caches: caches, offset: 300 + i)
            MLX.eval(logits)
        }
        print(String(format: "YUE2SPEED forward %.1f ms/token", Date().timeIntervalSince(start) * 10))
        let settings = YuE2Prompt.semanticSettings(YuE2Options(), duration: nil)
        let mask = YuE2Sampling.phaseMask(.semantic)
        let random = MLXRandom.RandomState(seed: 1)
        let history = Array(160_000 ..< 160_050)
        start = Date()
        for step in 0 ..< 100 {
            let scores = YuE2Sampling.scores(logits, mask: mask, settings: settings, history: history, step: step,
                                             end: YuE2Protocol.musicEnd, legacy: false)
            _ = YuE2Sampling.draw(scores, settings: settings, legacy: false, random: random)
        }
        print(String(format: "YUE2SPEED sampling %.1f ms/token", Date().timeIntervalSince(start) * 10))
    }

    /// The acoustic stage at song length: prefill, one velocity, and its attention and MLP alone.
    func testAcousticBreakdown() throws {
        let env = ProcessInfo.processInfo.environment
        guard let model = env["YUE2_MODEL"], env["YUE2_SPEED"] != nil else { throw XCTSkip("set YUE2_MODEL and YUE2_SPEED") }
        let p = try YuE2Pipeline(folder: URL(fileURLWithPath: model), decoder: .standard)
        if let limit = env["YUE2_CACHE_MB"].flatMap(Int.init) { MLX.Memory.cacheLimit = limit << 20 }
        for (prefixLength, frames) in [(700, 400), (4300, 2250)] {
            let ar = Array(repeating: 1000, count: prefixLength) + Array(repeating: YuE2Protocol.codecOffset + 5, count: frames) + [YuE2Protocol.musicEnd]
            var start = Date()
            let chunk = p.prefillAcoustic(ar, frames: frames)
            let prefill = Date().timeIntervalSince(start)
            let state = MLXRandom.normal([frames, 64]).asType(.bfloat16)
            var v = p.velocity(state, rawT: 1, chunk: chunk); MLX.eval(v)
            start = Date()
            for _ in 0 ..< 3 { v = p.velocity(state, rawT: 1, chunk: chunk); MLX.eval(v) }
            let velocity = Date().timeIntervalSince(start) / 3
            let layer = p.network.backbone.layers[0]
            let x = MLXRandom.normal([1, frames + 2, 2048]).asType(.bfloat16)
            start = Date()
            for _ in 0 ..< 3 {
                let (q, k, vv) = layer.narSelfAttn.project(layer.narInputLayerNorm(x), rope: chunk.rope)
                let keys = MLX.concatenated([chunk.keys[0], k], axis: 2), values = MLX.concatenated([chunk.values[0], vv], axis: 2)
                MLX.eval(layer.narSelfAttn.attend(q, keys, values, mask: .none))
            }
            let attention = Date().timeIntervalSince(start) / 3
            start = Date()
            for _ in 0 ..< 3 { MLX.eval(layer.narMLP(layer.narPreMLPLayerNorm(x))) }
            let mlp = Date().timeIntervalSince(start) / 3
            print(String(format: "YUE2NAR prefix %d frames %d: prefill %.2f s, velocity %.3f s, one layer attention %.1f ms, MLP %.1f ms",
                         prefixLength, frames, prefill, velocity, attention * 1000, mlp * 1000))
        }
    }

    /// The whole acoustic solve at song length, as the engine runs it (YUE2_CACHE_MB sets the buffer cache).
    func testAcousticSolve() throws {
        let env = ProcessInfo.processInfo.environment
        guard let model = env["YUE2_MODEL"], env["YUE2_SPEED"] != nil else { throw XCTSkip("set YUE2_MODEL and YUE2_SPEED") }
        let p = try YuE2Pipeline(folder: URL(fileURLWithPath: model), decoder: .standard)
        if let limit = env["YUE2_CACHE_MB"].flatMap(Int.init) { MLX.Memory.cacheLimit = limit << 20 }
        let steps = env["YUE2_STEPS"].flatMap(Int.init) ?? 4
        let prefix = Array(repeating: 1000, count: 4300), codec = (0 ..< 2250).map { $0 % 32_768 }
        let noise = MLXRandom.normal([2250, 64], key: MLXRandom.key(1))
        MLX.Memory.peakMemory = 0
        let start = Date()
        var marks: [Double] = []
        _ = try p.synthesize(prefix: prefix, codec: codec, noise: noise, steps: steps, cancelled: { false },
                             progress: { _ in marks.append(Date().timeIntervalSince(start)) })
        let gaps = zip(marks.dropFirst(), marks).map { $0 - $1 }
        print("YUE2SOLVE seconds per step:", gaps.map { String(format: "%.1f", $0) }.joined(separator: " "))
        print(String(format: "YUE2SOLVE cache %@ MB, %d steps: %.1f s (%.2f s a velocity), peak %.1f GB", env["YUE2_CACHE_MB"] ?? "default",
                     steps, Date().timeIntervalSince(start), Date().timeIntervalSince(start) / Double(2 * steps),
                     Double(MLX.Memory.peakMemory) / 1e9))
    }
}
