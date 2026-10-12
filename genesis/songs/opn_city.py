"""OPN City: 4-bar intro into a 16-bar night-city groove, 124 BPM, A minor.

The listening test for the Genesis machines: an original cue in the style
of the early-90s brawler soundtracks. FM: a plucked octave bass, a string
pad in three channels, and a fed-back lead [opn, 5 channels with the
DAC's]. DAC: a synth kick and claps, never together, as it is one channel
[opndac]. PSG: off-beat noise hats, an arpeggio, and a quiet copy of the
lead a dotted eighth late, the console's stand-in for echo [psg].

Levels are the chips' own: FM channels sit back by VOL [carrier TL], so
the quieter ones reach the 9-bit DAC coarse, as on the console.

The intro adds a part a bar: hats and kick, bass, pad and arpeggio, then
claps and a snare fill. It plays once; the loop runs over A and B.
Within budget (tools/budget.py): FM 5 of 5, DAC 1, PSG tone 2 of 3,
noise 1.

    SLAB_DIR=path/to/slab python3 songs/opn_city.py --render
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

PACKAGE = HERE / "songs/opn_city.slab"
OUT = HERE / "songs/opn_city"

PROG_I = "Am7 Fmaj7 Dm7 E7"
PROG_A = "Am7 Fmaj7 Dm7 E7 Am7 Fmaj7 Dm7 E7"
PROG_B = "Fmaj7 G Em7 Am7 Dm7 G Cmaj7 E7"
LEAD_A = ("A5:1.5 C6:.5 E6:1 r:1  D6:.5 C6:.5 A5:1 r:2  F5:.5 A5:.5 C6:1 D6:1 C6:.5 A5:.5  B5:2 G#5:1 r:1  "
          "A5:1.5 C6:.5 E6:1 G6:1  F6:.5 E6:.5 C6:1 r:2  D6:.5 C6:.5 A5:.5 F5:.5 A5:1 C6:1  B5:3 r:1")
LEAD_B = ("C6:2 A5:1 C6:1  D6:3 r:1  E6:1 D6:1 B5:1 G5:1  A5:3 r:1  "
          "F6:2 E6:1 D6:1  D6:1 B5:1 G5:1 B5:1  C6:2 E6:2  G#6:2 B5:1 E6:1")
BASS = "x.o.x.o.x.o.x.ox"
KICK = "x.....x...x....."
CLAP = "....x.......x..."
HATS = "..x...x...x...x."
ECHO = .75


class IntroSong(Song):
    """A Song whose loop starts after the intro (slabkit loops from 0)."""
    loop_from = 0.0

    def build(self):
        project = super().build()
        project["transport"]["loop"]["start"] = float(self.loop_from)
        return project


def build_song():
    song = IntroSong("OPN City", bpm=124, key="A minor", loop=True)
    intro, a, b = song.section("INTRO", 4), song.section("A", 8), song.section("B", 8)
    song.loop_from = a.start

    drums = song.track("DAC - drums", "opndac", "kit", volume=1.0, params={"dac-gain": 1.0})
    hats = song.track("PSG - hats", "psg", "noise-hat", volume=1.0, params={"psg-gain": 0.7})
    bass = song.track("FM - bass", "opn", "fm-bass", volume=1.0)
    pad = song.track("FM - strings", "opn", "fm-strings", volume=1.0, params={"opn-vol": 10})
    lead = song.track("FM - lead", "opn", "fm-lead", volume=1.0, params={"opn-vol": 2})
    echo = song.track("PSG - echo", "psg", "square-lead", volume=1.0, params={"psg-vol": 5})
    arp = song.track("PSG - arp", "psg", "square-arp", volume=1.0, params={"psg-vol": 3})
    song.master(subsonic=True, fx=[fx("limiter2", gain=0, ceil=-1)])

    # intro: hats and kick, then bass, then pad and arpeggio, then claps
    hats.clip(intro).drums({60: HATS}, length=.2)
    d = drums.clip(intro)
    d.drums({35: KICK}, bars=4, length=.5)
    d.drums({39: CLAP}, at=12, bars=1, length=.5)
    d.notes = [n for n in d.notes if not (n["start"] >= 14)]
    d.drums({38: "........x.x.xxxx"}, at=12, length=.25)
    bass.clip(intro, at_bar=1, bars=3).bass("Fmaj7 Dm7 E7", BASS, octave=2)
    pad.clip(intro, at_bar=2, bars=2).chords("Dm7 E7", near=60, voices=3)
    arp.clip(intro, at_bar=2, bars=2).arp("Dm7 E7", "up", rate=.25, octave=5)

    lead.clip(a).melody(LEAD_A, gate=.9)
    lead.clip(b).melody(LEAD_B, gate=.9)
    echo.clip(a).melody(LEAD_A, at=ECHO, gate=.9)
    echo.clip(b).melody(LEAD_B, at=ECHO, gate=.9)
    arp.clip(b).arp(PROG_B, "up", rate=.25, octave=5)
    for sec, prog in ((a, PROG_A), (b, PROG_B)):
        hats.clip(sec).drums({60: HATS}, length=.2)
        bass.clip(sec).bass(prog, BASS, octave=2)
        pad.clip(sec).chords(prog, near=60, voices=3)
        d = drums.clip(sec)
        d.drums({35: KICK, 39: CLAP}, bars=7, length=.5)
        d.drums({35: "x.....x.........", 39: "....x...........", 38: "........x.x.xxxx"}, at=28, bars=1, length=.25)
    song.save(str(PACKAGE))
    return song


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    song = build_song()
    if args.render:
        OUT.mkdir(exist_ok=True)
        wav = OUT / "opn_city.wav"
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
