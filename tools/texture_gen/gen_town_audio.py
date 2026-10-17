#!/usr/bin/env python3
"""
Brinehollow's town sounds (BrinehollowLife's TownLife node plays them, positional): the market street's
murmur by day, the Salted Gull's common room at night, Haldor's hammer on the anvil.
Built from gen_psx_audio's helpers, levelled the same way (by loudness).

Usage (from the project root):
    py tools/texture_gen/gen_town_audio.py                 # everything
    py tools/texture_gen/gen_town_audio.py market_murmur   # only the named sounds
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from gen_psx_audio import (OUT, ROOT, SR, _cband, _cenv, _filt, _hp, _lp, _modes, _place, _thump,  # noqa: E402
                           _write_loop, _write_shot, resonate)

# vowel formants (F1, F2, F3) for the babble's syllables
VOWELS = [(730, 1090, 2440), (530, 1840, 2480), (270, 2290, 3010), (570, 840, 2410), (300, 870, 2240),
          (640, 1190, 2390), (490, 1350, 1690)]


def _syllable(rng, f0, dur, vowel, breath=0.25):
    """One voiced syllable: a jittered glottal buzz through a vowel's formants, a soft onset and fall."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    glide = f0 * (1 + rng.uniform(-0.12, 0.1) * t / dur)
    ph = np.cumsum(glide * (1 + 0.01 * rng.standard_normal(n)) / SR)
    src = np.zeros(n)
    for k in range(1, 18):
        src += np.sin(2 * np.pi * k * ph) / k ** 1.1
    src += breath * rng.standard_normal(n)
    f1, f2, f3 = vowel
    y = resonate(src, f1, 6) * 1.0 + resonate(src, f2, 9) * 0.55 + resonate(src, f3, 12) * 0.25
    env = np.sin(np.pi * np.minimum(1, t / dur)) ** 0.8
    return y * env


def _phrase(rng, f0, count, gap=0.03):
    """A run of syllables spoken in one breath, pitch falling a little at the end."""
    parts = []
    for k in range(count):
        dur = rng.uniform(0.07, 0.19)
        fall = 1.0 - 0.15 * (k / max(count - 1, 1)) ** 2
        parts.append(_syllable(rng, f0 * fall * rng.uniform(0.94, 1.08), dur, VOWELS[rng.integers(len(VOWELS))]))
        parts.append(np.zeros(int(SR * rng.uniform(0.0, gap))))
    return np.concatenate(parts)


def _laugh(rng, f0):
    """A short laugh: quick breathy 'ha's, pitch stepping down."""
    parts = []
    for k in range(int(rng.integers(3, 7))):
        parts.append(_syllable(rng, f0 * (1.25 - 0.06 * k), rng.uniform(0.07, 0.11), VOWELS[0], breath=0.9))
        parts.append(np.zeros(int(SR * rng.uniform(0.05, 0.09))))
    return np.concatenate(parts)


def _call(rng, f0):
    """A vendor's call: two short syllables and a long sung vowel, rising then falling."""
    n = int(SR * rng.uniform(0.7, 1.1))
    t = np.arange(n) / SR
    d = n / SR
    glide = f0 * np.interp(t, [0, 0.25 * d, d], [1.0, 1.35, 1.05])
    ph = np.cumsum(glide / SR)
    src = sum(np.sin(2 * np.pi * k * ph) / k for k in range(1, 16)) + 0.2 * rng.standard_normal(n)
    v = VOWELS[rng.integers(len(VOWELS))]
    y = resonate(src, v[0], 7) + 0.6 * resonate(src, v[1], 10) + 0.25 * resonate(src, v[2], 12)
    env = np.minimum(1, t / 0.05) * np.clip((d - t) / 0.3, 0, 1)
    return np.concatenate([_phrase(rng, f0, 2), y * env])


def _clink(rng, hi=True):
    """A coin or a mug knocking: a few bright damped modes."""
    n = int(SR * 0.35)
    t = np.arange(n) / SR
    base = rng.uniform(2200, 3400) if hi else rng.uniform(700, 1100)
    return _modes(t, rng, [(base, 1.0, 40), (base * 2.37, 0.5, 60), (base * 3.9, 0.25, 90)]) * 0.6


def _distance(x, far):
    """Darker and softer the further off a voice is (0 near .. 1 far)."""
    return _filt(x, lambda f: _lp(f, 4200 - 3000 * far) * _hp(f, 140)) * (1.0 - 0.7 * far)


def _babble(rng, n, voices, density, near_share, f0s=(105, 240)):
    """Voices chatting over a loop of n samples: each speaks phrases with pauses between."""
    out = np.zeros(n)
    for v in range(voices):
        f0 = rng.uniform(*f0s)
        far = 0.15 + 0.85 * rng.random() if rng.random() > near_share else rng.uniform(0.0, 0.25)
        at = rng.uniform(0, n)
        while at < n:
            ph = _phrase(rng, f0, int(rng.integers(2, 9)))
            _place(out, _distance(ph, far), at)
            at += len(ph) + SR * rng.exponential(1.0 / density)
    return out


def market_murmur():
    """The market street by day: a crowd's babble near and far, vendors calling, laughs, coins."""
    rng = np.random.default_rng(6101)
    n = int(SR * 47.3)
    bed = _cband(n, rng, 180, 1500, tilt=0.4) * (0.5 + 0.5 * _cenv(n, rng, 0.25)) * 0.12
    out = bed + _babble(rng, n, 16, 0.55, 0.3)
    for k in range(9):
        _place(out, _distance(_call(rng, rng.uniform(130, 230)), rng.uniform(0.2, 0.7)) * 1.2, rng.uniform(0, n))
    for k in range(7):
        _place(out, _distance(_laugh(rng, rng.uniform(140, 260)), rng.uniform(0.1, 0.6)), rng.uniform(0, n))
    for k in range(24):
        _place(out, _clink(rng) * rng.uniform(0.15, 0.4), rng.uniform(0, n))
    _write_loop("market_murmur_loop", out)


def tavern_room():
    """The Salted Gull's common room at night: close talk, laughter, mugs on tables, a cheer, the fire."""
    rng = np.random.default_rng(6202)
    n = int(SR * 41.7)
    fire = _cband(n, rng, 300, 5000, tilt=0.9) * (0.4 + 0.6 * _cenv(n, rng, 3.0)) * 0.04
    room = _cband(n, rng, 120, 900, tilt=0.6) * (0.6 + 0.4 * _cenv(n, rng, 0.4)) * 0.15
    out = fire + room + _babble(rng, n, 14, 0.8, 0.55, f0s=(95, 220))
    for k in range(14):
        _place(out, _distance(_laugh(rng, rng.uniform(120, 240)), rng.uniform(0.0, 0.4)) * 1.3, rng.uniform(0, n))
    for k in range(40):
        _place(out, _clink(rng, hi=rng.random() < 0.3) * rng.uniform(0.2, 0.6), rng.uniform(0, n))
    for k in range(2):
        cheer = np.zeros(int(SR * 0.9))
        for _ in range(5):
            ph = _phrase(rng, rng.uniform(110, 230), 3, gap=0.0)[:len(cheer)]
            cheer[:len(ph)] += ph
        _place(out, cheer * 0.5, rng.uniform(0, n))
    out = _filt(out, lambda f: _lp(f, 3600))
    _write_loop("tavern_room_loop", out)


def anvil_takes(count=4):
    """Haldor's hammer on the anvil: a bright ring over a dull knock, each take its own pitch."""
    for k in range(count):
        rng = np.random.default_rng(6300 + k)
        n = int(SR * 0.9)
        t = np.arange(n) / SR
        base = rng.uniform(1150, 1400)
        ring = _modes(t, rng, [(base, 1.0, 9), (base * 2.71, 0.55, 14), (base * 4.13, 0.3, 22), (base * 5.6, 0.15, 30)])
        knock = _thump(t, 420, 160, 0.01, 45) * 0.7
        tick = _filt(rng.standard_normal(n) * np.exp(-t * 300), lambda f: _hp(f, 2500))
        _write_shot(f"anvil_{k + 1}", ring + knock + tick * 0.4, -17.0, fade=0.2)


SOUNDS = [("market_murmur", market_murmur), ("tavern_room", tavern_room), ("anvil", anvil_takes)]


def main(argv=None):
    wanted = list(sys.argv[1:] if argv is None else argv)
    known = {name for name, _ in SOUNDS}
    unknown = [w for w in wanted if w not in known]
    if unknown:
        print("unknown sound(s):", ", ".join(unknown))
        print("available:", ", ".join(name for name, _ in SOUNDS))
        sys.exit(1)
    os.makedirs(OUT, exist_ok=True)
    print("Generating town audio ->", os.path.relpath(OUT, ROOT))
    for name, fn in SOUNDS:
        if not wanted or name in wanted:
            fn()
    print("done.")


if __name__ == "__main__":
    main()
