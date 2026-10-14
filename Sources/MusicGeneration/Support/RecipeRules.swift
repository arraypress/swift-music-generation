//
//  RecipeRules.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//
//  The pure parts of requests and recipes: changing one field by name, as
//  `--set seed=42` or a style default does; reading recipe JSON strictly
//  (a key it does not know is an error, as imagine's recipes are); and
//  writing it pretty and key-sorted.
//

import Foundation

/// Why a recipe or a field could not be read.
public struct RecipeError: Error, Sendable, Equatable, LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public enum RecipeRules {

    // MARK: Setting one field

    /// Every request field's JSON key.
    public static var requestFields: [String] { SongRequest.fieldNames }

    /// `request` with `field` (a JSON key, or `request.`-prefixed) set from text as typed.
    /// An empty value clears an optional field or restores a required one's default.
    public static func set(_ field: String, _ value: String, in request: SongRequest) throws(RecipeError) -> SongRequest {
        var name = field.hasPrefix("request.") ? String(field.dropFirst("request.".count)) : field
        if !name.hasPrefix("yue."), YuE2Options.fieldNames.contains(name), !requestFields.contains(name) { name = "yue." + name }
        if name.hasPrefix("yue.") { return try setYuE(String(name.dropFirst(4)), value, in: request) }
        guard requestFields.contains(name), name != "yue" else {
            throw RecipeError("\(field) is not a request field (\(requestFields.joined(separator: ", ")))")
        }
        var object: [String: Any]
        do {
            object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any] ?? [:]
        } catch { throw RecipeError("cannot read the request: \(error.localizedDescription)") }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            object.removeValue(forKey: name)
        } else {
            object[name] = try typed(text, for: name)
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: object)
            return try JSONDecoder().decode(SongRequest.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            throw RecipeError("\(name) is not a value it can hold\(context.debugDescription.isEmpty ? "" : ": \(context.debugDescription)")")
        } catch {
            throw RecipeError("\(name) cannot be \(value): \(kindHint(name))")
        }
    }

    /// A field of the request's `yue` settings.
    static func setYuE(_ name: String, _ value: String, in request: SongRequest) throws(RecipeError) -> SongRequest {
        guard YuE2Options.fieldNames.contains(name) else {
            throw RecipeError("yue.\(name) is not a YuE2 field (\(YuE2Options.fieldNames.map { "yue." + $0 }.joined(separator: ", ")))")
        }
        var object: [String: Any]
        do {
            object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request.yue ?? YuE2Options())) as? [String: Any] ?? [:]
        } catch { throw RecipeError("cannot read the YuE2 settings: \(error.localizedDescription)") }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { object.removeValue(forKey: name) } else { object[name] = try typedYuE(text, for: name) }
        var r = request
        do {
            r.yue = try JSONDecoder().decode(YuE2Options.self, from: JSONSerialization.data(withJSONObject: object))
        } catch {
            let choices = name == "planning" ? YuE2Planning.allCases.map(\.rawValue).joined(separator: ", ")
                : name == "decoder" ? YuE2Decoder.allCases.map(\.rawValue).joined(separator: " or ") : "see `song recipe --help`"
            throw RecipeError("yue.\(name) cannot be \(value): \(choices)")
        }
        return r
    }

    static func typedYuE(_ text: String, for name: String) throws(RecipeError) -> Any {
        switch name {
        case "planning", "decoder", "score": return text
        case "abc_top_k", "abc_penalty_window", "abc_min_tokens", "abc_max_tokens", "semantic_top_k",
             "semantic_penalty_window", "semantic_min_tokens", "semantic_max_tokens", "ode_steps", "decoder_tile_frames":
            guard let n = Int(text) else { throw RecipeError("yue.\(name) is a whole number; not \(text)") }
            return n
        default:
            guard let n = Double(text), n.isFinite else { throw RecipeError("yue.\(name) is a number; not \(text)") }
            return n
        }
    }

    /// The JSON value for typed text, by the field's kind.
    static func typed(_ text: String, for name: String) throws(RecipeError) -> Any {
        switch kind(of: name) {
        case .bool:
            switch text.lowercased() {
            case "true", "yes", "1", "on": return true
            case "false", "no", "0", "off": return false
            default: throw RecipeError("\(name) is true or false; not \(text)")
            }
        case .integer:
            guard let n = Int(text) ?? Double(text).flatMap({ $0.rounded() == $0 ? Int($0) : nil }) else {
                throw RecipeError("\(name) is a whole number; not \(text)")
            }
            if name == "seed" || name == "retake_seed", !(0...Int(UInt32.max)).contains(n) {
                throw RecipeError("\(name) is a whole number 0–\(UInt32.max); not \(text)")
            }
            return n
        case .number:
            guard let n = Double(text), n.isFinite else { throw RecipeError("\(name) is a number; not \(text)") }
            return n
        case .numbers:
            let items = text.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            let numbers = items.compactMap(Double.init)
            guard numbers.count == items.count, !numbers.isEmpty else {
                throw RecipeError("\(name) is a list of numbers: 0.97,0.76,0.5; not \(text)")
            }
            return name == "audio_codes" ? numbers.map { Int($0) } : numbers
        case .text:
            return text
        }
    }

    enum Kind { case bool, integer, number, numbers, text }

    static func kind(of name: String) -> Kind {
        switch name {
        case "instrumental", "adaptive_dual_guidance", "dcw", "thinking", "plan_metadata", "rewrite_caption",
             "detect_language", "constrained_decoding", "normalize": .bool
        case "bpm", "time_signature", "steps", "seed", "retake_seed", "planner_top_k", "repaint_crossfade_frames",
             "batch_size": .integer
        case "duration", "guidance", "guidance_start", "guidance_end", "shift", "velocity_norm_threshold", "velocity_ema",
             "dcw_scaler", "dcw_high_scaler", "retake_variance", "latent_shift", "latent_rescale", "planner_temperature",
             "planner_guidance", "planner_top_p", "planner_repetition_penalty", "repaint_start", "repaint_end",
             "repaint_strength", "repaint_wave_crossfade", "cover_strength", "cover_noise_strength", "normalization_db",
             "fade_in", "fade_out": .number
        case "timesteps", "audio_codes": .numbers
        default: .text
        }
    }

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

    /// Pretty, key-sorted JSON with slashes left alone.
    public static func encoded(_ recipe: SongRecipe) throws(RecipeError) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do { return try encoder.encode(recipe) } catch { throw RecipeError(error.localizedDescription) }
    }

    /// A recipe from JSON, refusing a newer format and any key it does not know.
    public static func decoded(_ data: Data) throws(RecipeError) -> SongRecipe {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw RecipeError("it is not a JSON object")
        }
        guard let version = root["song"] as? Int else {
            throw RecipeError("it has no \"song\": \(SongRecipe.formatVersion) — the format version")
        }
        guard (1...SongRecipe.formatVersion).contains(version) else {
            throw RecipeError("it is format \(version); this reads format \(SongRecipe.formatVersion)")
        }
        try unknown(root, SongRecipe.CodingKeys.allCases.map(\.rawValue), "")
        let sections: [(String, [String])] = [
            ("model", SongRecipe.ModelRef.CodingKeys.allCases.map(\.rawValue)),
            ("style", SongRecipe.StyleRef.CodingKeys.allCases.map(\.rawValue)),
            ("request", SongRequest.fieldNames),
            ("request.yue", YuE2Options.fieldNames),
            ("output", SongRecipe.Output.CodingKeys.allCases.map(\.rawValue)),
            ("plan", ["bpm", "caption", "duration", "key", "language", "score", "time_signature"]),
            ("provenance", SongRecipe.Provenance.CodingKeys.allCases.map(\.rawValue)),
        ]
        for (name, keys) in sections {
            let value: Any? = name == "request.yue" ? (root["request"] as? [String: Any])?["yue"] : root[name]
            guard let value, !(value is NSNull) else { continue }
            guard let section = value as? [String: Any] else { throw RecipeError("\"\(name)\" is not an object") }
            try unknown(section, keys, name + ".")
        }
        do { return try JSONDecoder().decode(SongRecipe.self, from: data) } catch let DecodingError.typeMismatch(_, context) {
            throw RecipeError("\(path(context.codingPath)) has the wrong type")
        } catch let DecodingError.keyNotFound(key, context) {
            throw RecipeError("\(path(context.codingPath + [key])) is missing")
        } catch let DecodingError.dataCorrupted(context) {
            throw RecipeError("\(path(context.codingPath)) is not a value it can hold")
        } catch {
            throw RecipeError(error.localizedDescription)
        }
    }

    static func unknown(_ object: [String: Any], _ known: [String], _ prefix: String) throws(RecipeError) {
        if let bad = object.keys.sorted().first(where: { !known.contains($0) }) {
            throw RecipeError("\(prefix)\(bad) is not a recipe field (\(known.map { prefix + $0 }.joined(separator: ", ")))")
        }
    }

    static func path(_ keys: [any CodingKey]) -> String {
        keys.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
    }

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
