//
//  TierTests.swift
//  ACEStepMusicTests
//
//  Created by David Sherlock on 2026.
//
//  What each tier loads, and which Macs each starts on — no model needed.
//

import ACEStepMusic
import Foundation
import MusicGeneration
import XCTest

final class TierTests: XCTestCase {

    let folder = URL(fileURLWithPath: "/nonexistent")
    let gib: UInt64 = 1 << 30

    func testLoadOptions() {
        XCTAssertEqual(ACEStepLoadOptions.tier(.full, precision: .float32),
                       ACEStepLoadOptions(precision: .float32, vaePrecision: .float32, plannerBits: nil))
        XCTAssertEqual(ACEStepLoadOptions.tier(.full, precision: .bfloat16).vaePrecision, .float32)
        // lite ignores the precision asked for: bfloat16 everywhere, an 8-bit planner.
        XCTAssertEqual(ACEStepLoadOptions.tier(.lite, precision: .float32),
                       ACEStepLoadOptions(precision: .bfloat16, vaePrecision: .bfloat16, plannerBits: 8))
    }

    func testMemoryFloorsAndAutomaticTier() throws {
        XCTAssertEqual(ACEStepEngine.minimumMemory(for: .float32), 32 * gib)
        XCTAssertEqual(ACEStepEngine.minimumMemory(for: .bfloat16), 24 * gib)
        XCTAssertEqual(ACEStepEngine.minimumMemory(for: .float32, tier: .lite), 16 * gib)
        XCTAssertEqual(ACEStepEngine.automaticTier(physicalMemory: 36 * gib), .full)
        XCTAssertEqual(ACEStepEngine.automaticTier(physicalMemory: 16 * gib), .lite)
        let lite = try ACEStepEngine(modelDirectory: folder, tier: .lite, physicalMemory: 16 * gib)
        XCTAssertEqual(lite.precision, .bfloat16)
        XCTAssertEqual(lite.loadOptions.plannerBits, 8)
        XCTAssertThrowsError(try ACEStepEngine(modelDirectory: folder, tier: .lite, physicalMemory: 8 * gib)) { error in
            XCTAssertEqual(error as? ACEStepError, .insufficientMemory(physicalGB: 8, requiredGB: 16))
        }
        XCTAssertThrowsError(try ACEStepEngine(modelDirectory: folder, physicalMemory: 16 * gib)) { error in
            XCTAssertTrue((error as? ACEStepError)?.errorDescription?.contains("--tier lite") == true)
        }
    }
}
