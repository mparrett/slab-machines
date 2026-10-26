"""Fire walk: from the hearth out into the storm and back.  One beat is one
second [60 BPM]: at the hearth to 0:15, walking out to 0:45, in the cold
to 1:00, walking back to 1:30, at the hearth to 1:40.

A distance d, 0 at the hearth and 1 in the cold, drives every layer
through its own gradient: g = 1 - smoothstep[r0, r1, d].

    now         today's fire and storm, with one narrow gradient for
                everything: the storm switches on over a few steps.
    diffuse     the same sounds, each layer with its own soft gradient:
                the pops fade first, then the hiss, while the fire's level
                carries furthest; the storm opens gradually.
    suggestive  diffuse, with the deep fire [BED, softer pops] and a deep,
                wide, quieter storm [RUMBLE, little whistle].

    SLAB_DIR=path/to/slab python3 ambience/songs/fire_walk.py --way suggestive --render
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fire_fuel import FUELS  # noqa: E402
from studio import Song, fx, render  # noqa: E402

END = 100
# (beat, distance) at the corners of the walk
PATH = [(0, 0.0), (15, 0.0), (45, 1.0), (60, 1.0), (90, 0.0), (END, 0.0)]
NARROW = (0.3, 0.45)
# layer: (r0, r1) for the diffuse ways
# the storm opens from the first step, so it fills in as the fire recedes
DIFFUSE = {"pops": (0.0, 0.35), "hiss": (0.05, 0.5), "fire": (0.15, 1.0), "storm": (0.0, 0.7)}

FIRE = {
    "old": (dict(FUELS["softwood"], roar=0.4, hiss=0.4), 0.8),
    "deep": (dict(FUELS["softwood"], roar=0.4, hiss=0.4, bed=0.5, crackle=9, snap=0.22), 0.8 * 10 ** (-17 / 20)),
}
WIND = dict(speed=0.45, swing=0.5, rate=0.03, gust=1.4, width=0.9, atk=3, rel=4)
STORM = {
    # fire_vs_storm's two layers, as the game has them
    "literal": [("STORM ROAR", 0.8, dict(WIND, air=0.9, whistle=0.4, doors=0.4, leaves=0.3, gain=1.0)),
                ("STORM WHISTLE", 0.5, dict(WIND, speed=0.4, swing=0.6, rate=0.05, gust=1.2, air=0.15,
                                             whistle=0.9, doors=0.0, leaves=0.0, width=0.7, gain=0.6, seed=1))],
    # one deep layer, steadier, with a trace of whistle
    "deep": [("STORM", 0.1, dict(WIND, speed=0.35, gust=0.6, air=0.35, whistle=0.12, doors=0.0, leaves=0.1,
                                  width=1.0, rumble=0.6, gain=1.0))],
}
WAYS = {"now": ("old", "literal", False), "diffuse": ("old", "literal", True),
        "suggestive": ("deep", "deep", True)}


def smooth(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def distance(beat):
    for (b0, d0), (b1, d1) in zip(PATH, PATH[1:]):
        if b0 <= beat <= b1:
            return d0 + (d1 - d0) * (beat - b0) / (b1 - b0)
    return 0.0


def lane(track, target, radius, value):
    """Automate target with value(g), g the layer's gradient at each second."""
    track.automate(target, *[(b, value(1 - smooth(*radius, distance(b)))) for b in range(0, END + 1)])


def build_song(way):
    fire_kind, storm_kind, diffuse = WAYS[way]
    r = (lambda layer: DIFFUSE[layer]) if diffuse else (lambda layer: NARROW)
    song = Song(f"Fire Walk ({way})", bpm=60)
    song.section("hearth", 4)
    song.section("out", 7)
    song.section("cold", 4)
    song.section("back", 8)
    song.section("hearth again", 2)

    params, vol = FIRE[fire_kind]
    fire = song.track("FIRE", "fire", volume=vol, params=dict(
        flicker=0.5, tone=16000, width=0.6, atk=1.5, rel=2, gain=0.6, **params))
    fire.clip(bars=END // 4).note("C4", 0, END - 2, vel=100)
    snap, hiss = params["snap"], params["hiss"]
    lane(fire, "snap", r("pops"), lambda g: snap * g)
    lane(fire, "hiss", r("hiss"), lambda g: hiss * g)
    # the fire's level falls 30 dB and darkens over its own, widest gradient
    lane(fire, "volume", r("fire"), lambda g: vol * 10 ** (-30 * (1 - g) / 20))
    lane(fire, "tone", r("fire"), lambda g: 3000 * (16000 / 3000) ** g)

    storm = song.bus("STORM", fx=[fx("eq2", hs_hz=1500)])
    for name, v, p in STORM[storm_kind]:
        t = song.track(name, "wind", output=storm, volume=v, params=p)
        t.clip(bars=END // 4).note("C4", 0, END - 2, vel=100)
    # sheltered, the storm is 14 dB down and loses its top; it opens as the
    # fire's shelter fades.  The deep storm sits 4 dB under the literal one.
    top = 1.0 if storm_kind == "literal" else 10 ** (-4 / 20)
    lane(storm, "volume", r("storm"), lambda g: top * 10 ** (-14 * g / 20))
    lane(storm, "fx0:eq-hs-db", r("storm"), lambda g: -16.0 * g)
    song.master(fx=[fx("limiter2", gain=3, ceil=-1)])
    return song


if __name__ == "__main__":
    args = sys.argv
    i = args.index("--way")
    way = args.pop(i + 1)
    args.pop(i)
    render(build_song(way), f"fire_walk_{way}")
