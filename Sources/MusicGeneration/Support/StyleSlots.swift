//
//  StyleSlots.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//
//  Filling a style's `{slot}` markers: the caller's values checked against
//  the style (a name it does not have is refused; a value it does not know
//  goes in as typed), defaults for the rest, known values turned into their
//  phrases. Pure — the same rules imagine's interior styles follow.
//

import Foundation

public enum StyleSlots {

    /// How values compare: case, hyphens, underscores and repeated spaces ignored.
    public static func key(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
            .split(separator: " ").joined(separator: " ")
    }

    /// The names of every `{marker}` in `text`, in order.
    public static func markers(in text: String) -> [String] {
        var names: [String] = []
        var open: String?
        for character in text {
            if character == "{" { open = "" }
            else if character == "}" { if let name = open { names.append(name) }; open = nil }
            else { open?.append(character) }
        }
        return names
    }

    /// A value for every slot — the caller's, or the default — after checking the names.
    public static func resolved(_ values: [String: String], for style: MusicStyle) throws(StyleError) -> [String: String] {
        var result: [String: String] = [:]
        for (name, value) in values {
            let wanted = name.trimmingCharacters(in: .whitespaces).lowercased()
            guard style.slots.contains(where: { $0.name == wanted }) else {
                throw .unknownSlot(style: style.name, slot: wanted, slots: style.slots.map(\.name))
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw .emptyValue(slot: wanted) }
            result[wanted] = trimmed
        }
        for slot in style.slots where result[slot.name] == nil { result[slot.name] = slot.defaultValue }
        return result
    }

    /// The known value a typed one names, or nil.
    public static func known(_ value: String, in slot: StyleSlot) -> StyleSlot.Value? {
        let wanted = key(value)
        return slot.known.first { $0.names.contains { key($0) == wanted } }
    }

    /// The style's caption with every marker replaced.
    public static func caption(of style: MusicStyle, values: [String: String]) -> String {
        var text = style.caption
        for slot in style.slots {
            let value = values[slot.name] ?? slot.defaultValue
            text = text.replacingOccurrences(of: slot.marker, with: known(value, in: slot)?.text ?? value)
        }
        return text
    }
}

/// Why a style could not be used as asked.
public enum StyleError: Error, Sendable, Equatable, LocalizedError {
    case unknownStyle(String, suggestions: [String])
    case unknownSlot(style: String, slot: String, slots: [String])
    case emptyValue(slot: String)
    case badDefault(style: String, field: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .unknownStyle(let name, let close):
            "No style called \"\(name)\"" + (close.isEmpty ? "." : " — did you mean \(close.joined(separator: ", "))?")
        case .unknownSlot(let style, let slot, let slots):
            slots.isEmpty ? "\(style) has no slots to fill; \(slot) is not one"
                : "\(style) has no slot \"\(slot)\"; its slots: \(slots.joined(separator: ", "))"
        case .emptyValue(let slot): "\(slot) needs a value"
        case .badDefault(let style, let field, let reason): "style \(style) sets \(field) wrongly: \(reason)"
        }
    }
}
