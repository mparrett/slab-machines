"""S-DSP Spike: 16-bar overworld loop, 132 BPM, F major.

The listening test for the sdsp voice and echo. Scored for the console's
eight voices: a trumpet lead (strings take the tune in B), cello chords,
a spiccato ostinato, pizzicato bass and the synth kit. One echo on a
send, as the console had one echo buffer that voices switched into.

Needs a Slab checkout that loads user machines, built, and this repo's
machines installed (see the README):
    SLAB_DIR=path/to/slab python3 songs/sdsp_spike.py --render
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

PACKAGE = HERE / "songs/sdsp_spike.slab"
OUT = HERE / "songs/sdsp_spike"

PROG_A = "F C Dm Bb F C Bb C"
PROG_B = "Dm Bb F C Dm Bb Gm C"
LEAD_A = ("C5:1 F5:1.5 G5:.5 A5:1  G5:1.5 E5:.5 C5:2  D5:1 F5:1 A5:1 D6:1  C6:3 r:1 "
          "A5:1 C6:1.5 Bb5:.5 A5:1  G5:1.5 A5:.5 G5:1 E5:1  F5:1 D5:1 Bb5:1 A5:1  G5:3 r:1")
LEAD_B = ("A4:1.5 D5:.5 F5:1 E5:1  D5:1.5 C5:.5 Bb4:2  A4:1 C5:1 F5:1 A5:1  G5:3 r:1 "
          "A5:1.5 F5:.5 D5:1 F5:1  Bb5:1.5 A5:.5 F5:1 D5:1  G5:1 Bb5:1 D6:1 C6:1  C6:2 E5:1 G5:1")


def build_song():
    song = Song("S-DSP Spike", bpm=132, key="F major", loop=True)
    a, b = song.section("A", 8), song.section("B", 8)

    echo = song.bus("ECHO", fx=[fx("sdspecho", "overworld", dry=0)])
    lead = song.track("TRUMPET - lead", "sdsp", "trumpet", volume=.80, pan=-.10)
    tune = song.track("STRINGS - lead", "sdsp", "strings", volume=.78, pan=.10)
    pad = song.track("CELLO - chords", "sdsp", "cello", volume=.30, pan=-.20)
    ost = song.track("SPICCATO - ostinato", "sdsp", "spiccato", volume=.95, pan=.30)
    bass = song.track("PIZZ - bass", "sdsp", "pizz-bass", volume=1.0)
    kit = song.track("KIT", "sdsp", "drum-kit", volume=.80)
    for t, db in ((lead, -8), (tune, -8), (ost, -10)):
        t.send(echo, db)
    song.master(subsonic=True, fx=[fx("limiter2", gain=0, ceil=-1)])

    lead.clip(a).melody(LEAD_A)
    tune.clip(b).melody(LEAD_B)
    for sec, prog in ((a, PROG_A), (b, PROG_B)):
        pad.clip(sec).chords(prog, near=60)
        ost.clip(sec).arp(prog, "up", rate=.5, octave=4)
        bass.clip(sec).bass(prog, "x.....x.x...x...", octave=2)
        k = kit.clip(sec)
        k.drums({36: "x.....x.x.......", 38: "....x.......x...", 42: "x.x.x.x.x.x.x.x."}, bars=7, length=.2)
        k.drums({36: "x.....x.x.......", 38: "....x.....x.xxxx", 42: "x.x.x.x.x.x....."}, at=28, bars=1, length=.2)
        k.note(49, 0, .5, 100)
    song.save(str(PACKAGE))
    return song


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    song = build_song()
    if args.render:
        OUT.mkdir(exist_ok=True)
        wav = OUT / "sdsp_spike-loop.wav"
        # cwd is the factory root: the machines' includes resolve there
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
