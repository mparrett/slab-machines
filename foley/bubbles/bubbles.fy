( bubbles.fy - BUBBLES: water as swarms of bubbles, from a drip to a
  boil.  A user machine [Slab docs/25]; the sound is in kernel.fy.  Hold
  a note while the water runs; the note sets the bubbles' size, C4 as
  SIZE says. )

include "kernel.fy"
include "machines/lib/manifest.fy"

: manifest
  "BUBBLES" voice-sample machine*
  "k-bubbles-voice"  render!
  "bb-note-on"       note-on!
  "bb-note-off"      note-off!
  "bb-block-prepare" block-prepare!
  4 voices!
  stereo
  BubbleState.size  state-size!
  BubbleParams.size params-size!
  1024.0 panel-w!

  "WATER" "RATE"   "bb-rate"   BubbleParams.rate   0.5 2000.0 12.0 curve-exp knob
  "WATER" "SIZE"   "bb-size"   BubbleParams.radius 0.3 30.0 3.0 curve-exp knob
  "WATER" "SPREAD" "bb-spread" BubbleParams.spread 0.0 1.0 0.4 curve-lin knob
  "WATER" "RISE"   "bb-rise"   BubbleParams.rise   0.0 1.0 0.3 curve-lin knob
  "WATER" "RING"   "bb-ring"   BubbleParams.ring   0.25 4.0 1.0 curve-exp knob
  "WATER" "CLUMP"  "bb-clump"  BubbleParams.clump  0.0 1.0 0.0 curve-lin knob

  "SPACE" "WIDTH" "bb-width" BubbleParams.width 0.0 1.0 0.6 curve-lin knob
  "SPACE" "TONE"  "bb-tone"  BubbleParams.tone  500.0 20000.0 16000.0 curve-exp knob

  "FADE" "ATTACK"  "bb-atk"  BubbleParams.atk  0.01 20.0 0.5 curve-exp knob
  "FADE" "RELEASE" "bb-rel"  BubbleParams.rel  0.01 20.0 1.0 curve-exp knob
  "FADE" "GAIN"    "bb-gain" BubbleParams.gain 0.0 1.0 0.5 curve-pow knob as-fader
  "FADE" "SEED"    "bb-seed" BubbleParams.seed 0.0 99.0 0.0 int-step

  "WATER" 6 strip
  "SPACE" 2 strip
  "FADE" 4 strip
  0.0 row
    6.0 cell  "WATER" 1.0 item
    2.0 cell  "SPACE" 1.0 item
    4.0 cell  "FADE" 1.0 item
  machine-desc
;
