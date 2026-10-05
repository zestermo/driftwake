#!/usr/bin/env python3
"""
Driftwake retro audio generator: dialogue blips, ocean ambience, campfire crackle.
Low sample rate on purpose (22.05 kHz) for a PS1-ish crunch.

Usage (from the project root):
    pip install numpy scipy
    python tools/texture_gen/gen_psx_audio.py              # everything
    python tools/texture_gen/gen_psx_audio.py cannon horn  # only the named sounds
Output: assets/audio/*.wav
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


def blip(freq, dur=0.045, name="blip"):
    t = np.arange(int(SR * dur)) / SR
    sq = np.sign(np.sin(2 * np.pi * freq * t)) * 0.35
    env = np.minimum(1, t / 0.004) * np.exp(-t * 40)
    write_wav(name, sq * env)


def ocean_loop(seconds=12.0):
    rng = np.random.default_rng(7)
    n = int(SR * seconds)
    white = rng.standard_normal(n)
    brown = np.cumsum(white)
    brown -= lowpass(brown, 0.0005)  # remove drift
    brown /= np.max(np.abs(brown))
    t = np.arange(n) / SR
    # swells: integer cycles over the loop so it wraps cleanly
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * t * (3 / seconds)) ** 2
    hiss = lowpass(white, 0.25) * 0.15 * (swell ** 3)
    data = brown * 0.6 * swell + hiss
    # crossfade the ends for a seamless loop
    fade = int(SR * 0.5)
    ramp_ = np.linspace(0, 1, fade)
    data[:fade] = data[:fade] * ramp_ + data[-fade:] * (1 - ramp_)
    data = data[:-fade]
    data /= np.max(np.abs(data)) * 1.6
    write_wav("ocean_loop", data)


def campfire_loop(seconds=6.0):
    rng = np.random.default_rng(11)
    n = int(SR * seconds)
    base = lowpass(rng.standard_normal(n), 0.05) * 0.25
    for _ in range(int(seconds * 14)):
        p = rng.integers(0, n - 400)
        L = rng.integers(40, 300)
        base[p:p + L] += rng.standard_normal(L) * np.exp(-np.arange(L) / (L / 4)) * rng.uniform(0.3, 0.9)
    fade = int(SR * 0.3)
    r = np.linspace(0, 1, fade)
    base[:fade] = base[:fade] * r + base[-fade:] * (1 - r)
    base = base[:-fade]
    base /= np.max(np.abs(base)) * 1.8
    write_wav("campfire_loop", base)


def chime():
    t = np.arange(int(SR * 1.6)) / SR
    tone = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((392, 0.5), (587, 0.35), (784, 0.25), (1175, 0.12)))
    env = np.minimum(1, t / 0.01) * np.exp(-t * 2.2)
    write_wav("discover_chime", tone * env * 0.5)


def bandpass_noise(n, rng, lo_alpha, hi_alpha):
    w = rng.standard_normal(n)
    return lowpass(w, hi_alpha) - lowpass(w, lo_alpha)


def whoosh(name, dur=0.26, f0=0.05, f1=0.35, gain=0.9, seed=31):
    """Swept band of noise: swing / dodge whoosh."""
    rng = np.random.default_rng(seed)
    n = int(SR * dur)
    w = rng.standard_normal(n)
    out = np.zeros(n)
    acc = 0.0
    acc2 = 0.0
    for i in range(n):
        t = i / n
        a = f0 + (f1 - f0) * (np.sin(t * np.pi))  # cutoff rises then falls
        acc += a * (w[i] - acc)
        acc2 += (a * 0.35) * (acc - acc2)
        out[i] = acc - acc2
    env = np.sin(np.linspace(0, np.pi, n)) ** 1.5
    out = out * env
    out /= np.max(np.abs(out)) + 1e-9
    write_wav(name, out * gain)


def hit_sound():
    rng = np.random.default_rng(41)
    n = int(SR * 0.18)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * (140 - 260 * t) * t) * np.exp(-t * 28)
    crack = rng.standard_normal(n) * np.exp(-t * 60)
    crack = crack - lowpass(crack, 0.08)
    out = thump * 0.8 + crack * 0.6
    out /= np.max(np.abs(out))
    write_wav("hit", out * 0.9)


def step_sound():
    rng = np.random.default_rng(51)
    n = int(SR * 0.07)
    t = np.arange(n) / SR
    out = lowpass(rng.standard_normal(n), 0.12) * np.exp(-t * 70)
    out += np.sin(2 * np.pi * 90 * t) * np.exp(-t * 50) * 0.6
    out /= np.max(np.abs(out))
    write_wav("step", out * 0.7)


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


def land_sound():
    rng = np.random.default_rng(61)
    n = int(SR * 0.16)
    t = np.arange(n) / SR
    out = lowpass(rng.standard_normal(n), 0.06) * np.exp(-t * 35) * 1.5
    out += np.sin(2 * np.pi * (85 - 120 * t) * t) * np.exp(-t * 30)
    out /= np.max(np.abs(out))
    write_wav("land", out * 0.8)


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


def thud_sound():
    """Heavy body thud: shell bonks into a wall, a body hits the ground."""
    rng = np.random.default_rng(97)
    n = int(SR * 0.3)
    t = np.arange(n) / SR
    f = 95 - 50 * np.minimum(t / 0.12, 1.0)
    ph = np.cumsum(2 * np.pi * f / SR)
    body = np.sin(ph) * np.minimum(1, t / 0.002) * np.exp(-t * 16)
    knock = lowpass(rng.standard_normal(n), 0.2) * np.exp(-t * 70)
    out = body * 1.1 + knock * 0.9
    out = lowpass(out, 0.4)
    out /= np.max(np.abs(out))
    write_wav("thud", out * 0.9)


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


def splash_sound():
    """Water splash: a burst of bright noise with a hollow plop under it."""
    rng = np.random.default_rng(101)
    n = int(SR * 0.45)
    t = np.arange(n) / SR
    w = rng.standard_normal(n)
    hiss = w - lowpass(w, 0.12)
    hiss = lowpass(hiss, 0.5) * np.exp(-t * 9) * np.minimum(1, t / 0.006)
    f = 260 - 160 * np.minimum(t / 0.06, 1.0)
    ph = np.cumsum(2 * np.pi * f / SR)
    plop = np.sin(ph) * np.exp(-t * 30) * 0.7
    drops = np.zeros(n)
    for _ in range(14):
        p0 = rng.integers(int(SR * 0.04), n - 300)
        L = rng.integers(60, 200)
        tt = np.arange(L) / SR
        drops[p0:p0 + L] += np.sin(2 * np.pi * rng.uniform(900, 2200) * tt) * np.exp(-tt * 120) * rng.uniform(0.1, 0.3)
    out = hiss * 1.0 + plop + drops
    out /= np.max(np.abs(out))
    write_wav("splash", out * 0.75)


def gunshot_sound():
    """Flintlock shot: a cracking burst of noise over a deep boom, short tail."""
    rng = np.random.default_rng(113)
    n = int(SR * 0.7)
    t = np.arange(n) / SR
    w = rng.standard_normal(n)
    crack = (w - lowpass(w, 0.25)) * np.exp(-t * 55) * np.minimum(1, t / 0.0015)
    f = 70 - 30 * np.minimum(t / 0.2, 1.0)
    ph = np.cumsum(2 * np.pi * f / SR)
    boom = np.sin(ph) * np.exp(-t * 9) * np.minimum(1, t / 0.003)
    tail = lowpass(rng.standard_normal(n), 0.04) * np.exp(-t * 6) * 2.0
    out = crack * 1.2 + boom * 0.9 + tail * 0.6
    out = lowpass(out, 0.6)
    out /= np.max(np.abs(out))
    write_wav("gunshot", out * 0.9)


def parry_sound():
    """Parry: a bright metallic ting (inharmonic bell partials) on a hard click."""
    rng = np.random.default_rng(127)
    n = int(SR * 0.55)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, decay in ((1.0, 1.0, 9.0), (2.76, 0.55, 14.0), (5.40, 0.3, 22.0), (8.93, 0.15, 30.0)):
        f = 1450 * ratio
        out += np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * amp * np.exp(-t * decay)
    w = rng.standard_normal(n)
    click = (w - lowpass(w, 0.4)) * np.exp(-t * 160)
    out = out * np.minimum(1, t / 0.0008) + click * 1.4
    out /= np.max(np.abs(out))
    write_wav("parry", out * 0.7)


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


def block_sound():
    """Blocking a blow: a dull, heavy clank."""
    rng = np.random.default_rng(157)
    n = int(SR * 0.3)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, decay in ((1.0, 1.0, 22.0), (2.3, 0.5, 30.0), (3.9, 0.25, 40.0)):
        out += np.sin(2 * np.pi * 420 * ratio * t + rng.uniform(0, 6.28)) * amp * np.exp(-t * decay)
    w = rng.standard_normal(n)
    out += lowpass(w, 0.25) * np.exp(-t * 60) * 2.0
    out = lowpass(out, 0.6)
    out /= np.max(np.abs(out))
    write_wav("block", out * 0.75)


def peril_sound():
    """An unblockable attack's warning: a sharp rising sting."""
    n = int(SR * 0.4)
    t = np.arange(n) / SR
    f = np.interp(t, [0, 0.08, 0.4], [700, 1500, 1350])
    ph = np.cumsum(2 * np.pi * f / SR)
    tone = np.sign(np.sin(ph)) * 0.5 + np.sin(2 * ph) * 0.3
    env = np.minimum(1, t / 0.005) * np.exp(-t * 7.0)
    out = lowpass(tone * env, 0.55)
    out /= np.max(np.abs(out))
    write_wav("peril", out * 0.6)


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


def cannon_sound():
    """Ship cannon: a sharp crack, a very deep 60->40 Hz boom and a long rolling
    rumble with a couple of reflections off the water. Much heavier than gunshot."""
    rng = np.random.default_rng(163)
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
    out = crack * 1.0 + blast * 0.9 + boom * 1.1 + rumble * 0.9
    # distant reflections of the blast
    for delay, gain in ((0.19, 0.35), (0.43, 0.2), (0.71, 0.1)):
        d = int(SR * delay)
        out[d:] += lpf(crack + blast, 0.12)[: n - d] * gain
    out = lpf(out, 0.55)
    finish("cannon", out, 0.9, fade=0.35)


def cannon_hit_sound():
    """Cannonball impact: a noisy explosion, splintering wood crackle, falling debris."""
    rng = np.random.default_rng(167)
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
    finish("cannon_hit", out, 0.9, fade=0.2)


def wood_crack_sound():
    """Hull taking a hit: a splintering crunch, then a strained timber creak."""
    rng = np.random.default_rng(173)
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
    finish("wood_crack", out, 0.85, fade=0.05)


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


SOUNDS = [
    ("blip", lambda: blip(520, name="blip")),
    ("blip_low", lambda: blip(330, name="blip_low")),
    ("blip_high", lambda: blip(780, name="blip_high")),
    ("select", lambda: blip(660, dur=0.07, name="select")),
    ("ocean_loop", ocean_loop),
    ("campfire_loop", campfire_loop),
    ("discover_chime", chime),
    ("whoosh", lambda: whoosh("whoosh")),
    ("whoosh_big", lambda: whoosh("whoosh_big", dur=0.42, f0=0.03, f1=0.22, seed=33)),
    ("hit", hit_sound),
    ("step", step_sound),
    ("jump", jump_sound),
    ("land", land_sound),
    ("chitter", chitter_sound),
    ("bug_hiss", bug_hiss_sound),
    ("thud", thud_sound),
    ("coin", coin_sound),
    ("splash", splash_sound),
    ("gunshot", gunshot_sound),
    ("parry", parry_sound),
    ("fire_burst", fire_burst_sound),
    ("fire_blast", fire_blast_sound),
    ("crunch", crunch_sound),
    ("howl", howl_sound),
    ("haki", haki_sound),
    ("block", block_sound),
    ("peril", peril_sound),
    ("cannon", cannon_sound),
    ("cannon_hit", cannon_hit_sound),
    ("wood_crack", wood_crack_sound),
    ("horn", horn_sound),
    ("roar", roar_sound),
    ("bell", bell_sound),
    ("splash_big", splash_big_sound),
    ("rope", rope_sound),
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
