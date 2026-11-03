"""Sound building blocks shared by tools/sfx_synth.py and tools/music_synth.py (numpy + scipy only).

Every function returns float arrays at RATE: mono (n,) or stereo (n, 2). Times are in seconds,
frequencies in Hz. The game's key is A major (KEY_ROOT = A4): `note(degree, octave)` and `midi()`.
"""
import subprocess
import wave
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.ndimage import minimum_filter1d, uniform_filter1d

RATE = 44100
KEY_ROOT = 440.0  # A4: the game's key is A major
MAJOR = [0, 2, 4, 5, 7, 9, 11]
rng = np.random.default_rng(7)


def seed(n: int) -> None:
    """Restarts the shared random generator (each sound gets its own repeatable noise)."""
    global rng
    rng = np.random.default_rng(n)


def note(degree: int, octave: int = 0) -> float:
    """Frequency of a degree of A major (0 = A4, 2 = C#5, 4 = E5; negative goes down)."""
    o, d = divmod(degree, 7)
    return KEY_ROOT * 2 ** (octave + o + MAJOR[d] / 12)


def midi(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def t(sec: float) -> np.ndarray:
    return np.arange(int(round(sec * RATE))) / RATE


def n_of(sec: float) -> int:
    return int(round(sec * RATE))


# ---------------------------------------------------------------- envelopes

def perc(sec: float, attack: float, decay: float, curve: float = 1.0) -> np.ndarray:
    """A struck envelope: a linear rise over `attack`, then an exponential fall (time constant
    `decay`); `curve` > 1 makes the start of the fall hold longer."""
    x = t(sec)
    rise = np.clip(x / max(attack, 1e-5), 0, 1)
    fall = np.exp(-np.maximum(x - attack, 0) / decay)
    return rise * fall ** curve


def adsr(sec: float, a: float, d: float, s: float, r: float) -> np.ndarray:
    """Attack, decay to sustain level `s`, held, then a release of `r` seconds at the end."""
    x = t(sec)
    e = np.where(x < a, x / max(a, 1e-5), s + (1 - s) * np.exp(-(x - a) / max(d, 1e-5)))
    rel = np.clip((sec - x) / max(r, 1e-5), 0, 1)
    return e * rel


def taper(x: np.ndarray, part: float = 0.3) -> np.ndarray:
    """Lets a note die away over its last `part` (a cosine): a note cut shorter than its natural
    ring is damped, not chopped."""
    k = int(len(x) * part)
    if k < 2:
        return x
    x = x.copy()
    ramp = 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, k))
    x[-k:] *= ramp[:, None] if x.ndim == 2 else ramp
    return x


def fade(x: np.ndarray, fin: float = 0.001, fout: float = 0.005) -> np.ndarray:
    x = x.copy()
    a, b = min(n_of(fin), len(x) // 2), min(n_of(fout), len(x) // 2)
    if a:
        x[:a] *= np.linspace(0, 1, a) if x.ndim == 1 else np.linspace(0, 1, a)[:, None]
    if b:
        x[-b:] *= np.linspace(1, 0, b) if x.ndim == 1 else np.linspace(1, 0, b)[:, None]
    return x


# ---------------------------------------------------------------- sources

def noise(sec: float) -> np.ndarray:
    return rng.standard_normal(n_of(sec))


def sos_filter(x: np.ndarray, kind: str, f, order: int = 2) -> np.ndarray:
    nyq = RATE / 2 * 0.999
    f = np.clip(f, 10, nyq) if np.ndim(f) else min(max(f, 10), nyq)
    sos = signal.butter(order, f, btype=kind, fs=RATE, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def lp(x, f, order=2):
    return sos_filter(x, "lowpass", f, order)


def hp(x, f, order=2):
    return sos_filter(x, "highpass", f, order)


def bp(x, lo, hi, order=2):
    return sos_filter(x, "bandpass", [lo, hi], order)


def peak_eq(x: np.ndarray, f0: float, gain_db: float, q: float = 1.0) -> np.ndarray:
    """A bell EQ (RBJ cookbook)."""
    a = 10 ** (gain_db / 40)
    w = 2 * np.pi * f0 / RATE
    alpha = np.sin(w) / (2 * q)
    b = [1 + alpha * a, -2 * np.cos(w), 1 - alpha * a]
    den = [1 + alpha / a, -2 * np.cos(w), 1 - alpha / a]
    return signal.lfilter(b, den, x, axis=0)


def shelf(x: np.ndarray, f0: float, gain_db: float, high: bool = True) -> np.ndarray:
    """A high (or low) shelf (RBJ cookbook, slope 1)."""
    a = 10 ** (gain_db / 40)
    w = 2 * np.pi * f0 / RATE
    cw, alpha = np.cos(w), np.sin(w) / 2 * np.sqrt(2)
    s = 1 if high else -1
    b = [a * ((a + 1) + s * (a - 1) * cw + 2 * np.sqrt(a) * alpha), -2 * s * a * ((a - 1) + s * (a + 1) * cw),
         a * ((a + 1) + s * (a - 1) * cw - 2 * np.sqrt(a) * alpha)]
    den = [(a + 1) - s * (a - 1) * cw + 2 * np.sqrt(a) * alpha, 2 * s * ((a - 1) - s * (a + 1) * cw),
           (a + 1) - s * (a - 1) * cw - 2 * np.sqrt(a) * alpha]
    return signal.lfilter(b, den, x, axis=0)


def sweep_noise(sec: float, f0: float, f1: float, width: float = 1.0, frames: int = 48) -> np.ndarray:
    """Noise in a band whose centre glides from f0 to f1 (exponentially), `width` octaves wide:
    shaped frame by frame in the frequency domain, so the sweep is smooth."""
    n = n_of(sec)
    hop = max(n // frames, 64)
    win = hop * 4
    f, _, z = signal.stft(rng.standard_normal(n + win), RATE, nperseg=win, noverlap=win - hop)
    k = np.linspace(0, 1, z.shape[1])
    centre = f0 * (f1 / f0) ** k
    octs = np.log2(np.maximum(f[:, None], 1) / centre[None, :])
    z *= np.exp(-0.5 * (octs / (width / 2.355 * 2)) ** 2)
    _, y = signal.istft(z, RATE, nperseg=win, noverlap=win - hop)
    y = y[:n]
    return y / (np.abs(y).max() + 1e-9)


def phase_of(freq) -> np.ndarray:
    """Phase (radians) of a tone whose frequency follows the array `freq` sample by sample."""
    return 2 * np.pi * np.cumsum(freq) / RATE


def glide(f0: float, f1: float, sec: float, curve: float = 1.0) -> np.ndarray:
    """A frequency track from f0 to f1 (exponential; `curve` > 1 bends late, < 1 early)."""
    k = (t(sec) / sec) ** curve
    return f0 * (f1 / f0) ** k


def tone(freq, harmonics=(1.0,), sec: float | None = None) -> np.ndarray:
    """A tone of a few harmonics on a frequency (a number with `sec`, or a per-sample array)."""
    if np.ndim(freq) == 0:
        freq = np.full(n_of(sec), float(freq))
    ph = phase_of(freq)
    return sum(a * np.sin((i + 1) * ph) for i, a in enumerate(harmonics) if a)


def fm(fc, ratio: float, index, sec: float | None = None, feedback: float = 0.0) -> np.ndarray:
    """Two-operator FM: a carrier at fc modulated by a sine at fc * ratio, depth `index`
    (a number or a per-sample envelope)."""
    if np.ndim(fc) == 0:
        fc = np.full(n_of(sec), float(fc))
    ph = phase_of(fc)
    mod = np.sin(ph * ratio)
    if feedback:
        mod = np.sin(ph * ratio + feedback * mod)
    return np.sin(ph + index * mod)


def modal(sec: float, modes, scale: float = 1.0) -> np.ndarray:
    """A struck object: decaying partials (frequency, amplitude, decay s), frequencies x scale,
    each with a random phase so a stack of them doesn't line up into a click."""
    x = t(sec)
    out = np.zeros_like(x)
    for f, a, d in modes:
        out += a * np.sin(2 * np.pi * f * scale * x + rng.uniform(0, 0.4)) * np.exp(-x / d)
    return taper(out)


MEMBRANE = [1.0, 1.594, 2.136, 2.296, 2.653, 2.918, 3.156, 3.501]  # circular membrane (Bessel) modes


def drum(f0: float, sec: float, decay: float, bright: float = 0.5, bend: float = 0.06,
         mode_amps=None) -> np.ndarray:
    """A hand drum: membrane modes on f0 whose pitch drops by `bend` as the skin relaxes, the
    upper modes dying faster; `bright` raises the upper modes."""
    x = t(sec)
    pitch = 1 + bend * np.exp(-x / 0.025)
    amps = mode_amps or [1.0, 0.55, 0.4, 0.3, 0.22, 0.15, 0.1, 0.08]
    out = np.zeros_like(x)
    for k, (r, a) in enumerate(zip(MEMBRANE, amps)):
        w = a * (1 if k == 0 else bright)
        out += w * np.sin(phase_of(f0 * r * pitch) + rng.uniform(0, 6.28)) * np.exp(-x / (decay / (1 + 0.9 * k)))
    return taper(out)


def pluck(freq: float, sec: float, decay: float = 1.5, bright: float = 0.6, pick: float = 0.12) -> np.ndarray:
    """A plucked string (Karplus-Strong through scipy's lfilter): a burst of filtered noise in a
    delay line with a loss filter; `decay` is roughly the T60 in seconds, `pick` where it is
    plucked (0..0.5: nearer the bridge is thinner)."""
    n = n_of(sec)
    period = RATE / freq - 0.5
    d = max(int(period), 2)
    g = 10 ** (-3 / (decay * freq))  # loss per trip round the loop for that T60
    exc = rng.uniform(-1, 1, d)
    exc = lp(exc, 800 + 9000 * bright, 1)
    if pick > 0:  # a comb at the pluck point
        k = max(int(d * pick), 1)
        exc = exc - np.roll(exc, k) * 0.9
    x = np.zeros(n)
    x[:d] = exc
    a = np.zeros(d + 2)
    a[0] = 1
    a[d] = -g * 0.5
    a[d + 1] = -g * 0.5
    return signal.lfilter([1.0], a, x)


# ---------------------------------------------------------------- space

def impulse(sec: float, decay: float, damp: float = 6000.0, early: int = 6, stereo: bool = True,
            predelay: float = 0.008) -> np.ndarray:
    """A synthetic room: a few early reflections, then a dense tail of noise that decays (T60 =
    `decay` s) and darkens as it goes (the highs above `damp` die three times faster)."""
    n = n_of(sec)
    chans = []
    for c in range(2 if stereo else 1):
        x = t(sec)
        tail = rng.standard_normal(n)
        low = lp(tail, damp, 2) * np.exp(-x * 6.9 / decay)
        high = hp(tail, damp, 2) * np.exp(-x * 6.9 * 3 / decay)
        ir = (low + 0.6 * high) * np.clip(x / 0.01, 0, 1)
        for _ in range(early):
            i = int(rng.uniform(0.004, 0.045) * RATE)
            ir[i] += rng.uniform(-1, 1) * 2.5
        p = n_of(predelay)
        chans.append(np.concatenate([np.zeros(p), ir])[:n])
    ir = np.stack(chans, axis=1) if stereo else chans[0]
    return ir / np.sqrt((ir ** 2).sum(axis=0)).max()


def convolve(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    """x (mono or stereo) through ir (mono or stereo); a stereo IR on a mono x gives stereo.
    Keeps the length of x plus the IR's tail."""
    if x.ndim == 1 and ir.ndim == 2:
        return np.stack([signal.fftconvolve(x, ir[:, c]) for c in range(2)], axis=1)
    if x.ndim == 2 and ir.ndim == 2:
        return np.stack([signal.fftconvolve(x[:, c], ir[:, c]) for c in range(2)], axis=1)
    if x.ndim == 2:
        return np.stack([signal.fftconvolve(x[:, c], ir) for c in range(2)], axis=1)
    return signal.fftconvolve(x, ir)


def reverb(x: np.ndarray, mix: float, decay: float = 0.8, damp: float = 5000.0, stereo: bool = False,
           low_cut: float = 220.0) -> np.ndarray:
    """x with a little room (`mix` of wet), the tail kept. The lows stay out of the room (a booming
    tail under a thump is mud)."""
    ir = impulse(decay * 1.3, decay, damp, stereo=stereo)
    wet = convolve(hp(x, low_cut, 2), ir)
    dry = np.zeros_like(wet)
    dry[: len(x)] += x if (x.ndim == wet.ndim) else np.stack([x, x], axis=1)
    return dry + mix * wet


def pan(x: np.ndarray, p: float) -> np.ndarray:
    """Mono to stereo at position p (-1 left .. 1 right), equal power."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def place(out: np.ndarray, at: float, x: np.ndarray, gain: float = 1.0, wrap: bool = False) -> None:
    """Mixes x into out from time `at` (s). With `wrap`, what runs past the end comes back in
    at the start (a loop: the tails of its last notes ring into its first bar). Without it, a
    layer that runs past the end of `out` is faded out where it is cut (a hard cut clicks)."""
    i = n_of(at)
    if x.ndim == 1 and out.ndim == 2:
        x = np.stack([x, x], axis=1) * np.sqrt(0.5)
    if i < 0:
        x = x[-i:]
        i = 0
    n = len(out)
    if not wrap and len(x) > n - i:
        x = x[: max(n - i, 0)]
    x = x.copy()
    k = min(len(x) // 3, n_of(0.02))  # a layer cut off while still ringing clicks: fade its end
    if k > 1:
        ramp = 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, k))
        x[-k:] *= ramp[:, None] if x.ndim == 2 else ramp
    while len(x) > 0 and i < n:
        k = min(len(x), n - i)
        out[i:i + k] += x[:k] * gain
        x = x[k:]
        i = 0
        if not wrap:
            break


def saturate(x: np.ndarray, drive: float = 1.0) -> np.ndarray:
    return np.tanh(x * drive) / np.tanh(drive)


def phone(x: np.ndarray, cut: float = 110.0, harmonics: float = 0.6, drive: float = 3.0) -> np.ndarray:
    """Ready for a phone speaker (nothing under ~300 Hz comes out of it): the lows (under 250 Hz) are
    saturated so their 2nd and 3rd harmonics carry the weight where the speaker plays, then the
    sub-bass the speaker can't play is cut under `cut` (it only eats headroom)."""
    low = lp(x, 250.0, 2)
    harm = hp(saturate(low * drive / (np.abs(low).max() + 1e-9), 1.0) * np.abs(low).max(), 220.0, 2)
    return hp(x, cut, 2) + harmonics * harm


def snap(sec: float = 0.02, lo: float = 1500.0, hi: float = 4000.0, decay: float = 0.004) -> np.ndarray:
    """A transient in the band a phone plays best (1.5-4 kHz): a crack, a click, a crunch's edge."""
    return bp(noise(sec), lo, hi, 2) * perc(sec, 0.0002, decay)


# ---------------------------------------------------------------- loudness (ITU-R BS.1770-4)

def k_weight(x: np.ndarray) -> np.ndarray:
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
    return signal.lfilter([1, -2, 1], a2, signal.lfilter(b1, a1, x, axis=0), axis=0)


def _blocks(x: np.ndarray, block: float = 0.4, overlap: float = 0.75) -> np.ndarray:
    y = k_weight(x if x.ndim == 2 else x[:, None])
    n = n_of(block)
    if len(y) < n:
        y = np.vstack([y, np.zeros((n - len(y), y.shape[1]))])
    hop = max(int(n * (1 - overlap)), 1)
    c = np.cumsum(np.vstack([np.zeros((1, y.shape[1])), y ** 2]), axis=0)
    starts = np.arange(0, len(y) - n + 1, hop)
    power = ((c[starts + n] - c[starts]) / n).sum(axis=1)
    return -0.691 + 10 * np.log10(power + 1e-20)


def lufs(x: np.ndarray) -> float:
    """Integrated loudness (gated)."""
    lk = _blocks(x)
    lk = lk[lk > -70]
    if lk.size == 0:
        return -70.0
    gate = 10 * np.log10(np.mean(10 ** (lk / 10))) - 10
    lk = lk[lk > gate]
    return float(10 * np.log10(np.mean(10 ** (lk / 10))))


def momentary_max(x: np.ndarray) -> float:
    """The loudest 400 ms (LUFS): how loud a short sound is heard."""
    return float(_blocks(x, overlap=0.95).max())


def true_peak(x: np.ndarray) -> float:
    return float(np.abs(signal.resample_poly(x, 4, 1, axis=0)).max())


# ---------------------------------------------------------------- dynamics

def limit(x: np.ndarray, ceiling_db: float = -1.0, lookahead: float = 0.004, release: float = 0.08) -> np.ndarray:
    """A look-ahead peak limiter on the 4x-oversampled peaks: the gain never lets a true peak past
    the ceiling, comes down ahead of the peak and recovers over `release`."""
    ceiling = 10 ** (ceiling_db / 20)
    mono_peak = np.abs(x).max(axis=1) if x.ndim == 2 else np.abs(x)
    up = np.abs(signal.resample_poly(x, 4, 1, axis=0))
    up = up.max(axis=1) if up.ndim == 2 else up
    tp = up.reshape(-1, 4).max(axis=1)[: len(mono_peak)] if len(up) >= 4 * len(mono_peak) else mono_peak
    tp = np.maximum(tp, mono_peak)
    need = np.minimum(1.0, ceiling / np.maximum(tp, 1e-9))
    la = max(n_of(lookahead), 1)
    g = minimum_filter1d(need, 2 * la + 1)
    g = uniform_filter1d(g, la)  # smooth the dips (still under need: the min covered twice the span)
    # release: the gain may rise only slowly (one-pole on the way up, by blocks of 64 samples)
    rel = np.exp(-64 / (release * RATE))
    blocks = g[: len(g) // 64 * 64].reshape(-1, 64).min(axis=1)
    out = np.empty_like(blocks)
    level = 1.0
    for i, b in enumerate(blocks):
        level = b if b < level else b + (level - b) * rel
        out[i] = level
    smooth = np.repeat(out, 64)
    smooth = np.concatenate([smooth, g[len(smooth):]])
    gain = np.minimum(g, uniform_filter1d(smooth, 64))
    return x * (gain[:, None] if x.ndim == 2 else gain)


def compress(x: np.ndarray, threshold_db: float, ratio: float, attack: float = 0.01, release: float = 0.15,
             knee_db: float = 6.0) -> np.ndarray:
    """A feed-forward RMS compressor (soft knee), the gain smoothed by a one-pole attack/release
    computed on blocks of 32 samples."""
    mono = x.mean(axis=1) if x.ndim == 2 else x
    blk = 32
    m = len(mono) // blk * blk
    rms = np.sqrt((mono[:m].reshape(-1, blk) ** 2).mean(axis=1) + 1e-12)
    level = 20 * np.log10(rms)
    over = level - threshold_db
    gr = np.where(over <= -knee_db / 2, 0.0,
                  np.where(over >= knee_db / 2, over * (1 - 1 / ratio),
                           (1 - 1 / ratio) * (over + knee_db / 2) ** 2 / (2 * knee_db)))
    a = np.exp(-blk / (attack * RATE))
    r = np.exp(-blk / (release * RATE))
    out = np.empty_like(gr)
    g = 0.0
    for i, v in enumerate(gr):
        g = v + (g - v) * (a if v > g else r)
        out[i] = g
    gain = 10 ** (-np.repeat(out, blk) / 20)
    gain = np.concatenate([gain, np.full(len(mono) - m, gain[-1] if m else 1.0)])
    return x * (gain[:, None] if x.ndim == 2 else gain)


def master(x: np.ndarray, target_lufs: float | None = None, ceiling_db: float = -1.0,
           momentary: float | None = None) -> np.ndarray:
    """Brings x to a loudness (integrated, or the loudest 400 ms for a one-shot) and keeps its true
    peak under the ceiling with the limiter (twice: the limiter takes a little loudness)."""
    x = x - x.mean(axis=0)
    for _ in range(3):
        now = momentary_max(x) if momentary is not None else lufs(x)
        want = momentary if momentary is not None else target_lufs
        x = x * 10 ** ((want - now) / 20)
        x = limit(x, ceiling_db - 0.15)
    tp = true_peak(x)
    if tp > 10 ** (ceiling_db / 20):
        x = x * 10 ** (ceiling_db / 20) / tp
    return x


# ---------------------------------------------------------------- files

def trim(x: np.ndarray, floor_db: float = -66.0) -> np.ndarray:
    """Cuts the silence before the first and after the last sound above floor_db of its peak."""
    mono = np.abs(x).max(axis=1) if x.ndim == 2 else np.abs(x)
    nz = np.nonzero(mono > mono.max() * 10 ** (floor_db / 20))[0]
    return x[nz[0]: nz[-1] + 1] if len(nz) else x


def write_wav(path: Path, x: np.ndarray) -> None:
    """16-bit PCM, dithered (TPDF)."""
    x = np.atleast_2d(x.T).T if x.ndim == 1 else x
    d = rng.uniform(-0.5, 0.5, x.shape) + rng.uniform(-0.5, 0.5, x.shape)
    pcm = np.clip(np.round(x * 32767 + d), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(x.shape[1])
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def write_ogg(path: Path, x: np.ndarray, quality: float = 4.0) -> None:
    """Ogg Vorbis through ffmpeg's libvorbis (quality -1..10; 3 is about 112 kb/s stereo)."""
    tmp = path.with_suffix(".tmp.wav")
    write_wav(tmp, x)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(tmp), "-c:a", "libvorbis", "-q:a", str(quality),
                    "-map_metadata", "-1", str(path)], check=True)
    tmp.unlink()
