//
//  MusicGenerationTests.swift
//  MusicGenerationTests
//
//  Created by David Sherlock on 2026.
//

import Foundation
import XCTest
@testable import MusicGeneration

final class MusicGenerationTests: XCTestCase {

    func testCatalogHasNoProblems() {
        let result = StyleCatalog.parse(StyleText.all)
        XCTAssertEqual(result.problems, [])
        XCTAssertGreaterThanOrEqual(result.styles.count, 35)
        for name in ["progressive-house", "uplifting-trance", "vocal-trance", "pop", "rap"] {
            XCTAssertNotNil(MusicStyle.named(name), name)
        }
    }

    func testEveryStyleComposes() throws {
        for style in MusicStyle.all {
            let request = try StyleComposer.request(style: style, vars: [:], prompt: "", fields: [])
            XCTAssertFalse(request.caption.contains("{"), style.name)
            XCTAssertNotNil(request.bpm, style.name)
            XCTAssertNil(request.key, "\(style.name): styles leave the key to the planner, so it still writes its plan")
        }
    }

    func testFlagsWinOverStyleAndSlotsFill() throws {
        let style = try MusicStyle.require("uplifting-trance")
        let request = try StyleComposer.request(style: style, vars: ["lead": "acid"], prompt: "a sunrise anthem",
                                                fields: [("bpm", "140")])
        XCTAssertEqual(request.bpm, 140)
        XCTAssertTrue(request.caption.hasPrefix("a sunrise anthem, uplifting trance"))
        XCTAssertTrue(request.caption.contains("squelching acid line"))
        XCTAssertThrowsError(try StyleComposer.request(style: style, vars: ["room": "x"], prompt: "", fields: []))
        let typed = try StyleComposer.request(style: style, vars: ["lead": "a kazoo"], prompt: "", fields: [])
        XCTAssertTrue(typed.caption.contains("a kazoo"))
    }

    func testUnknownStyleSuggests() {
        XCTAssertThrowsError(try MusicStyle.require("trance")) { error in
            XCTAssertTrue((error as? StyleError)?.errorDescription?.contains("uplifting-trance") ?? false)
        }
    }

    func testKeyScaleNormalises() {
        XCTAssertEqual(KeyScale.normalised("Am"), "A minor")
        XCTAssertEqual(KeyScale.normalised("f# min"), "F# minor")
        XCTAssertEqual(KeyScale.normalised("Eb"), "Eb major")
        XCTAssertEqual(KeyScale.normalised("C Major"), "C major")
        XCTAssertNil(KeyScale.normalised("H minor"))
        XCTAssertNil(KeyScale.normalised("C dorian"))
    }

    func testSetCoercesAndRefuses() throws {
        var r = SongRequest(caption: "x")
        r = try RecipeRules.set("seed", "42", in: r)
        XCTAssertEqual(r.seed, 42)
        r = try RecipeRules.set("request.shift", "3", in: r)
        XCTAssertEqual(r.shift, 3)
        r = try RecipeRules.set("timesteps", "0.97,0.5,0", in: r)
        XCTAssertEqual(r.timesteps, [0.97, 0.5, 0])
        r = try RecipeRules.set("instrumental", "yes", in: r)
        XCTAssertTrue(r.instrumental)
        r = try RecipeRules.set("seed", "", in: r)
        XCTAssertNil(r.seed)
        XCTAssertThrowsError(try RecipeRules.set("lightning", "1", in: r))
        XCTAssertThrowsError(try RecipeRules.set("method", "rk4", in: r))
        XCTAssertThrowsError(try RecipeRules.set("seed", "-1", in: r))
        XCTAssertThrowsError(try RecipeRules.set("bpm", "fast", in: r))
    }

    func testRecipeRoundTripsAndRefusesUnknownKeys() throws {
        var request = SongRequest(caption: "synthwave", instrumental: true)
        request.seed = 7
        request.bpm = 100
        let recipe = SongRecipe(engine: "ace-step-1.5-turbo", model: .init(repository: "r", revision: "v"),
                                style: .init(name: "synthwave", vars: ["lead": "sax"], prompt: nil), request: request,
                                output: .init(format: .m4a, sampleRate: 44_100), provenance: .init(tool: "song 0.1.0", created: "now"))
        let data = try RecipeRules.encoded(recipe)
        XCTAssertEqual(try RecipeRules.decoded(data), recipe)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var inner = object["request"] as! [String: Any]
        inner["bmp"] = 99
        object["request"] = inner
        XCTAssertThrowsError(try RecipeRules.decoded(JSONSerialization.data(withJSONObject: object))) { error in
            XCTAssertTrue((error as! RecipeError).message.contains("request.bmp"))
        }
        object["song"] = 2
        XCTAssertThrowsError(try RecipeRules.decoded(JSONSerialization.data(withJSONObject: object)))
        let changed = try RecipeRules.set("output.format", "flac", in: recipe)
        XCTAssertEqual(changed.output.format, .flac)
    }

    func testYuE2RecipeFields() throws {
        var r = SongRequest(caption: "pop")
        r = try RecipeRules.set("engine", "yue2", in: r)
        r = try RecipeRules.set("yue.planning", "off", in: r)
        r = try RecipeRules.set("ode_steps", "16", in: r)               // a bare YuE2 name
        r = try RecipeRules.set("request.yue.semantic_top_p", "0.9", in: r)
        XCTAssertEqual(r.engine, .yue2)
        XCTAssertEqual(r.yue?.planning, .off)
        XCTAssertEqual(r.yue?.odeSteps, 16)
        XCTAssertEqual(r.yue?.semanticTopP, 0.9)
        XCTAssertEqual(r.yue?.effectiveGuidance, 1.01)
        XCTAssertThrowsError(try RecipeRules.set("yue.planning", "sometimes", in: r))
        XCTAssertThrowsError(try RecipeRules.set("yue.ode_step", "3", in: r))
        XCTAssertThrowsError(try RecipeRules.set("engine", "musicgen", in: r))
        let recipe = SongRecipe(engine: "yue2-3b", model: .init(repository: "m-a-p/YuE2-3B", revision: "v", decoder: "m-a-p/YuE2-Vae@w"),
                                style: nil, request: r, output: .init(format: .wav), plan: SongPlan(score: "X:1\nK:C\nC4|"),
                                provenance: nil)
        let data = try RecipeRules.encoded(recipe)
        XCTAssertEqual(try RecipeRules.decoded(data), recipe)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var inner = object["request"] as! [String: Any]
        var yue = inner["yue"] as! [String: Any]
        yue["ode_step"] = 3
        inner["yue"] = yue
        object["request"] = inner
        XCTAssertThrowsError(try RecipeRules.decoded(JSONSerialization.data(withJSONObject: object))) { error in
            XCTAssertTrue((error as! RecipeError).message.contains("request.yue.ode_step"))
        }
    }

    func testRequestDefaultsAreUpstreams() {
        let r = SongRequest(caption: "x")
        XCTAssertEqual(r.steps, 8)
        XCTAssertEqual(r.shift, 1)
        XCTAssertEqual(r.plannerTemperature, 0.85)
        XCTAssertEqual(r.plannerGuidance, 2)
        XCTAssertEqual(r.plannerTopP, 0.9)
        XCTAssertEqual(r.dcwScaler, 0.05)
        XCTAssertEqual(r.dcwHighScaler, 0.02)
        XCTAssertEqual(r.normalizationDB, -1)
        XCTAssertEqual(r.effectiveLyrics, "[Instrumental]")
    }

    func testAudioFilesRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let tone = (0..<48_000).map { Float(sin(Double($0) * 2 * .pi * 440 / 48_000) * 0.5) }
        let audio = SongAudio(channels: [tone, tone], sampleRate: 48_000)
        for format in AudioFileFormat.allCases {
            let url = dir.appendingPathComponent("t-\(format.rawValue).\(format.fileExtension)")
            try AudioFiles.write(audio, to: url, format: format)
            let back = try AudioFiles.read(url)
            XCTAssertEqual(back.channels.count, 2, format.rawValue)
            XCTAssertEqual(back.seconds, 1, accuracy: 0.05, format.rawValue)
        }
        let resampled = AudioFiles.resampled(audio, to: 44_100)
        XCTAssertEqual(resampled.frameCount, 44_100, accuracy: 64)
    }
}
