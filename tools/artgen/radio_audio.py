#!/usr/bin/env python3
"""Synthesise the built-in MUDRO Radio jingles.

Every sample here is generated from oscillators, noise and envelopes in this
script: no third-party recording is read, decoded or resampled. That makes the
output "bucket A — original / procedurally generated" under
docs/RADIO_CONTENT_POLICY.md, which is the only bucket the APK itself may carry.

Run:
    python tools/artgen/radio_audio.py
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio" / "radio"


def env(t: float, attack: float, decay: float) -> float:
    """Simple attack/decay envelope, 1.0 at the end of the attack."""
    if t < 0.0:
        return 0.0
    if t < attack:
        return t / max(attack, 1e-6)
    return math.exp(-(t - attack) / max(decay, 1e-6))


def note(name: str) -> float:
    """Equal-tempered frequency for names such as 'A2', 'C#4'."""
    table = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    pitch = name[0].upper()
    rest = name[1:]
    semis = table[pitch]
    while rest and rest[0] in "#b":
        semis += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    octave = int(rest)
    midi = (octave + 1) * 12 + semis
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


def sine(freq: float, t: float) -> float:
    return math.sin(2.0 * math.pi * freq * t)


def saw(freq: float, t: float) -> float:
    return 2.0 * ((freq * t) % 1.0) - 1.0


def square(freq: float, t: float, duty: float = 0.5) -> float:
    return 1.0 if (freq * t) % 1.0 < duty else -1.0


def bass(seq: list[tuple[str, float]], length: float) -> list[float]:
    buf = [0.0] * int(length * RATE)
    pos = 0
    for name, dur in seq:
        f = note(name)
        n = int(dur * RATE)
        for i in range(n):
            if pos + i >= len(buf):
                break
            t = i / RATE
            e = env(t, 0.008, dur * 0.55)
            # Slight saw-on-sine body keeps it warm on phone speakers.
            buf[pos + i] += (0.62 * sine(f, t) + 0.22 * saw(f, t)) * e
        pos += n
    return buf


def kick(buf: list[float], at: float, gain: float = 0.9) -> None:
    start = int(at * RATE)
    n = int(0.20 * RATE)
    for i in range(n):
        idx = start + i
        if idx >= len(buf):
            break
        t = i / RATE
        f = 120.0 * math.exp(-t * 26.0) + 44.0
        buf[idx] += sine(f, t) * math.exp(-t * 13.0) * gain


def snare(buf: list[float], at: float, gain: float = 0.35, seed: int = 7) -> None:
    rng = random.Random(seed)
    start = int(at * RATE)
    n = int(0.16 * RATE)
    for i in range(n):
        idx = start + i
        if idx >= len(buf):
            break
        t = i / RATE
        noise = rng.uniform(-1.0, 1.0)
        buf[idx] += (noise * 0.7 + sine(190.0, t) * 0.3) * math.exp(-t * 22.0) * gain


def hat(buf: list[float], at: float, gain: float = 0.12, seed: int = 11) -> None:
    rng = random.Random(seed + int(at * 1000))
    start = int(at * RATE)
    n = int(0.05 * RATE)
    last = 0.0
    for i in range(n):
        idx = start + i
        if idx >= len(buf):
            break
        t = i / RATE
        noise = rng.uniform(-1.0, 1.0)
        # Crude high-pass: difference of consecutive noise samples.
        hp = noise - last
        last = noise
        buf[idx] += hp * math.exp(-t * 70.0) * gain


def pad(notes: list[str], length: float, gain: float = 0.22) -> list[float]:
    buf = [0.0] * int(length * RATE)
    for i in range(len(buf)):
        t = i / RATE
        fade = min(1.0, t / 1.2) * min(1.0, max(0.0, (length - t) / 1.4))
        v = 0.0
        for j, nm in enumerate(notes):
            f = note(nm)
            drift = 1.0 + 0.0016 * math.sin(2.0 * math.pi * (0.11 + 0.03 * j) * t)
            v += sine(f * drift, t) * 0.5 + sine(f * 2.0 * drift, t) * 0.12
        buf[i] += v / max(len(notes), 1) * fade * gain
    return buf


def mix(*layers: list[float]) -> list[float]:
    length = max(len(x) for x in layers)
    out = [0.0] * length
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    return out


def loop_fade(buf: list[float], seconds: float = 0.04) -> list[float]:
    """Cross-fade the tail into the head so the loop point is inaudible."""
    n = int(seconds * RATE)
    if n <= 0 or len(buf) < 2 * n:
        return buf
    head = buf[:n]
    tail = buf[-n:]
    for i in range(n):
        w = i / n
        buf[i] = head[i] * w + tail[i] * (1.0 - w)
    return buf[:-n]


def normalise(buf: list[float], peak: float = 0.86) -> list[float]:
    top = max((abs(v) for v in buf), default=0.0)
    if top < 1e-9:
        return buf
    k = peak / top
    return [v * k for v in buf]


def write_wav(path: Path, buf: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for v in buf:
            s = int(max(-1.0, min(1.0, v)) * 32767)
            frames += struct.pack("<h", s)
        w.writeframes(bytes(frames))


def track_dust_road() -> list[float]:
    """Dust Road — 8 s gravel groove in A minor."""
    length = 8.0
    b = bass([("A1", 0.5), ("A1", 0.5), ("C2", 0.5), ("D2", 0.5),
              ("A1", 0.5), ("A1", 0.5), ("G1", 0.5), ("E1", 0.5),
              ("A1", 0.5), ("A1", 0.5), ("C2", 0.5), ("D2", 0.5),
              ("F2", 0.5), ("E2", 0.5), ("D2", 0.5), ("A1", 0.5)], length)
    drums: list[float] = [0.0] * int(length * RATE)
    for beat in range(16):
        t = beat * 0.5
        if beat % 4 == 0:
            kick(drums, t)
        if beat % 4 == 2:
            snare(drums, t)
        hat(drums, t + 0.25, 0.09)
        if beat % 8 == 7:
            hat(drums, t + 0.375, 0.06)
    lead: list[float] = [0.0] * int(length * RATE)
    riff = [("E4", 0.25), ("A4", 0.25), ("C5", 0.5), ("A4", 0.25), ("G4", 0.25), ("E4", 0.5)]
    pos = int(1.0 * RATE)
    for name, dur in riff * 2:
        f = note(name)
        n = int(dur * RATE)
        for i in range(n):
            idx = pos + i
            if idx >= len(lead):
                break
            t = i / RATE
            lead[idx] += sine(f, t) * env(t, 0.01, 0.20) * 0.26
        pos += n + int(0.0 * RATE)
        if pos >= len(lead):
            break
    return loop_fade(normalise(mix(b, drums, lead)))


def track_long_climb() -> list[float]:
    """Long Climb — 8 s slow minor pad with a pulse."""
    length = 8.0
    bed = pad(["A2", "C3", "E3", "G3"], length, 0.30)
    pulse: list[float] = [0.0] * int(length * RATE)
    for i in range(32):
        t = i * 0.25
        f = note("A1")
        start = int(t * RATE)
        n = int(0.12 * RATE)
        for k in range(n):
            idx = start + k
            if idx >= len(pulse):
                break
            tt = k / RATE
            pulse[idx] += sine(f, tt) * math.exp(-tt * 18.0) * 0.35
    arp: list[float] = [0.0] * int(length * RATE)
    seq = ["A3", "E4", "G4", "C5", "E5", "C5", "G4", "E4"]
    step = 0.5
    for rep in range(2):
        for i, name in enumerate(seq):
            start = int((i * step + rep * 4.0) * RATE)
            f = note(name)
            n = int(step * RATE)
            for k in range(n):
                idx = start + k
                if idx >= len(arp):
                    break
                tt = k / RATE
                arp[idx] += (sine(f, tt) * 0.7 + sine(f * 2.0, tt) * 0.12) * env(tt, 0.01, 0.35) * 0.16
    return loop_fade(normalise(mix(bed, pulse, arp)))


def track_workshop() -> list[float]:
    """Workshop — 8 s percussive piston rhythm, no melody."""
    length = 8.0
    buf: list[float] = [0.0] * int(length * RATE)
    rng = random.Random(4242)
    for i in range(16):
        at = i * 0.5
        # Clank: two detuned square blips with a metallic ring.
        start = int(at * RATE)
        for k in range(int(0.18 * RATE)):
            idx = start + k
            if idx >= len(buf):
                break
            t = k / RATE
            ring = sine(1180.0, t) * 0.25 + sine(1760.0, t) * 0.16 + sine(2350.0, t) * 0.09
            buf[idx] += (square(220.0, t, 0.3) * 0.10 + ring) * math.exp(-t * 15.0)
        if i % 4 == 0:
            kick(buf, at, 0.55)
        if i % 4 == 2:
            # Air tool: filtered noise burst.
            start = int((at + 0.25) * RATE)
            last = 0.0
            for k in range(int(0.30 * RATE)):
                idx = start + k
                if idx >= len(buf):
                    break
                t = k / RATE
                n = rng.uniform(-1.0, 1.0)
                n = n - last * 0.6
                last = n
                buf[idx] += n * math.exp(-t * 9.0) * 0.10
    return loop_fade(normalise(buf, 0.8))


def jingle_ident() -> list[float]:
    """Station ident: three rising notes and a short chord, 2.4 s."""
    length = 2.4
    buf: list[float] = [0.0] * int(length * RATE)
    hits = [("A4", 0.0, 0.18), ("C5", 0.20, 0.18), ("E5", 0.40, 0.30)]
    for name, at, dur in hits:
        f = note(name)
        start = int(at * RATE)
        for k in range(int(dur * RATE)):
            idx = start + k
            if idx >= len(buf):
                break
            t = k / RATE
            buf[idx] += (sine(f, t) * 0.6 + square(f * 0.5, t) * 0.12) * env(t, 0.006, dur * 0.5) * 0.5
    for name in ["A3", "C4", "E4", "A4"]:
        f = note(name)
        start = int(0.46 * RATE)
        for k in range(int(1.8 * RATE)):
            idx = start + k
            if idx >= len(buf):
                break
            t = k / RATE
            buf[idx] += sine(f, t) * env(t, 0.02, 0.9) * 0.16
    return normalise(buf)


def main() -> None:
    tracks = {
        "radio_ident.wav": jingle_ident(),
        "01_dust_road.wav": track_dust_road(),
        "02_long_climb.wav": track_long_climb(),
        "03_workshop.wav": track_workshop(),
    }
    for name, buf in tracks.items():
        path = OUT / name
        write_wav(path, buf)
        print(f"{path.relative_to(OUT.parents[2])}: {len(buf) / RATE:.2f}s, {path.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
