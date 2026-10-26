"""Fire bed: softwood with the low body under it, and the pops brought down,
towards the deep burning the reference fires have.  30 s of steady fire
each.  --bed adds a quiet storm under it.

    softwood   the fuel study's softwood, with the pop and hiss fixes
    bed        + BED 0.5: a low body that breathes
    bed, soft  + the pops 6 dB down and half as many [9 a second]
    deep       + BED 1.0 and the softer pops: the bed leads

    SLAB_DIR=path/to/slab python3 ambience/songs/fire_bed.py --way deep [--bed] --render
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fire_fuel import FUELS  # noqa: E402
from studio import Song, render  # noqa: E402

SOFT = dict(crackle=9, snap=0.22)
# way: (fire params, track trim in dB to land near softwood's loudness, as
# the bed carries most of the level)
WAYS = {
    "softwood": (dict(FUELS["softwood"]), 0.0),
    "bed": (dict(FUELS["softwood"], bed=0.5), -13.0),
    "bed-soft": (dict(FUELS["softwood"], bed=0.5, **SOFT), -13.0),
    "deep": (dict(FUELS["softwood"], bed=1.0, **SOFT), -19.0),
}
END = 32


def build_song(way, storm_bed):
    song = Song(f"Fire Bed ({way})", bpm=60)
    song.section(way, END // 4)
    params, trim = WAYS[way]
    fire = song.track("FIRE", "fire", volume=0.8 * 10 ** (trim / 20), params=dict(
        roar=0.4, hiss=0.4, flicker=0.5, tone=16000, width=0.6, atk=1.5, rel=2, gain=0.6, **params))
    fire.clip(bars=END // 4).note("C4", 0, END - 2, vel=100)
    if storm_bed:
        storm = song.track("STORM", "wind", volume=0.25, params=dict(
            speed=0.4, swing=0.5, rate=0.03, gust=1.2, air=0.6, whistle=0.3, doors=0.2, leaves=0.2, width=0.9,
            atk=2, rel=2, gain=0.6, seed=2))
        storm.clip(bars=END // 4).note("C4", 0, END - 2, vel=100)
    return song


if __name__ == "__main__":
    args = sys.argv
    storm_bed = "--bed" in args
    if storm_bed:
        args.remove("--bed")
    i = args.index("--way")
    way = args.pop(i + 1)
    args.pop(i)
    render(build_song(way, storm_bed), f"fire_bed_{way}{'_storm' if storm_bed else ''}")
