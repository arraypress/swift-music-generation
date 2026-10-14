//
//  SongRecipe.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//
//  A song as data: the engine and the exact model revision, every request
//  value the engine used (the seed included), the style and slot values it
//  was composed from, the output file's format and rate, and what wrote
//  it. The same recipe replays the same song. JSON keys are snake_case,
//  the format is versioned (`"song": 1`) and reading refuses keys it does
//  not know (``RecipeRules``), so a misspelt field fails rather than
//  quietly changing the song.
//

import Foundation

/// A song as data.
public struct SongRecipe: Codable, Sendable, Equatable {

    /// The format version: `"song": 1`.
    public var song: Int
    /// The engine: `ace-step-1.5-turbo`.
    public var engine: String
    /// The weights, pinned.
    public var model: ModelRef
    /// The style it was composed from, if any (informational: `request` already holds its words and settings).
    public var style: StyleRef?
    /// Every value the engine used.
    public var request: SongRequest
    /// How the audio was written.
    public var output: Output
    /// What the planner decided (tempo, key, the rewritten caption); never read back as a setting.
    public var plan: SongPlan?
    /// What wrote it; never read back as a setting.
    public var provenance: Provenance?

    public static let formatVersion = 1

    public init(engine: String, model: ModelRef, style: StyleRef?, request: SongRequest, output: Output,
                plan: SongPlan? = nil, provenance: Provenance?) {
        song = Self.formatVersion
        self.engine = engine
        self.model = model
        self.style = style
        self.request = request
        self.output = output
        self.plan = plan
        self.provenance = provenance
    }

    enum CodingKeys: String, CodingKey, CaseIterable { case song, engine, model, style, request, output, plan, provenance }

    public struct ModelRef: Codable, Sendable, Equatable {
        public var repository: String
        public var revision: String
        public var precision: String?
        /// A LoRA adapter folded into the DiT: its folder (relative to the recipe when inside it).
        public var lora: String?
        public var loraScale: Double?
        /// YuE2: the decoder's repository and revision (`m-a-p/YuE2-Vae@152733a…`).
        public var decoder: String?
        public init(repository: String, revision: String, precision: String? = nil, lora: String? = nil,
                    loraScale: Double? = nil, decoder: String? = nil) {
            self.repository = repository
            self.revision = revision
            self.precision = precision
            self.lora = lora
            self.loraScale = loraScale
            self.decoder = decoder
        }
        enum CodingKeys: String, CodingKey, CaseIterable {
            case repository, revision, precision, lora, decoder
            case loraScale = "lora_scale"
        }
    }

    public struct StyleRef: Codable, Sendable, Equatable {
        public var name: String
        public var vars: [String: String]?
        /// The words typed alongside the style.
        public var prompt: String?
        public init(name: String, vars: [String: String]?, prompt: String?) {
            self.name = name
            self.vars = vars
            self.prompt = prompt
        }
        enum CodingKeys: String, CodingKey, CaseIterable { case name, vars, prompt }
    }

    public struct Output: Codable, Sendable, Equatable {
        public var format: AudioFileFormat
        /// Hz; nil keeps the model's 48,000.
        public var sampleRate: Int?
        public init(format: AudioFileFormat, sampleRate: Int? = nil) {
            self.format = format
            self.sampleRate = sampleRate
        }
        enum CodingKeys: String, CodingKey, CaseIterable {
            case format
            case sampleRate = "sample_rate"
        }
    }

    public struct Provenance: Codable, Sendable, Equatable {
        public var tool: String
        public var created: String
        public init(tool: String, created: String) {
            self.tool = tool
            self.created = created
        }
        enum CodingKeys: String, CodingKey, CaseIterable { case tool, created }
    }
}
