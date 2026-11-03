#!/usr/bin/env python3
"""Chaka Zulu's sound effects, synthesised from scratch (numpy + scipy: tools/audio_dsp.py): no
samples, no paid service, nothing to license.

One family: wood, metal and air. Movement is foley (boots on packed earth, dry grass, cloth, air);
the ring is bright metal; rewards are the score's kalimba and bells, always on notes of A major (the
key of the music), so a pickup or a star sounds like part of the tune.

Made for a phone's speaker, which plays almost nothing under 300 Hz:
- every hit has three layers: a transient (a 10-30 ms crack or crunch at 1.5-6 kHz, where the
  speaker is loudest), a body (an 80-150 ms foley thud at 300 Hz-1.5 kHz) and a sweetener (a ting,
  a whoosh, a chime);
- the weight of a thump is kept as harmonics (audio_dsp.phone: the lows saturated, the sub-bass the
  speaker can't play cut under 110 Hz);
- loudness follows importance (integrated LUFS): death -14 > hurt -16 > KO -17 > ring hit -18 >
  pickup -21 > land -23 > jump -24 > step -27 > footstep -30; every file peaks at -3 dBTP or under
  (Master's limiter at -1 dB catches a pile-up);
- frequent sounds are short (a pickup 0.25 s, a KO 0.5 s, a hurt 0.4 s, the death 0.8 s: the
  stinger carries the rest) and come in 4-6 takes (the game varies them by ±1.2 semitones and
  ±1.5 dB too);
- every layer ends in a fade, also where the file cuts it (audio_dsp.place), and every file is
  checked for cuts and clicks (tools/audio_report.py).

Each recipe lists how it should sound (RECIPES: the 4th field), copied into the measurement table.

Usage: python3 tools/sfx_synth.py [assets/audio] [name ...] [--no-grains]   (default: all)
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import audio_dsp as dsp
from audio_dsp import (RATE, adsr, bp, drum, fade, fm, glide, hp, lp, master, modal, n_of, noise, note, pan, perc,
                       phase_of, phone, place, reverb, saturate, seed, snap, sweep_noise, t, taper, tone, trim,
                       write_wav)

CEILING = -3.0  ## dBTP: the effects leave headroom for a pile-up (Master limits at -1)
NO_GRAINS = "--no-grains" in sys.argv  ## renders without the grit grains (to check the clicks)


def buf(sec: float) -> np.ndarray:
    return np.zeros(n_of(sec))


# ---------------------------------------------------------------- instruments (shared with the music)

def kalimba(f: float, sec: float = 1.2, bright: float = 1.0) -> np.ndarray:
    """A thumb piano tine: the note, its inharmonic first overtone (~6x) that dies fast, a click
    of the thumb and a knock of the box."""
    x = t(sec)
    bend = 1 + 0.004 * np.exp(-x / 0.01)
    ring = 0.55 * (440 / f) ** 0.3
    s = np.sin(phase_of(f * bend)) * np.exp(-x / ring)
    s += 0.12 * np.sin(2 * phase_of(f * bend)) * np.exp(-x / (ring * 0.4))
    s += 0.32 * bright * np.sin(phase_of(f * 5.95 * bend)) * np.exp(-x / 0.035)
    s += 0.1 * bright * np.sin(phase_of(f * 13.2)) * np.exp(-x / 0.01)
    click = bp(noise(0.006), 2500, 9000) * perc(0.006, 0.0002, 0.0012) * 0.25 * bright
    place(s, 0, click)
    place(s, 0, bp(noise(0.05), 180, 800) * perc(0.05, 0.001, 0.012), 0.12)
    return taper(fade(s, 0.0004, 0.01), 0.25)


def marimba(f: float, sec: float = 0.8) -> np.ndarray:
    """A wooden bar over its tube: the note, the bar's 4th and 10th partials (short), the mallet."""
    x = t(sec)
    d = 0.32 * (440 / f) ** 0.5
    s = np.sin(2 * np.pi * f * x) * np.exp(-x / d)
    s += 0.28 * np.sin(2 * np.pi * f * 3.99 * x) * np.exp(-x / 0.045)
    s += 0.08 * np.sin(2 * np.pi * f * 9.2 * x) * np.exp(-x / 0.012)
    place(s, 0, lp(noise(0.01), 3000) * perc(0.01, 0.0005, 0.002), 0.2)
    return taper(fade(s, 0.0005, 0.01), 0.3)


def bell(f: float, sec: float = 0.8, bright: float = 1.0) -> np.ndarray:
    """A small glockenspiel bar: partials 1, 2.76, 5.40, 8.93 (a free bar), the high ones short."""
    x = t(sec)
    s = np.zeros_like(x)
    for r, a, d in [(1, 1.0, 0.45), (2.756, 0.35 * bright, 0.12), (5.404, 0.18 * bright, 0.05),
                    (8.933, 0.08 * bright, 0.02)]:
        s += a * np.sin(2 * np.pi * f * r * x + dsp.rng.uniform(0, 1)) * np.exp(-x / (d * sec / 0.8))
    return taper(fade(s * perc(sec, 0.0008, 10), 0.0005, 0.01), 0.25)


def woodblock(f: float = 1900.0, sec: float = 0.12) -> np.ndarray:
    return modal(sec, [(f, 1.0, 0.03), (f * 2.71, 0.4, 0.012), (f * 0.52, 0.3, 0.02)])


# ---------------------------------------------------------------- foley parts

def grains(sec: float, count: int, lo: float, hi: float, length=(0.003, 0.012), spread: float = 1.0,
           decay: float = 0.04) -> np.ndarray:
    """Crunch: short grains of band-passed noise (grit, dry grass) packed near the start."""
    out = buf(sec)
    if NO_GRAINS:  # (a check: tools/audio_report.py's click test, without the grains it would flag)
        return out
    for _ in range(count):
        d = dsp.rng.uniform(*length)
        c = dsp.rng.uniform(lo, hi)
        g = bp(noise(d + 0.01), c * 0.6, min(c * 1.6, 20000))[: n_of(d)] * np.hanning(n_of(d))
        at = abs(dsp.rng.normal(0, decay)) * spread
        place(out, min(at, sec - d), g, dsp.rng.uniform(0.3, 1.0))
    return out


def thump(f0: float, f1: float, sec: float, decay: float, drive: float = 1.5) -> np.ndarray:
    """The weight of a blow: a sine dropping from f0 to f1, a little saturated (phone() then keeps
    it as harmonics the speaker can play)."""
    return saturate(np.sin(phase_of(glide(f0, f1, sec, 0.5))) * perc(sec, 0.0012, decay), drive)


def thud(sec: float, lo: float, hi: float, k: float = 1.0, decay: float = 0.03) -> np.ndarray:
    """The body of a hit (300 Hz-1.5 kHz, where a phone plays it): a burst of band-passed noise and
    three resonances of what was struck."""
    out = bp(noise(sec), lo * k, hi * k, 2) * perc(sec, 0.0008, decay)
    centre = np.sqrt(lo * hi) * k
    out += 0.6 * modal(sec, [(centre * 0.62, 1.0, decay * 1.3), (centre * 1.15, 0.6, decay * 0.8),
                             (centre * 2.05, 0.35, decay * 0.5)])
    return out


def whoosh(sec: float, f0: float, f1: float, width: float = 1.3, attack: float = 0.3) -> np.ndarray:
    """Air: noise in a band gliding f0 to f1, swelling then fading (`attack`: where the peak is)."""
    x = t(sec) / sec
    shape = np.where(x < attack, (x / attack) ** 2, np.exp(-(x - attack) / (1 - attack) * 3.5))
    return sweep_noise(sec, f0, f1, width) * shape


def breath(sec: float, lo: float = 500.0, hi: float = 1800.0, attack: float = 0.012) -> np.ndarray:
    """A short breath out ("hff"): air through the throat's band, quick in, falling away."""
    return bp(noise(sec), lo, hi, 2) * adsr(sec, attack, sec * 0.3, 0.3, sec * 0.5)


def creak(sec: float, f0: float) -> np.ndarray:
    """Wood or vine under strain: a rough FM tone that sticks and slips."""
    stick = (dsp.rng.random(n_of(sec)) < 0.005).astype(float)
    stick = np.convolve(stick, np.hanning(260), "same") * 0.4  # each slip a soft 6 ms swell, not a click
    wobble = 1 + 0.06 * np.sin(2 * np.pi * 7 * t(sec))
    return bp(fm(f0 * wobble, 2.3, 3.0) * (0.3 + stick) * adsr(sec, 0.03, sec * 0.3, 0.6, sec * 0.3), 150, 2500)


def room(x: np.ndarray, mix: float, decay: float = 0.5, damp: float = 5000.0) -> np.ndarray:
    return reverb(x, mix, decay, damp)


# ---------------------------------------------------------------- the moves

def footstep(v: int) -> np.ndarray:
    seed(100 + v)
    k = 1 + 0.07 * (v % 3 - 1)
    out = buf(0.13)
    place(out, 0, snap(0.012, 1800, 5000, 0.002), 0.35)
    place(out, 0, bp(noise(0.05), 280 * k, 1100 * k) * perc(0.05, 0.001, 0.012), 0.8)
    place(out, 0, thump(140 * k, 80 * k, 0.05, 0.014, 1.2), 0.5)
    place(out, 0.018 + 0.005 * (v % 2), bp(noise(0.03), 400 * k, 1500 * k) * perc(0.03, 0.001, 0.008), 0.35)
    place(out, 0.002, grains(0.09, 6 + v % 3, 1500, 6000, decay=0.018), 0.4)
    return phone(room(out, 0.05, 0.2))


def jump(v: int) -> np.ndarray:
    seed(200 + v)
    k = 1 + 0.04 * (v - 2)
    out = buf(0.3)
    place(out, 0, snap(0.015, 1500, 4500, 0.003), 0.5)
    place(out, 0, bp(noise(0.04), 250, 1800) * perc(0.04, 0.001, 0.012), 0.6)
    place(out, 0.005, whoosh(0.24, 700 * k, 3200 * k, 1.3, 0.3), 0.75)
    place(out, 0, grains(0.08, 6, 1500, 6000, decay=0.02), 0.3)
    lift = tone(glide(note(2, -1) * k, note(0, 0) * k, 0.12, 0.7), (1.0, 0.3)) * perc(0.12, 0.006, 0.04)
    place(out, 0.01, lift, 0.06)
    return phone(room(out, 0.06, 0.3))


def land(v: int) -> np.ndarray:
    seed(300 + v)
    k = 1 + 0.05 * (v - 2)
    out = buf(0.3)
    place(out, 0, grains(0.05, 10, 1500, 4500, decay=0.012), 0.7)
    place(out, 0, snap(0.02, 1500, 4000, 0.004), 0.5)
    place(out, 0, thud(0.15, 300, 1400, k), 0.9)
    place(out, 0, thump(120 * k, 50 * k, 0.14, 0.04, 2.0), 0.7)
    place(out, 0.01, lp(noise(0.2), 1800) * perc(0.2, 0.02, 0.05), 0.12)
    return phone(room(out, 0.08, 0.35))


def step(v: int) -> np.ndarray:
    seed(400 + v)
    out = buf(0.18)
    place(out, 0, sweep_noise(0.09, 700, 1900, 1.5) * perc(0.09, 0.006, 0.03), 0.6)
    place(out, 0.005, grains(0.1, 8, 1500, 6000, decay=0.025), 0.4)
    place(out, 0, thud(0.06, 350, 1200, 1 + 0.05 * v, 0.015), 0.4)
    return phone(room(out, 0.05, 0.25))


def throw(v: int) -> np.ndarray:
    seed(500 + v)
    k = 1 + 0.035 * (v - 2)
    out = buf(0.3)
    place(out, 0, snap(0.012, 2000, 5000, 0.002), 0.4)
    place(out, 0.004, whoosh(0.2, 1400 * k, 4200 * k, 1.0, 0.25), 0.8)
    sec = 0.22
    x = t(sec)
    f = glide(note(4, 1) * k, note(4, 1) * k * 2 ** (1.5 / 12), sec)
    zing = fm(f, 1.414, 1.6 * np.exp(-x / 0.1) + 0.3, sec) * perc(sec, 0.004, 0.06)
    zing *= 1 - 0.45 * (0.5 + 0.5 * np.sin(2 * np.pi * 26 * x))
    place(out, 0.01, hp(zing, 600), 0.25)
    return room(out, 0.08, 0.35)


def ring_hit(v: int) -> np.ndarray:
    seed(600 + v)
    k = 1 + 0.06 * (v - 2)
    out = buf(0.35)
    place(out, 0, snap(0.025, 2000, 6000, 0.004), 1.0)
    place(out, 0, thud(0.12, 300, 1500, k), 1.0)
    place(out, 0, thump(180 * k, 70, 0.08, 0.025, 2.0), 0.5)
    place(out, 0.002, modal(0.3, [(1318 * k, 1.0, 0.13), (1318 * k * 2.756, 0.4, 0.05), (1318 * k * 5.404, 0.2, 0.02)]),
          0.4)
    return phone(room(out, 0.1, 0.35))


def knock_out(v: int) -> np.ndarray:
    seed(700 + v)
    k = 1 + 0.04 * (v - 2)
    out = buf(0.5)
    place(out, 0, snap(0.03, 1800, 6000, 0.006), 1.0)
    place(out, 0, thud(0.16, 250, 1300, 0.9 * k, 0.04), 1.1)
    place(out, 0, thump(160 * k, 45, 0.16, 0.05, 2.6), 0.8)
    place(out, 0.002, modal(0.3, [(880 * k, 1.0, 0.12), (880 * k * 2.756, 0.45, 0.05), (880 * k * 5.404, 0.2, 0.02)]), 0.2)
    place(out, 0.03, whoosh(0.3, 2400, 600, 1.4, 0.15), 0.3)
    place(out, 0.06, kalimba(note(4, 1), 0.3), 0.28)
    place(out, 0.12, kalimba(note(0, 2), 0.34), 0.28)
    return phone(room(out, 0.12, 0.4))


def bob(step_: int) -> np.ndarray:
    seed(800 + step_)
    f1, f2 = note(step_, 1), note(step_ + 2, 1)
    out = buf(0.24)
    place(out, 0, kalimba(f1, 0.07), 0.5)
    place(out, 0.04, kalimba(f2, 0.19), 0.8)
    place(out, 0.04, bell(f2 * 2, 0.17, 0.7), 0.12)
    place(out, 0.035, grains(0.12, 5, 8000, 14000, length=(0.002, 0.004), decay=0.03), 0.1)
    return room(out, 0.06, 0.18, 7000)[: n_of(0.25)]


def streak() -> np.ndarray:
    seed(850)
    out = buf(0.6)
    for i, d in enumerate([0, 2, 4, 7]):
        place(out, i * 0.025, kalimba(note(d, 2), 0.5), 0.4)
        place(out, i * 0.025, bell(note(d, 2), 0.45, 0.8), 0.1)
    place(out, 0.02, grains(0.4, 16, 7000, 14000, length=(0.002, 0.005), decay=0.1), 0.15)
    return room(out, 0.15, 0.5, 7000)


def hurt(v: int) -> np.ndarray:
    seed(900 + v)
    k = 1 + 0.05 * (v - 2)
    out = buf(0.4)
    place(out, 0, snap(0.02, 1500, 4000, 0.004), 0.9)
    place(out, 0, thud(0.2, 200, 1000, k, 0.06), 1.1)
    place(out, 0, thump(150 * k, 48, 0.16, 0.05, 2.5), 0.9)
    place(out, 0.02, breath(0.26, 500 * k, 1700 * k), 0.55)
    sting = tone(glide(note(0, -1), note(0, -1) * 2 ** (-1 / 12), 0.26), (1.0, 0.4, 0.25, 0.15)) * perc(0.26, 0.005, 0.09)
    place(out, 0.03, lp(sting, 2500), 0.16)
    return phone(room(out, 0.08, 0.3))


def death() -> np.ndarray:
    seed(950)
    out = buf(0.85)
    place(out, 0, snap(0.03, 1500, 5000, 0.006), 1.0)
    place(out, 0, thud(0.18, 200, 1100, 1.0, 0.05), 1.2)
    place(out, 0, thump(110, 32, 0.6, 0.18, 2.2), 1.0)
    place(out, 0.02, whoosh(0.5, 2500, 300, 1.6, 0.12), 0.35)
    place(out, 0.02, breath(0.28, 400, 1400, 0.02), 0.35)
    sink = tone(glide(220, 110, 0.5, 0.8), (1.0, 0.5, 0.3, 0.15)) * adsr(0.5, 0.03, 0.2, 0.6, 0.2)
    place(out, 0.05, lp(sink, 1500), 0.16)
    place(out, 0.45, thud(0.12, 200, 800, 1.0, 0.03), 0.6)
    place(out, 0.45, grains(0.2, 10, 1200, 4500, decay=0.04), 0.4)
    return phone(room(out, 0.15, 0.6, 3500))


def fall(v: int) -> np.ndarray:
    seed(960 + v)
    out = buf(0.85)
    place(out, 0, whoosh(0.6, 2600, 350, 1.6, 0.25), 0.7)
    x = t(0.5)
    flutter = bp(noise(0.5), 600, 2500) * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * x)) * adsr(0.5, 0.05, 0.2, 0.6, 0.15)
    place(out, 0.02, flutter, 0.25)
    place(out, 0.6, lp(thud(0.15, 200, 900, 1.0, 0.04), 1200), 0.6)
    place(out, 0.6, grains(0.15, 8, 800, 3000, decay=0.03), 0.25)
    return phone(room(out, 0.2, 0.7, 3000))


def fell() -> np.ndarray:
    seed(970)
    out = buf(0.55)
    place(out, 0, marimba(note(2, 0), 0.25), 0.8)
    place(out, 0.12, marimba(note(0, 0), 0.4), 0.9)
    place(out, 0, whoosh(0.35, 1800, 500), 0.15)
    return room(out, 0.12, 0.4)


def spring() -> np.ndarray:
    seed(980)
    out = buf(0.65)
    place(out, 0, whoosh(0.4, 400, 3500, 1.4, 0.6), 0.45)
    sec = 0.3
    x = t(sec)
    g = tone(glide(note(0, -1), note(0, 1), sec, 1.2) * (1 + 0.01 * np.sin(2 * np.pi * 11 * x)), (1.0, 0.3, 0.12))
    place(out, 0.02, g * adsr(sec, 0.03, 0.2, 0.7, 0.1), 0.25)
    place(out, 0.3, bell(note(4, 2), 0.3), 0.2)
    place(out, 0.35, bell(note(0, 3), 0.3), 0.16)
    return room(out, 0.15, 0.45, 7000)


def splash(v: int) -> np.ndarray:
    r = np.random.default_rng(40 + v)
    seed(990 + v)
    out = buf(0.6)
    place(out, 0, lp(noise(0.06), 5000) * perc(0.06, 0.001, 0.015), 0.6)
    place(out, 0, snap(0.015, 1500, 4500, 0.003), 0.4)
    place(out, 0.004, np.sin(phase_of(glide(260, 640 + 40 * v, 0.07))) * perc(0.07, 0.002, 0.03), 0.6)
    place(out, 0, bp(noise(0.4), 300, 4500) * perc(0.4, 0.008, 0.09), 0.55)
    n = n_of(0.4)
    grit = np.convolve(np.abs(r.standard_normal(n)), np.ones(160) / 160, "same") ** 3
    place(out, 0.01, hp(noise(0.4), 3000) * perc(0.4, 0.01, 0.1) * grit / grit.max(), 0.35)
    for _ in range(12):
        f0 = r.uniform(500, 2400)
        d = r.uniform(0.01, 0.03)
        b = np.sin(phase_of(f0 * (1 + 0.4 * t(d * 3) / (d * 3)))) * perc(d * 3, 0.001, d)
        place(out, r.uniform(0.06, 0.45), b, r.uniform(0.08, 0.25))
    return phone(room(out, 0.12, 0.4))


def hang(v: int) -> np.ndarray:
    seed(1000 + v)
    out = buf(0.42)
    place(out, 0, snap(0.015, 1500, 3500, 0.003), 0.6)
    place(out, 0, bp(noise(0.03), 600, 2500) * perc(0.03, 0.0004, 0.007), 0.5)
    place(out, 0.02, creak(0.26, 170 + 20 * v), 0.35)
    place(out, 0.01, grains(0.32, 16, 2500, 8000, length=(0.006, 0.02), decay=0.07), 0.3)
    place(out, 0.004, modal(0.2, [(2650, 1.0, 0.04), (2650 * 2.32, 0.5, 0.02)]), 0.1)
    place(out, 0, thump(140, 90, 0.05, 0.015), 0.25)
    return phone(room(out, 0.08, 0.35))


def vine_creak(v: int) -> np.ndarray:
    seed(1005 + v)
    out = buf(0.5)
    place(out, 0, creak(0.42, 150 + 25 * v), 0.6)
    place(out, 0.05, grains(0.3, 6, 2500, 7000, length=(0.008, 0.02), decay=0.08), 0.15)
    return room(out, 0.1, 0.35)


def let_go() -> np.ndarray:
    seed(1010)
    out = buf(0.4)
    place(out, 0, grains(0.3, 12, 2500, 8000, length=(0.006, 0.02), decay=0.06), 0.4)
    place(out, 0.01, whoosh(0.3, 2200, 600, 1.4, 0.25), 0.45)
    return room(out, 0.08, 0.3)


def grab(v: int) -> np.ndarray:
    seed(1020 + v)
    out = buf(0.2)
    place(out, 0, snap(0.012, 1800, 4500, 0.0025), 0.7)
    place(out, 0, thud(0.07, 400, 1400, 1 + 0.06 * v, 0.018), 0.8)
    place(out, 0.02, grains(0.15, 7, 1200, 5000, decay=0.05), 0.35)
    return phone(room(out, 0.06, 0.25))


def mantle(v: int) -> np.ndarray:
    seed(1030 + v)
    out = buf(0.34)
    place(out, 0, sweep_noise(0.2, 500, 1500, 1.4) * adsr(0.2, 0.03, 0.08, 0.6, 0.06), 0.55)
    place(out, 0.14, thud(0.1, 300, 1100, 1.0, 0.025), 0.8)
    place(out, 0.14, thump(130, 70, 0.08, 0.025), 0.4)
    place(out, 0.02, breath(0.14, 600, 1700), 0.2)
    place(out, 0.15, grains(0.15, 8, 1200, 5000, decay=0.04), 0.35)
    return phone(room(out, 0.06, 0.3))


def bump(v: int) -> np.ndarray:
    seed(1040 + v)
    out = buf(0.45)
    place(out, 0, snap(0.012, 1500, 4000, 0.003), 0.7)
    place(out, 0, thud(0.1, 300, 900, 1 + 0.05 * v, 0.025), 1.0)
    place(out, 0, modal(0.09, [(420 * (1 + 0.05 * v), 1.0, 0.03), (950, 0.5, 0.015)]), 0.5)
    place(out, 0.04, grains(0.38, 14, 800, 4000, length=(0.005, 0.015), decay=0.12), 0.35)
    return phone(room(out, 0.06, 0.3))


def heart_break() -> np.ndarray:
    seed(1050)
    out = buf(0.45)
    place(out, 0, snap(0.01, 2500, 7000, 0.002), 0.8)
    place(out, 0, modal(0.3, [(1870, 1.0, 0.12), (2930, 0.7, 0.08), (4410, 0.5, 0.05), (6120, 0.35, 0.03)]), 0.45)
    place(out, 0.01, grains(0.25, 12, 3000, 9000, length=(0.002, 0.006), decay=0.06), 0.3)
    place(out, 0, thud(0.1, 200, 700, 1.0, 0.03), 0.6)
    return phone(room(out, 0.1, 0.35))


def last_heart() -> np.ndarray:
    seed(1060)
    out = buf(0.8)
    for at, g in [(0.0, 1.0), (0.18, 1.05)]:
        place(out, at, thump(85, 55, 0.12, 0.035, 2.5), g)
        place(out, at, thud(0.1, 150, 600, 1.0, 0.025), 0.6 * g)
    x = t(0.7)
    tense = (np.sin(2 * np.pi * note(4, 0) * x) + 0.8 * np.sin(2 * np.pi * note(4, 0) * 2 ** (1 / 12) * x))
    tense *= (0.6 + 0.4 * np.sin(2 * np.pi * 8 * x)) * adsr(0.7, 0.08, 0.2, 0.6, 0.3)
    place(out, 0.05, tense, 0.12)
    return phone(room(out, 0.1, 0.4))


def door() -> np.ndarray:
    seed(1070)
    out = buf(1.3)
    place(out, 0, whoosh(0.55, 500, 3000, 1.3, 0.55), 0.5)
    sec = 1.1
    swell = sum(tone(np.full(n_of(sec), f), (1.0, 0.3, 0.12)) for f in (220.0, 277.2, 329.6)) * adsr(sec, 0.35, 0.3, 0.8, 0.5)
    place(out, 0.1, lp(swell, 2500), 0.12)
    place(out, 0.35, bell(note(0, 1), 0.7, 0.6), 0.12)
    place(out, 0.45, bell(note(4, 1), 0.7, 0.6), 0.1)
    return room(out, 0.2, 0.7, 6000)


def coins(v: int) -> np.ndarray:
    r = np.random.default_rng(1080 + v)
    seed(1080 + v)
    out = buf(1.8)
    for _ in range(30):
        f = r.uniform(2800, 5500)
        at = min(r.exponential(0.45), 1.5)
        ping = modal(0.12, [(f, 1.0, r.uniform(0.03, 0.08)), (f * 2.41, 0.4, 0.02), (f * 4.1, 0.2, 0.01)])
        place(out, at, ping, r.uniform(0.15, 0.6) * np.exp(-at / 1.2))
    for _ in range(4):  # a few heavier coins bouncing on wood
        f = r.uniform(1800, 2400)
        at = r.uniform(0.1, 1.0)
        for b in range(3):
            place(out, at + b * 0.06 * (0.8 ** b), modal(0.06, [(f, 1.0, 0.02), (f * 2.7, 0.5, 0.01)]), 0.5 * 0.6 ** b)
    return room(out, 0.12, 0.4, 8000)


def firework(v: int) -> np.ndarray:
    seed(1090 + v)
    out = buf(1.1)
    place(out, 0, whoosh(0.22, 1500, 5000, 1.2, 0.85), 0.25)
    place(out, 0.22, snap(0.02, 1500, 5000, 0.004), 0.8)
    place(out, 0.22, thud(0.12, 250, 900, 1 + 0.08 * v, 0.03), 0.6)
    place(out, 0.22, thump(110, 50, 0.2, 0.06, 2.0), 0.4)
    place(out, 0.3, grains(0.7, 34, 2500, 9000, length=(0.002, 0.006), decay=0.2), 0.3)
    return phone(room(out, 0.2, 0.9, 6000))


# ---------------------------------------------------------------- interface

def button(v: int) -> np.ndarray:
    seed(1100 + v)
    f = note(v, 0)
    out = buf(0.16)
    place(out, 0, tone(glide(f * 1.3, f, 0.12, 0.25), (1.0, 0.18)) * perc(0.12, 0.002, 0.035), 0.8)
    place(out, 0, modal(0.04, [(f * 2.8, 1.0, 0.008), (f * 6.1, 0.4, 0.004)]), 0.25)
    place(out, 0, hp(noise(0.004), 3000) * perc(0.004, 0.0002, 0.0008), 0.12)
    return room(out, 0.05, 0.2, 6000)


def panel(opening: bool) -> np.ndarray:
    seed(1120 if opening else 1121)
    out = buf(0.4)
    sw = whoosh(0.2, 500, 2400, 1.2, 0.8) if opening else whoosh(0.2, 2400, 500, 1.2, 0.15)
    place(out, 0, sw, 0.35)
    f = note(4, 0) if opening else note(0, 0)
    place(out, 0.16 if opening else 0.0, tone(glide(f * 1.25, f, 0.15, 0.25), (1.0, 0.2)) * perc(0.15, 0.002, 0.04), 0.6)
    return room(out, 0.06, 0.25)


def toggle(on: bool) -> np.ndarray:
    seed(1130 if on else 1131)
    a, b = (note(2, 0), note(4, 0)) if on else (note(4, 0), note(2, 0))
    out = buf(0.45)
    place(out, 0, woodblock(2400, 0.06), 0.4)
    place(out, 0.0, marimba(a, 0.22), 0.55)
    place(out, 0.06, marimba(b, 0.34), 0.6 if on else 0.45)
    return room(out, 0.05, 0.2)


def wipe() -> np.ndarray:
    seed(1140)
    sec = 0.42
    w = whoosh(sec, 400, 2200, 1.3, 0.45) * 0.8 + whoosh(sec, 1800, 5000, 1.0, 0.5) * 0.2
    x = t(sec) / sec
    a = (-0.8 + 1.6 * x + 1) * np.pi / 4
    return np.stack([w * np.cos(a), w * np.sin(a)], axis=1)


def tick() -> np.ndarray:
    seed(1150)
    out = buf(0.09)
    place(out, 0, woodblock(2100, 0.05), 0.35)
    place(out, 0, kalimba(note(4, 1), 0.06, 0.6), 0.5)
    return out


def count(n: int) -> np.ndarray:
    seed(1160 + n)
    f = note({3: 0, 2: 2, 1: 4}[n], 0)
    out = buf(0.5)
    place(out, 0, drum(f / 4, 0.3, 0.1, 0.3), 0.45)
    place(out, 0, woodblock(1700 + 200 * (3 - n), 0.08), 0.35)
    place(out, 0.002, kalimba(f, 0.42), 0.6)
    return phone(room(out, 0.1, 0.35))


def go() -> np.ndarray:
    seed(1170)
    out = buf(0.8)
    place(out, 0, drum(196, 0.3, 0.1, 0.9, 0.04), 0.5)
    place(out, 0, snap(0.02, 2500, 6000, 0.004), 0.3)
    for i, d in enumerate([0, 2, 4, 7]):
        place(out, 0.008 * i, kalimba(note(d, 1), 0.7), 0.35)
        place(out, 0.008 * i, bell(note(d, 2), 0.5, 0.7), 0.08)
    place(out, 0, whoosh(0.35, 600, 3500, 1.2, 0.4), 0.3)
    return phone(room(out, 0.14, 0.5))


def star(i: int) -> np.ndarray:
    seed(1180 + i)
    f = note(2 * i, 1)
    out = buf(0.9)
    place(out, 0, thump(100, 45, 0.25, 0.08, 2.2), 0.8)
    place(out, 0, thud(0.12, 200, 900, 1.0, 0.03), 0.9)
    place(out, 0, snap(0.015, 2500, 6000, 0.003), 0.5)
    place(out, 0.004, bell(f, 0.8, 1.1), 0.45)
    place(out, 0.004, kalimba(f, 0.7), 0.4)
    if i == 2:
        place(out, 0.06, bell(note(4, 2), 0.8, 1.0), 0.18)
        place(out, 0.06, kalimba(note(0, 2), 0.8), 0.28)
    place(out, 0.03, grains(0.5, 12 + 6 * i, 7000, 14000, length=(0.002, 0.006), decay=0.1), 0.16)
    return phone(room(out, 0.16, 0.6, 7000))


def new_best() -> np.ndarray:
    seed(1190)
    out = buf(1.5)
    for i, d in enumerate([0, 2, 4, 7, 9]):
        place(out, i * 0.075, kalimba(note(d, 1), 0.8), 0.45)
        place(out, i * 0.075, bell(note(d, 2), 0.7, 0.8), 0.14)
    for k in range(10):
        place(out, k * 0.03, drum(150, 0.18, 0.05, 0.6), 0.1 + 0.03 * k)
    place(out, 0.3, drum(98, 0.5, 0.15, 0.4), 0.5)
    place(out, 0.3, grains(0.9, 26, 7000, 15000, length=(0.002, 0.006), decay=0.22), 0.18)
    return phone(room(out, 0.2, 0.8, 7000))


# ---------------------------------------------------------------- the list

## name: (recipe(take) -> samples, takes, integrated loudness LUFS, how it should sound). The levels
## are the mix: the game plays them at 0 dB and only turns a sound down for its context.
RECIPES = {
    "sfx_footstep": (footstep, 6, -30.0, "A running step on dry packed earth: a soft heel thump and toe tap with a "
                     "little grit and dry grass; quiet, dry, never the same twice."),
    "sfx_jump": (jump, 5, -24.0, "Push-off: a boot scuffing dirt, a quick rising whoosh of cloth and air, grit "
                 "kicked back, a faint lift underneath."),
    "sfx_land": (land, 5, -23.0, "Landing on packed earth: a crunch of grit on top, a woody thud in the middle, "
                 "the weight felt as harmonics, a breath of dust settling."),
    "sfx_step": (step, 4, -27.0, "Swipe-right step: a short sliding scuff on grit with a light knock."),
    "sfx_throw": (throw, 5, -22.0, "Ring thrown: a wrist flick, a fast whoosh past the ear, the ring's bright "
                  "spinning zing rising a touch; 0.3 s."),
    "sfx_ring_hit": (ring_hit, 5, -18.0, "Ring hits a bandit: a sharp wooden crack, a punchy body thud, the ring "
                     "ringing out briefly like a struck bar; three clear layers, 0.35 s."),
    "sfx_knock_out": (knock_out, 5, -17.0, "Knock-out: a bigger crack and heavy thud, a metal clang, a whoosh of "
                      "the bandit tumbling away, then two quick rising kalimba notes (E6, A6); 0.5 s."),
    "sfx_bob": (bob, 8, -21.0, "Red Bob pickup, a take per step of a streak (bob_1 = A5 .. bob_8 = A6): a quick "
                "kalimba pair a third apart with a pinch of bell and sparkle; 0.25 s, clean ends."),
    "sfx_streak": (lambda v: streak(), 1, -19.0, "A streak of 3+ Red Bobs ends: a quick bright A major arpeggio on "
                   "kalimba and bells with a shimmer; 0.6 s."),
    "sfx_hurt": (hurt, 5, -16.0, "Hit by a club: a whack, a heavy body thud with weight, a short breath knocked out, "
                 "a sour low tone underneath; 0.4 s."),
    "sfx_death": (lambda v: death(), 1, -14.0, "Caught for good: the hardest blow of the game, a low boom falling "
                  "away, a dark rush, the body hitting the ground at 0.45 s; 0.8 s (the stinger follows)."),
    "sfx_fall": (fall, 2, -16.0, "Off the edge into the pit: air rushing past, cloth flapping, a dull far thud at "
                 "0.6 s; no cartoon whistle; 0.8 s."),
    "sfx_fell": (lambda v: fell(), 1, -18.0, "A fall that costs a life (he springs back): a quick falling marimba "
                 "'uh-oh' (C#5 to A4) over a small whoosh."),
    "sfx_spring": (lambda v: spring(), 1, -19.0, "Springing back out of the pit: a whoosh sweeping up, a shimmering "
                   "rising glide, two bright bells at the top."),
    "sfx_splash": (splash, 4, -19.0, "Into a pool: the slap of the surface, a rising 'plunk', the rush and spray, "
                   "small bubbles and drops."),
    "sfx_hang": (hang, 4, -21.0, "Catching the vine: a hand slapping on, the vine creaking as it takes his weight, "
                 "leaves rustling, a tiny clink of the staff."),
    "sfx_vine_creak": (vine_creak, 3, -30.0, "Hanging: now and then a soft creak of the vine and a few leaves; "
                       "barely there."),
    "sfx_let_go": (lambda v: let_go(), 1, -24.0, "Letting go: leaves rustling back and a short falling breath of air."),
    "sfx_grab": (grab, 4, -24.0, "Climbing: a hand slapping onto stone, a knock, a little grit falling."),
    "sfx_mantle": (mantle, 2, -23.0, "Pulling up over a ledge: cloth scraping on rock, a knee thud, a breath, grit."),
    "sfx_bump": (bump, 3, -20.0, "Head on a ceiling: a dull bonk, a woody knock, dirt crumbling down for a moment."),
    "sfx_heart_break": (lambda v: heart_break(), 1, -18.0, "A heart lost: a sharp glassy crack with bright shards "
                        "tinkling, a low thud under it; 0.45 s."),
    "sfx_last_heart": (lambda v: last_heart(), 1, -19.0, "Down to the last heart: two heartbeat thumps (lub-dub) "
                       "and a tense trembling interval; a warning, not a punishment."),
    "sfx_door": (lambda v: door(), 1, -22.0, "Over the threshold home: a soft whoosh in and a warm A major swell "
                 "with two bells (the win stinger lands on it)."),
    "sfx_coins": (coins, 2, -21.0, "The coin shower: a light rain of small metal tinkles thinning out over 1.5 s, "
                  "a few coins bouncing on wood."),
    "sfx_firework": (firework, 3, -24.0, "A firework over the results: a short rising hiss, a soft pop, a "
                     "crackle of sparks falling away; quiet, under the win stinger."),
    "sfx_button": (button, 3, -22.0, "Button tap: a soft, round, bubbly 'boop' (A4, B4, C#5 takes) with a small "
                   "plastic tock; short and friendly."),
    "sfx_panel_open": (lambda v: panel(True), 1, -24.0, "Panel opens: a soft rising swoosh into a pop on E5."),
    "sfx_panel_close": (lambda v: panel(False), 1, -25.0, "Panel closes: a falling swoosh and a lower pop on A4."),
    "sfx_toggle_on": (lambda v: toggle(True), 1, -23.0, "Switch on: a click and two marimba notes going up "
                      "(C#5, E5)."),
    "sfx_toggle_off": (lambda v: toggle(False), 1, -24.0, "Switch off: a click and the two notes going down, softer."),
    "sfx_wipe": (lambda v: wipe(), 1, -27.0, "Screen change: a soft whoosh travelling left to right (stereo)."),
    "sfx_tick": (lambda v: tick(), 1, -26.0, "A count rolling up: a tiny dry woodblock tick with a kalimba blip; "
                 "60 ms, it can repeat fast."),
    "sfx_count_3": (lambda v: count(3), 1, -21.0, "Resume countdown '3': a low drum tone, a woodblock, kalimba A4."),
    "sfx_count_2": (lambda v: count(2), 1, -21.0, "Countdown '2': the same a step higher (kalimba C#5)."),
    "sfx_count_1": (lambda v: count(1), 1, -21.0, "Countdown '1': the same, kalimba E5."),
    "sfx_count_go": (lambda v: go(), 1, -18.0, "GO: a drum slap and a bright A major chord on kalimba and bells "
                     "with a forward whoosh."),
    "sfx_star": (star, 3, -16.0, "A result star slamming into its socket: a deep drum thud and crack, then a "
                 "bright chime a step higher per star (A5, C#6, E6); the third rings longest."),
    "sfx_new_best": (lambda v: new_best(), 1, -15.0, "NEW BEST: kalimba and bells running up the A major chord "
                     "over a swelling drum roll, a shimmer to finish."),
}


## Hits made denser before mastering (a fast compressor: the body and tail come up under the crack),
## so they reach their loudness under the -3 dBTP ceiling: dB of compression wanted at the peak.
PUNCH = {"sfx_ring_hit": 12.0, "sfx_knock_out": 8.0, "sfx_hurt": 14.0, "sfx_death": 10.0, "sfx_fall": 6.0,
         "sfx_bump": 8.0, "sfx_grab": 8.0, "sfx_land": 6.0, "sfx_heart_break": 6.0, "sfx_last_heart": 6.0,
         "sfx_star": 6.0, "sfx_splash": 6.0}
## Longest each may last (s): the frequent ones are short, so they never run over the next event.
MAX_LEN = {"sfx_bob": 0.25, "sfx_knock_out": 0.5, "sfx_hurt": 0.4, "sfx_death": 0.85, "sfx_fall": 0.9,
           "sfx_ring_hit": 0.35, "sfx_streak": 0.6, "sfx_jump": 0.32, "sfx_land": 0.3, "sfx_throw": 0.32}


def finish(x: np.ndarray, level: float, name: str = "") -> np.ndarray:
    x = hp(x, 25, 2)  # no DC or rumble a phone can't play
    x = trim(x, -55)
    if name in MAX_LEN:
        x = x[: n_of(MAX_LEN[name])]
    x = fade(x, 0.0005, 0.015)
    if name in PUNCH:
        top = 20 * np.log10(np.abs(x).max() + 1e-9)
        x = dsp.compress(x, top - PUNCH[name] - 6.0, 4.0, 0.0008, 0.05, knee_db=4.0)
    return master(x, level, ceiling_db=CEILING)


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("assets/audio")
    names = [a for a in sys.argv[2:] if not a.startswith("--")] or list(RECIPES)
    out.mkdir(parents=True, exist_ok=True)
    for name in names:
        make, takes, level, _ = RECIPES[name]
        for v in range(takes):
            file = out / (f"{name}.wav" if takes == 1 else f"{name}_{v + 1}.wav")
            s = finish(make(v), level, name)
            write_wav(file, s)
            print(f"{file}  {len(s) / RATE:5.2f} s  {dsp.lufs(s):6.1f} LUFS  "
                  f"true peak {20 * np.log10(dsp.true_peak(s)):5.1f} dBTP")


if __name__ == "__main__":
    main()
