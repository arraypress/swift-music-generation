//
//  ACEStepModel.swift
//  ACEStepMusic
//
//  Created by David Sherlock on 2026.
//
//  Where the weights come from: arraypress/song-ace-step-1.5 on Hugging Face,
//  a byte-identical copy of the 23 files this engine reads from
//  ACE-Step/Ace-Step1.5, kept so song survives the upstream repository moving
//  or changing. Every LFS file carries its SHA-256, checked on download — the
//  same hashes as upstream's. MIT, like the code.
//

import Foundation

public enum ACEStepModel {

    public static let repository = "arraypress/song-ace-step-1.5"

    /// Pinned: the repository can change under a tool.
    public static let revision = "7cdff8bafa5893c4b067d396d684993339eee878"

    /// Where the copy came from: the ACE-Step team's own repository and revision.
    public static let upstreamRepository = "ACE-Step/Ace-Step1.5"
    public static let upstreamRevision = "19671f406d603126926c1b7e2adc169acbcade22"

    /// Revisions that hold these exact files: recipes written before the copy
    /// name upstream's, and they replay the same.
    public static let revisions: Set<String> = [revision, upstreamRevision]

    public static let licence = "MIT"

    /// Upstream code the port follows (github.com/ace-step/ACE-Step-1.5).
    public static let referenceCommit = "ca1e85fe9430179831e6bc6be790c332190a3866"

    /// Every file the engine reads, relative to the model folder.
    public static let files: [String] = [
        "acestep-v15-turbo/config.json", "acestep-v15-turbo/model.safetensors", "acestep-v15-turbo/silence_latent.pt",
        "vae/config.json", "vae/diffusion_pytorch_model.safetensors",
        "Qwen3-Embedding-0.6B/config.json", "Qwen3-Embedding-0.6B/model.safetensors",
        "Qwen3-Embedding-0.6B/tokenizer.json", "Qwen3-Embedding-0.6B/tokenizer_config.json",
        "Qwen3-Embedding-0.6B/special_tokens_map.json", "Qwen3-Embedding-0.6B/added_tokens.json",
        "Qwen3-Embedding-0.6B/vocab.json", "Qwen3-Embedding-0.6B/merges.txt", "Qwen3-Embedding-0.6B/chat_template.jinja",
        "acestep-5Hz-lm-1.7B/config.json", "acestep-5Hz-lm-1.7B/model.safetensors",
        "acestep-5Hz-lm-1.7B/tokenizer.json", "acestep-5Hz-lm-1.7B/tokenizer_config.json",
        "acestep-5Hz-lm-1.7B/special_tokens_map.json", "acestep-5Hz-lm-1.7B/added_tokens.json",
        "acestep-5Hz-lm-1.7B/vocab.json", "acestep-5Hz-lm-1.7B/merges.txt", "acestep-5Hz-lm-1.7B/chat_template.jinja",
    ]

    /// SHA-256 of the large files, from the Hub's LFS listing at ``revision``.
    public static let sha256: [String: String] = [
        "acestep-v15-turbo/model.safetensors": "3f6e0797fad420a39bd33979eb6e840e30989e34a3794e843d23b60ec6e422d7",
        "acestep-v15-turbo/silence_latent.pt": "a778e9dd942f5e8b2c09c55370782d318834432b03dabbcdf70e6ed49ad6358b",
        "vae/diffusion_pytorch_model.safetensors": "da17edb604c40deaf09e9b24974e590d1ca83a374070e5d0884cfa4bed9a99b0",
        "Qwen3-Embedding-0.6B/model.safetensors": "0437e45c94563b09e13cb7a64478fc406947a93cb34a7e05870fc8dcd48e23fd",
        "Qwen3-Embedding-0.6B/tokenizer.json": "def76fb086971c7867b829c23a26261e38d9d74e02139253b38aeb9df8b4b50a",
        "acestep-5Hz-lm-1.7B/model.safetensors": "f161689da73e5ecefa28ff780d51c2d92a00f056d021d7933c779ed5c6cd7db8",
        "acestep-5Hz-lm-1.7B/tokenizer.json": "35af56c3f5cb3ea2cc578aa28a8937770981d504f183ac5c8c38baf4bbd4af4d",
        "acestep-5Hz-lm-1.7B/tokenizer_config.json": "6cd70cdd89425971794f5235562edcc608b0629a6c4686ae51a8b8c8b8ba5e95",
    ]

    /// Download size.
    public static let gigabytes = 10.1
}
