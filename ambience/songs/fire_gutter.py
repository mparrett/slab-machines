"""Fire gutter: one fire burning, starving and going out, three ways.  One
beat is one second [60 BPM]; the fire burns steady to 0:12, then dies.

    now      fire_vs_storm's gutter, sped to the same scale: the crackle
             thins and the tone darkens while the roar and hiss stay full,
             then the note ends.  Sparse, dark ticks over a full flame
             read as rustling, not a dying fire.
    starve   the flame dies first: the roar sinks with one last flare, the
             hiss breaks into spits and stops, and the pops grow fewer but
             stay bright.  An ember bed then ticks on and cools.
    tick     starve, with TICK shortening the pops as the wood runs out,
             so the last ones are sharp and dry.

    SLAB_DIR=path/to/slab python3 ambience/songs/fire_gutter.py --way starve --render
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio import Song, render  # noqa: E402

STARVE, OUT_AT, END = 12, 36, 56   # seconds
FIRE = dict(crackle=30, snap=0.4, roar=0.4, hiss=0.4, flicker=0.5, tone=16000, width=0.6,
            atk=1.5, rel=4, gain=0.6)


def build_song(way):
    song = Song(f"Fire Gutter ({way})", bpm=60)
    song.section("burning", 3)
    song.section("gutter", 6)
    song.section("embers", 5)
    fire = song.track("FIRE", "fire", volume=0.8, params=FIRE)
    if way == "now":
        out = STARVE + 6
        fire.clip(bars=END // 4).note("C4", 0, out, vel=100)
        fire.automate("crackle", (STARVE, 30), (out, 3, "curve", 0.3))
        fire.automate("tone", (STARVE, 16000), (out + 2, 2500, "curve", 0.3))
        return song

    fire.clip(bars=END // 4).note("C4", 0, OUT_AT, vel=100)
    # The roar sinks unevenly, with one last flare before it fails.
    fire.automate("roar", (STARVE, 0.4), (18, 0.3), (21, 0.45), (23, 0.25), (34, 0.02, "curve", 0.4))
    fire.automate("flicker", (STARVE, 0.5), (24, 0.9), (34, 0.3))
    # The hiss breaks into a few spits, then stops.
    fire.automate("hiss", (STARVE, 0.4), (20, 0.12), (24, 0.3), (26, 0.05), (31, 0.0))
    # Fewer pops, but each stays bright and a little louder against the quiet.
    fire.automate("crackle", (STARVE, 30), (24, 12), (34, 3, "curve", 0.3))
    fire.automate("snap", (STARVE, 0.4), (34, 0.55))
    fire.automate("tone", (STARVE, 16000), (34, 8000))
    if way == "tick":
        fire.automate("tick", (STARVE, 30), (34, 8, "curve", 0.3))

    # Embers: no flame, rare quiet ticks as the bed cools.
    embers = song.track("EMBERS", "fire", volume=0.8, params=dict(
        crackle=1.5, snap=0.35, roar=0.0, hiss=0.02, flicker=0.2, tone=12000, width=0.8,
        atk=3, rel=3, gain=0.5, seed=1, tick=4 if way == "tick" else 30))
    embers.clip(bars=END // 4).note("C4", OUT_AT - 4, END - OUT_AT, vel=100)
    embers.automate("crackle", (OUT_AT, 1.5), (END - 4, 0.5))
    return song


if __name__ == "__main__":
    way = "starve"
    if "--way" in sys.argv:
        i = sys.argv.index("--way")
        way = sys.argv.pop(i + 1)
        sys.argv.pop(i)
    render(build_song(way), f"fire_gutter_{way}")
