"""Build the sdsp instrument pack: short looped samples through the BRR codec.

The console stored every sample as BRR: 16-sample blocks of 4-bit nibbles
with a shift and one of four prediction filters per block, in 64 KB of
audio RAM shared with the music and the echo buffer. So an instrument was
one short sample: an attack and a loop of a few whole periods. This tool
makes such instruments from Slab's factory VSCO 2 CE samples (CC0) and
from synthesized waves and drums, round-trips each through a BRR encoder
and the DSP's decoder, and writes 16-bit WAVs whose `smpl` chunk carries
the root and the loop. The codec noise is then in the file, and the sdsp
voice doesn't need to model it.

    SLAB_DIR=path/to/slab uv run --no-project --with numpy tools/brr_pack.py

Loops must start and end on block boundaries, so each looped instrument
is resampled to a rate where a whole number of periods fills a whole
number of blocks, and the WAV's root carries the pitch that rate gives.
The decoder follows blargg's SPC_DSP (snes_spc 0.9.0, LGPL), bit for bit.
"""
from pathlib import Path
import math
import os
import re
import struct
import subprocess
import sys

import numpy as np

HERE = Path(__file__).resolve().parents[1]
OUT = HERE / "sdsp/assets"

# Pitched instruments from the factory VSCO 2 CE keymaps. key: the note to
# take the sample nearest; rate: the stored rate before loop fitting;
# attack: seconds before the loop; loop: seconds of loop, as whole periods.
# A loop of 0 is a one-shot of `attack` seconds.
SAMPLED = {
    "strings":  dict(src="vsco/violin-section-susvib.sfz", key=69, rate=16000, attack=.25, loop=.20),
    "cello":    dict(src="vsco/cello-section-susvib.sfz", key=48, rate=12000, attack=.25, loop=.20),
    "trumpet":  dict(src="vsco/trumpet-sus.sfz", key=67, rate=16000, attack=.12, loop=.12),
    "trombone": dict(src="vsco/tenor-trombone-sus.sfz", key=55, rate=12000, attack=.15, loop=.12),
    "spic":     dict(src="vsco/violin-section-spic.sfz", key=72, rate=16000, attack=.30, loop=0),
    "pizz":     dict(src="vsco/solo-contrabass-pizz.sfz", key=43, rate=8000, attack=.70, loop=0),
}

# Single-cycle waves, the console's synth sounds: one 64-sample cycle at
# 32 kHz, looped from the start.
CYCLE = 64
WAVE_RATE = 32000

# Drums, synthesized, one-shot at a low rate for the grit.
DRUM_RATE = 16000
DRUM_KEYS = {"kick": 36, "snare": 38, "tom-lo": 41, "hat": 42, "tom-hi": 45, "open-hat": 46, "crash": 49}


# ── BRR ──────────────────────────────────────────────────────────────────

def _clamp16(v):
    return -32768 if v < -32768 else 32767 if v > 32767 else v


def _i16(v):
    v &= 0xFFFF
    return v - 65536 if v >= 32768 else v


def _decode(n, shift, filt, p2s, p1):
    """One sample of the DSP's BRR decoder. p1, p2s: the previous two
    stored outputs (the DSP keeps them doubled; p2 is halved here)."""
    s = (n << shift) >> 1 if shift <= 12 else (n & ~0x7FF)
    p2 = p2s >> 1
    if filt >= 2:
        s += p1 - p2
        if filt == 2:
            s += (p2 >> 4) + ((p1 * -3) >> 6)
        else:
            s += ((p1 * -13) >> 7) + ((p2 * 3) >> 4)
    elif filt == 1:
        s += (p1 >> 1) + ((-p1) >> 5)
    return _i16(_clamp16(s) * 2)


def _try_block(target, shift, filt, hist):
    """Greedy encode of one block at this shift and filter: each nibble is
    the best of the two around the ideal. Returns (error, nibbles, out, hist)."""
    p2s, p1 = hist
    err = 0
    nibs, out = [], []
    step = (1 << shift) >> 1 or 1
    for t in target:
        base = _decode(0, shift, filt, p2s, p1)
        ideal = (t - base) / 2 / step
        best = None
        for n in {max(-8, min(7, math.floor(ideal))), max(-8, min(7, math.ceil(ideal)))}:
            s = _decode(n, shift, filt, p2s, p1)
            e = (s - t) ** 2
            if best is None or e < best[0]:
                best = (e, n, s)
        e, n, s = best
        err += e
        nibs.append(n)
        out.append(s)
        p2s, p1 = p1, s
    return err, nibs, out, (p2s, p1)


def brr_roundtrip(x, loop_start=None):
    """x: float samples, length a multiple of 16. The decoded result,
    as the DSP would play it. The first block and the loop's first block
    use filter 0, as encoders do: the decoder enters them without the
    history the other filters predict from."""
    t = np.clip(np.round(x * 32767), -32768, 32767).astype(int).tolist()
    hist = (0, 0)
    out = []
    for b in range(0, len(t), 16):
        block = t[b:b + 16]
        filters = (0,) if b == 0 or b == loop_start else (0, 1, 2, 3)
        best = None
        for filt in filters:
            for shift in range(13):
                r = _try_block(block, shift, filt, hist)
                if best is None or r[0] < best[0]:
                    best = r
        out.extend(best[2])
        hist = best[3]
    return np.array(out, dtype=float) / 32768.0


# ── sources ──────────────────────────────────────────────────────────────

def decode_audio(path, rate):
    """Mono float32 at `rate`, through ffmpeg's resampler."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(rate),
                          "-f", "f32le", "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(float)


def sfz_regions(path):
    regions = []
    for line in path.read_text().splitlines():
        if line.startswith("<region>"):
            regions.append(dict(re.findall(r"(\w+)=(\S+)", line)))
    return regions


def pick_region(sfz, key):
    """The region whose root is nearest `key`, loudest layer."""
    regs = sfz_regions(sfz)
    return min(regs, key=lambda r: (abs(int(r["pitch_keycenter"]) - key), -int(r.get("hivel", 127))))


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def hz_midi(f):
    return 69 + 12 * math.log2(f / 440.0)


def find_loop(x, start, length, period):
    """The loop start within a period of `start` whose loop of `length`
    joins most smoothly: the best match between the audio there and
    `length` later."""
    w = max(16, int(period * 2))
    best, best_ls = None, start
    for ls in range(max(w, start - int(period)), start + int(period) + 1):
        a, b = x[ls - w // 2:ls + w // 2], x[ls + length - w // 2:ls + length + w // 2]
        if len(b) < len(a):
            break
        d = np.sum((a - b) ** 2) / (np.sum(a * a) + 1e-9)
        if best is None or d < best:
            best, best_ls = d, ls
    return best_ls


def sampled_instrument(slab_assets, name, spec):
    sfz = slab_assets / spec["src"]
    r = pick_region(sfz, spec["key"])
    root = int(r["pitch_keycenter"]) - float(r.get("tune", 0)) / 100
    f0 = midi_hz(root)
    src = sfz.parent / r["sample"]
    if not spec["loop"]:
        rate = spec["rate"]
        x = decode_audio(src, rate)
        x = trim_onset(x)[:int(spec["attack"] * rate)]
        n = len(x)
        x = x * np.concatenate([np.ones(n - n // 5), np.linspace(1, 0, n // 5)])
        return rate, pad16(normalize(x)), root, None
    # The loop: N periods that fill a whole number of blocks exactly, at a
    # stored rate near spec["rate"] chosen so.
    n_per = max(1, round(spec["loop"] * f0))
    blocks = max(1, round(n_per * spec["rate"] / f0 / 16))
    rate = blocks * 16 * f0 / n_per
    x = decode_audio(src, int(rate))
    # ffmpeg takes whole rates: move the last fraction by interpolation
    t = np.arange(0, len(x) - 1, int(rate) / rate)
    x = trim_onset(np.interp(t, np.arange(len(x)), x))
    length = blocks * 16
    ls = find_loop(x, int(spec["attack"] * rate), length, rate / f0)
    # crossfade the loop's tail into what precedes its start, so the jump
    # back lands where the tail was heading
    fade = min(length // 2, ls)
    seg = x[:ls + length].copy()
    ramp = np.linspace(0, 1, fade)
    seg[ls + length - fade:] = seg[ls + length - fade:] * (1 - ramp) + x[ls - fade:ls] * ramp
    # block-align the loop start with leading silence
    pad = (-ls) % 16
    seg = np.concatenate([np.zeros(pad), seg])
    ls += pad
    return rate, normalize(seg), hz_midi(f0 * round(rate) / rate), ls


def trim_onset(x, thresh=0.01):
    """Drop the silence before the note."""
    loud = np.nonzero(np.abs(x) > thresh * np.max(np.abs(x)))[0]
    return x[max(0, loud[0] - 8):] if len(loud) else x


def normalize(x, peak=0.9):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def pad16(x):
    return np.concatenate([x, np.zeros((-len(x)) % 16)])


# ── synthesized ──────────────────────────────────────────────────────────

def waves():
    ph = np.arange(CYCLE) / CYCLE
    saw = 1 - 2 * ph
    square = np.where(ph < .5, 1.0, -1.0)
    organ = sum(a * np.sin(2 * np.pi * h * ph) for h, a in ((1, 1), (2, .5), (3, .35), (4, .2), (6, .12)))
    # a few harmonics fewer than the naive waves, as the drivers' tables
    # were drawn: a full-band saw at 4x would alias the 32 kHz clock
    def soften(w, keep):
        spec = np.fft.rfft(w)
        spec[keep:] = 0
        return np.fft.irfft(spec, CYCLE)
    return {"saw": soften(saw, 12), "square": soften(square, 12), "organ": organ}


def drums():
    sr = DRUM_RATE
    rng = np.random.default_rng(7)

    def t(sec):
        return np.arange(int(sec * sr)) / sr

    def env(tt, d):
        return np.exp(-tt / d)

    def onepole(x, hz, high=False):
        a = math.exp(-2 * math.pi * hz / sr)
        y = np.zeros_like(x)
        z = 0.0
        for i, v in enumerate(x):
            z = (1 - a) * v + a * z
            y[i] = v - z if high else z
        return y

    out = {}
    tt = t(.35)
    f = 45 + 110 * np.exp(-tt / .03)
    out["kick"] = np.sin(2 * np.pi * np.cumsum(f) / sr) * env(tt, .12) + .3 * rng.standard_normal(len(tt)) * env(tt, .004)
    tt = t(.25)
    noise = onepole(rng.standard_normal(len(tt)), 900, high=True)
    out["snare"] = .7 * noise * env(tt, .07) + .6 * np.sin(2 * np.pi * 185 * tt) * env(tt, .05)
    tt = t(.06)
    out["hat"] = onepole(rng.standard_normal(len(tt)), 5000, high=True) * env(tt, .015)
    tt = t(.4)
    out["open-hat"] = onepole(rng.standard_normal(len(tt)), 5000, high=True) * env(tt, .12)
    tt = t(1.2)
    out["crash"] = onepole(onepole(rng.standard_normal(len(tt)), 3000, high=True), 7000) * env(tt, .4)
    for name, hz in (("tom-lo", 95), ("tom-hi", 140)):
        tt = t(.35)
        ff = hz * (1 + .4 * np.exp(-tt / .04))
        out[name] = np.sin(2 * np.pi * np.cumsum(ff) / sr) * env(tt, .12)
    return {k: pad16(normalize(v)) for k, v in out.items()}


# ── output ───────────────────────────────────────────────────────────────

def write_wav(path, x, rate, root=None, loop=None):
    """16-bit mono with a `smpl` chunk: the root as MIDI note + fraction,
    and the loop [start, end) when there is one."""
    pcm = np.clip(np.round(x * 32768), -32768, 32767).astype("<i2").tobytes()
    chunks = struct.pack("<4sIHHIIHH", b"fmt ", 16, 1, 1, int(round(rate)), int(round(rate)) * 2, 2, 16)
    if root is not None:
        unity = math.floor(root)
        frac = int((root - unity) * 2 ** 32) & 0xFFFFFFFF
        loops = b""
        if loop is not None:
            loops = struct.pack("<IIIIII", 0, 0, loop[0], loop[1] - 1, 0, 0)
        body = struct.pack("<IIIIIIIII", 0, 0, int(1e9 / rate), unity, frac, 0, 0, 1 if loop else 0, 0) + loops
        chunks += struct.pack("<4sI", b"smpl", len(body)) + body
    chunks += struct.pack("<4sI", b"data", len(pcm)) + pcm
    path.write_bytes(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


def main():
    if "SLAB_DIR" not in os.environ:
        sys.exit("set SLAB_DIR to a Slab checkout (for its factory VSCO samples)")
    assets = Path(os.environ["SLAB_DIR"]).expanduser() / "machines/sampler/assets"
    OUT.mkdir(parents=True, exist_ok=True)
    report = []
    for name, spec in SAMPLED.items():
        rate, x, root, ls = sampled_instrument(assets, name, spec)
        y = brr_roundtrip(x, ls)
        loop = (ls, len(y)) if ls is not None else None
        write_wav(OUT / f"{name}.wav", y, rate, root, loop)
        report.append((name, rate, len(y), root, loop, x, y))
    for name, w in waves().items():
        x = normalize(w)
        y = brr_roundtrip(x, 0)
        root = hz_midi(WAVE_RATE / CYCLE)
        write_wav(OUT / f"{name}.wav", y, WAVE_RATE, root, (0, CYCLE))
        report.append((name, WAVE_RATE, CYCLE, root, (0, CYCLE), x, y))
    (OUT / "drums").mkdir(exist_ok=True)
    lines = ["// sdsp drum kit: synthesized, BRR round-tripped at 16 kHz (tools/brr_pack.py)"]
    for name, x in drums().items():
        y = brr_roundtrip(x)
        key = DRUM_KEYS[name]
        write_wav(OUT / "drums" / f"{name}.wav", y, DRUM_RATE)
        lines.append(f"<region> lokey={key} hikey={key} pitch_keycenter={key} loop_mode=one_shot sample=drums/{name}.wav")
        report.append((f"drums/{name}", DRUM_RATE, len(y), key, None, x, y))
    (OUT / "drums.sfz").write_text("\n".join(lines) + "\n")
    total = 0
    for name, rate, n, root, loop, x, y in report:
        snr = 10 * math.log10(np.sum(x * x) / (np.sum((x - y[:len(x)]) ** 2) + 1e-12))
        brr = n // 16 * 9
        total += brr
        print(f"{name:16s} {rate:8.1f} Hz  {n:6d} smp  {brr:6d} B BRR  root {root:6.2f}  "
              f"loop {loop}  BRR SNR {snr:4.1f} dB")
    print(f"total {total} bytes of BRR (the console had 64 KB, shared with the music and the echo)")


if __name__ == "__main__":
    main()
