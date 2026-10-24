"""Fire vs storm: shelter from a storm by a fire, made audible.

A blizzard bed of two wind layers [the full scene and a whistle] runs
throughout.  At 0:20 a fire catches close by, and as it grows the storm
muffles, drops and recedes into a hall: the shelter of the firelight.  At
0:48 the fire starves, its crackle thins and darkens, it gutters out, and
the storm comes back to full.  One beat is one second [60 BPM].

    SLAB_DIR=path/to/slab python3 ambience/songs/fire_vs_storm.py --render
"""
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
from slabkit import Song, fx  # noqa: E402
from slabkit.analyze import analyze_wav  # noqa: E402

PACKAGE = HERE / "songs/fire_vs_storm.slab"
OUT = HERE / "songs/fire_vs_storm"

LIT, FULL, STARVE, OUT_AT, END = 20, 28, 48, 54, 80   # seconds


def build_song():
    song = Song("Fire vs Storm", bpm=60)
    song.section("storm", 5)
    song.section("shelter", 7)
    song.section("gutter", 2)
    song.section("return", 6)

    storm = song.bus("STORM", fx=[
        fx("eq2", hs_hz=1500, p2_hz=3000, p2_q=0.7),
        fx("verb2", "big-hall", mix=0.0, decay=3.5, lowcut=200),
    ])
    low = song.track("STORM ROAR", "wind", output=storm, volume=0.8, params=dict(
        speed=0.45, swing=0.5, rate=0.03, gust=1.4, air=0.9, whistle=0.4, doors=0.4, leaves=0.3, width=0.9,
        atk=3, rel=4, gain=1.0))
    high = song.track("STORM WHISTLE", "wind", output=storm, volume=0.5, params=dict(
        speed=0.4, swing=0.6, rate=0.05, gust=1.2, air=0.15, whistle=0.9, doors=0.0, leaves=0.0, width=0.7,
        atk=4, rel=4, gain=0.6))
    fire = song.track("FIRE", "fire", volume=0.8, params=dict(
        crackle=30, snap=0.4, roar=0.4, hiss=0.4, flicker=0.5, tone=16000, width=0.6,
        atk=4, rel=5, gain=0.6))
    song.master(fx=[fx("limiter2", gain=6, ceil=-1)])

    low.clip(bars=END // 4).note("C4", 0, END - 4, vel=100)
    # a second whistle a fifth up enters with the gusts, for movement
    c = high.clip(bars=END // 4)
    c.note("C4", 2, END - 6, vel=100)
    c.note("G4", 30, 40, vel=100)
    fire.clip(bars=END // 4).note("C4", LIT, OUT_AT - LIT, vel=100)

    # The fire starves: fewer, smaller pops and a darker tone before it goes.
    fire.automate("crackle", (STARVE, 30), (OUT_AT, 3, "curve", 0.3))
    fire.automate("tone", (STARVE, 16000), (OUT_AT + 2, 2500, "curve", 0.3))

    # Shelter: as the fire grows, the storm loses its top, drops and goes
    # distant; it comes back as the fire dies.
    for target, open_, shut in (("fx0:eq-hs-db", 0.0, -16.0), ("fx0:eq-p2-db", 0.0, -9.0),
                                ("fx1:verb-mix", 0.0, 0.4), ("volume", 1.0, 0.45)):
        storm.automate(target, (LIT, open_), (FULL, shut, "curve", -0.3),
                       (STARVE + 2, shut), (OUT_AT + 4, open_, "curve", 0.3))
    return song


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    song = build_song()
    song.save(str(PACKAGE))
    if args.render:
        OUT.mkdir(exist_ok=True)
        wav = OUT / "fire_vs_storm.wav"
        # cwd is the factory root: the machines' includes resolve there
        subprocess.run([str(SLAB / "zig-out/bin/slab"), str(PACKAGE),
            "--render", str(wav), "--stems", str(OUT / "stems"), "--stem-kind", "tracks",
            "--tap", "fader", "--range", f"0:{song.sections[-1].end:g}", "--tail", "auto",
            "--bits", "24"], cwd=SLAB, check=True)
        sections = [(s.name, song.seconds_at(s.start), song.seconds_at(s.end)) for s in song.sections]
        report = {"mix": analyze_wav(str(wav), sections), "stems": {
            p.stem: analyze_wav(str(p)) for p in sorted((OUT / "stems").glob("*.wav"))}}
        (OUT / "mix-report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report["mix"], indent=2))


if __name__ == "__main__":
    main()
