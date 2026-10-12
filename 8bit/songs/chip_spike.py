"""Chip Spike: 16-bar chiptune stage loop, 150 BPM, A minor.

The listening test for the chip machine. The parts are the console's
channels: two pulses, a triangle bass and noise drums, with the kick a
swept triangle on its own track for mixing. No reverb: the chips had none.
In the first half pulse 2 echoes the lead a dotted eighth late, the
trick for faking a delay. In the second half it holds one note a bar and
the machine's ARP turns it into the chord.

Needs a Slab checkout that loads user machines, built, and the chip
machine installed (see the README):
    SLAB_DIR=path/to/slab python3 songs/chip_spike.py --render
slabkit needs numpy.
"""
from pathlib import Path
import argparse
import json
import os
import subprocess
import sys

HERE = Path(__file__).resolve().parents[1]
if "SLAB_DIR" not in os.environ:
    sys.exit("set SLAB_DIR to a built Slab checkout that loads user machines (see README)")
SLAB = Path(os.environ["SLAB_DIR"]).expanduser().resolve()
sys.path.insert(0, str(SLAB / "tools"))
from slabkit import Song, fx  # noqa: E402
from slabkit.analyze import analyze_wav  # noqa: E402

PACKAGE = HERE / "songs/chip_spike.slab"
OUT = HERE / "songs/chip_spike"

PROG_A = "Am F C G Am F C G"
PROG_B = "F G Em Am F G E E"
LEAD_A = ("A4:.5 C5:.5 E5:1 D5:.5 C5:.5 B4:.5 C5:.5  A4:1.5 F4:.5 A4:1 C5:1 "
          "G4:.5 C5:.5 E5:1 G5:1 E5:1  D5:1.5 B4:.5 G4:2 "
          "A4:.5 C5:.5 E5:1 A5:1 G5:.5 E5:.5  F5:1.5 E5:.5 C5:1 A4:1 "
          "E5:.5 D5:.5 C5:.5 D5:.5 E5:1 G5:1  B5:1.5 A5:.5 G5:1 r:1")
LEAD_B = ("C6:1.5 A5:.5 F5:1 A5:1  B5:1.5 G5:.5 D5:1 G5:1 "
          "E5:.5 G5:.5 B5:1 G5:.5 E5:.5 B4:1  C5:1 E5:1 A5:2 "
          "A5:.5 G5:.5 F5:.5 E5:.5 F5:1 A5:1  G5:.5 F5:.5 E5:.5 D5:.5 B4:1 D5:1 "
          "E5:1 G#5:1 B5:1 D6:1  C6:.5 B5:.5 A5:.5 G#5:.5 E5:1 r:1")
# One held note a bar for pulse 2's ARP: the root, and the ARP mode
# (index: 1 MAJ, 2 MIN) that spells the chord.
ARP_B = [("F4", 1), ("G4", 1), ("E4", 2), ("A4", 2), ("F4", 1), ("G4", 1), ("E4", 1), ("E4", 1)]


def build_song():
    song = Song("Chip Spike", bpm=150, key="A minor", loop=True)
    a, b = song.section("A", 8), song.section("B", 8)

    lead = song.track("PULSE 1 - lead", "chip", "lead-25", volume=.80, pan=-.12)
    harm = song.track("PULSE 2 - echo/arp", "chip", "lead-12", volume=.50, pan=.15)
    tri = song.track("TRIANGLE - bass", "chip", "tri-bass", volume=.62)
    kick = song.track("KICK - tri sweep", "chip", "tri-kick", volume=.60)
    snare = song.track("NOISE - snare", "chip", "noise-snare", volume=.55)
    hat = song.track("NOISE - hat", "chip", "noise-hat", volume=.32)
    song.master(subsonic=True, fx=[fx("limiter2", gain=0, ceil=-1)])

    lead.clip(a).melody(LEAD_A)
    lead.clip(b).melody(LEAD_B)
    # The echo: the same line a dotted eighth late, quieter, on the thinner pulse.
    echo = harm.clip(a).melody(LEAD_A, at=.75)
    echo.velocities(lambda n: 70)
    arps = harm.clip(b)
    points = []
    for bar, (root, mode) in enumerate(ARP_B):
        arps.note(root, bar * 4, 3.9, 90)
        points.append((bar * 4, mode, "hold"))
    arps.automate("arp", *points)

    tri.clip(a).bass(PROG_A, "x.o.x.o.x.o.x.ox", octave=2)
    tri.clip(b).bass(PROG_B, "x...x.o.x...x.o.", octave=2)

    for section, bars in ((a, 8), (b, 8)):
        kick.clip(section).drums({48: "x.......x.x....."}, bars=bars, length=.2)
        sn = snare.clip(section)
        sn.drums({62: "....x.......x..."}, bars=bars - 1, length=.2)
        sn.drums({62: "....x.......x.xx"}, at=(bars - 1) * 4, bars=1, length=.15)
        hat.clip(section).drums({86: "x.x.x.x.x.x.x.x."}, bars=bars, length=.05)
    song.save(str(PACKAGE))
    return song


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    song = build_song()
    if args.render:
        OUT.mkdir(exist_ok=True)
        wav = OUT / "chip_spike-loop.wav"
        # cwd is the factory root: the machine's includes resolve there
        subprocess.run([str(SLAB / "zig-out/bin/slab"), str(PACKAGE),
            "--render", str(wav), "--stems", str(OUT / "stems"), "--stem-kind", "tracks",
            "--tap", "fader", "--range", "0:64", "--loop-wrap", "--tail", "auto",
            "--bits", "24"], cwd=SLAB, check=True)
        sections = [(s.name, song.seconds_at(s.start), song.seconds_at(s.end)) for s in song.sections]
        report = {"mix": analyze_wav(str(wav), sections), "stems": {
            p.stem: analyze_wav(str(p)) for p in sorted((OUT / "stems").glob("*.wav"))}}
        (OUT / "mix-report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report["mix"], indent=2))


if __name__ == "__main__":
    main()
