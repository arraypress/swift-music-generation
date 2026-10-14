//
//  StyleComposer.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//
//  A request from three layers, lowest first: upstream's defaults, the
//  style's defaults, then the caller's explicit fields. The caption is the
//  caller's words followed by the style's (slots filled).
//

import Foundation

public enum StyleComposer {

    /// The request a style, its slot values, the caller's words and the caller's fields make.
    public static func request(style: MusicStyle?, vars: [String: String], prompt: String,
                               fields: [(String, String)]) throws -> SongRequest {
        var request = SongRequest(caption: prompt)
        if let style {
            let values = try StyleSlots.resolved(vars, for: style)
            for (field, value) in style.defaults.sorted(by: { $0.key < $1.key }) {
                do { request = try RecipeRules.set(field, value.description, in: request) } catch {
                    throw StyleError.badDefault(style: style.name, field: field, reason: error.message)
                }
            }
            let styleWords = StyleSlots.caption(of: style, values: values)
            let typed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            request.caption = typed.isEmpty ? styleWords : typed + ", " + styleWords
        } else if !vars.isEmpty {
            throw StyleError.unknownSlot(style: "the request", slot: vars.keys.sorted()[0], slots: [])
        }
        for (field, value) in fields {
            request = try RecipeRules.set(field, value, in: request)
        }
        return request
    }
}
