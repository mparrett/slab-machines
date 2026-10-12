"""S-DSP Spike: 4-bar intro into a 16-bar overworld loop, 132 BPM, F major.

The listening test for the sdsp voice and echo. Scored for the console's
eight voices: a trumpet lead (strings take the tune in B), cello chords,
a spiccato ostinato, pizzicato bass and the synth kit. One echo on a
send, as the console had one echo buffer that voices switched into.
It fits the console's 8 voices (tools/budget.py): lead 1, cello triads
3, ostinato 1, bass 1, kit 2, with the crash standing in for the hat for
its half bar.

The intro sits on Bb-C (IV-V) and adds a layer a bar: ostinato, cello,
bass and hats, then a snare roll that the crash on A's downbeat answers.
It plays once; the song's loop runs over A and B.

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

PROG_I = "Bb C Bb C"
PROG_A = "F C Dm Bb F C Bb C"
PROG_B = "Dm Bb F C Dm Bb Gm C"
LEAD_A = ("C5:1 F5:1.5 G5:.5 A5:1  G5:1.5 E5:.5 C5:2  D5:1 F5:1 A5:1 D6:1  C6:3 r:1 "
          "A5:1 C6:1.5 Bb5:.5 A5:1  G5:1.5 A5:.5 G5:1 E5:1  F5:1 D5:1 Bb5:1 A5:1  G5:3 r:1")
LEAD_B = ("A4:1.5 D5:.5 F5:1 E5:1  D5:1.5 C5:.5 Bb4:2  A4:1 C5:1 F5:1 A5:1  G5:3 r:1 "
          "A5:1.5 F5:.5 D5:1 F5:1  Bb5:1.5 A5:.5 F5:1 D5:1  G5:1 Bb5:1 D6:1 C6:1  C6:2 E5:1 G5:1")


class IntroSong(Song):
    """A Song whose loop starts after the intro (slabkit loops from 0)."""
    loop_from = 0.0

    def build(self):
        project = super().build()
        project["transport"]["loop"]["start"] = float(self.loop_from)
        return project


def build_song():
    song = IntroSong("S-DSP Spike", bpm=132, key="F major", loop=True)
    intro, a, b = song.section("INTRO", 4), song.section("A", 8), song.section("B", 8)
    song.loop_from = a.start

    # SURR inverts the right echo, the width trick games used
    echo = song.bus("ECHO", fx=[fx("sdspecho", "overworld", dry=0, surr=1)])
    lead = song.track("TRUMPET - lead", "sdsp", "trumpet", volume=.80, pan=-.30)
    tune = song.track("STRINGS - lead", "sdsp", "strings", volume=.78, pan=.30)
    pad = song.track("CELLO - chords", "sdsp", "cello", volume=.30, pan=-.45)
    ost = song.track("SPICCATO - ostinato", "sdsp", "spiccato", volume=.95, pan=.50)
    bass = song.track("PIZZ - bass", "sdsp", "pizz-bass", volume=1.0,
                      fx=[fx("eq2", hpf_on=1, hpf_hz=55)])
    kit = song.track("KIT", "sdsp", "drum-kit", volume=.80)
    for t, db in ((lead, -8), (tune, -8), (ost, -10)):
        t.send(echo, db)
    song.master(subsonic=True, fx=[fx("limiter2", gain=0, ceil=-1)])

    # intro: one layer a bar, each riding up from below its fader
    ost.clip(intro).arp(PROG_I, "up", rate=.5, octave=4)
    pad.clip(intro, at_bar=1, bars=3).chords("C Bb C", near=60, voices=3)
    bass.clip(intro, at_bar=2, bars=2).bass("Bb C", "x.....x.x...x...", octave=2)
    k = kit.clip(intro, at_bar=2, bars=2)
    k.drums({42: "x.x.x.x.x.x.x.x."}, bars=1, length=.2)
    k.drums({36: "x.......x......."}, at=4, bars=1, length=.5)
    k.drums({42: "x.x.x.x........."}, at=4, bars=1, length=.2)
    for i in range(8):  # a sixteenth snare roll over the last two beats, swelling
        k.note(38, 6 + i * .25, .2, 50 + i * 9)
    ost.ride({intro: (-14, 0)})
    pad.ride({intro: (-10, 0)})

    lead.clip(a).melody(LEAD_A)
    tune.clip(b).melody(LEAD_B)
    for sec, prog in ((a, PROG_A), (b, PROG_B)):
        pad.clip(sec).chords(prog, near=60, voices=3)
        ost.clip(sec).arp(prog, "up", rate=.5, octave=4)
        bass.clip(sec).bass(prog, "x.....x.x...x...", octave=2)
        # a note's length is how long its hit holds a voice (the kit keys off)
        k = kit.clip(sec)
        k.drums({36: "x.....x.x.......", 38: "....x.......x..."}, bars=7, length=.5)
        k.drums({42: "........x.x.x.x."}, bars=1, length=.2)
        k.drums({42: "x.x.x.x.x.x.x.x."}, at=4, bars=6, length=.2)
        k.drums({36: "x.....x.x.......", 38: "....x.....x.xxxx"}, at=28, bars=1, length=.25)
        k.drums({42: "x.x.x.x.x.x....."}, at=28, bars=1, length=.2)
        k.note(49, 0, 2, 100)
    song.save(str(PACKAGE))
    return song


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    song = build_song()
    if args.render:
        OUT.mkdir(exist_ok=True)
        wav = OUT / "sdsp_spike.wav"
        # cwd is the factory root: the machines' includes resolve there
        subprocess.run([str(SLAB / "zig-out/bin/slab"), str(PACKAGE),
            "--render", str(wav), "--stems", str(OUT / "stems"), "--stem-kind", "tracks",
            "--tap", "fader", "--range", f"0:{song.sections[-1].end:g}", "--tail", "auto",
            "--bits", "24"], cwd=SLAB, check=True)
        sections = [(s.name, song.seconds_at(s.start), song.seconds_at(s.end)) for s in song.sections]
        report = {"mix": analyze_wav(str(wav), sections), "stems": {
            p.stem: analyze_wav(str(p)) for p in sorted((OUT / "stems").glob("*.wav"))}}
        (OUT / "mix-report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report["mix"], indent=2))


if __name__ == "__main__":
    main()
