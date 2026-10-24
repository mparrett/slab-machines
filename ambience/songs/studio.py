"""Shared setup for the study songs: slabkit from the Slab checkout named by
SLAB_DIR, and render(), which saves a song and optionally bounces it."""
from pathlib import Path
import argparse
import json
import os
import subprocess
import sys

HERE = Path(__file__).resolve().parents[1]
if "SLAB_DIR" not in os.environ:
    sys.exit("set SLAB_DIR to a built Slab checkout that loads user machines (see README)")
SLAB = Path(os.environ["SLAB_DIR"]).expanduser().resolve()
sys.path.insert(0, str(SLAB / "tools"))
from slabkit import Song, fx  # noqa: E402,F401
from slabkit.analyze import analyze_wav  # noqa: E402


def render(song, name):
    """Save the song as songs/<name>.slab and, with --render, bounce it with
    stems and write a mix report beside it."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    package, out = HERE / f"songs/{name}.slab", HERE / f"songs/{name}"
    song.save(str(package))
    if args.render:
        out.mkdir(exist_ok=True)
        wav = out / f"{name}.wav"
        # cwd is the factory root: the machines' includes resolve there
        subprocess.run([str(SLAB / "zig-out/bin/slab"), str(package),
            "--render", str(wav), "--stems", str(out / "stems"), "--stem-kind", "tracks",
            "--tap", "fader", "--range", f"0:{song.sections[-1].end:g}", "--tail", "auto",
            "--bits", "24"], cwd=SLAB, check=True)
        sections = [(s.name, song.seconds_at(s.start), song.seconds_at(s.end)) for s in song.sections]
        report = {"mix": analyze_wav(str(wav), sections), "stems": {
            p.stem: analyze_wav(str(p)) for p in sorted((out / "stems").glob("*.wav"))}}
        (out / "mix-report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report["mix"], indent=2))
