( fire.fy - FIRE: a hearth or campfire in stereo: random crackles over a
  flickering roar.  A user machine [Slab docs/25]; the sound is in
  kernel.fy.  Hold a note for as long as the fire burns; TONE is the
  distance. )

include "kernel.fy"
include "machines/lib/manifest.fy"

: manifest
  "FIRE" voice-sample machine*
  "k-fire-voice"       render!
  "fire-note-on"       note-on!
  "fire-note-off"      note-off!
  "fire-block-prepare" block-prepare!
  4 voices!
  stereo
  FireState.size  state-size!
  FireParams.size params-size!
  896.0 panel-w!

  "FLAME" "ROAR"    "fire-roar"    FireParams.roar    0.0 1.0 0.4 curve-pow knob
  "FLAME" "HISS"    "fire-hiss"    FireParams.hiss    0.0 1.0 0.4 curve-pow knob

  "POPS" "CRACKLE" "fire-crackle" FireParams.crackle 0.5 200.0 25.0 curve-exp knob
  "POPS" "SNAP"    "fire-snap"    FireParams.snap    0.0 1.0 0.4 curve-lin knob
  "POPS" "TICK"    "fire-tick"    FireParams.tick    1.0 30.0 30.0 curve-exp knob
  "POPS" "CLUMP"   "fire-clump"   FireParams.clump   0.0 1.0 0.0 curve-lin knob
  "POPS" "SPREAD"  "fire-spread"  FireParams.spread  0.0 1.0 0.0 curve-lin knob

  "SPACE" "FLICKER" "fire-flicker" FireParams.flicker 0.0 1.0 0.5 curve-lin knob
  "SPACE" "TONE"    "fire-tone"    FireParams.tone    500.0 20000.0 16000.0 curve-exp knob
  "SPACE" "WIDTH"   "fire-width"   FireParams.width   0.0 1.0 0.6 curve-lin knob

  "FADE" "ATTACK"  "fire-atk"  FireParams.atk  0.01 20.0 1.5 curve-exp knob
  "FADE" "RELEASE" "fire-rel"  FireParams.rel  0.01 20.0 2.5 curve-exp knob
  "FADE" "GAIN"    "fire-gain" FireParams.gain 0.0 1.0 0.5 curve-pow knob as-fader
  "FADE" "SEED"    "fire-seed" FireParams.seed 0.0 99.0 0.0 int-step

  "FLAME" 2 strip
  "POPS" 5 strip
  "SPACE" 3 strip
  "FADE" 4 strip
  0.0 row
    2.0 cell  "FLAME" 1.0 item
    5.0 cell  "POPS" 1.0 item
    3.0 cell  "SPACE" 1.0 item
    4.0 cell  "FADE" 1.0 item
  machine-desc
;
