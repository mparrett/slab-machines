( sdspecho.fy - the 16-bit console DSP's echo, as an effect.

  A user machine [Slab docs/25].  The DSP's one reverb-like effect: a
  stereo delay in audio RAM, run at 32 kHz like the rest of the chip.

    DELAY     EDL: 0..15 steps of 16 ms [512 frames at 32 kHz]
    FEEDBACK  EFB: -128..127, /128, of the filtered echo back into it
    FIR       8 taps, signed 8-bit /128, on what comes out of the ring.
              Tap 0 weighs the oldest of the last eight echo samples.
              PRESET loads the four filter sets the console's
              first-party sound driver shipped; the knobs stay free.
    ECHO      EVOL, the filtered echo's level; SURR inverts the right
              channel's, as games did for width.
    DRY       the input's level, at the host rate.

  The ring stores 32 kHz frames, so the input is taken at the 32 kHz
  ticks after a one-pole lowpass, and the echo is linearly interpolated
  back onto the host grid.  A wide FIR with high feedback runs away, as
  it did on the console: the ring clips at full scale.  The decoder
  reference is blargg's SPC_DSP [snes_spc 0.9.0]. )

include "kernels/00-primitives/ctx.fy"
include "kernels/00-primitives/math.fy"
include "machines/lib/manifest.fy"

ustruct: EchoState
  f64 buf-l
  f64 len-l
  f64 buf-r
  f64 len-r
  f64 pos        ( ring frame, 0..length-1 )
  f64 hp         ( FIR history slot of the newest sample, 0..7 )
  f64 hl 8
  f64 hr 8
  f64 oc         ( the 32 kHz clock )
  f64 lp-l       ( input lowpass )
  f64 lp-r
  f64 l0 f64 l1  ( the last two echo outputs per channel )
  f64 r0 f64 r1
;

ustruct: EchoParams
  f64 edl
  f64 efb
  f64 preset
  f64 c0 f64 c1 f64 c2 f64 c3 f64 c4 f64 c5 f64 c6 f64 c7
  f64 evol
  f64 surr
  f64 dry
  ( derived )
  f64 tick-inc
  f64 frames     ( ring length in 32 kHz frames )
  f64 lp-a
;

( ctx state params -- )
dsp: echo-block-prepare | ctx:Ctx state params:EchoParams |
  32000.0 ctx.sr f/ 1.0 fmin -> params.tick-inc
  params.edl 0.0 15.0 fclamp floor 512.0 f* 1.0 fmax -> params.frames
  -6.283185307179586 14000.0 f* ctx.sr f/ exp -> params.lp-a
;

( x m -- y : x mod m for x >= 0 and m > 0. )
dsp: fmod-pos | x m -- y |
  x  x m f/ floor m f*  f-
;

( h hp -- y : the FIR over one channel's history, newest at slot hp. )
dsp: echo-fir | h hp params:EchoParams -- y |
  ( slot of the sample k ticks older than the oldest: [hp + 1 + k] mod 8 )
  0.0
  h hp 1.0 f+ 8.0 fmod-pos f@i params.c0 f* f+
  h hp 2.0 f+ 8.0 fmod-pos f@i params.c1 f* f+
  h hp 3.0 f+ 8.0 fmod-pos f@i params.c2 f* f+
  h hp 4.0 f+ 8.0 fmod-pos f@i params.c3 f* f+
  h hp 5.0 f+ 8.0 fmod-pos f@i params.c4 f* f+
  h hp 6.0 f+ 8.0 fmod-pos f@i params.c5 f* f+
  h hp 7.0 f+ 8.0 fmod-pos f@i params.c6 f* f+
  h hp 8.0 f+ 8.0 fmod-pos f@i params.c7 f* f+
  128.0 f/ -1.0 1.0 fclamp
;

( io ctx state params -- )
dsp: k-echo-tick | io:Io ctx state:EchoState params:EchoParams -- |
  state.oc params.tick-inc f+ | oc |
  oc 1.0 f>= | tk |
  tk  oc 1.0 f-  oc  select -> state.oc
  io.in-l | xl |
  io.in-r | xr |
  ( band-limit the input for the 32 kHz ring )
  state.lp-l xl f-  params.lp-a f*  xl f+ | fl |
  state.lp-r xr f-  params.lp-a f*  xr f+ | fr |
  fl -> state.lp-l
  fr -> state.lp-r
  ( a shorter DELAY can leave the head past the new end )
  state.pos params.frames f>=  0.0  state.pos  select | p |
  state.buf-l& p@64 | bl |
  state.buf-r& p@64 | br |
  ( read the ring into the FIR history, at the tick )
  state.hp 1.0 f+ 8.0 fmod-pos | hp1 |
  tk hp1 state.hp select | hp |
  hp -> state.hp
  bl p f@i | el |
  br p f@i | er |
  tk  el  state.hl& hp f@i  select  state.hl& hp f!i
  tk  er  state.hr& hp f@i  select  state.hr& hp f!i
  state.hl& hp params echo-fir | wl |
  state.hr& hp params echo-fir | wr |
  ( write input plus feedback back where it was read )
  params.efb 128.0 f/ | fb |
  tk  fl wl fb f* f+ -1.0 1.0 fclamp  el  select  bl p f!i
  tk  fr wr fb f* f+ -1.0 1.0 fclamp  er  select  br p f!i
  p 1.0 f+ | p1 |
  p1 params.frames f>=  0.0  p1  select | p2 |
  tk p2 p select -> state.pos
  tk  state.l1  state.l0  select -> state.l0
  tk  wl  state.l1  select -> state.l1
  tk  state.r1  state.r0  select -> state.r0
  tk  wr  state.r1  select -> state.r1
  state.oc | u |
  state.l0  state.l1 state.l0 f-  u f*  f+ | ol |
  state.r0  state.r1 state.r0 f-  u f*  f+ | or |
  params.evol 128.0 f/ | ev |
  params.surr 0.5 f>  0.0 ev f-  ev  select | evr |
  xl params.dry f*  ol ev f*  f+ -> io.out-l
  xr params.dry f*  or evr f*  f+ -> io.out-r
;

: manifest
  "S-DSP Echo" effect-block machine*
  "k-echo-tick"        render!
  "echo-block-prepare" block-prepare!
  EchoState.size  state-size!
  EchoParams.size params-size!
  560.0 panel-w!
  stereo

  ( 15 x 512 frames at 32 kHz is 240 ms; the rings are in host samples,
    so leave room for 32 kHz frames at any host rate down to 32 kHz )
  "echo-l" EchoState.buf-l EchoState.len-l 0.26 buffer
  "echo-r" EchoState.buf-r EchoState.len-r 0.26 buffer

  "ECHO" "DELAY" "secho-edl" EchoParams.edl 0.0 15.0 6.0 int-step
  "ECHO" "FEEDBK" "secho-efb" EchoParams.efb -128.0 127.0 64.0 int-step
  "ECHO" "EVOL" "secho-evol" EchoParams.evol -128.0 127.0 40.0 int-step
  "ECHO" "SURR" "secho-surr" EchoParams.surr 0.0 switch
    "OFF" 0.0 opt  "ON" 1.0 opt
  "ECHO" "DRY" "secho-dry" EchoParams.dry 0.0 1.0 1.0 curve-pow knob

  "FIR" "PRESET" "secho-preset" EchoParams.preset 1.0 switch
    "FLAT" 0.0 opt
      "secho-c0" 127.0 sets  "secho-c1" 0.0 sets  "secho-c2" 0.0 sets  "secho-c3" 0.0 sets
      "secho-c4" 0.0 sets  "secho-c5" 0.0 sets  "secho-c6" 0.0 sets  "secho-c7" 0.0 sets
    "LOWPASS" 1.0 opt
      "secho-c0" 12.0 sets  "secho-c1" 33.0 sets  "secho-c2" 43.0 sets  "secho-c3" 43.0 sets
      "secho-c4" 19.0 sets  "secho-c5" -2.0 sets  "secho-c6" -13.0 sets  "secho-c7" -7.0 sets
    "HIPASS" 2.0 opt
      "secho-c0" 88.0 sets  "secho-c1" -65.0 sets  "secho-c2" -37.0 sets  "secho-c3" -16.0 sets
      "secho-c4" -2.0 sets  "secho-c5" 7.0 sets  "secho-c6" 12.0 sets  "secho-c7" 12.0 sets
    "BANDPASS" 3.0 opt
      "secho-c0" 52.0 sets  "secho-c1" 51.0 sets  "secho-c2" 0.0 sets  "secho-c3" -39.0 sets
      "secho-c4" -27.0 sets  "secho-c5" 1.0 sets  "secho-c6" -4.0 sets  "secho-c7" -21.0 sets
    as-display
  "FIR" "C0" "secho-c0" EchoParams.c0 -128.0 127.0 12.0 int-step
  "FIR" "C1" "secho-c1" EchoParams.c1 -128.0 127.0 33.0 int-step
  "FIR" "C2" "secho-c2" EchoParams.c2 -128.0 127.0 43.0 int-step
  "FIR" "C3" "secho-c3" EchoParams.c3 -128.0 127.0 43.0 int-step
  "FIR" "C4" "secho-c4" EchoParams.c4 -128.0 127.0 19.0 int-step
  "FIR" "C5" "secho-c5" EchoParams.c5 -128.0 127.0 -2.0 int-step
  "FIR" "C6" "secho-c6" EchoParams.c6 -128.0 127.0 -13.0 int-step
  "FIR" "C7" "secho-c7" EchoParams.c7 -128.0 127.0 -7.0 int-step

  "ECHO" 5 strip
  "FIR" 9 strip
  0.0 row
    5.0 cell  "ECHO" 1.0 item
  0.0 row
    9.0 cell  "FIR" 1.0 item
  machine-desc
;
