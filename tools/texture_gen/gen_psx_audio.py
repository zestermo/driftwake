#!/usr/bin/env python3
"""
Driftwake retro audio generator: dialogue blips, ocean ambience, campfire crackle.
Low sample rate on purpose (22.05 kHz) for a PS1-ish crunch.

Usage (from the project root):
    pip install numpy
    python tools/texture_gen/gen_psx_audio.py
Output: assets/audio/*.wav
"""
import os
import wave

import numpy as np

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


def main():
    os.makedirs(OUT, exist_ok=True)
    print("Generating retro audio ->", os.path.relpath(OUT, ROOT))
    blip(520, name="blip")
    blip(330, name="blip_low")
    blip(780, name="blip_high")
    blip(660, dur=0.07, name="select")
    ocean_loop()
    campfire_loop()
    chime()
    whoosh("whoosh")
    whoosh("whoosh_big", dur=0.42, f0=0.03, f1=0.22, seed=33)
    hit_sound()
    step_sound()
    jump_sound()
    land_sound()
    chitter_sound()
    bug_hiss_sound()
    thud_sound()
    coin_sound()
    splash_sound()
    print("done.")


if __name__ == "__main__":
    main()
