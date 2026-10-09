#!/usr/bin/env python3
"""
Driftwake retro music generator: seamless looping PS1-style shanty tracks.

A tiny sequencer (note lists per instrument, in ticks) drives simple
"sample-ish" instruments (Karplus-Strong plucks, additive reeds / fiddle /
flute / brass, synthesized drums). Everything is rendered at 22.05 kHz mono
with a mild 12-bit quantize for PSX flavour. All melodies are original.

Seamless loops: each track is exactly an integer number of bars long. Note
tails that run past the loop end are folded back onto the start, and every
linear effect after that (reverb, echo, EQ, master lowpass) is applied as a
*circular* convolution / filter in the frequency domain, so the output is the
steady state of the loop playing forever: no gap or click at the loop point.

Usage (from the project root):
    pip install numpy scipy
    python tools/texture_gen/gen_psx_music.py              # all tracks
    python tools/texture_gen/gen_psx_music.py sea boss     # only some
    python tools/texture_gen/gen_psx_music.py samples      # style samples to listen to
Output: assets/audio/music_*.ogg (or .wav if ffmpeg is not installed); samples go to
tools/dev/out/music_samples/
"""
import os
import re
import shutil
import subprocess
import sys
import wave
import zlib

import numpy as np
from scipy.signal import butter, lfilter, sosfilt, sosfreqz, fftconvolve

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")
SR = 22050
NYQ_LIMIT = 7500.0  # highest partial the additive instruments will generate
TARGET_RMS = 0.13
PEAK_CEIL = 0.77  # leaves headroom for vorbis overshoot (decoded peaks stay <= ~0.8)

# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------

NOTE_RE = re.compile(r"^([A-Ga-g])([#b]?)(-?\d)$")
PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def nn(name):
    """'F#4' -> MIDI note number."""
    m = NOTE_RE.match(name)
    if not m:
        raise ValueError("bad note " + name)
    letter, acc, octv = m.groups()
    v = PC[letter.upper()] + (1 if acc == "#" else -1 if acc == "b" else 0)
    return v + 12 * (int(octv) + 1)


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def seeded(*key):
    return np.random.default_rng(zlib.crc32(repr(key).encode()))


def envelope(n_gate, a, d, s, r):
    """ADSR. Returns gate + release samples; exponential decay and release."""
    a_n = max(1, int(a * SR))
    d_n = max(1, int(d * SR))
    r_n = max(8, int(r * SR))
    t = np.arange(n_gate)
    e = np.where(t < a_n, t / a_n, s + (1 - s) * np.exp(-(t - a_n) / d_n))
    last = e[-1] if n_gate else 0.0
    rel = last * np.exp(-np.arange(r_n) / (r_n / 5.0))
    rel *= np.linspace(1, 0, r_n) ** 0.5
    return np.concatenate([e, rel])


def phase_of(f, n, vib_rate=0.0, vib_depth=0.0, vib_delay=0.0, scoop=0.0, scoop_t=0.03):
    t = np.arange(n) / SR
    mult = np.ones(n)
    if vib_depth:
        mult += vib_depth * np.sin(2 * np.pi * vib_rate * t) * np.clip((t - vib_delay) / 0.25, 0, 1)
    if scoop:
        mult *= 1 - scoop * np.exp(-t / scoop_t)
    return 2 * np.pi * np.cumsum(f * mult) / SR


def additive(ph, f, amps):
    out = np.zeros(len(ph))
    for k, a in enumerate(amps, start=1):
        if a == 0 or k * f > NYQ_LIMIT:
            continue
        out += a * np.sin(k * ph)
    return out


def harmonics(f, fn, kmax=60):
    K = int(min(kmax, NYQ_LIMIT // f))
    return [fn(k) for k in range(1, max(K, 1) + 1)]


def onepole(x, alpha):
    return lfilter([alpha], [1.0, alpha - 1.0], x)


def bandnoise(rng, n, lo, hi, order=2):
    sos = butter(order, [lo, min(hi, SR / 2 - 200)], btype="band", fs=SR, output="sos")
    return sosfilt(sos, rng.standard_normal(n))


def normpeak(x):
    return x / (np.max(np.abs(x)) + 1e-12)


# --------------------------------------------------------------------------
# instruments: fn(midi, gate_samples, **kw) -> mono array (gate + release)
# --------------------------------------------------------------------------

def inst_flute(m, n):
    f = mtof(m)
    rng = seeded("flute", m, n)
    e = envelope(n, 0.05, 0.12, 0.85, 0.12)
    L = len(e)
    ph = phase_of(f, L, 5.0, 0.006, 0.18)
    tone = additive(ph, f, [1.0, 0.22, 0.07, 0.03])
    t = np.arange(L) / SR
    breath = bandnoise(rng, L, 600, 4000) * (0.05 + 0.25 * np.exp(-t / 0.04))
    return (tone + breath * 0.6) * e * 0.8


def _body(fr):
    """Fiddle body response: two low wood modes, a bridge hill, high rolloff."""
    lf = np.log2(fr)
    g = 0.35
    g += 0.8 * np.exp(-((lf - np.log2(290)) / 0.3) ** 2)
    g += 0.6 * np.exp(-((lf - np.log2(480)) / 0.3) ** 2)
    g += 0.9 * np.exp(-((lf - np.log2(2600)) / 0.6) ** 2)
    return g / (1 + (fr / 4200.0) ** 2)


def inst_fiddle(m, n):
    f = mtof(m)
    rng = seeded("fiddle", m, n)
    e = envelope(n, 0.035, 0.15, 0.8, 0.1)
    L = len(e)
    ph = phase_of(f, L, 5.6, 0.0075, 0.12, scoop=0.01)
    amps = harmonics(f, lambda k: _body(k * f) / k)
    tone = additive(ph, f, amps)
    t = np.arange(L) / SR
    bow = bandnoise(rng, L, 2000, 6000) * (0.03 + 0.12 * np.exp(-t / 0.03))
    return normpeak(tone) * e * 0.85 + bow * e


def _reed(m, n, duty, detunes, a=0.025, r=0.07, tilt=0.4, s=0.9):
    f = mtof(m)
    e = envelope(n, a, 0.08, s, r)
    L = len(e)
    amps = harmonics(f, lambda k: np.sin(np.pi * k * duty) / k ** (1 + tilt))
    out = np.zeros(L)
    for c in detunes:
        fd = f * 2 ** (c / 1200.0)
        out += additive(phase_of(fd, L), fd, amps)
    return normpeak(out) * e


def inst_accordion(m, n):
    return _reed(m, n, 0.33, (0, 11), tilt=0.35) * 0.8


def inst_concertina(m, n):
    return _reed(m, n, 0.5, (0, 6), a=0.03, r=0.06, tilt=0.5) * 0.75


def _ks(f, n_total, bright, t60, rng, pick=0.13):
    """Karplus-Strong with an allpass for fractional delay (in tune up high)."""
    P = SR / f
    N = int(P - 0.5)
    frac = P - 0.5 - N
    if frac < 0.15:
        N -= 1
        frac += 1.0
    c = (1 - frac) / (1 + frac)
    g = 10 ** (-3.0 / (t60 * f))
    a = np.zeros(N + 3)
    a[0] = 1.0
    a[1] += c
    a[N] -= 0.5 * g * c
    a[N + 1] -= 0.5 * g * (1 + c)
    a[N + 2] -= 0.5 * g
    exc = rng.uniform(-1, 1, N)
    exc = onepole(exc, bright)
    d = max(1, int(pick * N))
    exc[d:] -= exc[:-d] * 0.9  # pluck position comb
    x = np.zeros(n_total)
    x[:N] = exc
    return lfilter([1.0, c], a, x)


def inst_pluck(m, n, bright=0.55, t60=1.1, rel=0.08):
    f = mtof(m)
    rng = seeded("pluck", m, n, bright)
    r_n = int(rel * SR)
    y = _ks(f, n + r_n, bright, t60, rng)
    y[n:] *= np.exp(-np.arange(r_n) / (r_n / 5.0)) * np.linspace(1, 0, r_n)
    y[:30] *= np.linspace(0, 1, 30)
    return normpeak(y) * 0.9


def inst_guitar(m, n):
    return inst_pluck(m, n, bright=0.42, t60=1.6, rel=0.12)


def inst_bass(m, n):
    """Plucked upright-ish bass: dark KS plus a sine for weight."""
    f = mtof(m)
    rng = seeded("bass", m, n)
    r_n = int(0.06 * SR)
    L = n + r_n
    y = normpeak(_ks(f, L, 0.22, 1.8, rng, pick=0.2))
    t = np.arange(L) / SR
    y += np.sin(2 * np.pi * f * t) * np.exp(-t * 2.0) * 0.8
    y[n:] *= np.exp(-np.arange(r_n) / (r_n / 5.0)) * np.linspace(1, 0, r_n)
    y[:40] *= np.linspace(0, 1, 40)
    return normpeak(y)


def _strings(m, n, a, d, s, r, tilt, voices=(-6, 6), vib=0.003):
    f = mtof(m)
    e = envelope(n, a, d, s, r)
    L = len(e)
    amps = harmonics(f, lambda k: 1.0 / k ** tilt / (1 + (k * f / 3500.0) ** 2))
    out = np.zeros(L)
    for c in voices:
        fd = f * 2 ** (c / 1200.0)
        out += additive(phase_of(fd, L, 5.0 + c * 0.05, vib, 0.1), fd, amps)
    return normpeak(out) * e


def inst_lowstr(m, n):
    return _strings(m, n, 0.09, 0.25, 0.85, 0.2, 1.15) * 0.8


def inst_stacc(m, n):
    return _strings(m, n, 0.005, 0.07, 0.25, 0.05, 1.0, vib=0.0)


def inst_brass(m, n, drive=1.6):
    """Saw-ish brass whose brightness follows its envelope, with a pitch scoop."""
    f = mtof(m)
    e = envelope(n, 0.03, 0.22, 0.7, 0.1)
    L = len(e)
    ph = phase_of(f, L, 5.0, 0.004, 0.3, scoop=0.025)
    K = int(min(40, 5200 // f))
    out = np.zeros(L)
    for k in range(1, max(K, 1) + 1):
        out += np.sin(k * ph) / k * e ** (0.7 * (k - 1))
    out = np.tanh(drive * normpeak(out) * e)
    return normpeak(out) * e ** 0.3


def inst_timpani(m, n):
    f = mtof(m)
    rng = seeded("timp", m)
    L = int(1.8 * SR)
    t = np.arange(L) / SR
    glide = 1 - 0.015 * np.exp(-t / 0.08) * -1  # starts slightly sharp
    out = np.zeros(L)
    for r, a, dcy in ((1.0, 1.0, 2.8), (1.5, 0.45, 4.0), (1.98, 0.3, 5.5), (2.44, 0.18, 7.0), (2.94, 0.1, 9.0)):
        out += a * np.sin(2 * np.pi * np.cumsum(f * r * glide) / SR) * np.exp(-t * dcy)
    thump = onepole(rng.standard_normal(L), 0.08) * np.exp(-t * 35) * 3.0
    out = out * np.minimum(1, t / 0.002) + thump
    if n < L:  # damped early (rolls)
        out[n:] *= np.exp(-np.arange(L - n) / (0.08 * SR))
    return normpeak(out)


def inst_kick(m, n):
    L = int(0.45 * SR)
    t = np.arange(L) / SR
    f = 46 + 80 * np.exp(-t / 0.035)
    out = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8.5)
    out += onepole(seeded("kick").standard_normal(L), 0.3) * np.exp(-t * 120) * 0.3
    return normpeak(out)


def inst_frame(m, n):
    """Frame drum / bodhran: soft low thump with a skin slap."""
    rng = seeded("frame", m)
    L = int(0.35 * SR)
    t = np.arange(L) / SR
    f0 = mtof(m) if m else 70.0
    f = f0 + f0 * 0.4 * np.exp(-t / 0.03)
    out = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 13)
    out += bandnoise(rng, L, 200, 1800) * np.exp(-t * 45) * 0.6
    return normpeak(out)


def inst_snare(m, n):
    rng = seeded("snare")
    L = int(0.3 * SR)
    t = np.arange(L) / SR
    noise = bandnoise(rng, L, 1200, 7000) * np.exp(-t * 17)
    body = (np.sin(2 * np.pi * 190 * t) + 0.5 * np.sin(2 * np.pi * 330 * t)) * np.exp(-t * 30)
    return normpeak(normpeak(noise) * 0.9 + body * 0.6)


def inst_tom(m, n):
    rng = seeded("tom", m)
    L = int(0.5 * SR)
    t = np.arange(L) / SR
    f0 = mtof(m)
    f = f0 * (0.78 + 0.22 * np.exp(-t / 0.08)) * 1.1
    out = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    out += bandnoise(rng, L, 300, 3000) * np.exp(-t * 60) * 0.4
    return normpeak(out)


def inst_conga(m, n):
    rng = seeded("conga", m)
    L = int(0.3 * SR)
    t = np.arange(L) / SR
    f0 = mtof(m)
    out = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.08 * np.exp(-t / 0.02))) / SR) * np.exp(-t * 16)
    out += bandnoise(rng, L, 800, 4000) * np.exp(-t * 90) * 0.5
    return normpeak(out)


def inst_hat(m, n):
    rng = seeded("hat")
    L = int(0.08 * SR)
    t = np.arange(L) / SR
    return normpeak(bandnoise(rng, L, 5000, 9500) * np.exp(-t * 70))


def inst_shaker(m, n):
    rng = seeded("shaker")
    L = int(0.1 * SR)
    t = np.arange(L) / SR
    env = np.minimum(1, t / 0.015) * np.exp(-t * 40)
    return normpeak(bandnoise(rng, L, 3500, 8500) * env)


def inst_crash(m, n):
    rng = seeded("crash")
    L = int(2.2 * SR)
    t = np.arange(L) / SR
    hi = bandnoise(rng, L, 3000, 9000) * np.exp(-t * 2.4)
    lo = bandnoise(rng, L, 500, 3000) * np.exp(-t * 4.0) * 0.6
    return normpeak(hi + lo) * np.minimum(1, t / 0.003)


def inst_marimba(m, n):
    f = mtof(m)
    L = int(0.9 * SR)
    t = np.arange(L) / SR
    out = np.sin(2 * np.pi * f * t) * np.exp(-t * 5.5)
    out += 0.3 * np.sin(2 * np.pi * 3.98 * f * t) * np.exp(-t * 22)
    out += 0.08 * np.sin(2 * np.pi * 9.9 * f * t) * np.exp(-t * 60) * (9.9 * f < NYQ_LIMIT)
    return normpeak(out * np.minimum(1, t / 0.002))


# --- orchestral voices (the adventure samples): horn, harp, string section,
# pizzicato, oboe, choir, taiko, glockenspiel, a reversed-cymbal swell ---

def inst_horn(m, n):
    """French horn: dark and round (few, soft upper partials that open up as it swells)."""
    f = mtof(m)
    e = envelope(n, 0.06, 0.3, 0.8, 0.18)
    L = len(e)
    ph = phase_of(f, L, 4.8, 0.004, 0.35, scoop=0.015)
    K = int(min(24, 2600 // f))
    out = np.zeros(L)
    for k in range(1, max(K, 1) + 1):
        out += np.sin(k * ph) / k ** 1.3 * e ** (0.5 * (k - 1))
    out = np.tanh(1.2 * normpeak(out))
    return normpeak(out) * e ** 0.5


def inst_harp(m, n):
    """Harp: a bright pluck that rings on whatever the gate (strings left to sound)."""
    f = mtof(m)
    rng = seeded("harp", m)
    L = max(n, int(1.6 * SR))
    y = _ks(f, L, 0.62, 2.4, rng, pick=0.27)
    y[:20] *= np.linspace(0, 1, 20)
    fade = int(0.1 * SR)
    y[-fade:] *= np.linspace(1, 0, fade)
    return normpeak(y) * 0.85


def inst_harp_dark(m, n):
    """Harp, played softly: a darker, rounder pluck (less chime)."""
    f = mtof(m)
    rng = seeded("harp_dark", m)
    L = max(n, int(1.8 * SR))
    y = _ks(f, L, 0.36, 2.2, rng, pick=0.42)
    y[:40] *= np.linspace(0, 1, 40)
    fade = int(0.12 * SR)
    y[-fade:] *= np.linspace(1, 0, fade)
    return normpeak(y) * 0.8


def inst_pizz(m, n):
    """Pizzicato strings: a short dark pluck."""
    f = mtof(m)
    rng = seeded("pizz", m)
    L = int(0.5 * SR)
    y = _ks(f, L, 0.4, 0.45, rng, pick=0.35)
    y[:20] *= np.linspace(0, 1, 20)
    fade = int(0.08 * SR)
    y[-fade:] *= np.linspace(1, 0, fade)
    return normpeak(y)


def inst_strings(m, n):
    """String section, legato: four detuned players with vibrato."""
    return _strings(m, n, 0.08, 0.3, 0.9, 0.25, 1.0, voices=(-9, -3, 4, 10), vib=0.005) * 0.85


def inst_oboe(m, n):
    """Oboe: nasal reed, formant humps near 1.2 and 2.9 kHz."""
    f = mtof(m)
    e = envelope(n, 0.03, 0.1, 0.85, 0.08)
    L = len(e)
    ph = phase_of(f, L, 5.5, 0.006, 0.15)
    amps = harmonics(f, lambda k: (0.25 + 1.2 * np.exp(-((k * f - 1200) / 500) ** 2)
                                   + 0.6 * np.exp(-((k * f - 2900) / 600) ** 2)) / k ** 0.6)
    return normpeak(additive(ph, f, amps)) * e * 0.8


def inst_choir(m, n):
    """Choir 'aah': a buzz through vowel formants, three loose voices, slow in."""
    f = mtof(m)
    e = envelope(n, 0.25, 0.3, 0.9, 0.35)
    L = len(e)

    def form(fr):
        return (np.exp(-((fr - 800) / 130) ** 2) + 0.6 * np.exp(-((fr - 1150) / 150) ** 2)
                + 0.25 * np.exp(-((fr - 2900) / 250) ** 2) + 0.08)

    amps = harmonics(f, lambda k: form(k * f) / k ** 0.3)
    out = np.zeros(L)
    for c in (-8, 0, 7):
        fd = f * 2 ** (c / 1200.0)
        out += additive(phase_of(fd, L, 5.2 + c * 0.03, 0.006, 0.2), fd, amps)
    return normpeak(out) * e


def inst_taiko(m, n):
    """Big low drum: a falling boom, a skin thud and a slap."""
    rng = seeded("taiko", m)
    L = int(1.1 * SR)
    t = np.arange(L) / SR
    f0 = mtof(m) if m else 55.0
    f = f0 * (1 + 0.6 * np.exp(-t / 0.04))
    out = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 4.5)
    out += bandnoise(rng, L, 120, 900) * np.exp(-t * 14) * 0.7
    out += bandnoise(rng, L, 1500, 5000) * np.exp(-t * 60) * 0.25
    return normpeak(out * np.minimum(1, t / 0.002))


def inst_glock(m, n):
    """Glockenspiel: bright bar partials, quick to fade."""
    f = mtof(m)
    L = int(1.2 * SR)
    t = np.arange(L) / SR
    out = np.sin(2 * np.pi * f * t) * np.exp(-t * 3)
    if 2.76 * f < NYQ_LIMIT:
        out += 0.4 * np.sin(2 * np.pi * 2.76 * f * t) * np.exp(-t * 8)
    if 5.4 * f < NYQ_LIMIT:
        out += 0.2 * np.sin(2 * np.pi * 5.4 * f * t) * np.exp(-t * 15)
    return normpeak(out * np.minimum(1, t / 0.001))


def inst_swell(m, n):
    """Reversed cymbal: noise rising over the note into the next downbeat."""
    rng = seeded("swell", n)
    L = max(n, 64)
    t = np.arange(L) / L
    x = bandnoise(rng, L, 2500, 9000) + 0.5 * bandnoise(rng, L, 500, 2500)
    return normpeak(x) * t ** 3


INSTRUMENTS = {
    "flute": inst_flute, "fiddle": inst_fiddle, "accordion": inst_accordion,
    "concertina": inst_concertina, "pluck": inst_pluck, "guitar": inst_guitar,
    "bass": inst_bass, "lowstr": inst_lowstr, "stacc": inst_stacc, "brass": inst_brass,
    "timpani": inst_timpani, "kick": inst_kick, "frame": inst_frame, "snare": inst_snare,
    "tom": inst_tom, "conga": inst_conga, "hat": inst_hat, "shaker": inst_shaker,
    "crash": inst_crash, "marimba": inst_marimba,
    "horn": inst_horn, "harp": inst_harp, "harp_dark": inst_harp_dark, "pizz": inst_pizz, "strings": inst_strings,
    "oboe": inst_oboe, "choir": inst_choir, "taiko": inst_taiko, "glock": inst_glock,
    "swell": inst_swell,
}

_cache = {}


def render_note(inst, midi, n_gate):
    """Instrument 'samples' are cached: like a PS1 sequencer, the same note
    replays the same sample (also keeps rendering fast)."""
    key = (inst, midi, n_gate)
    if key not in _cache:
        _cache[key] = INSTRUMENTS[inst](midi, max(n_gate, 16)).astype(np.float64)
    return _cache[key]


# --------------------------------------------------------------------------
# harmony / notation
# --------------------------------------------------------------------------

QUALITIES = {
    "": (0, 4, 7), "m": (0, 3, 7), "7": (0, 4, 7, 10), "m7": (0, 3, 7, 10),
    "dim": (0, 3, 6), "sus4": (0, 5, 7), "5": (0, 7), "maj7": (0, 4, 7, 11),
}
CHORD_RE = re.compile(r"^([A-G])([#b]?)(.*)$")


def chord_pcs(sym):
    m = CHORD_RE.match(sym)
    root = PC[m.group(1)] + (1 if m.group(2) == "#" else -1 if m.group(2) == "b" else 0)
    return root % 12, [(root + i) % 12 for i in QUALITIES[m.group(3)]]


def voice(pcs, low):
    """Place pitch classes in [low, low+12): automatic close voicing."""
    return sorted(low + ((pc - low) % 12) for pc in pcs)


def parse_line(text):
    """'D5/2 E5/1 -/1 ~/2' -> [(midi|None, dur_ticks)]; '~' ties onto previous."""
    out = []
    for tok in text.split():
        name, dur = tok.split("/")
        dur = float(dur)
        if name == "~":
            mm, d0 = out[-1]
            out[-1] = (mm, d0 + dur)
        elif name == "-":
            out.append((None, dur))
        else:
            out.append((nn(name), dur))
    return out


def diatonic_shift(m, scale_pcs, steps):
    """Move a note by scale degrees (for parallel thirds etc.)."""
    pcs = sorted(scale_pcs)
    cand = m
    count = 0
    direction = 1 if steps > 0 else -1
    while count < abs(steps):
        cand += direction
        if cand % 12 in pcs:
            count += 1
    return cand


def scale(root_name, mode):
    modes = {"major": (0, 2, 4, 5, 7, 9, 11), "minor": (0, 2, 3, 5, 7, 8, 10),
             "dorian": (0, 2, 3, 5, 7, 9, 10), "mixolydian": (0, 2, 4, 5, 7, 9, 10),
             "phrygian": (0, 1, 3, 5, 7, 8, 10), "harmonic": (0, 2, 3, 5, 7, 8, 11)}
    r = PC[root_name[0]] + (1 if root_name[1:] == "#" else -1 if root_name[1:] == "b" else 0)
    return [(r + i) % 12 for i in modes[mode]]


def split_chords(chords):
    """['D', 'G A'] -> per bar list of (chord, start_frac, end_frac)."""
    bars = []
    for entry in chords:
        parts = entry.split()
        k = len(parts)
        bars.append([(p, i / k, (i + 1) / k) for i, p in enumerate(parts)])
    return bars


def chord_at(chord_bars, bar, frac):
    for sym, a, b in chord_bars[bar % len(chord_bars)]:
        if a <= frac < b:
            return sym
    return chord_bars[bar % len(chord_bars)][-1][0]


# --------------------------------------------------------------------------
# sequencer + mixer
# --------------------------------------------------------------------------

class Song:
    def __init__(self, name, tick_sec, ticks_per_bar, bars, info, loop=True, seed=1):
        self.name = name
        self.tick_sec = tick_sec
        self.tpb = ticks_per_bar
        self.bars = bars
        self.info = info
        self.loop = loop
        self.events = []  # (bus, inst, midi, tick, dur_ticks, vel, gate)
        self.rng = np.random.default_rng(seed)
        self.buses = {}  # bus -> dict(gain, verb, echo, hp, lp)

    @property
    def length(self):
        return int(round(self.bars * self.tpb * self.tick_sec * SR))

    def bus(self, name, gain=1.0, verb=0.15, echo=0.0, lp=None, hp=None):
        self.buses[name] = dict(gain=gain, verb=verb, echo=echo, lp=lp, hp=hp)

    def note(self, bus, inst, midi, tick, dur, vel=1.0, gate=0.92, human=0.06):
        v = vel * (1 + human * (self.rng.random() - 0.5) * 2)
        self.events.append((bus, inst, midi, tick, dur, v, gate))

    def line(self, bus, inst, text, bar, vel=1.0, gate=0.92, transpose=0, accent_first=0.0,
             harmonize=None):
        """Sequence a melody line starting at a bar. harmonize=(scale_pcs, steps)."""
        tick = bar * self.tpb
        for midi, dur in parse_line(text):
            if midi is not None:
                m = midi + transpose
                if harmonize:
                    m = diatonic_shift(m, *harmonize)
                v = vel * (1 + accent_first) if (tick % self.tpb == 0) else vel
                self.note(bus, inst, m, tick, dur, v, gate)
            tick += dur
        return tick

    def drums(self, bus, inst, pattern, bars, midi=0, vel=1.0, every=1):
        """Pattern string, one char per tick: X=accent x=normal o=ghost .=rest."""
        levels = {"X": 1.0, "x": 0.72, "o": 0.42}
        ticks_per_char = self.tpb / len(pattern)
        for b in bars:
            for i, ch in enumerate(pattern):
                if ch in levels:
                    self.note(bus, inst, midi, b * self.tpb + i * ticks_per_char,
                              ticks_per_char, vel * levels[ch], 1.0, human=0.1)

    # ----------------------------------------------------------------------
    def render(self):
        spt = self.tick_sec * SR
        L = self.length
        maxlen = int(4.0 * SR)
        raw = {b: np.zeros(L + maxlen + int(3 * SR)) for b in self.buses}
        for bus, inst, midi, tick, dur, vel, gate in self.events:
            s0 = int(round(tick * spt))
            g = int(round(dur * spt * gate))
            sig = render_note(inst, midi, g)
            buf = raw[bus]
            if s0 + len(sig) > len(buf):
                sig = sig[: len(buf) - s0]
            buf[s0:s0 + len(sig)] += sig * vel
        out_buses = {}
        for b, buf in raw.items():
            if self.loop:
                circ = buf[:L].copy()
                for k in range(L, len(buf), L):  # fold note tails back onto the start
                    seg = buf[k:k + L]
                    circ[:len(seg)] += seg
                out_buses[b] = circ
            else:
                out_buses[b] = buf
        return out_buses


def _filter_response(sos, n):
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    _, h = sosfreqz(sos, worN=freqs, fs=SR)
    return h


def apply_filter(x, sos, circular):
    if circular:
        return np.fft.irfft(np.fft.rfft(x) * _filter_response(sos, len(x)), len(x))
    return sosfilt(sos, x)


def convolve(x, ir, circular):
    if circular:
        L = len(x)
        h = np.zeros(L)
        k = min(len(ir), L)
        h[:k] = ir[:k]
        return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(h), L)
    return fftconvolve(x, ir)[: len(x)]


def make_reverb_ir(t60=1.5, seed=5, predelay=0.018):
    """Small hall: early reflections + filtered noise tail (darker as it decays)."""
    rng = np.random.default_rng(seed)
    L = int(SR * t60 * 1.2)
    t = np.arange(L) / SR
    lo = bandnoise(rng, L, 80, 2400) * np.exp(-t * 6.9 / t60)
    hi = bandnoise(rng, L, 2400, 7500) * np.exp(-t * 6.9 / (t60 * 0.35))
    tail = (lo + hi * 0.5) * np.minimum(1, t / 0.03)
    ir = np.zeros(L + int(predelay * SR))
    ir[int(predelay * SR):] = tail
    for dt, g in ((0.011, 0.5), (0.019, -0.35), (0.027, 0.3), (0.041, -0.22), (0.053, 0.18)):
        ir[int(dt * SR)] += g * 6
    ir /= np.sqrt(np.sum(ir ** 2))
    return ir


def make_echo_ir(delay_sec, feedback=0.38, taps=5):
    """Feedback delay expressed as an IR (each repeat a little darker)."""
    d = int(round(delay_sec * SR))
    ir = np.zeros(d * taps + 64)
    for k in range(1, taps + 1):
        pulse = np.zeros(64)
        pulse[0] = 1.0
        pulse = onepole(pulse, 0.65 ** (k * 0.5))
        ir[d * k:d * k + 64] += pulse * feedback ** k * 0.9
    return ir


def soft_ceiling(x, ceil=PEAK_CEIL, knee=0.6):
    """Pointwise soft limiter: linear below knee, smoothly approaches ceil."""
    a = np.abs(x)
    over = a > knee
    y = x.copy()
    span = ceil - knee
    y[over] = np.sign(x[over]) * (knee + span * np.tanh((a[over] - knee) / span))
    return y


def mixdown(song, buses, verb_t60=1.4, echo_sec=None, target_rms=TARGET_RMS, crunch_bits=12, trim=None):
    circ = song.loop
    L = len(next(iter(buses.values())))
    dry = np.zeros(L)
    send = np.zeros(L)
    esend = np.zeros(L)
    for name, cfg in song.buses.items():
        x = buses[name]
        if cfg["hp"]:
            x = apply_filter(x, butter(2, cfg["hp"], "high", fs=SR, output="sos"), circ)
        if cfg["lp"]:
            x = apply_filter(x, butter(2, cfg["lp"], "low", fs=SR, output="sos"), circ)
        x = x * cfg["gain"]
        dry += x
        send += x * cfg["verb"]
        esend += x * cfg["echo"]
    wet = convolve(send, make_reverb_ir(verb_t60), circ)
    if echo_sec and np.any(esend):
        ech = convolve(esend, make_echo_ir(echo_sec), circ)
        wet += ech + convolve(ech, make_reverb_ir(verb_t60), circ) * 0.5
    mix = dry + wet
    mix = apply_filter(mix, butter(2, 38, "high", fs=SR, output="sos"), circ)
    mix = apply_filter(mix, butter(4, 8000, "low", fs=SR, output="sos"), circ)
    if circ:
        mix -= np.mean(mix)
    if trim:  # stings: cut to length (with a fade) before levelling
        mix = mix[:trim].copy()
        fade = int(0.6 * SR)
        mix[-fade:] *= np.linspace(1, 0, fade) ** 2
        mix[:16] *= np.linspace(0, 1, 16)
    mix *= target_rms / (np.sqrt(np.mean(mix ** 2)) + 1e-12)
    mix = soft_ceiling(mix)
    if crunch_bits:
        q = 2.0 ** (crunch_bits - 1)
        mix = np.round(mix * q) / q
    return mix


# --------------------------------------------------------------------------
# accompaniment helpers
# --------------------------------------------------------------------------

def comp(song, bus, inst, chord_bars, bars, hits, low=55, vel=0.6, gate=0.8, top_only=False):
    """Chord stabs/pumps at the given (tick, dur_ticks) positions within each bar."""
    for b in bars:
        for tk, dur in hits:
            sym = chord_at(chord_bars, b, tk / song.tpb)
            _, pcs = chord_pcs(sym)
            notes = voice(pcs, low)
            if top_only:
                notes = notes[-2:]
            for m in notes:
                song.note(bus, inst, m, b * song.tpb + tk, dur, vel / np.sqrt(len(notes)), gate)


def bassline(song, bus, inst, chord_bars, bars, hits, octave_low=38, vel=0.9, gate=0.85):
    """hits: (tick, dur, interval) where interval is 'R', '5', '8', '3' or semitones."""
    for b in bars:
        for tk, dur, iv in hits:
            sym = chord_at(chord_bars, b, tk / song.tpb)
            root, pcs = chord_pcs(sym)
            r = octave_low + ((root - octave_low) % 12)
            if iv == "R":
                m = r
            elif iv == "5":
                m = r + 7 if len(pcs) > 1 and (root + 7) % 12 in pcs else r + 7
            elif iv == "8":
                m = r + 12
            elif iv == "3":
                m = r + ((pcs[1] - root) % 12)
            else:
                m = r + int(iv)
            song.note(bus, inst, m, b * song.tpb + tk, dur, vel, gate)


def arpeggio(song, bus, inst, chord_bars, bars, order, step, low=52, vel=0.5, dur=None, gate=1.0):
    """Arpeggiate the chord tones (two octaves) in 'order' index list, one per step ticks."""
    for b in bars:
        for i, idx in enumerate(order):
            tk = i * step
            if tk >= song.tpb:
                break
            sym = chord_at(chord_bars, b, tk / song.tpb)
            _, pcs = chord_pcs(sym)
            tones = voice(pcs, low)
            tones = tones + [x + 12 for x in tones] + [x + 24 for x in tones]
            song.note(bus, inst, tones[idx], b * song.tpb + tk, dur or step * 2, vel, gate)


# --------------------------------------------------------------------------
# the tracks
# --------------------------------------------------------------------------

def track_title():
    # 4/4, 100 bpm, ticks = eighth notes. D major. 24 bars: A (flute) B (flute) A' (accordion lead).
    s = Song("music_title", 60 / 100 / 2, 8, 24, "4/4, 100 bpm, D major, warm adventurous (A-B-A')")
    s.bus("lead", 0.36, verb=0.28, echo=0.12)
    s.bus("lead2", 0.55, verb=0.25)
    s.bus("acc", 0.5, verb=0.18)
    s.bus("pluck", 0.62, verb=0.22)
    s.bus("bass", 0.45, verb=0.05)
    s.bus("pad", 0.28, verb=0.35)
    s.bus("drum", 0.42, verb=0.12)
    s.bus("shk", 0.16, verb=0.1)
    A_ch = ["D", "G", "D", "A", "Bm", "G", "A", "D"]
    B_ch = ["G", "A", "F#m", "Bm", "G", "A", "D", "A"]
    ch = split_chords(A_ch + B_ch + A_ch)
    A_mel = ("D5/3 E5/1 F#5/2 A5/2 | G5/3 F#5/1 E5/2 D5/2 | F#5/3 E5/1 D5/2 A4/2 | E5/4 -/2 A4/1 C#5/1 | "
             "D5/3 C#5/1 B4/2 F#5/2 | G5/3 F#5/1 E5/2 B4/2 | C#5/2 E5/2 A5/2 G5/1 E5/1 | D5/6 -/2")
    B_mel = ("B5/3 A5/1 G5/2 D5/2 | C#5/2 E5/2 A5/4 | A5/3 G5/1 F#5/2 C#5/2 | D5/2 F#5/2 B5/4 | "
             "G5/2 A5/2 B5/3 A5/1 | A5/3 G5/1 E5/2 C#5/2 | D5/2 F#5/2 E5/2 D5/2 | E5/4 C#5/2 A4/2")
    clean = lambda txt: txt.replace("|", " ")
    s.line("lead", "flute", clean(A_mel), 0, vel=0.9)
    s.line("lead", "flute", clean(B_mel), 8, vel=0.9)
    s.line("lead2", "accordion", clean(A_mel), 16, vel=0.9, transpose=-12)
    s.line("lead", "flute", clean(A_mel), 16, vel=0.55, harmonize=(scale("D", "major"), -2))
    allb = range(24)
    bassline(s, "bass", "bass", ch, allb, [(0, 3, "R"), (4, 2, "5"), (6, 1, "R")])
    comp(s, "acc", "accordion", ch, allb, [(2, 1.5), (6, 1.5)], low=57, vel=0.7, gate=0.7)
    arpeggio(s, "pluck", "pluck", ch, allb, [0, 1, 2, 3, 4, 3, 2, 1], 1, low=55, vel=0.45, dur=2)
    for b in range(8, 16):  # B section: soft sustained strings
        sym = chord_at(ch, b, 0)
        for m in voice(chord_pcs(sym)[1], 50):
            s.note("pad", "lowstr", m, b * 8, 8, 0.4, 0.98)
    s.drums("drum", "frame", "X...x.o.", allb, midi=nn("D2"))
    s.drums("drum", "frame", "X...x.oo", [7, 15, 23], midi=nn("D2"))
    s.drums("shk", "shaker", "o.x.o.x.", allb)
    return s, dict(verb_t60=1.6, echo_sec=0.45)


def track_island():
    # 4/4, 90 bpm, eighth-note ticks. G major. 16 bars, relaxed and sunny.
    s = Song("music_island", 60 / 90 / 2, 8, 16, "4/4, 90 bpm, G major, relaxed sunny exploration")
    s.bus("lead", 0.42, verb=0.25, echo=0.18)
    s.bus("mar", 0.45, verb=0.2)
    s.bus("gtr", 0.75, verb=0.2)
    s.bus("bass", 0.42, verb=0.04)
    s.bus("perc", 0.42, verb=0.12)
    s.bus("shk", 0.13, verb=0.08)
    A_ch = ["G", "Em", "C", "D", "G", "Bm", "C D", "G"]
    B_ch = ["C", "D", "Bm", "Em", "Am", "D", "G", "D7"]
    ch = split_chords(A_ch + B_ch)
    A_mel = ("-/1 B4/1 D5/2 B4/1 D5/1 E5/2  G5/3 E5/1 -/2 D5/1 B4/1  C5/2 E5/2 G5/1 E5/1 D5/1 C5/1  "
             "D5/4 -/2 A4/1 B4/1  D5/3 B4/1 G4/2 A4/1 B4/1  D5/2 F#5/2 -/1 E5/1 D5/1 B4/1  "
             "E5/2 C5/2 D5/2 F#5/2  G5/4 -/4")
    B_mel = ("E5/3 G5/1 E5/2 C5/2  F#5/3 A5/1 F#5/2 D5/2  D5/2 B4/2 F#5/3 E5/1  E5/4 -/2 G4/1 A4/1  "
             "C5/3 E5/1 A5/2 G5/2  F#5/3 E5/1 D5/2 C5/2  B4/2 D5/2 G5/3 F#5/1  E5/2 D5/2 C5/2 A4/2")
    s.line("lead", "guitar", A_mel, 0, vel=0.85, transpose=0)
    s.line("lead", "flute", B_mel, 8, vel=0.75)
    s.line("mar", "marimba", B_mel, 8, vel=0.35, harmonize=(scale("G", "major"), -2), gate=0.5)
    allb = range(16)
    bassline(s, "bass", "bass", ch, allb, [(0, 2.5, "R"), (3, 2.5, "5"), (6, 2, "8")], vel=0.85)
    arpeggio(s, "gtr", "guitar", ch, allb, [0, 2, 3, 2, 4, 2, 3, 2], 1, low=50, vel=0.4, dur=2)
    arpeggio(s, "mar", "marimba", ch, range(0, 8), [5, -1, 4, -1, 5, -1, 6, -1][::2], 2, low=62, vel=0.25)
    s.drums("perc", "conga", "x..x..x.", allb, midi=nn("A3"), vel=0.8)
    s.drums("perc", "conga", "....o..o", allb, midi=nn("E4"), vel=0.6)
    s.drums("shk", "shaker", "xoxoxoxo", allb)
    return s, dict(verb_t60=1.3, echo_sec=0.5)


def track_sea():
    # 6/8 rolling shanty. Quarter = 110 (eighth = 220, dotted quarter ~73). D mixolydian/major.
    s = Song("music_sea", 60 / 220, 6, 32, "6/8, quarter=110 (eighth=220, dotted-quarter=73.3), "
                                           "D major w/ mixolydian C, rolling shanty (A-B-A'-B')")
    s.bus("fiddle", 0.42, verb=0.25, echo=0.08)
    s.bus("flute", 0.4, verb=0.3, echo=0.12)
    s.bus("conc", 0.55, verb=0.2)
    s.bus("bass", 0.45, verb=0.05)
    s.bus("drum", 0.45, verb=0.15)
    s.bus("shk", 0.13, verb=0.08)
    s.bus("wind", 0.07, verb=0.0)
    A_ch = ["D", "C", "D", "A", "D", "C", "G A", "D"]
    B_ch = ["G", "D", "Em", "A", "G", "D", "Bm A", "D"]
    ch = split_chords(A_ch + B_ch + A_ch + B_ch)
    A_mel = ("A4/2 D5/1 F#5/2 E5/1  G5/2 E5/1 C5/2 E5/1  F#5/2 A5/1 F#5/2 D5/1  E5/3 C#5/2 A4/1  "
             "D5/2 F#5/1 A5/2 B5/1  C6/2 B5/1 G5/2 E5/1  D5/2 B4/1 C#5/2 E5/1  D5/5 -/1")
    B_mel = ("B5/3 A5/2 G5/1  F#5/2 E5/1 D5/2 F#5/1  G5/2 F#5/1 E5/2 B4/1  C#5/2 E5/1 A5/3  "
             "B5/2 G5/1 D5/2 G5/1  A5/2 F#5/1 D5/2 A4/1  B4/2 D5/1 C#5/2 A4/1  D5/4 -/2")
    dmaj = scale("D", "mixolydian")
    s.line("fiddle", "fiddle", A_mel, 0, vel=0.85)
    s.line("fiddle", "fiddle", B_mel, 8, vel=0.85)
    s.line("flute", "flute", A_mel, 16, vel=0.9)
    s.line("fiddle", "fiddle", A_mel, 16, vel=0.45, harmonize=(dmaj, -2), transpose=0)
    s.line("flute", "flute", B_mel, 24, vel=0.85)
    s.line("fiddle", "fiddle", B_mel, 24, vel=0.7, transpose=-12)
    allb = range(32)
    bassline(s, "bass", "bass", ch, allb, [(0, 2, "R"), (3, 2, "5")])
    comp(s, "conc", "concertina", ch, allb, [(1, 1), (2, 1), (4, 1), (5, 1)], low=57, vel=0.55, gate=0.75)
    s.drums("drum", "kick", "X..x..", allb, vel=0.8)
    s.drums("drum", "frame", "...o.o", allb, midi=nn("A2"), vel=0.6)
    s.drums("drum", "frame", "x.xx.x", [7, 15, 23, 31], midi=nn("A2"), vel=0.7)
    s.drums("shk", "shaker", "xoo xoo".replace(" ", ""), allb)
    return s, dict(verb_t60=1.6, echo_sec=60 / 220 * 3, wind=True)


def track_combat():
    # 4/4, 140 bpm, sixteenth ticks. E minor. 32 bars: A, B (fiddle), A' (fiddle motif), C (brass build).
    s = Song("music_combat", 60 / 140 / 4, 16, 32, "4/4, 140 bpm, E minor (harmonic), driving tense fight")
    s.bus("ost", 0.42, verb=0.08)
    s.bus("stab", 0.55, verb=0.2)
    s.bus("lead", 0.55, verb=0.22, echo=0.1)
    s.bus("brass", 0.42, verb=0.25)
    s.bus("pad", 0.24, verb=0.3)
    s.bus("kick", 0.45, verb=0.05)
    s.bus("snare", 0.5, verb=0.2)
    s.bus("tom", 0.42, verb=0.15)
    s.bus("hat", 0.12, verb=0.05)
    A_ch = ["Em", "Em", "C", "D", "Em", "Em", "C", "B"]
    B_ch = ["Am", "Am", "Em", "Em", "C", "D", "B", "B"]
    C_ch = ["Am", "B", "Em", "C", "Am", "B", "C", "B"]
    ch = split_chords(A_ch + B_ch + A_ch + C_ch)
    allb = range(32)
    gallop = [(0, 1, "R"), (2, 1, "R"), (3, 1, "R"), (4, 1, "8"), (6, 1, "R"), (7, 1, "R"),
              (8, 1, "R"), (10, 1, "R"), (11, 1, "R"), (12, 1, "8"), (14, 1, "5"), (15, 1, "R")]
    bassline(s, "ost", "stacc", ch, allb, gallop, octave_low=nn("E2"), vel=0.85, gate=0.6)
    stab_odd = [(0, 2), (6, 2)]
    stab_even = [(4, 2), (10, 2)]
    for b in list(range(0, 8)) + list(range(16, 24)):
        comp(s, "stab", "stacc", ch, [b], stab_odd if b % 2 == 0 else stab_even, low=59, vel=0.8, gate=0.5)
        comp(s, "stab", "brass", ch, [b], [(0, 2)] if b % 2 == 0 else [(10, 2)], low=52, vel=0.5, gate=0.5)
    B_mel = ("E5/4 A5/4 C6/6 B5/2  A5/4 G5/2 A5/2 E5/8  G5/4 B5/4 E6/6 D6/2  B5/4 A5/2 B5/2 G5/8  "
             "G5/4 E5/4 C6/4 B5/4  A5/4 F#5/4 D6/4 C6/4  B5/6 A5/2 G5/4 F#5/4  D#5/8 F#5/4 B5/4")
    s.line("lead", "fiddle", B_mel, 8, vel=0.8)
    for b in range(8, 16):
        sym = chord_at(ch, b, 0)
        for m in voice(chord_pcs(sym)[1], 52):
            s.note("pad", "lowstr", m, b * 16, 16, 0.4, 0.98)
    A2_mel = ("B5/2 -/2 B5/2 -/2 E6/4 D6/2 B5/2  G5/8 -/8  C6/2 -/2 C6/2 -/2 E6/4 D6/2 C6/2  "
              "A5/8 F#5/4 D5/4  B5/2 -/2 B5/2 -/2 E6/4 F#6/2 G6/2  F#6/4 E6/4 B5/8  "
              "C6/4 B5/4 G5/4 E5/4  D#5/4 F#5/4 B5/8")
    s.line("lead", "fiddle", A2_mel, 16, vel=0.7, gate=0.85, transpose=-12)
    C_mel = ("A3/12 C4/4  B3/12 D#4/4  E4/8 G4/8  G4/8 E4/8  A4/8 C5/4 B4/4  B4/8 A4/4 F#4/4  "
             "G4/8 E4/8  F#4/8 D#4/8")
    s.line("brass", "brass", C_mel, 24, vel=0.85, gate=0.9)
    s.line("brass", "brass", C_mel, 24, vel=0.5, gate=0.9, transpose=-12)
    for b in range(24, 32):
        sym = chord_at(ch, b, 0)
        for m in voice(chord_pcs(sym)[1], 52):
            s.note("pad", "lowstr", m, b * 16, 16, 0.45, 0.98)
    main_beat = [b for b in allb if b < 24]
    s.drums("kick", "kick", "X.......X.x.....", main_beat)
    s.drums("snare", "snare", "....X.......X...", main_beat, vel=0.9)
    s.drums("hat", "hat", "x.o.x.o.x.o.x.o.", allb)
    for b in (3, 7, 11, 15, 19, 23):  # tom fills on the last half of each 4-bar phrase
        for i, tm in enumerate(["A3", "A3", "E3", "E3", "C3", "C3", "A2", "A2"]):
            s.note("tom", "tom", nn(tm), b * 16 + 8 + i, 1, 0.55 + i * 0.05, 1.0)
    # C section: half-time toms, then a snare build into the loop
    s.drums("kick", "kick", "X.......X.......", range(24, 32))
    s.drums("tom", "tom", "....x.......x.x.", range(24, 30), midi=nn("D3"))
    s.drums("snare", "snare", "........x.......", range(24, 30), vel=0.7)
    s.drums("snare", "snare", "x.x.x.x.x.x.x.x.", [30], vel=0.6)
    s.drums("snare", "snare", "xxxxxxxxxxxxXXXX", [31], vel=0.7)
    return s, dict(verb_t60=1.2, echo_sec=60 / 140 * 0.75)


def track_boss():
    # 4/4, 150 bpm, sixteenth ticks. E phrygian (F natural, E major cadences). 32 bars.
    s = Song("music_boss", 60 / 150 / 4, 16, 32, "4/4, 150 bpm, E phrygian / phrygian dominant, heavy boss")
    s.bus("ost", 0.4, verb=0.08)
    s.bus("brass", 0.42, verb=0.22)
    s.bus("fiddle", 0.55, verb=0.2, echo=0.06)
    s.bus("timp", 0.5, verb=0.2)
    s.bus("pad", 0.24, verb=0.3)
    s.bus("kick", 0.42, verb=0.05)
    s.bus("snare", 0.5, verb=0.18)
    s.bus("hat", 0.1, verb=0.05)
    s.bus("crash", 0.14, verb=0.15)
    A_ch = ["Em", "F", "Em", "F", "Em", "F", "G", "F"]
    B_ch = ["Am", "G", "F", "Em", "Am", "G", "F", "E"]
    C_ch = ["Dm", "Em", "F", "G", "F", "Em", "F", "E"]
    ch = split_chords(A_ch + B_ch + C_ch + A_ch)
    allb = range(32)
    ost = [(0, 1, "R"), (1, 1, "R"), (2, 1, "1"), (3, 1, "R"), (4, 1, "R"), (5, 1, "R"), (6, 1, "1"),
           (7, 1, "R"), (8, 1, "R"), (9, 1, "R"), (10, 1, "3"), (11, 1, "R"), (12, 1, "1"),
           (13, 1, "R"), (14, 1, "8"), (15, 1, "R")]
    bassline(s, "ost", "stacc", ch, allb, ost, octave_low=nn("E2"), vel=0.85, gate=0.55)
    # 3-3-2 brass stabs
    for b in allb:
        if 16 <= b < 24:
            hits = [(0, 4)] if b % 2 == 0 else [(0, 2), (6, 2), (12, 2)]
        else:
            hits = [(0, 2), (6, 2), (12, 2)]
        comp(s, "brass", "brass", ch, [b], hits, low=50, vel=0.8, gate=0.55)
    # timpani: root on 1, fifth on beat 3, roll at phrase ends
    for b in allb:
        root = chord_pcs(chord_at(ch, b, 0))[0]
        r = nn("E2") + ((root - 4) % 12)
        if r > nn("A2"):
            r -= 12
        s.note("timp", "timpani", r, b * 16, 4, 0.9, 1.0)
        s.note("timp", "timpani", r + 7, b * 16 + 8, 4, 0.6, 1.0)
        if b % 8 == 7:
            for i in range(8):
                s.note("timp", "timpani", r, b * 16 + 8 + i, 1, 0.35 + 0.07 * i, 0.9)
    B_mel = ("A5/1 C6/1 B5/1 A5/1 G5/1 A5/1 B5/1 C6/1 D6/1 C6/1 B5/1 A5/1 G5/1 F5/1 E5/1 F5/1 "
             "G5/1 B5/1 A5/1 G5/1 F5/1 G5/1 A5/1 B5/1 D6/1 B5/1 A5/1 G5/1 F5/1 E5/1 D5/1 E5/1 "
             "F5/1 A5/1 G5/1 F5/1 E5/1 F5/1 G5/1 A5/1 C6/1 A5/1 G5/1 F5/1 E5/1 D5/1 C5/1 D5/1 "
             "E5/1 G5/1 F5/1 E5/1 D5/1 E5/1 F5/1 G5/1 B5/1 G5/1 F5/1 E5/1 F5/1 E5/1 D5/1 E5/1 "
             "A5/1 E6/1 C6/1 A5/1 B5/1 E6/1 C6/1 B5/1 C6/1 E6/1 D6/1 C6/1 B5/1 A5/1 G5/1 A5/1 "
             "G5/1 D6/1 B5/1 G5/1 A5/1 D6/1 B5/1 A5/1 B5/1 D6/1 C6/1 B5/1 A5/1 G5/1 F5/1 G5/1 "
             "F5/1 C6/1 A5/1 F5/1 G5/1 C6/1 A5/1 G5/1 A5/1 C6/1 B5/1 A5/1 G5/1 F5/1 E5/1 F5/1 "
             "E5/4 G#5/4 B5/4 E6/4")
    s.line("fiddle", "fiddle", B_mel, 8, vel=0.75, gate=0.9)
    C_mel = "D4/8 F4/4 A4/4  G4/8 E4/8  F4/4 A4/4 C5/8  B4/8 D5/4 B4/4  C5/12 A4/4  B4/8 G4/8  A4/4 C5/4 F5/8  E5/8 G#4/4 B4/4"
    s.line("brass", "brass", C_mel, 16, vel=0.75, gate=0.95)
    s.line("fiddle", "fiddle", C_mel, 16, vel=0.5, gate=0.95, transpose=12)
    for b in range(16, 24):
        sym = chord_at(ch, b, 0)
        for m in voice(chord_pcs(sym)[1], 52):
            s.note("pad", "lowstr", m, b * 16, 16, 0.5, 0.98)
    cells = {"Em": "B5/1 A5/1 G5/1 E5/1 B4/1 E5/1 G5/1 A5/1 B5/4 -/4",
             "F": "C6/1 B5/1 A5/1 F5/1 C5/1 F5/1 A5/1 B5/1 C6/4 -/4",
             "G": "D6/1 C6/1 B5/1 G5/1 D5/1 G5/1 B5/1 C6/1 D6/4 -/4"}
    for b in range(24, 32):
        s.line("fiddle", "fiddle", cells[chord_at(ch, b, 0)], b, vel=0.75, gate=0.9)
    s.drums("kick", "kick", "X.....x.x...x...", allb)
    s.drums("snare", "snare", "....X.......X..o", allb, vel=0.9)
    s.drums("hat", "hat", "xoxoxoxoxoxoxoxo", allb)
    s.drums("crash", "crash", "X...............", [0, 8, 16, 24])
    return s, dict(verb_t60=1.5, echo_sec=60 / 150 * 0.75)


def track_victory():
    # Non-looping fanfare: 4/4 at 120 bpm, triplet-eighth ticks (12 per bar). C major.
    s = Song("music_victory", 60 / 120 / 3, 12, 3, "4/4, 120 bpm (triplet grid), C major fanfare sting",
             loop=False)
    s.bus("brass", 0.55, verb=0.3)
    s.bus("brass2", 0.4, verb=0.3)
    s.bus("flute", 0.3, verb=0.35)
    s.bus("timp", 0.6, verb=0.25)
    s.bus("snare", 0.3, verb=0.2)
    s.bus("crash", 0.18, verb=0.25)
    s.bus("pad", 0.3, verb=0.35)
    mel = "C5/1 C5/1 C5/1 G5/3 E5/2 F5/1 G5/3  A5/2 G5/1 F5/2 E5/1 D5/3 G4/1 B4/1 D5/1  C6/12"
    s.line("brass", "brass", mel, 0, vel=0.95, gate=0.92)
    s.line("brass2", "brass", mel, 0, vel=0.6, gate=0.92, harmonize=(scale("C", "major"), -2))
    s.line("flute", "flute", mel, 0, vel=0.6, transpose=12)
    ch = split_chords(["C", "F G", "C"])
    for b, (tk, dur) in ((0, (0, 12)), (1, (0, 6)), (1, (6, 6)), (2, (0, 18))):
        sym = chord_at(ch, b, tk / 12)
        for m in voice(chord_pcs(sym)[1], 48):
            s.note("pad", "lowstr", m, b * 12 + tk, dur, 0.55, 0.95)
            s.note("brass2", "brass", m + 12, b * 12 + tk, min(dur, 3) if b < 2 else dur, 0.35, 0.9)
    for tk, m, v in ((0, "C2", 1.0), (6, "G2", 0.7), (12, "F2", 0.8), (18, "G2", 0.8)):
        s.note("timp", "timpani", nn(m), tk, 3, v, 1.0)
    for i in range(6):  # roll into the final chord
        s.note("timp", "timpani", nn("G2"), 18 + i, 1, 0.4 + i * 0.08, 0.9)
    s.note("timp", "timpani", nn("C2"), 24, 12, 1.0, 1.0)
    s.drums("snare", "snare", "x..x..x..x..", [0], vel=0.6)
    s.drums("snare", "snare", "x..x..xxxxxx", [1], vel=0.7)
    s.note("snare", "snare", 0, 24, 1, 1.0)
    s.note("crash", "crash", 0, 24, 12, 1.0, 1.0)
    return s, dict(verb_t60=1.8, target_rms=0.16, tail_sec=5.4)


TRACKS = {"title": track_title, "island": track_island, "sea": track_sea,
          "combat": track_combat, "boss": track_boss, "victory": track_victory}


# --------------------------------------------------------------------------
# style samples (`samples`): four takes on a more adventurous, orchestral
# sound, written to tools/dev/out/music_samples to listen to and pick from
# --------------------------------------------------------------------------

def _timp_root(ch, b, low="D2", top="A2"):
    root = chord_pcs(chord_at(ch, b, 0))[0]
    r = nn(low) + ((root - nn(low)) % 12)
    return r - 12 if r > nn(top) else r


def _pads(s, bus, inst, ch, bars, low, vel, ticks=None):
    for b in bars:
        for m in voice(chord_pcs(chord_at(ch, b, 0))[1], low):
            s.note(bus, inst, m, b * s.tpb, ticks or s.tpb, vel, 0.98)


def sample_corsair():
    # 6/8, eighth = 216 (dotted quarter 72), D minor. Swashbuckling: galloping
    # low strings, a horn theme, strings take the B section, everyone in A'.
    s = Song("sample1_corsair", 60 / 216, 6, 32,
             "6/8, dotted quarter = 72, D minor: swashbuckling (galloping strings, horns, timpani)")
    s.bus("ost", 0.5, verb=0.1)
    s.bus("horn", 0.5, verb=0.32)
    s.bus("horn2", 0.32, verb=0.32)
    s.bus("str", 0.36, verb=0.32)
    s.bus("strlead", 0.46, verb=0.28)
    s.bus("choir", 0.2, verb=0.42)
    s.bus("timp", 0.5, verb=0.22)
    s.bus("drum", 0.38, verb=0.15)
    s.bus("crash", 0.13, verb=0.25)
    s.bus("swell", 0.12, verb=0.2)
    intro = ["Dm", "Dm", "Dm", "A"]
    A = ["Dm", "Dm", "Bb", "Bb", "Gm", "A", "Dm", "A"]
    B = ["F", "C", "Dm", "Bb", "Gm", "C", "F", "A"]
    turn = ["Bb", "C", "A", "A"]
    ch = split_chords(intro + A + B + A + turn)
    allb = range(32)
    for b in allb:  # the gallop: every eighth, the root in octaves, accents on the beats
        r = _timp_root(ch, b)
        for i in range(6):
            v = 0.95 if i in (0, 3) else 0.5
            s.note("ost", "stacc", r, b * 6 + i, 1, v, 0.6)
            s.note("ost", "stacc", r + 12, b * 6 + i, 1, v * 0.7, 0.6)
    _pads(s, "str", "strings", ch, range(4, 32), 55, 0.4)
    A_mel = ("A4/1 D5/2 D5/1 D5/1 E5/1  F5/3 E5/1 D5/1 E5/1  F5/2 G5/1 A5/2 G5/1  F5/3 D5/3  "
             "G5/2 A5/1 Bb5/2 A5/1  G5/2 F5/1 E5/2 C#5/1  D5/2 E5/1 F5/2 E5/1  E5/3 A4/3")
    B_mel = ("C6/3 A5/2 F5/1  G5/3 E5/2 C5/1  D5/2 F5/1 A5/2 D6/1  C6/3 Bb5/3  "
             "Bb5/2 A5/1 G5/2 D5/1  E5/2 F5/1 G5/2 E5/1  F5/2 A5/1 C6/2 A5/1  C#6/3 E5/3")
    s.line("horn", "horn", A_mel, 4, vel=0.9)
    s.line("strlead", "strings", B_mel, 12, vel=0.85)
    s.line("horn2", "horn", B_mel, 12, vel=0.55, transpose=-12)
    s.line("horn", "horn", A_mel, 20, vel=0.95)
    s.line("strlead", "strings", A_mel, 20, vel=0.6, transpose=12)
    s.line("horn2", "horn", A_mel, 20, vel=0.6, harmonize=(scale("D", "harmonic"), -2))
    _pads(s, "choir", "choir", ch, range(20, 28), 62, 0.5)
    s.line("horn", "horn", "D5/3 F5/3  E5/3 G5/3  C#5/6  E5/3 A5/3", 28, vel=0.9)
    s.line("horn2", "horn", "Bb4/3 D5/3  C5/3 E5/3  A4/6  C#5/3 E5/3", 28, vel=0.6)
    for b in range(4, 32):
        r = _timp_root(ch, b)
        s.note("timp", "timpani", r, b * 6, 3, 0.9, 1.0)
        s.note("timp", "timpani", r, b * 6 + 3, 3, 0.55, 1.0)
        if b in (11, 19, 27, 31):
            for i in range(3):
                s.note("timp", "timpani", r, b * 6 + 3 + i, 1, 0.45 + 0.15 * i, 0.9)
    s.drums("drum", "tom", "X..x..", range(4, 32), midi=nn("A2"), vel=0.7)
    s.drums("drum", "snare", "...X..", range(12, 32), vel=0.55)
    s.drums("crash", "crash", "X.....", [4, 12, 20, 28])
    for b in (3, 19, 27):
        s.note("swell", "swell", 0, b * 6, 6, 1.0, 1.0)
    return s, dict(verb_t60=1.8)


def sample_harbour():
    # 4/4, 92 bpm, eighth ticks. A dorian: a modal, storybook harbour-town
    # theme - harp, pizzicato, an oboe tune, strings and horn in B, flute in A'.
    s = Song("sample2_harbour", 60 / 92 / 2, 8, 24,
             "4/4, 92 bpm, A dorian: modal adventure town (harp, oboe, pizzicato, horn)")
    s.bus("harp", 0.42, verb=0.3)
    s.bus("pizz", 0.5, verb=0.15)
    s.bus("lead", 0.5, verb=0.28, echo=0.08)
    s.bus("lead2", 0.38, verb=0.28)
    s.bus("str", 0.3, verb=0.35)
    s.bus("horn", 0.36, verb=0.32)
    s.bus("glock", 0.16, verb=0.35)
    s.bus("perc", 0.32, verb=0.12)
    s.bus("shk", 0.1, verb=0.08)
    A = ["Am", "D", "Am", "D", "C", "G", "Am", "E"]
    B = ["F", "G", "Am", "Am", "F", "G", "E", "E"]
    ch = split_chords(A + B + A)
    allb = range(24)
    A_mel = ("A4/2 C5/1 E5/1 D5/2 C5/1 B4/1  A4/3 F#4/1 A4/2 D5/2  E5/2 G5/1 E5/1 D5/2 C5/1 D5/1  "
             "E5/3 D5/1 F#5/4  G5/2 E5/1 C5/1 E5/2 G5/2  D5/3 B4/1 G4/2 B4/2  "
             "C5/2 E5/2 A5/2 G5/1 E5/1  B4/4 -/2 E4/1 G#4/1")
    B_mel = ("C6/4 A5/2 F5/2  B5/4 G5/2 D5/2  C6/2 B5/1 A5/1 E5/4  A5/4 G5/2 E5/2  "
             "F5/2 A5/2 C6/2 A5/2  G5/2 B5/2 D6/2 B5/2  G#5/3 A5/1 B5/2 E5/2  B5/4 G#5/2 E5/2")
    s.line("lead", "oboe", A_mel, 0, vel=0.9)
    s.line("lead", "strings", B_mel, 8, vel=0.85)
    s.line("horn", "horn", B_mel, 8, vel=0.5, harmonize=(scale("A", "dorian"), -2), transpose=-12)
    s.line("lead", "flute", A_mel, 16, vel=0.85, transpose=12)
    s.line("lead2", "oboe", A_mel, 16, vel=0.6, harmonize=(scale("A", "dorian"), -2))
    arpeggio(s, "harp", "harp", ch, allb, [0, 1, 2, 3, 4, 3, 2, 1], 1, low=52, vel=0.5, dur=2)
    bassline(s, "pizz", "pizz", ch, allb, [(0, 2, "R"), (4, 2, "5"), (6, 1, "8")], octave_low=nn("A2"), vel=0.8)
    _pads(s, "str", "strings", ch, range(8, 24), 55, 0.35)
    for b in range(16, 24, 2):
        for i, idx in enumerate([4, 5, 6, 5]):
            tones = voice(chord_pcs(chord_at(ch, b, 0))[1], 76)
            s.note("glock", "glock", (tones * 3)[idx % len(tones)], b * 8 + i * 2, 2, 0.5, 1.0)
    s.drums("perc", "frame", "X...x.o.", allb, midi=nn("D2"), vel=0.8)
    s.drums("perc", "snare", "....o...", range(8, 24), vel=0.35)
    s.drums("shk", "shaker", "o.x.o.x.", allb)
    return s, dict(verb_t60=1.7, echo_sec=60 / 92 * 0.75)


def sample_waters():
    # 3/4, quarter = 126, eighth ticks. E minor lifting to G major: a broad,
    # sweeping sea theme - strings over a rolling harp, horns take the B
    # section, all of them with the choir in A'.
    s = Song("sample3_waters", 60 / 126 / 2, 6, 36,
             "3/4, quarter = 126, E minor / G major: sweeping open-sea adventure (strings, horns, choir)")
    s.bus("harp", 0.4, verb=0.32)
    s.bus("low", 0.34, verb=0.2)
    s.bus("waltz", 0.32, verb=0.22)
    s.bus("lead", 0.5, verb=0.3)
    s.bus("horn", 0.48, verb=0.32)
    s.bus("horn2", 0.3, verb=0.32)
    s.bus("str", 0.3, verb=0.35)
    s.bus("choir", 0.2, verb=0.42)
    s.bus("timp", 0.42, verb=0.25)
    s.bus("crash", 0.12, verb=0.3)
    s.bus("swell", 0.12, verb=0.2)
    intro = ["Em", "C", "Em", "D"]
    A = ["Em", "C", "G", "D", "Em", "C", "Am", "B"]
    B = ["G", "D", "Em", "C", "G", "D", "C", "D"]
    tag = ["C", "D", "Em", "Em"]
    ch = split_chords(intro + A + B + A + tag)
    allb = range(36)
    arpeggio(s, "harp", "harp", ch, allb, [0, 1, 2, 3, 2, 1], 1, low=52, vel=0.5, dur=2)
    for b in allb:  # low strings: the root, a bar long
        root = chord_pcs(chord_at(ch, b, 0))[0]
        s.note("low", "lowstr", nn("E2") + ((root - 4) % 12), b * 6, 6, 0.75, 0.98)
    comp(s, "waltz", "stacc", ch, range(12, 36), [(2, 1), (4, 1)], low=55, vel=0.6, gate=0.6)
    A_mel = ("B4/2 E5/2 G5/2  G5/3 F#5/1 E5/2  D5/2 G5/2 B5/2  A5/4 F#5/2  "
             "G5/2 F#5/1 E5/1 B4/2  C5/2 E5/2 G5/2  A5/3 G5/1 F#5/1 E5/1  D#5/4 B4/2")
    B_mel = ("D5/2 G5/2 B5/2  A5/3 G5/1 F#5/2  G5/2 E5/2 B4/2  C5/4 E5/2  "
             "D5/2 G5/2 B5/2  D6/3 C6/1 B5/1 A5/1  G5/2 E5/2 C5/2  D5/4 F#5/2")
    s.line("lead", "strings", A_mel, 4, vel=0.9)
    s.line("horn", "horn", B_mel, 12, vel=0.9)
    s.line("lead", "strings", B_mel, 12, vel=0.45, transpose=12)
    s.line("lead", "strings", A_mel, 20, vel=0.95, transpose=12)
    s.line("horn", "horn", A_mel, 20, vel=0.8)
    s.line("horn2", "horn", A_mel, 20, vel=0.5, harmonize=(scale("E", "minor"), -2), transpose=-12)
    _pads(s, "str", "strings", ch, range(12, 36), 55, 0.32)
    _pads(s, "choir", "choir", ch, range(20, 32), 59, 0.5)
    s.line("horn", "horn", "C5/6  D5/6  E5/6  E5/6", 32, vel=0.8)
    s.line("lead", "strings", "E5/2 G5/2 C6/2  F#5/2 A5/2 D6/2  B5/6  E5/6", 32, vel=0.7)
    for b in allb:
        r = _timp_root(ch, b, "E2", "B2")
        s.note("timp", "timpani", r, b * 6, 2, 0.75 if b >= 12 else 0.45, 1.0)
        if b in (11, 19, 31):
            for i in range(6):
                s.note("timp", "timpani", r, b * 6 + i, 1, 0.3 + 0.1 * i, 0.9)
    s.drums("crash", "crash", "X.....", [12, 20, 32])
    for b in (11, 19):
        s.note("swell", "swell", 0, b * 6, 6, 1.0, 1.0)
    return s, dict(verb_t60=2.0)


def sample_storm():
    # 4/4, 144 bpm, sixteenth ticks. C minor: a driving, heroic battle piece -
    # spiccato strings in sixteenths, taiko, a horn call, brass stabs, the
    # choir and sixteenth runs in B, a snare roll back into the loop.
    s = Song("sample4_storm", 60 / 144 / 4, 16, 24,
             "4/4, 144 bpm, C minor: driving heroic battle (spiccato strings, taiko, horns, choir)")
    s.bus("ost", 0.42, verb=0.1)
    s.bus("horn", 0.5, verb=0.3)
    s.bus("horn2", 0.32, verb=0.3)
    s.bus("brass", 0.4, verb=0.25)
    s.bus("run", 0.34, verb=0.22)
    s.bus("str", 0.28, verb=0.32)
    s.bus("choir", 0.22, verb=0.42)
    s.bus("taiko", 0.5, verb=0.22)
    s.bus("snare", 0.4, verb=0.2)
    s.bus("hat", 0.1, verb=0.05)
    s.bus("crash", 0.13, verb=0.25)
    s.bus("swell", 0.12, verb=0.2)
    intro = ["Cm", "Cm", "Ab", "Bb"]
    A = ["Cm", "Ab", "Eb", "Bb", "Cm", "Ab", "Fm", "G"]
    B = ["Ab", "Bb", "Cm", "Cm", "Ab", "Bb", "G", "G"]
    outro = ["Ab", "Bb", "G", "G"]
    ch = split_chords(intro + A + B + outro)
    allb = range(24)
    ost = [(i, 1, "8" if i in (3, 11) else "5" if i in (7, 14) else "R") for i in range(16)]
    bassline(s, "ost", "stacc", ch, allb, ost, octave_low=nn("C2"), vel=0.8, gate=0.5)
    A_mel = ("G4/4 C5/4 Eb5/6 D5/2  C5/4 Ab4/4 Eb5/8  Bb4/4 Eb5/4 G5/6 F5/2  D5/12 Bb4/4  "
             "G5/4 Eb5/4 C6/6 Bb5/2  Ab5/4 G5/4 Eb5/8  F5/4 Ab5/4 C6/4 Ab5/4  B5/8 G5/4 D5/4")
    s.line("horn", "horn", A_mel, 4, vel=0.95)
    s.line("horn2", "horn", A_mel, 4, vel=0.55, transpose=-12)
    for b in range(4, 12):  # brass stabs under the horn call
        comp(s, "brass", "brass", ch, [b], [(0, 2), (6, 2), (12, 2)], low=48, vel=0.55, gate=0.5)
    B_horn = "C5/16  D5/16  Eb5/8 G5/8  C6/16  Ab5/8 C6/8  Bb5/8 D6/8  B5/16  D6/8 B5/8"
    s.line("horn", "horn", B_horn, 12, vel=0.9)
    arpeggio(s, "run", "fiddle", ch, range(12, 20), [0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 2, 3, 4, 5, 6, 5], 1,
             low=60, vel=0.45, dur=1, gate=0.8)
    _pads(s, "choir", "choir", ch, range(12, 24), 60, 0.55)
    _pads(s, "str", "strings", ch, range(4, 24), 55, 0.32)
    comp(s, "brass", "brass", ch, range(20, 24), [(0, 4), (8, 4)], low=48, vel=0.6, gate=0.7)
    s.line("horn", "horn", "Ab4/8 C5/8  Bb4/8 D5/8  B4/16  D5/8 G5/8", 20, vel=0.85)
    s.drums("taiko", "taiko", "X.....x...X.....", allb, midi=nn("G1"), vel=0.9)
    s.drums("taiko", "tom", "........x.....x.", range(4, 24), midi=nn("C3"), vel=0.6)
    s.drums("snare", "snare", "....X.......X...", range(4, 22), vel=0.8)
    s.drums("hat", "hat", "x.o.x.o.x.o.x.o.", range(4, 24))
    s.drums("snare", "snare", "x.x.x.x.x.x.x.x.", [22], vel=0.55)
    s.drums("snare", "snare", "xxxxxxxxxxxxXXXX", [23], vel=0.65)
    s.drums("crash", "crash", "X...............", [4, 12, 20])
    for b in (3, 11):
        s.note("swell", "swell", 0, b * 16, 16, 1.0, 1.0)
    return s, dict(verb_t60=1.5, echo_sec=60 / 144 * 0.75)


# (Zach's picks, round 1: Corsair's sound, Waters' tunes; the harbour calmer)
WATERS_A = ("B4/2 E5/2 G5/2  G5/3 F#5/1 E5/2  D5/2 G5/2 B5/2  A5/4 F#5/2  "
            "G5/2 F#5/1 E5/1 B4/2  C5/2 E5/2 G5/2  A5/3 G5/1 F#5/1 E5/1  D#5/4 B4/2")
WATERS_B = ("D5/2 G5/2 B5/2  A5/3 G5/1 F#5/2  G5/2 E5/2 B4/2  C5/4 E5/2  "
            "D5/2 G5/2 B5/2  D6/3 C6/1 B5/1 A5/1  G5/2 E5/2 C5/2  D5/4 F#5/2")


def sample_corsair_waters():
    # Corsair's band (6/8 gallop, horns, timpani, choir) playing Waters' tunes:
    # a 3/4 bar of Waters is six eighths, the same as a 6/8 bar here.
    # Eighth = 216 (dotted quarter 72), E minor lifting to G major.
    s = Song("sample5_corsair_waters", 60 / 216, 6, 32,
             "6/8, dotted quarter = 72, E minor / G major: Corsair's gallop and horns with Waters' tunes")
    s.bus("ost", 0.5, verb=0.1)
    s.bus("horn", 0.5, verb=0.32)
    s.bus("horn2", 0.32, verb=0.32)
    s.bus("str", 0.34, verb=0.32)
    s.bus("strlead", 0.46, verb=0.28)
    s.bus("harp", 0.3, verb=0.3)
    s.bus("choir", 0.2, verb=0.42)
    s.bus("timp", 0.5, verb=0.22)
    s.bus("drum", 0.38, verb=0.15)
    s.bus("crash", 0.13, verb=0.25)
    s.bus("swell", 0.12, verb=0.2)
    intro = ["Em", "Em", "C", "D"]
    A = ["Em", "C", "G", "D", "Em", "C", "Am", "B"]
    B = ["G", "D", "Em", "C", "G", "D", "C", "D"]
    turn = ["C", "D", "B", "B"]
    ch = split_chords(intro + A + B + A + turn)
    allb = range(32)
    for b in allb:
        r = _timp_root(ch, b, "E2", "B2")
        for i in range(6):
            v = 0.95 if i in (0, 3) else 0.5
            s.note("ost", "stacc", r, b * 6 + i, 1, v, 0.6)
            s.note("ost", "stacc", r + 12, b * 6 + i, 1, v * 0.7, 0.6)
    _pads(s, "str", "strings", ch, range(4, 32), 55, 0.38)
    arpeggio(s, "harp", "harp", ch, range(12, 20), [0, 1, 2, 3, 2, 1], 1, low=52, vel=0.45, dur=2)
    s.line("horn", "horn", WATERS_A, 4, vel=0.9)
    s.line("strlead", "strings", WATERS_B, 12, vel=0.85, transpose=12)
    s.line("horn2", "horn", WATERS_B, 12, vel=0.6)
    s.line("horn", "horn", WATERS_A, 20, vel=0.95)
    s.line("strlead", "strings", WATERS_A, 20, vel=0.65, transpose=12)
    s.line("horn2", "horn", WATERS_A, 20, vel=0.55, harmonize=(scale("E", "harmonic"), -2), transpose=-12)
    _pads(s, "choir", "choir", ch, range(20, 28), 59, 0.5)
    s.line("horn", "horn", "E5/3 G5/3  F#5/3 A5/3  D#5/6  F#5/3 B5/3", 28, vel=0.9)
    s.line("horn2", "horn", "C5/3 E5/3  D5/3 F#5/3  B4/6  D#5/3 F#5/3", 28, vel=0.6)
    for b in range(4, 32):
        r = _timp_root(ch, b, "E2", "B2")
        s.note("timp", "timpani", r, b * 6, 3, 0.9, 1.0)
        s.note("timp", "timpani", r, b * 6 + 3, 3, 0.55, 1.0)
        if b in (11, 19, 27, 31):
            for i in range(3):
                s.note("timp", "timpani", r, b * 6 + 3 + i, 1, 0.45 + 0.15 * i, 0.9)
    s.drums("drum", "tom", "X..x..", range(4, 32), midi=nn("B2"), vel=0.7)
    s.drums("drum", "snare", "...X..", range(12, 32), vel=0.55)
    s.drums("crash", "crash", "X.....", [4, 12, 20, 28])
    for b in (3, 19, 27):
        s.note("swell", "swell", 0, b * 6, 6, 1.0, 1.0)
    return s, dict(verb_t60=1.8)


def sample_harbour_calm():
    # The harbour theme, calmer and warmer for a town: slower (80 bpm), the
    # tune on low strings (viola/cello range) and a soft oboe, a darker harp
    # in long rolls, pizzicato bass, horn pads; no flute, no glockenspiel.
    s = Song("sample6_harbour_calm", 60 / 80 / 2, 8, 24,
             "4/4, 80 bpm, A dorian: calm warm town (low strings, oboe, soft harp, horn pads)")
    s.bus("harp", 0.4, verb=0.34)
    s.bus("pizz", 0.42, verb=0.18)
    s.bus("lead", 0.5, verb=0.32)
    s.bus("lead2", 0.34, verb=0.32)
    s.bus("str", 0.3, verb=0.38)
    s.bus("horn", 0.24, verb=0.38)
    s.bus("perc", 0.2, verb=0.15)
    A = ["Am", "D", "Am", "D", "C", "G", "Am", "E"]
    B = ["F", "G", "Am", "Am", "F", "G", "E", "E"]
    ch = split_chords(A + B + A)
    allb = range(24)
    A_mel = ("A4/2 C5/1 E5/1 D5/2 C5/1 B4/1  A4/3 F#4/1 A4/2 D5/2  E5/2 G5/1 E5/1 D5/2 C5/1 D5/1  "
             "E5/3 D5/1 F#5/4  G5/2 E5/1 C5/1 E5/2 G5/2  D5/3 B4/1 G4/2 B4/2  "
             "C5/2 E5/2 A5/2 G5/1 E5/1  B4/4 -/2 E4/1 G#4/1")
    B_mel = ("C6/4 A5/2 F5/2  B5/4 G5/2 D5/2  C6/2 B5/1 A5/1 E5/4  A5/4 G5/2 E5/2  "
             "F5/2 A5/2 C6/2 A5/2  G5/2 B5/2 D6/2 B5/2  G#5/3 A5/1 B5/2 E5/2  B5/4 G#5/2 E5/2")
    s.line("lead", "strings", A_mel, 0, vel=0.85, transpose=-12)
    s.line("lead", "oboe", B_mel, 8, vel=0.7, transpose=-12)
    s.line("lead2", "strings", B_mel, 8, vel=0.4, harmonize=(scale("A", "dorian"), -2), transpose=-24)
    s.line("lead", "strings", A_mel, 16, vel=0.8, transpose=-12)
    s.line("lead2", "oboe", A_mel, 16, vel=0.5, harmonize=(scale("A", "dorian"), 2))
    arpeggio(s, "harp", "harp_dark", ch, allb, [0, 2, 3, 2], 2, low=45, vel=0.5, dur=4)
    bassline(s, "pizz", "pizz", ch, allb, [(0, 3, "R"), (4, 3, "5")], octave_low=nn("A2"), vel=0.7)
    _pads(s, "str", "strings", ch, allb, 50, 0.32)
    _pads(s, "horn", "horn", ch, range(8, 24), 48, 0.35)
    s.drums("perc", "frame", "X.......", allb, midi=nn("D2"), vel=0.6)
    return s, dict(verb_t60=2.0)


SAMPLES = {"corsair": sample_corsair, "harbour": sample_harbour, "waters": sample_waters,
           "storm": sample_storm, "corsair_waters": sample_corsair_waters, "harbour_calm": sample_harbour_calm}
SAMPLE_OUT = os.path.join(ROOT, "tools", "dev", "out", "music_samples")


# --------------------------------------------------------------------------
# output
# --------------------------------------------------------------------------

def write_wav(path, data):
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def to_ogg(wav_path):
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        print("    ffmpeg not found: keeping", os.path.basename(wav_path))
        return None
    ogg = wav_path[:-4] + ".ogg"
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav_path,
                    "-c:a", "libvorbis", "-q:a", "3", ogg], check=True)
    os.remove(wav_path)
    return ogg


def wind_layer(n, seed=17, swells=4):
    """Breathy wind bed that loops exactly: circularly filtered noise and an
    amplitude swell with an integer number of cycles over the loop."""
    rng = np.random.default_rng(seed)
    x = rng.standard_normal(n)
    x = apply_filter(x, butter(2, [250, 1400], "band", fs=SR, output="sos"), True)
    t = np.arange(n) / n
    sw = 0.35 + 0.65 * (0.5 - 0.5 * np.cos(2 * np.pi * swells * t)) ** 2
    return normpeak(x) * sw


def build(key, table=None, out_dir=OUT):
    song, opts = (table or TRACKS)[key]()
    buses = song.render()
    if opts.get("wind"):
        buses["wind"] = buses["wind"] + wind_layer(song.length)
    trim = None if song.loop else int(opts.get("tail_sec", 5.0) * SR)
    mix = mixdown(song, buses, verb_t60=opts.get("verb_t60", 1.4), echo_sec=opts.get("echo_sec"),
                  target_rms=opts.get("target_rms", TARGET_RMS), trim=trim)
    os.makedirs(out_dir, exist_ok=True)
    wav = os.path.join(out_dir, song.name + ".wav")
    write_wav(wav, mix)
    pcm = np.clip(mix, -1, 1)
    secs = len(mix) / SR
    bar_sec = song.tpb * song.tick_sec
    print(f"  {song.name}: {song.info}")
    print(f"    {'loop' if song.loop else 'sting'} {secs:.4f}s = {len(mix)} samples"
          + (f" = {song.bars} bars x {bar_sec:.4f}s" if song.loop else "")
          + f" | peak {np.max(np.abs(pcm)):.3f} rms {np.sqrt(np.mean(pcm ** 2)):.3f}")
    if song.loop:
        d = abs(pcm[-1] - pcm[0])
        typ = np.mean(np.abs(np.diff(pcm)))
        print(f"    seam |x[-1]-x[0]| = {d:.4f} (mean |dx| {typ:.4f}, max |dx| {np.max(np.abs(np.diff(pcm))):.4f})")
    out = to_ogg(wav)
    return song.name, out or wav, len(mix)


def main(argv=None):
    wanted = list(sys.argv[1:] if argv is None else argv) or list(TRACKS)
    if wanted[0] == "samples":
        # style samples: `samples` (all) or `samples corsair storm`
        keys = wanted[1:] or list(SAMPLES)
        print("Generating style samples ->", os.path.relpath(SAMPLE_OUT, ROOT))
        for k in keys:
            _cache.clear()
            build(k, SAMPLES, SAMPLE_OUT)
        print("done.")
        return
    bad = [w for w in wanted if w not in TRACKS]
    if bad:
        print("unknown track(s):", bad, "available:", list(TRACKS))
        sys.exit(1)
    print("Generating retro music ->", os.path.relpath(OUT, ROOT))
    for k in wanted:
        _cache.clear()
        build(k)
    print("done.")


if __name__ == "__main__":
    main()
