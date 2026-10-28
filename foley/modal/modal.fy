( modal.fy - MODAL: a body of wood, stone, metal, glass or hide, struck,
  scraped, rolled on or rubbed.  A user machine [Slab docs/25]; the sound
  is in kernel.fy.  The note sets the body's pitch; a strike rings out
  past the note, the other exciters play while it's held. )

include "kernel.fy"
include "machines/lib/manifest.fy"

: manifest
  "MODAL" voice-sample machine*
  "k-modal-voice"    render!
  "md-note-on"       note-on!
  "md-note-off"      note-off!
  "md-block-prepare" block-prepare!
  8 voices!
  stereo
  ModalState.size  state-size!
  ModalParams.size params-size!
  1024.0 panel-w!

  "BODY" "MATERIAL" "md-material" ModalParams.material 0.0 switch
    "WOOD" 0.0 opt  "STONE" 1.0 opt  "METAL" 2.0 opt  "GLASS" 3.0 opt  "HIDE" 4.0 opt
  "BODY" "SIZE"     "md-size"     ModalParams.scale 0.125 8.0 1.0 curve-exp knob
  "BODY" "DECAY"    "md-decay"    ModalParams.decay 0.1 10.0 1.0 curve-exp knob
  "BODY" "DAMP"     "md-damp"     ModalParams.damp  0.0 1.0 0.5 curve-lin knob
  "BODY" "POSITION" "md-pos"      ModalParams.pos   0.02 0.5 0.2 curve-lin knob

  "EXCITE" "EXCITE" "md-excite" ModalParams.excite 0.0 switch
    "STRIKE" 0.0 opt  "SCRAPE" 1.0 opt  "ROLL" 2.0 opt  "RUB" 3.0 opt
  "EXCITE" "HARD"   "md-hard"   ModalParams.hard   0.0 1.0 0.5 curve-lin knob
  "EXCITE" "BOUNCE" "md-bounce" ModalParams.bounce 0.0 1.0 0.0 curve-lin knob
  "EXCITE" "SPEED"  "md-speed"  ModalParams.speed  0.0 1.0 0.4 curve-lin knob
  "EXCITE" "ROUGH"  "md-rough"  ModalParams.rough  0.0 1.0 0.3 curve-lin knob

  "COLOR" "DROP"   "md-drop"   ModalParams.drop   0.0 1.0 0.0 curve-lin knob
  "COLOR" "RATTLE" "md-rattle" ModalParams.rattle 0.0 1.0 0.0 curve-pow knob
  "COLOR" "VARY"   "md-vary"   ModalParams.vary   0.0 1.0 0.3 curve-lin knob
  "COLOR" "WIDTH"  "md-width"  ModalParams.width  0.0 1.0 0.6 curve-lin knob

  "OUT" "TONE" "md-tone" ModalParams.tone 500.0 20000.0 20000.0 curve-exp knob
  "OUT" "GAIN" "md-gain" ModalParams.gain 0.0 1.0 0.5 curve-pow knob as-fader
  "OUT" "SEED" "md-seed" ModalParams.seed 0.0 99.0 0.0 int-step

  "BODY" 5 strip
  "EXCITE" 5 strip
  "COLOR" 4 strip
  "OUT" 3 strip
  0.0 row
    5.0 cell  "BODY" 1.0 item
    5.0 cell  "EXCITE" 1.0 item
    4.0 cell  "COLOR" 1.0 item
    3.0 cell  "OUT" 1.0 item
  machine-desc
;
