"""Calm air: the storm's wind, calm, as a day and a night bed.  A bed of
slow even swells reads as the sea; here the swell [SWING] is small and the
wind is driven instead by a train of gusts at uneven times, each a quick
rise and a slower fall automated on SPEED, so the air, leaves and whistles
all follow it, and on the level, up to 10 dB for a full gust.  The veer ways split the wind into two narrow voices, one a
side, each with its own train, so a gust arrives from one side and then
the other and the wind seems to shift direction.

    day         one voice, about 10 gusts a minute
    day-veer    two voices, one a side, about 6 a minute each
    night-veer  day-veer slower, sparser and darker: 3 a minute each, fewer
                leaves, the top shelved down
    night-lull  night-veer near still between gusts, 2 a minute each

    SLAB_DIR=path/to/slab python3 ambience/songs/calm_air.py --way day-veer --render
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from studio import Song, fx, render  # noqa: E402

END = 72
DAY = dict(speed=0.18, swing=0.15, rate=0.03, gust=1.2, air=0.7, whistle=0.08, doors=0.0, leaves=0.2,
           width=0.9, rumble=0.05, atk=2, rel=3, gain=1.0)
NIGHT = dict(DAY, speed=0.12, rate=0.02, leaves=0.08, whistle=0.04)
VEER = [(-0.7, 1), (0.7, 2)]
# way: (voices as (pan, seed), params, gusts a minute, gust depth on SPEED, top shelf dB)
WAYS = {
    "day": ([(0.0, 0)], DAY, 10, 0.3, 0.0),
    "day-veer": (VEER, dict(DAY, width=0.3), 6, 0.3, 0.0),
    "night-veer": (VEER, dict(NIGHT, width=0.3), 3, 0.25, -9.0),
    "night-lull": (VEER, dict(NIGHT, width=0.3, speed=0.05), 2, 0.3, -9.0),
}


def gusts(seed, per_min, depth):
    """SPEED offsets every quarter second: gusts at random times, each rising
    in 0.5-1.5 s and falling over 1.5-4 s; most are small, a few large."""
    rng = random.Random(seed)
    t, events = rng.uniform(0, 60 / per_min), []
    while t < END:
        events.append((t, rng.uniform(0.5, 1.5), rng.uniform(1.5, 4.0), depth * (0.3 + 0.7 * rng.random() ** 2)))
        t += rng.expovariate(per_min / 60)
    out = []
    for i in range(END * 4 + 1):
        b, v = i / 4, 0.0
        for t0, rise, fall, a in events:
            u = b - t0
            if 0 <= u < rise:
                v += a * (u / rise) ** 2 * (3 - 2 * u / rise)
            elif u >= rise:
                v += a * 2.0 ** (-(u - rise) / (fall / 3))
        out.append((b, v))
    return out


def build_song(way):
    voices, params, per_min, depth, shelf = WAYS[way]
    song = Song(f"Calm Air ({way})", bpm=60)
    song.section("air", END // 4)
    air = song.bus("AIR", fx=[fx("eq2", hs_hz=1500, hs_db=shelf)])
    for i, (pan, seed) in enumerate(voices):
        vol = 0.35 / len(voices) ** 0.5
        t = song.track(f"AIR {i + 1}", "wind", output=air, volume=vol, pan=pan, params=dict(params, seed=seed))
        t.clip(bars=END // 4).note("C4", 0, END, vel=100)
        g = gusts(seed, per_min, depth)
        t.automate("speed", *[(b, min(1.0, params["speed"] + v)) for b, v in g])
        t.automate("volume", *[(b, vol * 10 ** (min(10.0, 10 * v / depth) / 20)) for b, v in g])
    return song


if __name__ == "__main__":
    args = sys.argv
    i = args.index("--way")
    way = args.pop(i + 1)
    args.pop(i)
    render(build_song(way), f"calm_air_{way}")
