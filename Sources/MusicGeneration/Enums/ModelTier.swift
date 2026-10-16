//
//  ModelTier.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//
//  Every engine loads its weights one of two ways: `full` (the parity
//  build) or `lite` (quantised or half-precision so an 8–16 GB Mac can run
//  it). `auto` picks from the Mac's memory and the engine's measured
//  peaks. A recipe stores the tier it ran on, because the two tiers make
//  different audio from the same seed.
//

import Foundation

/// How an engine loads its weights.
public enum ModelTier: String, Sendable, Codable, CaseIterable {
    /// The parity build.
    case full
    /// Quantised or half precision, for Macs with less memory.
    case lite
}

/// What the person asked for: a tier, or `auto`.
public enum TierChoice: String, Sendable, Codable, CaseIterable {
    case auto, full, lite

    /// The tier on a Mac with `physicalMemory` bytes, when the full tier needs `fullNeeds`.
    public func resolved(physicalMemory: UInt64, fullNeeds: UInt64) -> ModelTier {
        switch self {
        case .full: .full
        case .lite: .lite
        case .auto: physicalMemory >= fullNeeds ? .full : .lite
        }
    }
}

/// Why a Mac gets the tier it gets, in words for `song models`.
public enum TierReason {
    public static func text(tier: ModelTier, physicalMemory: UInt64, fullNeeds: UInt64, liteNeeds: UInt64) -> String {
        let have = Int((Double(physicalMemory) / 1_073_741_824).rounded())
        if physicalMemory < liteNeeds {
            return "this Mac has \(have) GB; even the lite tier needs \(liteNeeds >> 30) GB"
        }
        return tier == .full
            ? "this Mac has \(have) GB; full needs \(fullNeeds >> 30) GB"
            : "this Mac has \(have) GB; full needs \(fullNeeds >> 30) GB, lite \(liteNeeds >> 30) GB"
    }
}
