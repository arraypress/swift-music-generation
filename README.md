# swift-music-generation

Songs from words on Apple silicon: [ACE-Step 1.5](https://github.com/ace-step/ACE-Step-1.5)
turbo (MIT) ported to MLX Swift. Give it a caption, optional lyrics and as many musical facts
as you like; its planner writes the rest (tempo, key, a detailed caption and a 5 Hz sketch
of the song), its diffusion transformer renders 48 kHz stereo. Covers, repaints, extensions
and timbre references of your own audio too. Nothing leaves the Mac. A second, opt-in
engine runs [YuE2-3B](https://huggingface.co/m-a-p/YuE2-3B), which writes an editable ABC
score before the song (its weights carry their own licence — see [YuE2](#yue2)).

| Product | What it is | Dependencies |
| --- | --- | --- |
| `MusicGeneration` | The request (every upstream parameter), styles, recipes, audio files | swift-recipe-kit (Foundation only) |
| `ACEStepMusic` | The engine: planner LM, text encoder, DiT, Oobleck VAE | mlx-swift, mlx-swift-lm, swift-transformers |
| `YuE2Music` | The opt-in YuE2 engine: score, song tokens, flow-matched latents, decoder | mlx-swift, mlx-swift-lm |

The command-line tool is [`song`](https://github.com/arraypress/swift-song-cli).

```swift
import ACEStepMusic
import MusicGeneration

let engine = try ACEStepEngine(modelDirectory: folder)     // the four model folders, see below
var request = SongRequest(caption: "uplifting trance, huge supersaw lead", instrumental: true)
request.bpm = 138
request.duration = 120
request.seed = 7
let song = try await engine.generate(request)[0]
try AudioFiles.write(song.audio, to: URL(fileURLWithPath: "trance.wav"), format: .wav)
print(song.plan?.key ?? "", song.timings.total)
```

Styles and recipes:

```swift
let style = try MusicStyle.require("uplifting-trance")
let request = try StyleComposer.request(style: style, vars: ["lead": "acid"], prompt: "a sunrise anthem",
                                        fields: [("bpm", "140")])        // explicit fields win over the style
let recipe = try RecipeRules.decoded(Data(contentsOf: url))           // strict: unknown keys are refused
```

## The model

`ACEStepModel` pins the weights: `ACE-Step/Ace-Step1.5` at
`19671f406d603126926c1b7e2adc169acbcade22`, loaded as Hugging Face ships them (nothing
converted or re-hosted). Four folders, 10.1 GB: `acestep-v15-turbo` (the DiT with its lyric
and timbre encoders and the FSQ detokenizer, 4.8 GB bf16), `vae` (Oobleck, 337 MB),
`Qwen3-Embedding-0.6B` (text encoder, 1.2 GB) and `acestep-5Hz-lm-1.7B` (the planner, 3.7 GB).
`ACEStepModel.sha256` lists the large files' checksums. `song` fetches them on first use.

Requirements: macOS 14, Apple silicon, 32 GB of memory at float32 or 24 GB at bfloat16
(`ACEStepPrecision`).

## How the port was checked

Parity is the method, as for swift-tts' Drama and OmniVoice engines: upstream's Python
pipeline at ca1e85f (MLX LM, MLX DiT, MLX VAE; PyTorch on the CPU for its condition and text
encoders) was run with every intermediate tensor dumped, and each Swift module was fed the
same inputs. `ParityTests` reproduces this (`ACESTEP_MODEL=… ACESTEP_PARITY=<dump> swift test
--filter Parity`).

Module by module, on the five probe prompts (worst of the three checked):

| Module | Cosine to Python | Max abs difference |
| --- | --- | --- |
| Planner prompts, CoT YAML block, all token ids | identical | 0 |
| Text encoder (Qwen3-Embedding, 189 tokens) | 1.0000000 | 2.5e-4 |
| Lyric embeddings | 1.0000000 | 0 |
| Condition encoder (lyrics + timbre + caption, packed) | 1.0000000 | 8.5e-5 |
| FSQ codes → 25 Hz hints (detokenizer) | 1.0000000 | 1.3e-5 |
| Seeded starting noise (`mx.random.key(seed)`) | 1.0000000 | 3.0e-8 |
| DiT velocity, one step at t = 1 | 1.0000000 | 1.5e-3 |
| Whole 8-step sampler with DCW | 0.9999999 | 3.5e-4 |
| VAE decode (tiled 512/64) | 1.0000000 | 3.1e-5 (116–120 dB SNR) |

End to end, with Python's planner output (metadata and audio codes) and the same seed, the
Swift engine's waveform matches upstream's `python.wav` at **78–100 dB SNR**. The tasks,
with the sampled VAE encodings injected (upstream samples them unseeded):

| Task | SNR to Python's output |
| --- | --- |
| Cover, `cover_strength` 0.7 (switches to the non-cover branch at step 6) | 91.3 dB |
| Repaint 30–45 s, balanced | 76.4 dB |
| Extend 90 → 100 s (repaint past the end) | 103.3 dB |
| Timbre reference, no planner (text-to-music from silence) | 84.0 dB |

The planner is where runs part ways, and they part the same way in Python: audio codes are
sampled at temperature 0.85 from 64,000 tokens, so a 1e-3 logit difference changes a draw.
Teacher-forced on Python's own tokens with Python's random stream, Swift draws the same
token for **183 of 187** reasoning tokens and **253 of 451** audio codes. Python against
itself, changing only how the prompt is prefilled (mathematically identical), draws the same
code **257 of 450** times — so the Swift planner sits on Python's own noise floor.
Same-seed runs are deterministic in Swift: a recipe replays byte for byte.

Measured on the probe's five prompts (90 s instrumental, 75 s vocal; tempo and key by `muse`,
lyrics by `transcribe` with Whisper large-v3-turbo and with Apple's recogniser) — one render
each, so the vocal numbers carry seed-to-seed spread:

| Prompt | Python BPM (asked) | Swift BPM | Python lyrics recall | Swift lyrics recall |
| --- | --- | --- | --- | --- |
| Progressive house | 124.9 (125) | 125 | – | – |
| Uplifting trance | 138 (138) | 92 = 138 × 2/3 | – | – |
| Vocal trance | 69 = 138 / 2 | 138 | 98.2 % / Apple 94.5 % | 78.2 % / Apple 47.3 % |
| Pop | 110 (110) | 111 | 69.1 % / Apple 63.6 % | 89.1 % / Apple 80.0 % |
| Rap | 91.5 (90) | 92 | 98.6 % / Apple 93.2 % | 98.6 % / Apple 97.3 % |

## Speed and memory

Measured on an M3 Max (36 GB, macOS 27), one process per run, the five probe prompts back to
back, nothing else of mine running (other agents may have had the GPU at moments):

| Run | Per song (90 s / 75 s of audio) | Real-time factor | Peak memory footprint | Model load |
| --- | --- | --- | --- | --- |
| Upstream Python (MLX LM, DiT, VAE; PyTorch on the CPU) | 45.5–55.1 s | 1.4–2.0× | 36.8 GB | 23.9 s |
| Upstream Python as the probe ran it (PyTorch on MPS) | 40.3–60.8 s | 1.5–1.9× | 44.5 GB | 71 s |
| Swift, float32 | 27.8–35.9 s | 2.1–3.2× | 32.7 GB (buffer cache unlimited); 23.6 GB with the default 512 MB cap | 3.7 s |
| Swift, bfloat16 | 26.4–30.7 s | 2.6–3.2× | 29.4 GB unlimited; 18.7 GB with the cap | 3.5 s |

A 90 s song through the `song` CLI, model load included: 33.7 s at float32 (23.6 GB), 33.0 s
at bfloat16 (18.7 GB). Most of the time is the planner's 5 Hz codes (11–14 s for 450 codes,
two forward passes per code for its guidance) and the VAE (6–9 s); the DiT's eight steps take
4–6 s. bfloat16 renders the same song (same plan, same codes) about 26 dB SNR from float32.

Two traps the port hit, both measured: swift-transformers splits text on one regular
expression alternating every added token, and the planner's tokenizer has 65,535
`<|audio_code_N|>` added tokens — encoding the codes prompt took 65 s, so the planner's
tokenizer is built without them (codes come back as ids). And the sampling filter
(log-softmax, top-p over 217k tokens) costs 25 ms a token uncompiled; compiled, as mlx_lm
compiles it, 2 ms.

## Every upstream parameter

Each `GenerationParams` / `GenerationConfig` field of ACE-Step 1.5 at ca1e85f, with the
`SongRequest` key (JSON, recipes, `song recipe --set`) and the `song` flag.

| Upstream parameter | `SongRequest` / recipe key | `song` flag | Notes |
| --- | --- | --- | --- |
| `caption` | `caption` | the words; `--style` adds its own | |
| `lyrics` | `lyrics` | `--lyrics FILE` / `-` | |
| `instrumental` | `instrumental` | `--instrumental` / `--vocal` | |
| `vocal_language` | `language` | `--language` | 51 codes |
| `bpm` | `bpm` | `--bpm` | 30–300 |
| `keyscale` | `key` | `--key` | `Am`, `F# minor` normalised |
| `timesignature` | `time_signature` | `--time-signature` | 2, 3, 4, 6 |
| `duration` | `duration` | `--duration` | 10–600 s |
| `inference_steps` | `steps` | `--steps` | 8 |
| `guidance_scale` | `guidance` | `--guidance` | upstream forces 1 for turbo; > 1 is honoured here (APG) |
| `cfg_interval_start` / `_end` | `guidance_start` / `guidance_end` | `--guidance-start` / `--guidance-end` | |
| `shift` | `shift` | `--shift` | |
| `timesteps` | `timesteps` | `--timesteps` | snapped to the 20 distilled values, as upstream |
| `infer_method` | `method` | `--method ode/sde` | |
| `sampler_mode` | `sampler` | `--sampler euler/heun` | |
| `velocity_norm_threshold` | `velocity_norm_threshold` | `--velocity-norm` | |
| `velocity_ema_factor` | `velocity_ema` | `--velocity-ema` | |
| `dcw_enabled` | `dcw` | `--no-dcw` | on for turbo |
| `dcw_mode` | `dcw_mode` | `--dcw-mode` | low, high, double, pix |
| `dcw_scaler` / `dcw_high_scaler` | `dcw_scaler` / `dcw_high_scaler` | `--dcw-scaler` / `--dcw-high-scaler` | |
| `dcw_wavelet` | `dcw_wavelet` | recipe only | `haar` only (see below) |
| `seed` / `seeds` / `use_random_seed` | `seed` | `--seed` | batch item n uses seed + n; omitted is random and recorded |
| `retake_seed` / `retake_variance` | `retake_seed` / `retake_variance` | `--retake-seed` / `--retake-variance` | |
| `latent_shift` / `latent_rescale` | `latent_shift` / `latent_rescale` | `--latent-shift` / `--latent-rescale` | |
| `enable_normalization` / `normalization_db` | `normalize` / `normalization_db` | `--no-normalize` / `--normalize-db` | |
| `fade_in_duration` / `fade_out_duration` | `fade_in` / `fade_out` | `--fade-in` / `--fade-out` | |
| `thinking` | `thinking` | `--no-thinking` | |
| `use_cot_metas` | `plan_metadata` | `--no-plan` | |
| `use_cot_caption` | `rewrite_caption` | `--no-rewrite` | |
| `use_cot_language` | `detect_language` | `--no-detect-language` | see below |
| `lm_temperature` | `planner_temperature` | `--planner-temperature` | |
| `lm_cfg_scale` | `planner_guidance` | `--planner-guidance` | |
| `lm_top_k` / `lm_top_p` | `planner_top_k` / `planner_top_p` | `--planner-top-k` / `--planner-top-p` | |
| `lm_negative_prompt` | `planner_negative_prompt` | `--negative-prompt` | |
| `repetition_penalty` (LM call) | `planner_repetition_penalty` | `--planner-repetition-penalty` | |
| `use_constrained_decoding` | `constrained_decoding` | `--no-constrained-decoding` | |
| `task_type` | `task` | `--cover` / `--repaint` | text2music, cover, repaint (extend = repaint past the end) |
| `src_audio` | `source_audio` | the `--cover` / `--repaint` file | |
| `reference_audio` | `reference_audio` | `--reference` | |
| `audio_codes` | `audio_codes` | `--audio-codes FILE` | |
| `instruction` | `instruction` | `--instruction` | defaults to the task's own (see below) |
| `repainting_start` / `_end` | `repaint_start` / `repaint_end` | `--repaint-start` / `--repaint-end` | |
| `chunk_mask_mode` | `chunk_mask_mode` | `--chunk-mask` | explicit for repaints by default |
| `repaint_mode` / `repaint_strength` | `repaint_mode` / `repaint_strength` | `--repaint-mode` / `--repaint-strength` | |
| `repaint_latent_crossfade_frames` | `repaint_crossfade_frames` | `--repaint-crossfade-frames` | upstream's handler always derives it from the mode; here an explicit value wins |
| `repaint_wav_crossfade_sec` | `repaint_wave_crossfade` | `--repaint-wave-crossfade` | as above |
| `audio_cover_strength` | `cover_strength` | `--cover-strength` | |
| `cover_noise_strength` | `cover_noise_strength` | `--cover-noise` | upstream's PyTorch semantics; its MLX path ignores it |
| `batch_size` | `batch_size` | `--batch` | rendered one after another; same songs as a batch |
| `audio_format` | recipe `output.format` | `-o` extension / `--format` | wav, wav32, flac, m4a (AAC), alac |
| `mp3_sample_rate` (any rate) | recipe `output.sample_rate` | `--sample-rate` | |
| LoRA adapters (PEFT) | recipe `model.lora`, `model.lora_scale` | `--lora DIR` / `--lora-scale` | folded into the DiT at load; nothing trains |

Not supported, and why:

| Upstream parameter | Why not |
| --- | --- |
| `use_adg` | Adaptive dual guidance is for ACE-Step's base models; the turbo model does not use guidance at all. Refused if set. |
| `dcw_wavelet` other than `haar` | Upstream's MLX path is native only for Haar; other bases go through PyTorch Wavelets, which was not ported. Refused. |
| `task_type` lego, extract, complete; `global_caption` | Base and SFT-stems models only; this release ships the turbo model. |
| `flow_edit_morph` and `flow_edit_*` | The flow-edit overlay is a separate sampler (paired velocities); not ported in v0.1.0. |
| `use_cot_lyrics` | Reserved upstream; it does nothing there either. |
| `audio_format` mp3, opus; `mp3_bitrate` | macOS has no MP3 encoder and AVFoundation writes no Ogg Opus; AAC, FLAC and ALAC cover the uses. |
| `allow_lm_batch`, `lm_batch_chunk_size` | Speed knobs for batched planning; songs are planned one at a time, with the same results. |
| `constrained_decoding_debug` | Debug logging only; `ACESTEP_PROFILE=1` prints stage timings instead. |
| `understand_music`, `create_sample`, `format_sample` | The planner's other modes (describe audio, write lyrics from a query); not in v0.1.0. |
| LoKr / LyCORIS adapters | Only PEFT LoRA adapters fold in; LoKr is refused by name. |

Where this port deliberately differs from upstream's Python API:

- **The DiT's instruction defaults to the task's own** — "Repaint the mask area…" for
  repaints, "Generate audio semantic tokens…" for covers — as upstream's own interface and
  REST server set it. Upstream's `generate_music` keeps the text-to-music line for every task
  unless `instruction` is given; pass `instruction` to reproduce that (the parity runs do).
- **The planner and every random draw are seeded.** Upstream seeds only the diffusion noise;
  its planner, VAE posterior samples and reference-clip offsets are unseeded, so the same
  seed does not replay a song there. Here it does.
- `use_cot_language` is honoured as upstream honours it: its result is read from a
  `vocal_language` key the planner never writes, so the DiT keeps the language you gave.
- Captions longer than 256 tokens are cut by the text tokenizer, as upstream cuts them; the
  512-character figure in upstream's documentation is not enforced there or here.

## Styles

39 built-in styles (`MusicStyle.all`), written for this library, as JSON in
`Support/StyleText/`: each has caption words with `{slot}` markers, slots with defaults and
the values they know, and default request fields. Styles set tempo, time signature, length
and vocals but leave the key to the planner, so it still writes its plan (with every fact
fixed, upstream skips the plan and the caption stays as typed). `StyleComposer` layers
upstream defaults < style defaults < explicit fields.

Every style was rendered once (45 s, seed 1, the probe's lyrics for vocal styles) and
measured with [{"alternatives":[{"class":"keys","confidence":0.61},{"class":"stab","confidence":0.16},{"class":"vocal","confidence":0.05}],"barCount":5,"beatCount":16,"bpm":123,"class":"keys","classConfidence":0.61,"file":"audio_16k.wav","group":"synth","instruments":[{"instrument":"vocal","mean":0,"peak":0},{"instrument":"drum","mean":0,"peak":0.38},{"instrument":"bass","mean":0.01,"peak":0.71},{"activeSeconds":7.9,"instrument":"other","mean":0.63,"peak":0.74}],"key":"Ab major","lufs":-22.8,"pace":30.8,"peakDb":-6.5,"phrases":3,"seconds":7.8,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"keys","confidence":0.93},{"class":"vocal","confidence":0.01},{"class":"lead","confidence":0.01}],"barCount":10,"beatCount":37,"bpm":128,"class":"keys","classConfidence":0.93,"file":"render_audio_16k.wav","group":"synth","instruments":[{"instrument":"vocal","mean":0,"peak":0},{"instrument":"drum","mean":0,"peak":0.13},{"instrument":"bass","mean":0.01,"peak":0.36},{"activeSeconds":16.1,"instrument":"other","mean":0.61,"peak":0.8}],"key":"G major","lufs":-22.1,"pace":8,"peakDb":-6.9,"phrases":4,"seconds":17,"sections":1,"segments":2,"tonal":true},{"alternatives":[{"class":"vocal","confidence":0.64},{"class":"drum_loop","confidence":0.07},{"class":"lead","confidence":0.05}],"barCount":3,"beatCount":13,"bpm":77.5,"class":"vocal","classConfidence":0.64,"file":"demo_16k.wav","group":"vocals","instruments":[{"instrument":"vocal","mean":0,"peak":0.01},{"activeSeconds":10.1,"instrument":"drum","mean":0.64,"peak":0.86},{"activeSeconds":10.1,"instrument":"bass","mean":0.63,"peak":0.87},{"activeSeconds":10.1,"instrument":"other","mean":0.73,"peak":0.81}],"key":"A major","lufs":-13.1,"pace":38.8,"peakDb":-0.5,"phrases":2,"seconds":10.02,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"bass","confidence":0.85},{"class":"stab","confidence":0.04},{"class":"percussion","confidence":0.03}],"barCount":5,"beatCount":21,"bpm":81.9,"class":"bass","classConfidence":0.85,"file":"bass_16k.wav","group":"bass","instruments":[{"instrument":"vocal","mean":0,"peak":0},{"instrument":"drum","mean":0,"peak":0.15},{"activeSeconds":15.7,"instrument":"bass","mean":0.55,"peak":0.76},{"instrument":"other","mean":0,"peak":0.11}],"key":"C minor","lufs":-20.5,"pace":25.7,"peakDb":-4.7,"phrases":4,"seconds":15.61,"sections":2,"segments":3,"tonal":true},{"alternatives":[{"class":"bass","confidence":0.39},{"class":"sweep","confidence":0.17},{"class":"fx","confidence":0.12}],"barCount":0,"beatCount":1,"class":"bass","classConfidence":0.39,"file":"glide_16k.wav","group":"bass","instruments":[{"instrument":"vocal","mean":0.02,"peak":0.05},{"instrument":"drum","mean":0.02,"peak":0.58},{"activeSeconds":2.1,"instrument":"bass","mean":0.46,"peak":0.69},{"activeSeconds":2.1,"instrument":"other","mean":0.55,"peak":0.6}],"key":"C major","lufs":-12,"pace":11,"peakDb":-6,"phrases":1,"seconds":2,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"pluck","confidence":0.47},{"class":"atmo","confidence":0.19},{"class":"stab","confidence":0.11}],"barCount":4,"beatCount":16,"bpm":70,"class":"pluck","classConfidence":0.47,"file":"lead_16k.wav","group":"synth","instruments":[{"instrument":"vocal","mean":0,"peak":0},{"instrument":"drum","mean":0,"peak":0.65},{"activeSeconds":13.8,"instrument":"bass","mean":0.52,"peak":0.79},{"activeSeconds":13.8,"instrument":"other","mean":0.82,"peak":0.85}],"key":"Eb major","lufs":-13.5,"pace":17.5,"peakDb":-2.4,"phrases":2,"seconds":13.71,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"bass","confidence":0.46},{"class":"atmo","confidence":0.15},{"class":"stab","confidence":0.12}],"barCount":1,"beatCount":2,"bpm":40.5,"class":"bass","classConfidence":0.46,"file":"steady441_16k.wav","group":"bass","instruments":[{"instrument":"vocal","mean":0.01,"peak":0.05},{"instrument":"drum","mean":0.01,"peak":0.5},{"instrument":"bass","mean":0.09,"peak":0.64},{"activeSeconds":2.1,"instrument":"other","mean":0.72,"peak":0.76}],"key":"A minor","lufs":-11.5,"pace":10.1,"peakDb":-6,"phrases":1,"seconds":2,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"bass","confidence":0.47},{"class":"atmo","confidence":0.15},{"class":"stab","confidence":0.12}],"barCount":1,"beatCount":2,"bpm":40.5,"class":"bass","classConfidence":0.47,"file":"steady_16k.wav","group":"bass","instruments":[{"instrument":"vocal","mean":0.01,"peak":0.05},{"instrument":"drum","mean":0.01,"peak":0.51},{"instrument":"bass","mean":0.09,"peak":0.64},{"activeSeconds":2.1,"instrument":"other","mean":0.72,"peak":0.76}],"key":"A minor","lufs":-11.5,"pace":10.1,"peakDb":-6,"phrases":1,"seconds":2,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"stab","confidence":0.23},{"class":"vocal","confidence":0.22},{"class":"pad","confidence":0.14}],"barCount":1,"beatCount":2,"bpm":40.5,"class":"stab","classConfidence":0.23,"file":"vibrato_16k.wav","group":"synth","instruments":[{"instrument":"vocal","mean":0.17,"peak":0.24},{"instrument":"drum","mean":0.01,"peak":0.3},{"instrument":"bass","mean":0.03,"peak":0.6},{"activeSeconds":2.1,"instrument":"other","mean":0.62,"peak":0.68}],"key":"C major","lufs":-11.4,"pace":10.1,"peakDb":-6,"phrases":1,"seconds":2,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"vocal","confidence":0.98},{"class":"perc_loop","confidence":0},{"class":"atmo","confidence":0}],"barCount":4,"beatCount":16,"bpm":125.8,"class":"vocal","classConfidence":0.98,"file":"vocal_16k.wav","group":"vocals","instruments":[{"activeSeconds":7.7,"instrument":"vocal","mean":0.3,"peak":0.47},{"instrument":"drum","mean":0,"peak":0.15},{"instrument":"bass","mean":0.01,"peak":0.43},{"instrument":"other","mean":0.01,"peak":0.17}],"key":"E major","lufs":-37.7,"pace":31.2,"peakDb":-19,"phrases":3,"seconds":7.62,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"lead","confidence":0.43},{"class":"drum_loop","confidence":0.26},{"class":"pluck","confidence":0.13}],"barCount":6,"beatCount":22,"bpm":128,"class":"lead","classConfidence":0.43,"file":"demo10s_48k.wav","group":"synth","instruments":[{"instrument":"vocal","mean":0.1,"peak":0.16},{"activeSeconds":10,"instrument":"drum","mean":0.77,"peak":0.89},{"activeSeconds":10,"instrument":"bass","mean":0.68,"peak":0.89},{"activeSeconds":10,"instrument":"other","mean":0.72,"peak":0.79}],"key":"Eb minor","lufs":-10.6,"pace":42.7,"peakDb":-0,"phrases":2,"seconds":10,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"drum_loop","confidence":0.92},{"class":"kick","confidence":0.01},{"class":"clap","confidence":0.01}],"barCount":1,"beatCount":5,"bpm":82.9,"class":"drum_loop","classConfidence":0.92,"file":"drums6s_48k.wav","group":"drums","instruments":[{"instrument":"vocal","mean":0,"peak":0},{"activeSeconds":3.9,"instrument":"drum","mean":0.69,"peak":0.92},{"instrument":"bass","mean":0.01,"peak":0.45},{"instrument":"other","mean":0,"peak":0.01}],"lufs":-15.3,"pace":27.8,"peakDb":-0.2,"phrases":1,"seconds":3.84,"sections":1,"segments":1,"tonal":false},{"alternatives":[{"class":"vocal","confidence":0.61},{"class":"drum_loop","confidence":0.19},{"class":"pluck","confidence":0.09}],"barCount":1,"beatCount":4,"bpm":77.7,"class":"vocal","classConfidence":0.61,"file":"short3s_48k.wav","group":"vocals","instruments":[{"instrument":"vocal","mean":0.03,"peak":0.06},{"activeSeconds":3,"instrument":"drum","mean":0.68,"peak":0.85},{"activeSeconds":3,"instrument":"bass","mean":0.37,"peak":0.68},{"activeSeconds":3,"instrument":"other","mean":0.68,"peak":0.72}],"key":"F# minor","lufs":-13.9,"pace":25.9,"peakDb":-0.6,"phrases":1,"seconds":3,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"atmo","confidence":0.59},{"class":"fx","confidence":0.29},{"class":"vocal","confidence":0.03}],"barCount":75,"beatCount":302,"bpm":148,"class":"atmo","classConfidence":0.59,"file":"chao-phraya-ambience.mp3","group":"fx","instruments":[{"activeSeconds":49.3,"instrument":"vocal","mean":0.2,"peak":0.63},{"instrument":"drum","mean":0.07,"peak":0.17},{"instrument":"bass","mean":0.02,"peak":0.06},{"activeSeconds":122.1,"instrument":"other","mean":0.64,"peak":0.7}],"key":"F# minor","lufs":-19.3,"pace":25,"peakDb":-5.8,"phrases":27,"seconds":122.3,"sections":6,"segments":15,"tonal":true},{"alternatives":[{"class":"vocal","confidence":0.46},{"class":"atmo","confidence":0.31},{"class":"fx","confidence":0.11}],"barCount":2,"beatCount":8,"bpm":127.8,"class":"vocal","classConfidence":0.46,"file":"narration-1.aiff","group":"vocals","instruments":[{"activeSeconds":3.4,"instrument":"vocal","mean":0.57,"peak":0.77},{"instrument":"drum","mean":0,"peak":0.15},{"instrument":"bass","mean":0.03,"peak":0.48},{"instrument":"other","mean":0.04,"peak":0.2}],"key":"E minor","lufs":-20.5,"pace":32,"peakDb":-1.8,"phrases":1,"seconds":3.68,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"vocal","confidence":0.38},{"class":"atmo","confidence":0.24},{"class":"fx","confidence":0.2}],"barCount":1,"beatCount":4,"bpm":42.8,"class":"vocal","classConfidence":0.38,"file":"narration-2.aiff","group":"vocals","instruments":[{"activeSeconds":5.5,"instrument":"vocal","mean":0.58,"peak":0.78},{"instrument":"drum","mean":0,"peak":0.22},{"instrument":"bass","mean":0.02,"peak":0.45},{"instrument":"other","mean":0,"peak":0.05}],"key":"Bb minor","lufs":-19.3,"pace":21.4,"peakDb":-1.8,"phrases":2,"seconds":5.69,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"vocal","confidence":0.46},{"class":"atmo","confidence":0.31},{"class":"fx","confidence":0.11}],"barCount":2,"beatCount":8,"bpm":106.6,"class":"vocal","classConfidence":0.46,"file":"narration-3.aiff","group":"vocals","instruments":[{"activeSeconds":4.8,"instrument":"vocal","mean":0.56,"peak":0.81},{"instrument":"drum","mean":0,"peak":0.14},{"instrument":"bass","mean":0.01,"peak":0.46},{"instrument":"other","mean":0.01,"peak":0.05}],"key":"C major","lufs":-20.6,"pace":26.7,"peakDb":-3.7,"phrases":1,"seconds":4.97,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"vocal","confidence":0.5},{"class":"atmo","confidence":0.19},{"class":"fx","confidence":0.14}],"barCount":3,"beatCount":10,"bpm":113.7,"class":"vocal","classConfidence":0.5,"file":"narration-4.aiff","group":"vocals","instruments":[{"activeSeconds":5.2,"instrument":"vocal","mean":0.57,"peak":0.8},{"instrument":"drum","mean":0,"peak":0.14},{"instrument":"bass","mean":0.02,"peak":0.48},{"instrument":"other","mean":0,"peak":0}],"key":"Bb minor","lufs":-20.1,"pace":28.1,"peakDb":-2.4,"phrases":1,"seconds":5.41,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"atmo","confidence":0.49},{"class":"vocal","confidence":0.25},{"class":"fx","confidence":0.13}],"barCount":2,"beatCount":11,"bpm":72.6,"class":"atmo","classConfidence":0.49,"file":"narration.aiff","group":"fx","instruments":[{"activeSeconds":9.6,"instrument":"vocal","mean":0.61,"peak":0.79},{"instrument":"drum","mean":0,"peak":0.24},{"instrument":"bass","mean":0,"peak":0.46},{"instrument":"other","mean":0,"peak":0.11}],"key":"E minor","lufs":-19.4,"pace":18.3,"peakDb":-2,"phrases":2,"seconds":9.77,"sections":1,"segments":1,"tonal":true},{"alternatives":[{"class":"atmo","confidence":0.44},{"class":"fx","confidence":0.25},{"class":"vocal","confidence":0.19}],"barCount":3,"beatCount":14,"bpm":97.7,"class":"atmo","classConfidence":0.44,"file":"narration.aiff","group":"fx","instruments":[{"activeSeconds":8.4,"instrument":"vocal","mean":0.58,"peak":0.78},{"instrument":"drum","mean":0,"peak":0.22},{"instrument":"bass","mean":0.03,"peak":0.38},{"instrument":"other","mean":0.03,"peak":0.15}],"key":"Eb minor","lufs":-20.6,"pace":32.7,"peakDb":-1.4,"phrases":2,"seconds":8.54,"sections":1,"segments":1,"tonal":true}]: tempo heard against tempo asked (folded across ×2, ×½, ×3/2, ×2/3, as
half-time hearings are common), key heard (without muse's tonal gate) against the key the
planner chose. **Tempo landed within 3 % for 37 of 39 styles**; lo-fi hip hop came out at
85 for 82 (3.7 %), and reggae's one-drop was heard at 95 for 76 — a miss. **The key landed
exactly for 26**, on the relative key (the same notes) for 3, the parallel key for 2, a
fifth away for 6; progressive house was planned in F major and heard in A minor, and techno
has no key muse would name.

| Style | BPM asked | BPM heard (folded) | Planned key | Heard key | Key match |
| --- | --- | --- | --- | --- | --- |
| progressive-house | 125 | 124 (124) | F major | A minor | miss |
| uplifting-trance | 138 | 135.4 (135.4) | F major | F major | exact |
| vocal-trance | 138 | 136 (136) | C# minor | C# minor | exact |
| deep-house | 122 | 122 (122) | C major | A minor | relative |
| tech-house | 126 | 126 (126) | C minor | C major | parallel |
| techno | 130 | 130 (130) | G minor | none | no key |
| drum-and-bass | 174 | 172 (172) | E minor | E minor | exact |
| dubstep | 140 | 70 (140) | F minor | F minor | exact |
| synthwave | 100 | 100 (100) | A major | E major | fifth |
| ambient | 70 | 70 (70) | A major | A major | exact |
| chillout | 100 | 99.9 (99.9) | D minor | D minor | exact |
| lofi-hip-hop | 82 | 85 (85) | C minor | G minor | fifth |
| pop | 110 | 112.1 (112.1) | C major | C major | exact |
| dance-pop | 122 | 122.3 (122.3) | G major | E minor | relative |
| indie-pop | 115 | 116 (116) | A major | A major | exact |
| ballad | 72 | 72 (72) | F major | F major | exact |
| rap | 90 | 92 (92) | F# minor | F# minor | exact |
| trap | 140 | 70 (140) | C minor | C major | parallel |
| r-and-b | 95 | 93 (93) | B♭ minor | Bb minor | exact |
| neo-soul | 88 | 88.9 (88.9) | C minor | G minor | fifth |
| funk | 108 | 108 (108) | E minor | E minor | exact |
| disco | 120 | 120 (120) | B minor | B minor | exact |
| rock | 120 | 120 (120) | D major | D major | exact |
| indie-rock | 128 | 128 (128) | G major | D major | fifth |
| punk | 170 | 172.3 (172.3) | D major | D major | exact |
| metal | 140 | 70 (140) | E minor | E minor | exact |
| blues | 80 | 80 (80) | D major | A major | fifth |
| jazz | 140 | 70 (140) | C major | C major | exact |
| bossa-nova | 130 | 130 (130) | E major | E major | exact |
| folk | 96 | 94.8 (94.8) | C major | C major | exact |
| country | 104 | 105.2 (105.2) | G major | D major | fifth |
| cinematic | 90 | 90 (90) | G minor | G minor | exact |
| piano-solo | 72 | 72 (72) | A♭ major | F minor | relative |
| string-quartet | 96 | 96 (96) | A major | A major | exact |
| waltz | 150 | 151.7 (151.7) | B♭ major | Bb major | exact |
| reggae | 76 | 95 (63.3) | D minor | D minor | exact |
| afrobeats | 104 | 105 (105) | D minor | D minor | exact |
| reggaeton | 95 | 95 (95) | F minor | F minor | exact |
| celtic | 112 | 110 (110) | A minor | A minor | exact |

## Recipes

`SongRecipe` (`"song": 1`) records the engine, the pinned model revision and precision,
the request as given (with the seed), the style and its slot values, the output format and
rate, and, for information only, the planner's choices and what wrote it. Reading refuses
unknown keys and newer formats. Replaying it is the same run: the same planner draws, the
same noise, the same song, byte for byte (checked).

Slot filling, `--var`, the strict recipe reader and the `--set` engine are
[swift-recipe-kit](https://github.com/arraypress/swift-recipe-kit)'s, shared with imagine
(0.2.1; imported with this library). What is song's own is the field-kind table and the
paths. Since 0.2.1, `--set` follows the shared rules: a yes/no field takes
`true`/`yes`/`1` or `false`/`no`/`0` (not `on`/`off`), a whole-number field refuses `120.0`,
a seed's message names its range, and `inf` in a number field is refused rather than
crashing.

## YuE2

`YuE2Engine` runs YuE2-3B (Multimodal Art Projection) on MLX, in bfloat16 as shipped. It is a
mixture of transformers: 28 Qwen3-shaped layers, each with an autoregressive path that
writes a chord-annotated ABC score and then 25 Hz song tokens, and a bidirectional path that
turns those tokens into 64-channel latents with 32 midpoint flow-matching steps. An Oobleck
decoder renders 48 kHz stereo from the latents.

```swift
import MusicGeneration
import YuE2Music

let engine = try YuE2Engine(modelDirectory: folder, licence: YuE2Licence.version)   // naming the licence accepts it
var request = SongRequest(caption: "vocal trance, ethereal female vocal, supersaw chords")
request.engine = .yue2
request.lyrics = words                         // [Verse] / [Chorus] sections
request.bpm = 138
request.seed = 42
let song = try await engine.generate(request)[0]
print(song.plan?.score ?? "")                  // the ABC it followed; edit it and pass it back as yue.score
```

**Licence.** The weights are CC BY-NC 4.0, with the licensors' 2026-09-16 permission for
individual creators: a person may use them free of charge and publish, sell or license the
songs they make; a company may not use them commercially without a licence from m-a-p;
responsible-use conditions apply. `YuE2Engine` refuses to start unless it is handed
`YuE2Licence.version`; `YuE2Licence.summary` and `.individualCreatorPermission` hold the
terms (the CLI shows both before a person accepts). The engine's code follows m-a-p's
yue2-infer (Apache-2.0) — see `THIRD_PARTY_NOTICES.md`.

**The model.** `YuE2Model` pins `m-a-p/YuE2-3B` at `8f24312` (7.26 GB, bfloat16, with
`qwen.tiktoken`) and `m-a-p/YuE2-Vae` at `152733a` (0.53 GB, float32); the legacy decoder
upstream benchmarked, `m-a-p/YuE2-Vae-legacy` at `d0585a9`, is a separate opt-in download.
They live in one folder as `YuE2-3B/`, `YuE2-Vae/` and `YuE2-Vae-legacy/`.

**How it was checked.** Against yue2-infer 0.1.5 on PyTorch (MPS), with every stage dumped,
for two cases — full planning with a song, and planning off with a rap (`YuE2ParityTests`:
`YUE2_MODEL=… YUE2_REF=<dump> swift test --filter YuE2Parity`):

| Stage | Full planning | Planning off |
| --- | --- | --- |
| Tokenizer (six texts incl. CJK, accents, ABC) and both prompts | identical ids | identical ids |
| Score logits, 24 steps teacher-forced | cos ≥ 0.99976 | — |
| Song-token logits, 24 steps (off: with its 1.01 guidance) | cos ≥ 0.99992 | cos ≥ 0.99998 |
| Sampling filter from upstream's logits | same tokens kept, every step | within 3 tokens on the top-p edge (upstream's bf16 arithmetic) |
| Velocity at t = 1 / mid-step | 34.3 / 32.9 dB SNR | 39.1 / 39.0 dB |
| Latents after 32 steps, same noise | 36.5 dB | 39.6 dB |
| Decoder, same latents (1024- or 128-frame tiles) | 116.0 dB | 114.0 dB |
| Audio from Swift's latents | 29.7 dB | 35.0 dB |

The transformer runs in bfloat16 on both sides, so the 33–40 dB on the latents is bf16 noise
between two backends, not a modelling difference; the decoder (float32) matches to 116 dB.
The random draws differ by design (see the table below), so a seed replays in Swift, not the
Python song.

**The five probe prompts** (`song --engine yue2`, full planning, seed 42, a 90 s cap, the
score planned by YuE2 itself; measured with `muse` and Whisper large-v3-turbo; M3 Max 36 GB with
the Mac awake and in use, so ordinary desktop GPU load ran alongside):

| Prompt | Length | Score (tempo, key) | Heard (tempo, key) | Lyrics recall / WER | Time (real-time factor) |
| --- | --- | --- | --- | --- | --- |
| Progressive house (125 BPM asked) | 90 s, capped | 126, G minor | 126, G minor | instrumental | 254 s (0.35×) |
| Uplifting trance (138) | 90 s, capped | 138, G minor | 138, G minor | instrumental | 242 s (0.37×) |
| Vocal trance (138) | 90 s, capped | 138, G minor | 69 = 138 / 2, G minor | 96.4 % / 3.6 % | 152 s (0.59×) |
| Pop (110) | 41 s, ended itself | 108, A major | 108, A major | 96.4 % / 5.5 % | 87 s (0.47×) |
| Rap (90) | 67 s, ended itself | 90, B minor | 90.9, B minor | 94.6 % / 12.2 % | 116 s (0.58×) |

The score's tempo and key are what you hear, every time. Peak memory footprint 13.9–14.0 GB
(the process, model load included). Time splits for the 90 s instrumentals: the score 76–85 s
(4,096 tokens, capped), the song tokens 48–51 s, the acoustic latents 112 s, the decoder 6 s.
For comparison, on the same Mac: upstream's PyTorch package on MPS made a 16 s clip at 0.32×
real time, and the earlier probe's community 8-bit MLX port ran 0.26–0.49× at a 27–31 GB peak.
A recipe replays byte for byte (checked), and `--score-only` writes the same score a full run
follows.

Two things measured on the way: a debug build of MLX (`swift test` without `-c release`)
runs the transformer 3.4× slower (58 against 17 ms a token), so time only release builds; and
a Mac in idle sleep runs a job only in DarkWake windows, with minutes-long stalls and
thermal-emergency sleeps under GPU load — measure with the Mac awake.

### Every YuE2 parameter

Each field of yue2_infer 0.1.5's `SongRequest`, `GenerationConfig`, `Sampling` and
`YuE2Pipeline`, and each option of its `yue2` command, with the `SongRequest` key and the
`song` flag. YuE2 settings sit under `yue` in a request (`--set yue.ode_steps=16`, or the bare
name: `--set ode_steps=16`).

| Upstream parameter | `SongRequest` / recipe key | `song` flag | Notes |
| --- | --- | --- | --- |
| `style` / `tags` | `caption` (+ `bpm`, `key`, `instrumental`) | the words; `--style` adds its own | the `[Tags]` line; a tempo or key you set is appended as YuE2's examples write it ("138 BPM", "A minor") unless the caption already names it |
| `lyrics` / `--lyrics-file` | `lyrics` | `--lyrics FILE` / `-` | section tags capitalised (`[verse]` → `[Verse]`); `--instrumental` sends wordless sections |
| `cot` | `yue.planning` | `--planning full\|melody\|off` | full is upstream's default |
| `abc` / `--abc-file` | `yue.score` | `--score FILE` | render your own (or an edited) ABC score; needs full or melody |
| `seed` | `seed` | `--seed` | 0–2³²−1 here (upstream 0–2⁶³−1); random when left out, and recorded |
| `cfg_scale` / `--cfg-scale` | `yue.guidance` | `--yue-guidance` | upstream's 1.0, or 1.01 with planning off |
| `GenerationConfig.abc` (`temperature`, `top_p`, `top_k`, `repetition_penalty`, `penalty_window`, `min_tokens`, `max_tokens`) | `yue.abc_*` | `--abc-temperature`, `--abc-top-p`, `--abc-top-k`, `--abc-repetition-penalty`, `--abc-penalty-window`, `--abc-min-tokens`, `--abc-max-tokens` | 0.7, 0.9, 30, 1.005, 100, 32, 4096 |
| `GenerationConfig.semantic` (the same seven) | `yue.semantic_*` | `--semantic-temperature` … `--semantic-max-tokens` | 1.0, 0.95, 100, 1.2, 50, 200, 9000 |
| — (no duration upstream) | `duration` | `--duration` | caps the song tokens at 25 a second (the lower of it and `semantic_max_tokens`) |
| `ode_steps` | `yue.ode_steps` | `--ode-steps` | 32 midpoint steps |
| `--vae` (standard, legacy) | `yue.decoder` | `--decoder standard\|legacy` | legacy is a separate 0.5 GB download |
| `vae_core_frames` | `yue.decoder_tile_frames` | `--decoder-tile-frames` | 16 frames of context either side, as upstream |
| `--stage plan` | — | `--score-only --save-score FILE` | the score, no audio |
| `--request`, `--config`, `batch --input` | a recipe | `song recipe FILE` | |
| `--offline` | — | `--no-download` | |
| `--output`, `--id` | — | `-o`, `--out` | |
| `--quiet` / `--no-progress` | — | `--quiet` | |
| `--model`, `--revision`, `--vae-revision` | `model` in a recipe | `--model DIR` | revisions are pinned (`YuE2Model`) |
| `SongResult.save_artifacts` (score, tokens, latents) | — | `--save-score`, `--save-recipe` | the song tokens are in `GeneratedSong.audioCodes` |

Not supported, and why:

| Upstream | Why not |
| --- | --- |
| `ode_method` other than midpoint, `context` other than 24,576 | upstream refuses them too (`GenerationConfig.__post_init__`) |
| `backend` torch / torch-eager / vllm, `--device`, CUDA graphs | one MLX backend on Apple silicon |
| `quantization` fp8, `--offload-ar`, `memory_budget_gib` / `--budget` | CUDA memory tools; on unified memory `--decoder-tile-frames` is the one memory knob that matters |
| `--resume`, `--concurrency` | one song at a time, nothing half-written to resume |
| `doctor --verify-hashes`, `verify`, `bench`, `eval` | checksums are verified on every download; `song models` shows the state |
| Cover transcription (SheetSage 2 / MERT, in the README's cover recipe) | separate models upstream does not ship in the wheel; write or edit the ABC and pass `--score` |
| Exact Python draws | upstream draws with `torch.multinomial` and `torch.randn` on its own generators; the same distributions are drawn here with MLX's seeded generator, so a seed replays in Swift but is not the Python song |

## Licences

MIT. The weights are MIT (ACE-Step); the text encoder and planner derive from Qwen3
(Apache-2.0). YuE2's weights are CC BY-NC 4.0 with the individual-creator permission, and
opt-in; the YuE2 engine follows m-a-p's yue2-infer (Apache-2.0); the shared Oobleck decoder
derives from stable-audio-tools and BigVGAN (MIT). Parts of the network code were adapted from
[mere.run](https://github.com/sawfwair/mere-run) (MIT) — see `THIRD_PARTY_NOTICES.md`.
