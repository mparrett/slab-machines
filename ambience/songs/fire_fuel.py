"""Fire fuel: the same fire on five fuels, told apart only by the crackle:
CRACKLE, SNAP, TICK, CLUMP and SPREAD.  Roar, hiss, flicker and tone stay
fixed, so any difference is the pops.  30 s of steady fire each.  What each
should evoke, written before listening:

    reference  the fire as fire_vs_storm has it: an even patter.
    kindling   twigs catching: quick, dry, chattering bursts; busy, young.
    softwood   pine: steady with now and then a loud resin split; lively.
    hardwood   oak: settled, sparse, single pops; a fire that will last.
    peat       almost no pops, a low patient smoulder; old, quiet.

--bed adds a quiet storm under it, to judge the fire as ambience.

    SLAB_DIR=path/to/slab python3 ambience/songs/fire_fuel.py --fuel kindling [--bed] --render
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio import Song, render  # noqa: E402

FUELS = {
    "reference": dict(crackle=30, snap=0.4, tick=30, clump=0.0, spread=0.0),
    "kindling": dict(crackle=70, snap=0.4, tick=5, clump=0.85, spread=0.25),
    "softwood": dict(crackle=18, snap=0.45, tick=14, clump=0.35, spread=0.9),
    "hardwood": dict(crackle=7, snap=0.4, tick=18, clump=0.05, spread=0.35),
    "peat": dict(crackle=1.5, snap=0.25, tick=30, clump=0.0, spread=0.1),
}
END = 32


def build_song(fuel, bed):
    song = Song(f"Fire Fuel ({fuel})", bpm=60)
    song.section(fuel, END // 4)
    fire = song.track("FIRE", "fire", volume=0.8, params=dict(
        roar=0.4, hiss=0.4, flicker=0.5, tone=16000, width=0.6, atk=1.5, rel=2, gain=0.6, **FUELS[fuel]))
    fire.clip(bars=END // 4).note("C4", 0, END - 2, vel=100)
    if bed:
        storm = song.track("STORM", "wind", volume=0.25, params=dict(
            speed=0.4, swing=0.5, rate=0.03, gust=1.2, air=0.6, whistle=0.3, doors=0.2, leaves=0.2, width=0.9,
            atk=2, rel=2, gain=0.6, seed=2))
        storm.clip(bars=END // 4).note("C4", 0, END - 2, vel=100)
    return song


if __name__ == "__main__":
    args = sys.argv
    bed = "--bed" in args
    if bed:
        args.remove("--bed")
    i = args.index("--fuel")
    fuel = args.pop(i + 1)
    args.pop(i)
    render(build_song(fuel, bed), f"fire_fuel_{fuel}{'_bed' if bed else ''}")
