//
//  ParityTests.swift
//  ACEStepMusicTests
//
//  Created by David Sherlock on 2026.
//
//  Module-by-module parity against tensors dumped from upstream's Python
//  pipeline (scripts/ref_dump.py in the session scratchpad). Opt-in:
//
//      ACESTEP_MODEL=<model folder> ACESTEP_PARITY=<dump folder> swift test --filter Parity
//

import Foundation
import MLX
import MusicGeneration
import XCTest
@testable import ACEStepMusic

struct Parity {
    static let model = ProcessInfo.processInfo.environment["ACESTEP_MODEL"]
    static let dump = ProcessInfo.processInfo.environment["ACESTEP_PARITY"]
    static var enabled: Bool { model != nil && dump != nil }
}

/// Cosine similarity and max abs difference of two tensors.
func compare(_ a: MLXArray, _ b: MLXArray) -> (cosine: Float, maxAbs: Float, relRMS: Float) {
    let x = a.asType(.float32).reshaped(-1), y = b.asType(.float32).reshaped(-1)
    let dot = (x * y).sum().item(Float.self)
    let cos = dot / (MLX.sqrt((x * x).sum()).item(Float.self) * MLX.sqrt((y * y).sum()).item(Float.self))
    let diff = x - y
    let rel = MLX.sqrt((diff * diff).mean()).item(Float.self) / MLX.sqrt((y * y).mean()).item(Float.self)
    return (cos, MLX.abs(diff).max().item(Float.self), rel)
}

func report(_ name: String, _ r: (cosine: Float, maxAbs: Float, relRMS: Float)) {
    print(String(format: "PARITY %-28@ cos %.7f  maxAbs %.3e  relRMS %.3e", name as NSString, r.cosine, r.maxAbs, r.relRMS))
}

final class ParityTests: XCTestCase {

    override func setUp() async throws {
        try XCTSkipUnless(Parity.enabled, "set ACESTEP_MODEL and ACESTEP_PARITY")
    }

    static func load() async throws -> (ACEStepPipeline, [String: MLXArray], [String: Any]) {
        let pipeline = try await ACEStepPipeline(folder: URL(fileURLWithPath: Parity.model!), dtype: .float32, progress: nil)
        let folder = URL(fileURLWithPath: Parity.dump!)
        let arrays = try loadArrays(url: folder.appendingPathComponent("ref.safetensors"))
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("ref.json"))) as! [String: Any]
        return (pipeline, arrays, json)
    }

    func testModules() async throws {
        let (p, ref, json) = try await Self.load()
        func ids(_ key: String) -> [Int] { ref[key]!.reshaped(-1).asArray(Int32.self).map(Int.init) }

        // Planner prompts and tokenization.
        let cotPrompt = json["lm_cot_prompt"] as! String
        let swiftCot = PlannerText.reasoningPrompt(caption: (json["lm_cot_cfg"] as! [String: Any])["caption"] as! String,
                                                   lyrics: (json["lm_cot_cfg"] as! [String: Any])["lyrics"] as! String)
        print("PARITY cot prompt text equal:", swiftCot == cotPrompt)
        print("PARITY cot prompt ids equal:", p.planner.encode(cotPrompt) == ids("lm_cot_prompt_ids"))
        let codesPrompt = json["lm_codes_prompt"] as! String
        print("PARITY codes prompt ids equal:", p.planner.encode(codesPrompt) == ids("lm_codes_prompt_ids"))
        // Reasoning block as YAML.
        let cotOutput = json["lm_cot_output"] as! String
        let (meta, _) = PlannerText.parse(cotOutput)
        let block = PlannerText.reasoningBlock(meta)
        let pyBlock = (json["lm_codes_cfg"] as! [String: Any])["cot_text"] as! String
        print("PARITY reasoning block equal:", block == pyBlock)
        if block != pyBlock { print("SWIFT:\n\(block)\nPYTHON:\n\(pyBlock)") }

        // Text encoder.
        let textIDs = ids("text_input_ids")
        let lyricIDs = ids("lyric_input_ids")
        let caption = meta.caption ?? ""
        let metas = ACEStepPipeline.metas(bpm: meta.bpm, timeSignature: meta.timesignature, key: meta.keyscale,
                                          duration: meta.duration.map(Double.init))
        let swiftText = p.textEncoder.tokens(ACEStepPipeline.textPrompt(instruction: TaskInstruction.cover,
                                                                        caption: caption, metas: metas), maxLength: 256)
        print("PARITY text ids equal:", swiftText == textIDs, swiftText.count, textIDs.count)
        let params = json["params"] as! [String: Any]
        let language = params["vocal_language"] as? String ?? "unknown"
        let lyricsText = (json["lm_cot_cfg"] as! [String: Any])["lyrics"] as! String
        let swiftLyric = p.textEncoder.tokens(ACEStepPipeline.lyricPrompt(lyrics: lyricsText, language: language),
                                              maxLength: 2048)
        print("PARITY lyric ids equal:", swiftLyric == lyricIDs, swiftLyric.count, lyricIDs.count)
        report("text encoder", compare(p.textEncoder.encode(textIDs), ref["text_hidden_states"]!))
        report("lyric embeddings", compare(p.textEncoder.embed(lyricIDs), ref["lyric_hidden_states"]!))

        // Condition encoder from Python's inputs.
        let (enc, _) = p.network.encoder(text: ref["text_hidden_states"]!, textKeep: ref["prep_text_attention_mask"]!,
                                         lyrics: ref["lyric_hidden_states"]!, lyricKeep: ref["prep_lyric_attention_mask"]!,
                                         references: ref["prep_refer_audio_acoustic_hidden_states_packed"]!, referenceOrder: [0])
        report("condition encoder", compare(enc, ref["enc_hidden_states"]!))
        report("silence reference", compare(p.silence(frames: 750).expandedDimensions(axis: 0),
                                             ref["prep_refer_audio_acoustic_hidden_states_packed"]!))

        // Codes → hints.
        let hints = p.hints(codes: ids("audio_codes"))
        report("detokenized hints", compare(hints, ref["lm_hints_25hz"]!))

        // One DiT forward at t = 1.
        let noise = ref["diff_noise"]!
        let swiftNoise = DiffusionSampler.noise(seeds: [42], frames: noise.dim(1), channels: 64)
        report("seeded noise", compare(swiftNoise, noise))
        let cache = p.network.decoder.crossCache(for: ref["diff_enc"]!)
        let t = MLXArray([Float(1)])
        let v = p.network.decoder(noise, t: t, tr: t, context: ref["diff_ctx"]!, cache: cache)
        report("DiT velocity t=1", compare(v, ref["diff_first_velocity"]!))

        // Whole sampler from Python's inputs.
        let settings = DiffusionSettings(seeds: [42], steps: 8)
        let latents = try DiffusionSampler.run(decoder: p.network.decoder,
                                               conditions: DiffusionConditions(encoder: ref["diff_enc"]!, context: ref["diff_ctx"]!),
                                               nonCover: nil, nullCondition: p.network.nullCondition, frames: noise.dim(1),
                                               settings: settings, repaint: nil, progress: nil, cancelled: { false })
        report("diffusion latents", compare(latents, ref["diff_latents"]!))

        // VAE decode of Python's latents.
        let audio = p.decode(ref["diff_latents"]!, progress: nil)
        let pyAudio = ref["vae_audio_ncl"]![0]
        let swiftAudio = MLX.stacked([MLXArray(audio[0]), MLXArray(audio[1])], axis: 0)
        let r = compare(swiftAudio, pyAudio)
        report("VAE decode", r)
        print(String(format: "PARITY VAE SNR %.1f dB", -20 * log10(r.relRMS)))
    }

    func testPlanner() async throws {
        let (p, ref, json) = try await Self.load()
        let cfg = json["lm_cot_cfg"] as! [String: Any]
        let user = cfg["user_metadata"] as! [String: Any]
        let fixed = MetadataConstraint.Fixed(bpm: (user["bpm"] as? Int).map(String.init), caption: nil,
                                             duration: (user["duration"] as? Int).map(String.init), keyscale: user["keyscale"] as? String,
                                             language: nil, timesignature: user["timesignature"] as? String)
        let state = MLXRandom.RandomState(seed: 42)
        var settings = PlannerSettings()
        settings.temperature = 0.85
        let start = Date()
        let (meta, text, count) = p.planner.reason(caption: cfg["caption"] as! String, lyrics: cfg["lyrics"] as! String,
                                                  fixed: fixed, settings: settings, random: state)
        let pyText = json["lm_cot_output"] as! String
        print(String(format: "PARITY planner phase 1: %d tokens in %.2f s", count, Date().timeIntervalSince(start)))
        print("PARITY cot text equal:", text == pyText)
        if text != pyText {
            let a = Array(text), b = Array(pyText)
            let same = zip(a, b).prefix { $0 == $1 }.count
            print("PARITY cot common prefix chars:", same, "of", b.count)
            print("SWIFT COT:\n\(text)\nPY COT:\n\(pyText)")
        }
        // Phase 2 from Python's own reasoning block, continuing the same random state.
        let block = (json["lm_codes_cfg"] as! [String: Any])["cot_text"] as! String
        let start2 = Date()
        let codes = p.planner.codes(caption: cfg["caption"] as! String, lyrics: cfg["lyrics"] as! String, reasoning: block,
                                    duration: 90, settings: settings, random: state, progress: nil)
        let pyCodes = ref["audio_codes"]!.asArray(Int32.self).map(Int.init)
        let same = zip(codes, pyCodes).filter { $0 == $1 }.count
        let prefix = zip(codes, pyCodes).prefix { $0 == $1 }.count
        print(String(format: "PARITY planner phase 2: %d codes in %.2f s; equal %d/%d, common prefix %d", codes.count,
                     Date().timeIntervalSince(start2), same, pyCodes.count, prefix))
        _ = meta

        // Teacher-forced: Python's tokens fed back, Swift's sample checked at every step.
        let pyCot = ref["lm_cot_output_ids"]!.asArray(Int32.self).map(Int.init)
        let constraint = MetadataConstraint(vocabulary: p.planner.vocabulary, enabled: true, fixed: fixed, skipCaption: false,
                                            skipLanguage: false, stopAtReasoning: true, targetDuration: nil)
        p.planner.teacherLog = []
        let forcedState = MLXRandom.RandomState(seed: 42)
        _ = p.planner.generate(prompt: p.planner.encode(json["lm_cot_prompt"] as! String), unconditional: nil, cfgScale: 1,
                               settings: settings, constraint: constraint, maxTokens: 3500, codes: false,
                               random: forcedState, progress: nil, forced: pyCot)
        let cotAgree = p.planner.teacherLog.filter { $0.0 == $0.1 }.count
        print("PARITY teacher-forced phase 1: \(cotAgree)/\(p.planner.teacherLog.count) sampled tokens equal Python's")
        let pyCodeIDs = ref["lm_codes_output_ids"]!.asArray(Int32.self).map(Int.init)
        let codeConstraint = MetadataConstraint(vocabulary: p.planner.vocabulary, enabled: true, fixed: .init(), skipCaption: true,
                                                skipLanguage: true, stopAtReasoning: false, targetDuration: 90)
        codeConstraint.beginCodes()
        p.planner.teacherLog = []
        _ = p.planner.generate(prompt: p.planner.encode(json["lm_codes_prompt"] as! String),
                               unconditional: p.planner.encode(PlannerText.codesUnconditional(negative: PlannerText.noUserInput)),
                               cfgScale: 2, settings: settings, constraint: codeConstraint, maxTokens: 460, codes: true,
                               random: forcedState, progress: nil, forced: pyCodeIDs)
        let log = p.planner.teacherLog
        print("PARITY teacher-forced phase 2 (same random stream as Python): \(log.filter { $0.0 == $0.1 }.count)/\(log.count)")
    }

    /// Cover, repaint, extension and timbre reference against upstream, with the
    /// sampled VAE encodings and the noise injected (both are random upstream).
    func testTask() async throws {
        let (p, ref, json) = try await Self.load()
        let params = json["params"] as! [String: Any]
        var r = SongRequest(caption: params["caption"] as! String, lyrics: "", instrumental: true)
        r.seed = 42
        r.bpm = params["bpm"] as? Int
        if let key = params["keyscale"] as? String, !key.isEmpty { r.key = key }
        if let ts = params["timesignature"] as? String, let n = Int(ts) { r.timeSignature = n }
        if let d = params["duration"] as? Double, d > 0 { r.duration = d }
        if let d = params["duration"] as? Int, d > 0 { r.duration = Double(d) }
        switch params["task_type"] as! String {
        case "cover": r.task = .cover
        case "repaint": r.task = .repaint
        default: r.task = .text2music
        }
        r.sourceAudio = params["src_audio"] as? String
        r.referenceAudio = params["reference_audio"] as? String
        r.coverStrength = params["audio_cover_strength"] as? Double ?? 1
        r.repaintStart = params["repainting_start"] as? Double ?? 0
        r.repaintEnd = (params["repainting_end"] as? Double).flatMap { $0 < 0 ? nil : $0 }
        r.chunkMaskMode = (params["chunk_mask_mode"] as? String).flatMap(ChunkMaskMode.init(rawValue:))
        r.thinking = params["thinking"] as? Bool ?? true
        r.planMetadata = params["use_cot_metas"] as? Bool ?? true
        r.rewriteCaption = params["use_cot_caption"] as? Bool ?? true
        r.detectLanguage = params["use_cot_language"] as? Bool ?? true
        // upstream's Python generate_music keeps its default (text-to-music) instruction for every task
        r.instruction = params["instruction"] as? String
        var overrides = ParityOverrides(noise: ref["diff_noise"])
        if let target = ref["target_latents"] { overrides.sourceLatents = target.ndim == 2 ? target.expandedDimensions(axis: 0) : target }
        if r.referenceAudio != nil { overrides.referenceLatents = ref["prep_refer_audio_acoustic_hidden_states_packed"] }
        let song = try p.generate(r, overrides: overrides, progress: nil) { false }[0]
        let py = ref["final_audio"]!
        let sw = MLX.stacked([MLXArray(song.audio.channels[0]), MLXArray(song.audio.channels[1])], axis: 0)
        let n = min(py.dim(1), sw.dim(1))
        let d = sw[0..., ..<n] - py[0..., ..<n]
        let snr = 10 * log10((py[0..., ..<n] * py[0..., ..<n]).sum().item(Float.self) / (d * d).sum().item(Float.self))
        print(String(format: "PARITY task %@: SNR %.1f dB, frames %d vs %d", params["task_type"] as! String, snr, sw.dim(1), py.dim(1)))
    }
}
