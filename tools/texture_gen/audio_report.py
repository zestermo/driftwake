#!/usr/bin/env python3
"""
Driftwake audio report: measures every sound and music file so the mix can be
judged by numbers as well as by ear.

Per file: length, peak and RMS (dBFS), crest factor, approximate loudness
(K-weighted, LUFS-ish: integrated for loops, loudest 400 ms for one-shots),
spectral centroid, the share of energy per band (the 2-5 kHz band is where
noise turns harsh), the sharpest resonant peak (dB above the 1/3-octave
smoothed spectrum), clipping and DC. Loops also get the seam (the jump from
the last sample to the first against a typical step, and the level change
across it) and their strongest repeat inside the loop (autocorrelation of
the 50 ms loudness envelope: a high score at a short lag = audibly periodic).

Usage (from the project root):
    py tools/texture_gen/audio_report.py                 # everything in assets/audio
    py tools/texture_gen/audio_report.py hull_ step_     # names containing these
.ogg files are decoded with ffmpeg.
"""
import glob
import os
import shutil
import subprocess
import sys
import wave

import numpy as np
from scipy.signal import lfilter, welch

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
AUDIO = os.path.join(ROOT, "assets", "audio")
BANDS = ((0, 200), (200, 1000), (1000, 2000), (2000, 5000), (5000, 20000))


def load(path):
    if path.endswith(".wav"):
        with wave.open(path, "rb") as w:
            sr = w.getframerate()
            ch = w.getnchannels()
            x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
        if ch > 1:
            x = x.reshape(-1, ch).mean(axis=1)
        return x, sr
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        return None, 0
    raw = subprocess.run([ffmpeg, "-loglevel", "error", "-i", path, "-f", "s16le", "-ac", "1", "-"],
                         capture_output=True, check=True).stdout
    sr = 22050
    probe = subprocess.run([ffmpeg, "-i", path], capture_output=True, text=True).stderr
    for tok in probe.split(","):
        if " Hz" in tok:
            sr = int(tok.strip().split()[0])
            break
    return np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0, sr


def _biquad(kind, f0, q, gain_db, sr):
    a = 10 ** (gain_db / 40.0)
    w0 = 2 * np.pi * f0 / sr
    alpha = np.sin(w0) / (2 * q)
    c = np.cos(w0)
    if kind == "hs":
        b = [a * ((a + 1) + (a - 1) * c + 2 * np.sqrt(a) * alpha), -2 * a * ((a - 1) + (a + 1) * c),
             a * ((a + 1) + (a - 1) * c - 2 * np.sqrt(a) * alpha)]
        aa = [(a + 1) - (a - 1) * c + 2 * np.sqrt(a) * alpha, 2 * ((a - 1) - (a + 1) * c),
              (a + 1) - (a - 1) * c - 2 * np.sqrt(a) * alpha]
    else:
        b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
        aa = [1 + alpha, -2 * c, 1 - alpha]
    return np.array(b) / aa[0], np.array(aa) / aa[0]


def k_weight(x, sr):
    b, a = _biquad("hs", 1681.97, 0.7071, 4.0, sr)
    y = lfilter(b, a, x)
    b, a = _biquad("hp", 38.13, 0.5003, 0.0, sr)
    return lfilter(b, a, y)


def loudness(x, sr, looped):
    y = k_weight(x, sr)
    win = int(0.4 * sr)
    hop = int(0.1 * sr)
    if len(y) < win:
        return -0.691 + 10 * np.log10(np.mean(y ** 2) + 1e-12)
    ms = np.array([np.mean(y[i:i + win] ** 2) for i in range(0, len(y) - win + 1, hop)])
    lk = -0.691 + 10 * np.log10(ms + 1e-12)
    if not looped:
        return float(np.max(lk))
    gated = ms[lk > -70]
    if len(gated) == 0:
        return -70.0
    rel = -0.691 + 10 * np.log10(np.mean(gated)) - 10
    gated = ms[lk > rel]
    return float(-0.691 + 10 * np.log10(np.mean(gated) + 1e-12))


def spectrum(x, sr):
    n = min(4096, 1 << int(np.log2(max(len(x), 256))))
    f, p = welch(x, sr, nperseg=n)
    return f, p


def resonance(f, p):
    """The sharpest peak above the 1/3-octave-smoothed spectrum (100 Hz - 8 kHz)."""
    db = 10 * np.log10(p + 1e-20)
    sm = np.empty_like(db)
    for i, fi in enumerate(f):
        lo, hi = fi / 2 ** (1 / 6), fi * 2 ** (1 / 6)
        m = (f >= lo) & (f <= hi)
        sm[i] = np.median(db[m]) if np.any(m) else db[i]
    rng = (f > 100) & (f < 8000)
    if not np.any(rng):
        return 0.0, 0.0
    prom = np.where(rng, db - sm, -99)
    i = int(np.argmax(prom))
    return float(prom[i]), float(f[i])


def env_repeat(x, sr):
    """Strongest repeat inside a loop: circular autocorrelation of the 50 ms
    loudness envelope, best peak with lag 0.5 s .. half the loop."""
    hop = int(0.05 * sr)
    k = len(x) // hop
    if k < 24:
        return 0.0, 0.0
    e = np.sqrt(np.mean(x[:k * hop].reshape(k, hop) ** 2, axis=1))
    e = np.log(e + 1e-6)
    e -= e.mean()
    E = np.fft.rfft(e)
    ac = np.fft.irfft(E * np.conj(E), k)
    ac /= ac[0] + 1e-12
    # (a slow envelope is still like itself a moment later: look past where it first decorrelates)
    below = np.nonzero(ac[1:k // 2] < 0.2)[0]
    lo = max(int(0.5 / 0.05), int(below[0]) + 1 if len(below) else k // 2)
    hi = k // 2
    if hi <= lo:
        return 0.0, 0.0
    i = lo + int(np.argmax(ac[lo:hi]))
    return float(ac[i]), i * 0.05


def seam(x, sr):
    d = abs(x[-1] - x[0])
    typ = np.median(np.abs(np.diff(x))) + 1e-9
    w = int(0.05 * sr)
    a = np.sqrt(np.mean(x[-w:] ** 2)) + 1e-9
    b = np.sqrt(np.mean(x[:w] ** 2)) + 1e-9
    return d / typ, 20 * np.log10(b / a)


def analyse(path):
    x, sr = load(path)
    if x is None or len(x) == 0:
        return None
    name = os.path.splitext(os.path.basename(path))[0]
    looped = name.endswith("_loop") or (name.startswith("music_") and name != "music_victory")
    peak = np.max(np.abs(x)) + 1e-12
    rms = np.sqrt(np.mean(x ** 2)) + 1e-12
    f, p = spectrum(x, sr)
    tot = np.sum(p) + 1e-20
    bands = [np.sum(p[(f >= lo) & (f < hi)]) / tot for lo, hi in BANDS]
    r = dict(name=name, sr=sr, secs=len(x) / sr, peak=20 * np.log10(peak), rms=20 * np.log10(rms),
             crest=20 * np.log10(peak / rms), lufs=loudness(x, sr, looped),
             centroid=float(np.sum(f * p) / tot), bands=bands, clip=int(np.sum(np.abs(x) >= 0.999)),
             dc=float(np.mean(x)), looped=looped)
    r["res_db"], r["res_hz"] = resonance(f, p)
    if looped:
        r["seam_jump"], r["seam_db"] = seam(x, sr)
        r["rep"], r["rep_lag"] = env_repeat(x, sr)
    return r


def main(argv=None):
    wanted = list(sys.argv[1:] if argv is None else argv)
    files = sorted(glob.glob(os.path.join(AUDIO, "*.wav")) + glob.glob(os.path.join(AUDIO, "*.ogg")))
    if wanted:
        files = [p for p in files if any(w in os.path.basename(p) for w in wanted)]
    print(f"{'name':24} {'secs':>6} {'peak':>6} {'rms':>6} {'crest':>5} {'LU':>6} {'cent':>5} "
          f"{'<200':>4} {'-1k':>4} {'-2k':>4} {'2-5k':>4} {'>5k':>4} {'res':>10} {'seam':>11} {'repeat':>11}")
    for path in files:
        r = analyse(path)
        if r is None:
            print(f"{os.path.basename(path):24} (could not decode)")
            continue
        b = " ".join(f"{v * 100:4.0f}" for v in r["bands"])
        line = (f"{r['name']:24} {r['secs']:6.2f} {r['peak']:6.1f} {r['rms']:6.1f} {r['crest']:5.1f} {r['lufs']:6.1f} "
                f"{r['centroid']:5.0f} {b} {r['res_db']:4.1f}@{r['res_hz']:<5.0f}")
        if r["looped"]:
            line += f" {r['seam_jump']:5.1f}x{r['seam_db']:+4.1f} {r['rep']:4.2f}@{r['rep_lag']:5.1f}s"
        if r["clip"]:
            line += f"  CLIP {r['clip']}"
        if abs(r["dc"]) > 0.005:
            line += f"  DC {r['dc']:+.3f}"
        print(line)


if __name__ == "__main__":
    main()
