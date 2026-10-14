//
//  StyleText+Songs.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//
//  Pop, hip-hop and R&B styles — vocal by default; give lyrics with
//  --lyrics, or set instrumental. Every caption was written for this library.
//

extension StyleText {

    static let songs = #"""
    [
      {"name": "pop", "title": "Pop", "category": "pop",
       "caption": "upbeat pop song, catchy {voice}, bright synths and guitar, punchy drums, big singalong chorus, polished radio production",
       "slots": [{"name": "voice", "default": "female", "known": [
         {"name": "female", "phrase": "female lead vocal"}, {"name": "male", "phrase": "male lead vocal"},
         {"name": "duet", "phrase": "male and female duet vocals"}]}],
       "defaults": {"bpm": 110, "time_signature": 4, "duration": 120, "instrumental": false, "language": "en"},
       "lyrics_hint": "[verse] 4 lines, [pre-chorus] 2 lines, [chorus] 4 lines with the title, [verse], [chorus], [bridge], [chorus]"},

      {"name": "dance-pop", "title": "Dance pop", "category": "pop",
       "caption": "dance pop, four-on-the-floor beat, glossy synth chords, {voice}, euphoric hook, club-ready mix",
       "slots": [{"name": "voice", "default": "female", "known": [
         {"name": "female", "phrase": "confident female vocal"}, {"name": "male", "phrase": "smooth male vocal"}]}],
       "defaults": {"bpm": 122, "time_signature": 4, "duration": 120, "instrumental": false, "language": "en"},
       "lyrics_hint": "[verse] 4 lines, [chorus] a short repeated hook, [verse], [chorus], [drop]"},

      {"name": "indie-pop", "title": "Indie pop", "category": "pop",
       "caption": "indie pop, jangly guitars, warm bass, light drums, dreamy {voice}, nostalgic and hopeful",
       "slots": [{"name": "voice", "default": "female", "known": [
         {"name": "female", "phrase": "soft female vocal"}, {"name": "male", "phrase": "boyish male vocal"}]}],
       "defaults": {"bpm": 115, "time_signature": 4, "duration": 120, "instrumental": false, "language": "en"},
       "lyrics_hint": "[verse] 4 lines, [chorus] 4 lines, [verse], [chorus]"},

      {"name": "ballad", "title": "Piano ballad", "category": "pop",
       "caption": "emotional piano ballad, {voice}, intimate verses building to a powerful chorus, strings swell, heartfelt",
       "slots": [{"name": "voice", "default": "female", "known": [
         {"name": "female", "phrase": "expressive female vocal"}, {"name": "male", "phrase": "tender male vocal"}]}],
       "defaults": {"bpm": 72, "time_signature": 4, "duration": 150, "instrumental": false, "language": "en"},
       "lyrics_hint": "[verse] 4 lines, [chorus] 4 lines, [verse], [chorus], [bridge], [chorus]"},

      {"name": "rap", "title": "Rap", "category": "hip-hop",
       "caption": "hip-hop, confident {voice} rapping, {beat}, deep 808 bass, head-nodding groove",
       "slots": [
         {"name": "voice", "default": "male", "known": [{"name": "male"}, {"name": "female"}]},
         {"name": "beat", "default": "boom bap", "known": [
           {"name": "boom bap", "phrase": "dusty boom-bap drums with a sampled loop"},
           {"name": "west coast", "phrase": "laid-back west coast synth groove"},
           {"name": "jazzy", "phrase": "jazzy sampled horns and upright bass"}]}],
       "defaults": {"bpm": 90, "time_signature": 4, "duration": 90, "instrumental": false, "language": "en"},
       "lyrics_hint": "[verse] 8–16 rhyming lines, [hook] 4 lines, [verse]"},

      {"name": "trap", "title": "Trap", "category": "hip-hop",
       "caption": "trap, rattling hi-hat rolls, booming 808 slides, dark {melody}, half-time feel, {voice} vocal",
       "slots": [
         {"name": "melody", "default": "bells", "known": [
           {"name": "bells", "phrase": "eerie bell melody"}, {"name": "piano", "phrase": "minor piano loop"},
           {"name": "flute", "phrase": "haunting flute loop"}]},
         {"name": "voice", "default": "male", "known": [{"name": "male"}, {"name": "female"}]}],
       "defaults": {"bpm": 140, "time_signature": 4, "duration": 90, "instrumental": false, "language": "en"},
       "lyrics_hint": "[hook] 4 lines, [verse] 8 lines, [hook]"},

      {"name": "r-and-b", "title": "R&B", "category": "r-and-b",
       "caption": "contemporary R&B, silky {voice}, smooth chords, soft trap-influenced drums, warm bass, intimate late-night mood",
       "slots": [{"name": "voice", "default": "female", "known": [
         {"name": "female", "phrase": "female vocal with lush harmonies"}, {"name": "male", "phrase": "male falsetto vocal"}]}],
       "defaults": {"bpm": 95, "time_signature": 4, "duration": 120, "instrumental": false, "language": "en"},
       "lyrics_hint": "[verse] 4 lines, [chorus] 4 lines, [verse], [chorus], [bridge]"},

      {"name": "neo-soul", "title": "Neo soul", "category": "r-and-b",
       "caption": "neo soul, behind-the-beat drums, warm electric bass, rich extended chords on {keys}, soulful {voice}",
       "slots": [
         {"name": "keys", "default": "rhodes", "known": [{"name": "rhodes"}, {"name": "organ"}, {"name": "guitar", "phrase": "clean jazz guitar"}]},
         {"name": "voice", "default": "female", "known": [{"name": "female", "phrase": "female vocal"}, {"name": "male", "phrase": "male vocal"}]}],
       "defaults": {"bpm": 88, "time_signature": 4, "duration": 120, "instrumental": false, "language": "en"},
       "lyrics_hint": "[verse] 4 lines, [chorus] 4 lines, [verse], [chorus]"},

      {"name": "funk", "title": "Funk", "category": "r-and-b",
       "caption": "funk, tight syncopated drums, slap bass, choppy rhythm guitar, {horns}, irresistible groove",
       "slots": [{"name": "horns", "default": "horn section", "known": [
         {"name": "horn section", "phrase": "punchy brass stabs"}, {"name": "clavinet", "phrase": "clavinet riffs"},
         {"name": "synth", "phrase": "squelchy synth bass lead"}]}],
       "defaults": {"bpm": 108, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "disco", "title": "Disco", "category": "dance",
       "caption": "disco, four-on-the-floor kick with open hi-hats, octave bassline, lush string runs, {extra}, glittering dance floor",
       "slots": [{"name": "extra", "default": "guitar", "known": [
         {"name": "guitar", "phrase": "funky muted guitar"}, {"name": "vocals", "phrase": "joyful diva vocals"},
         {"name": "synth", "phrase": "space-age synth arpeggios"}]}],
       "defaults": {"bpm": 120, "time_signature": 4, "duration": 120, "instrumental": true}}
    ]
    """#
}
