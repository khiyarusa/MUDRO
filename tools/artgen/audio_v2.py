#!/usr/bin/env python3
"""audio_v2.py - deterministic synthesis of MUDRO's second audio batch.

19 new assets: 44100 Hz, mono, 16-bit PCM WAV, no DC, peak-normalised to
-3.0 dBFS.  Existing files in assets/audio are never touched (the writer aborts
if a target name already exists).

Loop method
-----------
Every looping asset is built *periodic over the file length*, so the seam is
continuous by construction and no crossfade is used:

* each tonal partial's frequency is snapped to k / duration, i.e. a whole
  number of cycles fills the file exactly;
* every LFO / vibrato completes a whole number of cycles, and vibrato is
  applied as an analytic phase term whose value at t=duration equals its value
  at t=0 (no cumulative drift);
* noise beds are shaped in the frequency domain with an FFT of exactly the
  file length, i.e. circular filtering, which is periodic by definition;
* grains (ratchet ticks, gravel, raindrops, injector clatter) are summed with
  wrap-around indexing, so a grain that crosses the seam simply continues at
  the head of the buffer;
* the 24 Hz zero-phase high-pass is an FFT filter of the same length, so it
  also runs circularly and cannot break the period.

One-shots instead get a 1 ms raised-cosine fade-in and a short fade-out.

Determinism
-----------
Every random stream is seeded from SHA-256 of a fixed tag, and all processing
is plain float64 numpy, so repeated runs produce byte-identical WAVs.

Usage
-----
    python tools/artgen/audio_v2.py                 # write into assets/audio
    python tools/artgen/audio_v2.py --out DIR       # write to another folder
    python tools/artgen/audio_v2.py --analyze       # add spectral character table
"""

from __future__ import annotations

import argparse
import hashlib
import math
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
TWO_PI = 2.0 * math.pi
PEAK_DB = -3.0
PEAK = 10.0 ** (PEAK_DB / 20.0)
AUDIO_DIR = Path(__file__).resolve().parents[2] / "assets" / "audio"

ASSETS: list[tuple[str, float, bool, object]] = []


# --------------------------------------------------------------------- utils
def asset(name: str, dur: float, loop: bool = False):
    def deco(fn):
        ASSETS.append((name, dur, loop, fn))
        return fn

    return deco


def rng(tag: str) -> np.random.Generator:
    digest = hashlib.sha256(tag.encode("utf-8")).digest()
    return np.random.default_rng(int.from_bytes(digest[:8], "big"))


def nsamp(dur: float) -> int:
    return int(round(dur * SR))


def tline(n: int) -> np.ndarray:
    return np.arange(n, dtype=np.float64) / SR


def snap(freq: float, dur: float) -> float:
    """Nearest frequency holding a whole number of cycles in `dur` seconds."""
    return max(1, int(round(freq * dur))) / dur


def lfo(n: int, cycles: int, phase: float = 0.0) -> np.ndarray:
    """Periodic sine LFO: exactly `cycles` cycles across the buffer."""
    return np.sin(TWO_PI * cycles * np.arange(n) / n + phase)


def smooth_random(n: int, knots: int, tag: str) -> np.ndarray:
    """Periodic smooth random curve (cosine interpolation around a circle)."""
    vals = rng(tag).uniform(-1.0, 1.0, knots)
    x = np.linspace(0.0, knots, n, endpoint=False)
    i = np.floor(x).astype(int)
    f = x - i
    f = 0.5 - 0.5 * np.cos(np.pi * f)
    return (1.0 - f) * vals[i % knots] + f * vals[(i + 1) % knots]


def _band_mask(freqs: np.ndarray, lo, hi, width: float = 0.30) -> np.ndarray:
    m = np.ones_like(freqs)
    if lo:
        a, b = lo * math.exp(-width), lo * math.exp(width)
        x = np.clip((freqs - a) / max(b - a, 1e-9), 0.0, 1.0)
        m *= 0.5 - 0.5 * np.cos(np.pi * x)
    if hi:
        a, b = hi * math.exp(-width), hi * math.exp(width)
        x = np.clip((freqs - a) / max(b - a, 1e-9), 0.0, 1.0)
        m *= 0.5 + 0.5 * np.cos(np.pi * x)
    return m


def noise(n: int, tag: str, lo=None, hi=None, tilt: float = 0.0,
          width: float = 0.30) -> np.ndarray:
    """Band-limited noise via circular FFT shaping -> periodic over n samples.

    `tilt` is the amplitude-spectrum slope in dB/octave (negative = darker).
    """
    spec = np.fft.rfft(rng(tag).standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    m = _band_mask(f, lo, hi, width)
    if tilt:
        m *= np.where(f > 0.0, (np.maximum(f, 20.0) / 1000.0) ** (tilt / 6.0206), 0.0)
    m[0] = 0.0
    out = np.fft.irfft(spec * m, n)
    s = out.std()
    return out / s if s > 0.0 else out


def hp(x: np.ndarray, fc: float = 24.0) -> np.ndarray:
    """Zero-phase circular high-pass (2nd order magnitude), removes DC."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    h = (f ** 2) / (f ** 2 + fc ** 2 + 1e-12)
    return np.fft.irfft(np.fft.rfft(x) * h, n)


def damped(freq: float, dur: float, decay: float, glide: float = 1.0,
           tau: float = 0.02, phase: float = 0.0) -> np.ndarray:
    """Exponentially decaying sine with an exponential pitch glide."""
    n = nsamp(dur)
    t = tline(n)
    g = glide - 1.0
    integ = freq * t + freq * g * (t - tau * (1.0 - np.exp(-t / tau)))
    return np.sin(TWO_PI * integ + phase) * np.exp(-t / decay)


def env_perc(n: int, attack: float, decay: float) -> np.ndarray:
    t = tline(n)
    a = np.clip(t / max(attack, 1e-6), 0.0, 1.0)
    a = 0.5 - 0.5 * np.cos(np.pi * a)
    return a * np.exp(-t / decay)


def fade(x: np.ndarray, fin: float, fout: float) -> np.ndarray:
    n = len(x)
    a = min(n, max(1, int(fin * SR)))
    b = min(n, max(1, int(fout * SR)))
    x[:a] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(a) / a)
    x[-b:] *= 0.5 + 0.5 * np.cos(np.pi * (np.arange(b) + 1) / b)
    return x


def add_grains(buf: np.ndarray, positions, length: int, decay: float,
               lo: float, hi: float, tag: str, gains) -> None:
    """Add short filtered noise grains, wrapping across the buffer end."""
    n = len(buf)
    bed = noise(n, tag, lo, hi)
    env = env_perc(length, 0.0006, decay)
    k = np.arange(length)
    if np.isscalar(gains):
        gains = np.full(len(positions), float(gains))
    for p, g in zip(positions, gains):
        idx = (int(p) + k) % n
        buf[idx] += bed[idx] * env * g


def finalize(x: np.ndarray, loop: bool) -> np.ndarray:
    x = np.asarray(x, dtype=np.float64)
    x = hp(x)
    x -= x.mean()
    if not loop:
        dur = len(x) / SR
        x = fade(x, 0.0010, min(0.025, 0.25 * dur))
        x -= x.mean()
    x *= PEAK / max(np.abs(x).max(), 1e-12)
    x -= x.mean()
    x *= PEAK / max(np.abs(x).max(), 1e-12)
    return x


# ------------------------------------------------------------------- winch
@asset("winch_loop", 2.0, loop=True)
def _winch_loop() -> np.ndarray:
    dur, n = 2.0, nsamp(2.0)
    t = tline(n)

    # gear whine 180 Hz + harmonics, wavering under load
    whine = np.zeros(n)
    for order, amp, dev in ((1, 0.55, 1.2), (2, 0.30, 1.8), (3, 0.17, 2.4),
                            (4, 0.08, 3.0), (6, 0.035, 4.0)):
        f = snap(180.0 * order, dur)
        a = dev / 3.0                     # 3 Hz vibrato = 6 cycles over 2 s
        whine += amp * np.sin(TWO_PI * f * t + a * np.sin(TWO_PI * 3.0 * t + 0.9 * order))
    whine += 0.10 * np.sin(TWO_PI * snap(90.0, dur) * t + 0.4)
    whine *= 1.0 + 0.10 * lfo(n, 3, 0.7) + 0.05 * lfo(n, 7, 2.1)

    load = noise(n, "winch:load", 55, 780, tilt=-2.0)
    hiss = noise(n, "winch:hiss", 900, 4200, tilt=-3.0)
    rumble = noise(n, "winch:rumble", 30, 120, tilt=-1.0)

    sig = (whine * 0.55
           + load * 0.26 * (0.75 + 0.25 * lfo(n, 2, 1.3))
           + hiss * 0.05
           + rumble * 0.30 * (0.7 + 0.3 * lfo(n, 2, 2.6)))

    # ratchet: 16 ticks/s, evenly spaced so the rhythm is loop-periodic
    ticks = np.zeros(n)
    count = 32
    step = n / count
    pos = ((np.arange(count) * step + step * 0.18) % n).astype(int)
    gains = rng("winch:tickgain").uniform(0.55, 1.0, count)
    add_grains(ticks, pos, int(0.0055 * SR), 0.0016, 1800, 7800, "winch:tick", gains)
    sig += ticks * 0.22
    return sig


@asset("winch_strain", 1.0)
def _winch_strain() -> np.ndarray:
    dur, n = 1.0, nsamp(1.0)
    t = tline(n)
    sig = np.zeros(n)

    # cable creak: rising stick-slip tone, accelerating
    f = 190.0 * (1.0 + 0.20 * t)
    ph = TWO_PI * np.cumsum(f) / SR
    rate = 9.0 + 26.0 * t
    slip = 0.28 + 0.72 * np.clip(np.sin(TWO_PI * np.cumsum(rate) / SR), 0.0, 1.0) ** 2
    sig += 0.34 * np.sin(ph) * slip
    sig += 0.14 * np.sin(2.0 * ph + 0.6) * (0.35 + 0.65 * slip)
    sig += 0.06 * np.sin(3.0 * ph + 1.4)

    # metallic groan: rising inharmonic partials with slow beating
    for fr, amp, tau, beat in ((604.0, 0.10, 0.70, 2.1),
                               (933.0, 0.07, 0.55, 3.4),
                               (1322.0, 0.045, 0.40, 4.9)):
        p = TWO_PI * np.cumsum(fr * (1.0 + 0.085 * t)) / SR
        sig += amp * np.sin(p) * (0.55 + 0.45 * np.sin(TWO_PI * beat * t + fr)) * np.exp(-t / tau)

    body = noise(n, "strain:body", 60, 420, tilt=-1.5)
    sig += body * 0.10 * (1.0 + np.sin(TWO_PI * 3.0 * t))

    # cable fibres snapping under load
    ticks = np.zeros(n)
    cnt = 14
    pos = np.sort(rng("strain:pos").integers(0, n - int(0.012 * SR), cnt))
    gains = rng("strain:gain").uniform(0.25, 1.0, cnt)
    add_grains(ticks, pos, int(0.008 * SR), 0.0022, 900, 5200, "strain:tick", gains)
    sig += ticks * 0.22
    sig *= np.clip(t / 0.025, 0.0, 1.0)
    return sig


# ------------------------------------------------------------------ gearbox
@asset("gear_grind", 0.45)
def _gear_grind() -> np.ndarray:
    dur, n = 0.45, nsamp(0.45)
    t = tline(n)

    # teeth skipping over each other: irregular 68 Hz rasp
    rate = 68.0 + 6.0 * np.sin(TWO_PI * 1.4 * t)
    teeth = np.exp(-((np.cumsum(rate) / SR) % 1.0) * 7.0)
    teeth *= 0.55 + 0.45 * smooth_random(n, 9, "grind:jit")
    rasp = noise(n, "grind:rasp", 1200, 8000, tilt=-1.0)
    sig = rasp * teeth * 0.55

    # inharmonic metal
    for fr, amp, d in ((1487.0, 0.18, 0.10), (2213.0, 0.13, 0.08),
                       (3170.0, 0.09, 0.06), (4210.0, 0.05, 0.05)):
        p = TWO_PI * fr * np.cumsum(1.0 + 0.02 * np.sin(TWO_PI * 47.0 * t)) / SR
        sig += amp * np.sin(p) * np.exp(-t / d)

    sig += noise(n, "grind:low", 120, 700, tilt=-2.0) * np.exp(-t / 0.18) * 0.25
    sig += noise(n, "grind:tail", 400, 2400, tilt=-2.0) * 0.10

    env = np.zeros(n)
    for off, g in ((0.0, 1.0), (0.11, 0.75), (0.235, 0.45)):
        k = int(off * SR)
        env[k:] += g * env_perc(n - k, 0.003, 0.085)
    return soft_crest(sig * env, 16.0)


@asset("gear_engage", 0.30)
def _gear_engage() -> np.ndarray:
    dur, n = 0.30, nsamp(0.30)
    sig = np.zeros(n)

    sig += damped(150.0, dur, 0.075, glide=0.62, tau=0.012) * 0.55
    sig += damped(232.0, dur, 0.045, glide=0.80, tau=0.010) * 0.22
    sig += noise(n, "gear_engage:burst", 140, 2800, tilt=-1.5) * env_perc(n, 0.0015, 0.016) * 0.45

    # synchro ring
    for fr, a, d in ((4180.0, 0.06, 0.055), (6310.0, 0.035, 0.042), (8120.0, 0.02, 0.030)):
        sig += a * damped(fr, dur, d, glide=0.995)

    # short low body so the thunk reads as a solid engagement, not a tick
    sig += damped(78.0, dur, 0.120, glide=0.95, tau=0.03) * 0.22

    # detent click just after the thunk
    k = int(0.055 * SR)
    sig[k:] += (noise(n, "gear_engage:click", 2500, 9000)[:n - k]
                * env_perc(n - k, 0.0008, 0.004) * 0.18)
    return soft_crest(sig, 15.5)


@asset("clutch_engage", 0.35)
def _clutch_engage() -> np.ndarray:
    dur, n = 0.35, nsamp(0.35)
    sig = np.zeros(n)

    sig += damped(74.0, dur, 0.105, glide=0.70, tau=0.02) * 0.60
    sig += damped(148.0, dur, 0.060, glide=0.82, tau=0.015) * 0.24
    sig += damped(296.0, dur, 0.032, glide=0.90, tau=0.010) * 0.10
    sig += noise(n, "clutch_engage:friction", 240, 2000, tilt=-1.0) * env_perc(n, 0.004, 0.070) * 0.30

    k = int(0.02 * SR)
    bite = noise(n, "clutch_engage:bite", 1800, 6500, tilt=-1.0)
    sig[k:] += bite[:n - k] * env_perc(n - k, 0.0015, 0.018) * 0.20
    sig += damped(1850.0, dur, 0.012, glide=0.98) * 0.05
    return sig


@asset("clutch_release", 0.25)
def _clutch_release() -> np.ndarray:
    dur, n = 0.25, nsamp(0.25)
    t = tline(n)

    hiss = noise(n, "clutch_release:hiss", 1100, 9500, tilt=-1.5)
    sig = hiss * env_perc(n, 0.006, 0.085) * 0.55

    # release spring: damped pings, downward glide, fast tremolo
    for fr, a, d in ((880.0, 0.16, 0.055), (1320.0, 0.09, 0.040), (2210.0, 0.04, 0.025)):
        s = damped(fr, dur, d, glide=0.86, tau=0.02) * a
        sig += s * (0.65 + 0.35 * np.sin(TWO_PI * 37.0 * t))

    k = int(0.035 * SR)
    sig[k:] += damped(96.0, dur, 0.05, glide=0.90)[:n - k] * 0.18
    sig *= np.clip(t / 0.004, 0.0, 1.0)
    return sig


# -------------------------------------------------------------------- turbo
@asset("turbo_spool", 1.2, loop=True)
def _turbo_spool() -> np.ndarray:
    dur, n = 1.2, nsamp(1.2)
    t = tline(n)

    # spool shape 0 -> 1 -> 0, one whole cycle; its integral vanishes at t=dur,
    # so the phase below closes on an integer number of cycles.
    shape = 0.5 - 0.5 * np.cos(TWO_PI * t / dur)
    integ = 0.5 * t - (dur / (4.0 * np.pi)) * np.sin(TWO_PI * t / dur)
    f0, depth = 2000.0, 3200.0
    phase = TWO_PI * (f0 * t + depth * integ)
    whistle = (np.sin(phase)
               + 0.28 * np.sin(1.5 * phase + 0.6)
               + 0.12 * np.sin(2.0 * phase + 1.9))

    blade = np.zeros(n)
    for lo, hi, gain, ex in ((1800, 3200, 0.30, 1.0),
                             (3200, 5200, 0.22, 1.6),
                             (5200, 9000, 0.10, 2.2)):
        band = noise(n, f"turbo:band:{lo}", lo, hi, tilt=-1.0)
        blade += gain * band * (0.25 + 0.75 * shape ** ex)

    rumble = noise(n, "turbo:rumble", 65, 260, tilt=-2.0)
    sig = whistle * (0.20 + 0.30 * shape) + blade + rumble * (0.25 + 0.15 * shape)
    sig *= 1.0 + 0.04 * lfo(n, 5, 1.1)
    return sig


# ----------------------------------------------------------------- surfaces
@asset("tire_roll_rock", 2.0, loop=True)
def _tire_roll_rock() -> np.ndarray:
    dur, n = 2.0, nsamp(2.0)
    t = tline(n)

    rumble = noise(n, "rock:rumble", 65, 400, tilt=-1.0)
    grit = noise(n, "rock:grit", 500, 6500, tilt=-2.0)

    pulse = 0.5 + 0.5 * np.cos(TWO_PI * 26.0 * t)      # 52 tread slaps over 2 s
    tread = 0.55 + 0.45 * pulse ** 6
    sig = rumble * 0.40 + grit * 0.30 * tread

    for fr, a in ((1650.0, 0.10), (2680.0, 0.07), (3960.0, 0.05)):
        sig += a * noise(n, f"rock:res:{fr}", fr * 0.85, fr * 1.15) * (0.5 + 0.5 * pulse ** 3)

    stones = np.zeros(n)
    cnt = 900
    pos = rng("rock:pos").integers(0, n, cnt)
    gains = rng("rock:gain").uniform(0.08, 1.0, cnt) ** 2
    add_grains(stones, pos, int(0.004 * SR), 0.0018, 1500, 9000, "rock:stones", gains)
    sig += stones * 0.30
    sig *= 0.85 + 0.15 * lfo(n, 2, 0.3)
    return sig


@asset("snow_crunch", 1.5, loop=True)
def _snow_crunch() -> np.ndarray:
    dur, n = 1.5, nsamp(1.5)
    t = tline(n)

    bed = noise(n, "snow:bed", 220, 4200, tilt=-3.0)
    squeak = noise(n, "snow:squeak", 900, 1600)
    sig = bed * 0.24 + squeak * 0.09 * (0.5 + 0.5 * lfo(n, 18, 0.4))

    grains = np.zeros(n)
    cnt = 1300
    pos = rng("snow:pos").integers(0, n, cnt)
    gains = rng("snow:gain").uniform(0.05, 1.0, cnt) ** 2
    add_grains(grains, pos, int(0.004 * SR), 0.0022, 1200, 9500, "snow:grain", gains)
    sig += grains * 0.26

    packs = np.zeros(n)
    cnt = 90
    pos = rng("snow:packpos").integers(0, n, cnt)
    gains = rng("snow:packgain").uniform(0.3, 1.0, cnt)
    add_grains(packs, pos, int(0.014 * SR), 0.0085, 350, 2600, "snow:pack", gains)
    sig += packs * 0.24

    sig += 0.035 * np.sin(TWO_PI * snap(240.0, dur) * t) * (0.5 + 0.5 * lfo(n, 4, 0.9))
    sig *= 0.92 + 0.08 * lfo(n, 3, 2.0)
    return sig


# ------------------------------------------------------------------ weather
@asset("wind_loop", 3.0, loop=True)
def _wind_loop() -> np.ndarray:
    dur, n = 3.0, nsamp(3.0)
    t = np.arange(n) / n

    gust = (0.55
            + 0.25 * np.sin(TWO_PI * 1.0 * t + 0.4)
            + 0.14 * np.sin(TWO_PI * 3.0 * t + 1.9)
            + 0.08 * np.sin(TWO_PI * 5.0 * t + 3.4))
    gust = np.clip(gust, 0.05, None)

    body = noise(n, "wind:body", 90, 2200, tilt=-4.0)
    hiss = noise(n, "wind:hiss", 400, 6000, tilt=-5.0)
    sub = noise(n, "wind:sub", 40, 120, tilt=-2.0)
    whistle = noise(n, "wind:whistle", 600, 780, width=0.10)

    sig = body * gust * 0.55
    sig += hiss * (0.10 + 0.14 * (gust - 0.3)) * 0.6
    sig += sub * (0.16 + 0.10 * gust)
    sig += whistle * 0.10 * (gust ** 2)
    sig += 0.02 * np.sin(TWO_PI * snap(640.0, dur) * np.arange(n) / SR
                         + 0.8 * np.sin(TWO_PI * 2.0 * t))
    return sig


@asset("rain_loop", 3.0, loop=True)
def _rain_loop() -> np.ndarray:
    dur, n = 3.0, nsamp(3.0)

    bed = noise(n, "rain:bed", 1500, 12000, tilt=-2.0)
    low = noise(n, "rain:low", 300, 1200, tilt=-2.0)
    sig = bed * 0.30 + low * 0.10

    drops = np.zeros(n)
    cnt = 5000
    pos = rng("rain:pos").integers(0, n, cnt)
    gains = rng("rain:gain").uniform(0.03, 1.0, cnt) ** 2
    add_grains(drops, pos, int(0.0035 * SR), 0.0016, 2500, 12000, "rain:drops", gains)
    sig += drops * 0.26

    heavy = np.zeros(n)
    cnt = 320
    pos = rng("rain:heavypos").integers(0, n, cnt)
    gains = rng("rain:heavygain").uniform(0.3, 1.0, cnt)
    add_grains(heavy, pos, int(0.012 * SR), 0.0060, 900, 4200, "rain:heavy", gains)
    sig += heavy * 0.14

    sig *= 0.94 + 0.06 * lfo(n, 4, 1.2)
    return sig


@asset("weather_thunder", 2.5)
def _weather_thunder() -> np.ndarray:
    dur, n = 2.5, nsamp(2.5)
    t = tline(n)

    env = np.zeros(n)
    for center, width, gain in ((0.45, 0.30, 1.0), (1.15, 0.45, 0.75), (1.85, 0.30, 0.35)):
        env += gain * np.exp(-0.5 * ((t - center) / width) ** 2)
    env *= np.clip(t / 0.14, 0.0, 1.0)
    env /= max(env.max(), 1e-9)

    rumble = noise(n, "thunder:rumble", 25, 170, tilt=-5.0)
    crackle = noise(n, "thunder:crackle", 220, 1400, tilt=-2.0)
    roll = 0.6 + 0.4 * smooth_random(n, 7, "thunder:roll")

    sig = rumble * env * roll * 0.80
    sig += crackle * env * (0.10 + 0.06 * roll)

    sub = np.sin(TWO_PI * np.cumsum(38.0 * (1.0 - 0.05 * t)) / SR)
    sig += sub * env * 0.35

    for center, width, gain in ((0.62, 0.10, 1.0), (1.42, 0.16, 0.5)):
        sig += (noise(n, f"thunder:peal:{center}", 60, 300, tilt=-3.0)
                * gain * np.exp(-0.5 * ((t - center) / width) ** 2) * 0.25)
    return sig


# ------------------------------------------------------------- suspension
@asset("suspension_bottom", 0.30)
def _suspension_bottom() -> np.ndarray:
    dur, n = 0.30, nsamp(0.30)
    t = tline(n)

    sig = damped(88.0, dur, 0.090, glide=0.66, tau=0.015) * 0.60
    sig += damped(176.0, dur, 0.050, glide=0.78, tau=0.012) * 0.24
    sig += noise(n, "susp:rubber", 240, 360, width=0.45) * env_perc(n, 0.002, 0.045) * 0.30
    sig += noise(n, "susp:click", 900, 5000, tilt=-1.0) * env_perc(n, 0.0012, 0.010) * 0.22
    sig *= np.clip(t / 0.002, 0.0, 1.0)
    return sig


@asset("bridge_rumble", 1.5, loop=True)
def _bridge_rumble() -> np.ndarray:
    dur, n = 1.5, nsamp(1.5)
    t = tline(n)

    low = noise(n, "bridge:low", 40, 130, tilt=-1.0)
    sig = low * 0.45 * (0.85 + 0.15 * lfo(n, 2, 0.2))
    sig += 0.05 * np.sin(TWO_PI * snap(64.0, dur) * t + 0.5) * (0.7 + 0.3 * lfo(n, 1, 0.0))

    hiss = noise(n, "bridge:hiss", 700, 5000, tilt=-2.0)
    tread = 0.6 + 0.4 * (0.5 + 0.5 * np.cos(TWO_PI * 40.0 * t)) ** 5   # 60 slaps / 1.5 s
    sig += hiss * 0.22 * tread

    # steel deck plate ring
    for fr, a, cyc in ((512.0, 0.055, 3), (768.0, 0.035, 4), (1180.0, 0.022, 5), (1620.0, 0.014, 7)):
        sig += a * np.sin(TWO_PI * snap(fr, dur) * t + 0.4) * (0.5 + 0.5 * lfo(n, cyc, 0.9))

    clanks = np.zeros(n)
    cnt = 20
    pos = rng("bridge:pos").integers(0, n, cnt)
    gains = rng("bridge:gain").uniform(0.4, 1.0, cnt)
    add_grains(clanks, pos, int(0.020 * SR), 0.009, 1200, 5200, "bridge:clank", gains)
    sig += clanks * 0.10
    sig *= 0.9 + 0.1 * lfo(n, 1, 1.0)
    return sig


# ----------------------------------------------------------------- engines
def harmonic_bank(n: int, dur: float, f0: float, count: int, rolloff: float,
                  tag: str, comb: float = 0.0, formant=None) -> np.ndarray:
    """Dense harmonic engine spectrum, periodic over `dur`.

    Harmonics get fixed pseudo-random phases: the sum stays periodic but has a
    realistic dense spectrum and a ~11 dB crest factor instead of the impulse
    peak a phase-coherent stack would produce.
    """
    t = tline(n)
    phases = rng(tag).uniform(0.0, TWO_PI, count + 1)
    out = np.zeros(n)
    for h in range(1, count + 1):
        fh = snap(f0 * h, dur)
        amp = h ** (-rolloff)
        if comb:
            amp *= 1.0 + comb * np.cos(TWO_PI * h * 0.25 + 0.7)
        if formant:
            center, width, g = formant
            f = h * f0
            amp *= 1.0 + g * np.exp(-0.5 * ((f - center) / width) ** 2)
        out += amp * np.sin(TWO_PI * fh * t + phases[h])
    return out


def soft_crest(x: np.ndarray, target_db: float) -> np.ndarray:
    """Tanh soft-limit until peak/RMS reaches `target_db` (engine grit)."""
    target = 10.0 ** (target_db / 20.0)
    x = x / max(np.abs(x).max(), 1e-12)
    best, best_err = x, abs(1.0 / rms(x) - target)
    for d in np.geomspace(0.05, 8.0, 120):
        y = np.tanh(x * d)
        err = abs(np.abs(y).max() / rms(y) - target)
        if err < best_err:
            best_err, best = err, y
    return best


def firing_pulse(n: int, dur: float, f: float, sharp: float) -> np.ndarray:
    f = snap(f, dur)
    t = tline(n)
    return (0.5 + 0.5 * np.cos(TWO_PI * f * t)) ** sharp


def clatter(n: int, dur: float, rate: float, length: float, decay: float,
            lo: float, hi: float, tag: str, gain_range=(0.6, 1.0)) -> np.ndarray:
    f = snap(rate, dur)
    cnt = int(round(f * dur))
    pos = np.round(np.arange(cnt) * n / cnt).astype(int) % n
    gains = rng(tag).uniform(gain_range[0], gain_range[1], cnt)
    buf = np.zeros(n)
    add_grains(buf, pos, int(length * SR), decay, lo, hi, tag, gains)
    return buf


@asset("engine_buggy_high", 2.0, loop=True)
def _engine_buggy_high() -> np.ndarray:
    dur, n = 2.0, nsamp(2.0)
    f0 = 148.0        # octave of the 74 Hz base loop in engine_buggy.wav

    tone = harmonic_bank(n, dur, f0, 28, 0.62, "buggy:phase",
                         comb=0.15, formant=(1200.0, 700.0, 0.55))
    am = 0.55 + 0.45 * firing_pulse(n, dur, f0, 2.0)
    rasp = noise(n, "buggy:rasp", 1200, 7500, tilt=-1.0)
    rasp *= 0.20 + 0.80 * firing_pulse(n, dur, f0, 3.0)

    sig = tone * am * 0.80 + rasp * 0.22
    sig += 0.03 * np.sin(TWO_PI * snap(3100.0, dur) * tline(n)) * (0.5 + 0.5 * lfo(n, 4, 0.3))
    sig *= 0.90 + 0.10 * lfo(n, 3, 1.4)
    return soft_crest(sig, 9.0)


@asset("engine_ranger_high", 2.0, loop=True)
def _engine_ranger_high() -> np.ndarray:
    dur, n = 2.0, nsamp(2.0)
    f0 = 144.0        # octave of the 72 Hz base loop in engine_ranger.wav

    tone = harmonic_bank(n, dur, f0, 34, 0.78, "ranger:phase",
                         comb=0.10, formant=(700.0, 480.0, 0.65))
    diesel = clatter(n, dur, f0, 0.0035, 0.0016, 900, 6000, "ranger:clatter", (0.5, 1.0))
    whine = np.sin(TWO_PI * snap(2650.0, dur) * tline(n) + 0.3) * (0.5 + 0.5 * lfo(n, 3, 0.8))

    sig = tone * 0.72 + diesel * 0.26 + whine * 0.02
    sig += noise(n, "ranger:air", 300, 3000, tilt=-2.0) * 0.07
    sig *= 0.92 + 0.08 * lfo(n, 2, 0.5)
    return soft_crest(sig, 9.5)


@asset("engine_pickup_high", 2.0, loop=True)
def _engine_pickup_high() -> np.ndarray:
    dur, n = 2.0, nsamp(2.0)
    f0 = 148.0        # octave of the 74 Hz base loop in engine_pickup.wav

    tone = harmonic_bank(n, dur, f0, 28, 0.72, "pickup:phase",
                         comb=0.30, formant=(950.0, 650.0, 0.55))
    lope = 0.90 + 0.10 * lfo(n, 3, 0.0)          # uneven firing burble
    exhaust = noise(n, "pickup:exhaust", 400, 3200, tilt=-1.5)
    exhaust *= 0.35 + 0.65 * firing_pulse(n, dur, f0 / 2.0, 2.5)

    sig = tone * lope * 0.70 + exhaust * 0.24
    sig += noise(n, "pickup:growl", 120, 700, tilt=-1.0) * 0.10
    sig *= 0.90 + 0.10 * lfo(n, 2, 1.7)
    return soft_crest(sig, 8.5)


@asset("engine_titan_high", 2.0, loop=True)
def _engine_titan_high() -> np.ndarray:
    dur, n = 2.0, nsamp(2.0)
    f0 = 144.0        # octave of the 72 Hz base loop in engine_titan.wav

    tone = harmonic_bank(n, dur, f0, 34, 0.80, "titan:phase",
                         comb=0.12, formant=(520.0, 380.0, 0.65))
    heavy = clatter(n, dur, f0, 0.005, 0.0022, 700, 4200, "titan:clatter", (0.6, 1.0))
    sub = np.sin(TWO_PI * snap(72.0, dur) * tline(n) + 1.1)

    sig = tone * 0.72 + heavy * 0.26 + sub * 0.14
    sig += 0.05 * np.sin(TWO_PI * snap(36.0, dur) * tline(n) + 0.4)
    sig += noise(n, "titan:air", 200, 2000, tilt=-2.5) * 0.07
    sig *= 0.95 + 0.05 * lfo(n, 2, 0.2)
    return soft_crest(sig, 9.5)


# ---------------------------------------------------------------------- ui
@asset("ui_tick", 0.06)
def _ui_tick() -> np.ndarray:
    n = nsamp(0.06)
    sig = np.zeros(n)

    sig += damped(2600.0, 0.06, 0.0045, glide=0.995) * 0.45
    sig += damped(5200.0, 0.06, 0.0028, glide=0.99) * 0.16
    sig += damped(1180.0, 0.06, 0.0035, glide=0.99) * 0.10
    sig += damped(190.0, 0.06, 0.010, glide=0.85) * 0.22
    sig += noise(n, "ui:click", 2500, 10000, tilt=-1.0) * env_perc(n, 0.0004, 0.0022) * 0.35
    return sig


# --------------------------------------------------------------------- I/O
def write_wav(path: Path, x: np.ndarray) -> None:
    pcm = np.clip(np.rint(x * 32767.0), -32768.0, 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def read_wav(path: Path) -> tuple[np.ndarray, int, int, int]:
    with wave.open(str(path), "rb") as w:
        ch, width, rate, frames = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(frames)
    return np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0, ch, width, rate


def db(x: float) -> float:
    return 20.0 * math.log10(max(x, 1e-12))


def rms(x: np.ndarray) -> float:
    return float(np.sqrt(np.mean(x * x)))


def seam_stats(x: np.ndarray) -> tuple[float, float, float, float]:
    step = np.abs(np.diff(x))
    ref = float(np.percentile(step, 99.9))
    jump = float(abs(x[0] - x[-1]))
    w = min(len(x) // 8, int(0.005 * SR))
    local = rms(np.concatenate([x[-w:], x[:w]]))
    return jump, ref, jump / max(ref, 1e-12), local / max(rms(x), 1e-12)


def spectrum_stats(x: np.ndarray) -> tuple[float, float, float, float]:
    sp = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    tot = max(float(sp.sum()), 1e-20)
    centroid = float((sp * f).sum() / tot)
    lo = float(sp[f < 300.0].sum() / tot)
    mid = float(sp[(f >= 300.0) & (f < 2500.0)].sum() / tot)
    hi = float(sp[f >= 2500.0].sum() / tot)
    return centroid, lo, mid, hi


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Synthesise MUDRO audio batch 2 (deterministic).")
    ap.add_argument("--out", default=None, help="output directory (default: assets/audio)")
    ap.add_argument("--analyze", action="store_true", help="print spectral character table")
    args = ap.parse_args(argv)

    out_dir = Path(args.out).resolve() if args.out else AUDIO_DIR
    out_dir.mkdir(parents=True, exist_ok=True)

    clashes = [out_dir / f"{name}.wav" for name, _, _, _ in ASSETS
               if (out_dir / f"{name}.wav").exists()]
    if clashes:
        print("REFUSING TO OVERWRITE existing files:", file=sys.stderr)
        for p in clashes:
            print("  " + p.name, file=sys.stderr)
        return 2

    for name, dur, loop, fn in ASSETS:
        x = fn()
        if len(x) != nsamp(dur):
            raise RuntimeError(f"{name}: got {len(x)} samples, expected {nsamp(dur)}")
        x = finalize(x, loop)
        write_wav(out_dir / f"{name}.wav", x)

    rows, loops, chars = [], [], []
    for name, dur, loop, _ in ASSETS:
        path = out_dir / f"{name}.wav"
        x, ch, width, rate = read_wav(path)
        if (ch, width, rate) != (1, 2, SR):
            raise RuntimeError(f"{name}: bad format {(ch, width, rate)}")
        if (len(x) - 1) / SR - dur > 0.001:
            raise RuntimeError(f"{name}: bad duration {len(x)/SR}")
        peak = float(np.abs(x).max())
        if not (0.70 < peak < 0.712):
            raise RuntimeError(f"{name}: peak {db(peak):.3f} dBFS out of target")
        if abs(float(x.mean())) > 2e-4:
            raise RuntimeError(f"{name}: DC offset {x.mean():.2e}")
        rows.append((path.name, len(x) / SR, db(peak), db(rms(x))))
        if loop:
            loops.append((path.name, *seam_stats(x)))
        chars.append((path.name, *spectrum_stats(x)))

    w = 26
    print()
    print(f"{'file':<{w}}{'dur s':>8}{'peak dBFS':>12}{'RMS dBFS':>11}")
    print("-" * (w + 31))
    for name, dur, peak, rms_db in rows:
        print(f"{name:<{w}}{dur:>8.3f}{peak:>12.2f}{rms_db:>11.2f}")
    print("-" * (w + 31))
    print(f"{len(rows)} files, 44100 Hz, mono, 16-bit PCM, peak target {PEAK_DB:.1f} dBFS")

    print()
    print(f"{'LOOP SAFETY':<{w}}{'jump/step':>11}{'seam RMS x':>12}{'method':>18}")
    print("-" * (w + 41))
    worst = 0.0
    for name, jump, ref, ratio, local in loops:
        worst = max(worst, ratio)
        print(f"{name:<{w}}{ratio:>11.3f}{local:>12.3f}{'periodic build':>18}")
    print(f"max seam jump / 99.9th pct sample step = {worst:.3f} (<= 1.0 means no step at the seam)")

    if args.analyze:
        print()
        print(f"{'CHARACTER':<{w}}{'centroid Hz':>13}{'<300':>8}{'300-2.5k':>10}{'>2.5k':>8}")
        print("-" * (w + 39))
        for name, cent, lo, mid, hi in chars:
            print(f"{name:<{w}}{cent:>13.0f}{lo:>8.2f}{mid:>10.2f}{hi:>8.2f}")

    total = sum((out_dir / f"{n}.wav").stat().st_size for n, _, _, _ in ASSETS)
    print(f"\nwritten to {out_dir}  ({total/1024/1024:.2f} MiB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
