( kernel.fy - bubbles: water, from drips to a boil, per voice, in stereo.

  Each bubble is the sound a bubble makes as it forms [Minnaert 1933]:
  a sine at 3.26 / r kHz [r the radius in mm], decaying at van den Doel's
  rate d = 0.13 f + 0.0072 f^1.5 per second, its pitch rising as it nears
  the surface, f[t] = f0 [1 + RISE x 0.6 x d t]  [van den Doel, Physically
  Based Models for Liquid Sounds, 2005].  Small bubbles are high, short
  and quiet; big ones low, longer and louder.

    RATE    bubbles a second, on average
    SIZE    the typical radius in mm, at C4; each octave up halves it
    SPREAD  how far the radii scatter around SIZE: 0 one size, 1 from
            a fifth of it to five times it
    RISE    the upward chirp: 0 a plain decaying tone, 1 a drip's "plip"
    RING    x every bubble's decay time
    CLUMP   gathers the bubbles into bursts at the same average rate,
            as a boil or a glug does
    WIDTH   how far each bubble is panned, at random
    TONE    a final low-pass: the water's distance, or a container
            [after a 60 Hz high-pass that takes the bubbles' DC]

  Sixteen bubbles sound at once; past that the oldest gives way.  Hold a
  note for as long as the water runs.  Clean-room, from the papers cited;
  the levels are set by measurement. )

include "kernels/00-primitives/ctx.fy"
include "kernels/00-primitives/math.fy"
include "kernels/00-primitives/rand.fy"

:: BN 16 ;   ( bubbles at once )

ustruct: BubbleState
  f64 ph 16  f64 fr 16  f64 df 16   ( phase and frequency in cycles a sample, its rise )
  f64 a 16   f64 dk 16              ( amplitude and its decay per sample )
  f64 gl 16  f64 gr 16              ( pan gains )
  f64 gate
  f64 env
  f64 next                          ( the slot the next bubble takes )
  f64 act                           ( 1 inside a burst )
  f64 re                            ( noise cells: events, sizes, pans, bursts )
  f64 rs
  f64 rp
  f64 rk
  f64 pitch                         ( the note's size factor )
  f64 seedv                         ( the SEED the noise cells were seeded from )
  f64 vel
  f64 tl  f64 tr                    ( tone low-passes )
  f64 hl  f64 hr                    ( 60 Hz high-pass: the low-passes it subtracts )
;

ustruct: BubbleParams
  f64 rate       ( bubbles a second )
  f64 radius     ( mm at C4: SIZE )
  f64 spread     ( 0..1 )
  f64 rise       ( 0..1 )
  f64 ring       ( x decay time )
  f64 clump      ( 0..1 )
  f64 width      ( 0..1 )
  f64 tone       ( Hz )
  f64 atk
  f64 rel
  f64 gain
  f64 seed       ( 0..99: which noise this instance plays )
  ( derived - block-prepare )
  f64 ka  f64 kr
  f64 ktone
  f64 khp
  f64 kend  f64 kstart              ( per-sample chances a burst ends, starts )
  f64 fny                           ( the highest bubble, Hz )
;

( hz sr -- k : a one-pole's coefficient for a corner )
dsp: bb-k | hz sr -- k |
  1.0  -6.283185307179586 hz f* sr f/ exp  f-
;

( p x k -- y : a one-pole low-pass step on the cell at p )
dsp: bb-lp | p x k -- y |
  p f@64 | s |
  s  x s f- k f*  f+ | y0 |
  ( flushed below -300 dB, so a tail never turns denormal )
  y0 fabs 1.0e-15 f> mask>f y0 f* | y |
  y p f!64
  y
;

dsp: bb-block-prepare | ctx:Ctx state params:BubbleParams -- |
  1.0  -1.0 params.atk ctx.sr f* f/ exp  f- -> params.ka
  1.0  -1.0 params.rel ctx.sr f* f/ exp  f- -> params.kr
  params.tone ctx.sr 0.45 f* fmin ctx.sr bb-k -> params.ktone
  60.0 ctx.sr bb-k -> params.khp
  ( bursts last 0.2 s on average and fill 15% of the time )
  ctx.inv-sr 0.2 f/ -> params.kend
  ctx.inv-sr 0.2 f/ 0.15 f* 0.85 f/ -> params.kstart
  ctx.sr 0.4 f* -> params.fny
;

( ctx state params -- )
dsp: bb-note-on | ctx:Ctx state:BubbleState params:BubbleParams |
  1.0 -> state.gate
  ctx.vel 0.0 1.0 fclamp -> state.vel
  ( C4 is SIZE as set; higher notes make smaller, higher bubbles )
  ctx.hz 261.6255653005986 f/ -> state.pitch
  ( a changed SEED reseeds the noise cells, which seed only from 0 )
  params.seed state.seedv f= | same |
  same state.re 0.0 select -> state.re
  same state.rs 0.0 select -> state.rs
  same state.rp 0.0 select -> state.rp
  same state.rk 0.0 select -> state.rk
  params.seed -> state.seedv
  state.re&  ctx.chan 5.0 f* 31.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.rs&  ctx.chan 5.0 f* 32.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.rp&  ctx.chan 5.0 f* 33.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.rk&  ctx.chan 5.0 f* 34.0 f+ params.seed 101.0 f* f+  rand-seed-once
;

( ctx state params -- )
dsp: bb-note-off | ctx state:BubbleState params |
  0.0 -> state.gate
;

( io ctx state params -- : one voice, one host sample.  Output ACCUMULATES. )
dsp: k-bubbles-voice | io:Io ctx:Ctx state:BubbleState params:BubbleParams -- |
  state.gate 0.5 f>  params.ka  params.kr  select | k |
  state.env  state.gate state.env f- k f*  f+ | env |
  env -> state.env
  ( bursts: a telegraph, as fire's CLUMP; inside one the chance rises by
    1 / 0.15 so the average rate holds )
  state.rk& rand-u | uk |
  state.act 0.5 f>  uk params.kend f< 0.0 1.0 select  uk params.kstart f< 1.0 0.0 select  select -> state.act
  1.0 params.clump f-  params.clump 6.666666666666667 f* state.act f*  f+ | burst |
  state.re& rand-u  params.rate ctx.inv-sr f* burst f*  f<  state.gate 0.5 f> and | spawn |
  ( the new bubble: a radius scattered log-evenly over SPREAD's range,
    its frequency, decay, chirp, level and pan )
  state.rs& rand-b | us |
  state.rs& rand-u | ua |
  params.radius  us params.spread f* 2.3219 f* exp2 f*  state.pitch f/ | r |
  3260.0 r f/ 60.0 params.fny fclamp | f0 |
  0.13 f0 f*  0.0072 f0 f0 fsqrt f* f*  f+  params.ring f/ | d |
  -1.0 d f* ctx.inv-sr f* exp | dk |
  f0 ctx.inv-sr f* | fc |
  fc params.rise 0.6 f* d f* f* ctx.inv-sr f* | dfc |
  ( bigger is louder, by the radius over SIZE's, square-rooted )
  r params.radius state.pitch f/ f/ fsqrt  0.5 ua 0.5 f* f+ f*  state.vel f* | a0 |
  state.rp& rand-b params.width f* 0.5 f* 0.5 f+ | pan |
  1.0 pan f- fsqrt | g0l |
  pan fsqrt | g0r |
  0.0 0.0 0.0 BN [ | i ol or |
    state.ph& i f@i | ph |
    state.fr& i f@i | fr |
    state.a& i f@i | a |
    ph sin2pi a f* | s |
    ph fr f+ ffrac state.ph& i f!i
    fr state.df& i f@i f+ 0.45 fmin state.fr& i f!i
    a state.dk& i f@i f* | an |
    an 1.0e-7 f> mask>f an f* state.a& i f!i
    i 1.0 f+
    ol s state.gl& i f@i f* f+
    or s state.gr& i f@i f* f+ ] times | i ol or |
  ( the new bubble takes the next slot, the oldest; stores land after the
    loop's, in order, so it starts next sample )
  state.next | nx |
  spawn  0.0  state.ph& nx f@i  select state.ph& nx f!i
  spawn  fc   state.fr& nx f@i  select state.fr& nx f!i
  spawn  dfc  state.df& nx f@i  select state.df& nx f!i
  spawn  a0   state.a& nx f@i   select state.a& nx f!i
  spawn  dk   state.dk& nx f@i  select state.dk& nx f!i
  spawn  g0l  state.gl& nx f@i  select state.gl& nx f!i
  spawn  g0r  state.gr& nx f@i  select state.gr& nx f!i
  nx 1.0 f+ | n1 |
  spawn  n1 15.5 f> 0.0 n1 select  nx  select -> state.next
  env params.gain f* | g |
  ( a bubble's sine starts at zero, so it carries a little DC [2d / w of
    its peak]; many at once would rumble, so a 60 Hz high-pass takes it )
  ol g f* | xl |
  or g f* | xr |
  xl  state.hl& xl params.khp bb-lp  f- | hl |
  xr  state.hr& xr params.khp bb-lp  f- | hr |
  state.tl& hl params.ktone bb-lp | yl |
  state.tr& hr params.ktone bb-lp | yr |
  io.out-l yl f+ -> io.out-l
  io.out-r yr f+ -> io.out-r
;
