#!/usr/bin/env python3
"""Chaka Zulu's music and ambience, composed and synthesised here (numpy + scipy): no samples, no
paid service, nothing to license. Every note below is written in this file.

The style is South African township jive (kwela, mbaqanga): a pennywhistle melody over a bouncing
electric bass, two interlocking clean guitars, hand drums and shakers, with a kalimba (thumb piano)
and a choir; all in A major, the key of the sound effects.

    music_game.ogg   "Run Home": 118 BPM, 48 bars (98 s): groove, whistle tune, kalimba and choir
                     bridge, the tune in thirds, a marimba section in B minor, the tune with the choir,
                     a drum break; loops seamlessly; 2.5 dB less around 3 kHz (room for the effects)
    music_game_drive.ogg  its drive layer (djembe 16ths, agogo bell, shaker, tom fills), the same
                     98 s in sync: the game fades it in on the home stretch
    music_menu.ogg   "Sunset": 92 BPM, 16 bars (42 s): kalimba, choir, soft drums, the whistle tune
                     the second time round; loops seamlessly
    sting_win.ogg    home reached: a drum roll, the band's A major chord, the whistle on top
    sting_lose.ogg   game over: a gentle fall in A minor on kalimba and marimba
    amb_savanna.ogg  the savanna bed under the music: wind and grass, crickets, a far cicada,
                     a few distant birds (48 s, loops seamlessly)

Masters: music at -16 LUFS integrated, stingers -14, ambience -30, true peak under -1 dBTP;
Ogg Vorbis (quality 3 for music, 0 for the ambience: noise, quiet, under the music).

Usage: python3 tools/music_synth.py [assets/audio] [game|menu|win|lose|ambience ...]
"""
import sys
from pathlib import Path

import numpy as np
from scipy.ndimage import uniform_filter1d
from scipy.signal import fftconvolve

sys.path.insert(0, str(Path(__file__).parent))
import audio_dsp as dsp
from audio_dsp import (RATE, adsr, bp, compress, convolve, drum, fade, glide, hp, impulse, lp, master, n_of, noise, peak_eq,
                       pan, perc, phase_of, place, saturate, seed, shelf, t, taper, write_ogg)
from sfx_synth import bell, kalimba, marimba

A2 = 110.0
REPORT = False  ## print each track's loudness in the mix (--report)
OGG_CEILING = -1.6  ## dBTP before encoding: Vorbis adds a few tenths of overshoot, the file stays under -1


def hz(degree: int, octave: int = 0) -> float:
    """A degree of A major (0 = A4) as a frequency (dsp.note)."""
    return dsp.note(degree, octave)


def semis(f: float, s: float) -> float:
    return f * 2 ** (s / 12)


# ---------------------------------------------------------------- drums

def kick(v: float = 1.0) -> np.ndarray:
    x = t(0.4)
    body = np.sin(phase_of(48 + 115 * np.exp(-x / 0.028))) * perc(0.4, 0.001, 0.13)
    click = hp(noise(0.005), 3500) * perc(0.005, 0.0002, 0.001)
    out = saturate(body * 1.2, 1.6) + 0.25 * np.pad(click, (0, len(x) - len(click)))
    return taper(out, 0.3) * v


def snare(v: float = 1.0) -> np.ndarray:
    """A tight township snare: a woody body and a crisp burst of wires."""
    out = dsp.modal(0.2, [(190, 1.0, 0.06), (335, 0.6, 0.04), (520, 0.3, 0.02)])
    out += 0.9 * bp(noise(0.2), 1500, 9000) * perc(0.2, 0.0008, 0.045)
    return taper(out, 0.3) * v


def clap(v: float = 1.0) -> np.ndarray:
    out = np.zeros(n_of(0.25))
    for k, d in enumerate([0.0, 0.009, 0.019]):
        place(out, d, bp(noise(0.02), 900, 5000) * perc(0.02, 0.0005, 0.004), 0.7)
    place(out, 0.028, bp(noise(0.22), 900, 4500) * perc(0.22, 0.002, 0.06), 0.8)
    return out * v


def shaker(v: float = 1.0, accent: bool = False) -> np.ndarray:
    sec = 0.12 if accent else 0.08
    return bp(noise(sec), 3800, 11000) * adsr(sec, 0.008, 0.03 if accent else 0.018, 0.0, 0.01) * v


def hat(v: float = 1.0, open_: bool = False) -> np.ndarray:
    sec = 0.3 if open_ else 0.06
    return hp(noise(sec), 7000, 2) * perc(sec, 0.0005, 0.09 if open_ else 0.015) * v


def conga(f: float, v: float = 1.0, slap: bool = False) -> np.ndarray:
    out = drum(f, 0.4, 0.16 if not slap else 0.08, 0.9 if slap else 0.35, 0.04)
    if slap:
        place(out, 0, hp(noise(0.03), 2500) * perc(0.03, 0.0003, 0.006), 0.8)
    return out * v


def agogo(high: bool, v: float = 1.0) -> np.ndarray:
    """The two-tone bell of West and South African bands: a bright inharmonic clank."""
    f = 940.0 if high else 705.0
    return dsp.modal(0.25, [(f, 1.0, 0.11), (f * 2.51, 0.45, 0.05), (f * 4.12, 0.2, 0.025)]) * v


def djembe_bass(v: float = 1.0) -> np.ndarray:
    return drum(78, 0.45, 0.22, 0.2, 0.08) * v


def talking(f0: float, f1: float, sec: float = 0.3, v: float = 1.0) -> np.ndarray:
    """A talking drum: a membrane whose pitch the player bends from f0 to f1."""
    x = t(sec)
    f = glide(f0, f1, sec, 0.6)
    out = np.zeros_like(x)
    for k, (r, a) in enumerate(zip(dsp.MEMBRANE[:5], [1.0, 0.45, 0.3, 0.2, 0.12])):
        out += a * np.sin(phase_of(f * r)) * np.exp(-x / (0.22 / (1 + k)))
    place(out, 0, bp(noise(0.02), 1500, 6000) * perc(0.02, 0.0003, 0.004), 0.3)
    return taper(out * v, 0.3)


# ---------------------------------------------------------------- pitched

def bass(f: float, sec: float, v: float = 1.0) -> np.ndarray:
    """An electric bass played with the thumb: the upper harmonics fade faster than the
    fundamental (a pluck closing like a filter), a little growl from saturation."""
    x = t(sec + 0.05)
    out = np.zeros_like(x)
    for k in range(1, 14):
        if f * k > 5000:
            break
        a = 1.0 / k ** 1.1
        out += a * np.sin(2 * np.pi * f * k * x) * np.exp(-x * (2.0 + 9.0 * (k - 1)))
    out *= adsr(sec + 0.05, 0.004, 0.25, 0.75, min(0.3, 0.05 + sec * 0.15))
    place(out, 0, lp(noise(0.012), 1800) * perc(0.012, 0.0005, 0.003), 0.4)
    return saturate(out * 0.8, 1.8) * v


def guitar(f: float, sec: float, v: float = 1.0, mute: bool = False) -> np.ndarray:
    s = dsp.pluck(f, sec + 0.05, 0.22 if mute else 1.1, 0.75 if not mute else 0.5, 0.18)
    s = hp(s, 180)
    return taper(s * adsr(sec + 0.05, 0.001, 1, 1, 0.04), 0.2) * v


def voice_aah(f0: float, sec: float, vowel: float = 0.5, v: float = 1.0, voices: int = 3) -> np.ndarray:
    """A small choir on one note: harmonics shaped by the formants of a vowel between "ooh"
    (vowel 0) and "aah" (1), three singers a few cents apart, each with its own vibrato."""
    oo, aa = [(300, 80, 1.0), (870, 100, 0.5), (2240, 140, 0.15)], [(730, 90, 1.0), (1090, 110, 0.7), (2440, 150, 0.25)]
    form = [(o[0] + (a[0] - o[0]) * vowel, o[1] + (a[1] - o[1]) * vowel, o[2] + (a[2] - o[2]) * vowel)
            for o, a in zip(oo, aa)]
    x = t(sec)
    out = np.zeros_like(x)
    for i in range(voices):
        det = 2 ** ((i - (voices - 1) / 2) * 7 / 1200)
        vib = 1 + 0.004 * np.sin(2 * np.pi * (5.0 + 0.4 * i) * x + dsp.rng.uniform(0, 6.28)) * np.minimum(1, x / 0.4)
        ph = phase_of(f0 * det * vib)
        for k in range(1, 40):
            fk = f0 * k
            if fk > 6000:
                break
            g = sum(a / (1 + ((fk - c) / b) ** 2) for c, b, a in form) / k ** 0.3
            out += g * np.sin(k * ph)
    breath = bp(noise(sec), 1500, 4000) * 0.02
    return (out / voices + breath) * adsr(sec, 0.25, 0.4, 0.85, min(0.45, sec * 0.4)) * v


def pad(freqs, sec: float, v: float = 1.0, bright: float = 4.0) -> np.ndarray:
    """A warm string pad: soft saws (harmonics rolled off), two voices detuned, a slow swell."""
    x = t(sec)
    out = np.zeros_like(x)
    for f in freqs:
        for d in (0.9965, 1.0035):
            ph = phase_of(np.full(len(x), f * d)) + dsp.rng.uniform(0, 6.28)
            for k in range(1, 16):
                if f * k > 7000:
                    break
                out += np.exp(-k / bright) / k * np.sin(k * ph)
    return out * adsr(sec, 0.35, 0.5, 0.9, min(0.6, sec * 0.4)) * v / len(freqs)


def whistle(notes, sec: float, v: float = 1.0, breath: float = 0.07) -> np.ndarray:
    """A pennywhistle phrase, played as one breath: notes (start s, length s, Hz, grace) glide into
    each other, the tongue dips between notes, held notes get a delayed vibrato, a grace note
    flicks in from the note above, every onset has a puff of air (chiff)."""
    n = n_of(sec)
    f = np.full(n, notes[0][2] if notes else 440.0)
    amp = np.zeros(n)
    chiff = np.zeros(n)
    prev_end, prev_f = -1.0, None
    starts = [nt[0] for nt in notes] + [1e9]
    for idx, (start, length, freq, grace) in enumerate(notes):
        i, j = n_of(start), min(n_of(start + length), n)
        if i >= n:
            break
        seg = np.arange(j - i) / RATE
        legato = prev_f is not None and abs(start - prev_end) < 0.02
        if legato:  # slur: the pitch glides over 18 ms
            f[i:j] = freq * (prev_f / freq) ** np.exp(-seg / 0.006)
        else:  # a scoop up from 40 cents under
            f[i:j] = freq * 2 ** (-0.4 / 12 * np.exp(-seg / 0.02))
        if grace:
            g = min(n_of(0.035), j - i)
            f[i:i + g] = freq * 2 ** (2 / 12)
        if length > 0.28:  # delayed vibrato on held notes
            vib = 1 + 0.006 * np.sin(2 * np.pi * 5.6 * seg) * np.clip((seg - 0.16) / 0.2, 0, 1)
            f[i:j] *= vib
        a = np.minimum(1, seg / 0.018) * (0.88 + 0.12 * np.exp(-seg / 0.08))
        tied = starts[idx + 1] - (start + length) < 0.02  # the next note follows at once: only a tongue's dip
        rel = n_of(0.03 if tied else 0.06)
        if j - i > rel:
            a[-rel:] *= np.linspace(1, 0.25 if tied else 0.0, rel)
        amp[i:j] = np.maximum(amp[i:j], a)
        if not legato:
            k = min(n_of(0.02), n - i)
            chiff[i:i + k] += np.hanning(2 * k)[k:]
        prev_end, prev_f = start + length, freq
        if j < n:
            f[j:] = freq
    amp = np.convolve(amp, np.hanning(n_of(0.006)) / np.hanning(n_of(0.006)).sum(), "same")
    ph = phase_of(f)
    tone_ = np.sin(ph) + 0.2 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)
    air = bp(noise(sec), 1800, 7000)
    out = tone_ * amp + air * (amp * breath + chiff * 0.25)
    return out * v


# ---------------------------------------------------------------- the song engine

class Song:
    """Tracks laid on a loop of `bars` bars at `bpm` (4/4, 16ths swung by `swing`). Anything that
    rings past the end comes back in at the start, so the file loops seamlessly."""

    def __init__(self, bpm: float, bars: int, swing: float = 0.0, loop: bool = True):
        self.bpm, self.bars, self.swing, self.loop = bpm, bars, swing, loop
        self.beat = 60.0 / bpm
        self.length = bars * 4 * self.beat
        self.n = n_of(self.length)
        self.tracks: dict[str, np.ndarray] = {}
        self.send = np.zeros((self.n, 2))
        self.kicks: list[float] = []

    def time(self, bar: float, step: float = 0.0) -> float:
        """Seconds at a 16th `step` of `bar` (odd 16ths swung late)."""
        s = int(np.floor(step))
        sw = self.swing if s % 2 == 1 else 0.0
        return (bar * 16 + step + sw) * self.beat / 4

    def add(self, track: str, at: float, sig: np.ndarray, gain: float = 1.0, p: float = 0.0, send: float = 0.0,
            human: float = 0.004) -> None:
        if track not in self.tracks:
            self.tracks[track] = np.zeros((self.n, 2))
        at += dsp.rng.uniform(-human, human)
        if self.loop:  # a note pushed a hair before the top of the loop sounds at its end
            at %= self.length
        st = pan(sig, p) if sig.ndim == 1 else sig
        place(self.tracks[track], at, st, gain, wrap=self.loop)
        if send:
            place(self.send, at, st, gain * send, wrap=self.loop)

    def duck(self, tracks, depth: float = 0.3, release: float = 0.14) -> None:
        """Sidechain: these tracks dip under each kick (the pump of a dance record, gently)."""
        g = np.ones(self.n)
        x = t(release * 5)
        dip = 1 - depth * np.exp(-x / release) * np.minimum(1, x / 0.004)
        for k in self.kicks:
            i = n_of(k)
            m = min(len(dip), self.n - i)
            g[i:i + m] = np.minimum(g[i:i + m], dip[:m])
            if self.loop and m < len(dip):
                g[: len(dip) - m] = np.minimum(g[: len(dip) - m], dip[m:])
        for name in tracks:
            if name in self.tracks:
                self.tracks[name] *= g[:, None]

    def mix(self, levels: dict, reverb: float = 1.6, target: float = -16.0, dip: float = 0.0) -> np.ndarray:
        """The tracks at their levels, the shared room, `dip` dB cut around 3 kHz (room for the
        effects' transients), glue compression and the master (loudness `target`)."""
        out = np.zeros((self.n, 2))
        for name, buf in self.tracks.items():
            out += buf * levels.get(name, 1.0)
        if REPORT:
            for name, buf in sorted(self.tracks.items()):
                b = buf * levels.get(name, 1.0)
                print(f"    {name:10s} {dsp.lufs(b):6.1f} LUFS  loudest 400 ms {dsp.momentary_max(b):6.1f}")
        ir = impulse(reverb * 1.4, reverb, 4500)
        wet = convolve(hp(self.send, 250, 2), ir)
        if self.loop:  # the room's tail rings into the start of the loop
            tail = wet[self.n:]
            while len(tail):
                k = min(len(tail), self.n)
                wet[:k] += tail[:k]
                tail = tail[k:]
        out += wet[: self.n] * levels.get("reverb", 0.3)
        out = shelf(out, 9000, 1.5)  # a little air
        if dip:
            out = peak_eq(out, 3000, -dip, 0.8)
        if self.loop:  # dynamics run on two passes, the second kept: no seam in their state
            two = compress(np.vstack([out, out]), -20, 2.0, 0.012, 0.18)
            two = master(two, target, OGG_CEILING)
            return two[self.n:]
        return master(compress(out, -20, 2.0, 0.012, 0.18), target, OGG_CEILING)


# chords: (root as a degree of A major, chord tones as degrees)
CHORDS = {
    "A": (0, [0, 2, 4]), "D": (3, [3, 5, 7]), "E": (4, [4, 6, 8]), "F#m": (5, [5, 7, 9]),
    "E/G#": (4, [-1, 1, 4]), "C#m": (2, [2, 4, 6]), "Bm": (1, [1, 3, 5]),
}


def drums_groove(s: Song, bar: int, full: float = 1.0, fill: bool = False) -> None:
    """Township groove: kick on 1, the "and" of 2 and 3, a snare on 2 and 4, shaker 16ths (the
    off-beats leaning), congas talking between."""
    for step, v in [(0, 1.0), (6, 0.55), (8, 0.9), (14, 0.45)]:
        tm = s.time(bar, step)
        s.add("kick", tm, kick(v), 1.0)
        s.kicks.append(tm)
    for step in (4, 12):
        s.add("snare", s.time(bar, step), snare(1.0), 0.8, 0.05, 0.15)
        s.add("snare", s.time(bar, step), clap(0.6), 0.5, -0.1, 0.25)
    for step in range(16):
        acc = step % 4 == 2
        s.add("shaker", s.time(bar, step), shaker(0.55 + 0.45 * acc, acc), 0.55 * full, 0.35, 0.05)
    if full > 0.5:
        for step, f, v, sl in [(3, 330, 0.6, False), (7, 380, 0.8, True), (10, 300, 0.6, False),
                               (11, 300, 0.5, False), (15, 380, 0.7, True)]:
            s.add("conga", s.time(bar, step), conga(f, v, sl), 0.5, -0.4, 0.12)
        s.add("hat", s.time(bar, 14), hat(0.5, True), 0.35, 0.5, 0.1)
    if fill:  # a talking-drum run into the next bar
        for k, (step, a, b) in enumerate([(8, 260, 200), (10, 240, 300), (11, 300, 220), (12, 220, 330),
                                           (13, 330, 260), (14, 260, 360), (15, 380, 240)]):
            s.add("talk", s.time(bar, step), talking(a, b, 0.25, 0.8), 0.7, 0.3, 0.2)


def bass_bar(s: Song, bar: int, chord: str, nxt: str, v: float = 1.0) -> None:
    """The mbaqanga bass: root, its octave, the fifth, and a step leading to the next root."""
    root, _ = CHORDS[chord]
    nroot, _ = CHORDS[nxt]
    f = hz(root, -2)
    for step, d, sec, vel in [(0, 0, 0.32, 1.0), (3, 0, 0.12, 0.6), (4, 7, 0.22, 0.85), (6, 4, 0.12, 0.7),
                              (8, 0, 0.3, 0.95), (11, 4, 0.12, 0.6), (12, 7, 0.22, 0.8)]:
        fq = hz(root + d, -2) if d != 7 else f * 2
        s.add("bass", s.time(bar, step), bass(fq, sec, vel), 0.9 * v, 0.0)
    lead_in = hz(nroot + (1 if nroot < root else -1), -2)
    s.add("bass", s.time(bar, 14), bass(lead_in, 0.2, 0.75), 0.9 * v, 0.0)


def guitars_bar(s: Song, bar: int, chord: str, v: float = 1.0) -> None:
    """Two guitars locked together: a bright picked line on the chord high up (right), short muted
    chord chops on the off-beats (left)."""
    _, tones = CHORDS[chord]
    line = [tones[2] + 7, tones[0] + 7, tones[1] + 7, tones[0] + 7, tones[2] + 7, tones[0] + 7, tones[1] + 7, tones[0] + 14]
    for k, d in enumerate(line):
        s.add("gtr_lead", s.time(bar, 2 * k), guitar(hz(d, -1), 0.3, 0.8 if k % 2 == 0 else 0.6, mute=k % 2 == 1),
              0.55 * v, 0.45, 0.12)
    for step in (2, 6, 10, 14):
        for d in tones:
            s.add("gtr_chop", s.time(bar, step), guitar(hz(d, 0), 0.12, 0.5, mute=True), 0.35 * v, -0.45, 0.08, 0.001)


def kalimba_bar(s: Song, bar: int, chord: str, v: float = 1.0, octave: int = 1) -> None:
    _, tones = CHORDS[chord]
    pattern = [tones[0], tones[2], tones[1] + 7, tones[2], tones[0] + 7, tones[2], tones[1] + 7, tones[2] + 7]
    for k, d in enumerate(pattern):
        s.add("kalimba", s.time(bar, 2 * k), kalimba(hz(d, octave - 1), 0.9), 0.45 * v * (1.0 if k % 2 == 0 else 0.75),
              -0.25 + 0.5 * (k % 2), 0.25)


def melody(s: Song, bar0: int, phrase, octave: int = 0, gain: float = 0.5, p: float = 0.1, send: float = 0.3,
           harmony: int = 0) -> None:
    """A whistle phrase: (bar, 8th, length in 8ths, degree, grace) from bar0, rendered as one breath;
    `harmony` adds a second whistle that many scale steps below."""
    eighth = s.beat / 2
    start = s.time(bar0)
    for shift, g, pp in [(0, gain, p)] + ([(-harmony, gain * 0.55, -p)] if harmony else []):
        notes = []
        for bar, e, ln, deg, grace in phrase:
            at = s.time(bar0 + bar, 2 * e) - start
            notes.append((at, ln * eighth * 0.96, hz(deg + shift, octave), grace))
        end = max(a + b for a, b, _, _ in notes) + 0.3
        s.add("whistle", start, whistle(notes, end), g, pp, send, 0.0)


# The game tune: (bar, 8th, length in 8ths, degree from A4, grace)
TUNE_A = [
    (0, 2, 1, 4, 0), (0, 3, 1, 5, 0), (0, 4, 2, 7, 1), (0, 6, 1, 5, 0), (0, 7, 1, 4, 0),
    (1, 0, 2, 5, 0), (1, 2, 1, 7, 0), (1, 3, 1, 5, 0), (1, 4, 1, 4, 0), (1, 5, 1, 3, 0), (1, 6, 2, 4, 1),
    (2, 0, 1, 2, 0), (2, 1, 1, 4, 0), (2, 2, 3, 7, 1), (2, 5, 1, 8, 0), (2, 6, 2, 9, 0),
    (3, 0, 3, 8, 1), (3, 3, 1, 6, 0), (3, 4, 3, 4, 0),
    (4, 2, 1, 4, 0), (4, 3, 1, 5, 0), (4, 4, 2, 7, 1), (4, 6, 1, 9, 0), (4, 7, 1, 8, 0),
    (5, 0, 2, 7, 0), (5, 2, 1, 5, 0), (5, 3, 1, 7, 0), (5, 4, 2, 10, 1), (5, 6, 1, 9, 0), (5, 7, 1, 8, 0),
    (6, 0, 2, 7, 0), (6, 2, 1, 9, 0), (6, 3, 1, 8, 0), (6, 4, 2, 6, 1), (6, 6, 2, 8, 0),
    (7, 0, 5, 7, 1), (7, 7, 1, 4, 0),
]
# the bridge's answer phrases (over F#m D A E)
ANSWER = [
    (0, 0, 1, 9, 0), (0, 1, 1, 8, 0), (0, 2, 2, 7, 1), (0, 4, 1, 5, 0), (0, 5, 3, 4, 0),
    (1, 0, 2, 5, 0), (1, 2, 1, 4, 0), (1, 3, 1, 2, 0), (1, 4, 4, 4, 1),
]
CALL = [(0, 0, 1, 7, 0), (0, 1, 1, 9, 0), (0, 2, 2, 11, 1), (0, 4, 1, 9, 0), (0, 5, 3, 7, 0)]


# the C section's marimba line (over Bm D A E Bm D E E)
TUNE_C = [
    (0, 0, 1, 5, 0), (0, 1, 1, 3, 0), (0, 2, 2, 1, 0), (0, 4, 1, 3, 0), (0, 5, 1, 5, 0), (0, 6, 2, 8, 0),
    (1, 0, 2, 7, 0), (1, 2, 1, 5, 0), (1, 3, 1, 3, 0), (1, 4, 2, 5, 0), (1, 6, 2, 3, 0),
    (2, 0, 1, 2, 0), (2, 1, 1, 4, 0), (2, 2, 2, 7, 0), (2, 4, 1, 4, 0), (2, 5, 1, 2, 0), (2, 6, 2, 0, 0),
    (3, 0, 3, 1, 0), (3, 3, 1, 4, 0), (3, 4, 4, 6, 0),
    (4, 0, 1, 5, 0), (4, 1, 1, 3, 0), (4, 2, 2, 1, 0), (4, 4, 1, 3, 0), (4, 5, 1, 5, 0), (4, 6, 2, 10, 0),
    (5, 0, 2, 9, 0), (5, 2, 1, 7, 0), (5, 3, 1, 5, 0), (5, 4, 4, 7, 0),
    (6, 0, 2, 8, 0), (6, 2, 2, 6, 0), (6, 4, 2, 4, 0), (6, 6, 2, 6, 0),
    (7, 0, 4, 4, 0),
]


def marimba_line(s: Song, bar0: int, phrase, gain: float = 0.5, p: float = -0.2) -> None:
    """A melody on the marimba (struck notes, each ringing up to its next), from bar0."""
    eighth = s.beat / 2
    for bar, e, ln, deg, _ in phrase:
        f = hz(deg, 0)
        s.add("marimba", s.time(bar0 + bar, 2 * e), marimba(f, min(ln * eighth + 0.25, 0.9)), gain, p, 0.3)
        s.add("marimba", s.time(bar0 + bar, 2 * e), marimba(f * 2, min(ln * eighth + 0.15, 0.5)), gain * 0.25, -p, 0.3)


GAME_BARS = 48  ## 4 intro, A 8, B 8, A2 8, C 8, A3 8, break 4: 97.6 s at 118 BPM


def game_chords() -> list:
    prog_a = ["A", "D", "A", "E", "A", "D", "A", "E"]
    prog_b = ["F#m", "D", "A", "E", "F#m", "D", "E", "E"]
    prog_c = ["Bm", "D", "A", "E", "Bm", "D", "E", "E"]
    return prog_a[:4] + prog_a + prog_b + prog_a + prog_c + prog_a + ["A", "D", "E", "E"]


def game_section(bar: int) -> str:
    return ["intro", "A", "B", "A2", "C", "A3", "break"][0 if bar < 4 else min((bar - 4) // 8 + 1, 6)]


def game_theme() -> np.ndarray:
    """'Run Home': the groove, the whistle tune, a kalimba-and-choir bridge (B), the tune in thirds,
    a marimba section in B minor (C), the tune with the choir behind it (A3), a talking-drum break."""
    seed(2001)
    s = Song(118, GAME_BARS, swing=0.12)
    chords = game_chords()
    for bar, ch in enumerate(chords):
        nxt = chords[(bar + 1) % len(chords)]
        section = game_section(bar)
        drums_groove(s, bar, 0.5 if bar < 2 else (0.75 if section == "C" else 1.0),
                     fill=bar in (3, 11, 19, 27, 35, 43, 47))
        bass_bar(s, bar, ch, nxt, 0.0 if section == "break" and bar in (44, 45) else 1.0)
        if section != "break" or bar >= 46:
            guitars_bar(s, bar, ch, 0.7 if section in ("B", "C") else 1.0)
        root, tones = CHORDS[ch]
        if section == "B":
            kalimba_bar(s, bar, ch, 1.0)
            for d in tones:
                s.add("choir", s.time(bar), voice_aah(hz(d, 0), s.beat * 4 + 0.3, 0.35), 0.16, 0.0, 0.5)
        if section == "A2":
            kalimba_bar(s, bar, ch, 0.5, 2)
        if section == "C":
            s.add("pad", s.time(bar), pad([hz(d, -1) for d in tones], s.beat * 4 + 0.2, bright=3.0), 0.14, 0.0, 0.4)
        if section == "A3":
            for d in tones:
                s.add("choir", s.time(bar), voice_aah(hz(d, 0), s.beat * 4 + 0.3, 0.7), 0.13, 0.0, 0.5)
            kalimba_bar(s, bar, ch, 0.45, 2)
        if section == "break":
            s.add("pad", s.time(bar), pad([hz(d, -1) for d in tones], s.beat * 4 + 0.2), 0.12, 0.0, 0.4)
    melody(s, 4, TUNE_A, 0, 0.42, 0.1, 0.3)
    melody(s, 14, ANSWER, 0, 0.36, 0.15, 0.35)
    melody(s, 18, ANSWER, 0, 0.36, 0.15, 0.35)
    melody(s, 20, TUNE_A, 0, 0.42, 0.1, 0.3, harmony=2)
    marimba_line(s, 28, TUNE_C, 0.5)
    melody(s, 30, ANSWER, 1, 0.22, 0.2, 0.4)
    melody(s, 34, ANSWER, 1, 0.22, 0.2, 0.4)
    melody(s, 36, TUNE_A, 0, 0.42, 0.1, 0.3, harmony=2)
    melody(s, 46, CALL, 0, 0.4, 0.1, 0.35)
    s.duck(["bass", "gtr_lead", "gtr_chop", "kalimba", "pad", "choir", "marimba"], 0.22)
    # balance (pre-master, LUFS): whistle -13, bass -17.5, kick -16.5, kalimba -18, snare -18, talking
    # drum -19, guitars -21 and -25, choir -23, pad -24, shaker -24, congas -24, open hat -30
    return s.mix({"kick": 0.66, "snare": 0.6, "shaker": 0.58, "conga": 0.7, "hat": 0.5, "talk": 0.42, "bass": 0.385,
                  "gtr_lead": 1.83, "gtr_chop": 2.9, "kalimba": 0.6, "choir": 1.97, "pad": 1.4, "whistle": 0.9,
                  "marimba": 0.9, "reverb": 0.35}, dip=2.5)


def game_drive() -> np.ndarray:
    """The drive layer of 'Run Home' (same 48 bars, played over it as the run nears home): djembe
    16ths, the agogo bell's hi-lo pattern, a second shaker and tom fills. Mastered 6 dB under the
    theme: the game raises it from silence."""
    seed(2006)
    s = Song(118, GAME_BARS, swing=0.12)
    for bar in range(GAME_BARS):
        if game_section(bar) == "break" and bar < 46:
            continue
        for step, kind, v in [(0, "bass", 1.0), (2, "tone", 0.6), (3, "tone", 0.5), (4, "slap", 0.9), (6, "tone", 0.6),
                              (7, "slap", 0.7), (8, "bass", 0.9), (10, "tone", 0.6), (11, "tone", 0.5), (12, "slap", 0.9),
                              (13, "tone", 0.4), (14, "slap", 0.8), (15, "tone", 0.5)]:
            sig = djembe_bass(v) if kind == "bass" else conga(360 if kind == "tone" else 410, v, kind == "slap")
            s.add("djembe", s.time(bar, step), sig, 0.7, 0.25, 0.1)
        for step, high in [(2, True), (3, False), (6, True), (10, True), (11, False), (14, True)]:
            s.add("agogo", s.time(bar, step), agogo(high, 0.8 if high else 0.6), 0.35, -0.5, 0.15)
        for step in range(16):
            s.add("shaker2", s.time(bar, step), shaker(0.4 + 0.4 * (step % 2 == 1), step % 4 == 3), 0.4, -0.35, 0.05)
        if bar % 8 == 7:
            for k, step in enumerate([12, 13, 14, 15]):
                s.add("toms", s.time(bar, step), drum(140 - 15 * k, 0.4, 0.15, 0.5, 0.05), 0.6, 0.3 - 0.2 * k, 0.15)
    return s.mix({"djembe": 0.8, "agogo": 0.7, "shaker2": 0.6, "toms": 0.7, "reverb": 0.3}, target=-22.0, dip=2.5)


MENU_TUNE = [
    (0, 0, 3, 2, 0), (0, 3, 1, 1, 0), (0, 4, 2, 0, 0), (0, 6, 1, 1, 0), (0, 7, 1, 2, 0),
    (1, 0, 6, 1, 1), (1, 6, 1, -1, 0), (1, 7, 1, 1, 0),
    (2, 0, 3, 0, 0), (2, 3, 1, 2, 0), (2, 4, 4, 4, 1),
    (3, 0, 3, 5, 0), (3, 3, 1, 4, 0), (3, 4, 2, 3, 0), (3, 6, 1, 2, 0), (3, 7, 1, 1, 0),
    (4, 0, 3, 2, 0), (4, 3, 1, 4, 0), (4, 4, 4, 7, 1),
    (5, 0, 3, 6, 0), (5, 3, 1, 5, 0), (5, 4, 4, 4, 0),
    (6, 0, 2, 5, 0), (6, 2, 2, 7, 0), (6, 4, 1, 5, 0), (6, 5, 1, 4, 0), (6, 6, 2, 3, 0),
    (7, 0, 7, 4, 1),
]


def menu_theme() -> np.ndarray:
    seed(2002)
    s = Song(92, 16, swing=0.08)
    prog = ["A", "E/G#", "F#m", "D", "A", "E/G#", "D", "E"] * 2
    for bar, ch in enumerate(prog):
        root, tones = CHORDS[ch]
        kalimba_bar(s, bar, ch, 0.9)
        s.add("pad", s.time(bar), pad([hz(d, -1) for d in tones], s.beat * 4 + 0.3, bright=3.0), 0.2, 0.0, 0.5)
        bass_f = hz(tones[0] if ch == "E/G#" else root, -2)
        s.add("bass", s.time(bar), bass(bass_f, s.beat * 2.6, 0.8), 0.7)
        s.add("bass", s.time(bar, 10), bass(bass_f * 1.5 if ch != "E/G#" else hz(4, -2), s.beat * 1.4, 0.6), 0.7)
        if bar < 8:
            for d in tones:
                s.add("choir", s.time(bar), voice_aah(hz(d, 0), s.beat * 4 + 0.4, 0.15), 0.12, 0.0, 0.6)
        if bar >= 2:
            for step, v in [(0, 0.7), (10, 0.4)]:
                tm = s.time(bar, step)
                s.add("kick", tm, kick(v), 0.6)
                s.kicks.append(tm)
            for step in range(0, 16, 2):
                s.add("shaker", s.time(bar, step), shaker(0.5 + 0.3 * (step % 4 == 2), step % 4 == 2), 0.4, 0.3, 0.1)
            for step, f, v in [(6, 300, 0.5), (7, 300, 0.35), (14, 360, 0.5)]:
                s.add("conga", s.time(bar, step), conga(f, v), 0.45, -0.35, 0.2)
        if bar >= 4:
            s.add("snare", s.time(bar, 12), clap(0.5), 0.3, 0.1, 0.3)
    melody(s, 8, MENU_TUNE, 1, 0.34, 0.1, 0.4)
    s.duck(["bass", "pad"], 0.12)
    # balance (pre-master, LUFS): whistle -14, kalimba -16.5, bass -21, pad -24, choir -24, kick -24,
    # congas -27, shaker -29, clap -32
    return s.mix({"kalimba": 0.7, "pad": 0.8, "bass": 0.6, "choir": 2.14, "kick": 0.7, "shaker": 0.7, "conga": 0.8,
                  "snare": 1.35, "whistle": 0.85, "reverb": 0.45}, reverb=2.0)


def sting_win() -> np.ndarray:
    """Home: a djembe roll, then the whole band on A major: kick, kalimba running up the chord,
    the choir on "aah", the whistle climbing to a held E6, a shimmer; ring-out."""
    seed(2003)
    s = Song(118, 2, loop=False)
    s.n = n_of(3.6)
    s.send = np.zeros((s.n, 2))
    for k in range(12):
        s.add("drums", k * 0.035, conga(300 + 6 * k, 0.3 + 0.05 * k), 0.6, -0.3 + 0.05 * k, 0.15, 0.002)
    hit = 0.45
    s.add("drums", hit, kick(1.0), 1.0)
    s.add("drums", hit, djembe_bass(1.0), 0.6)
    s.add("drums", hit, clap(1.0), 0.6, 0, 0.3)
    s.add("drums", hit, taper(hp(noise(2.6), 5000) * perc(2.6, 0.005, 0.5), 0.5), 0.12, 0.0, 0.3)
    for i, d in enumerate([0, 2, 4, 7, 9, 11, 14]):
        s.add("kal", hit + i * 0.06, kalimba(hz(d, 0), 1.6), 0.45, -0.4 + i * 0.12, 0.35)
        s.add("kal", hit + i * 0.06, bell(hz(d, 1), 1.2, 0.8), 0.1, 0.4 - i * 0.12, 0.4)
    for d in [0, 2, 4, 7]:
        s.add("choir", hit, voice_aah(hz(d, 0), 2.6, 0.9), 0.18, 0.0, 0.5)
    s.add("bass", hit, taper(bass(A2, 2.4, 1.0), 0.6), 0.8)
    s.add("gtr", hit, sum(guitar(hz(d, 0), 1.6, 0.6) for d in [0, 2, 4, 7]), 0.35, 0.4, 0.3)
    notes = [(0.0, 0.1, hz(4, 0), 0), (0.1, 0.1, hz(7, 0), 0), (0.2, 0.1, hz(9, 0), 0), (0.3, 1.9, hz(11, 0), 1)]
    s.add("whistle", hit, whistle(notes, 2.4), 0.45, 0.1, 0.35, 0.0)
    out = s.mix({"reverb": 0.4}, reverb=1.8, target=-14.0)
    return fade(out, 0.002, 0.3)


def sting_lose() -> np.ndarray:
    """Game over: a soft fall in A minor (E5 D5 C5 B4, then A4 over a low A minor chord), kalimba
    doubled by marimba, the whistle sighing down, a low drum to close."""
    seed(2004)
    s = Song(92, 2, loop=False)
    s.n = n_of(3.4)
    s.send = np.zeros((s.n, 2))
    fall_ = [(0.0, 659.3), (0.22, 587.3), (0.44, 523.3), (0.66, 493.9), (0.98, 440.0)]
    for i, (at, f) in enumerate(fall_):
        last = i == len(fall_) - 1
        s.add("kal", at, kalimba(f, 1.8 if last else 0.9), 0.5, -0.2, 0.35)
        s.add("mar", at, marimba(f / 2, 1.2 if last else 0.6), 0.35, 0.2, 0.25)
    s.add("pad", 0.98, pad([110.0, 130.8, 164.8, 220.0], 2.2, bright=2.5), 0.4, 0.0, 0.5)
    s.add("bass", 0.98, taper(bass(110.0, 2.2, 0.8), 0.6), 0.6)
    s.add("drums", 0.98, djembe_bass(0.9), 0.7, 0.0, 0.2)
    notes = [(0.0, 0.35, 659.3, 1), (0.35, 0.5, 523.3, 0)]
    s.add("whistle", 1.25, whistle(notes, 1.2), 0.25, 0.15, 0.4, 0.0)
    out = s.mix({"reverb": 0.45}, reverb=2.0, target=-15.0)
    return fade(out, 0.002, 0.4)


# ---------------------------------------------------------------- ambience

def smooth_random(n: int, rate_hz: float, lo: float, hi: float) -> np.ndarray:
    """A slow random curve between lo and hi (noise low-passed at rate_hz)."""
    k = max(int(n / RATE * rate_hz * 4), 4)
    pts = dsp.rng.uniform(0, 1, k + 2)
    xs = np.linspace(0, n, k + 2)
    curve = np.interp(np.arange(n), xs, pts)
    win = np.hanning(int(RATE / rate_hz))
    curve = fftconvolve(curve, win / win.sum(), "same")
    curve = (curve - curve.min()) / (curve.max() - curve.min() + 1e-9)
    return lo + (hi - lo) * curve


def wind(sec: float, gust: np.ndarray) -> np.ndarray:
    """Wind over grass: noise whose brightness and level follow the gusts (shaped frame by frame)."""
    from scipy import signal as sg
    n = n_of(sec)
    chans = []
    for c in range(2):
        f, _, z = sg.stft(dsp.rng.standard_normal(n), RATE, nperseg=4096, noverlap=3072)
        g = np.interp(np.linspace(0, n, z.shape[1]), np.arange(n), gust)
        cut = 180 + 900 * g ** 1.5
        mask = 1 / (1 + (f[:, None] / cut[None, :]) ** 3) / np.sqrt(np.maximum(f[:, None], 40) / 40)
        z *= mask * g[None, :]
        _, y = sg.istft(z, RATE, nperseg=4096, noverlap=3072)
        chans.append(y[:n])
    return np.stack(chans, axis=1)


def crickets(sec: float, freq: float, period: float, p: float) -> np.ndarray:
    out = np.zeros(n_of(sec))
    x = t(0.012)
    pulse = np.sin(2 * np.pi * freq * x) * np.hanning(len(x))
    tm = dsp.rng.uniform(0, period)
    while tm < sec - 0.1:
        for k in range(3):
            place(out, tm + k * 0.022, pulse, dsp.rng.uniform(0.6, 1.0))
        tm += period * dsp.rng.uniform(0.92, 1.08)
    return pan(out, p)


def cicada(sec: float, swell_at: float, p: float) -> np.ndarray:
    x = t(sec)
    am = np.abs(np.sin(2 * np.pi * 55 * x)) ** 6
    env = np.exp(-((x - swell_at) / 2.2) ** 2)
    return pan(bp(noise(sec), 4800, 7200) * am * env, p)


def bird_dove() -> np.ndarray:
    """A distant dove: "coo, COO-coo", low and soft."""
    out = np.zeros(n_of(1.6))
    for at, d, f0, a in [(0.0, 0.28, 520, 0.6), (0.42, 0.42, 560, 1.0), (0.9, 0.3, 500, 0.7)]:
        f = glide(f0, f0 * 0.9, d)
        place(out, at, dsp.tone(f, (1.0, 0.25, 0.06)) * adsr(d, 0.06, 0.1, 0.8, 0.1), a)
    return lp(out, 1500)


def bird_trill() -> np.ndarray:
    """A small bird far off: a run of quick falling chirps."""
    out = np.zeros(n_of(0.9))
    f0 = dsp.rng.uniform(3200, 4200)
    for k in range(int(dsp.rng.integers(6, 10))):
        d = 0.045
        f = glide(f0 * 1.25, f0 * 0.85, d)
        place(out, k * 0.07, np.sin(phase_of(f)) * np.hanning(n_of(d)), 0.6 + 0.4 * np.sin(k))
    return out


def bird_whistle() -> np.ndarray:
    """A clear two-note call (up, then down a little)."""
    out = np.zeros(n_of(0.8))
    a, b, c = dsp.rng.uniform(2100, 2400), dsp.rng.uniform(2700, 3000), dsp.rng.uniform(2300, 2600)
    place(out, 0.0, np.sin(phase_of(glide(a, b, 0.16))) * adsr(0.16, 0.02, 0.05, 0.8, 0.04), 0.8)
    place(out, 0.22, np.sin(phase_of(glide(b, c, 0.22))) * adsr(0.22, 0.02, 0.05, 0.8, 0.06), 1.0)
    return out


def at_lufs(x: np.ndarray, target: float) -> np.ndarray:
    """x scaled so its gated loudness is `target` (LUFS)."""
    return x * 10 ** ((target - dsp.lufs(x)) / 20)


def ambience() -> np.ndarray:
    """Layers set by loudness (LUFS, before the master brings the whole to -30): wind -31, distant
    birds -36 (while they call), grass -40, crickets -41, cicada swells -42."""
    seed(2005)
    sec, xf = 48.0, 3.0
    total = sec + xf
    n = n_of(total)
    gust = smooth_random(n, 0.12, 0.25, 1.0)
    out = at_lufs(wind(total, gust), -31.0)
    grass = np.stack([bp(noise(total), 2500, 9000, 2) for _ in range(2)], axis=1)
    rustle = uniform_filter1d(np.abs(dsp.rng.standard_normal(n)), 300) ** 4  # bursts, not a hiss
    out += at_lufs(grass * (gust ** 2.5 * rustle / rustle.max())[:, None], -40.0)
    bugs = sum(crickets(total, freq, period, p) * g for freq, period, p, g in
               [(4300, 0.52, -0.6, 1.0), (4750, 0.61, 0.5, 0.7), (5100, 0.47, 0.1, 0.5)])
    out += at_lufs(bugs, -41.0)
    out += at_lufs(cicada(total, 14.0, -0.3) + 0.7 * cicada(total, 35.0, 0.4), -42.0)
    far = np.zeros((n, 2))
    calls = [(4.0, bird_dove, -0.5), (9.5, bird_trill, 0.6), (15.0, bird_whistle, -0.2), (21.0, bird_dove, 0.4),
             (26.5, bird_trill, -0.6), (30.0, bird_whistle, 0.3), (36.0, bird_trill, 0.1), (41.0, bird_whistle, -0.4)]
    for at, call, p in calls:
        place(far, at + dsp.rng.uniform(-0.5, 0.5), pan(lp(call(), 6000), p), dsp.rng.uniform(0.7, 1.0))
    ir = impulse(2.0, 1.4, 3500)
    out += at_lufs(far * 0.6 + convolve(far, ir)[:n] * 0.5, -36.0)
    # the last `xf` seconds cross-fade (equal power) into the first: the loop has no seam
    m = n_of(sec)
    k = n_of(xf)
    w = np.sin(np.linspace(0, np.pi / 2, k))[:, None]
    loop = out[:m].copy()
    loop[:k] = out[:k] * w + out[m:m + k] * np.cos(np.linspace(0, np.pi / 2, k))[:, None]
    two = master(np.vstack([loop, loop]), -30.0, OGG_CEILING)
    return two[m:]


## How each file should sound (copied into tools/audio_report.py's table).
DESCRIPTIONS = {
    "music_game": "'Run Home', 118 BPM township jive in A major, 98 s loop: bouncing thumb bass, two interlocking "
                  "clean guitars, kick/snare/clap, swung shaker and congas, a cheerful pennywhistle tune, a kalimba "
                  "and choir bridge, the tune in thirds, a marimba section in B minor, the tune with the choir, a "
                  "talking-drum break; slightly scooped at 3 kHz so the effects cut through; no seam.",
    "music_game_drive": "The game theme's drive layer, same 98 s in sync: djembe 16ths, the agogo bell's hi-lo, a second "
                        "shaker and tom fills; it fades in on the home stretch (alone it is only percussion).",
    "music_menu": "'Sunset', 92 BPM, A major: warm and unhurried; kalimba arpeggios, a soft string pad, a hummed choir, "
                  "gentle drums, the whistle tune the second time round; no seam.",
    "sting_win": "Home reached: a quick djembe roll landing at 0.45 s on the whole band in A major, the whistle climbing "
                 "to a held high note, a shimmer; rings out in 3 s.",
    "sting_lose": "Game over, gentle: kalimba and marimba falling E5-D5-C5-B4 onto A4 over a low A minor pad, the "
                  "whistle sighing down; fades over 3 s.",
    "amb_savanna": "The savanna under the music: wind gusting through grass, crickets chirping in threes, two far "
                   "cicada swells, a distant dove and small birds; barely noticed; no seam.",
}


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("assets/audio")
    global REPORT
    REPORT = "--report" in sys.argv
    which = [a for a in sys.argv[2:] if not a.startswith("--")] or ["game", "drive", "menu", "win", "lose", "ambience"]
    out.mkdir(parents=True, exist_ok=True)
    jobs = {
        "game": ("music_game.ogg", game_theme, 3),
        "drive": ("music_game_drive.ogg", game_drive, 0),
        "menu": ("music_menu.ogg", menu_theme, 3),
        "win": ("sting_win.ogg", sting_win, 3),
        "lose": ("sting_lose.ogg", sting_lose, 3),
        "ambience": ("amb_savanna.ogg", ambience, 0),
    }
    for key in which:
        name, make, q = jobs[key]
        x = make()
        write_ogg(out / name, x, q)
        print(f"{name}: {len(x) / RATE:6.2f} s  {dsp.lufs(x):6.1f} LUFS  true peak "
              f"{20 * np.log10(dsp.true_peak(x)):5.1f} dBTP  {(out / name).stat().st_size / 1024:6.0f} KB")


if __name__ == "__main__":
    main()
