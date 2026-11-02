#!/usr/bin/env python3
"""
The coral atoll's music (docs/v1_28_plan.md "Islands"), on gen_psx_music.py's sequencer and mixdown (its Song,
instruments, helpers and build(); integer bars, circular effects, levelled to -18 LU), its own table so the shared
generator's tracks stay as they are:

    atoll              the islets and the lagoon: 4/4, 88 bpm, G mixolydian - marimba rippling under a steel-drum
                       tune, congas and a shaker, the ocarina answering, a warm string pad
    atoll_night        the same form under the stars: harp and marimba soft, the ocarina far off, no drums
    atoll_town         the stilt town: 4/4, 108 bpm, C major - a strummed guitar, the tune on steel drum and tin
                       whistle, clave and conga, a walking bass
    atoll_town_night   the same form by lamplight on the boardwalk: guitar and flute, a soft shaker

    py tools/texture_gen/gen_atoll_music.py                 # all four
    py tools/texture_gen/gen_atoll_music.py atoll_town      # just these
"""
from __future__ import annotations

import sys

from gen_psx_music import (Song, nn, split_chords, _bars, _roots, _chordpads, arpeggio, bassline, build, _cache)

# The lagoon's tune (G mixolydian: G A B C D E F), sixteenth ticks, 16 a bar.
LAG_A = ("D5/4 B4/4 G4/4 A4/4 | B4/8 D5/8 | E5/4 D5/4 B4/4 A4/4 | G4/16 | "
         "F5/4 E5/4 D5/4 B4/4 | C5/8 A4/8 | B4/4 A4/4 G4/4 A4/4 | B4/16")
LAG_B = ("G5/8 F5/4 E5/4 | D5/12 B4/4 | C5/4 D5/4 E5/4 D5/4 | B4/16 | "
         "G5/8 F5/8 | E5/4 D5/4 C5/8 | B4/4 A4/4 F4/4 A4/4 | G4/16")
LAG_TURN = "D5/8 C5/8 | B4/4 A4/4 G4/8 | F4/8 A4/8 | G4/16"

# The stilt town's dance (C major).
TOWN_A = ("E5/4 G5/4 E5/4 C5/4 | D5/4 E5/4 D5/8 | C5/4 E5/4 G5/4 A5/4 | G5/16 | "
          "A5/4 G5/4 E5/4 C5/4 | D5/4 C5/4 A4/8 | G4/4 A4/4 C5/4 D5/4 | C5/16")
TOWN_B = ("F5/8 A5/8 | G5/4 F5/4 E5/8 | D5/8 F5/8 | E5/16 | "
          "C5/8 E5/8 | D5/4 C5/4 B4/8 | C5/4 D5/4 E5/4 B4/4 | C5/16")
TOWN_TURN = "G5/4 F5/4 E5/4 D5/4 | C5/8 G4/8 | A4/4 B4/4 D5/4 B4/4 | C5/16"


def track_atoll(night=False):
    # 32 bars: intro (marimba and the drone of the reef) | A the steel drum | B ocarina and strings | A' steel and
    # ocarina together | turn.
    s = Song("music_atoll_night" if night else "music_atoll", 60 / 88 / 4, 16, 32,
             "4/4, 88 bpm, G mixolydian: " + ("the lagoon at night" if night else "the lagoon"))
    s.bus("lead", 0.44, verb=0.32)
    s.bus("lead2", 0.3, verb=0.34)
    s.bus("mar", 0.32, verb=0.26)
    s.bus("str", 0.24, verb=0.4)
    s.bus("low", 0.38, verb=0.18)
    s.bus("conga", 0.3, verb=0.16)
    s.bus("shake", 0.18, verb=0.12)
    s.bus("harp", 0.3, verb=0.34)
    intro = ["G", "G", "C", "D"]
    A = ["G", "Em", "C", "D", "F", "C", "G D", "G"]
    B = ["C", "G", "Am", "Em", "F", "C", "D", "G"]
    turn = ["G", "F", "C", "G"]
    ch = split_chords(intro + A + B + A + turn)
    I, A1, B1, A2, TN = 0, 4, 12, 20, 28
    allb = range(32)
    _roots(s, "low", "bass", ch, allb, nn("G1"), 0.42 if night else 0.55)
    if not night:
        arpeggio(s, "mar", "marimba", ch, allb, [0, 1, 2, 1, 2, 1, 0, 2], 2, low=55, vel=0.42, dur=2)
        s.drums("conga", "conga", "X..x..X...x.x...", list(_bars(I + 2, 2)) + list(_bars(A1, 24)), midi=nn("C3"), vel=0.6)
        s.drums("shake", "shaker", "x.x.x.x.x.x.x.x.", list(_bars(A1, 24)), vel=0.4)
        _chordpads(s, "str", "strings", ch, list(_bars(B1, 8)) + list(_bars(TN, 4)), 55, 0.24)
        s.line("lead", "steel", LAG_A, A1, vel=0.85)
        s.line("lead", "ocarina", LAG_B, B1, vel=0.75)
        s.line("lead", "steel", LAG_A, A2, vel=0.85)
        s.line("lead2", "ocarina", LAG_A, A2, vel=0.4, transpose=-12)
        s.line("lead", "steel", LAG_TURN, TN, vel=0.7)
    else:
        arpeggio(s, "harp", "harp", ch, allb, [0, 2, 1, 2], 4, low=52, vel=0.36, dur=8)
        arpeggio(s, "mar", "marimba", ch, list(_bars(A1, 24)), [0, 2], 8, low=55, vel=0.22, dur=4)
        _chordpads(s, "str", "strings", ch, allb, 55, 0.18)
        s.line("lead", "ocarina", LAG_A, A1, vel=0.55)
        s.line("lead2", "steel", LAG_B, B1, vel=0.35)
        s.line("lead", "ocarina", LAG_A, A2, vel=0.5)
        s.line("lead", "ocarina", LAG_TURN, TN, vel=0.42)
    return s, dict(verb_t60=2.4 if night else 1.8, target_lu=-18.0)


def track_atoll_town(night=False):
    # 32 bars: intro (guitar and bass) | A the dance on steel drum | A' the tin whistle takes it, the steel above |
    # B the chorus, both | turn.
    s = Song("music_atoll_town_night" if night else "music_atoll_town", 60 / 108 / 4, 16, 32,
             "4/4, 108 bpm, C major: " + ("the stilt town at night" if night else "the stilt town"))
    s.bus("lead", 0.44, verb=0.26)
    s.bus("lead2", 0.3, verb=0.26)
    s.bus("comp", 0.32, verb=0.18)
    s.bus("bass", 0.4, verb=0.1)
    s.bus("clave", 0.22, verb=0.2)
    s.bus("conga", 0.28, verb=0.14)
    s.bus("shake", 0.18, verb=0.1)
    intro = ["C", "C", "F", "G"]
    A = ["C", "Am", "F", "G", "C", "F", "G7", "C"]
    B = ["F", "C", "Dm", "Em", "F", "C", "G", "C"]
    turn = ["C", "Am", "F", "G"]
    ch = split_chords(intro + A + A + B + turn)
    I, A1, A2, B1, TN = 0, 4, 12, 20, 28
    allb = range(32)
    if not night:
        bassline(s, "bass", "bass", ch, allb, [(0, 4, "R"), (6, 2, "5"), (8, 4, "R"), (12, 4, "5")], octave_low=nn("C2"), vel=0.8)
        arpeggio(s, "comp", "guitar", ch, allb, [0, 1, 2, 1, 2, 1, 0, 1], 2, low=52, vel=0.42, dur=2)
        s.drums("clave", "clave", "X..X..X...X.X...", list(_bars(A1, 24)), midi=nn("E5"), vel=0.6)
        s.drums("conga", "conga", "..x...X...x...X.", allb, midi=nn("C3"), vel=0.55)
        s.drums("shake", "shaker", "x.x.x.x.x.x.x.x.", list(_bars(A1, 24)), vel=0.35)
        s.line("lead", "steel", TOWN_A, A1, vel=0.85)
        s.line("lead", "whistle", TOWN_A, A2, vel=0.75)
        s.line("lead2", "steel", TOWN_A, A2, vel=0.4, transpose=-12)
        s.line("lead", "steel", TOWN_B, B1, vel=0.85)
        s.line("lead2", "whistle", TOWN_B, B1, vel=0.4)
        s.line("lead", "steel", TOWN_TURN, TN, vel=0.75)
    else:
        bassline(s, "bass", "bass", ch, allb, [(0, 8, "R"), (8, 8, "5")], octave_low=nn("C2"), vel=0.55)
        arpeggio(s, "comp", "guitar", ch, allb, [0, 1, 2, 1, 2, 1, 0, 1], 2, low=52, vel=0.36, dur=2)
        s.drums("shake", "shaker", "x...x...x...x...", list(_bars(A1, 24)), vel=0.3)
        s.line("lead", "flute", TOWN_A, A1, vel=0.6)
        s.line("lead", "flute", TOWN_A, A2, vel=0.55)
        s.line("lead2", "steel", TOWN_B, B1, vel=0.4)
        s.line("lead", "flute", TOWN_B, B1, vel=0.45, transpose=12)
        s.line("lead", "flute", TOWN_TURN, TN, vel=0.5)
    return s, dict(verb_t60=1.9 if night else 1.4, target_lu=-18.0)


TABLE = {"atoll": track_atoll, "atoll_night": lambda: track_atoll(True),
         "atoll_town": track_atoll_town, "atoll_town_night": lambda: track_atoll_town(True)}


def main():
    for k in sys.argv[1:] or list(TABLE):
        _cache.clear()
        build(k, TABLE)


if __name__ == "__main__":
    sys.exit(main())
