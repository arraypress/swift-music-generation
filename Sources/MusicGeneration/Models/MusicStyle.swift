//
//  MusicStyle.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//
//  A named sound: the caption words that make it, the settings it starts
//  from (bpm, key, length, guidance — any request field), and slots a
//  caller fills — `{lead}` in "uplifting trance with a {lead}" — each with
//  a default and the values it was written for. Styles are JSON
//  (``StyleCatalog``), compiled into the library: a resource bundle beside
//  a Homebrew binary breaks when the binary is reached through a symlink.
//  Genre lives here, in data, never in flags.
//

import Foundation

/// A named sound and its starting settings.
public struct MusicStyle: Codable, Sendable, Equatable, Identifiable {

    /// Lower-case kebab-case, as typed: `uplifting-trance`.
    public let name: String
    /// For people: "Uplifting trance".
    public let title: String
    /// Where it is listed.
    public let category: MusicCategory
    /// The caption words, with `{slot}` markers.
    public let caption: String
    /// Gaps in the caption a caller may fill; may be empty.
    public let slots: [StyleSlot]
    /// Request fields the style sets, by their JSON keys: `"bpm": 138`,
    /// `"instrumental": true`, `"duration": 120`. Explicit flags win.
    public let defaults: [String: StyleValue]
    /// For vocal styles: the shape of lyrics that suits it, as a hint.
    public let lyricsHint: String?

    public var id: String { name }

    public init(name: String, title: String, category: MusicCategory, caption: String, slots: [StyleSlot] = [],
                defaults: [String: StyleValue] = [:], lyricsHint: String? = nil) {
        self.name = name
        self.title = title
        self.category = category
        self.caption = caption
        self.slots = slots
        self.defaults = defaults
        self.lyricsHint = lyricsHint
    }

    enum CodingKeys: String, CodingKey {
        case name, title, category, caption, slots, defaults
        case lyricsHint = "lyrics_hint"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        title = try c.decode(String.self, forKey: .title)
        category = try c.decode(MusicCategory.self, forKey: .category)
        caption = try c.decode(String.self, forKey: .caption)
        slots = try c.decodeIfPresent([StyleSlot].self, forKey: .slots) ?? []
        defaults = try c.decodeIfPresent([String: StyleValue].self, forKey: .defaults) ?? [:]
        lyricsHint = try c.decodeIfPresent(String.self, forKey: .lyricsHint)
    }
}

/// A gap in a style's caption, written `{name}`, and what may fill it.
public struct StyleSlot: Codable, Sendable, Equatable {
    /// Lower-case, as written and typed: `lead`.
    public let name: String
    /// The value used when none is given: one of ``known``'s names.
    public let defaultValue: String
    /// The values it was written for; any other goes into the caption as typed.
    public let known: [Value]

    public init(name: String, defaultValue: String, known: [Value]) {
        self.name = name
        self.defaultValue = defaultValue
        self.known = known
    }

    enum CodingKeys: String, CodingKey {
        case name
        case defaultValue = "default"
        case known
    }

    /// One value a slot knows.
    public struct Value: Codable, Sendable, Equatable {
        /// As typed: `acid`.
        public let name: String
        /// What goes into the caption when it says more than the name: "squelching acid line".
        public let phrase: String?
        /// Other names for it.
        public let aliases: [String]?

        public init(name: String, phrase: String? = nil, aliases: [String]? = nil) {
            self.name = name
            self.phrase = phrase
            self.aliases = aliases
        }

        public var names: [String] { [name] + (aliases ?? []) }
        public var text: String { phrase ?? name }
    }

    /// The marker the caption uses: `{lead}`.
    public var marker: String { "{\(name)}" }
}

/// A default value as JSON writes it: a string, a number or a boolean.
public enum StyleValue: Codable, Sendable, Equatable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case bool(Bool)

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else { self = .string(try c.decode(String.self)) }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        }
    }

    /// As a command line would type it: `138`, `0.5`, `true`, `F# minor`.
    public var description: String {
        switch self {
        case .string(let s): s
        case .number(let n): n.rounded() == n && abs(n) < 1e15 ? String(Int(n)) : String(n)
        case .bool(let b): String(b)
        }
    }
}

/// Where a style is listed.
public enum MusicCategory: String, Codable, Sendable, CaseIterable {
    case electronic, dance, pop, hiphop = "hip-hop", rnb = "r-and-b", rock, metal, jazz, blues
    case folk, country, classical, cinematic, ambient, world, latin
}
