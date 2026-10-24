"""Drift study: slow random modulation [drift.py] on the texture kit.  The
same two minutes twice: CLOUD drift into SHIMMER frost-choir on three
chords sustained for 16 bars each, once with every knob still and once
drifting:

    cloud   SCAN wanders forward and back through the source (a random
            walk), with SPRAY, grain SIZE and WIDTH moving under it
    shimmer TONE and AMOUNT move slowly, so the bloom brightens, dulls,
            swells and thins

Each path is seeded, so a render is repeatable.  D, 3/4 at 72 BPM.

    SLAB_DIR=path/to/slab python3 ambience/songs/drift_study.py --static --render
    SLAB_DIR=path/to/slab python3 ambience/songs/drift_study.py --drift --render
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drift import drift  # noqa: E402
from studio import Song, fx, render  # noqa: E402

CHORDS = [["D3", "A3", "E4", "A4"], ["C3", "G3", "D4", "E4"], ["G2", "D3", "A3", "B3"]]


def build_song(drifting):
    song = Song("Drift Study", bpm=72, key="D dorian", meter=(3, 4))
    sec = song.section("bed", 48)
    pad = song.track("CLOUD", "cloud", "drift", volume=0.75,
                     fx=[fx("shimmer", "frost-choir", **{"shim-decay": 12.0})])
    c = pad.clip(sec)
    for i, chord in enumerate(CHORDS):
        c.chord(chord, i * 48, 45, vel=90)
    if drifting:
        end = sec.end
        drift(pad, "cloud-scan", 0, end, -0.2, 0.2, period=10, seed=1)
        drift(pad, "cloud-spray", 0, end, 0.05, 0.5, period=14, seed=2)
        drift(pad, "cloud-grain", 0, end, 80, 400, period=18, seed=3, log=True)
        drift(pad, "cloud-width", 0, end, 0.3, 1.0, period=22, seed=4)
        drift(pad, "fx0:shim-tone", 0, end, 2500, 10000, period=26, seed=5, log=True)
        drift(pad, "fx0:shim-amount", 0, end, 0.3, 0.8, period=30, seed=6)
    song.master(fx=[fx("limiter2", gain=3, ceil=-1)])
    return song


if __name__ == "__main__":
    variants = [v for v in ("static", "drift") if f"--{v}" in sys.argv]
    if len(variants) != 1:
        sys.exit("pick one of --static, --drift")
    sys.argv.remove(f"--{variants[0]}")
    render(build_song(variants[0] == "drift"), f"drift_{variants[0]}")
