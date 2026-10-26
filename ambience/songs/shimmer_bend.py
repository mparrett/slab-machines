"""Shimmer bend: the shimmer's BEND knob gliding a tail across intervals.
The open D chord from the shimmer study [D, A, E, A] holds for three bars
through SHIMMER octave-bloom with AMOUNT up; BEND then rises from +12 to
+19 over six bars and falls to +5 over the next six, while the chord
plays again at the turn.

    0:00   chord, the tail climbing in octaves
    0:10   BEND rising: the tail slides up to an octave and a fifth
    0:25   chord again; BEND falling to a fourth
    0:40   BEND gliding back to 0 by 0:42.5; the tail fades

D, 3/4 at 72 BPM.

    SLAB_DIR=path/to/slab python3 ambience/songs/shimmer_bend.py --render
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio import Song, fx, render  # noqa: E402

CHORD = ["D3", "A3", "E4", "A4"]
PAD = "vsco-strings/cello-section-susvib"


def build_song():
    song = Song("Shimmer Bend", bpm=72, key="D dorian", meter=(3, 4))
    glide = song.section("glide", 20)
    pad = song.track("PAD", "sampler", PAD, volume=0.6,
                     fx=[fx("shimmer", "octave-bloom", **{"shim-amount": 0.8, "shim-decay": 12.0})],
                     params=dict(atk=1.5, rel=2.5))
    c = pad.clip(glide)
    c.chord(CHORD, 0, 9, vel=80)
    c.chord(CHORD, 30, 9, vel=80)
    b = glide.start
    pad.automate("fx0:shim-bend", (b, 0, "hold"), (b + 12, 0, "linear"),
                 (b + 30, 7, "linear"), (b + 48, -7, "linear"), (b + 51, 0, "hold"))
    song.master(fx=[fx("limiter2", gain=3, ceil=-1)])
    return song


if __name__ == "__main__":
    render(build_song(), "shimmer_bend")
