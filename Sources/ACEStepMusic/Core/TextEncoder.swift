//
//  TextEncoder.swift
//  ACEStepMusic
//
//  Created by David Sherlock on 2026.
//
//  Qwen3-Embedding-0.6B as ACE-Step uses it: the caption prompt runs
//  through the whole model (last hidden state, after the final norm); the
//  lyrics only through its token-embedding table. Run in float32, as
//  upstream runs it on Apple silicon.
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXNN
import Tokenizers

final class TextEncoder {
    let model: Qwen3Model
    let embeddingTable: MLXArray
    let tokenizer: any Tokenizers.Tokenizer

    init(folder: URL, dtype: DType) async throws(ACEStepError) {
        let configuration: Qwen3Configuration
        do {
            configuration = try JSONDecoder().decode(Qwen3Configuration.self,
                                                     from: Data(contentsOf: folder.appendingPathComponent("config.json")))
        } catch { throw .modelMissing("text encoder config.json unreadable: \(error)") }
        let model = Qwen3Model(configuration)
        var table: MLXArray?
        do {
            var weights = try loadArrays(url: folder.appendingPathComponent("model.safetensors"))
            weights = Dictionary(uniqueKeysWithValues: weights.map { ("model." + $0.key, $0.value.asType(dtype)) })
            weights = model.sanitize(weights: weights)
            table = weights["model.embed_tokens.weight"]
            try model.update(parameters: ModuleParameters.unflattened(weights), verify: .all)
        } catch { throw .modelMissing("text encoder weights do not load: \(error)") }
        guard let table else { throw .modelMissing("text encoder has no embed_tokens") }
        MLX.eval(model)
        self.model = model
        embeddingTable = table
        do { tokenizer = try await AutoTokenizer.from(modelFolder: folder) } catch {
            throw .modelMissing("text encoder tokenizer unreadable: \(error)")
        }
    }

    /// Token ids, truncated as upstream truncates (`max_length`).
    func tokens(_ text: String, maxLength: Int) -> [Int] {
        Array(tokenizer.encode(text: text).prefix(maxLength))
    }

    /// `[1, L, 1024]` hidden states for a prompt's tokens.
    func encode(_ ids: [Int]) -> MLXArray {
        model.model(MLXArray(ids.map(Int32.init)).reshaped(1, -1), cache: nil)
    }

    /// `[1, L, 1024]` token embeddings (the lyric path).
    func embed(_ ids: [Int]) -> MLXArray {
        embeddingTable[MLXArray(ids.map(Int32.init))].expandedDimensions(axis: 0)
    }
}
