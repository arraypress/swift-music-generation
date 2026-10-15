//
//  ModelSourceTests.swift
//  ACEStepMusicTests
//
//  Created by David Sherlock on 2026.
//
//  The weights come from the arraypress copy of ACE-Step/Ace-Step1.5; recipes
//  written before the switch name upstream's revision and must still replay.
//

import XCTest
@testable import ACEStepMusic

final class ModelSourceTests: XCTestCase {

    func testServesTheCopyAndAcceptsUpstream() {
        XCTAssertEqual(ACEStepModel.repository, "arraypress/song-ace-step-1.5")
        XCTAssertEqual(ACEStepModel.upstreamRepository, "ACE-Step/Ace-Step1.5")
        XCTAssertTrue(ACEStepModel.revisions.contains(ACEStepModel.revision))
        XCTAssertTrue(ACEStepModel.revisions.contains("19671f406d603126926c1b7e2adc169acbcade22"))
        XCTAssertEqual(ACEStepModel.revisions.count, 2)
    }

    func testEveryLargeFileIsChecked() {
        for file in ACEStepModel.files where file.hasSuffix(".safetensors") || file.hasSuffix(".pt") {
            XCTAssertNotNil(ACEStepModel.sha256[file], file)
        }
    }
}
