"""Modal study: the foley kit's modal machine [foley/modal] through each of
its presets, 8 s apiece, in a small room:

    wood-knock, stone-tap, iron-plate, ice-ring, hide-drum
                  five hits each, soft to hard, on two sizes of the body
    dropped-pan   one drop, left to bounce and rattle
    cart-roll, metal-scrape, door-creak, glass-squeal
                  held for 5 s: rolling, scraping and stick-slip

60 BPM, so a beat is a second.

    SLAB_DIR=path/to/slab python3 ambience/songs/modal_study.py --render
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio import Song, fx, render  # noqa: E402

STRIKES = ["wood-knock", "stone-tap", "iron-plate", "ice-ring", "hide-drum"]
HELD = ["cart-roll", "metal-scrape", "door-creak", "glass-squeal"]
HITS = [("C4", 0.0, 50), ("C4", 1.0, 80), ("G3", 2.0, 100), ("C4", 2.5, 70), ("G3", 4.0, 120)]


def build_song():
    song = Song("Modal Study", bpm=60, meter=(4, 4))
    room = song.bus("ROOM", fx=[fx("verb2", "big-hall", **{"verb-decay": 1.2, "verb-mix": 1.0})])
    for name in STRIKES + ["dropped-pan"] + HELD:
        sec = song.section(name, 2)
        t = song.track(name.upper(), "modal", name, volume=0.7)
        c = t.clip(sec)
        if name in STRIKES:
            for note, at, vel in HITS:
                c.note(note, at, 0.25, vel=vel)
        elif name == "dropped-pan":
            c.note("C4", 0.5, 0.25, vel=110)
        else:
            c.note("C4", 0.5, 5.0, vel=100)
        t.send(room, -14)
    song.master(fx=[fx("limiter2", gain=0, ceil=-1)])
    return song


if __name__ == "__main__":
    render(build_song(), "modal_study")
