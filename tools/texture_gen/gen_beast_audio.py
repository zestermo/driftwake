#!/usr/bin/env python3
"""
The jungle beasts' sounds (BeastFX.sfx plays assets/audio/beast_<name>[_<take>].wav).
Built from gen_psx_audio's helpers, levelled the same way (by loudness).

Usage (from the project root):
    py tools/texture_gen/gen_beast_audio.py              # everything
    py tools/texture_gen/gen_beast_audio.py hiss snarl   # only the named sounds
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from gen_psx_audio import (OUT, ROOT, SR, _churn, _filt, _grains, _hp, _lp, _modes, _noise, _thump,  # noqa: E402
                           _write_shot, lpf, resonate)


def _voice(t, f0, rng, growl=0.55, rough=0.5, harmonics=30):
    """A rough glottal source at f0 (Hz per sample) with a period-doubling growl."""
    jitter = lpf(rng.standard_normal(len(t)), 0.01)
    f = f0 * (1 + 0.5 * jitter)
    ph = np.cumsum(f / SR)
    src = np.zeros(len(t))
    for k in range(1, harmonics + 1):
        src += np.sin(2 * np.pi * k * ph) / k
    src *= 1 + growl * np.sin(np.pi * ph)
    src *= np.clip(1 + rough * lpf(rng.standard_normal(len(t)), 0.02) / 0.1, 0.2, 2.0)
    return src, ph


def _formants(x, fs):
    y = np.zeros_like(x)
    for f, q, g in fs:
        y += resonate(x, f, q) * g
    return y


def leaves_takes(count=3):
    """Leaves thrashing in a crown: a dense rustle swelling and dying away, the odd twig snapping."""
    for k in range(count):
        rng = np.random.default_rng(3100 + k)
        d = rng.uniform(0.7, 1.0)
        n = int(SR * d)
        t = np.arange(n) / SR
        src = _noise(n, rng, 1400, 7000)
        rustle = _grains(n, rng, 2600, 0.0, d * 0.9, src, (0.002, 0.008))
        rustle *= 0.35 + 0.65 * _churn(n, rng, 9.0)
        env = np.minimum(1, t / 0.06) * np.clip((d - t) / (d * 0.55), 0, 1)
        out = rustle * env
        for _ in range(rng.integers(1, 3)):
            at = rng.uniform(0.05, d * 0.6)
            tt = np.clip(t - at, 0, None)
            out += _noise(n, rng, 1800, 6000) * np.exp(-tt * 90) * (t >= at) * 0.8
        _write_shot(f"beast_leaves_{k + 1}", _filt(out, lambda f: _hp(f, 500, 2) * _lp(f, 8000, 2)), -20.0, fade=0.05)


def branch_takes(count=2):
    """A limb taking a great weight: a creak, then a crack and a shower of leaves."""
    for k in range(count):
        rng = np.random.default_rng(3200 + k)
        n = int(SR * 0.9)
        t = np.arange(n) / SR
        rate = np.interp(t, [0, 0.15, 0.35, 0.9], [40, 65, 90, 60]) * rng.uniform(0.9, 1.1)
        ph = np.cumsum(rate / SR)
        pulses = np.diff(np.floor(ph), prepend=0.0) * (1 + 0.3 * rng.standard_normal(n))
        creak = (resonate(pulses, 420, 8.0) + resonate(pulses, 980, 10.0) * 0.5) * np.clip(t / 0.05, 0, 1) * np.clip((0.4 - t) / 0.1, 0, 1)
        at = 0.32
        tt = np.clip(t - at, 0, None)
        crack = _modes(tt, rng, [(rng.uniform(600, 800), 1.0, 60), (rng.uniform(1500, 1900), 0.6, 90), (3100, 0.3, 140)]) * (t >= at)
        crack += _noise(n, rng, 900, 6000) * np.exp(-tt * 40) * (t >= at) * 0.7
        leaves = _grains(n, rng, 1500, at, 0.9, _noise(n, rng, 1500, 7000), (0.002, 0.007)) * 0.5
        out = creak / (np.max(np.abs(creak)) + 1e-9) * 0.5 + crack + leaves
        _write_shot(f"beast_branch_{k + 1}", out, -16.0, fade=0.08)


def grunt_takes(count=3):
    """A great ape's grunt-hoot from the chest: a low 'huh-HOO' with a growl in it."""
    for k in range(count):
        rng = np.random.default_rng(3300 + k)
        d = rng.uniform(0.55, 0.8)
        n = int(SR * d)
        t = np.arange(n) / SR
        f0 = np.interp(t, [0, 0.12, d * 0.6, d], [70, 105, 92, 64]) * rng.uniform(0.9, 1.1)
        src, _ = _voice(t, f0, rng, growl=0.7, rough=0.6)
        uh = _formants(np.tanh(src * 1.6), ((420, 5, 1.0), (900, 7, 0.5), (2300, 10, 0.12)))
        oo = _formants(np.tanh(src * 1.6), ((300, 5, 1.0), (650, 7, 0.45), (2200, 10, 0.08)))
        x = np.clip((t - 0.1) / 0.15, 0, 1)
        env = np.minimum(1, t / 0.03) * np.clip((d - t) / (d * 0.45), 0, 1)
        chest = _thump(t, 140, 60, 0.05, 9.0) * 0.6
        out = (uh * (1 - x) + oo * x) * env + chest * np.max(np.abs(uh))
        _write_shot(f"beast_grunt_{k + 1}", lpf(out, 0.35), -15.0, fade=0.06)


def hiss_takes(count=2):
    """A great snake's hiss: breath through a slit, swelling, fluttering, trailing off."""
    for k in range(count):
        rng = np.random.default_rng(3400 + k)
        d = rng.uniform(1.1, 1.5)
        n = int(SR * d)
        t = np.arange(n) / SR
        air = _noise(n, rng, 2600, 9500)
        body = _noise(n, rng, 900, 2600) * 0.35
        flutter = 0.75 + 0.25 * np.sin(2 * np.pi * rng.uniform(9, 14) * t + rng.uniform(0, 6))
        env = np.clip(t / 0.18, 0, 1) ** 1.5 * np.clip((d - t) / (d * 0.5), 0, 1)
        out = (air + body) * flutter * env
        _write_shot(f"beast_hiss_{k + 1}", out, -17.0, fade=0.1)


def slither_takes(count=2):
    """Scales dragging over roots and leaf litter: a dry scrape that comes and goes."""
    for k in range(count):
        rng = np.random.default_rng(3500 + k)
        d = 1.2
        n = int(SR * d)
        t = np.arange(n) / SR
        src = _noise(n, rng, 500, 3800)
        scrape = _grains(n, rng, 3500, 0.0, d, src, (0.003, 0.012)) * (0.3 + 0.7 * _churn(n, rng, 3.0))
        env = np.clip(t / 0.15, 0, 1) * np.clip((d - t) / 0.3, 0, 1)
        _write_shot(f"beast_slither_{k + 1}", scrape * env, -21.0, fade=0.1)


def snarl_takes(count=2):
    """A big cat's snarl: a rasping, ripping growl through bared teeth."""
    for k in range(count):
        rng = np.random.default_rng(3600 + k)
        d = rng.uniform(0.7, 0.95)
        n = int(SR * d)
        t = np.arange(n) / SR
        f0 = np.interp(t, [0, 0.1, d], [85, 120, 75]) * rng.uniform(0.92, 1.08)
        src, ph = _voice(t, f0, rng, growl=0.9, rough=0.9)
        rasp = rng.standard_normal(n) * (0.4 + 0.6 * (np.sin(2 * np.pi * ph) > 0.2))
        v = np.tanh(src * 2.2) + rasp * 0.5
        out = _formants(v, ((650, 5, 1.0), (1300, 7, 0.7), (2700, 9, 0.35)))
        env = np.minimum(1, t / 0.02) * np.clip((d - t) / (d * 0.5), 0, 1)
        _write_shot(f"beast_snarl_{k + 1}", lpf(out * env, 0.5), -14.0, fade=0.05)


def catroar_sound():
    """A great cat's roar: a huge chesty 'AOUGH' falling away into a rumble."""
    rng = np.random.default_rng(3700)
    d = 1.7
    n = int(SR * d)
    t = np.arange(n) / SR
    f0 = np.interp(t, [0, 0.12, 0.5, 1.2, d], [95, 165, 150, 105, 60])
    src, ph = _voice(t, f0, rng, growl=0.8, rough=0.7, harmonics=36)
    v = np.tanh(src * 2.0) + rng.standard_normal(n) * 0.25 * (np.sin(2 * np.pi * ph) > 0.3)
    ao = _formants(v, ((560, 5, 1.0), (950, 6, 0.8), (2400, 10, 0.3)))
    oo = _formants(v, ((380, 5, 1.0), (750, 6, 0.6), (2300, 10, 0.15)))
    x = np.clip((t - 0.5) / 0.6, 0, 1)
    env = np.minimum(1, t / 0.06) * np.clip((d - t) / 0.7, 0, 1)
    rumble = _noise(n, rng, 40, 180) * np.clip((t - 0.9) / 0.3, 0, 1) * np.clip((d - t) / 0.4, 0, 1) * 0.6
    out = (ao * (1 - x) + oo * x) * env + rumble * np.max(np.abs(ao))
    _write_shot("beast_catroar", lpf(out, 0.45), -12.0, fade=0.1)


def screech_sound():
    """A giant mantis's threat screech: wings and chitin rasped together, buzzing, rising."""
    rng = np.random.default_rng(3800)
    d = 1.1
    n = int(SR * d)
    t = np.arange(n) / SR
    rate = np.interp(t, [0, 0.3, d], [45, 70, 55])
    ph = np.cumsum(rate / SR)
    pulses = np.diff(np.floor(ph), prepend=0.0)
    teeth = resonate(pulses, 2800, 6.0) + resonate(pulses, 4600, 8.0) * 0.7 + resonate(pulses, 1500, 5.0) * 0.4
    hiss = _noise(n, rng, 3000, 9000) * 0.25
    env = np.clip(t / 0.08, 0, 1) * np.clip((d - t) / 0.35, 0, 1)
    out = (teeth / (np.max(np.abs(teeth)) + 1e-9) + hiss) * env
    _write_shot("beast_screech", out, -15.0, fade=0.08)


def click_takes(count=2):
    """Chitin clicking: mandibles and jointed legs, a few hard ticks."""
    for k in range(count):
        rng = np.random.default_rng(3900 + k)
        n = int(SR * 0.45)
        t = np.arange(n) / SR
        out = np.zeros(n)
        for at in np.sort(rng.uniform(0.0, 0.35, rng.integers(3, 6))):
            tt = np.clip(t - at, 0, None)
            out += _modes(tt, rng, [(rng.uniform(1800, 2600), 1.0, 160), (rng.uniform(4200, 5200), 0.6, 260)]) * (t >= at)
        _write_shot(f"beast_click_{k + 1}", out, -18.0, fade=0.03)


def squeal_takes(count=2):
    """A great boar's squealing bellow: a pig's shriek dropped low, grunting at the end."""
    for k in range(count):
        rng = np.random.default_rng(4000 + k)
        d = rng.uniform(0.7, 0.9)
        n = int(SR * d)
        t = np.arange(n) / SR
        f0 = np.interp(t, [0, 0.08, d * 0.55, d], [180, 330, 260, 120]) * rng.uniform(0.92, 1.08)
        src, ph = _voice(t, f0, rng, growl=0.5, rough=0.8, harmonics=24)
        v = np.tanh(src * 2.4) + rng.standard_normal(n) * 0.3
        out = _formants(v, ((800, 6, 1.0), (1600, 8, 0.7), (3000, 10, 0.3)))
        env = np.minimum(1, t / 0.02) * np.clip((d - t) / (d * 0.5), 0, 1)
        _write_shot(f"beast_squeal_{k + 1}", lpf(out * env, 0.55), -14.0, fade=0.05)


def bellow_sound():
    """A huge grazer's bellow: a deep horn of a call from a barrel chest."""
    rng = np.random.default_rng(4100)
    d = 1.9
    n = int(SR * d)
    t = np.arange(n) / SR
    f0 = np.interp(t, [0, 0.2, 1.2, d], [48, 70, 66, 42])
    src, _ = _voice(t, f0, rng, growl=0.6, rough=0.4, harmonics=40)
    out = _formants(np.tanh(src * 1.5), ((260, 5, 1.0), (560, 6, 0.6), (1900, 10, 0.12)))
    env = np.minimum(1, t / 0.15) * np.clip((d - t) / 0.6, 0, 1)
    _write_shot("beast_bellow", lpf(out * env, 0.3), -13.0, fade=0.12)


SOUNDS = [
    ("leaves", leaves_takes), ("branch", branch_takes), ("grunt", grunt_takes), ("hiss", hiss_takes),
    ("slither", slither_takes), ("snarl", snarl_takes), ("catroar", catroar_sound), ("screech", screech_sound),
    ("click", click_takes), ("squeal", squeal_takes), ("bellow", bellow_sound),
]


def main(argv=None):
    wanted = list(sys.argv[1:] if argv is None else argv)
    known = {name for name, _ in SOUNDS}
    unknown = [w for w in wanted if w not in known]
    if unknown:
        print("unknown sound(s):", ", ".join(unknown))
        print("available:", ", ".join(name for name, _ in SOUNDS))
        sys.exit(1)
    os.makedirs(OUT, exist_ok=True)
    print("Generating beast audio ->", os.path.relpath(OUT, ROOT))
    for name, fn in SOUNDS:
        if not wanted or name in wanted:
            fn()
    print("done.")


if __name__ == "__main__":
    main()
