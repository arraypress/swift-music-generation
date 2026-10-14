//
//  WeightLoading.swift
//  ACEStepMusic
//
//  Created by David Sherlock on 2026.
//
//  The checkpoints load as Hugging Face ships them (bf16 safetensors);
//  only layouts change here, as upstream's dit_convert.py / vae_convert.py
//  change them: PyTorch Conv1d `[out, in, k]` → MLX `[out, k, in]`,
//  ConvTranspose1d `[in, out, k]` → `[out, k, in]`, the `proj_in.1` /
//  `proj_out.1` Sequential indices dropped, weight norm (`weight_g`,
//  `weight_v`) folded into one weight, Snake parameters squeezed to `[C]`.
//  Every array must land on a parameter (`verify: .all`).
//

import Foundation
import MLX
import MLXNN

enum WeightLoading {

    /// The DiT checkpoint into ``ACEStepNetwork``, cast to `dtype`.
    static func loadNetwork(_ network: ACEStepNetwork, from file: URL, dtype: DType) throws(ACEStepError) {
        let raw: [String: MLXArray]
        do { raw = try loadArrays(url: file) } catch { throw .modelMissing("\(file.lastPathComponent) unreadable: \(error)") }
        var weights: [String: MLXArray] = [:]
        for (key, value) in raw {
            var name = key
            var array = value
            if key.hasPrefix("decoder.proj_in.1.") {
                name = key.replacingOccurrences(of: "decoder.proj_in.1.", with: "decoder.proj_in.")
                if name.hasSuffix(".weight") { array = array.swappedAxes(1, 2) }
            } else if key.hasPrefix("decoder.proj_out.1.") {
                name = key.replacingOccurrences(of: "decoder.proj_out.1.", with: "decoder.proj_out.")
                if name.hasSuffix(".weight") { array = array.transposed(1, 2, 0) }
            } else if key.contains("rotary_emb") {
                continue
            }
            weights[name] = array.asType(dtype)
        }
        do {
            try network.update(parameters: ModuleParameters.unflattened(weights), verify: .all)
        } catch { throw .modelMissing("the DiT weights do not fit: \(error)") }
        MLX.eval(network)
    }

    /// The VAE checkpoint into ``OobleckVAE``, weight norm folded, cast to `dtype`.
    static func loadVAE(_ vae: OobleckVAE, from file: URL, dtype: DType) throws(ACEStepError) {
        let raw: [String: MLXArray]
        do { raw = try loadArrays(url: file) } catch { throw .modelMissing("\(file.lastPathComponent) unreadable: \(error)") }
        var weights: [String: MLXArray] = [:]
        for (key, value) in raw {
            if key.hasSuffix(".weight_v") { continue }
            if key.hasSuffix(".weight_g") {
                let base = String(key.dropLast(".weight_g".count))
                guard let v = raw[base + ".weight_v"] else { throw .modelMissing("VAE: \(key) has no weight_v") }
                var w = foldWeightNorm(g: value.asType(.float32), v: v.asType(.float32))
                w = base.hasSuffix("conv_t1") ? w.transposed(1, 2, 0) : w.swappedAxes(1, 2)
                weights[base + ".weight"] = w.asType(dtype)
            } else if key.hasSuffix(".alpha") || key.hasSuffix(".beta") {
                weights[key] = value.reshaped(-1).asType(dtype)
            } else {
                weights[key] = value.asType(dtype)
            }
        }
        do {
            try vae.update(parameters: ModuleParameters.unflattened(weights), verify: .all)
        } catch { throw .modelMissing("the VAE weights do not fit: \(error)") }
        MLX.eval(vae)
    }

    /// `g · v / (‖v‖ + 1e-9)`, the norm taken over every axis but the first.
    static func foldWeightNorm(g: MLXArray, v: MLXArray) -> MLXArray {
        let flat = v.reshaped(v.dim(0), -1)
        let norm = MLX.sqrt((flat * flat).sum(axis: 1)).reshaped(g.shape)
        return g * v / (norm + 1e-9)
    }
}

/// Reads `silence_latent.pt` — a torch zip holding one float32 `[1, 64, T]`
/// tensor — without Python: the archive's central directory gives the
/// stored `data/0` entry, whose bytes are the tensor.
enum TorchTensorFile {

    static func silenceLatent(_ file: URL, channels: Int = 64) throws(ACEStepError) -> MLXArray {
        let data: Data
        do { data = try Data(contentsOf: file) } catch { throw .modelMissing("\(file.lastPathComponent) unreadable") }
        guard let bytes = storedEntry(in: data, suffix: "/data/0"), bytes.count % (4 * channels) == 0 else {
            throw .modelMissing("\(file.lastPathComponent) is not the expected tensor")
        }
        let frames = bytes.count / (4 * channels)
        let floats = bytes.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        // [1, 64, T] → [T, 64]
        return MLXArray(floats, [channels, frames]).transposed(1, 0)
    }

    /// The bytes of the stored (uncompressed) entry whose name ends with `suffix`.
    static func storedEntry(in data: Data, suffix: String) -> Data? {
        let b = [UInt8](data)
        func u16(_ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 }
        func u32(_ o: Int) -> Int { u16(o) | u16(o + 2) << 16 }
        guard b.count > 22 else { return nil }
        var end = b.count - 22
        while end >= 0, u32(end) != 0x0605_4B50 { end -= 1 }
        guard end >= 0 else { return nil }
        var offset = u32(end + 16)
        let count = u16(end + 10)
        for _ in 0..<count {
            guard offset + 46 <= b.count, u32(offset) == 0x0201_4B50 else { return nil }
            let method = u16(offset + 10)
            let size = u32(offset + 20)
            let nameLength = u16(offset + 28), extraLength = u16(offset + 30), commentLength = u16(offset + 32)
            let local = u32(offset + 42)
            let name = String(decoding: b[(offset + 46)..<(offset + 46 + nameLength)], as: UTF8.self)
            if name.hasSuffix(suffix), method == 0 {
                let start = local + 30 + u16(local + 26) + u16(local + 28)
                guard start + size <= b.count else { return nil }
                return Data(b[start..<(start + size)])
            }
            offset += 46 + nameLength + extraLength + commentLength
        }
        return nil
    }
}
