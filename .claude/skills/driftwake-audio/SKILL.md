---
name: driftwake-audio
description: >
  Make Driftwake's music, ambience beds and sound effects, all generated in Python under
  tools/texture_gen/: the music sequencer (gen_psx_music.py: Song, the instrument set, scales and
  drones, integer bars, the THEME_A quote, day/night variants with the same form, -18 LU levelling,
  circular effects for seamless loops, TRACKS, style samples, jam stems), the SFX generator
  (gen_psx_audio.py: loops via _write_loop at -20, one-shots and takes, footsteps by surface, the
  helpers), measuring with audio_report.py (loudness, peaks, repeat score, seams), and wiring them
  into the game (Music.TRACKS and its place logic, KitStyle "music"/"music_town"/"ambience",
  Ambience.LOOPS/TOP_DB, Weather's rain-style beds, FX.SOUNDS, footsteps, imports). Use when Zach
  asks for a new track, a theme's town or wilds music, a night arrangement, an ambience or weather
  bed (sandstorm, blizzard), footsteps for a surface, a new sound effect or takes, or says a sound
  is too loud, harsh, clicks at the loop, repeats audibly or "doesn't fit the island".
---

# Driftwake audio

Every sound is code: Python generators write `assets/audio/` (22.05 kHz mono, PS1 crunch). Music
is `.ogg` (Vorbis q3), everything else `.wav` (QOA-compressed at import). Nothing is hand-made or
downloaded. Creature voices are in `gen_beast_audio.py` (same helpers and levelling as the SFX).

**Read first:** grep `docs/dev_notes.md` for the sound or system ("desert and snow music, beds and
footsteps", "v1.12 music", "audio pass") and `docs/audio_audit.md` for its row.

## Python (CLAUDE.md's rules)

- Run with the `py` launcher from the repo root: `py tools/texture_gen/gen_psx_music.py desert`.
  `python` may hit the Microsoft Store stub. (The SFX script's docstring still says `python`/`pip`: use `py`.)
- Needs numpy, scipy (requirements.txt) and `ffmpeg` on PATH for .ogg. **Never install anything:**
  if `py`, a module or ffmpeg is missing, tell Zach. Without ffmpeg a track stays `.wav`; never commit
  that in place of an .ogg (Music loads `.ogg` paths), and audio_report can't decode the .ogg files.
- Everything is seeded: the same code renders the same file. Use `seeded(...)` / a fixed
  `np.random.default_rng(n)`, never an unseeded rng.

## Music: gen_psx_music.py

- **Song(name, tick_sec, ticks_per_bar, bars, info)**: `tick_sec = 60 / bpm / 4` for sixteenth ticks
  (tpb 16 in 4/4), `/ 2` for eighths. `s.bus(name, gain, verb, echo, lp, hp)` per voice, then events:
  `s.line(bus, inst, text, bar, vel, transpose=, harmonize=(scale_pcs, steps))`, `s.note(...)`,
  `s.drums(bus, inst, "X..x....", bars, midi=)` (X accent, x normal, o ghost, . rest; one char per
  tick fraction). Accompaniment: `bassline`, `comp`, `arpeggio`, `_chordpads`, `_roots`, `_timp`,
  `_roll`, `_twinkle` (night stars), `_gallop`.
- **Notation:** `"D5/3 A4/1 -/2 ~/2"` (note/ticks, `-` rest, `~` tie). Mark bars with ` | `:
  `Song.line` raises if a bar doesn't add up to tpb. Always mark them.
- **Chords:** a list, one entry per bar (`"Fm G"` splits a bar); `split_chords(...)`. Qualities:
  "", m, 7, m7, dim, sus4, 5, maj7. **Scales:** `scale(root, mode)`: major, minor, dorian, mixolydian,
  phrygian, harmonic, hijaz.
- **Instruments** (`INSTRUMENTS`): flute, fiddle, accordion, concertina, pluck, guitar, bass, lowstr,
  stacc, brass, timpani, kick, frame, snare, tom, conga, hat, shaker, crash, marimba, horn, harp,
  harp_dark, pizz, strings, oboe, choir, taiko, glock, swell, ocarina, steel, bassoon, tamb, clave,
  celesta, swellstr, whistle, gurdy, trompette, bodhran, bodhran_rim; and for the desert and snow:
  **ney** (breathy end-blown flute), **mizmar** (nasal double reed), **oud** (two detuned KS courses),
  **dum** / **tek** (darbuka low and rim), **zill** (finger cymbals), **sleigh** (sleigh bells).
  A new voice is `inst_x(m, n)` returning a numpy buffer (n = gate samples; add a release tail),
  partials capped at `NYQ_LIMIT`, deterministic (`render_note` caches by (inst, midi, gate)).
  Add it to `INSTRUMENTS` and a line in the dated dev-notes section.
- **Drones:** `build()` option `drone=["G2", "D3"]` (+ `drone_hump`, `drone_tilt`; the desert's is 650,
  1.15, darker than the jam gurdy's 1500, 0.75) adds `drone_layer` to the track's `"drone"` bus. Its
  pitches are rounded to whole cycles over the loop so it's seamless. `wind=True` does the same for
  `wind_layer` (the sea's), with an integer number of swells.
- **Rules every calm track follows:**
  1. **Integer bars.** The file is exactly `bars x bar` long; Music uses the bar count for bar-line
     changes and resumes. 2-3 minutes in a real form (intro, A, A', B, T, ..., a turn back to bar 1).
  2. **Quote THEME_A once**, rewritten in the track's mode and metre (EX_C in D minor, VIL_THEME in C,
     THEME_68 re-barred for 6/8, DES_THEME / DT_THEME in Hijaz, SNOW_THEME in 3/4, SNT_THEME in Bb).
  3. **Day and night are one function** `track_x(night=False)`: same Song (tempo, tpb, bars), same
     chords and melodies, the night arranged sparser (lone lead, strings and harp, celesta stars,
     drums thinned or gone). Music crossfades between them at the same playback position.
  4. **-18 LU:** return `dict(..., target_lu=-18.0)`; `mixdown` levels with audio_report's measure.
     Fights are RMS-levelled (combat -18.3, boss -18.2); the victory sting isn't looped (`tail_sec`).
  5. **Seamless:** `Song.render` folds note tails past the end back onto bar 1, and every effect after
     (reverb, echo, bus EQ, the 38 Hz / 8 kHz master filters) is circular in the frequency domain,
     so the loop is its own steady state. Don't add a non-circular step to a looping mix.
- Return `s, dict(verb_t60=, echo_sec=60 / bpm * 0.75, target_lu=-18.0, drone=..., wind=...)` and add
  the keys to **TRACKS** (`"desert": track_desert, "desert_night": lambda: track_desert(True)`).
- **Render:** `py tools/texture_gen/gen_psx_music.py desert desert_night` (no args: every track;
  that rewrites all of them, so name yours). It prints length = bars x bar, peak, RMS, LU and the seam.
- **Samples to listen to:** `py tools/texture_gen/gen_psx_music.py samples [corsair storm ...]`
  renders the style samples (`SAMPLES`) into `tools/dev/out/music_samples/` (gitignored), never into
  assets. For a candidate that isn't ready to replace a game track, add it to `SAMPLES` (or call
  `build(key, TRACKS, SAMPLE_OUT)`) so it lands there, and tell Zach the file names to play.
- **Jam stems:** `py tools/texture_gen/gen_psx_music.py jam [lass haul bell rum]` writes
  `assets/audio/jam/<tune>_<instrument>.ogg` for concertina, fiddle, whistle, bodhran, gurdy. Every
  stem of a tune has the same tempo, bars and length (any mix is one band, played off one clock by
  `scripts/items/jam.gd`); stems at -20 LU (bodhran -22). A tune is a `JAM_TUNES` entry; its
  `[id, title, beats in a bar, bars, sub-beats]` row in `Instruments.TUNES`
  (`scripts/items/instruments.gd`) must match.

## SFX and beds: gen_psx_audio.py

- `py tools/texture_gen/gen_psx_audio.py desert_loop step_snow` renders the named `SOUNDS` entries
  (no args: all). A new sound is a function plus a `("name", fn)` line in `SOUNDS`.
- **Loops (beds):** build the whole loop circularly: `_cband(n, rng, lo, hi, tilt)` (band noise that
  loops), `_shape(n, rng, gain_fn)`, `_cenv(n, rng, rate)` (a looping 0..1 gust/surge curve), events
  dropped in with `_place(buf, ev, at)` (wraps round the end). Filter an event however you like
  before placing it; never run a plain IIR filter over the finished loop. Finish with
  `_write_loop(name, out)` (-20 LUFS integrated; measures -20.2 because write_wav scales by 32000).
  Long, odd lengths (beds are 40-60 s; the hull's 37/23/29 s never line up) and uneven event gaps
  keep the repeat score low. Name it `*_loop` (audio_report treats only those, and `music_*`, as loops).
- **One-shots and takes:** `_write_shot(name, out, lufs, fade)` (loudest 400 ms). Takes are
  `name_1.wav .. name_N.wav` (`[fn(f"x_{k + 1}") ...]` or a `*_takes()` function); FX finds them and
  plays them at random, never the same twice running. Levels to copy: steps -19 to -22, whooshes -17,
  hits/slices -15 to -13.5, UI -18 to -20, birds -20.
- **Footsteps:** `STEP_SURFACES` (sand, grass, dirt, stone, wood, water, snow, ice), `STEP_LUFS` per
  surface, `_step_contact(surface, ...)` designs one contact; `step_takes` writes 4 takes
  `step_<surface>_1..4` (heel, then the roll onto the toe 45-75 ms later). Each take's seed is
  `1500 + 37 x index + k`: **append** new surfaces, or every later surface's takes change.
- **Helpers:** `_thump` (falling-sine knock), `_modes` (struck resonances), `_grains` (crunch, rustle,
  patter), `_noise` / `_filt` / `_hp` / `_lp` (one-shot filtering, zero-padded), `_churn` (slosh
  flutter), `_stick_slip` (creaks, ice groans), `_scatter_bursts` (drips, shards), `_far_cry`,
  `_wolf_howl`, `_delay`, `_level`, `_fade_out`.

## Measuring: audio_report.py

`py tools/texture_gen/audio_report.py desert_ music_snow step_` (substrings; no args: everything).
Per file: secs, peak and RMS dBFS, crest, LU (integrated for loops, loudest 400 ms for one-shots),
spectral centroid, the share per band (2-5 kHz is where noise turns harsh: beds sit at 1-6%), the
sharpest resonance, CLIP and DC. Loops also get:
- **seam** `jump x level`: the last-to-first sample jump against a median step (music 0.3-3x is
  fine) and the level change across it. A big +dB on a track whose turn ends on a rest is bar 1's
  downbeat, not a click (music_island shows +18.8); listen across the join before "fixing" it.
- **repeat** `score@lag`: the strongest self-similarity of the loudness envelope inside the loop.
  Beds sit at 0.17-0.24; a high score at a short lag is audibly periodic (the old sea loop: 0.70 at 6 s).

## Wiring in game

- **Music** (`scripts/game/music.gd`): `TRACKS = {"desert": ["res://assets/audio/music_desert.ogg", 48]}`,
  the bar count equal to the generator's (`bar_len` = length / bars). Contexts: title, village,
  island, sea, combat, boss. In a village (`Music.in_village`: Brinehollow's square and harbour front,
  a chain island's plaza, hamlets, buildings) it plays the zone's KitStyle `"music_town"`; ashore in
  the wilds its `"music"` (defaults "village" / "island" in `kit_style.gd`; a theme sets its own in
  `scripts/island/themes/<theme>_theme.gd`, e.g. desert: "desert", "desert_town"). `<track>_night`
  is found by name and plays from DUSK 19:00 to DAWN 5:30 (6 s crossfade in step). Calm changes wait
  for a bar line; fights cut in. Music sets `stream.loop = true` itself.
- **Ambience** (`scripts/world/ambience.gd`): `LOOPS` key -> file stem, `TOP_DB` its level at full
  strength (jungle -13, desert -13, snow -13.5, wind -12.5). A theme's bed is its KitStyle
  `"ambience"` (an LOOPS key, "" none), strongest ashore and fading out to sea. Its own loop player
  sets `LOOP_FORWARD` with `loop_end` in frames (QOA: the byte count says nothing).
- **Weather** (`scripts/world/weather.gd`): `rain_loop` is played by `_loop_player` and
  `_update_audio` at -6 dB x rain x (1 - shelter / 2). `sandstorm_loop` / `blizzard_loop` (made
  10-15, -20.2 LU like rain) are meant for the same place on desert and snow islands; check
  whether the weather pass has wired them before adding a second path. Thunder: `FX_sfx`.
- **FX** (`scripts/game/fx.gd`): add the base name to `SOUNDS` (takes found as `_1.._N`); play with
  `FX.sfx(name, pos, volume_db, pitch_jitter)`, or `Net.fx("sfx", [...])` when every screen should
  hear it (driftwake-coop).
- **Footsteps:** `Player._on_footstep` plays `"step_" + ground_surface()`; `ground_surface()` is
  "water" when wading, else `Footsteps.surface_under` (`scripts/game/footsteps.gd`: terrain splat and
  height rules, mesh texture names, or a collider's `surface` meta). A new surface needs its
  `step_<s>` in FX.SOUNDS and a way for Footsteps to return it (`step_snow` / `step_ice` were made
  10-15 for the snow theme; check FX.SOUNDS before assuming they're wired).
- **Imports:** a new file needs an `.import` (open the editor or `& $env:GODOT --headless --import`);
  commit it with the asset. Keep the defaults: `.ogg` `loop=false`, `.wav` `loop_mode` detect (no loop
  chunk = off), `compress/mode=2`. The code loops tracks and beds; only `campfire_loop` (a 3D player)
  loops at import.

## Checking a change

1. Render, then `audio_report.py <name>`: LU on target, no CLIP, peak under -1 dBFS (`_level`'s ceiling;
   music lands at -2 to -4), seam and repeat in range, 2-5 kHz share not harsh. Report sizes (a track is ~0.7-0.8 MB).
2. Give Zach something to hear: the WAV/OGG paths (samples in `tools/dev/out/music_samples/`, game
   files in `assets/audio/`) and where to stand in game (which island theme, village or wilds, F7
   to reach night, F6 for weather).
3. Tests cover the wiring, not the sound (they don't run the generators). Through the runner only:
   `run_tests.ps1 musictest` (Music by place and time, KitStyle `music_town`), `ambiencetest`
   (surf, hull, wind, storm, underwater, rock and beach surf), `t/jam` (jam stems and the shared
   clock). An asset-only change runs none; a .gd change runs the ones it touches (driftwake-test).
4. Update `docs/audio_audit.md`: its row in Ambience loops / Footsteps / One-shots / Music (length,
   key and tempo, LU, design, where it's played) and the Gaps list ("not wired yet" goes once it is).
   Add a dated `docs/dev_notes.md` section: what, the numbers audio_report gave, how to render it.
