//
//  StyleCatalog.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//
//  The built-in styles: decoded once from ``StyleText`` and checked — every
//  marker a declared slot, every slot used, every default a request field
//  with a value it can hold — by a test, so a bad entry fails the build's
//  tests rather than a run.
//

import Foundation
import RecipeKit

public enum StyleCatalog {

    /// What a parse found, and every problem in it.
    public struct Result: Sendable {
        public var styles: [MusicStyle] = []
        public var problems: [String] = []
    }

    /// Every style in `texts` (JSON groups), with every problem: bad JSON, a
    /// name twice or not kebab-case, a marker that is no slot, a slot no
    /// marker uses, a default a slot does not know or a field cannot hold.
    public static func parse(_ texts: [String]) -> Result {
        let decoded = StyleCatalogs.decoded(texts, as: MusicStyle.self, name: \.name)
        var result = Result(styles: decoded.styles, problems: decoded.problems)
        for style in decoded.styles {
            result.problems += StyleCatalogs.slotProblems(style: style.name, markers: Set(StyleSlots.markers(in: style.caption)),
                                                          slots: style.slots)
            var request = SongRequest(caption: "")
            for (field, value) in style.defaults {
                do { request = try RecipeRules.set(field, value.description, in: request) } catch {
                    result.problems.append("\(style.name): default \(field): \(error.message)")
                }
            }
        }
        return result
    }

    static let parsed = parse(StyleText.all)
}

public extension MusicStyle {

    /// Every built-in style.
    static var all: [MusicStyle] { StyleCatalog.parsed.styles }

    /// The style called `name` (case and spacing forgiven).
    static func named(_ name: String) -> MusicStyle? {
        let wanted = name.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "_", with: "-")
        return all.first { $0.name == wanted }
    }

    /// Up to three names sharing a word with `name`.
    static func suggestions(for name: String) -> [String] { StyleCatalogs.suggestions(for: name, among: all.map(\.name)) }

    /// The style called `name`, or the error that names the closest.
    static func require(_ name: String) throws(StyleError) -> MusicStyle {
        guard let style = named(name) else { throw .unknownStyle(name, suggestions: suggestions(for: name)) }
        return style
    }

    /// Whether the style sings by default.
    var isVocal: Bool {
        if case .bool(let b) = defaults["instrumental"] { return !b }
        return true
    }
}
