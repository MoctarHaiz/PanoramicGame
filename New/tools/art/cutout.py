#!/usr/bin/env python3
"""Cuts a character out of a plain black or white background (AI segmentation + edge un-mixing).

The new 3D character renders come on black or white. Their black trousers and hair touch a black
background, so a colour key can't separate them: a segmentation network (BiRefNet, or IS-Net)
finds the character, then edge pixels are un-mixed from the background colour so the cut-out has
no dark or light fringe.

Usage: python cutout.py MODEL.onnx INPUT OUTPUT.png
Needs: onnxruntime, numpy, pillow.  Models: https://github.com/danielgatis/rembg/releases/tag/v0.0.0
(BiRefNet-general-epoch_244.onnx or isnet-general-use.onnx)
"""
import sys

import numpy as np
import onnxruntime as ort
from PIL import Image


def segment(model_path: str, rgb: Image.Image) -> np.ndarray:
    """Foreground probability (0..1) at the image size."""
    session = ort.InferenceSession(model_path, providers=["CPUExecutionProvider"])
    size = session.get_inputs()[0].shape[2:]
    size = (1024, 1024) if not isinstance(size[0], int) else (size[1], size[0])
    x = np.asarray(rgb.resize(size, Image.BICUBIC)).astype(np.float32) / 255.0
    if "isnet" in model_path.lower():  # as rembg: ImageNet means, no scaling
        x = x / max(float(x.max()), 1e-6) - np.array([0.485, 0.456, 0.406])
    else:  # BiRefNet: ImageNet statistics
        x = (x - np.array([0.485, 0.456, 0.406])) / np.array([0.229, 0.224, 0.225])
    x = x.transpose(2, 0, 1)[None].astype(np.float32)
    out = session.run(None, {session.get_inputs()[0].name: x})[0][0, 0]
    if "isnet" in model_path.lower():  # as rembg: stretched to 0..1
        out = (out - out.min()) / max(float(out.max() - out.min()), 1e-6)
    elif out.min() < 0 or out.max() > 1:  # logits
        out = 1 / (1 + np.exp(-out))
    mask = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "L").resize(rgb.size, Image.BICUBIC)
    return np.asarray(mask).astype(np.float32) / 255.0


def box_blur(a: np.ndarray, r: int) -> np.ndarray:
    """Mean over a (2r+1) square, for float arrays."""
    p = np.pad(a, ((r + 1, r), (r + 1, r)), mode="edge").cumsum(0).cumsum(1)
    n = 2 * r + 1
    return (p[n:, n:] - p[:-n, n:] - p[n:, :-n] + p[:-n, :-n]) / (n * n)


def unmix(rgb: np.ndarray, alpha: np.ndarray, bg: np.ndarray) -> np.ndarray:
    """Colour of the character itself on edge pixels: observed = a*F + (1-a)*bg."""
    a = alpha[..., None]
    f = (rgb - (1 - a) * bg) / np.maximum(a, 1e-3)
    f = np.clip(f, 0, 255)
    # Where alpha is tiny the estimate is noise: take the colour of nearby solid pixels instead.
    solid = alpha > 0.9
    known = np.where(solid[..., None], rgb, 0).astype(np.float32)
    weight = solid.astype(np.float32)
    blur_c = np.stack([box_blur(known[..., c], 6) for c in range(3)], 2)
    blur_w = box_blur(weight, 6)[..., None]
    nearby = np.where(blur_w > 1e-3, blur_c / np.maximum(blur_w, 1e-3), f)
    t = np.clip((alpha - 0.15) / 0.5, 0, 1)[..., None]  # trust the un-mix only where alpha is solid enough
    return np.where(solid[..., None], rgb, f * t + nearby * (1 - t))


def main(model, src, dst):
    im = Image.open(src).convert("RGB")
    rgb = np.asarray(im).astype(np.float32)
    corners = np.concatenate([rgb[:8, :8].reshape(-1, 3), rgb[:8, -8:].reshape(-1, 3),
                              rgb[-8:, :8].reshape(-1, 3), rgb[-8:, -8:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    alpha = segment(model, im)
    # Firm up the matte: the network is a little soft; keep a thin anti-aliased edge.
    alpha = np.clip((alpha - 0.08) / 0.84, 0, 1)
    colour = unmix(rgb, alpha, bg)
    out = np.dstack([np.clip(colour + 0.5, 0, 255), alpha * 255 + 0.5]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")
    img = img.crop(img.getbbox())
    img.save(dst)
    print(f"{src} -> {dst} {img.size} (background {bg.round().tolist()})")


if __name__ == "__main__":
    main(*sys.argv[1:4])
