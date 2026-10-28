"""Bubbles study: the foley kit's bubbles machine [foley/bubbles] through
each of its presets, 8 s apiece: drip, trickle, pour, boil, mud.  Each is
held 6 s on C4, where SIZE is as the preset sets it; pour then glides
SIZE down, as a vessel filling raises the pitch.

    SLAB_DIR=path/to/slab python3 ambience/songs/bubbles_study.py --render
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio import Song, fx, render  # noqa: E402

PRESETS = ["drip", "trickle", "pour", "boil", "mud"]


def build_song():
    song = Song("Bubbles Study", bpm=60, meter=(4, 4))
    room = song.bus("ROOM", fx=[fx("verb2", "big-hall", **{"verb-decay": 1.0, "verb-mix": 1.0})])
    for name in PRESETS:
        sec = song.section(name, 2)
        t = song.track(name.upper(), "bubbles", name, volume=0.7)
        c = t.clip(sec).note("C4", 0, 6, vel=100)
        if name == "pour":
            c.ramp("bb-size", 1, 6, 2.0, 0.8)
        t.send(room, -16)
    song.master(fx=[fx("limiter2", gain=0, ceil=-1)])
    return song


if __name__ == "__main__":
    render(build_song(), "bubbles_study")
