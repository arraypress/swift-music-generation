//
//  LoRAMerge.swift
//  ACEStepMusic
//
//  Created by David Sherlock on 2026.
//
//  A LoRA slot, load only: a PEFT adapter trained on ACE-Step's DiT
//  (adapter_config.json + adapter_model.safetensors, as upstream's training
//  writes them) is folded into the decoder's linear weights once, at load:
//  W += scale · (alpha / r) · B·A (alpha / √r with rsLoRA). Nothing here
//  trains. LoKr / LyCORIS adapters are refused by name.
//

import Foundation
import MLX
import MLXNN

/// A LoRA adapter to fold into the DiT.
public struct LoRASpec: Sendable, Equatable {
    /// The adapter's folder (or its adapter_model.safetensors).
    public var path: URL
    /// A multiplier on the adapter's own strength; 1 is as trained.
    public var scale: Double

    public init(path: URL, scale: Double = 1) {
        self.path = path
        self.scale = scale
    }
}

enum LoRAMerge {

    struct Config: Decodable {
        var r: Int
        var loraAlpha: Double
        var useRslora: Bool?
        enum CodingKeys: String, CodingKey {
            case r
            case loraAlpha = "lora_alpha"
            case useRslora = "use_rslora"
        }
    }

    /// The module path a PEFT key names: `base_model.model.layers.3.self_attn.q_proj.lora_A.weight` → `layers.3.self_attn.q_proj`.
    static func modulePath(_ key: String) -> String? {
        var path = key
        for suffix in [".lora_A.weight", ".lora_B.weight", ".lora_A.default.weight", ".lora_B.default.weight"] where path.hasSuffix(suffix) {
            path = String(path.dropLast(suffix.count))
        }
        guard path != key else { return nil }
        for prefix in ["base_model.model.", "decoder."] where path.hasPrefix(prefix) { path = String(path.dropFirst(prefix.count)) }
        return path
    }

    /// Folds the adapter into `decoder`. Returns how many layers it changed.
    @discardableResult
    static func merge(_ spec: LoRASpec, into decoder: DiTDecoder) throws(ACEStepError) -> Int {
        var folder = spec.path
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory)
        if !isDirectory.boolValue { folder = folder.deletingLastPathComponent() }
        let weightsURL = folder.appendingPathComponent("adapter_model.safetensors")
        guard FileManager.default.fileExists(atPath: weightsURL.path) else {
            if FileManager.default.fileExists(atPath: folder.appendingPathComponent("lokr_weights.safetensors").path) {
                throw .invalidRequest("LoKr / LyCORIS adapters are not supported; only PEFT LoRA adapters")
            }
            throw .modelMissing("no adapter_model.safetensors in \(folder.path)")
        }
        let config: Config
        do {
            config = try JSONDecoder().decode(Config.self, from: Data(contentsOf: folder.appendingPathComponent("adapter_config.json")))
        } catch { throw .modelMissing("adapter_config.json unreadable: \(error)") }
        let arrays: [String: MLXArray]
        do { arrays = try loadArrays(url: weightsURL) } catch { throw .modelMissing("adapter weights unreadable: \(error)") }
        let base = (config.useRslora ?? false) ? config.loraAlpha / Double(config.r).squareRoot() : config.loraAlpha / Double(config.r)
        let factor = Float(base * spec.scale)
        var linears: [String: Linear] = [:]
        for (path, module) in decoder.leafModules().flattened() {
            if let linear = module as? Linear { linears[path] = linear }
        }
        var updates: [String: MLXArray] = [:]
        for (key, a) in arrays where key.contains("lora_A") {
            guard let path = modulePath(key), let b = arrays[key.replacingOccurrences(of: "lora_A", with: "lora_B")] else { continue }
            guard let linear = linears[path] else {
                throw .invalidRequest("the adapter names \(path), which the turbo DiT does not have — is it for another model?")
            }
            let delta = MLX.matmul(b.asType(.float32), a.asType(.float32)) * factor
            guard delta.shape == linear.weight.shape else {
                throw .invalidRequest("the adapter's \(path) is \(delta.shape), the DiT's is \(linear.weight.shape)")
            }
            updates[path + ".weight"] = (linear.weight.asType(.float32) + delta).asType(linear.weight.dtype)
        }
        guard !updates.isEmpty else { throw .invalidRequest("the adapter has no LoRA weights") }
        do { try decoder.update(parameters: ModuleParameters.unflattened(updates), verify: []) } catch {
            throw .invalidRequest("the adapter does not fit the DiT: \(error)")
        }
        MLX.eval(decoder)
        return updates.count
    }
}
