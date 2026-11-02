#!/usr/bin/env python3
"""Measures every sound of the game and draws its spectrogram, so the mix can be checked by eye.

For each file (WAV or Ogg Vorbis, decoded with ffmpeg):
    length, channels, peak (dBFS), true peak (dBTP, 4x oversampled, ITU-R BS.1770-4),
    integrated loudness (LUFS, BS.1770-4: K-weighting, 400 ms blocks, gates at -70 LUFS and -10 LU;
    a clip shorter than a block is measured padded with silence, marked *), the loudest momentary
    loudness (M max, 400 ms), DC offset, clicks (a first or last sample far from zero, a jump in
    the first or last 2 ms), the spectral centroid, the 95 % roll-off, the highest frequency with
    energy (-60 dB under the strongest bin: shows a band-limited source), and the share of energy
    under 200 Hz (what a phone speaker can't play).
Writes a Markdown table (`sounds.md`), a CSV, one spectrogram PNG per sound (waveform on top,
log-frequency spectrogram under it) and a contact sheet of them all.

Usage: python3 tools/audio_report.py OUT_DIR [files or folders ...]   (default: assets/audio)
"""
import csv
import subprocess
import sys
from pathlib import Path

import numpy as np
from scipy import signal

RATE = 44100


def decode(path: Path) -> np.ndarray:
    """Samples as float (frames x channels) at RATE, through ffmpeg (any format)."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ar", str(RATE), "-"],
                         capture_output=True, check=True).stdout
    channels = channel_count(path)
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, channels).astype(np.float64)


def channel_count(path: Path) -> int:
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                          "stream=channels", "-of", "csv=p=0", str(path)], capture_output=True, text=True).stdout
    return int(out.strip() or 1)


def source_rate(path: Path) -> int:
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                          "stream=sample_rate", "-of", "csv=p=0", str(path)], capture_output=True, text=True).stdout
    return int(out.strip() or RATE)


def k_weight(x: np.ndarray) -> np.ndarray:
    """The BS.1770 K-weighting: a high shelf (+4 dB above ~1.7 kHz) and a high-pass (RLB, ~38 Hz),
    designed for any rate (the published coefficients are for 48 kHz)."""
    f0, gain, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    k = np.tan(np.pi * f0 / RATE)
    vh = 10 ** (gain / 20)
    vb = vh ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    b1 = [(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]
    a1 = [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    f0, q = 38.13547087602444, 0.5003270373238773
    k = np.tan(np.pi * f0 / RATE)
    a2 = [1, 2 * (k * k - 1) / (1 + k / q + k * k), (1 - k / q + k * k) / (1 + k / q + k * k)]
    b2 = [1, -2, 1]
    return signal.lfilter(b2, a2, signal.lfilter(b1, a1, x, axis=0), axis=0)


def block_loudness(x: np.ndarray, block: float = 0.4, overlap: float = 0.75) -> np.ndarray:
    """Loudness (LUFS) of each block of the K-weighted signal (channels summed with weight 1)."""
    y = k_weight(x)
    n = int(block * RATE)
    hop = int(n * (1 - overlap))
    if len(y) < n:
        y = np.vstack([y, np.zeros((n - len(y), y.shape[1]))])
    starts = range(0, len(y) - n + 1, hop)
    power = np.array([(y[s:s + n] ** 2).mean(axis=0).sum() for s in starts])
    return -0.691 + 10 * np.log10(power + 1e-20)


def integrated(x: np.ndarray) -> float:
    lk = block_loudness(x)
    lk = lk[lk > -70]
    if lk.size == 0:
        return -70.0
    gate = 10 * np.log10(np.mean(10 ** (lk / 10))) - 10
    lk = lk[lk > gate]
    return float(10 * np.log10(np.mean(10 ** (lk / 10))))


def true_peak(x: np.ndarray) -> float:
    up = signal.resample_poly(x, 4, 1, axis=0)
    return 20 * np.log10(np.abs(up).max() + 1e-12)


def measure(path: Path) -> dict:
    x = decode(path)
    mono = x.mean(axis=1)
    peak = np.abs(x).max() + 1e-12
    n = len(mono)
    spec = np.abs(np.fft.rfft(mono * np.hanning(n))) ** 2
    f = np.fft.rfftfreq(n, 1 / RATE)
    total = spec.sum() + 1e-20
    cum = np.cumsum(spec) / total
    edge = int(0.002 * RATE)
    m = {
        "file": path.name,
        "rate": source_rate(path),
        "ch": x.shape[1],
        "length_s": n / RATE,
        "peak_dbfs": 20 * np.log10(peak),
        "true_peak_dbtp": true_peak(x),
        "lufs_i": integrated(x),
        "short": n < 0.4 * RATE,
        "m_max": float(block_loudness(x, overlap=0.9).max()),
        "dc": float(mono.mean()),
        "start": float(np.abs(x[0]).max() / peak),
        "end": float(np.abs(x[-1]).max() / peak),
        "jump_start": float(np.abs(np.diff(x[:edge], axis=0)).max() / peak) if n > edge else 0.0,
        "jump_end": float(np.abs(np.diff(x[-edge:], axis=0)).max() / peak) if n > edge else 0.0,
        "centroid_hz": float((f * spec).sum() / total),
        "rolloff95_hz": float(f[np.searchsorted(cum, 0.95)]),
        "top_hz": float(f[np.nonzero(spec > spec.max() * 1e-6)[0].max()]),
        "below200": float(spec[f < 200].sum() / total),
    }
    if path.name.startswith(("music_", "amb_")):  # a loop: its end must run into its start
        step = np.abs(x[0] - x[-1]).max()
        typical = np.percentile(np.abs(np.diff(x, axis=0)).max(axis=1), 99.5)
        m["clicks"] = f"loop seam {step / typical:.2f}x" + (" (jump!)" if step > typical else " ok")
    else:  # a click: the sound starts or stops away from zero (> -40 dB of its peak), or jumps there
        m["clicks"] = ", ".join(k for k, v in [("start", m["start"] > 0.01), ("end", m["end"] > 0.01),
                                                ("jump-in", m["jump_start"] > 0.25 and m["start"] > 0.002),
                                                ("jump-out", m["jump_end"] > 0.25 and m["end"] > 0.002)] if v) or "-"
    m["_x"] = x
    return m


def spectrogram_png(m: dict, out: Path, note: str = "") -> None:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    x = m["_x"]
    mono = x.mean(axis=1)
    fig, (a, b) = plt.subplots(2, 1, figsize=(8, 4.6), gridspec_kw={"height_ratios": [1, 3]}, dpi=110)
    t = np.arange(len(mono)) / RATE
    for c in range(x.shape[1]):
        a.plot(t, x[:, c], lw=0.5, alpha=0.8)
    a.set_xlim(0, t[-1] if len(t) else 1)
    a.set_ylim(-1, 1)
    a.axhline(0, color="k", lw=0.3)
    a.set_xticks([])
    a.set_ylabel("wave")
    nper = 1024 if len(mono) > 4096 else 256
    f, tt, s = signal.spectrogram(mono, RATE, nperseg=nper, noverlap=nper * 3 // 4, window="hann")
    s_db = 10 * np.log10(s + 1e-14)
    s_db -= s_db.max()
    b.pcolormesh(tt, np.maximum(f, 1), s_db, vmin=-90, vmax=0, cmap="magma", shading="auto")
    b.set_yscale("log")
    b.set_ylim(40, RATE / 2)
    b.set_ylabel("Hz")
    b.set_xlabel("s")
    title = (f"{m['file']}  {m['length_s']:.2f} s  peak {m['peak_dbfs']:.1f} dBFS  TP {m['true_peak_dbtp']:.1f} dBTP  "
             f"{m['lufs_i']:.1f} LUFS{'*' if m['short'] else ''}")
    a.set_title(title + (f"\n{note}" if note else ""), fontsize=8)
    fig.tight_layout()
    fig.savefig(out)
    plt.close(fig)


def contact_sheet(pngs: list, out: Path, cols: int = 4) -> None:
    from PIL import Image
    if not pngs:
        return
    imgs = [Image.open(p) for p in pngs]
    w, h = imgs[0].size
    w2, h2 = w // 2, h // 2
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w2, rows * h2), "white")
    for i, im in enumerate(imgs):
        sheet.paste(im.resize((w2, h2), Image.LANCZOS), ((i % cols) * w2, (i // cols) * h2))
    sheet.save(out)


FIELDS = ["file", "rate", "ch", "length_s", "peak_dbfs", "true_peak_dbtp", "lufs_i", "m_max", "dc", "clicks",
          "centroid_hz", "rolloff95_hz", "top_hz", "below200"]


def main() -> None:
    out = Path(sys.argv[1])
    sources = [Path(p) for p in sys.argv[2:]] or [Path("assets/audio")]
    files = []
    for s in sources:
        files += sorted(p for p in s.rglob("*") if p.suffix in (".wav", ".ogg", ".mp3")) if s.is_dir() else [s]
    out.mkdir(parents=True, exist_ok=True)
    (out / "spectrograms").mkdir(exist_ok=True)
    rows, pngs = [], []
    for p in files:
        m = measure(p)
        png = out / "spectrograms" / (p.stem + ".png")
        spectrogram_png(m, png)
        pngs.append(png)
        rows.append(m)
        print(f"{m['file']:28s} {m['length_s']:6.2f}s {m['peak_dbfs']:6.1f} dBFS {m['true_peak_dbtp']:6.1f} dBTP "
              f"{m['lufs_i']:6.1f} LUFS{'*' if m['short'] else ' '} clicks {m['clicks']}")
    with open(out / "sounds.csv", "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(FIELDS)
        for m in rows:
            w.writerow([m[k] if not isinstance(m[k], float) else round(m[k], 4) for k in FIELDS])
    lines = ["| file | rate | ch | length s | peak dBFS | true peak dBTP | LUFS-I | M max | DC | clicks | centroid Hz | "
             "95% roll-off Hz | top Hz | < 200 Hz |", "|" + " --- |" * 14]
    for m in rows:
        lines.append(f"| {m['file']} | {m['rate']} | {m['ch']} | {m['length_s']:.3f} | {m['peak_dbfs']:.1f} | "
                     f"{m['true_peak_dbtp']:.1f} | {m['lufs_i']:.1f}{'*' if m['short'] else ''} | {m['m_max']:.1f} | "
                     f"{m['dc']:+.4f} | {m['clicks']} | {m['centroid_hz']:.0f} | {m['rolloff95_hz']:.0f} | "
                     f"{m['top_hz']:.0f} | {100 * m['below200']:.0f} % |")
    lines.append("")
    lines.append("`*` shorter than a 400 ms block: measured padded with silence (compare M max between one-shots).")
    lines.append("Loops (music_, amb_): the step from their last sample to their first, against the 99.5th percentile of")
    lines.append("their sample-to-sample steps (under 1x: the seam is no bigger than the music's own movement).")
    (out / "sounds.md").write_text("\n".join(lines) + "\n")
    contact_sheet(pngs, out / "spectrograms_sheet.png")
    print(f"{len(rows)} sounds -> {out / 'sounds.md'}")


if __name__ == "__main__":
    main()
