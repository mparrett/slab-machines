( opndac.fy - OPN DAC: the FM chip's sixth channel as an 8-bit sample
  player, fed by a sound driver.  A user machine [Slab docs/25]; the
  channel is in kernel.fy.  Using it takes channel 6 from opn, so a song
  has five FM voices beside it [tools/budget.py counts]. )

include "kernel.fy"
include "machines/lib/manifest.fy"

: manifest
  "OPN DAC" voice-sample machine*
  "k-dac-voice"       render!
  "dac-note-on"       note-on!
  "dac-note-off"      note-off!
  "dac-block-prepare" block-prepare!
  1 voices!
  stereo
  DacState.size  state-size!
  DacParams.size params-size!
  480.0 panel-w!

  "pcm" DacParams.pool DacParams.zones DacParams.zone-count DacParams.edits "assets/kit.sfz" keymap

  "DRIVER" "RATE"   "dac-rate"   DacParams.rate 4000.0 26000.0 13000.0 curve-lin knob
  "DRIVER" "JITTER" "dac-jitter" DacParams.jitter 0.0 1.0 0.1 curve-lin knob
  "DRIVER" "LEVEL"  "dac-level"  DacParams.level 0.0 1.0 1.0 curve-lin knob
  "PITCH" "TUNE" "dac-tune" DacParams.tune -24.0 24.0 0.0 curve-lin knob
  "PITCH" "ROOT" "dac-root" DacParams.root 24.0 96.0 60.0 curve-lin knob
  "CHIP" "PAN" "dac-pan" DacParams.pan 1.0 switch  "L" 0.0 opt  "L+R" 1.0 opt  "R" 2.0 opt
  "CHIP" "DAC" "dac-chip" DacParams.chip 0.0 switch  "YM2612" 0.0 opt  "YM3438" 1.0 opt
  "CHIP" "GAIN" "dac-gain" DacParams.gain 0.0 1.0 0.5 curve-pow knob as-fader

  "WAVE" "pcm" waveform-display
  "ZONES" "pcm" zone-display
  "DRIVER" 3 strip
  "PITCH" 2 strip
  "CHIP" 3 strip
  1.0 row
    2.0 cell  "WAVE" 1.0 item
    1.0 cell  "ZONES" 1.0 item
  0.0 row
    3.0 cell  "DRIVER" 1.0 item
    2.0 cell  "PITCH" 1.0 item
    3.0 cell  "CHIP" 1.0 item
  machine-desc
;
