"""Small edits of the Godot project files, shared by tools/firebase.py and tools/extras.py."""
import os
import re
import shutil
import tempfile
import urllib.request
import zipfile
from pathlib import Path

NEW = Path(__file__).resolve().parents[1]


def read_config(path: Path = NEW / "config/game_config.cfg") -> dict:
    """Reads a Godot ConfigFile with plain values (true/false, numbers, "strings") as {section: {key: value}}."""
    data: dict = {}
    section = None
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("["):
            section = data.setdefault(line.strip("[]"), {})
        elif "=" in line and section is not None:
            key, value = (part.strip() for part in line.split("=", 1))
            if value in ("true", "false"):
                section[key] = value == "true"
            elif value.startswith('"'):
                section[key] = value[1:-1]
            else:
                section[key] = value
    return data


def set_editor_plugin(cfg: str, on: bool) -> None:
    """Adds or removes "res://addons/<name>/plugin.cfg" in Project Settings > Plugins."""
    path = NEW / "project.godot"
    text = path.read_text()
    match = re.search(r'^enabled=PackedStringArray\((.*)\)$', text, re.M)
    plugins = [p.strip() for p in match.group(1).split(",") if p.strip()] if match else []
    entry = f'"{cfg}"'
    if on and entry not in plugins:
        plugins.append(entry)
    if not on and entry in plugins:
        plugins.remove(entry)
    text = text.replace(match.group(0), f"enabled=PackedStringArray({', '.join(plugins)})")
    path.write_text(text)


def set_autoload(name: str, script: str | None) -> None:
    """Adds an autoload ("*res://..." path), or removes it when script is None."""
    path = NEW / "project.godot"
    text = re.sub(rf'^{re.escape(name)}=.*\n', "", path.read_text(), flags=re.M)
    if script:
        text = re.sub(r'^(\[autoload\]\n\n(?:.+\n)*)', lambda m: m.group(1) + f'{name}="*{script}"\n', text, count=1, flags=re.M)
    path.write_text(text)


def _preset_blocks(text: str, platform: str):
    """Yields (start, end) of the [preset.N.options] blocks of a platform, last first."""
    spans = []
    for m in re.finditer(r'^\[preset\.(\d+)\]$(.*?)(?=^\[preset\.\d+\]$|\Z)', text, re.M | re.S):
        if f'platform="{platform}"' not in m.group(2):
            continue
        section = f"[preset.{m.group(1)}.options]"
        start = text.index(section)
        end_match = re.search(r'^\[', text[start + len(section):], re.M)
        end = start + len(section) + (end_match.start() if end_match else len(text) - start - len(section))
        spans.append((start, end))
    return reversed(spans)


def set_preset_options(platform: str, values: dict) -> None:
    """Sets options in every export preset of a platform (adds them when missing, removes them for None)."""
    path = NEW / "export_presets.cfg"
    text = path.read_text()
    for start, end in _preset_blocks(text, platform):
        block = text[start:end]
        for key, value in values.items():
            if value is None:
                block = re.sub(rf"^{re.escape(key)}=.*\n", "", block, flags=re.M)
                continue
            line = f"{key}={value}"
            block, n = re.subn(rf"^{re.escape(key)}=.*$", lambda _m: line, block, flags=re.M)
            if n == 0:
                block = block.rstrip("\n") + "\n" + line + "\n\n"
        text = text[:start] + block + text[end:]
    path.write_text(text)


def set_exclude(platform: str, pattern: str, on: bool) -> None:
    """Adds or removes a pattern in the "Filters to exclude" of every preset of a platform."""
    path = NEW / "export_presets.cfg"
    text = path.read_text()
    out = []
    for preset in re.split(r'(?=^\[preset\.\d+\]$)', text, flags=re.M):
        if f'platform="{platform}"' in preset:
            def edit(m: re.Match) -> str:
                items = [p.strip() for p in m.group(1).split(",") if p.strip()]
                if on and pattern not in items:
                    items.append(pattern)
                if not on and pattern in items:
                    items.remove(pattern)
                return f'exclude_filter="{", ".join(items)}"'
            preset = re.sub(r'^exclude_filter="(.*)"$', edit, preset, count=1, flags=re.M)
        out.append(preset)
    path.write_text("".join(out))


def install_from_zip(url: str, folders: dict[str, Path], label: str) -> None:
    """Downloads a release zip and copies some of its folders ({path in zip: destination})."""
    if all(dest.exists() for dest in folders.values()):
        return
    print(f"Downloading {label}...")
    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(tmp, "plugin.zip")
        urllib.request.urlretrieve(url, archive)
        extract(archive, Path(tmp, "x"))
        for inner, dest in folders.items():
            if dest.exists():
                continue
            src = Path(tmp, "x", inner)
            if not src.is_dir():
                raise SystemExit(f"{inner} is missing from {url}")
            shutil.copytree(src, dest, symlinks=True)


def extract(archive: Path, root: Path) -> None:
    """Unzips like `unzip`: keeps the symbolic links that macOS frameworks need (Versions/Current),
    refusing any link or file that would land outside root."""
    root = root.resolve()
    with zipfile.ZipFile(archive) as z:
        for info in z.infolist():
            dest = (root / info.filename).resolve()
            if not dest.is_relative_to(root):
                raise SystemExit(f"Unsafe path in {archive.name}: {info.filename}")
            if (info.external_attr >> 16) & 0o170000 == 0o120000:
                target = z.read(info).decode()
                if os.path.isabs(target) or not (dest.parent / target).resolve().is_relative_to(root):
                    raise SystemExit(f"Unsafe link in {archive.name}: {info.filename} -> {target}")
                dest.parent.mkdir(parents=True, exist_ok=True)
                os.symlink(target, dest)
            elif info.is_dir():
                dest.mkdir(parents=True, exist_ok=True)
            else:
                dest.parent.mkdir(parents=True, exist_ok=True)
                with z.open(info) as src, open(dest, "wb") as out:
                    shutil.copyfileobj(src, out)
                mode = (info.external_attr >> 16) & 0o777
                if mode:
                    dest.chmod(mode)


def remove(*paths: Path) -> None:
    for path in paths:
        if path.is_dir():
            shutil.rmtree(path)
        uid = path.with_name(path.name + ".uid")
        if uid.exists():
            uid.unlink()
