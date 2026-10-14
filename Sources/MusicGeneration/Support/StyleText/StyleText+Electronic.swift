//
//  StyleText+Electronic.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//
//  Electronic and dance styles. Every caption was written for this library.
//

extension StyleText {

    static let electronic = #"""
    [
      {"name": "progressive-house", "title": "Progressive house", "category": "dance",
       "caption": "progressive house, steady four-on-the-floor kick, rolling sixteenth-note bassline, {texture}, long filtered build into a warm wide drop, deep club mix",
       "slots": [{"name": "texture", "default": "pads", "known": [
         {"name": "pads", "phrase": "slowly opening atmospheric pads"},
         {"name": "plucks", "phrase": "hypnotic arpeggiated plucks"},
         {"name": "piano", "phrase": "melancholic piano chords"},
         {"name": "vocal chops", "phrase": "chopped airy vocal fragments"}]}],
       "defaults": {"bpm": 125, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "uplifting-trance", "title": "Uplifting trance", "category": "dance",
       "caption": "uplifting trance, driving kick and offbeat bass, {lead}, rolling arpeggios, emotional breakdown with lush pads, soaring {mood} climax",
       "slots": [
         {"name": "lead", "default": "supersaw", "known": [
           {"name": "supersaw", "phrase": "huge detuned supersaw lead"},
           {"name": "pluck", "phrase": "bright gated pluck lead"},
           {"name": "acid", "phrase": "squelching acid line"}]},
         {"name": "mood", "default": "euphoric", "known": [
           {"name": "euphoric"}, {"name": "bittersweet"}, {"name": "dark", "phrase": "dark and tense"}]}],
       "defaults": {"bpm": 138, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "vocal-trance", "title": "Vocal trance", "category": "dance",
       "caption": "vocal trance, {voice}, supersaw chords, pulsing offbeat bass, uplifting breakdown that rises into a euphoric drop",
       "slots": [{"name": "voice", "default": "female", "known": [
         {"name": "female", "phrase": "ethereal female vocal"},
         {"name": "male", "phrase": "warm male vocal"}]}],
       "defaults": {"bpm": 138, "time_signature": 4, "duration": 120, "instrumental": false},
       "lyrics_hint": "[verse] 4 lines, [chorus] 4 lines with a short repeated hook, [breakdown], [chorus]"},

      {"name": "deep-house", "title": "Deep house", "category": "dance",
       "caption": "deep house, soft swung hi-hats, round sub bass, {keys}, late-night groove, warm and spacious mix",
       "slots": [{"name": "keys", "default": "rhodes", "known": [
         {"name": "rhodes", "phrase": "jazzy electric piano chords"},
         {"name": "organ", "phrase": "dusty organ stabs"},
         {"name": "strings", "phrase": "filtered string swells"}]}],
       "defaults": {"bpm": 122, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "tech-house", "title": "Tech house", "category": "dance",
       "caption": "tech house, punchy kick, tight percussive groove, bouncy {bass}, crisp shakers and claps, minimal hooky stabs",
       "slots": [{"name": "bass", "default": "rubbery bassline", "known": [
         {"name": "rubbery bassline"}, {"name": "rolling bassline"}, {"name": "acid", "phrase": "acid bassline"}]}],
       "defaults": {"bpm": 126, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "techno", "title": "Techno", "category": "electronic",
       "caption": "{flavour} techno, relentless pounding kick, hypnotic looping synth motif, metallic percussion, rumbling low end, warehouse atmosphere",
       "slots": [{"name": "flavour", "default": "driving", "known": [
         {"name": "driving"}, {"name": "dark", "phrase": "dark industrial"}, {"name": "melodic", "phrase": "melodic"}]}],
       "defaults": {"bpm": 130, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "drum-and-bass", "title": "Drum and bass", "category": "electronic",
       "caption": "drum and bass, fast breakbeat drums, {bass}, atmospheric pads, energetic rollout and a big drop",
       "slots": [{"name": "bass", "default": "reese", "known": [
         {"name": "reese", "phrase": "growling reese bass"},
         {"name": "liquid", "phrase": "smooth liquid sub bass with soulful chords"},
         {"name": "neuro", "phrase": "aggressive neuro bass"}]}],
       "defaults": {"bpm": 174, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "dubstep", "title": "Dubstep", "category": "electronic",
       "caption": "dubstep, half-time drums with heavy snare, {bass}, tense build-up, cinematic drop",
       "slots": [{"name": "bass", "default": "wobble", "known": [
         {"name": "wobble", "phrase": "wobbling LFO bass"},
         {"name": "growl", "phrase": "snarling growl bass"},
         {"name": "deep", "phrase": "deep sub-heavy bass with sparse space"}]}],
       "defaults": {"bpm": 140, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "synthwave", "title": "Synthwave", "category": "electronic",
       "caption": "synthwave, gated reverb drums, pulsing arpeggiated bass, {lead}, lush analog pads, neon night-drive mood",
       "slots": [{"name": "lead", "default": "analog lead", "known": [
         {"name": "analog lead", "phrase": "soaring analog synth lead"},
         {"name": "sax", "phrase": "smoky saxophone lead"},
         {"name": "guitar", "phrase": "chorused electric guitar lead"}]}],
       "defaults": {"bpm": 100, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "ambient", "title": "Ambient", "category": "ambient",
       "caption": "ambient, slow evolving {texture}, long reverb tails, gentle movement, calm and spacious, no drums",
       "slots": [{"name": "texture", "default": "drones", "known": [
         {"name": "drones", "phrase": "warm drones and soft pads"},
         {"name": "piano", "phrase": "sparse felt piano notes"},
         {"name": "field", "phrase": "field recordings and shimmering textures"}]}],
       "defaults": {"bpm": 70, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "chillout", "title": "Chillout", "category": "ambient",
       "caption": "chillout downtempo, laid-back beat, warm bass, {colour}, sunset lounge mood, relaxed and smooth",
       "slots": [{"name": "colour", "default": "guitar", "known": [
         {"name": "guitar", "phrase": "soft nylon guitar"},
         {"name": "keys", "phrase": "mellow electric piano"},
         {"name": "flute", "phrase": "breathy flute melody"}]}],
       "defaults": {"bpm": 100, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "lofi-hip-hop", "title": "Lo-fi hip hop", "category": "hip-hop",
       "caption": "lo-fi hip hop beat, dusty swung drums, vinyl crackle, {keys}, mellow bass, cosy study mood",
       "slots": [{"name": "keys", "default": "piano", "known": [
         {"name": "piano", "phrase": "warm jazzy piano chords"},
         {"name": "guitar", "phrase": "soft jazz guitar"},
         {"name": "rhodes", "phrase": "wobbly tape-saturated rhodes"}]}],
       "defaults": {"bpm": 82, "time_signature": 4, "duration": 120, "instrumental": true}}
    ]
    """#
}
