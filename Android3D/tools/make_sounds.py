"""Synthesises the game's sound effects into app/src/main/assets/audio/*.ogg.

Usage (from Android3D/):  python3 tools/make_sounds.py
Requires numpy and ffmpeg. The music (chaka.mp3) and two original effects
(projectile.ogg, enemy.ogg) come from the 2D game.
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / "app" / "src" / "main" / "assets" / "audio"
rng = np.random.default_rng(3)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(x, attack=0.005, decay=8.0):
    e = np.exp(-decay * np.arange(len(x)) / RATE)
    a = int(RATE * attack)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return x * e


def sweep(f0, f1, seconds, shape=np.sin):
    tt = t(seconds)
    f = np.linspace(f0, f1, len(tt))
    return shape(2 * np.pi * np.cumsum(f) / RATE)


def lowpass(x, k):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def noise(seconds):
    return rng.uniform(-1, 1, len(t(seconds)))


def tone(freq, seconds, harmonics=(1.0, 0.3, 0.12)):
    tt = t(seconds)
    return sum(a * np.sin(2 * np.pi * freq * (i + 1) * tt) for i, a in enumerate(harmonics))


def write(name, x, gain=0.8):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    pcm = (x * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as d:
        wav = Path(d) / f"{name}.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4",
                        str(OUT / f"{name}.ogg")], check=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # Red bob: bright two-note "pling"
    a = env(tone(1318.5, 0.09), decay=30)
    b = env(tone(1975.5, 0.22), decay=14)
    write("coin", np.concatenate([a, b]), 0.6)
    # Golden bob / shield: rising shimmer chord
    s = sum(env(tone(f, 0.7, (1, 0.2)), attack=0.02 + i * 0.05, decay=4) for i, f in enumerate([523, 659, 784, 1047]))
    write("gold", s * (1 + 0.3 * np.sin(2 * np.pi * 12 * t(0.7))), 0.7)
    # Jump: quick upward sweep
    write("jump", env(sweep(260, 760, 0.16, np.sin) + 0.3 * sweep(520, 1520, 0.16), decay=12), 0.5)
    # Slide: airy whoosh
    n = noise(0.32)
    write("slide", env(lowpass(n, 0.08) * np.sin(np.linspace(0, np.pi, len(n))), attack=0.03, decay=3), 0.55)
    # Stomp: cartoon boing
    tt = t(0.32)
    f = 180 * (1 + 0.5 * np.exp(-tt * 10)) * (1 + 0.06 * np.sin(2 * np.pi * 22 * tt))
    write("stomp", env(np.sin(2 * np.pi * np.cumsum(f) / RATE), decay=7), 0.8)
    # Crash into an obstacle: thump + crunch
    thump = env(sweep(140, 45, 0.35), decay=9)
    crunch = env(lowpass(noise(0.35), 0.25), decay=14)
    write("crash", thump + 0.7 * crunch, 0.9)
    # Splash: noise burst + bubbles
    sp = env(lowpass(noise(0.7), 0.18), attack=0.01, decay=5)
    bubbles = sum(np.roll(env(sweep(600 + 400 * rng.random(), 1400, 0.06), decay=40), int(RATE * 0.08 * i)) for i in range(5))
    write("splash", np.concatenate([sp[:len(bubbles)] + 0.3 * bubbles, sp[len(bubbles):]]), 0.8)
    # Crate smashed: wooden crack
    crack = env(noise(0.25), decay=25) + env(tone(220, 0.25, (1, 0.5, 0.3)), decay=18) * 0.6
    write("smash", crack, 0.8)
    # Level complete: happy arpeggio
    notes = [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5]
    jingle = np.concatenate([env(tone(f, 0.16 if i < 5 else 0.6, (1, 0.35, 0.15)), decay=6 if i < 5 else 2.5)
                             for i, f in enumerate(notes)])
    write("win", jingle, 0.7)
    # Game over: sad descending tune
    notes = [392, 349.2, 311.1, 261.6]
    write("lose", np.concatenate([env(tone(f, 0.28 if i < 3 else 0.8, (1, 0.4, 0.2)), decay=4 if i < 3 else 2)
                                  for i, f in enumerate(notes)]), 0.6)
    print("sounds written to", OUT)


if __name__ == "__main__":
    main()
