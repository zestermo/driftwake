#!/usr/bin/env python3
"""
Driftwake retro audio generator: dialogue blips, ocean ambience, campfire crackle.
Low sample rate on purpose (22.05 kHz) for a PS1-ish crunch.

Usage (from the project root):
    pip install numpy scipy
    python tools/texture_gen/gen_psx_audio.py              # everything
    python tools/texture_gen/gen_psx_audio.py cannon horn  # only the named sounds
Output: assets/audio/*.wav. A sound with takes is written as name_1.wav,
name_2.wav... and FX plays them at random (never the same twice running).
Loudness: the newer sounds are levelled by loudness (K-weighted, see
audio_report.py), not by peak, so a click and a roar sit where they should.
"""
import os
import sys
import wave

import numpy as np

try:
    from scipy.signal import lfilter, iirpeak
except ImportError:  # the older sounds only need numpy
    lfilter = None
    iirpeak = None

try:
    from audio_report import loudness as _measure_lufs
except ImportError:
    _measure_lufs = None

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")
SR = 22050


def write_wav(name, data):
    data = np.clip(data, -1, 1)
    pcm = (data * 32000).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("  wrote", os.path.relpath(path, ROOT), f"{len(data) / SR:.2f}s")


def lowpass(x, alpha):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def lpf(x, alpha):
    """Same one-pole lowpass as lowpass(), but vectorised through scipy."""
    if lfilter is None:
        return lowpass(x, alpha)
    return lfilter([alpha], [1.0, alpha - 1.0], x)


def hpf(x, alpha):
    return x - lpf(x, alpha)


def resonate(x, freq, q):
    """Two-pole resonant bandpass (wood / hull / formant bodies)."""
    b, a = iirpeak(freq, q, fs=SR)
    return lfilter(b, a, x)


def finish(name, out, peak=0.9, fade=0.0):
    if fade > 0:
        k = int(SR * fade)
        out[-k:] *= np.linspace(1, 0, k) ** 2
    out = out - np.mean(out)
    out /= np.max(np.abs(out)) + 1e-9
    write_wav(name, out * peak)


def campfire_loop(seconds=13.0):
    """A campfire: a low breathy roar and pops and crackles in uneven bursts
    (built circularly: no seam)."""
    rng = np.random.default_rng(11)
    n = int(SR * seconds)
    base = _shape(n, rng, lambda f: _hp(f, 60) * _lp(f, 500, 1)) * 0.3 * (0.7 + 0.3 * _cenv(n, rng, 0.4))
    busy = _cenv(n, rng, 0.5)
    for _ in range(int(seconds * 16)):
        at = int(rng.integers(0, n))
        if rng.random() > 0.3 + 0.7 * busy[at]:
            continue
        L = int(rng.integers(40, 300))
        pop = rng.standard_normal(L) * np.exp(-np.arange(L) / (L / 4)) * rng.uniform(0.3, 0.9)
        _place(base, lpf(pop, 0.5), at)
    _write_loop("campfire_loop", base, -30.0)


def chime():
    t = np.arange(int(SR * 1.6)) / SR
    tone = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((392, 0.5), (587, 0.35), (784, 0.25), (1175, 0.12)))
    env = np.minimum(1, t / 0.01) * np.exp(-t * 2.2)
    write_wav("discover_chime", tone * env * 0.5)


def jump_sound():
    """Push-off thud: a low body thump plus a short muffled scuff of boots."""
    rng = np.random.default_rng(71)
    n = int(SR * 0.2)
    t = np.arange(n) / SR
    f = 110 - 50 * np.minimum(t / 0.08, 1.0)  # 110 Hz sagging to 60 Hz
    ph = np.cumsum(2 * np.pi * f / SR)
    thump = np.sin(ph) * np.minimum(1, t / 0.003) * np.exp(-t * 26)
    scuff = lowpass(rng.standard_normal(n), 0.09) * np.exp(-t * 55)
    scuff -= lowpass(scuff, 0.01)  # drop the rumble, keep the dull "fff"
    out = thump * 1.0 + scuff * 1.6
    out = lowpass(out, 0.35)
    out /= np.max(np.abs(out))
    write_wav("jump", out * 0.85)


def skid_sound():
    """Boots scraping to a stop on dirt: gritty noise, the grit thinning out."""
    rng = np.random.default_rng(81)
    n = int(SR * 0.34)
    t = np.arange(n) / SR
    w = rng.standard_normal(n)
    out = np.zeros(n)
    acc = 0.0
    acc2 = 0.0
    for i in range(n):
        a = 0.32 - 0.22 * (i / n)  # the scrape's pitch drops as it slows
        acc += a * (w[i] - acc)
        acc2 += 0.03 * (acc - acc2)
        out[i] = acc - acc2
    # grain: little bursts as the sole catches and slips
    grain = 0.55 + 0.45 * (lpf(np.abs(rng.standard_normal(n)), 0.02) > 0.75)
    env = np.minimum(1, t / 0.012) * np.exp(-t * 7.5)
    thump = np.sin(2 * np.pi * 75 * t) * np.exp(-t * 40) * 0.5
    finish("skid", out * grain * env + thump, 0.8, fade=0.05)


def chitter_sound():
    """Scuttlebug chitter: fast clicking bursts with a raspy hiss under them."""
    rng = np.random.default_rng(83)
    n = int(SR * 0.32)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k in range(9):
        p0 = int(SR * (0.012 + k * 0.032 + rng.uniform(-0.004, 0.004)))
        L = int(SR * 0.012)
        if p0 + L >= n:
            break
        tt = np.arange(L) / SR
        click = np.sign(np.sin(2 * np.pi * rng.uniform(1300, 1900) * tt)) * np.exp(-tt * 380)
        out[p0:p0 + L] += click * rng.uniform(0.5, 1.0)
    hiss = rng.standard_normal(n)
    hiss -= lowpass(hiss, 0.3)
    out += hiss * 0.18 * np.sin(np.pi * t / t[-1])
    out /= np.max(np.abs(out))
    write_wav("chitter", out * 0.6)


def bug_hiss_sound():
    """Rear-up telegraph: a rising raspy hiss with scraping clicks."""
    rng = np.random.default_rng(89)
    n = int(SR * 0.6)
    t = np.arange(n) / SR
    w = rng.standard_normal(n)
    hp = w - lowpass(w, 0.18)
    env = np.minimum(1, t / 0.35) ** 1.5 * np.exp(-np.maximum(t - 0.45, 0) * 20)
    rasp = 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 38 * t))
    out = hp * env * rasp
    out /= np.max(np.abs(out))
    write_wav("bug_hiss", out * 0.55)


def coin_sound():
    """Gold pickup: two bright square-ish pings."""
    out = np.zeros(int(SR * 0.28))
    for start, f in ((0.0, 988), (0.07, 1319)):
        L = int(SR * 0.2)
        t = np.arange(L) / SR
        tone = (np.sin(2 * np.pi * f * t) + 0.3 * np.sign(np.sin(2 * np.pi * f * t))) * np.exp(-t * 18)
        p0 = int(SR * start)
        out[p0:p0 + L] += tone[: len(out) - p0]
    out /= np.max(np.abs(out))
    write_wav("coin", out * 0.45)


def fire_burst_sound():
    """Fire: a breathy roar that swells and dies (fireballs, flame dashes)."""
    rng = np.random.default_rng(131)
    n = int(SR * 0.6)
    t = np.arange(n) / SR
    w = rng.standard_normal(n)
    roar = lowpass(w, 0.09) * 3.0 + (w - lowpass(w, 0.3)) * 0.25
    env = np.minimum(1, t / 0.05) * np.exp(-t * 5.5)
    crack = np.zeros(n)
    for _ in range(18):
        p0 = rng.integers(0, n - 200)
        L = rng.integers(30, 120)
        crack[p0:p0 + L] += rng.standard_normal(L) * np.exp(-np.arange(L) / 20.0) * rng.uniform(0.2, 0.6)
    out = roar * env + crack * env
    out = lowpass(out, 0.7)
    out /= np.max(np.abs(out))
    write_wav("fire_burst", out * 0.8)


def fire_blast_sound():
    """Big fire explosion: deep thump, roaring wash, crackling tail."""
    rng = np.random.default_rng(137)
    n = int(SR * 1.5)
    t = np.arange(n) / SR
    f = 55 - 25 * np.minimum(t / 0.4, 1.0)
    boom = np.sin(np.cumsum(2 * np.pi * f / SR)) * np.exp(-t * 4.0) * np.minimum(1, t / 0.004)
    w = rng.standard_normal(n)
    wash = lowpass(w, 0.06) * 3.5 * np.minimum(1, t / 0.03) * np.exp(-t * 2.4)
    crack = np.zeros(n)
    for _ in range(40):
        p0 = rng.integers(int(SR * 0.05), n - 200)
        L = rng.integers(30, 150)
        crack[p0:p0 + L] += rng.standard_normal(L) * np.exp(-np.arange(L) / 25.0) * rng.uniform(0.1, 0.4)
    crack *= np.exp(-t * 1.6)
    out = boom * 1.1 + wash + crack
    out = lowpass(out, 0.65)
    out /= np.max(np.abs(out))
    write_wav("fire_blast", out * 0.95)


def crunch_sound():
    """Biting into a fruit: three wet crunches."""
    rng = np.random.default_rng(139)
    out = np.zeros(int(SR * 0.5))
    for start in (0.0, 0.11, 0.24):
        L = int(SR * 0.09)
        tt = np.arange(L) / SR
        w = rng.standard_normal(L)
        c = (lowpass(w, 0.35) * 1.5 + (w - lowpass(w, 0.5)) * 0.5) * np.exp(-tt * 45) * np.minimum(1, tt / 0.002)
        p0 = int(SR * start)
        out[p0:p0 + L] += c * rng.uniform(0.6, 1.0)
    out /= np.max(np.abs(out))
    write_wav("crunch", out * 0.6)


def howl_sound():
    """A wolf's howl: a rising then long falling tone with vibrato and breath."""
    rng = np.random.default_rng(149)
    n = int(SR * 1.6)
    t = np.arange(n) / SR
    f = np.interp(t, [0, 0.25, 0.7, 1.6], [330, 560, 520, 300])
    f = f * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * t))
    ph = np.cumsum(2 * np.pi * f / SR)
    tone = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    breath = lowpass(rng.standard_normal(n), 0.2) * 0.4
    env = np.minimum(1, t / 0.12) * np.clip((1.6 - t) / 0.6, 0, 1)
    out = (tone + breath) * env
    out = lowpass(out, 0.5)
    out /= np.max(np.abs(out))
    write_wav("howl", out * 0.7)


def haki_sound():
    """Armament Haki: a rushing swell into a deep, distorted boom, with electric
    crackle and a dark metallic shimmer ringing out."""
    rng = np.random.default_rng(151)
    n = int(SR * 1.1)
    t = np.arange(n) / SR
    out = np.zeros(n)
    hit = 0.16
    # swell: filtered noise rising into the hit
    w = rng.standard_normal(n)
    swell = lowpass(w, 0.08) * 2.5 * np.clip(t / hit, 0, 1) ** 2 * (t < hit)
    out += swell
    # boom: a pitch-dropping sine, driven hard
    tb = np.clip(t - hit, 0, None)
    f = 130 * np.exp(-tb * 7.0) + 38
    ph = np.cumsum(2 * np.pi * f / SR)
    boom = np.tanh(np.sin(ph) * 3.0) * np.exp(-tb * 3.2) * (t >= hit)
    out += boom * 1.2
    # crackle: short bright bursts of static
    crack = np.zeros(n)
    hp = w - lowpass(w, 0.5)
    for _ in range(40):
        p0 = int(hit * SR) + rng.integers(0, int(0.7 * SR))
        L = rng.integers(20, 90)
        if p0 + L < n:
            crack[p0:p0 + L] += hp[p0:p0 + L] * rng.uniform(0.3, 1.0) * np.exp(-np.arange(L) / 18.0)
    out += crack * np.exp(-tb * 2.5) * 0.9
    # dark shimmer
    for ratio, amp in ((1.0, 0.35), (2.41, 0.2), (3.87, 0.12)):
        out += np.sin(2 * np.pi * 520 * ratio * tb) * amp * np.exp(-tb * 4.5) * (t >= hit)
    out = lowpass(out, 0.75)
    out /= np.max(np.abs(out))
    write_wav("haki", out * 0.85)


def _sweep_sine(t, f):
    return np.sin(np.cumsum(2 * np.pi * f / SR))


def _scatter_bursts(n, rng, count, t0, t1, freq_lo, freq_hi, len_lo, len_hi, amp_decay=0.0):
    """Short decaying resonant 'ticks' scattered in time (splinters, debris, drops)."""
    out = np.zeros(n)
    for _ in range(count):
        p0 = int(SR * (t0 + (t1 - t0) * rng.random() ** 1.6))
        L = int(rng.integers(len_lo, len_hi))
        if p0 + L >= n:
            continue
        tt = np.arange(L) / SR
        f = rng.uniform(freq_lo, freq_hi)
        tick = np.sin(2 * np.pi * f * tt + rng.uniform(0, 6.28)) * (0.5 + 0.5 * rng.standard_normal(L))
        tick *= np.exp(-tt * rng.uniform(150, 400))
        out[p0:p0 + L] += tick * rng.uniform(0.3, 1.0) * np.exp(-amp_decay * p0 / SR)
    return out


def cannon_sound(name="cannon", seed=163):
    """Ship cannon: a sharp crack, a very deep 60->40 Hz boom, a mid crump (so
    it carries on small speakers) and a long rolling rumble with a couple of
    reflections off the water. Much heavier than gunshot."""
    rng = np.random.default_rng(seed)
    n = int(SR * 2.0)
    t = np.arange(n) / SR
    w = rng.standard_normal(n)
    crack = hpf(w, 0.3) * np.exp(-t * 75) * np.minimum(1, t / 0.0008)
    blast = lpf(w, 0.07) * np.exp(-t * 13) * np.minimum(1, t / 0.002) * 3.0
    f = 60 - 20 * np.minimum(t / 0.6, 1.0) ** 0.7
    ph = np.cumsum(2 * np.pi * f / SR)
    boom = np.tanh(2.4 * np.sin(ph)) * np.exp(-t * 2.4) * np.minimum(1, t / 0.004)
    boom += np.sin(2 * ph) * 0.35 * np.exp(-t * 4.0)  # 2nd harmonic: audible on small speakers
    flutter = 1 + 0.6 * lpf(rng.standard_normal(n), 0.0015) / 0.03
    rumble = lpf(lpf(rng.standard_normal(n), 0.03), 0.05)
    rumble = rumble / (np.max(np.abs(rumble)) + 1e-9)
    rumble *= np.clip(flutter, 0.2, 2.0) * np.minimum(1, t / 0.06) * np.exp(-t * 1.6)
    crump = _noise(n, rng, 150, 700) * np.exp(-t * 9) * np.minimum(1, t / 0.003)
    out = crack * 1.0 + blast * 0.9 + boom * 1.1 + rumble * 0.9 + crump * 2.2
    # distant reflections of the blast
    for delay, gain in ((0.19, 0.35), (0.43, 0.2), (0.71, 0.1)):
        d = int(SR * delay)
        out[d:] += lpf(crack + blast, 0.12)[: n - d] * gain
    out = lpf(out, 0.55)
    _write_shot(name, out, -13.0, fade=0.35)


def cannon_hit_sound(name="cannon_hit", seed=167):
    """Cannonball impact: a noisy explosion, splintering wood crackle, falling debris."""
    rng = np.random.default_rng(seed)
    n = int(SR * 1.0)
    t = np.arange(n) / SR
    w = rng.standard_normal(n)
    burst = lpf(w, 0.14) * np.exp(-t * 7) * np.minimum(1, t / 0.002) * 2.5
    crack = hpf(w, 0.35) * np.exp(-t * 45)
    f = 75 - 40 * np.minimum(t / 0.35, 1.0)
    boom = np.tanh(2.0 * _sweep_sine(t, f)) * np.exp(-t * 5.0) * np.minimum(1, t / 0.003)
    splinter = _scatter_bursts(n, rng, 70, 0.01, 0.55, 700, 3200, 60, 260, amp_decay=3.0)
    splinter = resonate(splinter, 1100, 2.0) * 1.3 + splinter * 0.6
    debris = _scatter_bursts(n, rng, 25, 0.25, 0.95, 300, 1200, 80, 300, amp_decay=2.0) * 0.5
    out = burst + crack * 0.8 + boom * 1.0 + splinter * 0.9 + debris
    out = lpf(out, 0.6)
    _write_shot(name, out, -14.0, fade=0.2)


def wood_crack_sound(name="wood_crack", seed=173):
    """Hull taking a hit: a splintering crunch, then a strained timber creak."""
    rng = np.random.default_rng(seed)
    n = int(SR * 0.6)
    t = np.arange(n) / SR
    # crunch: dense impulses through woody resonances
    imp = np.zeros(n)
    k = int(SR * 0.16)
    hits = rng.random(k) < np.linspace(0.25, 0.02, k)
    imp[:k] = hits * rng.uniform(-1, 1, k)
    crunch = resonate(imp, 520, 3.0) * 1.2 + resonate(imp, 1350, 4.0) * 0.8 + hpf(imp, 0.5) * 0.4
    crunch += lpf(rng.standard_normal(n), 0.12) * np.exp(-t * 30) * 1.2
    # creak: stick-slip pulse train with a wandering rate
    rate = np.interp(t, [0, 0.12, 0.3, 0.6], [55, 70, 105, 75])
    ph = np.cumsum(rate / SR)
    pulses = np.diff(np.floor(ph), prepend=0.0) * (1 + 0.3 * rng.standard_normal(n))
    creak_env = np.clip((t - 0.1) / 0.06, 0, 1) * np.clip((0.6 - t) / 0.15, 0, 1)
    creak = (resonate(pulses, 680, 9.0) + resonate(pulses, 1450, 12.0) * 0.5) * creak_env
    creak /= np.max(np.abs(creak)) + 1e-9
    crunch /= np.max(np.abs(crunch)) + 1e-9
    out = crunch * 1.0 + creak * 0.55
    out = lpf(out, 0.7)
    _write_shot(name, out, -16.0, fade=0.05)


def horn_sound():
    """Pirate alarm horn / conch: two brassy blasts (low then a fourth up) from
    detuned saws and a square, swelling through a lowpass, with slight vibrato."""
    rng = np.random.default_rng(179)
    n = int(SR * 1.4)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for start, end, f0 in ((0.0, 0.56, 147.0), (0.6, 1.4, 196.0)):
        m = (t >= start) & (t < end)
        tt = t[m] - start
        L = end - start
        vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * tt) * np.minimum(1, tt / 0.25)
        scoop = 1 - 0.04 * np.exp(-tt / 0.04)
        raw = np.zeros(len(tt))
        for cents, amp, p0 in ((0, 1.0, 0.0), (9, 0.4, 0.33), (-8, 0.4, 0.71)):
            f = f0 * 2 ** (cents / 1200) * vib * scoop
            ph = np.cumsum(f / SR) + p0
            raw += amp * (2 * (ph % 1.0) - 1)  # saw
        ph = np.cumsum(f0 * vib * scoop / SR)
        raw += 0.5 * np.sign(np.sin(2 * np.pi * ph))  # square
        env = np.minimum(1, tt / 0.07) * np.clip((L - tt) / 0.12, 0, 1)
        dark = lpf(lpf(raw, 0.05), 0.08)
        bright = lpf(raw, 0.22)
        b = env ** 1.5 * 0.8
        tone = (dark * (1 - b) + bright * b) * env
        blat = lpf(rng.standard_normal(len(tt)), 0.2) * np.exp(-tt * 40) * 0.5
        out[m] += tone + blat
    out = np.tanh(out * 0.6)
    out = lpf(out, 0.5)
    finish("horn", out, 0.75, fade=0.05)


def roar_sound():
    """Pirate captain's battle roar: a gravelly human 'RAAAH'. Rough glottal saw
    with period-doubling growl, rasp noise locked to the pitch, through 'R'->'AA'
    vocal formants, ending on a breathy 'H'."""
    rng = np.random.default_rng(181)
    n = int(SR * 1.3)
    t = np.arange(n) / SR
    f0 = np.interp(t, [0, 0.1, 0.45, 1.0, 1.3], [100, 138, 132, 118, 82])
    jitter = lpf(rng.standard_normal(n), 0.01)
    f0 = f0 * (1 + 0.6 * jitter)
    ph = np.cumsum(f0 / SR)
    K = 36
    src = np.zeros(n)
    for k in range(1, K + 1):
        src += np.sin(2 * np.pi * k * ph) / k
    growl = 1 + 0.55 * np.sin(np.pi * ph)  # subharmonic (period doubling) = vocal growl
    rough = 1 + 0.5 * lpf(rng.standard_normal(n), 0.02) / 0.1
    src = src * growl * np.clip(rough, 0.2, 2.0)
    rasp = rng.standard_normal(n) * (0.4 + 0.6 * (np.sin(2 * np.pi * ph) > 0.3))
    voice = np.tanh(src * 1.8) + rasp * 0.35
    # parallel formant banks: 'R' (low F3) and 'AA', crossfaded
    def formants(x, fs):
        y = np.zeros_like(x)
        for f, q, g in fs:
            y += resonate(x, f, q) * g
        return y
    r_vow = formants(voice, ((480, 6, 1.0), (1250, 9, 0.6), (1650, 10, 0.4)))
    aa_vow = formants(voice, ((760, 6, 1.0), (1180, 8, 0.75), (2550, 12, 0.35), (3400, 14, 0.15)))
    x = np.clip((t - 0.04) / 0.12, 0, 1)
    vow = r_vow * (1 - x) + aa_vow * x
    env = np.minimum(1, t / 0.07) * np.clip((1.22 - t) / 0.4, 0, 1)
    breath_env = np.exp(-((t - 1.12) / 0.12) ** 2)
    breath = resonate(rng.standard_normal(n), 900, 1.5) * breath_env * 0.25
    out = vow * env + breath * np.max(np.abs(vow)) * 0.5
    out = lpf(out, 0.6)
    finish("roar", out, 0.85, fade=0.08)


def gull_sound():
    """Herring gull: a harsh, nasal 'kyow!' then two shorter 'kyow kyow'. A rough
    saw sliding up then down, rasp locked to the pitch, through nasal formants."""
    rng = np.random.default_rng(271)
    calls = [(0.0, 0.42, 1.0), (0.55, 0.22, 0.8), (0.82, 0.2, 0.7)]
    n = int(SR * 1.15)
    out = np.zeros(n)
    for t0, dur, amp in calls:
        m = int(SR * dur)
        t = np.arange(m) / SR
        x = t / dur
        f0 = np.interp(x, [0, 0.15, 0.4, 1.0], [900, 1500, 1350, 760])
        f0 = f0 * (1 + 0.02 * np.sin(2 * np.pi * 38 * t))
        ph = np.cumsum(f0 / SR)
        src = np.zeros(m)
        for k in range(1, 9):
            src += np.sin(2 * np.pi * k * ph) / k
        rasp = rng.standard_normal(m) * (0.3 + 0.4 * (np.sin(2 * np.pi * ph) > 0.5))
        v = np.tanh(src * 2.2) + rasp * 0.35
        y = resonate(v, 2600, 4) + resonate(v, 1400, 5) * 0.7 + resonate(v, 4200, 8) * 0.3
        env = np.minimum(1, t / 0.012) * np.clip((dur - t) / 0.08, 0, 1) * (1 - 0.3 * x)
        i0 = int(SR * t0)
        out[i0:i0 + m] += y * env * amp
    out = hpf(out, 0.08)
    finish("gull", out, 0.8, fade=0.03)


def bell_sound():
    """Ship's bell, two quick strikes ('ding-ding'), inharmonic bell partials."""
    rng = np.random.default_rng(191)
    n = int(SR * 1.6)
    t = np.arange(n) / SR
    base = 640.0
    partials = ((0.5, 0.35, 1.6), (1.0, 1.0, 2.6), (1.2, 0.55, 3.4), (1.5, 0.35, 4.2),
                (2.0, 0.6, 5.0), (2.51, 0.25, 7.0), (2.66, 0.2, 8.0), (3.01, 0.12, 10.0))
    phases = rng.uniform(0, 6.28, len(partials))
    out = np.zeros(n)
    for start, amp in ((0.0, 1.0), (0.3, 0.85)):
        m = t >= start
        tt = t[m] - start
        ring = np.zeros(len(tt))
        for (r, a, d), p in zip(partials, phases):
            ring += np.sin(2 * np.pi * base * r * tt + p) * a * np.exp(-tt * d)
        click = hpf(rng.standard_normal(len(tt)), 0.4) * np.exp(-tt * 300) * 1.5
        out[m] += (ring * np.minimum(1, tt / 0.001) + click) * amp
    out = lpf(out, 0.7)
    finish("bell", out, 0.75, fade=0.3)


def splash_big_sound():
    """Cannonball into the sea: a deep plunge 'whump' and cavity gulp, a tall
    spray hiss, the water column crashing back, and scattered drops."""
    rng = np.random.default_rng(193)
    n = int(SR * 1.0)
    t = np.arange(n) / SR
    whump = np.sin(np.cumsum(2 * np.pi * (45 + 100 * np.exp(-t / 0.05)) / SR)) * np.exp(-t * 8) * 1.2
    tg = np.clip(t - 0.1, 0, None)
    gulp = np.sin(np.cumsum(2 * np.pi * (170 + 280 * np.minimum(tg / 0.18, 1)) / SR))
    gulp *= np.exp(-((t - 0.2) / 0.06) ** 2) * 0.55
    w = rng.standard_normal(n)
    spray = lpf(hpf(w, 0.15), 0.55) * np.minimum(1, t / 0.02) * np.exp(-t * 4.2) * 1.4
    crash = lpf(rng.standard_normal(n), 0.12) * np.exp(-((t - 0.5) / 0.14) ** 2) * 1.3
    drops = _scatter_bursts(n, rng, 30, 0.08, 0.95, 900, 2600, 60, 220, amp_decay=1.5) * 0.35
    out = whump + gulp + spray + crash + drops
    out = lpf(out, 0.65)
    finish("splash_big", out, 0.85, fade=0.2)


def rope_sound():
    """Grappling hook / rope: a rising whip whoosh, a snap, a wooden thunk and a
    short rope creak as the line goes taut."""
    rng = np.random.default_rng(197)
    n = int(SR * 0.4)
    t = np.arange(n) / SR
    w = rng.standard_normal(n)
    whip = np.zeros(n)
    acc = acc2 = 0.0
    k = int(SR * 0.13)
    for i in range(k):
        a = 0.04 + 0.5 * (i / k) ** 2
        acc += a * (w[i] - acc)
        acc2 += a * 0.3 * (acc - acc2)
        whip[i] = acc - acc2
    whip *= (t / 0.13) ** 2 * (t < 0.13) * 2.0
    snap = hpf(w, 0.45) * np.exp(-np.clip(t - 0.125, 0, None) * 220) * (t >= 0.125) * 1.2
    tt = np.clip(t - 0.14, 0, None)
    on = t >= 0.14
    thunk = np.sin(np.cumsum(2 * np.pi * (110 + 90 * np.exp(-tt / 0.02)) / SR)) * np.exp(-tt * 28) * on
    thunk += lpf(w, 0.2) * np.exp(-tt * 70) * on * 1.5
    pulses = np.diff(np.floor(np.cumsum(np.interp(t, [0, 0.2, 0.4], [90, 140, 110]) / SR)), prepend=0.0)
    creak = resonate(pulses, 820, 10.0) * np.clip((t - 0.19) / 0.03, 0, 1) * np.clip((0.38 - t) / 0.1, 0, 1)
    creak /= np.max(np.abs(creak)) + 1e-9
    out = whip + snap + thunk * 1.2 + creak * 0.3
    out = lpf(out, 0.7)
    finish("rope", out, 0.8, fade=0.04)


def rain_loop_sound(seconds=17.0):
    """Steady rain: a soft hiss over a low wash, a bed of droplet ticks thick
    and thin by turns (built circularly: no seam)."""
    rng = np.random.default_rng(211)
    n = int(SR * seconds)
    hiss = _shape(n, rng, lambda f: _hp(f, 500) * _lp(f, 3500, 1) * _lp(f, 7000, 2)) * 0.5
    body = _shape(n, rng, lambda f: _hp(f, 70) * _lp(f, 600, 1)) * 0.55
    drops = np.zeros(n)
    for _ in range(int(seconds * 260)):
        L = int(rng.integers(30, 160))
        d = hpf(rng.standard_normal(L), 0.3) * np.exp(-np.arange(L) / (L / 5)) * rng.uniform(0.1, 0.5)
        _place(drops, d, rng.integers(0, n))
    drops = lpf(drops, 0.55) * (0.6 + 0.4 * _cenv(n, rng, 0.3))
    out = (hiss + body) * (0.85 + 0.15 * _cenv(n, rng, 0.2)) + _norm(drops) * 0.35
    _write_loop("rain_loop", out)


# --------------------------------------------------------------------------
# Ambience loops (Ambience mixes them by where you are). Built in the
# frequency domain and placed circularly, so each loops with no seam.
# --------------------------------------------------------------------------

def _norm(x):
    x = x - np.mean(x)
    return x / (np.max(np.abs(x)) + 1e-9)


def _cband(n, rng, lo, hi, tilt=0.0):
    """Band-limited noise that loops (shaped in the frequency domain)."""
    X = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    g = 1.0 / (1 + (lo / np.maximum(f, 1e-3)) ** 4) / (1 + (f / hi) ** 4)
    if tilt:
        g *= (np.maximum(f, 20.0) / 1000.0) ** (-tilt)
    return _norm(np.fft.irfft(X * g, n))


def _cenv(n, rng, rate):
    """A smooth random 0..1 envelope that loops (changing about `rate` times a second)."""
    X = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    g = np.exp(-(f / rate) ** 2)
    g[0] = 0.0
    e = np.fft.irfft(X * g, n)
    return (e - e.min()) / (e.max() - e.min() + 1e-9)


def _place(buf, ev, at):
    """Add an event at sample `at`, wrapping round the loop's end."""
    idx = (int(at) + np.arange(len(ev))) % len(buf)
    np.add.at(buf, idx, ev)


def _burst(rng, secs, lo, hi):
    """A short band of noise for an event (not looped)."""
    n = max(int(secs * SR), 32)
    return _cband(n, rng, lo, hi)


# --- shaping and levelling (2026-10-09 pass) ---

def _hp(f, fc, order=2):
    return 1.0 / np.sqrt(1 + (fc / f) ** (2 * order))


def _lp(f, fc, order=2):
    return 1.0 / np.sqrt(1 + (f / fc) ** (2 * order))


def _shape(n, rng, gain):
    """Noise that loops, coloured by gain(f) (an amplitude curve over frequency)."""
    X = np.fft.rfft(rng.standard_normal(n))
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1e-3)
    g = gain(f)
    g[0] = 0.0
    return _norm(np.fft.irfft(X * g, n))


def _filt(x, gain):
    """Filter a one-shot through gain(f), zero-padded (nothing wraps round)."""
    n = len(x)
    m = 2 * n
    f = np.maximum(np.fft.rfftfreq(m, 1.0 / SR), 1e-3)
    return np.fft.irfft(np.fft.rfft(x, m) * gain(f), m)[:n]


def _noise(n, rng, lo, hi, lo_order=2, hi_order=2):
    return _norm(_filt(rng.standard_normal(n), lambda f: _hp(f, lo, lo_order) * _lp(f, hi, hi_order)))


def _level(x, lufs, looped=False, ceil_db=-1.0, max_squash_db=5.0):
    """Set a sound's loudness (integrated for loops, loudest 400 ms for one-shots).
    Peaks that would pass ceil_db are rounded off by a soft knee (up to
    max_squash_db of them); past that the whole sound is turned down."""
    x = x - np.mean(x)
    x = x / (np.max(np.abs(x)) + 1e-9)
    if _measure_lufs is not None:
        x = x * 10 ** ((lufs - _measure_lufs(x, SR, looped)) / 20)
    ceil = 10 ** (ceil_db / 20)
    pk = np.max(np.abs(x))
    over = 20 * np.log10(pk / ceil) if pk > ceil else 0.0
    if over > max_squash_db:
        x = x * 10 ** (-(over - max_squash_db) / 20)
        print(f"    (turned down {over - max_squash_db:.1f} dB under its loudness target)")
    if over > 0.0:
        knee = ceil * 0.6
        a = np.abs(x)
        hot = a > knee
        x[hot] = np.sign(x[hot]) * (knee + (ceil - knee) * np.tanh((a[hot] - knee) / (ceil - knee)))
    return x


def _fade_out(x, secs):
    k = int(SR * secs)
    x[-k:] *= np.linspace(1, 0, k) ** 2
    return x


def _write_loop(name, out, lufs=-20.0):
    write_wav(name, _level(out, lufs, looped=True))


def _write_shot(name, out, lufs, fade=0.02):
    write_wav(name, _fade_out(_level(out, lufs), fade))


def _thump(t, f_hi, f_lo, tau, decay, atk=0.002):
    """A falling sine knock (a body, a heel, a hull meeting the sea)."""
    f = f_lo + (f_hi - f_lo) * np.exp(-t / tau)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * decay) * np.minimum(1, t / atk)


def _modes(t, rng, modes, atk=0.0008):
    """Damped resonances (freq, amp, decay) struck at once: planks, a boot heel, steel."""
    out = np.zeros(len(t))
    for fr, a, d in modes:
        out += np.sin(2 * np.pi * fr * t + rng.uniform(0, 6.28)) * a * np.exp(-t * d)
    return out * np.minimum(1, t / atk)


def _grains(n, rng, count, t0, t1, src, glen=(0.001, 0.004), decay=0.0):
    """Short windowed slices of `src` scattered over t0..t1 s, thickest early
    (sand crunching, grass rustling, spray pattering down)."""
    out = np.zeros(n)
    for _ in range(count):
        p = int(SR * (t0 + (t1 - t0) * rng.random() ** 1.5))
        L = max(int(SR * rng.uniform(*glen)), 8)
        if p + L >= n:
            continue
        s = int(rng.integers(0, len(src) - L))
        out[p:p + L] += src[s:s + L] * np.hanning(L) * rng.uniform(0.3, 1.0) * np.exp(-decay * p / SR)
    return out


def _churn(n, rng, rate):
    """A random 0..1 flutter about `rate` times a second (water sloshing, leaves)."""
    e = lpf(np.abs(rng.standard_normal(n)), min(rate / SR * 6.0, 0.5))
    return (e - e.min()) / (e.max() - e.min() + 1e-9)


def _delay(x, secs):
    d = int(secs * SR)
    y = np.zeros(len(x))
    y[d:] = x[:len(x) - d]
    return y


def shore_surf_loop(seconds=30.0):
    """Waves breaking on a beach: each builds, crashes and washes back up the
    sand fizzing; five to a loop at uneven gaps, over a low far-off wash."""
    rng = np.random.default_rng(311)
    n = int(SR * seconds)
    out = _cband(n, rng, 50, 600, tilt=0.5) * 0.22 * (0.7 + 0.3 * _cenv(n, rng, 0.15))
    for i in range(5):
        at = int((i * seconds / 5 + rng.uniform(-1.0, 1.0)) * SR) % n
        size = rng.uniform(0.6, 1.0)
        tb = np.linspace(0, 1, int(1.4 * SR))
        build = _burst(rng, 1.4, 80, 900) * tb ** 2 * 0.55 * size
        tc = np.arange(int(0.7 * SR)) / SR
        crash = _burst(rng, 0.7, 150, 5000) * np.exp(-tc * 6) * np.minimum(1, tc / 0.02) * size
        tw = np.arange(int(4.5 * SR)) / SR
        wash = (_burst(rng, 4.5, 1200, 7000) * 0.5 * np.exp(-tw * 0.9)
                + _burst(rng, 4.5, 200, 1500) * 0.45 * np.exp(-tw * 1.4)) * (1 - np.exp(-tw * 6)) * size
        fizz = np.zeros(len(tw))
        for _ in range(int(160 * size)):
            p = int(rng.uniform(0.2, 3.5) * SR)
            L = int(rng.uniform(0.004, 0.02) * SR)
            if p + L < len(fizz):
                fizz[p:p + L] += rng.standard_normal(L) * np.exp(-np.arange(L) / (L / 4)) * rng.uniform(0.1, 0.4)
        _place(out, build, at)
        _place(out, crash, at + len(build))
        _place(out, wash + hpf(fizz, 0.3) * 0.35 * np.exp(-tw * 0.6), at + len(build) + int(0.1 * SR))
    _write_loop("shore_surf_loop", out)


def sea_swell_loop(seconds=47.0):
    """The open sea: a deep slow roll whose swells come at uneven gaps (no
    fixed beat), foam hissing on the big crests and the odd lap of water."""
    rng = np.random.default_rng(313)
    n = int(SR * seconds)
    sw = 0.35 + 0.65 * _cenv(n, rng, 0.11) ** 1.4
    out = _shape(n, rng, lambda f: _hp(f, 30) * _lp(f, 400, 2) * (np.maximum(f, 30) / 100) ** -0.4) * sw
    out += _shape(n, rng, lambda f: _hp(f, 200) * _lp(f, 1200, 1)) * 0.22 * sw ** 2
    crest = np.clip((sw - 0.55) / 0.45, 0.0, 1.0)
    out += _shape(n, rng, lambda f: _hp(f, 900) * _lp(f, 4200, 2)) * 0.2 * crest ** 2 * (0.7 + 0.3 * _cenv(n, rng, 1.5))
    for _ in range(18):
        tl = np.arange(int(0.35 * SR)) / SR
        lap = _burst(rng, 0.35, 200, 1600) * np.exp(-tl * 10) * np.minimum(1, tl / 0.03) * rng.uniform(0.15, 0.35)
        _place(out, lap, rng.integers(0, n))
    _write_loop("sea_swell_loop", out)


def hull_rush_loop(seconds=37.0):
    """Water rushing along a wooden hull under way: a heavy, smooth rush whose
    colour drifts (a darker and a brighter take crossfaded on a slow random
    swell), surging slowly, with a low body under it. No flutter, and nothing
    above a soft roll-off (Ambience layers it with gurgle and foam by speed)."""
    rng = np.random.default_rng(401)
    n = int(SR * seconds)
    dark = _shape(n, rng, lambda f: _hp(f, 60) * _lp(f, 600, 1) * _lp(f, 2600, 2))
    bright = _shape(n, rng, lambda f: _hp(f, 110) * _lp(f, 1200, 1) * _lp(f, 4000, 2))
    body = _shape(n, rng, lambda f: _hp(f, 35) * _lp(f, 170, 2))
    tone = _cenv(n, rng, 0.06)
    surge = 0.55 + 0.45 * _cenv(n, rng, 0.12) ** 1.3
    ripple = 0.88 + 0.12 * _cenv(n, rng, 0.6)
    out = (dark * (1 - tone) + bright * tone * 0.75) * surge * ripple
    out += body * 0.5 * (0.6 + 0.4 * _cenv(n, rng, 0.08))
    _write_loop("hull_rush_loop", out)


def hull_gurgle_loop(seconds=23.0):
    """The water's burble along the planks: bubbles (rising chirps, small ones
    higher and shorter) in clusters that come and go, a churning mid bed and
    now and then a deeper gloop."""
    rng = np.random.default_rng(409)
    n = int(SR * seconds)
    bed = _shape(n, rng, lambda f: _hp(f, 250) * _lp(f, 1300, 2))
    out = bed * 0.3 * (0.25 + 0.75 * _cenv(n, rng, 3.0) ** 2) * (0.6 + 0.4 * _cenv(n, rng, 0.15))
    density = 0.2 + 0.8 * _cenv(n, rng, 0.25) ** 1.5
    t = 0.0
    while t < seconds:
        t += rng.exponential(1.0 / (8.0 + 70.0 * density[int(t * SR) % n]))
        f0 = np.exp(rng.uniform(np.log(320), np.log(2200)))
        L = int(SR * rng.uniform(0.02, 0.05))
        tt = np.arange(L) / SR
        f = f0 * (1 + rng.uniform(0.2, 0.9) * tt / tt[-1])
        bub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * np.pi * f0 * 0.06) * np.minimum(1, tt / 0.0015)
        _place(out, bub * rng.uniform(0.05, 0.22) * (600.0 / f0) ** 0.3, int(t * SR))
    for _ in range(int(seconds * 0.5)):
        L = int(SR * rng.uniform(0.18, 0.4))
        tt = np.arange(L) / SR
        gl = _burst(rng, L / SR, 150, 900) * np.minimum(1, tt / 0.03) * np.exp(-tt * 9)
        gl += _thump(tt, rng.uniform(180, 260), rng.uniform(110, 150), 0.08, 14, 0.01) * 0.5
        _place(out, gl * rng.uniform(0.1, 0.3), rng.integers(0, n))
    _write_loop("hull_gurgle_loop", out)


def hull_foam_loop(seconds=29.0):
    """Whitewater along the waterline at speed: a soft fizz of bursting foam
    that swells and thins (bright, but rolled off: no whistle, no hard edge)."""
    rng = np.random.default_rng(419)
    n = int(SR * seconds)
    hiss = _shape(n, rng, lambda f: _hp(f, 1100) * _lp(f, 2500, 1) * _lp(f, 6000, 2))
    grains = np.zeros(n)
    t = 0.0
    while t < seconds:
        t += rng.exponential(1.0 / 260.0)
        L = int(SR * rng.uniform(0.002, 0.008))
        _place(grains, np.hanning(L) * rng.uniform(0.2, 1.0), int(t * SR))
    fizz = _shape(n, rng, lambda f: _hp(f, 1500) * _lp(f, 5000, 2)) * grains
    swell = 0.35 + 0.65 * _cenv(n, rng, 0.15)
    out = (hiss * 0.45 + _norm(fizz) * 0.8) * swell
    _write_loop("hull_foam_loop", out)


def hull_slap_loop(seconds=19.0):
    """Waves knocking at a hull at rest: hollow slaps and little splashes."""
    rng = np.random.default_rng(319)
    n = int(SR * seconds)
    out = _cband(n, rng, 80, 1200) * 0.15 * (0.6 + 0.4 * _cenv(n, rng, 0.3))
    for _ in range(22):
        L = int(rng.uniform(0.12, 0.25) * SR)
        tt = np.arange(L) / SR
        clop = resonate(rng.standard_normal(L), rng.uniform(280, 600), 6.0) * np.exp(-tt * 25)
        splash = _burst(rng, L / SR, 1200, 5000) * np.exp(-tt * 14) * 0.3
        _place(out, (_norm(clop) * 0.8 + splash) * rng.uniform(0.4, 1.0), rng.integers(0, n))
    _write_loop("hull_slap_loop", out)


def _stick_slip(rng, secs, rate_lo, rate_hi, bodies):
    """A creak: friction pulses at a wandering rate through wood resonances."""
    L = int(secs * SR)
    tt = np.arange(L) / SR
    rate = rate_lo + (rate_hi - rate_lo) * (0.5 + 0.5 * np.sin(2 * np.pi * tt / secs * rng.uniform(0.5, 1.5) + rng.uniform(0, 6)))
    ph = np.cumsum(rate) / SR
    pulses = np.diff(np.floor(ph), prepend=0.0) * rng.uniform(0.6, 1.0, L)
    out = np.zeros(L)
    for fr, q, g in bodies:
        out += resonate(pulses, fr, q) * g
    env = np.sin(np.pi * tt / secs) ** 0.7
    return _norm(out) * env


def ship_creak_loop(seconds=33.0):
    """A wooden ship's timbers working and her ropes straining (sparse)."""
    rng = np.random.default_rng(331)
    n = int(SR * seconds)
    out = _cband(n, rng, 60, 300) * 0.02
    for _ in range(12):
        c = _stick_slip(rng, rng.uniform(0.4, 1.2), 25, 80, [(240, 6, 1.0), (700, 8, 0.6), (1400, 10, 0.25)])
        _place(out, c * rng.uniform(0.4, 0.9), rng.integers(0, n))
    for _ in range(6):
        c = _stick_slip(rng, rng.uniform(0.3, 0.7), 120, 260, [(900, 9, 1.0), (2000, 12, 0.4)])
        _place(out, c * rng.uniform(0.2, 0.45), rng.integers(0, n))
    _write_loop("ship_creak_loop", out)


def wind_loop_sound(seconds=41.0):
    """Sea wind in gusts that come and go at random (they still loop): a low
    roar, a breathy middle rising with each gust, a faint whistle on the peaks."""
    rng = np.random.default_rng(223)
    n = int(SR * seconds)
    gust = 0.3 + 0.7 * _cenv(n, rng, 0.12) ** 1.5
    fast = 0.85 + 0.15 * _cenv(n, rng, 2.0)
    out = (_cband(n, rng, 40, 350, tilt=1.0) + _cband(n, rng, 300, 1600) * 0.5 * gust) * gust * fast
    out += _cband(n, rng, 1500, 5000) * 0.12 * gust ** 2
    out += (_cband(n, rng, 690, 740) + 0.6 * _cband(n, rng, 1030, 1090)) * 0.18 * gust ** 3
    _write_loop("wind_loop", out)


def rigging_wind_loop(seconds=31.0):
    """Wind through a ship's rigging: shrouds moaning and whistling on
    their own slow swells, and a flutter of loose canvas."""
    rng = np.random.default_rng(337)
    n = int(SR * seconds)
    out = np.zeros(n)
    for fr in (520, 780, 1170, 1560):
        out += _cband(n, rng, fr * 0.97, fr * 1.03) * _cenv(n, rng, 0.2) ** 3 * (600.0 / fr)
    flap = 0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(7.0 + 2.0 * _cenv(n, rng, 0.3)) / SR)
    out += _cband(n, rng, 90, 400) * 0.35 * flap ** 4 * _cenv(n, rng, 0.15)
    _write_loop("rigging_wind_loop", out)


def thunder_sound(name="thunder", seed=231, dur=4.5, crack=1.0):
    """Thunder: a sharp crack (close strikes) rolling into long low rumbles."""
    rng = np.random.default_rng(seed)
    n = int(SR * dur)
    t = np.arange(n) / SR
    w = rng.standard_normal(n)
    snap = hpf(w, 0.25) * np.exp(-t * 30) * np.minimum(1, t / 0.002) * crack
    env = np.zeros(n)
    k = 0.05
    while k < dur - 0.5:
        a = rng.uniform(0.4, 1.0) * np.exp(-k * 0.55)
        env += a * np.exp(-np.maximum(t - k, 0) * rng.uniform(1.5, 3.5)) * (t >= k)
        k += rng.uniform(0.12, 0.6)
    rumble = lpf(lpf(rng.standard_normal(n), 0.02), 0.03)
    rumble /= np.max(np.abs(rumble)) + 1e-9
    out = snap * 0.8 + rumble * env * 1.4
    out = lpf(out, 0.4)
    finish(name, out, 0.9, fade=0.8)


# --------------------------------------------------------------------------
# 2026-10-09 pass: footsteps by surface, the ship's spray, takes for the
# combat sounds (FX picks one at random), softer UI tones
# --------------------------------------------------------------------------

STEP_SURFACES = ("sand", "grass", "dirt", "stone", "wood", "water")
STEP_TAKES = 4
STEP_LUFS = {"sand": -21.0, "grass": -22.0, "dirt": -20.0, "stone": -19.5, "wood": -19.0, "water": -19.0}


def _step_contact(surface, rng, n, t, k, s):
    """One foot meeting the ground (s = 1 the heel, less for the roll onto the toe)."""
    if surface == "sand":
        th = _thump(t, 110, 65, 0.02, 30, 0.004) * 0.45
        cr = _grains(n, rng, int(70 * s) + 10, 0.0, 0.09, _noise(n, rng, 900, 4200), (0.0008, 0.003)) * np.exp(-t * 18)
        slide = _noise(n, rng, 180, 1100) * np.exp(-t * 35) * np.minimum(1, t / 0.006) * 0.35
        return (th + cr * 0.9 + slide) * s
    if surface == "grass":
        th = _thump(t, 100, 70, 0.02, 34, 0.004) * 0.4
        rus = _noise(n, rng, 1600, 6500) * _churn(n, rng, 70) * np.minimum(1, t / 0.012) * np.exp(-t * 16) * 0.6
        swish = _grains(n, rng, 6, 0.0, 0.12, _noise(n, rng, 900, 3500), (0.01, 0.03)) * 0.4
        soil = _noise(n, rng, 120, 600) * np.exp(-t * 40) * np.minimum(1, t / 0.004) * 0.25
        return (th + rus + swish + soil) * s
    if surface == "dirt":
        th = _thump(t, 140, 85, 0.015, 40, 0.0015) * 0.85
        knock = _noise(n, rng, 160, 950) * np.exp(-t * 65) * np.minimum(1, t / 0.001) * 1.3
        grit = _grains(n, rng, 14, 0.0, 0.05, _noise(n, rng, 1200, 3800), (0.0006, 0.002)) * 0.35
        return (th + knock + grit) * s
    if surface == "stone":
        click = _noise(n, rng, 1400, 5200) * np.exp(-t * 260) * np.minimum(1, t / 0.0003) * 0.55
        heel = _modes(t, rng, [(rng.uniform(300, 420), 0.5, 70), (rng.uniform(850, 1100), 0.22, 110),
                               (rng.uniform(1900, 2400), 0.1, 160)])
        th = _thump(t, 160, 100, 0.01, 55, 0.001) * 0.45
        grit = _grains(n, rng, 8, 0.0, 0.03, _noise(n, rng, 2000, 5000), (0.0005, 0.0015)) * 0.15
        return (click + heel + th + grit) * s
    if surface == "wood":
        f1 = rng.uniform(135, 185)
        body = _modes(t, rng, [(f1, 1.0, 22), (f1 * rng.uniform(2.2, 2.6), 0.55, 38),
                               (rng.uniform(700, 950), 0.22, 65), (rng.uniform(1500, 1900), 0.08, 110)])
        click = _noise(n, rng, 700, 3200) * np.exp(-t * 180) * np.minimum(1, t / 0.0004) * 0.6
        out = body + click
        if k == 3 and s == 1.0:  # (one take in four: the plank gives a little)
            c = _stick_slip(rng, 0.14, 70, 140, [(620, 8, 1.0), (1350, 10, 0.4)])
            out += _delay(np.pad(c, (0, n - len(c))), 0.05) * 0.12
        return out * s
    # wading: a slosh, a bloop and a few drips (one contact)
    slosh = _noise(n, rng, 220, 2400) * _churn(n, rng, 25) * np.minimum(1, t / 0.02) * np.exp(-t * 9) * 0.8
    plunge = _thump(t, 160, 320, 0.06, 25, 0.006) * 0.35
    drips = _scatter_bursts(n, rng, 6, 0.12, 0.38, 1100, 2600, 40, 120) * 0.2
    return slosh + plunge + drips


def step_takes(surface):
    """Footsteps on a surface: heel then the roll onto the toe, four takes."""
    for k in range(STEP_TAKES):
        rng = np.random.default_rng(1500 + 37 * STEP_SURFACES.index(surface) + k)
        n = int(SR * (0.42 if surface == "water" else 0.24))
        t = np.arange(n) / SR
        out = _step_contact(surface, rng, n, t, k, 1.0)
        if surface != "water":
            out += _delay(_step_contact(surface, rng, n, t, k, rng.uniform(0.35, 0.55)), rng.uniform(0.045, 0.075))
        out = _filt(out, lambda f: _lp(f, 7000, 2))
        _write_shot(f"step_{surface}_{k + 1}", out, STEP_LUFS[surface])


def bow_spray_takes(count=3):
    """The bow driving into a swell: a soft deep whump, the water thrown up
    rushing, a sheet of spray, then it pattering down on deck and sea."""
    for k in range(count):
        rng = np.random.default_rng(1700 + k)
        n = int(SR * 1.8)
        t = np.arange(n) / SR
        whump = _thump(t, rng.uniform(120, 160), rng.uniform(42, 55), 0.05, 7, 0.012) * 0.9
        lift = np.where(t < 0.14, (t / 0.14) ** 1.5, np.exp(-(t - 0.14) * 3.0))
        rush = _noise(n, rng, 180, 1600, 2, 1) * lift
        peak = rng.uniform(0.22, 0.3)
        sp_env = np.where(t < peak, np.exp(-((t - peak) / 0.12) ** 2), np.exp(-(t - peak) * 3.6))
        spray = _noise(n, rng, 1400, 5500) * sp_env * 0.45
        fall = np.exp(-np.clip(t - 0.3, 0, None) * 1.6) * (t > 0.3)
        patter = _grains(n, rng, 160, 0.3, 1.6, _noise(n, rng, 900, 3600), (0.002, 0.006)) * fall * 0.6
        plinks = _scatter_bursts(n, rng, 40, 0.3, 1.5, 1200, 3000, 40, 140, amp_decay=1.5) * 0.15
        out = _filt(whump + rush + spray + patter + plinks, lambda f: _lp(f, 6500, 2))
        _write_shot(f"bow_spray_{k + 1}", out, -15.0, fade=0.3)


def swim_stroke_takes(count=3):
    """An arm pulling through the water: a scoop, a low pull, a drip or two."""
    for k in range(count):
        rng = np.random.default_rng(1750 + k)
        n = int(SR * 0.5)
        t = np.arange(n) / SR
        a = rng.uniform(0.04, 0.07)
        env = np.where(t < a, t / a, np.exp(-(t - a) * 8))
        scoop = _noise(n, rng, 250, 2000) * env * (0.5 + 0.5 * _churn(n, rng, 30))
        pull = _noise(n, rng, 90, 500) * np.where(t < 0.08, t / 0.08, np.exp(-(t - 0.08) * 6)) * 0.4
        drips = _scatter_bursts(n, rng, 5, 0.15, 0.45, 1000, 2400, 40, 120) * 0.15
        _write_shot(f"swim_stroke_{k + 1}", scoop + pull + drips, -20.0, fade=0.08)


def hit_takes(count=4):
    """A blow landing on a body: a deep punch, a slap of skin and cloth, a
    small crack on top, driven a little for weight."""
    for k in range(count):
        rng = np.random.default_rng(1100 + k)
        n = int(SR * 0.26)
        t = np.arange(n) / SR
        f0 = rng.uniform(95, 135)
        punch = np.sin(2 * np.pi * np.cumsum(f0 * (0.6 + np.exp(-t / 0.025))) / SR)
        punch *= np.exp(-t * rng.uniform(26, 32)) * np.minimum(1, t / 0.0015)
        hi = rng.uniform(1800, 2600)
        slap = _noise(n, rng, 350, hi) * np.exp(-t * rng.uniform(38, 55)) * np.minimum(1, t / 0.001)
        crack = _noise(n, rng, 2200, 5500) * np.exp(-t * 180)
        out = punch * 0.7 + slap * rng.uniform(4.0, 5.0) + crack * 1.0
        out = np.tanh(out / (np.max(np.abs(out)) + 1e-9) * 1.6)
        _write_shot(f"hit_{k + 1}", _filt(out, lambda f: _lp(f, 6000, 2)), -14.0, fade=0.03)


def _svf_sweep(x, fc, q):
    """A band-pass that follows fc (Hz, per sample): a whoosh's moving colour."""
    out = np.zeros(len(x))
    low = band = 0.0
    for i in range(len(x)):
        f = 2 * np.sin(np.pi * min(fc[i], 3500.0) / SR)
        low += f * band
        high = x[i] - low - band / q
        band += f * high
        out[i] = band
    return out


def whoosh_takes(name, count, dur, f_lo, f_hi, lufs, seed):
    """A swing cutting the air: noise through a band that sweeps up and back
    (peaking early), with a little low push for weight, rolled off on top."""
    for k in range(count):
        rng = np.random.default_rng(seed + k)
        d = dur * rng.uniform(0.9, 1.1)
        n = int(SR * d)
        x = np.arange(n) / n
        pk = rng.uniform(0.35, 0.45)
        shape = np.where(x < pk, np.sin(0.5 * np.pi * x / pk), np.cos(0.5 * np.pi * (x - pk) / (1 - pk)))
        fc = f_lo + (f_hi * rng.uniform(0.85, 1.15) - f_lo) * shape
        band = _svf_sweep(rng.standard_normal(n), fc, 1.3)
        push = _noise(n, rng, 120, 450) * 0.35
        env = shape ** 1.5
        out = (band / (np.max(np.abs(band)) + 1e-9) + push) * env
        _write_shot(f"{name}_{k + 1}", _filt(out, lambda f: _lp(f, 3800, 2)), lufs, fade=0.02)


def thud_takes(count=3):
    """A heavy body thud: a deep falling knock, and a mid knock on top so it
    still reads on small speakers."""
    for k in range(count):
        rng = np.random.default_rng(1200 + k)
        n = int(SR * 0.32)
        t = np.arange(n) / SR
        body = _thump(t, rng.uniform(85, 105), rng.uniform(42, 50), 0.05, 15, 0.002)
        knock = _noise(n, rng, 200, 900) * np.exp(-t * 45) * np.minimum(1, t / 0.001) * 4.0
        out = np.tanh((body * 1.1 + knock) * 1.3)
        _write_shot(f"thud_{k + 1}", _filt(out, lambda f: _lp(f, 4000, 2)), -15.0, fade=0.04)


def block_takes(count=3):
    """A blow caught on a blade or guard: a short clank (damped inharmonic
    partials, no long ring), the impact's grit and a low knock."""
    for k in range(count):
        rng = np.random.default_rng(1250 + k)
        n = int(SR * 0.32)
        t = np.arange(n) / SR
        b = rng.uniform(380, 520)
        ring = _modes(t, rng, [(b, 1.0, 24), (b * 2.32, 0.55, 32), (b * 3.86, 0.3, 44), (b * 5.1, 0.15, 60)])
        grit = _noise(n, rng, 300, 3000) * np.exp(-t * 90) * np.minimum(1, t / 0.0005) * 1.2
        low = _thump(t, 160, 110, 0.02, 40, 0.001) * 0.5
        _write_shot(f"block_{k + 1}", _filt(ring + grit + low, lambda f: _lp(f, 5500, 2)), -16.0, fade=0.05)


def parry_takes(count=2):
    """Parry: a bright metallic ting (inharmonic bell partials) on a hard click."""
    for k in range(count):
        rng = np.random.default_rng(127 + k)
        n = int(SR * 0.55)
        t = np.arange(n) / SR
        base = (1450, 1330)[k]
        out = _modes(t, rng, [(base, 1.0, 9.0), (base * 2.76, 0.5, 14.0), (base * 5.40, 0.22, 22.0)])
        click = _noise(n, rng, 2000, 6000) * np.exp(-t * 160) * 1.2
        _write_shot(f"parry_{k + 1}", _filt(out + click, lambda f: _lp(f, 7500, 2)), -17.0, fade=0.05)


def gunshot_takes(count=3):
    """Flintlock shot: a sharp crack, the bark of the charge, a boom under it
    and a short rolling tail with a slap back off the surroundings."""
    for k in range(count):
        rng = np.random.default_rng(1300 + k)
        n = int(SR * 0.8)
        t = np.arange(n) / SR
        crack = _noise(n, rng, 1200, 7000) * np.exp(-t * 120) * np.minimum(1, t / 0.0003)
        bark = _noise(n, rng, 250, 1800) * np.exp(-t * 30) * np.minimum(1, t / 0.001)
        boom = _thump(t, rng.uniform(80, 95), rng.uniform(42, 50), 0.06, 10, 0.002)
        tail = _noise(n, rng, 80, 600, 2, 1) * np.exp(-t * 5) * np.minimum(1, t / 0.02) * 0.35
        out = crack * 2.2 + bark * 2.0 + boom * 0.6 + tail
        out += _delay(_filt(out, lambda f: _lp(f, 1500, 1)), rng.uniform(0.08, 0.12)) * 0.2
        out = np.tanh(out / (np.max(np.abs(out)) + 1e-9) * 1.4)
        _write_shot(f"gunshot_{k + 1}", _filt(out, lambda f: _lp(f, 7500, 2)), -14.0, fade=0.15)


def land_takes(count=3):
    """Boots hitting the ground from a jump: a soft low thump and a scuff."""
    for k in range(count):
        rng = np.random.default_rng(1350 + k)
        n = int(SR * 0.2)
        t = np.arange(n) / SR
        th = _thump(t, rng.uniform(110, 130), rng.uniform(55, 70), 0.03, 26, 0.003)
        scuff = _noise(n, rng, 250, 1600) * np.exp(-t * 35) * np.minimum(1, t / 0.004) * 1.4
        _write_shot(f"land_{k + 1}", th + scuff, -17.0, fade=0.04)


def splash_takes(count=3):
    """Water splash: a burst of noise with a hollow plop under it and drops
    falling back (rolled off on top: wet, not hissy)."""
    for k in range(count):
        rng = np.random.default_rng(101 + k * 7)
        n = int(SR * 0.5)
        t = np.arange(n) / SR
        hiss = _noise(n, rng, 400, 3200) * np.exp(-t * rng.uniform(8, 11)) * np.minimum(1, t / 0.006)
        plop = _thump(t, rng.uniform(220, 290), rng.uniform(90, 120), 0.04, 30, 0.002) * 1.0
        drops = _scatter_bursts(n, rng, 14, 0.04, 0.45, 900, 2200, 60, 200) * 0.35
        _write_shot(f"splash_{k + 1}", hiss + plop + drops, -17.0, fade=0.06)


def _soft_tone(t, f, harmonics, decay, atk=0.002):
    """A band-limited tone: a few harmonics (amp per harmonic), no aliasing fizz."""
    out = np.zeros(len(t))
    for i, a in enumerate(harmonics, start=1):
        if f * i < SR * 0.4:
            out += np.sin(2 * np.pi * f * i * t) * a
    return out * np.minimum(1, t / atk) * np.exp(-t * decay)


def ui_blip(name, freq, dur=0.05, lufs=-18.0):
    """A text / UI blip: a soft square-ish voice (odd harmonics, rolled off)."""
    t = np.arange(int(SR * dur)) / SR
    out = _soft_tone(t, freq, [1.0, 0.0, 0.3, 0.0, 0.12, 0.0, 0.05], 40, 0.003)
    write_wav(name, _fade_out(_level(out, lufs), 0.012))


def ui_select():
    """Menu move / pick: a short wooden 'tock' with a fifth above it."""
    rng = np.random.default_rng(1400)
    t = np.arange(int(SR * 0.09)) / SR
    out = _soft_tone(t, 880, [1.0, 0.25], 55, 0.001) + _soft_tone(t, 1320, [0.5], 70, 0.001)
    out += _modes(t, rng, [(440, 0.5, 80)]) + _noise(len(t), rng, 1500, 4000) * np.exp(-t * 400) * 0.2
    write_wav("select", _fade_out(_level(out, -18.0), 0.015))


def peril_sound():
    """An unblockable attack's warning: a sharp rising brassy sting (band-limited)."""
    n = int(SR * 0.42)
    t = np.arange(n) / SR
    f = np.interp(t, [0, 0.08, 0.42], [700, 1500, 1350]) * (1 + 0.01 * np.sin(2 * np.pi * 9 * t))
    ph = np.cumsum(2 * np.pi * f / SR)
    tone = sum(np.sin(k * ph) / k ** 1.1 * (k * 1500 < SR * 0.4) for k in range(1, 7))
    env = np.minimum(1, t / 0.005) * np.exp(-t * 7.0)
    write_wav("peril", _fade_out(_level(tone * env, -16.0), 0.05))


SOUNDS = [
    ("blip", lambda: ui_blip("blip", 520)),
    ("blip_low", lambda: ui_blip("blip_low", 330)),
    ("blip_high", lambda: ui_blip("blip_high", 780)),
    ("select", ui_select),
    ("campfire_loop", campfire_loop),
    ("discover_chime", chime),
    ("whoosh", lambda: whoosh_takes("whoosh", 3, 0.26, 240, 1150, -17.0, 31)),
    ("whoosh_big", lambda: whoosh_takes("whoosh_big", 3, 0.42, 160, 950, -15.0, 33)),
    ("hit", hit_takes),
    ("step", lambda: [step_takes(s) for s in STEP_SURFACES]),
    ("jump", jump_sound),
    ("land", land_takes),
    ("skid", skid_sound),
    ("chitter", chitter_sound),
    ("bug_hiss", bug_hiss_sound),
    ("thud", thud_takes),
    ("coin", coin_sound),
    ("splash", splash_takes),
    ("swim_stroke", swim_stroke_takes),
    ("bow_spray", bow_spray_takes),
    ("gunshot", gunshot_takes),
    ("parry", parry_takes),
    ("fire_burst", fire_burst_sound),
    ("fire_blast", fire_blast_sound),
    ("crunch", crunch_sound),
    ("howl", howl_sound),
    ("haki", haki_sound),
    ("block", block_takes),
    ("peril", peril_sound),
    ("cannon", lambda: [cannon_sound(f"cannon_{k + 1}", 163 + k * 11) for k in range(2)]),
    ("cannon_hit", lambda: [cannon_hit_sound(f"cannon_hit_{k + 1}", 167 + k * 11) for k in range(2)]),
    ("wood_crack", lambda: [wood_crack_sound(f"wood_crack_{k + 1}", 173 + k * 11) for k in range(2)]),
    ("horn", horn_sound),
    ("roar", roar_sound),
    ("bell", bell_sound),
    ("splash_big", splash_big_sound),
    ("rope", rope_sound),
    ("rain_loop", rain_loop_sound),
    ("wind_loop", wind_loop_sound),
    ("rigging_wind_loop", rigging_wind_loop),
    ("shore_surf_loop", shore_surf_loop),
    ("sea_swell_loop", sea_swell_loop),
    ("hull_rush_loop", hull_rush_loop),
    ("hull_gurgle_loop", hull_gurgle_loop),
    ("hull_foam_loop", hull_foam_loop),
    ("hull_slap_loop", hull_slap_loop),
    ("ship_creak_loop", ship_creak_loop),
    ("thunder", lambda: thunder_sound("thunder", 231, 4.5, 1.0)),
    ("thunder_far", lambda: thunder_sound("thunder_far", 237, 5.0, 0.15)),
    ("gull", gull_sound),
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
    print("Generating retro audio ->", os.path.relpath(OUT, ROOT))
    for name, fn in SOUNDS:
        if not wanted or name in wanted:
            fn()
    print("done.")


if __name__ == "__main__":
    main()
