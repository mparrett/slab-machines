# slab-machines

Retro console sound chips as user machines for
[Slab](https://github.com/nooga/slab). Each machine models a chip in its own
units (registers, clocks, quantization) so a cue written with it sounds like the
console and stays within what the console could play. Alongside them are a
few machines for long ambient beds.

## Machines

8-bit (`8bit/`):

- **`chip`**: a game-console sound-chip voice: a pulse at four duty cycles, a
  4-bit stepped triangle, or LFSR noise, with pitch, volume and duty moving at
  the 60 Hz frame tick. One track is one channel; the classic layout is two
  pulses, a triangle bass and noise drums.

SNES (`snes/`):

- **`sdsp`**: a sample-playback voice modeled on the S-DSP. It has a 32 kHz
  clock, a 14-bit pitch register, 4-tap Gaussian interpolation from the DSP's
  ROM table, the ADSR in register units, the 15-bit noise source, and a sound
  driver's vibrato. 8 voices, like the hardware.
- **`sdspecho`**: the DSP's echo as an effect: 16 ms steps up to 240 ms, with
  feedback, an 8-tap FIR, and the first-party driver's four filter presets.

`snes/sdsp/assets/` holds the instruments: short looped samples, each
round-tripped through the console's BRR codec, cut from Slab's factory VSCO 2 CE
and Karoryfer samples and VCSL, or synthesized. `tools/brr_pack.py` rebuilds
them; the VCSL ones need the full VCSL in Slab's library
(`~/Music/Slab/Library/vcsl`, or `SLAB_LIBRARY`).

Genesis (`genesis/`):

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

Ambience (`ambience/`), synthesized beds to hold under a scene:

- **`wind`**: a wind scene after Andy Farnell's *Designing Sound*: one wind
  speed, with its gusts, drives the rush of AIR, WHISTLE in wires, DOORS
  buzzing in their frames and LEAVES. Hold a note for as long as the bed
  plays; the note moves the whistles.
- **`fire`**: a fireplace or campfire in stereo: random crackles and snaps
  over a flickering roar and hiss. TONE sets the distance.
  `ambience/songs/fire_vs_storm.py` plays the two together: a fire catches,
  the storm recedes, and the fire gutters out.

Texture (`texture/`), an effect and a voice for long ambient beds:

- **`shimmer`**: a hall that pitch-shifts its own tail back into itself, an
  octave up by default (also -12, +5, +7, +19, +24), so a held chord blooms
  into a choir above it. AMOUNT sets how much of each pass climbs again,
  FREEZE holds the tank indefinitely, and BEND glides the interval up to 12
  semitones either way. The tank is the factory verb2's FDN hall.
  `ambience/songs/shimmer_study.py` compares it with verb2 on a string pad;
  `shimmer_bend.py` automates BEND.
- **`cloud`**: a granular voice that turns any sample into a bed. Each held
  note runs eight grains read around a play head that SCAN moves through the
  file, transposed by the note from ROOT, with SPRAY, JITTER, REVERSE and
  WIDTH scattering them. LOAD on its waveform swaps the source; the default
  is a cut of VSCO 2 CE's violin section on A4. 6 voices.
  `ambience/songs/cloud_study.py` plays it against the plain sampler.

## Install

Slab 0.0.12 and later load machines from `~/Music/Slab/Machines/`. Build
[nooga/slab](https://github.com/nooga/slab) (Zig 0.16), then link the machines:

```sh
git clone https://github.com/nooga/slab && (cd slab && zig build)
git clone https://github.com/mparrett/slab-machines && slab-machines/install.sh
```

`install.sh` links every machine into the machines folder, or only the ones
you name (`install.sh opn psg`). Because they are links, edits here take effect
the next time Slab loads the machine. Run Slab from its checkout
(`zig-out/bin/slab`): the machines' includes resolve against the factory root,
which is the current directory.

## Songs

Each console folder has demo cues in `songs/`. Render one with:

```sh
SLAB_DIR=path/to/slab uv run --no-project --with numpy snes/songs/sdsp_spike.py --render
```

- `8bit/songs/chip_spike.py`: a 16-bar stage loop.
- `snes/songs/sdsp_spike.py`: an overworld loop with a 4-bar intro.
- `snes/songs/sdsp_battle.py`: a fast E-minor battle loop on the synth
  waves, trombone and noise hats, with the slapback echo.
- `snes/songs/sdsp_aqua.py`: an underwater cue under the longest echo, with
  a beating saw pad and VCSL's FM piano, recorder, vibes and percussion.
- `snes/songs/sdsp_jungle.py`: a jungle groove: congas and bongos, a funk
  kit, a round synth bass, a marimba riff and an ocarina lead.
- `genesis/songs/opn_city.py`: a night-city groove on FM, the DAC drums and
  the PSG.

`tools/budget.py <song>.slab` checks a song against its console: for the SNES,
8 voices across all sdsp tracks and 64 KiB of audio RAM for the samples, the
echo buffer and the driver; for the Genesis, 6 FM channels (5 with the DAC), 3
PSG tones and 1 noise. Slab allows more of both, so the check is how a cue stays
one the hardware could have played.

## Credits

The SNES Gaussian table, envelope rates and BRR decoder follow blargg's SPC_DSP
(snes_spc 0.9.0). The FM chip follows Nuked-OPN2, Copyright (C) 2017-2022
Alexey Khokholov (Nuke.YKT), LGPL-2.1+, whose log-sine and exponent tables
`genesis/opn/tables.fy` carries; the PSG follows MAME's sn76496. Instrument
samples are derived from [VSCO 2 CE](https://github.com/sgossner/VSCO-2-CE),
[VCSL](https://github.com/sgossner/VCSL), and Karoryfer Samples' Fashionbass
and Growlybass, all CC0.

## License

GPL-3.0-or-later, as Slab: the machines build on Slab's kernels.
