//
//  YuE2Model.swift
//  YuE2Music
//
//  Created by David Sherlock on 2026.
//
//  Where the weights come from: m-a-p's three YuE2 repositories on Hugging
//  Face, each at a pinned revision, the large files with their SHA-256 (from
//  the Hub's LFS listing and the repositories' own weights_manifest.json).
//  CC BY-NC 4.0 — see ``YuE2Licence``.
//

import Foundation
import MusicGeneration

/// One Hugging Face repository the engine reads.
public struct YuE2Repository: Sendable, Equatable {
    /// `m-a-p/YuE2-3B`.
    public let id: String
    /// The pinned commit.
    public let revision: String
    /// The folder it lives in under the model directory.
    public let folder: String
    /// Every file the engine or the licence needs, relative to `folder`.
    public let files: [String]
    /// SHA-256 of the files that are checked on download.
    public let sha256: [String: String]
    /// Download size in gigabytes.
    public let gigabytes: Double
}

public enum YuE2Model {

    /// The AR–NAR mixture of transformers and its tokenizer.
    public static let transformer = YuE2Repository(
        id: "m-a-p/YuE2-3B", revision: "8f24312f187763b9854adeec87e437e2b03bbff1", folder: "YuE2-3B",
        files: ["config.json", "model.safetensors", "qwen.tiktoken", "LICENSE", "THIRD_PARTY_NOTICES.md"],
        sha256: [
            "model.safetensors": "1d55c42c1a9875c34f5d736e15078449992b044e807ce2a138e6cf289a1e59e9",
            "qwen.tiktoken": "b2b1b8dfb5cc5f024bafc373121c6aba3f66f9a5a0269e243470a1de16a33186",
            "config.json": "ad3477bbef890bf98ae196c1e4b44779494a6231c4ab66f32708eabadf265329",
        ],
        gigabytes: 7.26)

    /// The standard decoder (upstream's default).
    public static let decoder = YuE2Repository(
        id: "m-a-p/YuE2-Vae", revision: "152733a19ad43aa67e367f9b5503ef8075bb5126", folder: "YuE2-Vae",
        files: ["config.json", "model.safetensors", "LICENSE", "THIRD_PARTY_NOTICES.md"],
        sha256: [
            "model.safetensors": "807ce9d5149fa27c5ad3e6582058469852e908f6c5acc8c8aa338e7ab7751346",
            "config.json": "f0191bb9694009956de44e0c361a6f1334760be4c8f848e599bde242a54a0970",
        ],
        gigabytes: 0.53)

    /// The legacy decoder (the one upstream's benchmarks used); fetched only when asked for.
    public static let legacyDecoder = YuE2Repository(
        id: "m-a-p/YuE2-Vae-legacy", revision: "d0585a9cdbb36e8b6930046974500ad7078317ca", folder: "YuE2-Vae-legacy",
        files: ["config.json", "model.safetensors", "LICENSE", "THIRD_PARTY_NOTICES.md"],
        sha256: ["model.safetensors": "b6d283628913bb41145ba99e2314eef613905ee95f690eb70e8212d5f4965044"],
        gigabytes: 0.53)

    /// The repositories a request needs.
    public static func repositories(decoder: YuE2Decoder) -> [YuE2Repository] {
        [transformer, decoder == .legacy ? legacyDecoder : Self.decoder]
    }

    /// Upstream inference code the port follows (yue2_infer, in m-a-p/YuE2-3B at ``YuE2Model/transformer``'s revision).
    public static let referenceVersion = "yue2_infer 0.1.5"
}
