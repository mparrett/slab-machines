# slab-16bit

16-bit console machines for [Slab](https://github.com/nooga/slab), loaded as
user machines.

SNES:

- **`sdsp`**: a sample-playback voice modeled on the console's S-DSP. It has a
  32 kHz clock, a 14-bit pitch register, 4-tap Gaussian interpolation from the
  DSP's ROM table, the ADSR in register units, and the 15-bit noise source.
  It has 8 voices, like the hardware.
- **`sdspecho`**: the DSP's echo as an effect. The delay runs in 16 ms steps
  up to 240 ms, with feedback, an 8-tap FIR, and the first-party driver's four
  filter presets.

`sdsp/assets/` holds the instruments: short looped samples, each round-tripped
through the console's BRR codec. They're cut from Slab's factory VSCO 2 CE
samples (CC0) or synthesized. `tools/brr_pack.py` rebuilds them.

Genesis:

- **`opn`**: the YM2612 FM chip, one channel per voice and 6 voices. Phase,
  envelope, LFO and the 8 algorithms run in the chip's units, with the 9-bit
  channel output and the YM2612's DAC "ladder" (or the cleaner YM3438). VOL
  attenuates the carriers as a sound driver did, so quiet parts reach the DAC
  coarse. Checked against Nuked-OPN2. SSG-EG and channel 3's special mode
  aren't modelled.
- **`opndac`**: channel 6 as an 8-bit sample player fed by a driver, at a
  jittered rate with no interpolation. `tools/dac_pack.py` builds its drum kit.
- **`psg`**: the SN76489-style square and noise channels, with Sega's 16-bit
  noise LFSR and a 60 Hz driver envelope. 3 voices.

## Install

The machines need a Slab that loads `~/Music/Slab/Machines/`, which is
nooga/slab#7. Until that merges, build the `user-machines` branch of
[mparrett/slab](https://github.com/mparrett/slab):

```sh
git clone -b user-machines https://github.com/mparrett/slab && cd slab && zig build
cd .. && git clone https://github.com/mparrett/slab-16bit && slab-16bit/install.sh
```

`install.sh` links `sdsp/` and `sdspecho/` into the machines folder. Run Slab
from its checkout (`zig-out/bin/slab`), because the machines' includes resolve
against the factory root, which is the current directory.

## Try it

```sh
SLAB_DIR=path/to/slab uv run --no-project --with numpy songs/sdsp_spike.py --render
```

This renders a 4-bar intro and the 16-bar overworld loop to `songs/sdsp_spike/`.
`songs/sdsp_battle.py` is a second cue, a fast E-minor battle loop on the
synth waves, trombone, and noise hats, with the slapback echo.
`songs/sdsp_aqua.py` is an original underwater cue under the longest echo
(the `lagoon` preset), with the aqua instruments: a beating saw pad, and VCSL's
FM piano, recorder, vibes and percussion. Building them takes the full VCSL in
Slab's library (`~/Music/Slab/Library/vcsl`, or `SLAB_LIBRARY`).
`songs/opn_city.py` is the Genesis test cue, a night-city groove on FM,
the DAC drums and the PSG.

`songs/sdsp_jungle.py` is an original jungle groove: congas and a funk kit,
a plucked bass, a marimba riff, and an ocarina lead, from the jungle instruments.

`tools/budget.py songs/sdsp_spike.slab` checks a song against the console:
for the SNES, 8 voices across all sdsp tracks and 64 KiB of audio RAM for the
samples, the echo buffer, and the driver; for the Genesis, 6 FM channels (5
with the DAC), 3 PSG tones and 1 noise. Slab allows more of both, so the check is how a
cue stays one the hardware could have played.

## Credits

The Gaussian table, the envelope rates, and the BRR decoder follow blargg's
SPC_DSP (snes_spc 0.9.0). The FM chip follows Nuked-OPN2 by Nuke.YKT (LGPL-2.1+),
whose log-sine and exponent tables `opn/tables.fy` carries; the PSG follows
MAME's sn76496. Instrument samples are derived from
[VSCO 2 CE](https://github.com/sgossner/VSCO-2-CE),
[VCSL](https://github.com/sgossner/VCSL), and Karoryfer Samples' Fashionbass and
Growlybass, all CC0.

GPL-3.0-or-later, like Slab.
