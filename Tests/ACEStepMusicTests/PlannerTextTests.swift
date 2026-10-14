//
//  PlannerTextTests.swift
//  ACEStepMusicTests
//
//  Created by David Sherlock on 2026.
//
//  The pure parts of the port, checked against values upstream's Python
//  produced: PyYAML's line folding, the planner's parse, the schedule,
//  the silence latent reader. No model, no GPU.
//

import Foundation
import MusicGeneration
import XCTest
@testable import ACEStepMusic

final class PlannerTextTests: XCTestCase {

    func testYAMLMatchesPyYAML() throws {
        let url = Bundle.module.url(forResource: "yaml-captions", withExtension: "json", subdirectory: "Fixtures")!
        let cases = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [[String: String]]
        XCTAssertGreaterThan(cases.count, 10)
        for c in cases {
            XCTAssertEqual(YAMLScalar.line(key: c["key"]!, value: c["value"]!), c["yaml"]!, c["value"]!)
        }
    }

    func testReasoningBlockSortsAndTrimsTimeSignature() {
        let block = PlannerText.reasoningBlock(PlannedMetadata(bpm: 125, caption: "warm", duration: 90, keyscale: "A minor",
                                                               language: "unknown", timesignature: "4/4"))
        XCTAssertEqual(block, "<think>\nbpm: 125\ncaption: warm\nduration: 90\nkeyscale: A minor\nlanguage: unknown\ntimesignature: 4\n</think>")
    }

    func testParseReadsFoldedCaptionAndCodes() {
        let text = "<think>\nbpm: 138\ncaption: a long\n  folded caption\nduration: 60\nkeyscale: F minor\nlanguage: en\ntimesignature: 4\n<|im_end|>"
            + "<|audio_code_12|><|audio_code_63999|>"
        let (meta, codes) = PlannerText.parse(text)
        XCTAssertEqual(meta.bpm, 138)
        XCTAssertEqual(meta.caption, "a long folded caption")
        XCTAssertEqual(meta.duration, 60)
        XCTAssertEqual(meta.keyscale, "F minor")
        XCTAssertEqual(meta.language, "en")
        XCTAssertEqual(meta.timesignature, "4")
        XCTAssertEqual(codes, [12, 63_999])
    }

    func testPromptsMatchUpstreamTemplate() {
        let prompt = PlannerText.reasoningPrompt(caption: "c", lyrics: "[Instrumental]")
        XCTAssertEqual(prompt, "<|im_start|>system\n# Instruction\nGenerate audio semantic tokens based on the given conditions:\n\n"
                       + "<|im_end|>\n<|im_start|>user\n# Caption\nc\n\n# Lyric\n[Instrumental]\n<|im_end|>\n<|im_start|>assistant\n")
        XCTAssertTrue(PlannerText.codesUnconditional(negative: "NO USER INPUT").hasSuffix("user\nNO USER INPUT<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"))
    }

    func testScheduleMatchesUpstream() {
        XCTAssertEqual(Schedule.timesteps(shift: 1, custom: nil, steps: 8), [1, 0.875, 0.75, 0.625, 0.5, 0.375, 0.25, 0.125])
        let shifted = Schedule.timesteps(shift: 3, custom: nil, steps: 8)
        XCTAssertEqual(shifted.count, 8)
        XCTAssertEqual(shifted[1], 3 * 0.875 / (1 + 2 * 0.875), accuracy: 1e-12)
        XCTAssertEqual(Schedule.timesteps(shift: 1, custom: [0.97, 0.76, 0.5, 0], steps: 8), [0.9545454545454546, 0.7692307692307693, 0.5])
    }

    func testRepaintConfigMatchesUpstream() {
        XCTAssertTrue(ACEStepPipeline.repaintConfig(mode: .aggressive, strength: 0.5) == (0, 0, 0))
        XCTAssertTrue(ACEStepPipeline.repaintConfig(mode: .conservative, strength: 0.5) == (1, 25, 0.05))
        let balanced = ACEStepPipeline.repaintConfig(mode: .balanced, strength: 0.5)
        XCTAssertEqual(balanced.injection, 0.5)
        XCTAssertEqual(balanced.frames, 12)  // round(12.5) is 12 in Python
        XCTAssertEqual(balanced.wave, 0.025, accuracy: 1e-12)
    }

    func testMetasAndPrompts() {
        XCTAssertEqual(ACEStepPipeline.metas(bpm: 125, timeSignature: "4", key: "A minor", duration: 90),
                       "- bpm: 125\n- timesignature: 4\n- keyscale: A minor\n- duration: 90 seconds\n")
        XCTAssertEqual(ACEStepPipeline.metas(bpm: nil, timeSignature: nil, key: nil, duration: 30.5),
                       "- bpm: N/A\n- timesignature: N/A\n- keyscale: N/A\n- duration: 30 seconds\n")
        XCTAssertEqual(ACEStepPipeline.lyricPrompt(lyrics: "[Instrumental]", language: "unknown"),
                       "# Languages\nunknown\n\n# Lyric\n[Instrumental]<|endoftext|>")
    }

    func testFinishNormalisesAndFades() {
        let wave: [[Float]] = [[0.5, -2, 0.25, 1], [0, 0, 0, 0]]
        let out = ACEStepPipeline.finish(wave, normalize: true, db: -1, fadeIn: 0, fadeOut: 0)
        XCTAssertEqual(out[0].map(abs).max()!, Float(pow(10, -1.0 / 20)), accuracy: 1e-6)
    }

    func testTorchZipReaderFindsStoredEntry() throws {
        // A one-entry stored zip, built by hand: name "x/data/0", 8 bytes.
        let payload = Data([1, 2, 3, 4, 5, 6, 7, 8])
        let name = Data("x/data/0".utf8)
        var zip = Data()
        func u16(_ v: Int) -> Data { Data([UInt8(v & 0xFF), UInt8(v >> 8 & 0xFF)]) }
        func u32(_ v: Int) -> Data { u16(v & 0xFFFF) + u16(v >> 16) }
        let local: [Data] = [u32(0x0403_4B50), u16(20), u16(0), u16(0), u16(0), u16(0), u32(0), u32(8), u32(8),
                             u16(name.count), u16(0), name, payload]
        for part in local { zip.append(part) }
        let central = zip.count
        let entry: [Data] = [u32(0x0201_4B50), u16(20), u16(20), u16(0), u16(0), u16(0), u16(0), u32(0), u32(8), u32(8),
                             u16(name.count), u16(0), u16(0), u16(0), u16(0), u32(0), u32(0), name]
        for part in entry { zip.append(part) }
        let size = zip.count - central
        let end: [Data] = [u32(0x0605_4B50), u16(0), u16(0), u16(1), u16(1), u32(size), u32(central), u16(0)]
        for part in end { zip.append(part) }
        XCTAssertEqual(TorchTensorFile.storedEntry(in: zip, suffix: "/data/0"), payload)
    }
}
