#!/usr/bin/env python3
"""Turns a kie.ai clip of a character on flat magenta into sprite frames.

    python3 tools/art/kie/clip.py frames NAME            # every frame keyed -> gen/kie/NAME/all/NNN.png, a contact sheet,
                                                         # and how alike frames are P frames apart (the cycle's length)
    python3 tools/art/kie/clip.py cycle NAME START PERIOD [STEP] # one cycle from START, a picture every STEP frames,
                                                         # each the median of its repeats in the clip
                                                         # -> gen/kie/NAME/cycle/NN.png (one canvas for all), a sheet, a gif

The frames keep the clip's framing (its camera is locked): one canvas for the whole cycle, so the figure bobs and
strides as filmed.
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from cells import key, unpink  # noqa: E402
from scipy import ndimage as ndi  # noqa: E402

GEN = Path(__file__).resolve().parents[1] / "gen/kie"


def load(path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0


def save(a: np.ndarray, path) -> None:
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA").save(path)


def sheet(frames, path, cols, scale=0.35, bg=(0.62, 0.72, 0.86)) -> None:
    h, w = frames[0].shape[:2]
    th, tw = int(h * scale), int(w * scale)
    rows = (len(frames) + cols - 1) // cols
    out = Image.new("RGB", (tw * cols, th * rows), tuple(int(c * 255) for c in bg))
    for i, f in enumerate(frames):
        im = Image.fromarray((f * 255).astype(np.uint8), "RGBA").resize((tw, th), Image.LANCZOS)
        out.paste(im, ((i % cols) * tw, (i // cols) * th), im)
    out.save(path)


# what each figure's own colours never hold (degrees of hue): the pink of the backdrop shows there
PINK = {"hero": (226.0, 346.0, 214.0), "bandit": (282.0, 344.0, -1.0), "strong": (262.0, 344.0, -1.0)}


def tint_table(clean: np.ndarray, tinted: list, n: int = 26) -> np.ndarray:
    """The clip's colours against its first frame's (the still it was given): the clip comes back to that pose every
    cycle, lit pinker by its backdrop (his steel turns purple). A table of the shift per colour, from the pixels of
    those frames against the still's."""
    sums = np.zeros((n, n, n, 3), np.float64)
    cnt = np.zeros((n, n, n), np.float64)
    for t in tinted:
        m = (clean[..., 3] > 0.97) & (t[..., 3] > 0.97)
        m &= np.abs(clean[..., :3].mean(axis=-1) - t[..., :3].mean(axis=-1)) < 0.12
        src = t[..., :3][m]
        i = np.clip((src * (n - 1) + 0.5).astype(int), 0, n - 1)
        np.add.at(sums, (i[:, 0], i[:, 1], i[:, 2]), (clean[..., :3][m] - src).astype(np.float64))
        np.add.at(cnt, (i[:, 0], i[:, 1], i[:, 2]), 1.0)
    near = np.stack([ndi.gaussian_filter(sums[..., c], 1.0) for c in range(3)], axis=-1)
    far = np.stack([ndi.gaussian_filter(sums[..., c], 3.5) for c in range(3)], axis=-1)
    cn, cf = ndi.gaussian_filter(cnt, 1.0), ndi.gaussian_filter(cnt, 3.5)
    return ((near + 0.02 * far) / (cn + 0.02 * cf + 0.5)[..., None]).astype(np.float32)


def untint(a: np.ndarray, table: np.ndarray) -> np.ndarray:
    n = table.shape[0]
    co = (a[..., :3] * (n - 1)).reshape(-1, 3).T
    d = np.stack([ndi.map_coordinates(table[..., c], co, order=1, mode="nearest") for c in range(3)], axis=-1)
    out = a.copy()
    out[..., :3] = np.clip(a[..., :3] + d.reshape(a.shape[0], a.shape[1], 3), 0.0, 1.0)
    return out


def frames(name: str) -> None:
    raw = GEN / name / "raw"
    raw.mkdir(parents=True, exist_ok=True)
    for f in raw.glob("*.png"):
        f.unlink()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(GEN / (name + ".mp4")), str(raw / "%03d.png")], check=True)
    paths = sorted(raw.glob("*.png"))
    fps = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=r_frame_rate,width,height",
                          "-of", "csv=p=0", str(GEN / (name + ".mp4"))], capture_output=True, text=True).stdout.strip()
    keyed = [key(load(p)) for p in paths]
    # the frames back in the first frame's pose (same outline): their colours against it
    first = keyed[0]
    same = [k for k in keyed[6:] if np.abs(k[..., 3] - first[..., 3]).mean() < 0.012]
    who = name.split("_")[0]
    if same:
        table = tint_table(first, same)
        keyed = [first] + [untint(k, table) for k in keyed[1:]]
    if who in PINK:
        lo, hi, blue = PINK[who]
        keyed = [unpink(k, lo, hi, blue) for k in keyed]
    print("%d frames in the first frame's pose" % len(same))
    # one box for the whole clip (the camera is locked)
    al = np.max([k[..., 3] for k in keyed], axis=0) > 0.5
    ys, xs = np.nonzero(al)
    y0, y1, x0, x1 = max(ys.min() - 6, 0), ys.max() + 7, max(xs.min() - 6, 0), xs.max() + 7
    out = GEN / name / "all"
    out.mkdir(exist_ok=True)
    for f in out.glob("*.png"):
        f.unlink()
    crops = []
    for i, k in enumerate(keyed):
        c = k[y0:y1, x0:x1]
        save(c, out / ("%03d.png" % i))
        crops.append(c)
    sheet(crops, GEN / name / "all.png", 12, 0.3)
    # how alike frames are P apart: small pictures, colour over alpha
    small = []
    for c in crops:
        im = Image.fromarray((c * 255).astype(np.uint8), "RGBA").resize((64, 64), Image.BILINEAR)
        a = np.asarray(im).astype(np.float32) / 255.0
        small.append((a[..., :3] * a[..., 3:4]).ravel())
    small = np.array(small)
    n = len(small)
    print("%s: %d frames, %s, box %dx%d" % (name, n, fps, x1 - x0, y1 - y0))
    best = []
    for p in range(6, min(n - 4, 60)):
        d = [float(np.abs(small[i] - small[i + p]).mean()) for i in range(4, n - p - 2)]
        if d:
            i = int(np.argmin(d))
            best.append((p, float(np.mean(d)), d[i], i + 4))
    for p, mean, lo, at in best:
        print("  P %2d  mean %.4f  best %.4f at %d" % (p, mean, lo, at))


def cycle(name: str, start: int, period: int, step: int = 1) -> None:
    """One cycle of PERIOD frames from START, a picture every STEP frames (2: a clip drawn on twos). The clip repeats
    its cycle to the frame: each picture is the median of all its repeats (the video's grain and ringing go)."""
    src = sorted((GEN / name / "all").glob("*.png"))
    out = GEN / name / "cycle"
    out.mkdir(exist_ok=True)
    for f in out.glob("*.png"):
        f.unlink()
    fr = []
    for j in range(period // step):
        idx = [i for i in range(start + j * step, len(src) - 1, period) for i in range(i, i + step)]
        idx = [i for i in idx if 2 <= i < len(src) - 1]
        stack = np.array([np.asarray(Image.open(src[i])).astype(np.float32) / 255.0 for i in idx])
        stack[..., :3] *= stack[..., 3:4]
        m = np.median(stack, axis=0)
        m[..., :3] = np.where(m[..., 3:4] > 1e-3, m[..., :3] / np.maximum(m[..., 3:4], 1e-3), 0.0)
        fr.append(np.clip(m, 0.0, 1.0))
    al = np.max([f[..., 3] for f in fr], axis=0) > 0.5
    ys, xs = np.nonzero(al)
    y0, y1, x0, x1 = max(ys.min() - 4, 0), ys.max() + 5, max(xs.min() - 4, 0), xs.max() + 5
    fr = [f[y0:y1, x0:x1] for f in fr]
    for i, f in enumerate(fr):
        save(f, out / ("%02d.png" % i))
    sheet(fr, GEN / name / "cycle.png", 6, 0.75)
    ims = []
    for f in fr:
        bg = np.zeros_like(f[..., :3]) + (0.62, 0.72, 0.86)
        ims.append(Image.fromarray(((bg * (1 - f[..., 3:4]) + f[..., :3] * f[..., 3:4]) * 255).astype(np.uint8)))
    ims[0].save(GEN / name / "cycle.gif", save_all=True, append_images=ims[1:], duration=round(1000 * step / 24), loop=0)
    print(name, "cycle:", len(fr), "pictures", fr[0].shape[1], "x", fr[0].shape[0])


if __name__ == "__main__":
    if sys.argv[1] == "frames":
        frames(sys.argv[2])
    else:
        cycle(sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5]) if len(sys.argv) > 5 else 1)
