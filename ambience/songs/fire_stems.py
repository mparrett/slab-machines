"""Fire stems: the chosen hearth fire and storm, held steady and split into
layers to loop independently, so they don't repeat together.

    FIRE BODY   bed, lapping and the flutter: BED 0.45, LAP 0.35, ROAR 0.4
    FIRE HISS   the steam and sap bursts: HISS 0.25
    FIRE POPS   the crackle: 9 a second, TICK 70 ms, SPREAD 0.4
    STORM       the deep storm with the whistle on its gust peaks

The fire layers each have their own seed and a small room; their levels
are the hearth's in fire_walk [thick, hiss -4, + lap + room], and the
storm's is its level in the cold.  Render with stems, then cut each stem
into a loop.

    SLAB_DIR=path/to/slab python3 ambience/songs/fire_stems.py --render
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fire_fuel import FUELS  # noqa: E402
from fire_walk import STORM, TRIM  # noqa: E402
from studio import Song, fx, render  # noqa: E402

END = 124
FIRE = dict(FUELS["softwood"], crackle=9, tick=70, spread=0.4, flicker=0.5, tone=16000, width=0.6,
            atk=1.5, rel=2, gain=0.6)
OFF = dict(snap=0.0, roar=0.0, hiss=0.0, bed=0.0, lap=0.0)
LAYERS = {
    "FIRE BODY": dict(FIRE, **dict(OFF, roar=0.4, bed=0.45, lap=0.35), seed=0),
    "FIRE HISS": dict(FIRE, **dict(OFF, hiss=0.25), seed=3),
    "FIRE POPS": dict(FIRE, **dict(OFF, snap=FUELS["softwood"]["snap"]), seed=5),
}


def build_song():
    song = Song("Fire Stems", bpm=60)
    song.section("steady", END // 4)
    for name, params in LAYERS.items():
        t = song.track(name, "fire", volume=0.8 * 10 ** (TRIM["lap-room"] / 20), params=params,
                       fx=[fx("verb2", "small-room", mix=0.2, lowcut=300)])
        t.clip(bars=END // 4).note("C4", 0, END, vel=100)
    (_, vol, params), = STORM["whistle"]
    t = song.track("STORM", "wind", volume=vol, params=params)
    t.clip(bars=END // 4).note("C4", 0, END, vel=100)
    return song


if __name__ == "__main__":
    render(build_song(), "fire_stems")
