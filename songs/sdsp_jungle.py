"""S-DSP Jungle: 4-bar intro into a 16-bar jungle groove, 104 BPM, A dorian.

An original cue in the style of the 1994 platformer's jungle stages: a
conga tumbao under a funk kit, a plucked bass locked to the kick, a
marimba riff over an Am7-D7 vamp that answers an ocarina lead, and
trombone stabs. B lifts to Fmaj7-G and turns on E7. The echo is set to
a sixteenth, so its repeats fall in the groove.

The intro is congas alone, then the shaker, then marimba and bass, then
the kit with a bongo pickup. It plays once; the loop runs over A and B.
Within 8 voices (tools/budget.py): kit 2, congas 1, bass 1, marimba 1,
lead 1, stabs 2.

    SLAB_DIR=path/to/slab python3 songs/sdsp_jungle.py --render
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

PACKAGE = HERE / "songs/sdsp_jungle.slab"
OUT = HERE / "songs/sdsp_jungle"

VAMP = "Am7 D7"
PROG_A = "Am7 D7 Am7 D7 Am7 D7 Am7 D7"
PROG_B = "Fmaj7 G Em7 Am7 Fmaj7 G E7 E7"
RIFF = ("A4:.75 C5:.25 r:.25 E5:.25 G5:.5 E5:.5 D5:.25 C5:.25 A4:1  "
        "F#4:.75 A4:.25 r:.25 C5:.25 D5:.5 C5:.5 A4:.25 F#4:.25 D4:1")
LEAD_A = ("E5:1.5 G5:.5 A5:1 r:1  F#5:.5 E5:.5 D5:1 E5:2  r:.5 A5:.5 C6:1 B5:.5 A5:.5 G5:1  A5:3 r:1  "
          "E5:1.5 G5:.5 A5:1 C6:1  D6:.5 C6:.5 A5:1 F#5:1 E5:1  G5:1 A5:.5 G5:.5 E5:1 D5:1  E5:3 r:1")
LEAD_B = ("C6:1.5 A5:.5 E5:2  D6:1.5 B5:.5 G5:2  B5:1 G5:1 E5:1 G5:1  A5:3 r:1  "
          "A5:.5 C6:.5 E6:1 D6:1 C6:1  B5:.5 D6:.5 G6:1 D6:1 B5:1  G#5:2 B5:2  E6:3 r:1")
# under the lead the marimba keeps the riff's opening motif and leaves the
# bar to the tune; the whole riff answers in the bars where the lead holds
MOTIF = {"Am7": "A4:.75 C5:.25 r:.25 E5:.25 r:2.5", "D7": "F#4:.75 A4:.25 r:.25 C5:.25 r:2.5"}
RIFF_D7 = RIFF.split("  ")[1]
ANSWER_A = "  ".join([MOTIF["Am7"], MOTIF["D7"], MOTIF["Am7"], RIFF_D7] * 2)
# the bass locks to the kick, with one octave pop on beat 3
BASS = "x..x..x.o.x..x.."
# conga tumbao, one drum at a time: muted heel-toe, open tones, tumba answers
TUMBAO = {63: "x...x...x...x...", 61: "..x.......x.....", 62: "...x.......x.x..", 60: "......x.......x."}
KIT = {36: "x..x..x...x..x..", 38: "....x..o....x..."}
SHAKER = "xoxoXoxoxoxoXoxo"


class IntroSong(Song):
    """A Song whose loop starts after the intro (slabkit loops from 0)."""
    loop_from = 0.0

    def build(self):
        project = super().build()
        project["transport"]["loop"]["start"] = float(self.loop_from)
        return project


def build_song():
    song = IntroSong("S-DSP Jungle", bpm=104, key="A minor", loop=True)
    intro, a, b = song.section("INTRO", 4), song.section("A", 8), song.section("B", 8)
    song.loop_from = a.start

    # EDL 9 is 144 ms, a sixteenth at 104 BPM, so the repeats land on the grid
    echo = song.bus("ECHO", fx=[fx("sdspecho", "overworld", dry=0, surr=1, edl=9, efb=48)])
    kit = song.track("KIT", "sdsp", "jungle-kit", volume=.95)
    congas = song.track("CONGAS", "sdsp", "jungle-kit", volume=.85, pan=.40)
    bass = song.track("BASS", "sdsp", "funk-bass", volume=.80,
                      fx=[fx("eq2", hpf_on=1, hpf_hz=50)])
    marimba = song.track("MARIMBA - riff", "sdsp", "marimba", volume=.70, pan=-.40)
    lead = song.track("OCARINA - lead", "sdsp", "ocarina", volume=.48, pan=.10)
    stabs = song.track("TROMBONE - stabs", "sdsp", "trombone", volume=.70, pan=-.15)
    for t, db in ((lead, -8), (marimba, -10), (stabs, -12)):
        t.send(echo, db)
    song.master(subsonic=True, fx=[fx("limiter2", gain=0, ceil=-1)])

    # intro: congas alone, then shaker and marimba, then bass, then the kit
    congas.clip(intro, bars=3).drums(TUMBAO, length=.25)
    c = congas.clip(intro, at_bar=3, bars=1)
    c.drums(TUMBAO, bars=1, length=.25)
    c.drums({64: "............x.x.", 65: ".............x.x"}, length=.25)  # bongo pickup
    c.notes = [n for n in c.notes if not (n["pitch"] < 64 and n["start"] >= 3)]
    k = kit.clip(intro, at_bar=1, bars=3)
    k.drums({42: SHAKER}, bars=3, length=.2)
    k.drums(KIT, at=8, bars=1, length=.25)
    marimba.clip(intro, at_bar=2, bars=2).melody(RIFF, gate=.5)
    bass.clip(intro, at_bar=2, bars=2).bass(VAMP, BASS, octave=2)
    congas.ride({intro: (-8, 0)})

    lead.clip(a).melody(LEAD_A, gate=.9)
    lead.clip(b).melody(LEAD_B, gate=.9)
    for sec, prog in ((a, PROG_A), (b, PROG_B)):
        congas.clip(sec).drums(TUMBAO, length=.25)
        bass.clip(sec).bass(prog, BASS, octave=2)
        stabs.clip(sec).chords(prog, "......x.......x.", near=55, voices=2)
        k = kit.clip(sec)
        k.drums(KIT, bars=7, length=.25)
        k.drums({42: SHAKER}, bars=7, length=.2)
        # the fill bar drops the shaker for its second half, so the snare
        # run keeps the kit at two voices
        k.drums({36: "x..x..x...x.....", 38: "....x.....x.xxxx"}, at=28, bars=1, length=.25)
        k.drums({42: "xoxoXoxo........"}, at=28, bars=1, length=.2)
    marimba.clip(a).melody(ANSWER_A, gate=.5)
    # B: the marimba doubles the stabs' off-beats on each chord's third
    m = marimba.clip(b)
    for i, (ch, _) in enumerate(song.key.timed(PROG_B)):
        for beat in (1.5, 3.5):
            m.note(ch.tone(1, 4), i * 4 + beat, .25, 90)
    song.save(str(PACKAGE))
    return song


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    song = build_song()
    if args.render:
        OUT.mkdir(exist_ok=True)
        wav = OUT / "sdsp_jungle.wav"
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
