//
//  StyleSlots.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//
//  Filling a style's `{slot}` markers: the caller's values checked against
//  the style (a name it does not have is refused; a value it does not know
//  goes in as typed), defaults for the rest, known values turned into their
//  phrases. The rules are RecipeKit's ``SlotFilling``, the same imagine's
//  styles follow; this is the music-style face of them.
//

import Foundation
import RecipeKit

public enum StyleSlots {

    /// How values compare: case, hyphens, underscores and repeated spaces ignored.
    public static func key(_ value: String) -> String { SlotFilling.key(value) }

    /// The names of every `{marker}` in `text`, in order.
    public static func markers(in text: String) -> [String] { SlotFilling.markers(in: text) }

    /// A value for every slot — the caller's, or the default — after checking the names.
    public static func resolved(_ values: [String: String], for style: MusicStyle) throws(StyleError) -> [String: String] {
        do { return try SlotFilling.resolved(values, for: style.slots, style: style.name) } catch {
            switch error {
            case .unknownSlot(let style, let slot, let slots): throw .unknownSlot(style: style, slot: slot, slots: slots)
            case .emptyValue(_, let slot, _): throw .emptyValue(slot: slot)
            }
        }
    }

    /// The known value a typed one names, or nil.
    public static func known(_ value: String, in slot: StyleSlot) -> StyleSlot.Value? { SlotFilling.known(value, in: slot) }

    /// The style's caption with every marker replaced.
    public static func caption(of style: MusicStyle, values: [String: String]) -> String {
        SlotFilling.filled(style.caption, slots: style.slots, values: values)
    }
}
