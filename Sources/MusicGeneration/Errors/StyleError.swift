//
//  StyleError.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//

import Foundation

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
            SlotError.unknownSlot(style: style, slot: slot, slots: slots).errorDescription
        case .emptyValue(let slot): "\(slot) needs a value"
        case .badDefault(let style, let field, let reason): "style \(style) sets \(field) wrongly: \(reason)"
        }
    }
}
