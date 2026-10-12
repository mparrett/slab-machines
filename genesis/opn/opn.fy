( opn.fy - OPN: one channel of a 16-bit console's FM chip [YM2612 /
  YM3438] per voice.  A user machine [Slab docs/25]; the chip is in
  kernel.fy.  Six voices, as the chip had six channels.  Registers keep
  their own units: AR 0-31, TL 0-127 in 0.75 dB steps, MUL 0-15 [0 is
  1/2], DT 0-7 [1-3 up, 5-7 down].  An init patch is OP4 alone at ALG 7:
  a sine. )

include "kernel.fy"
include "machines/lib/manifest.fy"

: manifest
  "OPN" voice-sample machine*
  "k-opn-voice"       render!
  "opn-note-on"       note-on!
  "opn-note-off"      note-off!
  "opn-note-expr"     note-expr!
  "opn-block-prepare" block-prepare!
  6 voices!
  stereo
  OpnState.size  state-size!
  OpnParams.size params-size!
  760.0 panel-w!

  "CHANNEL" "ALG"  "opn-alg"  OpnParams.alg 0.0 7.0 7.0 int-step as-display
  "CHANNEL" "FB"   "opn-fb"   OpnParams.fb  0.0 7.0 0.0 int-step
  "CHANNEL" "PAN"  "opn-pan"  OpnParams.pan 1.0 switch  "L" 0.0 opt  "L+R" 1.0 opt  "R" 2.0 opt
  "CHANNEL" "VOL"  "opn-vol"  OpnParams.vol 0.0 127.0 0.0 int-step
  "CHANNEL" "VEL"  "opn-vel"  OpnParams.vel-amt 0.0 1.0 0.5 curve-lin knob
  "CHANNEL" "TUNE" "opn-tune" OpnParams.tune -24.0 24.0 0.0 curve-lin knob
  "LFO" "FREQ" "opn-lfo" OpnParams.lfo 0.0 switch
    "OFF" 0.0 opt  "3.98" 1.0 opt  "5.56" 2.0 opt  "6.02" 3.0 opt  "6.37" 4.0 opt
    "6.88" 5.0 opt  "9.63" 6.0 opt  "48.1" 7.0 opt  "72.2" 8.0 opt
  "LFO" "PMS" "opn-pms" OpnParams.pms 0.0 7.0 0.0 int-step
  "LFO" "AMS" "opn-ams" OpnParams.ams 0.0 3.0 0.0 int-step
  "CHIP" "DAC" "opn-chip" OpnParams.chip 0.0 switch  "YM2612" 0.0 opt  "YM3438" 1.0 opt
  "CHIP" "GAIN" "opn-gain" OpnParams.gain 0.0 1.0 0.5 curve-pow knob as-fader

  "OP1" "AR" "opn-op1-ar" OpnParams.ops 0 + 0.0 31.0 31.0 int-step
  "OP1" "D1R" "opn-op1-d1r" OpnParams.ops 8 + 0.0 31.0 0.0 int-step
  "OP1" "D2R" "opn-op1-d2r" OpnParams.ops 16 + 0.0 31.0 0.0 int-step
  "OP1" "RR" "opn-op1-rr" OpnParams.ops 24 + 0.0 15.0 15.0 int-step
  "OP1" "SL" "opn-op1-sl" OpnParams.ops 32 + 0.0 15.0 0.0 int-step
  "OP1" "TL" "opn-op1-tl" OpnParams.ops 40 + 0.0 127.0 127.0 int-step
  "OP1" "KS" "opn-op1-ks" OpnParams.ops 48 + 0.0 3.0 0.0 int-step
  "OP1" "MUL" "opn-op1-mul" OpnParams.ops 56 + 0.0 15.0 1.0 int-step
  "OP1" "DT" "opn-op1-dt" OpnParams.ops 64 + 0.0 7.0 0.0 int-step
  "OP1" "AM" "opn-op1-am" OpnParams.ops 72 + 0.0 switch  "OFF" 0.0 opt  "ON" 1.0 opt
  "OP2" "AR" "opn-op2-ar" OpnParams.ops 80 + 0.0 31.0 31.0 int-step
  "OP2" "D1R" "opn-op2-d1r" OpnParams.ops 88 + 0.0 31.0 0.0 int-step
  "OP2" "D2R" "opn-op2-d2r" OpnParams.ops 96 + 0.0 31.0 0.0 int-step
  "OP2" "RR" "opn-op2-rr" OpnParams.ops 104 + 0.0 15.0 15.0 int-step
  "OP2" "SL" "opn-op2-sl" OpnParams.ops 112 + 0.0 15.0 0.0 int-step
  "OP2" "TL" "opn-op2-tl" OpnParams.ops 120 + 0.0 127.0 127.0 int-step
  "OP2" "KS" "opn-op2-ks" OpnParams.ops 128 + 0.0 3.0 0.0 int-step
  "OP2" "MUL" "opn-op2-mul" OpnParams.ops 136 + 0.0 15.0 1.0 int-step
  "OP2" "DT" "opn-op2-dt" OpnParams.ops 144 + 0.0 7.0 0.0 int-step
  "OP2" "AM" "opn-op2-am" OpnParams.ops 152 + 0.0 switch  "OFF" 0.0 opt  "ON" 1.0 opt
  "OP3" "AR" "opn-op3-ar" OpnParams.ops 160 + 0.0 31.0 31.0 int-step
  "OP3" "D1R" "opn-op3-d1r" OpnParams.ops 168 + 0.0 31.0 0.0 int-step
  "OP3" "D2R" "opn-op3-d2r" OpnParams.ops 176 + 0.0 31.0 0.0 int-step
  "OP3" "RR" "opn-op3-rr" OpnParams.ops 184 + 0.0 15.0 15.0 int-step
  "OP3" "SL" "opn-op3-sl" OpnParams.ops 192 + 0.0 15.0 0.0 int-step
  "OP3" "TL" "opn-op3-tl" OpnParams.ops 200 + 0.0 127.0 127.0 int-step
  "OP3" "KS" "opn-op3-ks" OpnParams.ops 208 + 0.0 3.0 0.0 int-step
  "OP3" "MUL" "opn-op3-mul" OpnParams.ops 216 + 0.0 15.0 1.0 int-step
  "OP3" "DT" "opn-op3-dt" OpnParams.ops 224 + 0.0 7.0 0.0 int-step
  "OP3" "AM" "opn-op3-am" OpnParams.ops 232 + 0.0 switch  "OFF" 0.0 opt  "ON" 1.0 opt
  "OP4" "AR" "opn-op4-ar" OpnParams.ops 240 + 0.0 31.0 31.0 int-step
  "OP4" "D1R" "opn-op4-d1r" OpnParams.ops 248 + 0.0 31.0 0.0 int-step
  "OP4" "D2R" "opn-op4-d2r" OpnParams.ops 256 + 0.0 31.0 0.0 int-step
  "OP4" "RR" "opn-op4-rr" OpnParams.ops 264 + 0.0 15.0 15.0 int-step
  "OP4" "SL" "opn-op4-sl" OpnParams.ops 272 + 0.0 15.0 0.0 int-step
  "OP4" "TL" "opn-op4-tl" OpnParams.ops 280 + 0.0 127.0 0.0 int-step
  "OP4" "KS" "opn-op4-ks" OpnParams.ops 288 + 0.0 3.0 0.0 int-step
  "OP4" "MUL" "opn-op4-mul" OpnParams.ops 296 + 0.0 15.0 1.0 int-step
  "OP4" "DT" "opn-op4-dt" OpnParams.ops 304 + 0.0 7.0 0.0 int-step
  "OP4" "AM" "opn-op4-am" OpnParams.ops 312 + 0.0 switch  "OFF" 0.0 opt  "ON" 1.0 opt

  "CHANNEL" 6 strip
  "LFO" 3 strip
  "CHIP" 2 strip
  "OP1" 10 strip
  "OP2" 10 strip
  "OP3" 10 strip
  "OP4" 10 strip

  0.0 row
    6.0 cell  "CHANNEL" 1.0 item
    3.0 cell  "LFO" 1.0 item
    2.0 cell  "CHIP" 1.0 item
  0.0 row  1.0 cell  "OP1" 1.0 item
  0.0 row  1.0 cell  "OP2" 1.0 item
  0.0 row  1.0 cell  "OP3" 1.0 item
  0.0 row  1.0 cell  "OP4" 1.0 item
  machine-desc
;
