( psg.fy - PSG: the 16-bit console's SN76489-clone square and noise
  channels, per voice.  A user machine [Slab docs/25]; the chip is in
  kernel.fy.  Three voices, as the chip had three tone channels; a NOISE
  mode track stands for the fourth.  Mono, as on the console. )

include "kernel.fy"
include "machines/lib/manifest.fy"

: manifest
  "PSG" voice-sample machine*
  "k-psg-voice"       render!
  "psg-note-on"       note-on!
  "psg-note-off"      note-off!
  "psg-note-expr"     note-expr!
  "psg-block-prepare" block-prepare!
  3 voices!
  PsgState.size  state-size!
  PsgParams.size params-size!
  480.0 panel-w!

  "CHANNEL" "MODE" "psg-mode" PsgParams.mode 0.0 switch
    "TONE" 0.0 opt  "PERIODIC" 1.0 opt  "WHITE" 2.0 opt
  "CHANNEL" "RATE" "psg-rate" PsgParams.rate 0.0 switch
    "HIGH" 0.0 opt  "MID" 1.0 opt  "LOW" 2.0 opt  "TONE 3" 3.0 opt
  "CHANNEL" "TUNE" "psg-tune" PsgParams.tune -24.0 24.0 0.0 curve-lin knob

  ( the sound driver's envelope, in 60 Hz frames per 2 dB step )
  "ENVELOPE" "AR" "psg-ar" PsgParams.ar 0.0 31.0 0.0 int-step
  "ENVELOPE" "DR" "psg-dr" PsgParams.dr 0.0 31.0 4.0 int-step
  "ENVELOPE" "SL" "psg-sl" PsgParams.sl 0.0 15.0 3.0 int-step
  "ENVELOPE" "RR" "psg-rr" PsgParams.rr 0.0 31.0 1.0 int-step

  "LEVEL" "VOL"  "psg-vol"  PsgParams.vol 0.0 15.0 0.0 int-step
  "LEVEL" "VEL"  "psg-vel"  PsgParams.vel-amt 0.0 1.0 0.5 curve-lin knob
  "LEVEL" "GAIN" "psg-gain" PsgParams.gain 0.0 1.0 0.5 curve-pow knob as-fader

  "CHANNEL" 3 strip
  "ENVELOPE" 4 strip
  "LEVEL" 3 strip
  0.0 row
    3.0 cell  "CHANNEL" 1.0 item
    4.0 cell  "ENVELOPE" 1.0 item
    3.0 cell  "LEVEL" 1.0 item
  machine-desc
;
