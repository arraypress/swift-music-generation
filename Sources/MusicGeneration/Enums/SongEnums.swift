//
//  SongEnums.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What the request asks of the model (upstream's `task_type`).
public enum SongTask: String, Codable, Sendable, CaseIterable {
    /// A new song from words.
    case text2music
    /// The source song re-made in the caption's style, keeping its structure.
    case cover
    /// A stretch of the source redrawn (or, past its end, extended).
    case repaint
}

/// `infer_method`.
public enum DiffusionMethod: String, Codable, Sendable, CaseIterable { case ode, sde }

/// `sampler_mode`.
public enum SamplerKind: String, Codable, Sendable, CaseIterable { case euler, heun }

/// `dcw_mode`.
public enum DCWMode: String, Codable, Sendable, CaseIterable { case low, high, double, pix }

/// `chunk_mask_mode`.
public enum ChunkMaskMode: String, Codable, Sendable, CaseIterable { case auto, explicit }

/// `repaint_mode`.
public enum RepaintMode: String, Codable, Sendable, CaseIterable { case conservative, balanced, aggressive }
