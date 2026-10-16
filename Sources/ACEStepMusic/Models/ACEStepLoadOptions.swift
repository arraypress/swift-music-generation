//
//  ACEStepLoadOptions.swift
//  ACEStepMusic
//
//  Created by David Sherlock on 2026.
//
//  What each ``ModelTier`` means for ACE-Step. `full` is the parity build
//  (the DiT and text encoder at ``ACEStepPrecision``, the VAE at float32,
//  the planner as shipped). `lite` is for 16 GB Macs: everything in
//  bfloat16 and the planner LM quantised at load. Nothing is downloaded
//  twice; the tier only changes how the same files are read.
//

import Foundation
import MusicGeneration

/// The exact load settings behind a tier; public so probes can measure variants.
public struct ACEStepLoadOptions: Sendable, Equatable {
    /// The DiT's and text encoder's compute type.
    public var precision: ACEStepPrecision
    /// The VAE's compute type.
    public var vaePrecision: ACEStepPrecision
    /// Planner weights quantised to this many bits at load (MLX affine); nil keeps bfloat16.
    public var plannerBits: Int?
    /// The quantisation group size.
    public var plannerGroupSize: Int

    public init(precision: ACEStepPrecision, vaePrecision: ACEStepPrecision, plannerBits: Int?, plannerGroupSize: Int = 64) {
        self.precision = precision
        self.vaePrecision = vaePrecision
        self.plannerBits = plannerBits
        self.plannerGroupSize = plannerGroupSize
    }

    /// The settings a tier means at `precision` (lite ignores `precision`).
    public static func tier(_ tier: ModelTier, precision: ACEStepPrecision) -> ACEStepLoadOptions {
        switch tier {
        case .full: ACEStepLoadOptions(precision: precision, vaePrecision: .float32, plannerBits: nil)
        case .lite: ACEStepLoadOptions(precision: .bfloat16, vaePrecision: .bfloat16, plannerBits: 8)
        }
    }
}
