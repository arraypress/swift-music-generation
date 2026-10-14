//
//  StyleText+Bands.swift
//  MusicGeneration
//
//  Created by David Sherlock on 2026.
//
//  Rock, metal, blues, jazz, folk and country styles. Every caption was
//  written for this library.
//

extension StyleText {

    static let bands = #"""
    [
      {"name": "rock", "title": "Rock", "category": "rock",
       "caption": "rock song, driving drums, crunchy distorted guitars, solid bass, {voice}, anthemic chorus",
       "slots": [{"name": "voice", "default": "male", "known": [
         {"name": "male", "phrase": "gritty male vocal"}, {"name": "female", "phrase": "powerful female vocal"},
         {"name": "none", "phrase": "instrumental guitar melody"}]}],
       "defaults": {"bpm": 120, "time_signature": 4, "duration": 120, "instrumental": false, "language": "en"},
       "lyrics_hint": "[verse] 4 lines, [chorus] 4 lines, [verse], [chorus], [guitar solo], [chorus]"},

      {"name": "indie-rock", "title": "Indie rock", "category": "rock",
       "caption": "indie rock, energetic drums, angular guitar riffs, melodic bass, {voice}, raw garage production",
       "slots": [{"name": "voice", "default": "male", "known": [
         {"name": "male", "phrase": "earnest male vocal"}, {"name": "female", "phrase": "cool female vocal"}]}],
       "defaults": {"bpm": 128, "time_signature": 4, "duration": 120, "instrumental": false, "language": "en"},
       "lyrics_hint": "[verse] 4 lines, [chorus] 4 lines, [verse], [chorus]"},

      {"name": "punk", "title": "Punk rock", "category": "rock",
       "caption": "fast punk rock, buzzing power chords, frantic drums, {voice}, short and loud",
       "slots": [{"name": "voice", "default": "shouted", "known": [
         {"name": "shouted", "phrase": "shouted gang vocals"}, {"name": "melodic", "phrase": "snotty melodic vocal"}]}],
       "defaults": {"bpm": 170, "time_signature": 4, "duration": 90, "instrumental": false, "language": "en"},
       "lyrics_hint": "[verse] 4 short lines, [chorus] 2–4 shouted lines"},

      {"name": "metal", "title": "Heavy metal", "category": "metal",
       "caption": "heavy metal, double-kick drums, chugging downtuned riffs, {lead}, epic and aggressive",
       "slots": [{"name": "lead", "default": "solo", "known": [
         {"name": "solo", "phrase": "shredding guitar solo"}, {"name": "vocals", "phrase": "soaring clean vocals"},
         {"name": "growl", "phrase": "growled vocals"}]}],
       "defaults": {"bpm": 140, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "blues", "title": "Blues", "category": "blues",
       "caption": "{flavour} blues, shuffling drums, walking bass, expressive bending guitar, {voice}",
       "slots": [
         {"name": "flavour", "default": "electric", "known": [{"name": "electric", "phrase": "electric Chicago"},
           {"name": "delta", "phrase": "acoustic delta"}, {"name": "slow", "phrase": "slow smoky"}]},
         {"name": "voice", "default": "male", "known": [{"name": "male", "phrase": "weathered male vocal"},
           {"name": "female", "phrase": "big female vocal"}]}],
       "defaults": {"bpm": 80, "time_signature": 4, "duration": 120, "instrumental": false, "language": "en"},
       "lyrics_hint": "Twelve-bar verses: a line, the line again, an answering line"},

      {"name": "jazz", "title": "Jazz", "category": "jazz",
       "caption": "{group} jazz, swinging ride cymbal, walking upright bass, improvised solos, warm room sound",
       "slots": [{"name": "group", "default": "piano trio", "known": [
         {"name": "piano trio", "phrase": "piano trio"}, {"name": "quartet", "phrase": "saxophone quartet"},
         {"name": "big band", "phrase": "big band"}]}],
       "defaults": {"bpm": 140, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "bossa-nova", "title": "Bossa nova", "category": "latin",
       "caption": "bossa nova, gentle nylon guitar comping, soft brushed drums, upright bass, {lead}, breezy and warm",
       "slots": [{"name": "lead", "default": "flute", "known": [
         {"name": "flute", "phrase": "airy flute melody"}, {"name": "vocal", "phrase": "whispery female vocal"},
         {"name": "piano", "phrase": "light piano melody"}]}],
       "defaults": {"bpm": 130, "time_signature": 4, "duration": 120, "instrumental": true}},

      {"name": "folk", "title": "Folk", "category": "folk",
       "caption": "acoustic folk, fingerpicked guitar, {extra}, {voice}, honest and intimate",
       "slots": [
         {"name": "extra", "default": "fiddle", "known": [{"name": "fiddle", "phrase": "soft fiddle lines"},
           {"name": "banjo", "phrase": "light banjo"}, {"name": "harmonica"}]},
         {"name": "voice", "default": "male", "known": [{"name": "male", "phrase": "warm male vocal"},
           {"name": "female", "phrase": "clear female vocal"}]}],
       "defaults": {"bpm": 96, "time_signature": 4, "duration": 120, "instrumental": false, "language": "en"},
       "lyrics_hint": "[verse] 4 storytelling lines, [chorus] 4 lines, [verse], [chorus]"},

      {"name": "country", "title": "Country", "category": "country",
       "caption": "modern country, twangy electric guitar, steel guitar, steady drums, {voice}, warm heartland feel",
       "slots": [{"name": "voice", "default": "male", "known": [{"name": "male", "phrase": "baritone male vocal"},
         {"name": "female", "phrase": "bright female vocal"}]}],
       "defaults": {"bpm": 104, "time_signature": 4, "duration": 120, "instrumental": false, "language": "en"},
       "lyrics_hint": "[verse] 4 lines, [chorus] 4 lines with the title, [verse], [chorus]"}
    ]
    """#
}
