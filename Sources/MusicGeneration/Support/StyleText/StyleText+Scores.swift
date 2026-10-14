//
//  StyleText+Scores.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//
//  Classical, cinematic and world styles. Every caption was written for
//  this library.
//

extension StyleText {

    static let scores = #"""
    [
      {"name": "cinematic", "title": "Cinematic orchestral", "category": "cinematic",
       "caption": "cinematic orchestral score, {mood}, sweeping strings, French horns, timpani rolls, choir swells, film trailer dynamics",
       "slots": [{"name": "mood", "default": "epic", "known": [
         {"name": "epic", "phrase": "epic and heroic"}, {"name": "sad", "phrase": "sorrowful and tender"},
         {"name": "tense", "phrase": "tense and suspenseful"}]}],
       "defaults": {"bpm": 90, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "piano-solo", "title": "Solo piano", "category": "classical",
       "caption": "solo piano, {mood}, expressive dynamics, gentle rubato, close intimate recording",
       "slots": [{"name": "mood", "default": "reflective", "known": [
         {"name": "reflective", "phrase": "reflective and calm"}, {"name": "romantic", "phrase": "romantic and flowing"},
         {"name": "playful", "phrase": "light and playful"}]}],
       "defaults": {"bpm": 72, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "string-quartet", "title": "String quartet", "category": "classical",
       "caption": "string quartet, two violins, viola and cello, {mood}, chamber hall acoustics",
       "slots": [{"name": "mood", "default": "lyrical", "known": [
         {"name": "lyrical", "phrase": "lyrical and singing"}, {"name": "lively", "phrase": "lively and dancing"},
         {"name": "dark", "phrase": "dark and brooding"}]}],
       "defaults": {"bpm": 96, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "waltz", "title": "Waltz", "category": "classical",
       "caption": "elegant waltz in three, {ensemble}, lilting accompaniment, graceful melody",
       "slots": [{"name": "ensemble", "default": "orchestra", "known": [
         {"name": "orchestra", "phrase": "small orchestra"}, {"name": "piano", "phrase": "solo piano"},
         {"name": "accordion", "phrase": "accordion and strings"}]}],
       "defaults": {"bpm": 150, "time_signature": 3, "duration": 120, "instrumental": true}},

      {"name": "reggae", "title": "Reggae", "category": "world",
       "caption": "roots reggae, one-drop drums, deep round bass, offbeat guitar skank, {extra}, relaxed sunny vibe",
       "slots": [{"name": "extra", "default": "organ", "known": [
         {"name": "organ", "phrase": "bubbling organ"}, {"name": "horns", "phrase": "mellow horn section"},
         {"name": "dub", "phrase": "dub echoes and spring reverb"}]}],
       "defaults": {"bpm": 76, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "afrobeats", "title": "Afrobeats", "category": "world",
       "caption": "afrobeats, bouncy syncopated percussion, log drums, warm synth chords, {lead}, sunny dance groove",
       "slots": [{"name": "lead", "default": "vocal", "known": [
         {"name": "vocal", "phrase": "melodic male vocal"}, {"name": "female", "phrase": "smooth female vocal"},
         {"name": "guitar", "phrase": "highlife guitar melody"}]}],
       "defaults": {"bpm": 104, "time_signature": 4, "duration": 120, "instrumental": false, "language": "en"},
       "lyrics_hint": "[verse] 4 lines, [chorus] a repeated chant, [verse], [chorus]"},

      {"name": "reggaeton", "title": "Reggaeton", "category": "latin",
       "caption": "reggaeton, dembow rhythm, heavy kick, plucky synth riff, {voice}, hot club energy",
       "slots": [{"name": "voice", "default": "male", "known": [{"name": "male", "phrase": "male vocal"},
         {"name": "female", "phrase": "female vocal"}]}],
       "defaults": {"bpm": 95, "time_signature": 4, "duration": 120, "instrumental": false, "language": "es"},
       "lyrics_hint": "[verse] 4 lines, [coro] 4 lines, in Spanish or English"},

      {"name": "celtic", "title": "Celtic", "category": "world",
       "caption": "celtic folk, {lead}, bodhrán drum, acoustic guitar, misty highland atmosphere",
       "slots": [{"name": "lead", "default": "whistle", "known": [
         {"name": "whistle", "phrase": "tin whistle melody"}, {"name": "fiddle", "phrase": "lively fiddle reel"},
         {"name": "harp", "phrase": "celtic harp"}]}],
       "defaults": {"bpm": 112, "time_signature": 4, "duration": 120, "instrumental": true}}
    ]
    """#
}
