"""Shimmer study: the first piece of the texture kit [texture/shimmer], on a
cold bed.  A string pad holds an open D chord [D, A, E: no third] for
three bars and lets go for three, four times:

    hall      the factory verb2 hall, DECAY 8 s, for reference
    bloom     SHIMMER octave-bloom: the tail climbs an octave each pass
    frost     SHIMMER frost-choir: higher, slower, almost endless
    freeze    frost-choir again, FREEZE engaged a bar before the chord
              lets go, so the bed holds after the strings stop; it lets
              go at the end of the pass and fades over DECAY 12 s

D, 3/4 at 72 BPM; the hall and bloom passes are 15 s, frost and freeze
20 s, and the hall sits 5 dB down so the passes match in loudness.

    SLAB_DIR=path/to/slab python3 ambience/songs/shimmer_study.py --render
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio import Song, fx, render  # noqa: E402

CHORD = ["D3", "A3", "E4", "A4"]
PAD = "vsco-strings/cello-section-susvib"


def build_song():
    song = Song("Shimmer Study", bpm=72, key="D dorian", meter=(3, 4))
    parts = [song.section(n, bars) for n, bars in
             (("hall", 6), ("bloom", 6), ("frost", 8), ("freeze", 8))]
    inserts = [
        fx("verb2", "big-hall", **{"verb-decay": 8.0, "verb-mix": 0.4}),
        fx("shimmer", "octave-bloom"),
        fx("shimmer", "frost-choir"),
        fx("shimmer", "frost-choir", **{"shim-decay": 12.0}),
    ]
    volumes = [0.34, 0.6, 0.6, 0.6]
    tracks = []
    for sec, ins, vol in zip(parts, inserts, volumes):
        t = song.track(sec.name.upper(), "sampler", PAD, volume=vol, fx=[ins],
                       params=dict(atk=1.5, rel=2.5))
        t.clip(sec).chord(CHORD, 0, 9, vel=80)
        tracks.append(t)
    freeze = parts[3]
    tracks[3].automate("fx0:shim-freeze", (freeze.start, 0, "hold"), (freeze.start + 6, 1, "hold"),
                       (freeze.end, 0, "hold"))
    song.master(fx=[fx("limiter2", gain=3, ceil=-1)])
    return song


if __name__ == "__main__":
    render(build_song(), "shimmer_study")
