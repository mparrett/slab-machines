# slab-chip

A game-console sound-chip instrument for [Slab](https://github.com/nooga/slab):
a pulse at four duty cycles, a 4-bit stepped triangle, or LFSR noise, with
pitch, volume and duty moving at the 60 Hz frame tick the chips ran at.
One track is one chip channel. The classic layout is two pulses, a
triangle bass and noise drums.

## Install

Slab loads machines from `~/Music/Slab/Machines/` starting with the
`user-machines` change, which is not in a Slab release yet. Until it is,
build Slab from that branch:

```sh
git clone -b user-machines https://github.com/mparrett/slab slab-user-machines
(cd slab-user-machines && zig build)   # Zig 0.16
./install.sh                           # links ./chip into ~/Music/Slab/Machines/chip
```

Point `SLAB_DIR` at that checkout to render the songs here.

The machine then shows up in Slab's instrument list, in `slab --describe`
and in slabkit as `chip`. Because it is a link, edits here take effect the
next time Slab loads the machine.

## Layout

- `chip/chip.fy`: the machine's manifest, panel and controls.
- `chip/kernel.fy`: the voice. It includes Slab's shipped primitives
  (`kernels/...`), which Slab resolves against its own tree.
- `chip/presets/`: leads, square and triangle bass, arpeggios, noise hat
  and snare, a swept-triangle kick, a pickup blip.
- `songs/chip_spike.py`: a 16-bar stage loop that exercises it.

```sh
SLAB_DIR=path/to/slab-user-machines python3 songs/chip_spike.py --render   # needs numpy
```

## License

GPL-3.0-or-later, as Slab: the machine builds on Slab's kernels.
