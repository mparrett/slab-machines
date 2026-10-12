"""S-DSP Aqua: 4-bar intro into a 16-bar underwater loop, 80 BPM, B minor.

An original cue in the style of the 1994 platformer's underwater stages:
the ceiling test for the pack. A beating saw pad, a TX81Z electric piano
in sixteenths, a round fingered bass, an alto recorder lead (soft vibes
take B), and quiet percussion, all into the longest echo the DSP had
[lagoon: EDL 15, high feedback, lowpassed, SURR]. That echo takes 30 of
the 64 KiB, so the instruments live in what's left.

The intro swells the pad alone, then adds the piano, then bass and
shaker, then the kick and a vibes bloom. It plays once; the loop runs
over A and B. Within 8 voices (tools/budget.py): pad 3, piano 1, bass 1,
lead 1, percussion 2, with the finger cymbals standing in for the shaker
on each section's first beat.

    SLAB_DIR=path/to/slab python3 songs/sdsp_aqua.py --render
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

PACKAGE = HERE / "songs/sdsp_aqua.slab"
OUT = HERE / "songs/sdsp_aqua"

PROG_I = "Bm7 Gmaj7 Bm7 Gmaj7"
PROG_A = "Bm7 Gmaj7 Em7 F#m7 Bm7 Gmaj7 Em7 Asus4:2 A:2"
PROG_B = "Gmaj7 F#m7 Em7 Dmaj7 Gmaj7 F#m7 Em7 F#7"
LEAD_A = ("r:1 F#5:1 E5:.5 D5:.5 C#5:1  D5:3 r:1  r:1 B4:1 D5:1 E5:1  C#5:3 A4:1  "
          "r:1 F#5:1 A5:.5 F#5:.5 E5:1  F#5:2 D5:2  E5:1 G5:1 F#5:1 E5:1  C#5:3 r:1")
LEAD_B = ("B5:1.5 A5:.5 F#5:2  E5:1.5 C#5:.5 A5:2  G5:1 F#5:1 E5:1 D5:1  F#5:3 r:1  "
          "B5:1 D6:1 C#6:1 B5:1  A5:3 C#6:1  B5:2 G5:2  A#5:3 r:1")
BASS = "x-----5-o---7-5-"
SHAKER = "oxoxXxoxoxoxXxox"


class IntroSong(Song):
    """A Song whose loop starts after the intro (slabkit loops from 0)."""
    loop_from = 0.0

    def build(self):
        project = super().build()
        project["transport"]["loop"]["start"] = float(self.loop_from)
        return project


def build_song():
    song = IntroSong("S-DSP Aqua", bpm=80, key="B minor", loop=True)
    intro, a, b = song.section("INTRO", 4), song.section("A", 8), song.section("B", 8)
    song.loop_from = a.start

    echo = song.bus("ECHO", fx=[fx("sdspecho", "lagoon", dry=0)])
    pad = song.track("PAD", "sdsp", "aqua-pad", volume=.45)
    keys = song.track("EPIANO - arp", "sdsp", "epiano", volume=.60, pan=.35)
    bass = song.track("BASS", "sdsp", "fret-bass", volume=.85,
                      fx=[fx("eq2", hpf_on=1, hpf_hz=50)])
    lead = song.track("RECORDER - lead", "sdsp", "recorder", volume=.60, pan=-.20)
    vibes = song.track("VIBES - lead", "sdsp", "vibes", volume=1.05, pan=-.20)
    perc = song.track("PERC", "sdsp", "aqua-perc", volume=.55, pan=.15)
    for t, db in ((keys, -5), (lead, -6), (vibes, -6), (pad, -10)):
        t.send(echo, db)
    song.master(subsonic=True, fx=[fx("limiter2", gain=0, ceil=-1)])

    # intro: the pad swells alone; piano, then bass and shaker, then kick
    pad.clip(intro).chords(PROG_I, near=62, voices=3)
    keys.clip(intro, at_bar=1, bars=3).arp("Gmaj7 Bm7 Gmaj7", "updown", rate=.25, octave=5)
    bass.clip(intro, at_bar=2, bars=2).bass("Bm7 Gmaj7", BASS, octave=2)
    k = perc.clip(intro, at_bar=2, bars=2)
    k.drums({42: SHAKER}, bars=2, length=.2)
    k.drums({36: "x.......x......."}, at=4, bars=1, length=.5)
    vibes.clip(intro, at_bar=3, bars=1).melody("F#6:3 r:1")
    keys.ride({intro: (-12, 0)})

    lead.clip(a).melody(LEAD_A, gate=.95)
    vibes.clip(b).melody(LEAD_B, gate=.9)
    for sec, prog in ((a, PROG_A), (b, PROG_B)):
        pad.clip(sec).chords(prog, near=62, voices=3)
        keys.clip(sec).arp(prog, "updown", rate=.25, octave=5)
        bass.clip(sec).bass(prog, BASS, octave=2)
        k = perc.clip(sec)
        k.note(46, 0, 1, 90)
        k.drums({42: "....XxoxoxoxXxox"}, bars=1, length=.2)
        k.drums({42: SHAKER}, at=4, bars=7, length=.2)
        k.drums({36: "x.......x.....x."}, bars=8, length=.5)
    song.save(str(PACKAGE))
    return song


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    song = build_song()
    if args.render:
        OUT.mkdir(exist_ok=True)
        wav = OUT / "sdsp_aqua.wav"
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
