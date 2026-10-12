"""Check a Slab project against its console's audio budget.

A console had one sound system for the whole game, sound effects
included. Slab gives each track its own voices, and the SNES side as much
memory as it likes, so a cue can quietly need more than the hardware had.
This reads a saved project and reports, for the machines it uses:

  SNES (sdsp): 8 voices, and 64 KiB of audio RAM holding the driver, the
  samples (as BRR) and the echo buffer.
  Genesis: FM 6 channels (opn), 5 when the DAC (opndac, 1) takes channel
  6; PSG 3 tone channels and 1 noise (psg), where a noise track at RATE
  TONE 3 also takes tone channel 3.

  ARAM    BRR bytes of every distinct sample the sdsp tracks load, the echo
          buffer (2 KiB per EDL step of the largest sdspecho), and a driver
          estimate (--driver, the driver's code plus the song's sequence
          data; a guess, as drivers varied), against 64 KiB.
  VOICES  notes sounding at once across each group's tracks. A note holds its
          voice for its length, or for the sample's length when that is
          shorter and the sample doesn't loop; one-shot SFZ regions hold it
          for the whole sample, as key-off doesn't stop them. A release
          tail holds the voice too: about 8 ms at REL 0, up to seconds at
          the slow RELs (rel_seconds), unless the sample ends first; opn's
          for its slowest carrier RR (opn_rel_seconds), psg's for its RR
          frames per step. A
          driver gave each part fixed channels, and a part's next note cuts
          a tail on its channel, so a track counts at most as many voices as
          it ever sounds notes at once (its channels).

    python3 tools/budget.py snes/songs/sdsp_spike.slab

Exits 1 when any budget is over. Standard library only.
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
# 32 kHz samples per envelope step at each rate, as sdsp/kernel.fy's sdsp-period
PERIOD = [None, 2048, 1536, 1280, 1024, 768, 640, 512, 384, 320, 256, 192, 160, 128, 96,
          80, 64, 48, 40, 32, 24, 20, 16, 12, 10, 8, 6, 5, 4, 3, 2, 1]


def rel_seconds(rel):
    """How long a release from full holds the voice: key-off's -8 a tick
    at REL 0, else the exponential step at that rate, down to 0."""
    rel = int(rel)
    if rel < 1:
        return 2048 / 8 / 32000
    env, steps = 2047, 0
    while env > 0:
        env -= (env - 1) // 256 + 1
        steps += 1
    return steps * PERIOD[min(rel, 31)] / 32000


# opn: carriers per ALG [OP1..OP4]
OPN_CARRIERS = [(4,), (4,), (4,), (4,), (2, 4), (2, 3, 4), (2, 3, 4), (1, 2, 3, 4)]
OPN_STEPHI = [[0, 0, 0, 0], [1, 0, 0, 0], [1, 0, 1, 0], [1, 1, 1, 0]]


def opn_rel_seconds(rr):
    """How long an opn operator's release holds the channel: from full
    level to -94 dB at RR, stepping the envelope as opn/kernel.fy does.
    Full level and no key scaling make it the longest case: a note cut
    before its decay starts from there."""
    rate = min(63, 2 * (2 * int(rr) + 1))
    level = 0
    timer, ticks = 0, 0
    while level < 1008 and ticks < 2_000_000:
        timer = (timer + 1) % 4096
        ticks += 1
        tz = next((j for j in range(12) if timer >> j & 1), 12)
        shl = 0 if timer == 0 else tz + 1
        if rate < 48:
            s = (rate // 4 + shl) % 16
            inc = 1 if s == 12 else (rate >> 1 & 1 if s == 13 else (rate & 1 if s == 14 else 0))
        else:
            inc = min(4, OPN_STEPHI[rate % 4][timer % 4] + rate // 4 - 11)
        if inc > 0:
            level += 1 << (inc - 1)
    return ticks * 3 / 53267.04


def resolve(ref, project_dir):
    """A machine asset ref to a file: user: refs under ~/Music/Slab (or
    this repo's <console>/<machine>, for its own machines before install),
    others beside the project."""
    if ref.startswith("user:"):
        rel = ref[len("user:"):]
        home = Path.home() / "Music/Slab" / rel
        if home.exists():
            return home
        if rel.startswith("Machines/"):
            machine, _, rest = rel[len("Machines/"):].partition("/")
            found = next(HERE.glob(f"*/{machine}"), None)
            if found is not None:
                return found / rest
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
        # sample= runs to the end of the line: its path may hold spaces
        head, _, sample = line.partition("sample=")
        kv = dict(re.findall(r"(\w+)=(\S+)", head), sample=sample.strip())
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

    samples, edls, notes, groups = {}, [], {}, {}
    dac_used = False
    for t in p["tracks"] + [p.get("master") or {}]:
        for fx in t.get("effects") or []:
            if fx["machine"] == "sdspecho" and not fx.get("bypass"):
                edls.append(int(fx["params"].get("secho-edl", 0)))
        inst = t.get("instrument") or {}
        machine = inst.get("machine")
        if machine not in ("sdsp", "opn", "psg", "opndac") or t.get("mute"):
            continue
        prm = inst.get("params", {})
        zs, tail = None, 0.0
        if machine == "sdsp":
            zs = zones(resolve(inst["assets"]["brr"], pj.parent))
            tail = rel_seconds(prm.get("sdsp-rel", 0))
            for z in zs:
                samples[z.path.resolve()] = z.frames
            groups[t["name"]] = ["S-DSP"]
        elif machine == "opndac":
            ref = (inst.get("assets") or {}).get("pcm", "user:Machines/opndac/assets/kit.sfz")
            zs = zones(resolve(ref, pj.parent))
            # one-shots: key-off doesn't stop the DAC
            for z in zs:
                z.oneshot = True
            groups[t["name"]] = ["DAC"]
        elif machine == "opn":
            alg = int(prm.get("opn-alg", 7))
            tail = max(opn_rel_seconds(prm.get(f"opn-op{i}-rr", 15)) for i in OPN_CARRIERS[alg])
            groups[t["name"]] = ["FM"]
        else:
            mode, rate = int(prm.get("psg-mode", 0)), int(prm.get("psg-rate", 0))
            # from the top: a note cut before its decay releases from there
            tail = 15 * max(1, int(prm.get("psg-rr", 1))) / 60
            groups[t["name"]] = ["PSG tone"] if mode == 0 else (
                ["PSG noise", "PSG tone"] if rate == 3 else ["PSG noise"])
        tail *= bpm / 60
        for c in t.get("clips") or []:
            for n in c.get("notes") or []:
                # notes past the clip's end don't play; the clip cuts the rest
                if n["start"] >= c["len"]:
                    continue
                length = min(n["len"], c["len"] - n["start"])
                body, held = length, length + tail
                if zs is not None:
                    z = next((z for z in zs if z.lo <= n["pitch"] <= z.hi), None)
                    if z is None:
                        continue
                    secs = z.seconds(n["pitch"])
                    if secs is not None:
                        end = secs * bpm / 60
                        body, held = (end, end) if z.oneshot else (min(body, end), min(held, end))
                if machine == "opndac":
                    dac_used = True
                notes.setdefault(t["name"], []).append((c["start"] + n["start"], body, held))

    # the DAC is one channel: a sample stops when the next starts
    for name, gs in groups.items():
        if "DAC" in gs and name in notes:
            ns = sorted(notes[name])
            notes[name] = [(a, min(b, nxt - a), min(h, nxt - a))
                           for (a, b, h), nxt in zip(ns, [x[0] for x in ns[1:]] + [float("inf")])]

    if samples or edls:
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

    # a track's channels: the most notes it ever sounds at once
    channels = {}
    for name, ns in notes.items():
        ev = sorted([(a, 1) for a, _, _ in ns] + [(a + b, -1) for a, b, _ in ns], key=lambda e: (e[0], e[1]))
        now = 0
        for _, d in ev:
            now += d
            channels[name] = max(channels.get(name, 0), now)
    limits = {"S-DSP": VOICES, "FM": 5 if dac_used else 6, "DAC": 1, "PSG tone": 3, "PSG noise": 1}
    bar = p["meter"][0]["num"] * 4 / p["meter"][0]["den"]
    for group, limit in limits.items():
        members = [n for n, gs in groups.items() if group in gs and n in notes]
        if not members:
            continue
        # ends sort before starts at the same beat, as a voice frees on key-off
        events = sorted([(a, 1, n) for n in members for a, _, _ in notes[n]] +
                        [(a + h, -1, n) for n in members for a, _, h in notes[n]], key=lambda e: (e[0], e[1]))
        peak, spans, open_at, active, held, at_peak = 0, [], None, {}, {}, ({}, 0.0)
        for beat, d, name in events:
            active[name] = active.get(name, 0) + d
            held[name] = min(active[name], channels[name])
            now = sum(held.values())
            if now > peak:
                peak, at_peak = now, (dict(held), beat)
            if now > limit and open_at is None:
                open_at = beat
            elif now <= limit and open_at is not None:
                spans.append((open_at, beat))
                open_at = None
        mix = ", ".join(f"{k} {v}" for k, v in at_peak[0].items() if v > 0)
        label = "VOICES " if group == "S-DSP" else f"{group:8s}"
        print(f"{label} peak {peak} of {limit}, first at bar {int(at_peak[1] // bar) + 1}: {mix}")
        if spans:
            over = True
            secs = sum(b - a for a, b in spans) * 60 / bpm
            bars = sorted({int(a // bar) + 1 for a, _ in spans})
            print(f"        over {limit} for {secs:.2f} s, in bars {', '.join(map(str, bars))}")
    sys.exit(1 if over else 0)


if __name__ == "__main__":
    main()
