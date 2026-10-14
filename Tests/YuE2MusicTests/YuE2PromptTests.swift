//
//  YuE2PromptTests.swift
//  YuE2MusicTests
//
//  Created by David Sherlock on 2026.
//

import Foundation
import MusicGeneration
import XCTest
@testable import YuE2Music

final class YuE2PromptTests: XCTestCase {

    func testStyleNamesTempoAndKeyOnce() {
        var r = SongRequest(caption: "uplifting trance, supersaw chords")
        r.bpm = 138
        r.key = "A minor"
        XCTAssertEqual(YuE2Prompt.style(r), "uplifting trance, supersaw chords, 138 BPM, A minor")
        r.caption = "trance at 138 BPM in A minor"
        XCTAssertEqual(YuE2Prompt.style(r), "trance at 138 BPM in A minor")
    }

    func testLyricTagsCapitalised() {
        XCTAssertEqual(YuE2Prompt.capitaliseTags("[verse]\nla la [not a tag]\n[pre-chorus]\n[final chorus]"),
                       "[Verse]\nla la [not a tag]\n[Pre-Chorus]\n[Final Chorus]")
    }

    func testInstrumentalIsWordlessSections() {
        var r = SongRequest(caption: "ambient")
        r.instrumental = true
        r.lyrics = "ignored words"
        XCTAssertFalse(YuE2Prompt.lyrics(r).contains("ignored"))
        XCTAssertTrue(YuE2Prompt.lyrics(r).hasPrefix("[Intro]"))
        XCTAssertTrue(YuE2Prompt.style(r).hasSuffix("instrumental"))
    }

    func testDurationCapsSongTokens() {
        let s = YuE2Prompt.semanticSettings(YuE2Options(), duration: 6)
        XCTAssertEqual(s.maxTokens, 150)
        XCTAssertEqual(s.minTokens, 150)
        XCTAssertEqual(YuE2Prompt.semanticSettings(YuE2Options(), duration: nil).maxTokens, 9000)
    }

    func testValidation() {
        var o = YuE2Options()
        o.planning = .off
        o.score = "X:1"
        XCTAssertThrowsError(try YuE2Prompt.validate(o, []))
        o = YuE2Options()
        o.semanticTopP = 0
        XCTAssertThrowsError(try YuE2Prompt.validate(o, [YuE2Prompt.semanticSettings(o, duration: nil)]))
    }

    func testDecoderLengthAndNames() {
        XCTAssertEqual(YuE2Pipeline.outputLength(frames: 400), 767_936)     // upstream: 1920·T − 64
        XCTAssertEqual(YuE2Pipeline.decoderName("layers.0.weight_g"), "conv1.weight_g")
        XCTAssertEqual(YuE2Pipeline.decoderName("layers.3.layers.1.bias"), "block.2.conv_t1.bias")
        XCTAssertEqual(YuE2Pipeline.decoderName("layers.6.layers.4.layers.3.weight_v"), "block.5.res_unit3.conv2.weight_v")
        XCTAssertEqual(YuE2Pipeline.decoderName("layers.1.layers.2.layers.0.alpha"), "block.0.res_unit1.snake1.alpha")
        XCTAssertEqual(YuE2Pipeline.decoderName("layers.7.beta"), "snake1.beta")
        XCTAssertNil(YuE2Pipeline.decoderName("layers.9.weight"))
    }

    func testRawTime() {
        XCTAssertEqual(YuE2Pipeline.rawTime(1), 20)
        XCTAssertEqual(YuE2Pipeline.rawTime(0.5), 0, accuracy: 1e-12)
    }

    func testEngineRefusesWithoutLicence() {
        XCTAssertThrowsError(try YuE2Engine(modelDirectory: URL(fileURLWithPath: "/nonexistent"), licence: "yes")) { error in
            XCTAssertEqual(error as? YuE2Error, .licenceNotAccepted(expected: YuE2Licence.version))
        }
        XCTAssertThrowsError(try YuE2Engine(modelDirectory: URL(fileURLWithPath: "/nonexistent"), licence: YuE2Licence.version,
                                            physicalMemory: 16 << 30))
    }
}
