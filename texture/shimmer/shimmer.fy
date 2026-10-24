( shimmer.fy - SHIMMER: a hall that pitch-shifts its own tail back into
  itself, an octave up by default, so a held chord blooms into a choir
  above it.  A user machine [Slab docs/25]; the DSP is in kernel.fy.
  AMOUNT is how much of each pass climbs again; FREEZE holds the tank. )

include "kernel.fy"
include "machines/lib/manifest.fy"

: manifest
  "SHIMMER" effect-block machine*
  "k-shim-tick"        render!
  "shim-prepare"       prepare!
  "shim-block-prepare" block-prepare!
  ShimState.size  state-size!
  ShimParams.size params-size!
  640.0 panel-w!
  stereo

  ( one packed buffer, region table in kernel.fy )
  "tank" ShimState.buf ShimState.buf-len 1.18 buffer

  "SPACE" "SIZE"  "shim-size"  ShimParams.space   0.5  2.0  1.2  curve-lin knob
  "SPACE" "DECAY" "shim-decay" ShimParams.decay   0.5  60.0 8.0  curve-exp knob
  "SPACE" "DIFF"  "shim-diff"  ShimParams.diff    0.0  1.0  1.0  curve-lin knob
  "SPACE" "DAMP"  "shim-damp"  ShimParams.damp-hz 1000.0 16000.0 6000.0 curve-exp knob
  "SPACE" 4 strip

  "SHIMMER" "AMOUNT" "shim-amount" ShimParams.amount 0.0 1.0 0.5 curve-lin knob
  "SHIMMER" "INTERVAL" "shim-interval" ShimParams.semis 3.0 switch
    "-12" -12.0 opt  "+5" 5.0 opt  "+7" 7.0 opt  "+12" 12.0 opt
    "+19" 19.0 opt  "+24" 24.0 opt  as-display
  "SHIMMER" "BEND"   "shim-bend"   ShimParams.bend -12.0 12.0 0.0 curve-lin knob
  "SHIMMER" "TONE"   "shim-tone"   ShimParams.tone-hz 1000.0 16000.0 7000.0 curve-exp knob
  "SHIMMER" "WINDOW" "shim-window" ShimParams.win-s   0.02 0.1 0.06 curve-exp knob
  "SHIMMER" 5 strip

  "MOD" "DEPTH" "shim-mod"      ShimParams.mod-depth 0.0 24.0 8.0 curve-lin knob
  "MOD" "RATE"  "shim-mod-rate" ShimParams.mod-rate  0.05 3.0 0.3 curve-exp knob
  "MOD" 2 strip

  "OUT" "LO CUT" "shim-lowcut" ShimParams.lowcut-hz 20.0 1000.0 120.0 curve-exp knob
  "OUT" "WIDTH"  "shim-width"  ShimParams.width 0.0 1.5 1.0 curve-lin knob
  "OUT" "MIX"    "shim-mix"    ShimParams.mix   0.0 1.0 0.4 curve-pow knob
  "OUT" "FREEZE" "shim-freeze" ShimParams.freeze 0.0 switch
    "OFF" 0.0 opt  "HOLD" 1.0 opt  as-button
  "OUT" 4 strip

  1.0 row
    1.0 cell  "SPACE" 1.0 item
    1.0 cell  "SHIMMER" 1.0 item
  1.0 row
    0.5 cell  "MOD" 1.0 item
    1.0 cell  "OUT" 1.0 item

  machine-desc
;
