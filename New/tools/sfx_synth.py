#!/usr/bin/env python3
"""Chaka Zulu's sound effects, synthesised from scratch (numpy + scipy: tools/audio_dsp.py): no
samples, no paid service, nothing to license.

One family: wood, metal and air. Movement is foley (boots on packed earth, dry grass, cloth, air);
the ring is bright metal; rewards are the score's kalimba and bells, always on notes of A major (the
key of the music), so a pickup or a star sounds like part of the tune. Each sound is layered (a
transient for the attack, a body for the weight, a tail for the space), varied (several takes of
the frequent ones: different grains, pitch and filter), mastered to its role's loudness (the
loudest 400 ms, LUFS, under a -1 dBTP ceiling) and written as 16-bit WAV (one-shots: Godot plays
them with no decoding delay and stores them as QOA).

Usage: python3 tools/sfx_synth.py [assets/audio] [name ...]   (default: all)
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from audio_dsp import (RATE, adsr, taper, bp, convolve, drum, fade, fm, glide, hp, impulse, lp, master, modal, n_of,
                       noise, note, pan, perc, phase_of, place, reverb, saturate, seed, sweep_noise, t, tone,
                       trim, write_wav)
import audio_dsp as dsp


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


def woodblock(f: float = 1900.0) -> np.ndarray:
    return modal(0.12, [(f, 1.0, 0.03), (f * 2.71, 0.4, 0.012), (f * 0.52, 0.3, 0.02)])


# ---------------------------------------------------------------- foley parts

def grains(sec: float, count: int, lo: float, hi: float, length=(0.003, 0.012), spread: float = 1.0,
           decay: float = 0.04) -> np.ndarray:
    """Crunch: short grains of band-passed noise (grit, dry grass) packed near the start."""
    out = buf(sec)
    for _ in range(count):
        d = dsp.rng.uniform(*length)
        c = dsp.rng.uniform(lo, hi)
        g = bp(noise(d + 0.01), c * 0.6, min(c * 1.6, 20000))[: n_of(d)] * np.hanning(n_of(d))
        at = abs(dsp.rng.normal(0, decay)) * spread
        place(out, min(at, sec - d), g, dsp.rng.uniform(0.3, 1.0))
    return out


def thump(f0: float, f1: float, sec: float, decay: float, drive: float = 1.5) -> np.ndarray:
    """The weight of a blow: a sine dropping from f0 to f1, a little saturated (it carries on a
    phone's speaker as harmonics)."""
    return saturate(np.sin(phase_of(glide(f0, f1, sec, 0.5))) * perc(sec, 0.0012, decay), drive)


def crack(sec: float = 0.02, lo: float = 2000.0) -> np.ndarray:
    return hp(noise(sec), lo, 2) * perc(sec, 0.0002, 0.0025)


def whoosh(sec: float, f0: float, f1: float, width: float = 1.3, attack: float = 0.3) -> np.ndarray:
    """Air: noise in a band gliding f0 to f1, swelling then fading (`attack`: where the peak is)."""
    x = t(sec) / sec
    shape = np.where(x < attack, (x / attack) ** 2, np.exp(-(x - attack) / (1 - attack) * 3.5))
    return sweep_noise(sec, f0, f1, width) * shape


def room(x: np.ndarray, mix: float, decay: float = 0.5, damp: float = 5000.0) -> np.ndarray:
    return reverb(x, mix, decay, damp)


# ---------------------------------------------------------------- the moves

def footstep(v: int) -> np.ndarray:
    """A running step on dry savanna earth: the heel's soft thump, the roll to the toe, grit and
    dry grass crunching under the sole. Each take has its own grains and pitch."""
    seed(100 + v)
    k = 1 + 0.06 * (v % 3 - 1)
    out = buf(0.16)
    place(out, 0, thump(150 * k, 75 * k, 0.07, 0.016, 1.2), 0.55)
    place(out, 0.0, bp(noise(0.04), 250, 1800) * perc(0.04, 0.001, 0.01), 0.35)
    place(out, 0.022 + 0.006 * (v % 2), thump(210 * k, 120 * k, 0.04, 0.01, 1.0), 0.25)  # the toe
    place(out, 0.002, grains(0.12, 10 + v % 4, 1400, 6500, spread=0.7, decay=0.022), 0.5)
    return room(out, 0.06, 0.25)


def jump(v: int) -> np.ndarray:
    """The push-off: the boot scuffing the dirt, cloth and air rushing up, a light rising "hup"
    (C#4 to A4: in the key), grit kicked back."""
    seed(200 + v)
    k = 1 + 0.04 * (v - 1.5)
    out = buf(0.32)
    place(out, 0, bp(noise(0.05), 220, 2200) * perc(0.05, 0.001, 0.014), 0.5)
    place(out, 0, thump(130, 70, 0.06, 0.018), 0.35)
    place(out, 0.004, whoosh(0.26, 600 * k, 2600 * k, 1.4, 0.35), 0.55)
    lift = tone(glide(note(2, -1) * k, note(0, 0) * k, 0.14, 0.7), (1.0, 0.3, 0.1)) * perc(0.14, 0.006, 0.05)
    place(out, 0.01, lift, 0.16)
    place(out, 0.0, grains(0.1, 7, 1500, 6000, decay=0.02), 0.3)
    return room(out, 0.08, 0.35)


def land(v: int) -> np.ndarray:
    """Landing: boots on packed earth. A deep body thump (felt), a knock in the phone's range,
    grit and dry grass crunching, a puff of dust settling."""
    seed(300 + v)
    k = 1 + 0.05 * (v - 1.5)
    out = buf(0.4)
    place(out, 0, thump(120 * k, 46 * k, 0.16, 0.05, 2.0), 0.7)
    place(out, 0, modal(0.12, [(185, 1.0, 0.035), (420, 0.5, 0.02), (830, 0.25, 0.011)], k), 0.45)
    place(out, 0, bp(noise(0.06), 300, 2600) * perc(0.06, 0.0006, 0.014), 0.45)
    place(out, 0.001, grains(0.2, 16, 1200, 7000, decay=0.035), 0.55)
    place(out, 0.012, lp(noise(0.25), 1800) * perc(0.25, 0.02, 0.07), 0.12)
    return room(out, 0.1, 0.4)


def step(v: int) -> np.ndarray:
    """A quick step forward (swipe right): a boot sliding on grit, a short breath of air."""
    seed(400 + v)
    out = buf(0.2)
    place(out, 0, sweep_noise(0.09, 700, 1900, 1.5) * perc(0.09, 0.006, 0.03), 0.5)
    place(out, 0.005, grains(0.1, 8, 1500, 6000, decay=0.025), 0.4)
    place(out, 0, thump(160, 90, 0.05, 0.012), 0.25)
    return room(out, 0.06, 0.25)


def throw(v: int) -> np.ndarray:
    """The ring thrown: a flick of the wrist, a fast whoosh past the ear, and the ring's bright
    spinning "zing" (FM metal on E6, flickering as it spins), rising a touch as it flies."""
    seed(500 + v)
    k = 1 + 0.035 * (v - 1)
    out = buf(0.36)
    place(out, 0, bp(noise(0.03), 900, 4000) * perc(0.03, 0.001, 0.006), 0.35)
    place(out, 0.008, whoosh(0.22, 1300 * k, 4200 * k, 1.0, 0.28), 0.6)
    sec = 0.3
    x = t(sec)
    f = glide(note(4, 1) * k, note(4, 1) * k * 2 ** (1.5 / 12), sec)
    zing = fm(f, 1.414, 1.6 * np.exp(-x / 0.12) + 0.3, sec) * perc(sec, 0.006, 0.09)
    zing *= 1 - 0.45 * (0.5 + 0.5 * np.sin(2 * np.pi * 26 * x))  # spinning
    place(out, 0.012, hp(zing, 600), 0.32)
    return room(out, 0.1, 0.45)


def ring_hit(v: int) -> np.ndarray:
    """The ring strikes a bandit: a crack, a punch with weight, the slap on his body and the
    ring's metal ringing out (a free bar on E6), in a small space."""
    seed(600 + v)
    k = 1 + 0.06 * (v - 1)
    out = buf(0.5)
    place(out, 0, crack(0.02, 2500), 0.9)
    place(out, 0, thump(190 * k, 62, 0.12, 0.035, 2.2), 0.75)
    place(out, 0, bp(noise(0.05), 500, 2800) * perc(0.05, 0.0004, 0.012), 0.6)
    place(out, 0.002, modal(0.45, [(1318 * k, 1.0, 0.22), (1318 * k * 2.756, 0.45, 0.09),
                                   (1318 * k * 5.404, 0.22, 0.04), (1318 * k * 8.933, 0.1, 0.02)]), 0.22)
    return room(out, 0.14, 0.5)


def knock_out(v: int) -> np.ndarray:
    """A bandit knocked out: a big crack and a heavy punch, the clang of the ring, the whoosh of
    him tumbling away, then the reward: two kalimba notes up (E6, A6) and a sparkle."""
    seed(700 + v)
    out = buf(1.0)
    place(out, 0, crack(0.03, 1800), 1.0)
    place(out, 0, thump(170, 42, 0.22, 0.07, 2.6), 0.95)
    place(out, 0, bp(noise(0.07), 350, 2400) * perc(0.07, 0.0004, 0.018), 0.7)
    place(out, 0.001, modal(0.6, [(880, 1.0, 0.3), (880 * 2.756, 0.5, 0.11), (880 * 5.404, 0.25, 0.05)]), 0.2)
    place(out, 0.04, whoosh(0.4, 2400, 500, 1.4, 0.2), 0.35)
    place(out, 0.075, kalimba(note(4, 1), 0.7), 0.42)
    place(out, 0.16, kalimba(note(0, 2), 0.8), 0.42)
    place(out, 0.16, grains(0.35, 12, 7000, 13000, length=(0.002, 0.006), decay=0.08), 0.2)
    return room(out, 0.18, 0.7)


def bob(step_: int) -> np.ndarray:
    """A Red Bob: a quick kalimba pair a diatonic third apart on step `step_` of A major from A5
    (the streak climbs the scale), a bell an octave over and a sparkle."""
    seed(800 + step_)
    f1, f2 = note(step_, 1), note(step_ + 2, 1)
    out = buf(0.75)
    place(out, 0, kalimba(f1, 0.25), 0.55)
    place(out, 0.055, kalimba(f2, 0.9), 0.75)
    place(out, 0.055, bell(f2 * 2, 0.5, 0.7), 0.16)
    place(out, 0.05, grains(0.3, 9, 8000, 14000, length=(0.002, 0.005), decay=0.06), 0.14)
    return room(out, 0.16, 0.6, 7000)


def hurt(v: int) -> np.ndarray:
    """Hit by a club: wood on body (a dull knock and a heavy thump), a breathless grunt of air,
    and a falling "uh-oh" low on the marimba (C#4 to A3)."""
    seed(900 + v)
    out = buf(0.7)
    place(out, 0, crack(0.02, 1500), 0.6)
    place(out, 0, thump(165, 48, 0.2, 0.06, 2.5), 1.0)
    place(out, 0, modal(0.15, [(255, 1.0, 0.05), (612, 0.6, 0.03), (1175, 0.3, 0.015)], 1 + 0.05 * v), 0.6)
    place(out, 0, bp(noise(0.08), 300, 1800) * perc(0.08, 0.0005, 0.02), 0.7)
    place(out, 0.03, bp(noise(0.16), 500, 1600) * perc(0.16, 0.02, 0.05), 0.12)
    place(out, 0.07, marimba(note(2, -1), 0.35), 0.5)
    place(out, 0.17, marimba(note(0, -1), 0.6), 0.55)
    return room(out, 0.12, 0.45)


def death() -> np.ndarray:
    """Caught for good: the blow, a low boom that falls away under it, a dark downward rush and a
    tone sinking an octave and a half (A3 to E2)."""
    seed(950)
    out = buf(1.6)
    place(out, 0, hurt(0)[: n_of(0.12)], 1.0)
    place(out, 0, thump(90, 30, 1.0, 0.35, 2.0), 0.9)
    place(out, 0.03, whoosh(0.9, 3000, 250, 1.6, 0.15), 0.35)
    sink = tone(glide(220, 82.4, 1.2, 0.8), (1.0, 0.5, 0.3, 0.15)) * adsr(1.2, 0.05, 0.4, 0.6, 0.5)
    place(out, 0.05, lp(sink, 1500), 0.3)
    return room(out, 0.2, 1.2, 3500)


def fall() -> np.ndarray:
    """Off the edge into the pit: air rushing past, a whistle sliding down from E6 to A4 (two
    reeds a hair apart), and far below, a dull thud."""
    seed(960)
    out = buf(1.4)
    sec = 0.85
    x = t(sec)
    f = glide(note(4, 1), note(0, 0), sec, 0.8) * (1 + 0.012 * np.sin(2 * np.pi * 6 * x))
    w = (tone(f, (1.0, 0.18)) + tone(f * 1.006, (0.8, 0.1))) * adsr(sec, 0.02, 0.3, 0.8, 0.25)
    place(out, 0, w, 0.25)
    place(out, 0, bp(noise(sec), 900, 3500) * adsr(sec, 0.05, 0.3, 0.7, 0.3), 0.06)
    place(out, 0, whoosh(0.9, 2500, 400, 1.6, 0.3), 0.35)
    place(out, 0.9, lp(thump(110, 40, 0.3, 0.08), 400), 0.6)
    return room(out, 0.2, 0.9, 3000)


def fell() -> np.ndarray:
    """A fall that costs a life (he springs back): a falling "uh-oh" (C#5 to A4) on the marimba."""
    seed(970)
    out = buf(0.7)
    place(out, 0, marimba(note(2, 0), 0.3), 0.8)
    place(out, 0.13, marimba(note(0, 0), 0.5), 0.9)
    place(out, 0, whoosh(0.4, 1800, 500), 0.15)
    return room(out, 0.15, 0.6)


def spring() -> np.ndarray:
    """Out of the pit and back up: a whoosh sweeping up, a rising glide (A3 to A5) that shimmers,
    two bells at the top."""
    seed(980)
    out = buf(0.8)
    place(out, 0, whoosh(0.45, 400, 3500, 1.4, 0.6), 0.45)
    sec = 0.34
    x = t(sec)
    g = tone(glide(note(0, -1), note(0, 1), sec, 1.2) * (1 + 0.01 * np.sin(2 * np.pi * 11 * x)), (1.0, 0.3, 0.12))
    place(out, 0.02, g * adsr(sec, 0.03, 0.2, 0.7, 0.1), 0.25)
    place(out, 0.33, bell(note(4, 2), 0.4), 0.2)
    place(out, 0.39, bell(note(0, 3), 0.4), 0.16)
    return room(out, 0.18, 0.6, 7000)


def splash(v: int) -> np.ndarray:
    """Into a pool: the slap of the surface, the plunk of the water closing (a bubble rising in
    pitch), the rush, spray, then small bubbles and drops."""
    seed(990 + v)
    out = buf(0.8)
    place(out, 0, lp(noise(0.06), 5000) * perc(0.06, 0.001, 0.015), 0.6)
    place(out, 0.004, np.sin(phase_of(glide(260, 640, 0.07))) * perc(0.07, 0.002, 0.03), 0.6)
    place(out, 0, bp(noise(0.5), 300, 4500) * perc(0.5, 0.008, 0.1), 0.55)
    n = n_of(0.5)
    grit = np.convolve(np.abs(dsp.rng.standard_normal(n)), np.ones(160) / 160, "same") ** 3
    place(out, 0.01, hp(noise(0.5), 3000) * perc(0.5, 0.01, 0.12) * grit / grit.max(), 0.35)
    for _ in range(16):
        f0 = dsp.rng.uniform(500, 2400)
        d = dsp.rng.uniform(0.01, 0.03)
        b = np.sin(phase_of(f0 * (1 + 0.4 * t(d * 3) / (d * 3)))) * perc(d * 3, 0.001, d)
        place(out, dsp.rng.uniform(0.06, 0.55), b, dsp.rng.uniform(0.08, 0.25))
    return room(out, 0.15, 0.5)


def hang() -> np.ndarray:
    """Catching the vine: the hand slapping on, the staff's hook clinking, the vine creaking under
    his weight and its leaves rustling."""
    seed(1000)
    out = buf(0.5)
    place(out, 0, bp(noise(0.02), 800, 3500) * perc(0.02, 0.0004, 0.006), 0.7)
    place(out, 0.004, modal(0.25, [(2650, 1.0, 0.05), (2650 * 2.32, 0.5, 0.025), (2650 * 3.9, 0.25, 0.012)]), 0.18)
    sec = 0.22
    x = t(sec)
    stick = (dsp.rng.random(n_of(sec)) < 0.004).astype(float)
    stick = np.convolve(stick, np.hanning(60), "same")
    creak = fm(185.0, 2.3, 3.0, sec) * (0.3 + stick) * adsr(sec, 0.02, 0.1, 0.6, 0.06)
    place(out, 0.02, bp(creak, 150, 2500), 0.25)
    place(out, 0.01, grains(0.35, 18, 2500, 8000, length=(0.006, 0.02), decay=0.08), 0.35)
    place(out, 0, thump(140, 90, 0.05, 0.015), 0.25)
    return room(out, 0.1, 0.45)


def let_go() -> np.ndarray:
    """Letting go of the vine: leaves rustling back and a short drop of air."""
    seed(1010)
    out = buf(0.45)
    place(out, 0, grains(0.3, 12, 2500, 8000, length=(0.006, 0.02), decay=0.06), 0.4)
    place(out, 0.01, whoosh(0.3, 2200, 600, 1.4, 0.25), 0.45)
    return room(out, 0.08, 0.35)


# ---------------------------------------------------------------- interface

def button(v: int) -> np.ndarray:
    """A tap on a candy button: a soft, round "boop" on a note of the key (A4, B4, C#5) gliding
    down a touch, a plastic tock and a tiny click of air. Short and bubbly."""
    seed(1100 + v)
    f = note(v, 0)
    out = buf(0.16)
    place(out, 0, tone(glide(f * 1.3, f, 0.12, 0.25), (1.0, 0.18)) * perc(0.12, 0.002, 0.035), 0.8)
    place(out, 0, modal(0.04, [(f * 2.8, 1.0, 0.008), (f * 6.1, 0.4, 0.004)]), 0.25)
    place(out, 0, hp(noise(0.004), 3000) * perc(0.004, 0.0002, 0.0008), 0.12)
    return room(out, 0.05, 0.25, 6000)


def panel(opening: bool) -> np.ndarray:
    """A panel arriving (a soft rising swoosh into a pop on E5) or leaving (falling, to A4)."""
    seed(1120 if opening else 1121)
    out = buf(0.35)
    sw = whoosh(0.2, 500, 2400, 1.2, 0.8) if opening else whoosh(0.2, 2400, 500, 1.2, 0.15)
    place(out, 0, sw, 0.35)
    f = note(4, 0) if opening else note(0, 0)
    place(out, 0.16 if opening else 0.0, tone(glide(f * 1.25, f, 0.15, 0.25), (1.0, 0.2)) * perc(0.15, 0.002, 0.04), 0.6)
    return room(out, 0.06, 0.3)


def toggle(on: bool) -> np.ndarray:
    """A switch: a click and two quick marimba notes, up (C#5, E5) for on, down for off."""
    seed(1130 if on else 1131)
    a, b = (note(2, 0), note(4, 0)) if on else (note(4, 0), note(2, 0))
    out = buf(0.3)
    place(out, 0, woodblock(2400) * 0.4)
    place(out, 0.0, marimba(a, 0.25), 0.55)
    place(out, 0.06, marimba(b, 0.4), 0.6 if on else 0.45)
    return room(out, 0.05, 0.25)


def wipe() -> np.ndarray:
    """The screen change: a soft whoosh passing from left to right (stereo)."""
    seed(1140)
    sec = 0.42
    w = whoosh(sec, 400, 2200, 1.3, 0.45) * 0.8 + whoosh(sec, 1800, 5000, 1.0, 0.5) * 0.2
    x = t(sec) / sec
    p = -0.8 + 1.6 * x
    a = (p + 1) * np.pi / 4
    return np.stack([w * np.cos(a), w * np.sin(a)], axis=1)


def tick(step_: int = 0) -> np.ndarray:
    """A count ticking up: a tiny woodblock and a kalimba blip on E6."""
    seed(1150)
    out = buf(0.12)
    place(out, 0, woodblock(2100), 0.35)
    place(out, 0, kalimba(note(4, 1), 0.1, 0.6), 0.5)
    return out


def count(n: int) -> np.ndarray:
    """The countdown after Resume: 3, 2, 1 climb (A4, C#5, E5): a drum's low tone for weight, a
    woodblock and a kalimba note."""
    seed(1160 + n)
    f = note({3: 0, 2: 2, 1: 4}[n], 0)
    out = buf(0.6)
    place(out, 0, drum(f / 4, 0.4, 0.12, 0.3), 0.45)
    place(out, 0, woodblock(1700 + 200 * (3 - n)), 0.35)
    place(out, 0.002, kalimba(f, 0.8), 0.6)
    return room(out, 0.12, 0.5)


def go() -> np.ndarray:
    """GO: the world moves again: an A major chord on kalimba and bells (A5 C#6 E6 A6), a drum
    slap and a whoosh forward."""
    seed(1170)
    out = buf(0.9)
    place(out, 0, drum(196, 0.4, 0.1, 0.9, 0.04), 0.5)
    place(out, 0, crack(0.02, 3000), 0.3)
    for i, d in enumerate([0, 2, 4, 7]):
        place(out, 0.008 * i, kalimba(note(d, 1), 0.8), 0.35)
        place(out, 0.008 * i, bell(note(d, 2), 0.6, 0.7), 0.08)
    place(out, 0, whoosh(0.35, 600, 3500, 1.2, 0.4), 0.3)
    return room(out, 0.16, 0.7)


def star(i: int) -> np.ndarray:
    """A result star slamming into its socket: a deep drum hit, a bright chime a third higher
    for each star (A5, C#6, E6), sparkles; the third rings longer, an octave on top."""
    seed(1180 + i)
    f = note(2 * i, 1)
    out = buf(1.2)
    place(out, 0, drum(98, 0.5, 0.14, 0.4), 0.55)
    place(out, 0, crack(0.015, 3000), 0.25)
    place(out, 0.004, bell(f, 0.9, 1.1), 0.5)
    place(out, 0.004, kalimba(f, 0.8), 0.45)
    if i == 2:
        place(out, 0.06, bell(f * 2 ** (5 / 12) * 2, 1.0, 1.0), 0.2)
        place(out, 0.06, kalimba(note(0, 2), 1.0), 0.3)
    place(out, 0.03, grains(0.6, 14 + 6 * i, 7000, 14000, length=(0.002, 0.006), decay=0.12), 0.18)
    return room(out, 0.2, 0.9, 7000)


def new_best() -> np.ndarray:
    """NEW BEST: kalimba and bells running up the A major chord (A5 C#6 E6 A6 C#7), a drum roll
    swelling under it, a shimmer to finish."""
    seed(1190)
    out = buf(1.9)
    for i, d in enumerate([0, 2, 4, 7, 9]):
        place(out, i * 0.075, kalimba(note(d, 1), 0.9), 0.45)
        place(out, i * 0.075, bell(note(d, 2), 0.8, 0.8), 0.14)
    for k in range(10):
        place(out, k * 0.03, drum(150, 0.2, 0.05, 0.6), 0.1 + 0.03 * k)
    place(out, 0.3, drum(98, 0.6, 0.16, 0.4), 0.5)
    place(out, 0.3, grains(1.0, 30, 7000, 15000, length=(0.002, 0.006), decay=0.25), 0.18)
    return room(out, 0.22, 1.1, 7000)


# ---------------------------------------------------------------- the list

## name: (recipe(take) -> samples, takes, loudest 400 ms in LUFS). The levels are the mix: the game
## plays them at 0 dB and only turns a sound down for its context (a soft landing, a far splash).
RECIPES = {
    "sfx_footstep": (footstep, 6, -31.0),
    "sfx_jump": (jump, 4, -22.0),
    "sfx_land": (land, 4, -19.5),
    "sfx_step": (step, 2, -23.0),
    "sfx_throw": (throw, 3, -19.5),
    "sfx_ring_hit": (ring_hit, 3, -16.5),
    "sfx_knock_out": (knock_out, 2, -13.5),
    "sfx_bob": (bob, 8, -18.0),  # one per step of the scale: sfx_bob_1 (A5) .. sfx_bob_8 (A6)
    "sfx_hurt": (hurt, 2, -13.5),
    "sfx_death": (lambda v: death(), 1, -12.5),
    "sfx_fall": (lambda v: fall(), 1, -15.0),
    "sfx_fell": (lambda v: fell(), 1, -16.0),
    "sfx_spring": (lambda v: spring(), 1, -18.0),
    "sfx_splash": (splash, 2, -17.0),
    "sfx_hang": (lambda v: hang(), 1, -20.0),
    "sfx_let_go": (lambda v: let_go(), 1, -24.0),
    "sfx_button": (button, 3, -21.0),
    "sfx_panel_open": (lambda v: panel(True), 1, -23.0),
    "sfx_panel_close": (lambda v: panel(False), 1, -24.0),
    "sfx_toggle_on": (lambda v: toggle(True), 1, -22.0),
    "sfx_toggle_off": (lambda v: toggle(False), 1, -23.0),
    "sfx_wipe": (lambda v: wipe(), 1, -26.0),
    "sfx_tick": (lambda v: tick(), 1, -25.0),
    "sfx_count_3": (lambda v: count(3), 1, -19.0),
    "sfx_count_2": (lambda v: count(2), 1, -19.0),
    "sfx_count_1": (lambda v: count(1), 1, -19.0),
    "sfx_count_go": (lambda v: go(), 1, -16.0),
    "sfx_star": (star, 3, -16.0),
    "sfx_new_best": (lambda v: new_best(), 1, -14.5),
}


def finish(x: np.ndarray, level: float) -> np.ndarray:
    x = hp(x, 25, 2)  # no DC or rumble a phone can't play
    x = trim(x, -60)
    x = fade(x, 0.0005, 0.012)
    return master(x, momentary=level, ceiling_db=-1.0)


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("assets/audio")
    names = sys.argv[2:] or list(RECIPES)
    out.mkdir(parents=True, exist_ok=True)
    for name in names:
        make, takes, level = RECIPES[name]
        for v in range(takes):
            file = out / (f"{name}.wav" if takes == 1 else f"{name}_{v + 1}.wav")
            s = finish(make(v), level)
            write_wav(file, s)
            print(f"{file}  {len(s) / RATE:5.2f} s  M max {dsp.momentary_max(s):6.1f} LUFS  "
                  f"true peak {20 * np.log10(dsp.true_peak(s)):5.1f} dBTP")


if __name__ == "__main__":
    main()
