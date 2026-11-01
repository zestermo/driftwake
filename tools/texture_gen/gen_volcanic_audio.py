#!/usr/bin/env python3
"""
The volcanic isle's sounds (docs/volcanic_island_plan.md): the volcano's rumble (a quake: a deep shuddering roar that
swells and dies), a lava bomb's fall and burst (a rising rush, then a crump and a hiss of cinders, two takes), and its
ambience bed (volcanic_loop: a low rumble that breathes, vents hissing, distant crackle; loops seamlessly). Built with
gen_psx_audio.py's helpers and levelled the same way.

    py tools/texture_gen/gen_volcanic_audio.py                 # all
    py tools/texture_gen/gen_volcanic_audio.py rumble bomb      # just these
"""
from __future__ import annotations

import sys

import numpy as np

from gen_psx_audio import SR, _noise, _thump, _write_shot, _write_loop, _shape, _hp, _lp, _cenv, _place, _burst, _norm


def rumble():
    """The volcano's rumble: sub-bass noise swelling over a second, shuddering (a slow tremolo), a grind of rock in it,
    dying away over three; 4.5 s."""
    rng = np.random.default_rng(9301)
    n = int(4.5 * SR)
    t = np.arange(n) / SR
    low = _noise(n, rng, 18.0, 90.0, 2, 4)
    grind = _noise(n, rng, 80.0, 420.0, 2, 3) * 0.35
    env = np.minimum(1.0, t / 1.0) ** 1.5 * np.exp(-np.maximum(t - 1.2, 0.0) / 1.3)
    shudder = 0.7 + 0.3 * np.sin(2 * np.pi * (5.0 + 2.0 * t) * t)
    out = (low + grind * (0.5 + 0.5 * np.sin(2 * np.pi * 1.3 * t))) * env * shudder
    out += _thump(t, 60.0, 30.0, 0.4, 1.4) * 0.6 * np.minimum(1.0, t / 0.6)
    _write_shot("volcano_rumble", out, -16.0, 0.3)


def bomb():
    """A lava bomb landing: a short rising rush of air, the crump of it hitting, a spatter and hiss of cinders; two takes."""
    for k in range(2):
        rng = np.random.default_rng(9310 + k)
        n = int(1.8 * SR)
        t = np.arange(n) / SR
        hit = 0.45 + 0.05 * k
        rush = _noise(n, rng, 300.0, 2400.0, 2, 2) * np.clip(t / hit, 0, 1) ** 3 * (t < hit)
        tt = np.maximum(t - hit, 0.0)
        crump = _thump(tt, 140.0 - 20 * k, 40.0, 0.06, 7.0) * (t >= hit)
        body = _noise(n, rng, 40.0, 600.0, 2, 3) * np.exp(-tt / 0.18) * (t >= hit)
        hiss = _noise(n, rng, 1800.0, 7000.0, 2, 2) * np.exp(-tt / 0.6) * (t >= hit) * 0.45
        out = rush * 0.4 + crump * 1.0 + body * 0.8 + hiss
        _write_shot("lava_bomb_%d" % (k + 1), out, -14.0, 0.1)


def bed(seconds=16.0):
    """The volcanic ambience bed: a low rumble breathing slowly, vents hissing in and out, a distant crackle of cooling
    lava and a pop now and then; loops."""
    rng = np.random.default_rng(9321)
    n = int(seconds * SR)
    low = _shape(n, rng, lambda f: _hp(f, 25.0, 2) * _lp(f, 110.0, 3)) * (0.6 + 0.4 * _cenv(n, rng, 0.15))
    hiss = _shape(n, rng, lambda f: _hp(f, 2000.0, 2) * _lp(f, 6500.0, 2)) * _cenv(n, rng, 0.25) ** 2 * 0.35
    crackle = np.zeros(n)
    for _ in range(int(seconds * 9)):
        ev = _burst(rng, rng.uniform(0.004, 0.02), 1500.0, 5000.0) * rng.uniform(0.05, 0.25)
        _place(crackle, ev * np.exp(-np.arange(len(ev)) / (len(ev) * 0.3)), rng.integers(0, n))
    for _ in range(int(seconds * 0.6)):
        m = int(0.25 * SR)
        tt = np.arange(m) / SR
        pop = _thump(tt, 180.0, 60.0, 0.03, 12.0) * rng.uniform(0.2, 0.4)
        _place(crackle, pop, rng.integers(0, n))
    _write_loop("volcanic_loop", _norm(low) + hiss + crackle, -20.0)


ALL = {"rumble": rumble, "bomb": bomb, "bed": bed}


def main():
    for k in sys.argv[1:] or list(ALL):
        ALL[k]()


if __name__ == "__main__":
    sys.exit(main())
