( kernel.fy - psg: one channel of the 16-bit console's PSG, the SN76489
  clone in Sega's video chip, per voice.

  The chip divides its 3.58 MHz clock by 16 and counts down from each
  channel's 10-bit period N.  A tone flips every N ticks:
  f = clock / [32 N], so nothing below about 109 Hz, and the top octaves
  go out of tune as N gets small.  The voice averages the square over each
  host sample, as the chip's output is far above the host's rate.

    noise    Sega's LFSR: 16 bits, reset to 0x8000 on a key-on, as a
             write to the noise register did.  WHITE feeds back bit 0 XOR
             bit 3; PERIODIC bit 0 alone, 16 steps, so it sits 6.25% below
             TI's 15-step chip.  RATE shifts it every 32, 64 or 128 ticks,
             or every second flip of the note's own period [TONE 3: the
             driver set tone 3 and borrowed it].
    volume   the chip's 4-bit attenuation, 2 dB a step, 15 off.  Velocity
             and VOL set where it starts; a sound driver's envelope moves
             it at the 60 Hz frame: up by AR frames a step, down to SL by
             DR, then down by RR after key-off.  AR 0 starts at the
             top; 0 elsewhere is a step every frame.

  The chip's channels are 0-or-level squares; the voice centres them, as
  the console's output capacitor did, so a silent channel is 0.0.
  Reference: MAME's sn76496.cpp [segapsg], BSD-3-Clause. )

include "kernels/00-primitives/ctx.fy"
include "kernels/00-primitives/math.fy"

ustruct: PsgState
  f64 key
  f64 vel
  f64 bend
  f64 n          ( the 10-bit period )
  f64 ph         ( tone phase in ticks, 0..2N )
  f64 nph        ( ticks toward the next noise shift )
  f64 rng
  f64 env        ( the envelope's attenuation, 0..15 )
  f64 stage      ( 0 attack / 1 decay / 2 sustain / 3 release )
  f64 fctr       ( frames since the envelope last stepped )
  f64 facc       ( host samples toward the next frame )
;

ustruct: PsgParams
  f64 mode       ( 0 tone / 1 periodic noise / 2 white noise )
  f64 rate       ( noise: 0 high / 1 mid / 2 low / 3 tone 3 )
  f64 vol        ( attenuation added, 0..15 )
  f64 vel-amt
  f64 ar         ( frames per step, 0..31 )
  f64 dr
  f64 sl         ( 0..15 )
  f64 rr
  f64 tune
  f64 gain
  ( derived - block-prepare )
  f64 tpc        ( chip ticks per host sample )
  f64 fpc        ( 60 Hz frames per host sample )
;

( x m -- x mod m )
dsp: psg-mod | x m -- y |
  x  x m f/ floor m f*  f-
;

( ctx state params -- )
dsp: psg-block-prepare | ctx:Ctx state params:PsgParams |
  223721.5625 ctx.sr f/ -> params.tpc
  60.0 ctx.sr f/ -> params.fpc
;

( state params -- : the note as the period a driver would write )
dsp: psg-period | state:PsgState params:PsgParams |
  state.key state.bend f+ params.tune f+ 69.0 f- 12.0 f/ exp2 440.0 f* | f |
  3579545.0 32.0 f/ f f/ 0.5 f+ floor 1.0 1023.0 fclamp -> state.n
;

( ctx state params -- )
dsp: psg-note-on | ctx:Ctx state:PsgState params:PsgParams |
  ctx.pitch -> state.key
  ctx.vel -> state.vel
  0.0 -> state.bend
  state params psg-period
  0.0 -> state.ph
  0.0 -> state.nph
  32768.0 -> state.rng
  ( attack from silence, or straight to the top at AR 0 )
  params.ar 0.5 f<  0.0  15.0  select -> state.env
  params.ar 0.5 f<  1.0  0.0  select -> state.stage
  0.0 -> state.fctr
;

( ctx state params -- )
dsp: psg-note-off | ctx state:PsgState params |
  3.0 -> state.stage
  0.0 -> state.fctr
;

( ctx state params -- )
dsp: psg-note-expr | ctx:Ctx state:PsgState params:PsgParams |
  ctx.pitch state.key f- -> state.bend
  state params psg-period
;

( x n -- high ticks of a square of period 2n, high first, from 0 to x )
dsp: psg-high | x n -- h |
  x 2.0 n f* f/ floor n f*  x 2.0 n f* psg-mod n fmin  f+
;

( io ctx state params -- : one channel, one host sample. )
dsp: k-psg-voice | io:Io ctx state:PsgState params:PsgParams -- |
  ( the driver's envelope, a step per frame at most )
  state.facc params.fpc f+ | fa |
  fa 1.0 f>= | frame |
  frame  fa 1.0 f-  fa  select -> state.facc
  frame  state.fctr 1.0 f+  state.fctr  select | fc |
  state.stage | s |
  state.env | e |
  s 0.5 f<  params.ar  s 1.5 f<  params.dr  params.rr  select  select | per |
  frame  fc per f>= and  s 1.5 f> s 2.5 f< and not and | step |
  ( attack toward 0, decay toward SL, release toward 15 )
  s 0.5 f<  e 1.0 f- 0.0 fmax  s 1.5 f<  e 1.0 f+ params.sl fmin  e 1.0 f+ 15.0 fmin  select  select | e1 |
  step  e1  e  select | e2 |
  e2 -> state.env
  step  0.0  fc  select -> state.fctr
  s 0.5 f<  e2 0.5 f< and  1.0
    s 1.5 f<  s 0.5 f> and  e2 params.sl f>= and  2.0  s  select
  select -> state.stage
  ( where velocity and VOL put the channel, in the chip's 2 dB steps )
  1.0 state.vel f- params.vel-amt f* 15.0 f* 0.5 f+ floor params.vol f+ e2 f+ 0.0 15.0 fclamp | att |
  att 14.5 f>  0.0  att -2.0 f* db>lin  select | amp |
  ( tone: the high share of this sample's ticks )
  state.n | n |
  state.ph | p0 |
  p0 params.tpc f+ | p1 |
  p1 n psg-high  p0 n psg-high f-  params.tpc f/ | hi |
  p1 2.0 n f* psg-mod -> state.ph
  ( noise: shift when its count runs out; TONE 3 shifts every 2N ticks )
  params.rate 0.5 f<  32.0  params.rate 1.5 f<  64.0  params.rate 2.5 f<  128.0  2.0 n f*  select select select | np |
  state.nph params.tpc f+ | nq |
  nq np f>= | shift |
  shift  nq np f-  nq  select -> state.nph
  state.rng | r |
  r 2.0 psg-mod | b0 |
  r 8.0 f/ floor 2.0 psg-mod | b3 |
  params.mode 1.5 f>  b0 b3 f- fabs  b0  select | fb |
  r 2.0 f/ floor  fb 32768.0 f* f+ | r2 |
  shift  r2  r  select | rn |
  rn -> state.rng
  rn 2.0 psg-mod | nbit |
  params.mode 0.5 f<  hi  nbit  select | on |
  ( centred: the 0-or-level square less its middle )
  on 0.5 f-  amp f*  params.gain f* | y |
  io.out-l y f+ -> io.out-l
;
