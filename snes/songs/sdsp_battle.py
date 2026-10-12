"""S-DSP Battle: 2-bar intro into a 16-bar battle loop, 160 BPM, E minor.

The second sdsp cue, for range against the overworld spike: fast and
minor, on the pack's synth side. A single-cycle square lead (the saw lead
takes B), a saw bass, trombone stabs in two voices, the synth kit, and the
DSP's noise source as the hats. The echo is the slapback: one 64 ms
repeat, unfiltered.

The intro is a bar of bass and toms on E, then the stabs on B under a
snare roll into A's crash. It plays once; the loop runs over A and B.
Within 8 voices (tools/budget.py): lead 1, stabs 2, bass 1, kit 3, hats 1.

    SLAB_DIR=path/to/slab python3 songs/sdsp_battle.py --render
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

PACKAGE = HERE / "songs/sdsp_battle.slab"
OUT = HERE / "songs/sdsp_battle"

PROG_A = "Em C D B Em C D B"
PROG_B = "C D Em Em C D B B"
LEAD_A = ("E5:.5 F#5:.5 G5:1 B5:1 G5:1  E5:.5 G5:.5 C6:1.5 B5:.5 A5:1  "
          "F#5:.5 A5:.5 D6:1 C6:.5 B5:.5 A5:1  B5:2 D#5:1 F#5:1  "
          "E5:.5 F#5:.5 G5:.5 A5:.5 B5:1 E6:1  D6:.5 C6:.5 B5:.5 C6:.5 G5:2  "
          "A5:.5 B5:.5 C6:.5 D6:.5 F#5:1 A5:1  B5:3 r:1")
LEAD_B = ("G5:1.5 E5:.5 C5:1 E5:1  F#5:1.5 D5:.5 A5:2  G5:.5 A5:.5 B5:1 E6:2  "
          "D6:.5 B5:.5 G5:1 E5:2  E6:1.5 D6:.5 C6:1 G5:1  F#6:1.5 E6:.5 D6:1 A5:1  "
          "D#6:2 F#6:2  B5:.5 r:.5 B5:.5 r:.5 B5:.5 r:.5 D#6:.5 F#6:.5")
STABS = "x..x..x...x.x..."
BASS = "x.x.o.x.x.x.o.x."


class IntroSong(Song):
    """A Song whose loop starts after the intro (slabkit loops from 0)."""
    loop_from = 0.0

    def build(self):
        project = super().build()
        project["transport"]["loop"]["start"] = float(self.loop_from)
        return project


def build_song():
    song = IntroSong("S-DSP Battle", bpm=160, key="E minor", loop=True)
    intro, a, b = song.section("INTRO", 2), song.section("A", 8), song.section("B", 8)
    song.loop_from = a.start

    echo = song.bus("ECHO", fx=[fx("sdspecho", "slapback", dry=0)])
    lead = song.track("SQUARE - lead", "sdsp", "square-lead", volume=.55, pan=-.15)
    tune = song.track("SAW - lead", "sdsp", "saw-lead", volume=.85, pan=.15)
    stab = song.track("TROMBONE - stabs", "sdsp", "trombone", volume=1.0, pan=.40)
    bass = song.track("SAW - bass", "sdsp", "saw-bass", volume=1.15,
                      fx=[fx("eq2", hpf_on=1, hpf_hz=55)])
    kit = song.track("KIT", "sdsp", "drum-kit", volume=.85)
    hats = song.track("NOISE - hats", "sdsp", "noise-hat", volume=.42, pan=-.40)
    for t, db in ((lead, -9), (tune, -9), (stab, -12)):
        t.send(echo, db)
    song.master(subsonic=True, fx=[fx("limiter2", gain=0, ceil=-1)])

    # intro: bass and toms on E, then stabs on B under a swelling roll
    bass.clip(intro).bass("Em B", BASS, octave=2)
    k = kit.clip(intro)
    k.drums({41: "x..x..x.x..x..x.", 45: "......x.......x."}, bars=1, length=.5)
    for i in range(16):
        k.note(38, 4 + i * .25, .2, 40 + i * 5)
    stab.clip(intro, at_bar=1, bars=1).chords("B", STABS, near=52, voices=2)
    bass.ride({intro: (-12, 0)})

    lead.clip(a).melody(LEAD_A, gate=.85)
    tune.clip(b).melody(LEAD_B, gate=.9)
    for sec, prog in ((a, PROG_A), (b, PROG_B)):
        stab.clip(sec).chords(prog, STABS, near=52, voices=2)
        bass.clip(sec).bass(prog, BASS, octave=2)
        # a note's length is how long its hit holds a voice (the kit keys off)
        k = kit.clip(sec)
        k.drums({36: "x.....x.x.....x.", 38: "....x.......x..."}, bars=7, length=.5)
        k.drums({36: "x.....x.x.......", 38: "....x...x.xxxxxx"}, at=28, bars=1, length=.25)
        k.note(49, 0, 2, 100)
        hats.clip(sec).drums({60: "xxXxxxXxxxXxxxXx"}, bars=8, length=.15)
    song.save(str(PACKAGE))
    return song


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    song = build_song()
    if args.render:
        OUT.mkdir(exist_ok=True)
        wav = OUT / "sdsp_battle.wav"
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
