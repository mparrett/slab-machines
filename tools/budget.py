"""Check a Slab project against the console's audio budget.

The console had one sound system for the whole game: 8 voices, sound
effects included, and 64 KiB of audio RAM holding the driver, the samples
(as BRR) and the echo buffer. Slab gives each sdsp track its own 8 voices
and as much memory as it likes, so a cue can quietly need more than the
hardware had. This reads a saved project and reports:

  ARAM    BRR bytes of every distinct sample the sdsp tracks load, the echo
          buffer (2 KiB per EDL step of the largest sdspecho), and a driver
          estimate (--driver, the driver's code plus the song's sequence
          data; a guess, as drivers varied), against 64 KiB.
  VOICES  notes sounding at once across all sdsp tracks. A note holds its
          voice for its length, or for the sample's length when that is
          shorter and the sample doesn't loop; one-shot SFZ regions hold it
          for the whole sample, as key-off doesn't stop them. Release tails
          are ignored: with REL 0 they last about 8 ms.

    python3 tools/budget.py songs/sdsp_spike.slab

Exits 1 when either budget is over. Standard library only.
"""
from pathlib import Path
import argparse
import json
import math
import re
import struct
import sys

HERE = Path(__file__).resolve().parents[1]
ARAM = 64 * 1024
VOICES = 8
ECHO_STEP = 2048  # 512 stereo frames of 16-bit samples per EDL step


def resolve(ref, project_dir):
    """A machine asset ref to a file: user: refs under ~/Music/Slab (or
    this repo, for its own machines before install), others beside the
    project."""
    if ref.startswith("user:"):
        rel = ref[len("user:"):]
        home = Path.home() / "Music/Slab" / rel
        if home.exists():
            return home
        if rel.startswith("Machines/"):
            return HERE / rel[len("Machines/"):]
        return home
    return project_dir / ref


def read_wav(path):
    """(rate, frames, root, looped) from a PCM WAV and its smpl chunk."""
    data = path.read_bytes()
    pos, rate, frames, root, looped, block = 12, 0, 0, 60.0, False, 2
    while pos + 8 <= len(data):
        cid, size = struct.unpack_from("<4sI", data, pos)
        body = pos + 8
        if cid == b"fmt ":
            _, ch, rate, _, block = struct.unpack_from("<HHIIH", data, body)
        elif cid == b"data":
            frames = size // block
        elif cid == b"smpl":
            unity, frac = struct.unpack_from("<II", data, body + 12)
            root = unity + frac / 2 ** 32
            looped = struct.unpack_from("<I", data, body + 28)[0] > 0
        pos = body + size + (size & 1)
    return rate, frames, root, looped


class Zone:
    def __init__(self, path, lo=0, hi=127, center=None, oneshot=False):
        self.path = path
        self.rate, self.frames, root, self.looped = read_wav(path)
        self.lo, self.hi = lo, hi
        self.root = root if center is None else center
        self.oneshot = oneshot

    def seconds(self, pitch):
        """How long the sample plays at this pitch, or None when it loops."""
        if self.looped and not self.oneshot:
            return None
        return self.frames / self.rate / 2 ** ((pitch - self.root) / 12)


def zones(path):
    if path.suffix.lower() != ".sfz":
        return [Zone(path)]
    out = []
    for line in path.read_text().splitlines():
        if not line.startswith("<region>"):
            continue
        kv = dict(re.findall(r"(\w+)=(\S+)", line))
        key = kv.get("key")
        lo, hi = int(kv.get("lokey", key or 0)), int(kv.get("hikey", key or 127))
        center = kv.get("pitch_keycenter", key)
        out.append(Zone(path.parent / kv["sample"], lo, hi,
                        float(center) if center is not None else None,
                        kv.get("loop_mode") == "one_shot"))
    return out


def brr_bytes(frames):
    return math.ceil(frames / 16) * 9


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("project", type=Path, help="a .slab package or its project.json")
    ap.add_argument("--driver", type=int, default=8192, help="bytes for driver and sequence data (default 8192)")
    args = ap.parse_args()
    pj = args.project / "project.json" if args.project.is_dir() else args.project
    p = json.loads(pj.read_text())
    bpm = p["transport"]["bpm"]
    over = False

    samples, edls, events = {}, [], []
    for t in p["tracks"] + [p.get("master") or {}]:
        for fx in t.get("effects") or []:
            if fx["machine"] == "sdspecho" and not fx.get("bypass"):
                edls.append(int(fx["params"].get("secho-edl", 0)))
        inst = t.get("instrument") or {}
        if inst.get("machine") != "sdsp" or t.get("mute"):
            continue
        zs = zones(resolve(inst["assets"]["brr"], pj.parent))
        for z in zs:
            samples[z.path.resolve()] = z.frames
        for c in t.get("clips") or []:
            for n in c.get("notes") or []:
                z = next((z for z in zs if z.lo <= n["pitch"] <= z.hi), None)
                if z is None:
                    continue
                beats = n["len"]
                secs = z.seconds(n["pitch"])
                if secs is not None:
                    beats = secs * bpm / 60 if z.oneshot else min(beats, secs * bpm / 60)
                start = c["start"] + n["start"]
                events.append((start, 1, t["name"]))
                events.append((start + beats, -1, t["name"]))

    sample_b = sum(brr_bytes(f) for f in samples.values())
    echo_b = max(edls, default=0) * ECHO_STEP
    total = sample_b + echo_b + args.driver
    print(f"ARAM    {total / 1024:5.1f} of {ARAM // 1024} KiB: samples {sample_b / 1024:.1f} "
          f"({len(samples)} files), echo {echo_b / 1024:.1f} (EDL {max(edls, default=0)}), "
          f"driver {args.driver / 1024:.1f} (estimate)")
    if len(set(edls)) > 1:
        print(f"        the console had one echo; these sdspecho instances differ in EDL: {sorted(set(edls))}")
    if total > ARAM:
        print(f"        over by {(total - ARAM) / 1024:.1f} KiB")
        over = True

    # ends sort before starts at the same beat, as a voice frees on key-off
    events.sort(key=lambda e: (e[0], e[1]))
    bar = p["meter"][0]["num"] * 4 / p["meter"][0]["den"]
    now, peak, spans, open_at, held, at_peak = 0, 0, [], None, {}, ({}, 0.0)
    for beat, d, name in events:
        now += d
        held[name] = held.get(name, 0) + d
        if now > peak:
            peak, at_peak = now, (dict(held), beat)
        if now > VOICES and open_at is None:
            open_at = beat
        elif now <= VOICES and open_at is not None:
            spans.append((open_at, beat))
            open_at = None
    mix = ", ".join(f"{k} {v}" for k, v in at_peak[0].items() if v > 0)
    print(f"VOICES  peak {peak} of {VOICES}, first at bar {int(at_peak[1] // bar) + 1}: {mix}")
    if spans:
        over = True
        secs = sum(b - a for a, b in spans) * 60 / bpm
        bars = sorted({int(a // bar) + 1 for a, _ in spans})
        print(f"        over {VOICES} for {secs:.2f} s, in bars {', '.join(map(str, bars))}")
    sys.exit(1 if over else 0)


if __name__ == "__main__":
    main()
