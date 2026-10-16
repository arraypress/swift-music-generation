//
//  YuE2TierTests.swift
//  YuE2MusicTests
//
//  Created by David Sherlock on 2026.
//

import Foundation
import MusicGeneration
import XCTest
import YuE2Music

final class YuE2TierTests: XCTestCase {

    func testTiersStartOnTheirMacs() throws {
        let gib: UInt64 = 1 << 30
        let folder = URL(fileURLWithPath: "/nonexistent")
        XCTAssertEqual(YuE2Engine.bits(for: .full), nil)
        XCTAssertEqual(YuE2Engine.bits(for: .lite), 4)
        XCTAssertEqual(YuE2Engine.minimumMemory(for: .full), YuE2Engine.minimumMemory)
        let lite = try YuE2Engine(modelDirectory: folder, licence: YuE2Licence.version, tier: .lite, physicalMemory: 16 * gib)
        XCTAssertEqual(lite.quantizationBits, 4)
        XCTAssertThrowsError(try YuE2Engine(modelDirectory: folder, licence: YuE2Licence.version, physicalMemory: 16 * gib))
        XCTAssertThrowsError(try YuE2Engine(modelDirectory: folder, licence: "no", tier: .lite, physicalMemory: 64 * gib))
    }
}
