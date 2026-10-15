//
//  RecipeRules.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//
//  The pure parts of requests and recipes: changing one field by name, as
//  `--set seed=42` or a style default does; reading recipe JSON strictly
//  (a key it does not know is an error, as imagine's recipes are); and
//  writing it pretty and key-sorted. The engines are RecipeKit's, shared
//  with imagine; what is song's own is the field-kind table and the paths.
//

import Foundation
import RecipeKit

/// Why a recipe or a field could not be read — RecipeKit's, shared with imagine.
public typealias RecipeError = RecipeKit.RecipeError

public enum RecipeRules {

    // MARK: Setting one field

    /// Every request field's JSON key.
    public static var requestFields: [String] { SongRequest.fieldNames }

    /// Every path ``set(_:_:in:)-(_,_,SongRequest)`` reaches, relative to the request:
    /// its fields, then the YuE2 settings as `yue.NAME`. A bare YuE2 name finds
    /// its `yue.` path when no request field has that name.
    static let requestPaths: [String] = requestFields.filter { $0 != "yue" } + YuE2Options.fieldNames.map { "yue." + $0 }

    /// `request` with `field` (a JSON key, or `request.`-prefixed) set from text as typed.
    /// An empty value clears an optional field or restores a required one's default.
    public static func set(_ field: String, _ value: String, in request: SongRequest) throws(RecipeError) -> SongRequest {
        let typed = field.hasPrefix("request.") ? String(field.dropFirst("request.".count)) : field
        guard let path = FieldPaths.resolve(typed, among: requestPaths) else {
            if typed.hasPrefix("yue.") {
                throw RecipeError("\(typed) is not a YuE2 field (\(YuE2Options.fieldNames.map { "yue." + $0 }.joined(separator: ", ")))")
            }
            throw RecipeError("\(field) is not a request field (\(requestFields.joined(separator: ", ")))")
        }
        var request = request
        // A YuE2 field on a request without YuE2 settings starts from their defaults.
        if path.hasPrefix("yue."), request.yue == nil { request.yue = YuE2Options() }
        return try FieldSetter.set(path, to: value, kind: kind(of: path), in: request) { error in
            failure(error, path: path, value: value)
        }
    }

    /// The message for a value the request's own decoding refused.
    static func failure(_ error: any Error, path: String, value: String) -> RecipeError {
        if path.hasPrefix("yue.") {
            let name = String(path.dropFirst("yue.".count))
            let choices = name == "planning" ? YuE2Planning.allCases.map(\.rawValue).joined(separator: ", ")
                : name == "decoder" ? YuE2Decoder.allCases.map(\.rawValue).joined(separator: " or ") : "see `song recipe --help`"
            return RecipeError("\(path) cannot be \(value): \(choices)")
        }
        if case DecodingError.dataCorrupted(let context) = error {
            return RecipeError("\(path) is not a value it can hold\(context.debugDescription.isEmpty ? "" : ": \(context.debugDescription)")")
        }
        return RecipeError("\(path) cannot be \(value): \(kindHint(path))")
    }

    /// What each field holds, by its path from the request; any other is text.
    static func kind(of path: String) -> FieldKind { kinds[path] ?? .text }

    /// The field-kind table `--set` and style defaults are read by.
    static let kinds: [String: FieldKind] = {
        var table: [String: FieldKind] = [:]
        for name in ["instrumental", "adaptive_dual_guidance", "dcw", "thinking", "plan_metadata", "rewrite_caption",
                     "detect_language", "constrained_decoding", "normalize"] { table[name] = .bool }
        for name in ["bpm", "time_signature", "steps", "planner_top_k", "repaint_crossfade_frames", "batch_size"] {
            table[name] = .integer()
        }
        for name in ["seed", "retake_seed"] { table[name] = .integer(0...Int(UInt32.max)) }
        for name in ["duration", "guidance", "guidance_start", "guidance_end", "shift", "velocity_norm_threshold", "velocity_ema",
                     "dcw_scaler", "dcw_high_scaler", "retake_variance", "latent_shift", "latent_rescale", "planner_temperature",
                     "planner_guidance", "planner_top_p", "planner_repetition_penalty", "repaint_start", "repaint_end",
                     "repaint_strength", "repaint_wave_crossfade", "cover_strength", "cover_noise_strength", "normalization_db",
                     "fade_in", "fade_out"] { table[name] = .number }
        table["timesteps"] = .numbers
        table["audio_codes"] = .wholeNumbers
        for name in YuE2Options.fieldNames {
            switch name {
            case "planning", "decoder", "score": table["yue." + name] = .text
            case "abc_top_k", "abc_penalty_window", "abc_min_tokens", "abc_max_tokens", "semantic_top_k",
                 "semantic_penalty_window", "semantic_min_tokens", "semantic_max_tokens", "ode_steps", "decoder_tile_frames":
                table["yue." + name] = .integer()
            default: table["yue." + name] = .number
            }
        }
        return table
    }()

    static func kindHint(_ name: String) -> String {
        switch name {
        case "method": DiffusionMethod.allCases.map(\.rawValue).joined(separator: " or ")
        case "sampler": SamplerKind.allCases.map(\.rawValue).joined(separator: " or ")
        case "dcw_mode": DCWMode.allCases.map(\.rawValue).joined(separator: ", ")
        case "task": SongTask.allCases.map(\.rawValue).joined(separator: ", ")
        case "chunk_mask_mode": ChunkMaskMode.allCases.map(\.rawValue).joined(separator: " or ")
        case "repaint_mode": RepaintMode.allCases.map(\.rawValue).joined(separator: ", ")
        case "engine": SongEngine.allCases.map(\.rawValue).joined(separator: " or ")
        default: "see `song recipe --help`"
        }
    }

    // MARK: Recipe JSON

    /// The keys a recipe file may hold.
    static let format = RecipeFormat(
        versionKey: "song", version: SongRecipe.formatVersion, rootKeys: SongRecipe.CodingKeys.allCases.map(\.rawValue),
        sections: [
            .init("model", keys: SongRecipe.ModelRef.CodingKeys.allCases.map(\.rawValue)),
            .init("style", keys: SongRecipe.StyleRef.CodingKeys.allCases.map(\.rawValue)),
            .init("request", keys: SongRequest.fieldNames),
            .init("request.yue", keys: YuE2Options.fieldNames),
            .init("output", keys: SongRecipe.Output.CodingKeys.allCases.map(\.rawValue)),
            .init("plan", keys: ["bpm", "caption", "duration", "key", "language", "score", "time_signature"]),
            .init("provenance", keys: SongRecipe.Provenance.CodingKeys.allCases.map(\.rawValue)),
        ])

    /// Pretty, key-sorted JSON with slashes left alone.
    public static func encoded(_ recipe: SongRecipe) throws(RecipeError) -> Data { try RecipeJSON.encoded(recipe) }

    /// A recipe from JSON, refusing a newer format and any key it does not know.
    public static func decoded(_ data: Data) throws(RecipeError) -> SongRecipe { try RecipeJSON.decoded(data, format: format) }

    /// `recipe` with one field changed: a request field (`seed`, `request.bpm`),
    /// `output.format`, `output.sample_rate`, or `model.precision`.
    public static func set(_ field: String, _ value: String, in recipe: SongRecipe) throws(RecipeError) -> SongRecipe {
        var recipe = recipe
        let text = value.trimmingCharacters(in: .whitespaces)
        switch field {
        case "output.format", "format":
            guard let format = AudioFileFormat(rawValue: text.lowercased()) else {
                throw RecipeError("output.format is \(AudioFileFormat.allCases.map(\.rawValue).joined(separator: ", ")); not \(value)")
            }
            recipe.output.format = format
        case "output.sample_rate", "sample_rate":
            if text.isEmpty { recipe.output.sampleRate = nil; break }
            guard let rate = Int(text), (8_000...192_000).contains(rate) else {
                throw RecipeError("output.sample_rate is 8000–192000 Hz; not \(value)")
            }
            recipe.output.sampleRate = rate
        case "model.precision", "precision":
            guard ["float32", "bfloat16"].contains(text) else { throw RecipeError("model.precision is float32 or bfloat16") }
            recipe.model.precision = text
        default:
            recipe.request = try set(field, value, in: recipe.request)
        }
        return recipe
    }
}
