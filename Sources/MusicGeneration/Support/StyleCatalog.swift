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

public enum StyleCatalog {

    /// What a parse found, and every problem in it.
    public struct Result: Sendable {
        public var styles: [MusicStyle] = []
        public var problems: [String] = []
    }

    public static func parse(_ texts: [String]) -> Result {
        var result = Result()
        var seen = Set<String>()
        for text in texts {
            let styles: [MusicStyle]
            do { styles = try JSONDecoder().decode([MusicStyle].self, from: Data(text.utf8)) } catch {
                result.problems.append("a style group is not valid JSON: \(error)")
                continue
            }
            for style in styles {
                if !seen.insert(style.name).inserted { result.problems.append("\(style.name): listed twice") }
                if style.name.range(of: "^[a-z][a-z0-9-]*$", options: .regularExpression) == nil {
                    result.problems.append("\(style.name): not a kebab-case name")
                }
                let markers = Set(StyleSlots.markers(in: style.caption))
                let slots = Set(style.slots.map(\.name))
                for marker in markers.subtracting(slots) { result.problems.append("\(style.name): {\(marker)} is not a slot") }
                for slot in slots.subtracting(markers) { result.problems.append("\(style.name): slot \(slot) is unused") }
                for slot in style.slots where StyleSlots.known(slot.defaultValue, in: slot) == nil {
                    result.problems.append("\(style.name): slot \(slot.name)'s default is not one of its values")
                }
                var request = SongRequest(caption: "")
                for (field, value) in style.defaults {
                    do { request = try RecipeRules.set(field, value.description, in: request) } catch {
                        result.problems.append("\(style.name): default \(field): \(error.message)")
                    }
                }
                result.styles.append(style)
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
    static func suggestions(for name: String) -> [String] {
        let words = name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 2 }
        return Array(all.map(\.name).filter { style in words.contains { style.contains($0) } }.prefix(3))
    }

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
