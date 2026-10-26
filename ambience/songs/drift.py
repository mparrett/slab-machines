"""Slow random modulation as automation.  Slab has no modulation yet (the
mod matrix in Slab's docs/08 is a design), so drift() writes a seeded,
smooth random path into an automation lane: the bed keeps moving, and the
path is ordinary automation, visible and editable in the app.

    drift(pad, "cloud-scan", 0, 96, -0.15, 0.15, period=12, seed=1)
    drift(pad, "fx0:shim-tone", 0, 96, 2500, 9000, period=24, log=True)

The path passes through random values in [lo, hi], about one every
`period` beats (each gap jittered so it never sounds periodic), joined by
smoothstep curves, which stay inside [lo, hi].  `log` draws and joins the
values on a log scale, for Hz and ms.  Automation is per track, so every
voice of the machine follows the same path.
"""
import math
import random


def drift_points(start, end, lo, hi, period, seed=0, log=False, jitter=0.4, steps=6):
    """The lane points for drift(): (beat, value) pairs from start to end."""
    if end <= start:
        raise ValueError("drift: end must be after start")
    if period <= 0 or not 0 <= jitter < 1 or steps < 1:
        raise ValueError("drift: needs period > 0, 0 <= jitter < 1 and steps >= 1")
    if log and lo <= 0:
        raise ValueError("drift: log needs lo > 0")
    rng = random.Random(seed)
    fwd, back = (math.log, math.exp) if log else (float, float)
    a, b = fwd(lo), fwd(hi)
    knots = [(start, rng.uniform(a, b))]
    while knots[-1][0] < end:
        knots.append((knots[-1][0] + period * rng.uniform(1 - jitter, 1 + jitter), rng.uniform(a, b)))
    points = []
    for (t0, v0), (t1, v1) in zip(knots, knots[1:]):
        for k in range(steps):
            t = t0 + (t1 - t0) * k / steps
            if t >= end:
                break
            u = k / steps
            points.append((t, back(v0 + (v1 - v0) * u * u * (3 - 2 * u))))
    t0, v0 = knots[-2]
    t1, v1 = knots[-1]
    u = (end - t0) / (t1 - t0)
    points.append((end, back(v0 + (v1 - v0) * u * u * (3 - 2 * u))))
    return [(round(t, 4), min(max(v, lo), hi)) for t, v in points]


def drift(track, target, start, end, lo, hi, period, seed=0, log=False, **kw):
    """Add a drifting path to the track's `target` lane between beats start
    and end; see drift_points for the shape."""
    return track.automate(target, *drift_points(start, end, lo, hi, period, seed, log, **kw))
