#!/usr/bin/env python3
"""Chaka Zulu's sound effects, synthesised from scratch (numpy only): no samples, no paid service.

Every tuned sound uses notes of one key (KEY_ROOT, major scale), so the set sounds like one family.
Recipes (each returns a mono float array at RATE):
    pop      button press: sine with a fast pitch drop and a click
    tick     counter tick: short high blip (pitch up with pitch=)
    toggle   two-note blip, up for on, down for off
    whoosh   transition: band-passed noise sweeping up, then down
    chime    reward: bell-like additive partials, a major triad
    fanfare  new best: rising arpeggio of chimes
    bonk     impact (stone hit): modal synthesis, decaying inharmonic partials + noise transient
    thud     landing: low sine thump + soft noise
    rustle   leaves/bushes: grains of band-passed noise
    fall     falling: descending slide with vibrato
    lose     game over: three falling notes
Then: trim, short fades, and either peak-normalise to the role's level (a positive level) or, for
the sounds of play (a negative level), master to a loudness: the RMS of the first 0.3 s as a phone
speaker plays it (little below 350 Hz), in dB, under a -1 dBFS ceiling. So the mix holds on a phone:
a landing thud made only of bass was silent there.

Usage: python3 tools/sfx_synth.py [assets/audio] [name ...]   (default: all; variants: sfx_name_1.wav ...)
"""
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
KEY_ROOT = 440.0  # A4: the Chaka Zulu theme is in A
MAJOR = [0, 2, 4, 5, 7, 9, 11]
rng = np.random.default_rng(7)


def note(degree: int, octave: int = 0) -> float:
    """Frequency of a scale degree (0 = root) in the game's key."""
    o, d = divmod(degree, 7)
    return KEY_ROOT * 2 ** (octave + o + MAJOR[d] / 12)


def t(sec: float) -> np.ndarray:
    return np.arange(int(sec * RATE)) / RATE


def env(n: int, attack: float, decay: float) -> np.ndarray:
    x = np.arange(n) / RATE
    return np.minimum(1, x / max(attack, 1e-4)) * np.exp(-x / decay)


def sweep(f0: float, f1: float, sec: float) -> np.ndarray:
    """Sine whose pitch glides exponentially from f0 to f1."""
    x = t(sec)
    f = f0 * (f1 / f0) ** (x / sec)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE)


def bandnoise(sec: float, lo: float, hi: float) -> np.ndarray:
    n = int(sec * RATE)
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / RATE)
    spec[(f < lo) | (f > hi)] = 0
    out = np.fft.irfft(spec, n)
    return out / (np.abs(out).max() + 1e-9)


def bell(freq: float, sec: float, bright: float = 1.0) -> np.ndarray:
    x = t(sec)
    partials = [(1, 1.0, 1.0), (2.0, 0.5 * bright, 0.6), (3.01, 0.25 * bright, 0.4), (4.2, 0.12 * bright, 0.25)]
    return sum(a * np.sin(2 * np.pi * freq * r * x) * np.exp(-x / (sec * d * 0.35)) for r, a, d in partials)


def pop(pitch: float = 1.0) -> np.ndarray:
    s = sweep(900 * pitch, 260 * pitch, 0.09) * env(int(0.09 * RATE), 0.002, 0.03)
    click = bandnoise(0.01, 2000, 8000) * env(int(0.01 * RATE), 0.0005, 0.003) * 0.3
    s[: len(click)] += click
    return s


def tick(pitch: float = 1.0) -> np.ndarray:
    return np.sin(2 * np.pi * note(4, 2) * pitch * t(0.045)) * env(int(0.045 * RATE), 0.001, 0.012)


def toggle(on: bool = True) -> np.ndarray:
    a, b = (note(0, 1), note(4, 1)) if on else (note(4, 1), note(0, 1))
    one = lambda f: np.sin(2 * np.pi * f * t(0.06)) * env(int(0.06 * RATE), 0.002, 0.02)
    return np.concatenate([one(a), one(b)])


def whoosh() -> np.ndarray:
    sec = 0.35
    n = int(sec * RATE)
    out = np.zeros(n)
    for i, lo in enumerate(np.geomspace(300, 2500, 12)):  # the band sweeps up, a slice at a time
        seg = bandnoise(sec, lo, lo * 2.2) * np.hanning(n) ** 2
        w = np.exp(-((np.arange(n) / n - i / 12) ** 2) / 0.02)
        out += seg * w
    return out


def chime() -> np.ndarray:
    return bell(note(0, 1), 0.7) + 0.7 * bell(note(2, 1), 0.7) + 0.5 * bell(note(4, 1), 0.7)


def fanfare() -> np.ndarray:
    out = np.zeros(int(1.3 * RATE))
    for i, deg in enumerate([0, 2, 4, 7]):
        b = bell(note(deg, 1), 0.9, bright=1.3)
        start = int(i * 0.11 * RATE)
        out[start:start + len(b)] += b[: len(out) - start]
    return out


def bonk(size: float = 1.0) -> np.ndarray:
    x = t(0.45)
    modes = [(180, 1.0, 0.09), (431, 0.6, 0.05), (777, 0.35, 0.03), (1290, 0.2, 0.02)]
    s = sum(a * np.sin(2 * np.pi * f / size * x) * np.exp(-x / d) for f, a, d in modes)
    transient = bandnoise(0.02, 800, 6000) * env(int(0.02 * RATE), 0.0005, 0.004)
    s[: len(transient)] += 0.8 * transient
    return s


def thud() -> np.ndarray:
    s = sweep(140, 55, 0.18) * env(int(0.18 * RATE), 0.002, 0.06)
    s += 0.25 * bandnoise(0.18, 100, 1200) * env(int(0.18 * RATE), 0.001, 0.02)
    return s


def rustle() -> np.ndarray:
    sec = 0.6
    out = np.zeros(int(sec * RATE))
    for _ in range(40):
        g = bandnoise(0.03, 2500, 9000) * np.hanning(int(0.03 * RATE))
        start = int(rng.uniform(0, sec - 0.03) * RATE * rng.uniform(0.3, 1.0))
        out[start:start + len(g)] += g * rng.uniform(0.2, 1.0)
    return out * np.exp(-np.arange(len(out)) / RATE / 0.35)


def fall() -> np.ndarray:
    x = t(0.8)
    f = 900 * (180 / 900) ** (x / 0.8) * (1 + 0.03 * np.sin(2 * np.pi * 7 * x))
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(len(x), 0.01, 0.5)


def lose() -> np.ndarray:
    parts = [np.sin(2 * np.pi * note(d, 0) * t(0.22)) * env(int(0.22 * RATE), 0.005, 0.12) for d in (4, 2, 0)]
    return np.concatenate(parts)


RECIPES = {
    "pop": (lambda v: pop(1 + 0.06 * v), 3, 0.7),
    "tick": (lambda v: tick(1 + 0.03 * v), 1, 0.5),
    "toggle_on": (lambda v: toggle(True), 1, 0.6),
    "toggle_off": (lambda v: toggle(False), 1, 0.6),
    "whoosh": (lambda v: whoosh(), 2, 0.6),
    "chime": (lambda v: chime(), 1, 0.8),
    "fanfare": (lambda v: fanfare(), 1, 0.85),
    "bonk": (lambda v: bonk(1 + 0.08 * v), 3, 0.9),
    "thud": (lambda v: thud(), 2, 0.8),
    "rustle": (lambda v: rustle(), 3, 0.5),
    "fall": (lambda v: fall(), 1, 0.8),
    "lose": (lambda v: lose(), 1, 0.8),
}


# ---------------------------------------------------------------- Chaka Zulu

def hop(pitch: float = 1.0) -> np.ndarray:
    """Jump: a springy rising 'hup' with a puff of air."""
    s = sweep(note(0, -1) * pitch, note(4, 0) * pitch, 0.13) * env(int(0.13 * RATE), 0.004, 0.06)
    air = bandnoise(0.1, 800, 3000) * env(int(0.1 * RATE), 0.002, 0.03) * 0.25
    s[: len(air)] += air
    return s


def clink(pitch: float = 1.0) -> np.ndarray:
    """Hang: the staff's hand hooking on, a short bright metallic clink."""
    s = bell(note(4, 2) * pitch, 0.35, 1.6) * 0.8
    s[: int(0.2 * RATE)] += bell(note(2, 3) * pitch, 0.2, 1.0) * 0.3
    hit = bandnoise(0.015, 3000, 9000) * env(int(0.015 * RATE), 0.0003, 0.004) * 0.5
    s[: len(hit)] += hit
    return s


def swish(pitch: float = 1.0) -> np.ndarray:
    """Ring throw: a fast airy swish with a ringing shimmer."""
    sec = 0.2
    n = int(sec * RATE)
    noise = bandnoise(sec, 1500 * pitch, 6000 * pitch) * np.sin(np.linspace(0, np.pi, n)) ** 2
    ring = sweep(note(4, 1) * pitch, note(0, 2) * pitch, sec) * env(n, 0.01, 0.08) * 0.35
    return noise * 0.7 + ring


def ting(pitch: float = 1.0) -> np.ndarray:
    """Ring on a bandit: a small knock with a metallic ting."""
    k = bonk(1.3 * pitch) * 0.7
    b = bell(note(5, 2) * pitch, 0.25, 1.2) * 0.4
    n = max(len(k), len(b))
    return np.pad(k, (0, n - len(k))) + np.pad(b, (0, n - len(b)))


def knockout() -> np.ndarray:
    """A bandit knocked out: a solid bonk, then a falling 'boing'."""
    k = bonk(0.9)
    boing = sweep(note(4, 0), note(0, -1), 0.35) * env(int(0.35 * RATE), 0.01, 0.15) * 0.6
    boing *= 1 + 0.3 * np.sin(2 * np.pi * 18 * t(0.35))
    return np.concatenate([k[: int(0.06 * RATE)], boing])


def bling(step: int = 0) -> np.ndarray:
    """Red Bob: two quick rising bell notes (coin-like), a step higher per variant."""
    a = bell(note(4 + step, 1), 0.08, 1.2)
    b = bell(note(0 + step, 2), 0.28, 1.4)
    return np.concatenate([a[: int(0.06 * RATE)], b])


def ouch() -> np.ndarray:
    """Hurt: a low punch and a short falling buzz."""
    punch = sweep(160, 55, 0.18) * env(int(0.18 * RATE), 0.002, 0.07)
    buzz = sweep(note(2, 0), note(0, -1), 0.22) * env(int(0.22 * RATE), 0.01, 0.1)
    buzz = np.sign(buzz) * np.abs(buzz) ** 0.5 * 0.3
    n = max(len(punch), len(buzz))
    return np.pad(punch, (0, n - len(punch))) + np.pad(buzz, (0, n - len(buzz)))


def footstep() -> np.ndarray:
    return bandnoise(0.05, 150, 1200) * env(int(0.05 * RATE), 0.001, 0.012)


def drop() -> np.ndarray:
    """Let go of the top: a short falling whoosh."""
    sec = 0.22
    n = int(sec * RATE)
    return bandnoise(sec, 300, 2500) * np.linspace(1, 0.2, n) * env(n, 0.005, 0.1)


def star(index: int) -> np.ndarray:
    """Results stars: a chime per star, each a third higher."""
    return bell(note(2 * index, 1), 0.6, 1.3)


def marimba(freq: float, sec: float) -> np.ndarray:
    """A soft wooden mallet: the fundamental, the 4th partial (a marimba bar's), a knock."""
    x = t(sec)
    s = np.sin(2 * np.pi * freq * x) * np.exp(-x / (sec * 0.35))
    s += 0.35 * np.sin(2 * np.pi * freq * 3.93 * x) * np.exp(-x / (sec * 0.08))
    knock = bandnoise(0.012, 400, 3000) * env(int(0.012 * RATE), 0.0005, 0.003) * 0.3
    s[: len(knock)] += knock
    return s * env(len(x), 0.002, sec)


def brass(freq: float, sec: float, bright: float = 1.0) -> np.ndarray:
    """A small brass section: a sawtooth whose upper harmonics open with the attack, a little
    vibrato, two voices slightly detuned."""
    x = t(sec)
    a = np.minimum(1, x / 0.03) * np.exp(-np.maximum(x - sec * 0.6, 0) / (sec * 0.15))
    opening = np.minimum(1, x / 0.06) * (0.6 + 0.4 * np.exp(-x / 0.25))
    out = np.zeros_like(x)
    for detune in (0.997, 1.003):
        f = freq * detune * (1 + 0.004 * np.sin(2 * np.pi * 5.5 * x) * np.minimum(1, x / 0.3))
        phase = 2 * np.pi * np.cumsum(f) / RATE
        for n in range(1, 14):
            weight = np.exp(-n / (1.0 + 7.0 * bright * opening))
            out += weight / n * np.sin(n * phase)
    return out * a


def fanfare_brass() -> np.ndarray:
    """Home: a rising call on brass (A, C#, E, then a held A with its fifth), bells on top, a
    timpani roll under the last chord."""
    out = np.zeros(int(1.8 * RATE))
    steps = [(0, 0.0, 0.16), (2, 0.15, 0.16), (4, 0.3, 0.16), (7, 0.45, 1.2)]
    for deg, at, sec in steps:
        b = brass(note(deg, 0), sec, 1.0)
        if deg == 7:
            b = b + 0.7 * brass(note(4, 0), sec, 0.8) + 0.5 * brass(note(0, 0), sec, 0.7)
        i = int(at * RATE)
        out[i:i + len(b)] += b[: len(out) - i] * 0.5
        bl = bell(note(deg, 1), min(sec + 0.3, 0.9), 1.2) * 0.35
        out[i:i + len(bl)] += bl[: len(out) - i]
    roll = bandnoise(1.0, 50, 300) * (1 + 0.5 * np.sin(2 * np.pi * 18 * t(1.0))) * env(int(1.0 * RATE), 0.05, 0.4)
    i = int(0.45 * RATE)
    out[i:i + len(roll)] += roll[: len(out) - i] * 0.35
    return out


def lose_marimba() -> np.ndarray:
    """Game over: a soft marimba falling down the scale, a low A to end."""
    out = np.zeros(int(1.3 * RATE))
    for k, (deg, oct_) in enumerate([(4, 0), (2, 0), (1, 0), (0, -1)]):
        m = marimba(note(deg, oct_), 0.9 if k == 3 else 0.4)
        i = int(k * 0.17 * RATE)
        out[i:i + len(m)] += m[: len(out) - i] * (1.2 if k == 3 else 1.0)
    return out


def ouch_marimba() -> np.ndarray:
    """Hurt: a body thump, the slap of the club, then a quick falling "uh-oh" on the marimba
    (C# down to A), so even the bad news stays in the key."""
    out = np.zeros(int(0.5 * RATE))
    thump = sweep(170, 55, 0.16) * env(int(0.16 * RATE), 0.002, 0.05)
    out[: len(thump)] += thump
    slap = bandnoise(0.05, 700, 4500) * env(int(0.05 * RATE), 0.0005, 0.01) * 0.7
    out[: len(slap)] += slap
    for k, deg in enumerate((2, 0)):
        m = marimba(note(deg, 0), 0.22) * 0.55
        i = int((0.05 + k * 0.1) * RATE)
        out[i:i + len(m)] += m[: len(out) - i]
    return out


def glide(f0: float, f1: float, sec: float, harmonics=(1.0, 0.35, 0.12)) -> np.ndarray:
    """A tone gliding exponentially from f0 to f1, with a few harmonics (they carry on a phone)."""
    x = t(sec)
    phase = 2 * np.pi * np.cumsum(f0 * (f1 / f0) ** (x / sec)) / RATE
    return sum(a * np.sin((i + 1) * phase) for i, a in enumerate(harmonics))


def modes(x: np.ndarray, table, k: float = 1.0) -> np.ndarray:
    """Struck-object modes: (frequency, amplitude, decay s) partials, frequencies scaled by k."""
    return sum(a * np.sin(2 * np.pi * f * k * x) * np.exp(-x / d) for f, a, d in table)


def at(out: np.ndarray, sec: float, s: np.ndarray, gain: float = 1.0) -> None:
    """Mixes s into out from time sec (its last 5 ms faded: a cut-off tail clicks)."""
    i = int(sec * RATE)
    n = min(len(s), len(out) - i)
    piece = s[:n] * gain
    fade = min(n // 4, int(0.005 * RATE))
    piece[n - fade:] *= np.linspace(1, 0, fade)
    out[i:i + n] += piece


def land(v: int = 0) -> np.ndarray:
    """Landing: boots on packed earth. A low body thump (felt in headphones), a short knock in the
    phone's range, grit and a brush of grass."""
    out = np.zeros(int(0.24 * RATE))
    at(out, 0, sweep(150, 60, 0.16) * env(int(0.16 * RATE), 0.001, 0.045), 0.55)
    at(out, 0, modes(t(0.12), [(240, 1.0, 0.03), (585, 0.5, 0.017), (1120, 0.22, 0.01)], 1 + 0.06 * v), 0.6)
    at(out, 0, bandnoise(0.09, 400, 3500) * env(int(0.09 * RATE), 0.0008, 0.016), 0.75)
    at(out, 0.004, bandnoise(0.14, 3000, 8000) * env(int(0.14 * RATE), 0.002, 0.03), 0.22)
    return out


def hup(pitch: float = 1.0) -> np.ndarray:
    """Jump: a springy rising note (C#4 to E5, in the key) with harmonics, and the swish of cloth."""
    out = np.zeros(int(0.17 * RATE))
    at(out, 0, glide(note(2, -1) * pitch, note(4, 0) * pitch, 0.12) * env(int(0.12 * RATE), 0.003, 0.045), 0.7)
    n = int(0.16 * RATE)
    swish = bandnoise(0.16, 700 * pitch, 4200 * pitch) * np.sin(np.linspace(0, np.pi, n)) ** 2 * np.exp(-np.arange(n) / RATE / 0.07)
    at(out, 0, swish, 0.5)
    return out


def ting2(pitch: float = 1.0) -> np.ndarray:
    """A ring strikes a bandit: a crack, a hard wooden knock in the phone's range, a body thump and
    the ring's metal ringing (E6)."""
    out = np.zeros(int(0.4 * RATE))
    at(out, 0, bandnoise(0.025, 1500, 7000) * env(int(0.025 * RATE), 0.0004, 0.005), 0.9)
    at(out, 0, modes(t(0.2), [(410, 1.0, 0.035), (955, 0.6, 0.02), (1720, 0.35, 0.012)], pitch), 0.8)
    at(out, 0, sweep(190, 90, 0.08) * env(int(0.08 * RATE), 0.001, 0.03), 0.5)
    at(out, 0.005, bell(note(4, 2) * pitch, 0.32, 1.4), 0.4)
    return out


def knockout2() -> np.ndarray:
    """A bandit knocked out: a big crack and knock, a falling cartoon "boing", and two reward bells."""
    out = np.zeros(int(0.6 * RATE))
    at(out, 0, bandnoise(0.035, 1200, 8000) * env(int(0.035 * RATE), 0.0004, 0.007), 1.0)
    at(out, 0, modes(t(0.25), [(330, 1.0, 0.05), (790, 0.6, 0.03), (1480, 0.35, 0.016)]), 0.9)
    at(out, 0, sweep(170, 60, 0.14) * env(int(0.14 * RATE), 0.001, 0.05), 0.7)
    boing = glide(note(4, 0), note(0, -1), 0.34) * env(int(0.34 * RATE), 0.01, 0.14)
    boing *= 1 + 0.3 * np.sin(2 * np.pi * 18 * t(0.34))
    at(out, 0.05, boing, 0.45)
    at(out, 0.07, bell(note(4, 2), 0.3, 1.3), 0.22)
    at(out, 0.15, bell(note(0, 3), 0.4, 1.3), 0.22)
    return out


def splash(v: int = 0) -> np.ndarray:
    """Into a pool: the plunk of the water closing (a bloop rising in pitch), the rush of the water,
    spray, then drops falling back."""
    r = np.random.default_rng(40 + v)
    out = np.zeros(int(0.65 * RATE))
    at(out, 0, sweep(240, 560, 0.07) * env(int(0.07 * RATE), 0.002, 0.03), 0.8)
    at(out, 0, bandnoise(0.4, 250, 5000) * env(int(0.4 * RATE), 0.003, 0.08), 0.8)
    n = int(0.5 * RATE)
    grains = np.convolve(np.abs(r.standard_normal(n)), np.ones(200) / 200, "same") ** 2
    at(out, 0.01, bandnoise(0.5, 2500, 11000) * env(n, 0.01, 0.12) * grains / grains.max(), 0.5)
    for k in range(9):
        f0 = r.uniform(700, 1700)
        drop = sweep(f0, f0 * 2.2, 0.025) * env(int(0.025 * RATE), 0.001, 0.008)
        at(out, r.uniform(0.08, 0.5), drop, 0.35 * (1 - k / 12))
    return out


def spring() -> np.ndarray:
    """Out of the pit and back up: a whoosh sweeping up, a rising glide (A3 to A5) and a sparkle."""
    out = np.zeros(int(0.6 * RATE))
    sec = 0.4
    n = int(sec * RATE)
    for i, lo in enumerate(np.geomspace(300, 3000, 10)):
        w = np.exp(-((np.arange(n) / n - i / 12) ** 2) / 0.015)
        at(out, 0, bandnoise(sec, lo, lo * 2.0) * w * np.hanning(n), 0.35)
    g = glide(note(0, -1), note(0, 1), 0.32) * env(int(0.32 * RATE), 0.02, 0.22)
    g *= 1 + 0.15 * np.sin(2 * np.pi * 9 * t(0.32))
    at(out, 0.02, g, 0.5)
    at(out, 0.3, bell(note(4, 2), 0.25, 1.3), 0.25)
    at(out, 0.36, bell(note(0, 3), 0.25, 1.3), 0.2)
    return out


def fell() -> np.ndarray:
    """A fall that costs a life: a falling "uh-oh" on the marimba (C#5 to A4) over a few bubbles."""
    r = np.random.default_rng(60)
    out = np.zeros(int(0.6 * RATE))
    for k, deg in enumerate((2, 0)):
        at(out, k * 0.13, marimba(note(deg, 0), 0.3 if k == 0 else 0.45), 0.8)
    for k in range(5):
        f0 = r.uniform(300, 600)
        at(out, r.uniform(0.0, 0.35), sweep(f0, f0 * 1.8, 0.03) * env(int(0.03 * RATE), 0.002, 0.01), 0.25)
    return out


def bling_same(v: int = 0) -> np.ndarray:
    """Red Bob: two quick rising bell notes and a sparkle; the variants share one pitch (the game
    raises it up the scale for a quick run of Bobs)."""
    a = bell(note(4, 1), 0.08, 1.2 + 0.1 * v)
    b = bell(note(0, 2), 0.3, 1.4 + 0.15 * v)
    sparkle = bandnoise(0.12, 6000, 12000) * env(int(0.12 * RATE), 0.002, 0.04) * 0.12
    out = np.concatenate([a[: int(0.055 * RATE)], b])
    out[int(0.055 * RATE): int(0.055 * RATE) + len(sparkle)] += sparkle
    return out


RECIPES.update({
    "sfx_button": (lambda v: pop(1 + 0.06 * v), 3, 0.6),
    "sfx_toggle_on": (lambda v: toggle(True), 1, 0.55),
    "sfx_toggle_off": (lambda v: toggle(False), 1, 0.55),
    "sfx_panel_open": (lambda v: pop(1.25), 1, 0.5),
    "sfx_panel_close": (lambda v: pop(0.8), 1, 0.5),
    "sfx_wipe": (lambda v: whoosh(), 1, 0.45),
    "sfx_jump": (lambda v: hup(1 + 0.05 * v), 3, -19.0),
    "sfx_land": (lambda v: land(v), 3, -20.0),
    "sfx_hang": (lambda v: clink(), 1, 0.6),
    "sfx_let_go": (lambda v: drop(), 1, -21.0),
    "sfx_step": (lambda v: footstep(), 1, 0.4),
    "sfx_throw": (lambda v: swish(1 + 0.06 * v), 3, -21.0),
    "sfx_ring_hit": (lambda v: ting2(1 + 0.07 * v), 2, -16.0),
    "sfx_knock_out": (lambda v: knockout2(), 1, -13.0),
    "sfx_bob": (lambda v: bling_same(v), 3, 0.6),
    "sfx_hurt": (lambda v: ouch_marimba(), 1, -14.0),
    "sfx_fall": (lambda v: fall(), 1, -14.0),
    "sfx_fell": (lambda v: fell(), 1, -15.0),
    "sfx_spring": (lambda v: spring(), 1, -17.0),
    "sfx_splash": (lambda v: splash(v), 2, -15.0),
    "sfx_game_over": (lambda v: lose_marimba(), 1, 0.8),
    "sfx_win": (lambda v: fanfare_brass(), 1, 0.85),
    "sfx_star": (lambda v: star(0), 1, 0.7),
    "sfx_counter": (lambda v: tick(1.0), 1, 0.45),
    "sfx_tick": (lambda v: tick(1.12), 1, 0.4),
    "sfx_new_best": (lambda v: fanfare(), 1, 0.9),
})
GAME = [k for k in RECIPES if k.startswith("sfx_")]


def phone(s: np.ndarray) -> np.ndarray:
    """What a phone speaker plays: a 4th-order high-pass at 350 Hz."""
    spec = np.fft.rfft(s)
    f = np.fft.rfftfreq(len(s), 1 / RATE)
    return np.fft.irfft(spec / np.sqrt(1 + (350 / np.maximum(f, 1.0)) ** 8), len(s))


def loudness(s: np.ndarray) -> float:
    """dB RMS of the first 0.3 s as a phone plays it."""
    p = phone(s)[: int(0.3 * RATE)]
    return 20 * np.log10(np.sqrt((p ** 2).mean()) + 1e-12)


CEILING = 0.89  # -1 dBFS


def finish(s: np.ndarray, level: float) -> np.ndarray:
    s = s - s.mean()
    nz = np.nonzero(np.abs(s) > 1e-3 * np.abs(s).max())[0]
    s = s[nz[0]: nz[-1] + 1]
    fade = min(len(s) // 4, int(0.005 * RATE))
    s[:fade] *= np.linspace(0, 1, fade)
    s[-fade:] *= np.linspace(1, 0, fade)
    if level > 0:
        return s / (np.abs(s).max() + 1e-9) * level
    s = s * 10 ** ((level - loudness(s)) / 20)
    peak = np.abs(s).max()
    if peak > CEILING:  # a soft knee above the ceiling rather than a quieter sound
        k = 0.6 * CEILING
        over = np.abs(s) > k
        s[over] = np.sign(s[over]) * (k + (CEILING - k) * np.tanh((np.abs(s[over]) - k) / (CEILING - k)))
    return s


def write(path: Path, s: np.ndarray) -> None:
    pcm = np.clip(s * 32767 + rng.uniform(-0.5, 0.5, len(s)), -32768, 32767).astype(np.int16)  # dithered
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("assets/audio")
    names = sys.argv[2:] or GAME
    out.mkdir(parents=True, exist_ok=True)
    for name in names:
        make, variants, peak = RECIPES[name]
        for v in range(variants):
            file = out / (f"{name}.wav" if variants == 1 else f"{name}_{v + 1}.wav")
            s = finish(make(v), peak)
            write(file, s)
            print(f"{file}  {loudness(s):6.1f} dB on a phone, peak {20 * np.log10(np.abs(s).max()):5.1f} dBFS")


if __name__ == "__main__":
    main()
