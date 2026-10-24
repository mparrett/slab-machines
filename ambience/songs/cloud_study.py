"""Cloud study: the texture kit's grain cloud [texture/cloud] on the open D
chord from the shimmer study [D, A, E, A], held six bars and let go for
two, five times:

    pad       the VSCO violin-section sampler, for reference
    drift     CLOUD drift: the same violins, grains wandering slowly
              through the file
    glitter   CLOUD glitter: short grains an octave up, scattered wide
    murmur    CLOUD murmur: an octave down, half the grains backwards
    kit       CLOUD drift into SHIMMER frost-choir: both pieces together

The cloud's default source is a cut of the same violin-section sample the
pad plays, so pad and drift differ only in the graining.  Each pass goes
through a small verb2 room, except the kit, whose shimmer is the space.
D, 3/4 at 72 BPM, 20 s a pass.

    SLAB_DIR=path/to/slab python3 ambience/songs/cloud_study.py --render
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio import Song, fx, render  # noqa: E402

CHORD = ["D3", "A3", "E4", "A4"]


def build_song():
    song = Song("Cloud Study", bpm=72, key="D dorian", meter=(3, 4))
    names = ("pad", "drift", "glitter", "murmur", "kit")
    parts = [song.section(n, 8) for n in names]
    room = fx("verb2", "big-hall", **{"verb-decay": 3.0, "verb-mix": 0.25})
    voices = [
        ("sampler", "vsco-strings/violin-section-susvib", [room], dict(atk=1.5, rel=2.5)),
        ("cloud", "drift", [room], None),
        ("cloud", "glitter", [room], None),
        ("cloud", "murmur", [room], None),
        ("cloud", "drift", [fx("shimmer", "frost-choir", **{"shim-decay": 12.0})], None),
    ]
    volumes = [0.6, 0.6, 0.6, 0.75, 0.75]   # murmur and the kit 2 dB up, to match
    for sec, (machine, preset, inserts, params), vol in zip(parts, voices, volumes):
        t = song.track(sec.name.upper(), machine, preset, volume=vol, fx=inserts, params=params)
        t.clip(sec).chord(CHORD, 0, 18, vel=90)
    song.master(fx=[fx("limiter2", gain=3, ceil=-1)])
    return song


if __name__ == "__main__":
    render(build_song(), "cloud_study")
