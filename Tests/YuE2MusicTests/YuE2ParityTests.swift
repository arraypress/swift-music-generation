//
//  YuE2ParityTests.swift
//  YuE2MusicTests
//
//  Created by David Sherlock on 2026.
//
//  Parity against tensors dumped from upstream's yue2_infer 0.1.5 on PyTorch
//  (MPS), for the two cases in Fixtures/yue_cases.json. Opt-in:
//
//      YUE2_MODEL=<folder with YuE2-3B/, YuE2-Vae/> YUE2_REF=<dump folder> swift test --filter YuE2Parity
//

import Foundation
import MLX
import MLXRandom
import MusicGeneration
import XCTest
@testable import YuE2Music

private enum Env {
    static let model = ProcessInfo.processInfo.environment["YUE2_MODEL"]
    static let ref = ProcessInfo.processInfo.environment["YUE2_REF"]
}

private func compare(_ a: MLXArray, _ b: MLXArray) -> (cosine: Float, maxAbs: Float, snr: Float) {
    let x = a.asType(.float32).reshaped(-1), y = b.asType(.float32).reshaped(-1)
    let finite = MLX.isFinite(y) .&& MLX.isFinite(x)
    let xs = MLX.where(finite, x, 0), ys = MLX.where(finite, y, 0)
    let dot = (xs * ys).sum().item(Float.self)
    let cos = dot / (MLX.sqrt((xs * xs).sum()).item(Float.self) * MLX.sqrt((ys * ys).sum()).item(Float.self))
    let diff = xs - ys
    let snr = 10 * log10((ys * ys).sum().item(Float.self) / max((diff * diff).sum().item(Float.self), 1e-30))
    return (cos, MLX.abs(diff).max().item(Float.self), snr)
}

private func report(_ name: String, _ r: (cosine: Float, maxAbs: Float, snr: Float)) {
    print(String(format: "YUE2 %-30@ cos %.7f  maxAbs %.3e  SNR %6.1f dB", name as NSString, r.cosine, r.maxAbs, r.snr))
}

private struct Case: Decodable {
    let id, style, lyrics, cot: String
    let seed: Int
}

private struct Cases: Decodable {
    let tokenizer: [String]
    let cases: [Case]
}

final class YuE2ParityTests: XCTestCase {

    func testParity() throws {
        try XCTSkipUnless(Env.model != nil && Env.ref != nil, "set YUE2_MODEL and YUE2_REF")
        let fixtures = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!
        let cases = try JSONDecoder().decode(Cases.self, from: Data(contentsOf: fixtures.appendingPathComponent("yue_cases.json")))
        let expectedIDs = try JSONDecoder().decode([String: [Int]].self,
                                                   from: Data(contentsOf: fixtures.appendingPathComponent("tokenizer_ids.json")))
        var start = Date()
        let p = try YuE2Pipeline(folder: URL(fileURLWithPath: Env.model!), decoder: .standard)
        print(String(format: "YUE2 load %.1f s", Date().timeIntervalSince(start)))

        for text in cases.tokenizer { XCTAssertEqual(p.tokenizer.encode(text), expectedIDs[text], text) }

        for c in cases.cases {
            let folder = URL(fileURLWithPath: Env.ref!).appendingPathComponent(c.id)
            let ref = try loadArrays(url: folder.appendingPathComponent("ref.safetensors"))
            func ids(_ key: String) -> [Int] { ref[key]!.reshaped(-1).asArray(Int32.self).map(Int.init) }
            let cot = YuE2Planning(rawValue: c.cot)!
            let abcIDs = ids("abc_ids")

            // Prompts.
            XCTAssertEqual(YuE2Protocol.prefix(style: c.style, lyrics: c.lyrics, cot: cot, abcIDs: nil, tokenizer: p.tokenizer),
                           ids("prefix0"), "\(c.id) prefix")
            let planPrefix = YuE2Protocol.prefix(style: c.style, lyrics: c.lyrics, cot: cot,
                                                 abcIDs: cot == .off ? nil : abcIDs, tokenizer: p.tokenizer)
            XCTAssertEqual(planPrefix, ids("plan_prefix"), "\(c.id) plan prefix")
            XCTAssertEqual(p.tokenizer.encode(p.tokenizer.decode(abcIDs)), abcIDs, "\(c.id) score round trip")

            // AR logits, teacher-forced on Python's own tokens, and the sampling scores from Python's logits.
            var o = YuE2Options()
            o.planning = cot
            func teacher(_ phase: YuE2Phase, prefix: [Int], negative: [Int]?, guidance: Float, tokens: [Int],
                         settings: YuE2SamplingSettings, legacy: Bool) {
                let positive = p.newCaches()
                let negativeCaches = negative.map { _ in p.newCaches() }
                var cond = p.arLogits(prefix, caches: positive, offset: 0)
                var uncond = negative.map { p.arLogits($0, caches: negativeCaches!, offset: 0) }
                var worst: Float = 1, worstScores: Float = 1, edgeTokens = 0
                let name = phase == .abc ? "abc" : "semantic"
                for step in 0 ..< 24 where step < tokens.count {
                    var logits = cond
                    if let u = uncond { logits = u + MLXArray(guidance).asType(.bfloat16) * (cond - u) }
                    if let expected = ref["\(name)_logits_\(step)"] {
                        let r = compare(logits, expected)
                        worst = min(worst, r.cosine)
                        if step == 0 || step == 23 { report("\(c.id) \(name) logits \(step)", r) }
                    }
                    if let expected = ref["\(name)_scores_\(step)"], let pyLogits = ref["\(name)_logits_\(step)"] {
                        let history = Array(tokens[..<step])
                        let raw = YuE2Sampling.scores(legacy ? pyLogits.asType(.bfloat16) : pyLogits,
                                                      mask: YuE2Sampling.phaseMask(phase), settings: settings,
                                                      history: history, step: step,
                                                      end: phase == .abc ? YuE2Protocol.abcEnd : YuE2Protocol.musicEnd,
                                                      legacy: legacy)
                        let mine = YuE2Sampling.filtered(raw, settings: settings, legacy: legacy)
                        let finiteMine = MLX.isFinite(mine).asArray(Bool.self), finiteRef = MLX.isFinite(expected.reshaped(-1)).asArray(Bool.self)
                        // The legacy (no-score) path keeps upstream's bfloat16 softmax and cumsum, so a token
                        // sitting exactly on the top-p edge can fall either side; the float32 path must match exactly.
                        let mineSet = Set(finiteMine.indices.filter { finiteMine[$0] })
                        let refSet = Set(finiteRef.indices.filter { finiteRef[$0] })
                        let differing = mineSet.symmetricDifference(refSet).count
                        edgeTokens += differing
                        XCTAssertLessThanOrEqual(differing, legacy ? 3 : 0, "\(c.id) \(name) kept set \(step)")
                        worstScores = min(worstScores, compare(mine, expected).cosine)
                    }
                    let token = tokens[step]
                    cond = p.arLogits([token], caches: positive, offset: prefix.count + step)
                    if let negative { uncond = p.arLogits([token], caches: negativeCaches!, offset: negative.count + step) }
                }
                print(String(format: "YUE2 %@ %@ worst logits cos %.7f, worst scores cos %.7f, top-p edge tokens %d in 24 steps",
                             c.id, name, worst, worstScores, edgeTokens))
                XCTAssertGreaterThan(worst, 0.999, "\(c.id) \(name) logits")
            }
            if cot != .off {
                teacher(.abc, prefix: ids("prefix0"), negative: nil, guidance: 1, tokens: abcIDs,
                        settings: YuE2Prompt.abcSettings(o), legacy: false)
            }
            let guidance = Float(o.effectiveGuidance)
            let negative = guidance != 1 ? YuE2Protocol.negative(cot: cot, abcIDs: abcIDs, tokenizer: p.tokenizer) : nil
            let semantic = ids("semantic")
            var sem = YuE2Prompt.semanticSettings(o, duration: nil)
            sem.minTokens = 200
            teacher(.semantic, prefix: planPrefix, negative: negative, guidance: guidance,
                    tokens: semantic.map { $0 + YuE2Protocol.codecOffset }, settings: sem, legacy: cot == .off)

            // NAR: the AR tokens, two velocities, then the whole solve from Python's noise.
            let ar = planPrefix + semantic.map { $0 + YuE2Protocol.codecOffset } + [YuE2Protocol.musicEnd]
            XCTAssertEqual(ar, ids("nar_ar_tokens"), "\(c.id) NAR tokens")
            let noise = ref["nar_noise"]!
            let chunk = p.prefillAcoustic(ar, frames: semantic.count)
            let state = noise.asType(.bfloat16)
            report("\(c.id) velocity t=1", compare(p.velocity(state, rawT: 20, chunk: chunk), ref["nar_velocity_t1"]!))
            let rawMid = YuE2Pipeline.rawTime(1 - 0.5 / 32)
            report("\(c.id) velocity mid", compare(p.velocity(state, rawT: rawMid, chunk: chunk), ref["nar_velocity_mid"]!))
            start = Date()
            let latents = try p.synthesize(prefix: planPrefix, codec: semantic, noise: noise, steps: 32,
                                           cancelled: { false }, progress: { _ in })
            let narSeconds = Date().timeIntervalSince(start)
            let lr = compare(latents, ref["latents"]!)
            report("\(c.id) latents (32 steps)", lr)
            XCTAssertGreaterThan(lr.cosine, 0.99, "\(c.id) latents")

            // Decoder on Python's latents, and end to end from ours.
            start = Date()
            let audio = try p.decode(ref["latents"]!, decoder: .standard, core: 1024, cancelled: { false }, progress: { _ in })
            let vaeSeconds = Date().timeIntervalSince(start)
            let expectedAudio = ref["audio"]!
            XCTAssertEqual(audio[0].count, expectedAudio.dim(0), "\(c.id) audio length")
            let mine = MLXArray(audio[0] + audio[1], [2, audio[0].count]).transposed(1, 0)
            let ar2 = compare(mine, expectedAudio)
            report("\(c.id) decoder audio", ar2)
            XCTAssertGreaterThan(ar2.snr, 40, "\(c.id) decoder")
            let tiled = try p.decode(ref["latents"]!, decoder: .standard, core: 128, cancelled: { false }, progress: { _ in })
            report("\(c.id) decoder 128-frame tiles", compare(MLXArray(tiled[0] + tiled[1], [2, tiled[0].count]).transposed(1, 0),
                                                              expectedAudio))
            let e2e = try p.decode(latents, decoder: .standard, core: 1024, cancelled: { false }, progress: { _ in })
            report("\(c.id) audio from Swift latents", compare(MLXArray(e2e[0] + e2e[1], [2, e2e[0].count]).transposed(1, 0),
                                                               expectedAudio))
            print(String(format: "YUE2 %@ NAR %.1f s, decoder %.1f s, peak %.1f GB", c.id, narSeconds, vaeSeconds,
                         Double(MLX.Memory.peakMemory) / 1e9))
        }
    }
}
