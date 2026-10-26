( wind.fy - WIND: a wind scene in stereo after Farnell: one wind speed
  driving the rush of air, whistling wires, buzzing doors and leaves.  A
  user machine [Slab docs/25]; the sound is in kernel.fy.  Hold a note for
  as long as the bed should play; the note moves the whistles, C4 as
  Farnell set them. )

include "kernel.fy"
include "machines/lib/manifest.fy"

: manifest
  "WIND" voice-sample machine*
  "k-wind-voice"       render!
  "wind-note-on"       note-on!
  "wind-note-off"      note-off!
  "wind-note-expr"     note-expr!
  "wind-block-prepare" block-prepare!
  4 voices!
  stereo
  WindState.size  state-size!
  WindParams.size params-size!
  780.0 panel-w!

  "SPEED" "SPEED" "wind-speed" WindParams.speed 0.0 1.0 0.25 curve-lin knob
  "SPEED" "SWING" "wind-swing" WindParams.swing 0.0 2.0 1.0 curve-lin knob
  "SPEED" "RATE"  "wind-rate"  WindParams.rate  0.005 0.5 0.1 curve-exp knob
  "SPEED" "GUSTS" "wind-gust"  WindParams.gust  0.0 2.0 1.0 curve-lin knob

  "SCENE" "AIR"     "wind-air"     WindParams.air     0.0 1.0 0.7 curve-pow knob
  "SCENE" "WHISTLE" "wind-whistle" WindParams.whistle 0.0 1.0 0.5 curve-pow knob
  "SCENE" "DOORS"   "wind-doors"   WindParams.doors   0.0 1.0 0.6 curve-pow knob
  "SCENE" "LEAVES"  "wind-leaves"  WindParams.leaves  0.0 1.0 0.4 curve-pow knob
  "SCENE" "WIDTH"   "wind-width"   WindParams.width   0.0 1.0 0.8 curve-lin knob

  "FADE" "ATTACK"  "wind-atk" WindParams.atk 0.01 20.0 2.0 curve-exp knob
  "FADE" "RELEASE" "wind-rel" WindParams.rel 0.01 20.0 3.0 curve-exp knob
  "FADE" "GAIN"    "wind-gain" WindParams.gain 0.0 1.0 0.5 curve-pow knob as-fader
  "FADE" "SEED"    "wind-seed" WindParams.seed 0.0 99.0 0.0 int-step

  "SPEED" 4 strip
  "SCENE" 5 strip
  "FADE" 4 strip
  0.0 row
    4.0 cell  "SPEED" 1.0 item
    5.0 cell  "SCENE" 1.0 item
    4.0 cell  "FADE" 1.0 item
  machine-desc
;
