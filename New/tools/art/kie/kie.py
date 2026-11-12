#!/usr/bin/env python3
"""A small kie.ai client for the character art (Nano Banana 2 stills). The key is read from ~/.config/kie/key and
never printed. Every task is logged with its credits in tools/art/gen/kie/ledger.jsonl (git-ignored, like the
pictures it makes: tools/art/gen/).

    python3 tools/art/kie/kie.py credits
    python3 tools/art/kie/kie.py gen NAME --prompt FILE.txt [--ref a.png b.png ...] [--aspect 16:9] [--res 2K]
            [--model nb2|sunburst|seedream] [--quality low|medium|high|xhigh|max] [--transparent]
        -> tools/art/gen/kie/NAME.png (one picture a call: be economical)
    python3 tools/art/kie/kie.py cutout NAME --first picture.png   (its subject on a transparent background)
    python3 tools/art/kie/kie.py video NAME --prompt FILE.txt --first a.png [--last a.png] [--seconds 3] [--res 1080p]
        -> tools/art/gen/kie/NAME.mp4 (Kling 4.0 keyframe-to-video: first = last frame for a cycle that loops)

Only the user's own art is sent as references (the game's sprites), never another game's pictures.
"""
import argparse
import base64
import json
import sys
import time
import urllib.request
from pathlib import Path

API = "https://api.kie.ai/api/v1"
UPLOAD = "https://kieai.redpandaai.co/api/file-base64-upload"
GEN = Path(__file__).resolve().parents[1] / "gen/kie"
KEY = (Path.home() / ".config/kie/key").read_text().strip()


def call(url, body=None):
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json",
                                          "User-Agent": "sprite-tool/1.0"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode())


def credits():
    return float(call(API + "/chat/credit")["data"])


def upload(path):
    p = Path(path)
    mime = "image/png" if p.suffix.lower() == ".png" else "image/jpeg"
    data = "data:%s;base64,%s" % (mime, base64.b64encode(p.read_bytes()).decode())
    r = call(UPLOAD, {"base64Data": data, "uploadPath": "sprites", "fileName": p.name})
    if r.get("code") != 200:
        raise SystemExit("upload failed: %s" % r.get("msg"))
    return r["data"]["downloadUrl"]


def run(name, model, inp, note):
    """Creates a task, waits for it, saves its first result as tools/art/gen/kie/NAME.<ext> and logs it."""
    GEN.mkdir(parents=True, exist_ok=True)
    r = call(API + "/jobs/createTask", {"model": model, "input": inp})
    if r.get("code") != 200:
        raise SystemExit("createTask failed: %s %s" % (r.get("code"), r.get("msg")))
    task = r["data"]["taskId"]
    with open(GEN / "tasks.jsonl", "a") as f:  # (before waiting: a clip paid for is never lost with the session)
        f.write(json.dumps({"time": time.strftime("%Y-%m-%d %H:%M"), "name": name, "model": model, "task": task}) + "\n")
    fetch(name, model, task, note)


def fetch(name, model, task, note):
    """Waits for a task and saves its first result (also for one started earlier: tasks.jsonl has the ids)."""
    t0 = time.time()
    while True:
        time.sleep(8)
        d = call(API + "/jobs/recordInfo?taskId=" + task).get("data") or {}
        state = d.get("state")
        if state == "success":
            out_url = json.loads(d["resultJson"])["resultUrls"][0]
            break
        if state == "fail":
            raise SystemExit("task failed: %s %s" % (d.get("failCode"), d.get("failMsg")))
        if time.time() - t0 > 1500:
            raise SystemExit("timed out (task %s)" % task)
    ext = out_url.split("?")[0].rsplit(".", 1)[-1].lower()
    out = GEN / (name + "." + (ext if ext in ("png", "jpg", "mp4", "mov", "webp") else "bin"))
    req = urllib.request.Request(out_url, headers={"User-Agent": "sprite-tool/1.0"})
    out.write_bytes(urllib.request.urlopen(req, timeout=300).read())
    used = d.get("creditsConsumed")
    with open(GEN / "ledger.jsonl", "a") as f:
        f.write(json.dumps({"time": time.strftime("%Y-%m-%d %H:%M"), "name": name, "model": model, "task": task,
                            "note": note, "credits": used, "seconds": round(time.time() - t0)}) + "\n")
    print("%s  (%s credits, %d s)" % (out, used, time.time() - t0))


## The image models (kie.ai's ids): nb2 = Nano Banana 2 (the sprite sheets' redraws); sunburst = GPT Image 2.6 Sunburst
## (the world's layers, 2026-11-12: true transparent backgrounds, 3:1 strips, up to 16 references; billed by the token:
## `quality` sets the price); seedream = Seedream 5.5 (cheap: 6.3 credits at 2K and 1.44 a reference).
def gen(name, prompt, refs, aspect, res, model="nb2", quality="medium", transparent=False):
    urls = [upload(r) for r in refs]
    note = {"res": res, "refs": [Path(x).name for x in refs]}
    bg = "transparent" if transparent else "opaque"
    if model == "sunburst":
        inp = {"prompt": prompt, "aspect_ratio": aspect, "resolution": res, "quality": quality, "background": bg,
               "output_format": "png"}
        if urls:
            inp["input_urls"] = urls
        run(name, "gpt-image-2-6/sunburst-" + ("image-to-image" if urls else "text-to-image"), inp,
            dict(note, quality=quality, background=bg))
    elif model == "seedream":
        inp = {"prompt": prompt, "aspect_ratio": aspect, "size": res, "output_format": "png", "background": bg,
               "nsfw_checker": False}
        if urls:
            inp["image_urls"] = urls
        run(name, "seedream/5-5-" + ("image-to-image" if urls else "text-to-image"), inp, dict(note, background=bg))
    else:
        run(name, "nano-banana-2", {"prompt": prompt, "image_input": urls, "aspect_ratio": aspect, "resolution": res,
                                    "output_format": "png"}, note)


def cutout(name, image):
    """A picture's subject cut from its background (Recraft: 1 credit): NAME.png with alpha."""
    run(name, "recraft/remove-background", {"image": upload(image)}, {"image": Path(image).name})


def video(name, prompt, first, last, seconds, res, model):
    """A clip from a first (and last) frame: Kling 4.0 keyframe-to-video by default."""
    inp = {"prompt": prompt, "duration": seconds, "resolution": res, "first_frame_url": upload(first)}
    if last:
        inp["last_frame_url"] = upload(last) if last != first else inp["first_frame_url"]
    run(name, model, inp, {"res": res, "seconds": seconds, "first": Path(first).name})


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["credits", "gen", "video", "fetch", "cutout"])
    ap.add_argument("--task")
    ap.add_argument("name", nargs="?")
    ap.add_argument("--prompt")
    ap.add_argument("--ref", nargs="*", default=[])
    ap.add_argument("--aspect", default="16:9")
    ap.add_argument("--res", default="2K")
    ap.add_argument("--first")
    ap.add_argument("--last")
    ap.add_argument("--seconds", type=int, default=3)
    ap.add_argument("--model", default="")
    ap.add_argument("--quality", default="medium")
    ap.add_argument("--transparent", action="store_true")
    a = ap.parse_args()
    if a.cmd == "credits":
        print(credits())
    elif a.cmd == "fetch":
        fetch(a.name, "", a.task, {})
    elif a.cmd == "cutout":
        cutout(a.name, a.first)
    elif a.cmd == "gen":
        gen(a.name, Path(a.prompt).read_text(), a.ref, a.aspect, a.res, a.model or "nb2", a.quality, a.transparent)
    else:
        video(a.name, Path(a.prompt).read_text(), a.first, a.last, a.seconds, a.res, a.model or "kling-4.0/keyframe-to-video")
