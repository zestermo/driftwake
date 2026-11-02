#!/usr/bin/env python3
"""
The coral atoll's ambience bed (atoll_loop: the lagoon lapping close, the surf on the reef far off in long slow sets,
the palms rustling in the trade wind, now and then a gull's cry and terns chattering; loops seamlessly). Built with
gen_psx_audio.py's helpers and levelled the same way.

    py tools/texture_gen/gen_atoll_audio.py
"""
from __future__ import annotations

import sys

import numpy as np

from gen_psx_audio import SR, _write_loop, _shape, _hp, _lp, _cenv, _place, _norm


def _gull(rng, dur):
    """A gull's cry: a falling, wavering squeal with a rasp in it."""
    m = int(dur * SR)
    t = np.arange(m) / SR
    f0 = rng.uniform(1300.0, 1700.0)
    f = f0 * (1.0 + 0.35 * np.exp(-t / (dur * 0.35))) * (1.0 + 0.04 * np.sin(2 * np.pi * 9.0 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    v = np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
    env = np.minimum(1.0, t / 0.03) * np.exp(-t / (dur * 0.45))
    return v * env


def _chirp(rng):
    """A tern's quick chatter: three or four short bright chirps."""
    out = np.zeros(int(0.5 * SR))
    for k in range(rng.integers(3, 5)):
        m = int(0.05 * SR)
        t = np.arange(m) / SR
        f = rng.uniform(2800.0, 3600.0) * (1.0 - 1.5 * t)
        c = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / t[-1])
        _place(out, c, int(k * 0.1 * SR))
    return out


def bed(seconds=20.0):
    rng = np.random.default_rng(9441)
    n = int(seconds * SR)
    lap = _shape(n, rng, lambda f: _hp(f, 120.0, 2) * _lp(f, 900.0, 2)) * (0.45 + 0.55 * _cenv(n, rng, 0.7) ** 2)
    surf = _shape(n, rng, lambda f: _hp(f, 40.0, 2) * _lp(f, 420.0, 3)) * (0.5 + 0.5 * _cenv(n, rng, 0.12))
    leaves = _shape(n, rng, lambda f: _hp(f, 2500.0, 2) * _lp(f, 8000.0, 2)) * _cenv(n, rng, 0.2) ** 2 * 0.3
    birds = np.zeros(n)
    for _ in range(int(seconds * 0.25)):
        _place(birds, _gull(rng, rng.uniform(0.35, 0.6)) * rng.uniform(0.04, 0.09), rng.integers(0, n))
    for _ in range(int(seconds * 0.2)):
        _place(birds, _chirp(rng) * rng.uniform(0.03, 0.06), rng.integers(0, n))
    _write_loop("atoll_loop", _norm(lap) * 0.8 + _norm(surf) * 0.6 + leaves + birds, -20.0)


ALL = {"bed": bed}


def main():
    for k in sys.argv[1:] or list(ALL):
        ALL[k]()


if __name__ == "__main__":
    sys.exit(main())
