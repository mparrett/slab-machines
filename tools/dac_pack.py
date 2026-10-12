"""Build the opndac drum kit: one-shots at the driver's 13 kHz.

The Genesis stored DAC drums as raw 8-bit PCM in cartridge ROM, played by
the sound driver at a rate of its own [opndac/kernel.fy]. This writes them
as 16-bit WAVs at 13 kHz, the default RATE, so they play at pitch; the
voice does the 8-bit rounding, so a LEVEL below 1 is as coarse as it was.
Sources: VCSL's studio kit and claps (CC0, from Slab's library), and the
synthesized kick from brr_pack.

    SLAB_DIR=path/to/slab uv run --no-project --with numpy tools/dac_pack.py
"""
from pathlib import Path
import os
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from brr_pack import decode_audio, drums, normalize, pick_region, source, trim_onset, write_wav  # noqa: E402

HERE = Path(__file__).resolve().parents[1]
OUT = HERE / "opndac/assets"
RATE = 13000

# kit key: (source, the source's key, seconds); None takes brr_pack's synth kick
KIT = {
    35: (None, 0, .30),
    36: ("lib:vcsl/vcsl-kits/studio-kit.sfz", 36, .30),
    38: ("lib:vcsl/vcsl-kits/studio-kit.sfz", 38, .25),
    39: ("lib:vcsl/vcsl-perc/claps.sfz", 36, .30),
    40: ("lib:vcsl/vcsl-kits/studio-kit.sfz", 40, .25),
    41: ("lib:vcsl/vcsl-kits/studio-kit.sfz", 41, .40),
    43: ("lib:vcsl/vcsl-kits/studio-kit.sfz", 43, .40),
    45: ("lib:vcsl/vcsl-kits/studio-kit.sfz", 45, .40),
    48: ("lib:vcsl/vcsl-kits/studio-kit.sfz", 48, .40),
    49: ("lib:vcsl/vcsl-kits/studio-kit.sfz", 49, 1.0),
}
NAMES = {35: "synth kick", 36: "kick", 38: "snare", 39: "clap", 40: "rimshot",
         41: "low tom", 43: "low-mid tom", 45: "mid tom", 48: "high tom", 49: "crash"}


def main():
    if "SLAB_DIR" not in os.environ:
        sys.exit("set SLAB_DIR to a Slab checkout")
    assets = Path(os.environ["SLAB_DIR"]).expanduser() / "machines/sampler/assets"
    OUT.mkdir(parents=True, exist_ok=True)
    lines = ["// opndac kit: one-shots at 13 kHz for the DAC channel (tools/dac_pack.py)",
             "// " + ", ".join(f"{k} {v}" for k, v in NAMES.items())]
    for key, (src, src_key, secs) in KIT.items():
        if src is None:
            k = drums()["kick"]
            x = np.interp(np.arange(0, len(k), 16000 / RATE), np.arange(len(k)), k)
        else:
            r = pick_region(source(assets, src), src_key)
            x = trim_onset(decode_audio(source(assets, src).parent / r["sample"], RATE))
        x = x[:int(secs * RATE)]
        n = len(x)
        x = normalize(x * np.concatenate([np.ones(n - n // 4), np.linspace(1, 0, n // 4)]))
        name = f"dac-{key}.wav"
        write_wav(OUT / name, x, RATE)
        lines.append(f"<region> lokey={key} hikey={key} pitch_keycenter={key} loop_mode=one_shot sample={name}")
        print(f"{key} {NAMES[key]:12s} {n / RATE:.2f} s")
    (OUT / "kit.sfz").write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
