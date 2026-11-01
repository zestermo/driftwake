#!/usr/bin/env python3
"""
The volcanic isle's music (docs/volcanic_island_plan.md "Sound"), on gen_psx_music.py's sequencer and mixdown (its
Song, instruments, helpers and build(); integer bars, circular effects, levelled to -18 LU), its own table so the
shared generator's tracks stay as they are:

    volcanic          the wilds: 4/4, 72 bpm, D Phrygian - taiko under a dark horn, low strings and choir, timpani
    volcanic_night    the same form hushed: ney and harp over the drone, the horn far off, no drums
    volcanic_town     the forge town: 4/4, 100 bpm, A minor - a work song on the fiddle, the anvil on two and four
    volcanic_town_night  the same form by the forges' glow: guitar and flute, a soft frame drum

    py tools/texture_gen/gen_volcanic_music.py                    # all four
    py tools/texture_gen/gen_volcanic_music.py volcanic_town       # just these
"""
from __future__ import annotations

import sys

from gen_psx_music import (Song, nn, split_chords, _bars, _roots, _chordpads, arpeggio, bassline, _timp, _roll, build,
                           _cache)

# The wilds' tunes (D Phrygian: D Eb F G A Bb C), sixteenth ticks, 16 a bar.
VOL_A = ("D4/8 F4/4 G4/4 | A4/8 Bb4/4 A4/4 | G4/6 F4/2 Eb4/4 F4/4 | D4/16 | "
         "A4/8 C5/4 Bb4/4 | A4/6 G4/2 F4/8 | G4/4 F4/4 Eb4/4 F4/4 | D4/16")
VOL_B = ("A4/12 Bb4/4 | C5/8 Bb4/8 | A4/4 G4/4 F4/4 G4/4 | A4/16 | "
         "D5/12 C5/4 | Bb4/8 A4/8 | G4/4 A4/4 Bb4/4 G4/4 | A4/16")
VOL_TURN = "Eb4/8 D4/8 | F4/4 Eb4/4 D4/8 | Eb4/8 F4/8 | D4/16"

# The forge town's work song (A minor).
TOWN_A = ("A4/4 C5/4 E5/4 C5/4 | D5/4 C5/4 B4/8 | A4/4 C5/4 E5/4 A5/4 | G5/8 E5/8 | "
          "F5/4 E5/4 D5/4 C5/4 | B4/4 C5/4 D5/8 | E5/4 D5/4 C5/4 B4/4 | A4/16")
TOWN_B = ("E5/8 G5/8 | A5/4 G5/4 E5/8 | D5/8 F5/8 | E5/16 | "
          "C5/8 E5/8 | D5/4 C5/4 B4/8 | C5/4 B4/4 A4/4 G#4/4 | A4/16")
TOWN_TURN = "E5/4 D5/4 C5/4 B4/4 | A4/8 E4/8 | F4/4 G4/4 G#4/4 B4/4 | A4/16"


def track_volcanic(night=False):
    # 32 bars: intro (the drone, taiko gathering) | A the horn | B strings and choir climb | A' horn and strings | turn.
    s = Song("music_volcanic_night" if night else "music_volcanic", 60 / 72 / 4, 16, 32,
             "4/4, 72 bpm, D Phrygian: " + ("the volcano at night" if night else "the volcano"))
    s.bus("lead", 0.46, verb=0.38)
    s.bus("lead2", 0.3, verb=0.38)
    s.bus("choir", 0.26, verb=0.45)
    s.bus("str", 0.28, verb=0.4)
    s.bus("low", 0.44, verb=0.22)
    s.bus("harp", 0.32, verb=0.34)
    s.bus("taiko", 0.36, verb=0.22)
    s.bus("timp", 0.3, verb=0.25)
    intro = ["Dm", "Dm", "Eb", "Dm"]
    A = ["Dm", "Bb", "Gm", "Dm", "F", "C", "Eb", "Dm"]
    B = ["Bb", "F", "Gm", "A", "Bb", "Gm", "Eb", "A"]
    turn = ["Eb", "Dm", "Eb", "Dm"]
    ch = split_chords(intro + A + B + A + turn)
    I, A1, B1, A2, TN = 0, 4, 12, 20, 28
    allb = range(32)
    _roots(s, "low", "lowstr", ch, allb, nn("D2"), 0.45 if night else 0.58)
    if not night:
        s.drums("taiko", "taiko", "X.......x...x...", list(_bars(I + 2, 2)) + list(_bars(A1, 24)), midi=nn("D2"), vel=0.7)
        _timp(s, "timp", ch, list(_bars(B1, 8)), [(0, 0.5), (8, 0.35)], "D2", "A2")
        for b in (I + 3, B1 + 7, A2 + 7):
            _roll(s, "timp", ch, b, 8, 8, 1, "D2", "A2", v0=0.2, dv=0.05)
        _chordpads(s, "choir", "choir", ch, list(_bars(B1, 8)) + list(_bars(A2, 8)), 57, 0.32)
        _chordpads(s, "str", "strings", ch, list(_bars(A1, 8)) + list(_bars(TN, 4)), 50, 0.28)
        s.line("lead", "horn", VOL_A, A1, vel=0.85)
        s.line("lead", "strings", VOL_B, B1, vel=0.75)
        s.line("lead2", "choir", VOL_B, B1, vel=0.35, transpose=-12)
        s.line("lead", "horn", VOL_A, A2, vel=0.9)
        s.line("lead2", "strings", VOL_A, A2, vel=0.45, transpose=12)
        s.line("lead", "horn", VOL_TURN, TN, vel=0.7)
    else:
        arpeggio(s, "harp", "harp_dark", ch, allb, [0, 2, 1, 2], 4, low=50, vel=0.38, dur=8)
        _chordpads(s, "str", "strings", ch, allb, 50, 0.2)
        s.line("lead", "ney", VOL_A, A1, vel=0.6, transpose=12)
        s.line("lead2", "horn", VOL_B, B1, vel=0.35)
        s.line("lead", "ney", VOL_A, A2, vel=0.55, transpose=12)
        s.line("lead", "ney", VOL_TURN, TN, vel=0.45, transpose=12)
    return s, dict(verb_t60=2.6 if night else 2.0, target_lu=-18.0)


def track_volcanic_town(night=False):
    # 32 bars: intro (bass and the anvil) | A the work song on the fiddle | A' accordion takes it, the fiddle above |
    # B the chorus on brass | turn.
    s = Song("music_volcanic_town_night" if night else "music_volcanic_town", 60 / 100 / 4, 16, 32,
             "4/4, 100 bpm, A minor: " + ("the forge town at night" if night else "the forge town"))
    s.bus("lead", 0.46, verb=0.28)
    s.bus("lead2", 0.32, verb=0.28)
    s.bus("comp", 0.3, verb=0.2)
    s.bus("bass", 0.42, verb=0.12)
    s.bus("anvil", 0.26, verb=0.3)
    s.bus("kick", 0.34, verb=0.1)
    s.bus("frame", 0.24, verb=0.15)
    intro = ["Am", "Am", "Dm", "E"]
    A = ["Am", "Dm", "Am", "Em", "F", "G", "Am E", "Am"]
    B = ["C", "F", "Dm", "Em", "Am", "Dm", "F E", "Am"]
    turn = ["Am", "Am", "F", "E"]
    ch = split_chords(intro + A + A + B + turn)
    I, A1, A2, B1, TN = 0, 4, 12, 20, 28
    allb = range(32)
    if not night:
        bassline(s, "bass", "bass", ch, allb, [(0, 4, "R"), (6, 2, "5"), (8, 4, "R"), (12, 4, "5")], octave_low=nn("A1"), vel=0.85)
        s.drums("kick", "kick", "X.......X.......", allb, vel=0.7)
        s.drums("anvil", "clave", "....X.......X...", allb, midi=nn("E5"), vel=0.8)
        arpeggio(s, "comp", "accordion", ch, list(_bars(A1, 8)) + list(_bars(B1, 8)), [0, 1, 2, 1], 4, low=55, vel=0.35, dur=4)
        s.line("lead", "fiddle", TOWN_A, A1, vel=0.85)
        s.line("lead", "accordion", TOWN_A, A2, vel=0.8)
        s.line("lead2", "fiddle", TOWN_A, A2, vel=0.45, transpose=12)
        s.line("lead", "brass", TOWN_B, B1, vel=0.85)
        s.line("lead2", "fiddle", TOWN_B, B1, vel=0.4)
        s.line("lead", "fiddle", TOWN_TURN, TN, vel=0.75)
    else:
        bassline(s, "bass", "bass", ch, allb, [(0, 8, "R"), (8, 8, "5")], octave_low=nn("A1"), vel=0.6)
        s.drums("frame", "frame", "X.......x.......", list(_bars(A1, 24)), midi=nn("A2"), vel=0.45)
        arpeggio(s, "comp", "guitar", ch, allb, [0, 1, 2, 1, 2, 1, 0, 1], 2, low=52, vel=0.4, dur=2)
        s.line("lead", "flute", TOWN_A, A1, vel=0.6)
        s.line("lead", "flute", TOWN_A, A2, vel=0.55)
        s.line("lead2", "guitar", TOWN_B, B1, vel=0.5)
        s.line("lead", "flute", TOWN_B, B1, vel=0.45, transpose=12)
        s.line("lead", "flute", TOWN_TURN, TN, vel=0.5)
    return s, dict(verb_t60=2.0 if night else 1.4, target_lu=-18.0)


TABLE = {"volcanic": track_volcanic, "volcanic_night": lambda: track_volcanic(True),
         "volcanic_town": track_volcanic_town, "volcanic_town_night": lambda: track_volcanic_town(True)}


def main():
    for k in sys.argv[1:] or list(TABLE):
        _cache.clear()
        build(k, TABLE)


if __name__ == "__main__":
    sys.exit(main())
