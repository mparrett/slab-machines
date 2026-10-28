( kernel.fy - wind: a wind scene, per voice, in stereo.

  Farnell's model [Designing Sound, Practical 18: Wind, wind4].  One
  wind-speed signal W, held between 0 and 1, drives everything; the sound
  is what the wind hits, not the air itself.

    speed    x = SPEED + SWING/4 sin[2 pi RATE t]: Farnell's 0.1 Hz swell
             is SPEED 0.25, SWING 1.  Gusts add slow noise scaled by
             [x + 0.5]^2 - 0.125; squalls add faster noise once x passes
             0.4, scaled by [8 [x - 0.4]]^2.  GUSTS scales both.  W is
             clipped to 0..1, so a gust can never run away.
    air      noise scaled by W + 0.2 through an 800 Hz band-pass and a
             one-zero whose coefficient rises with W: the broad rush
             around buildings, in stereo [WIDTH].
    wires    two narrow band-passes, Q 60, on centres that rise with W -
             1..2 kHz and 600..1000 Hz - gated by W squared: the whistle.
             The note moves both, C4 as Farnell set them.
    doors    two Q 40 band-passes at 400 and 200 Hz, ring-modulated by a
             low oscillator, that sing only in a window of wind speed:
             a door or gap catching the wind and buzzing.
    leaves   noise clipped from below at a threshold that drops as the
             wind rises: sparse ticks, a rustle of pine and turf.

    rumble   RUMBLE: the storm's low body, which the model leaves out:
             two noises, one a side so it is wide, low-passed twice at
             200 Hz and high-passed at 25, following W through its 3 s
             lag so it swells slowly and never gusts hard.

  Farnell taps W from a delay line, 0.1 to 3 s late per object, so a gust
  reaches each one in turn; here each object follows W through a lag of
  the same time instead.  His Pd noise levels are tiny at the sample rate,
  so the gust and squall noises are normalised to his spread, about 0.12,
  before scaling.  Pans are his: air 0.51, doors 0.91 and 0.03, wires
  0.64 and 0.28, leaves 0.71. )

include "kernels/00-primitives/ctx.fy"
include "kernels/00-primitives/math.fy"
include "kernels/00-primitives/rand.fy"
include "kernels/04-filters/coeffs.fy"

ustruct: WindState
  f64 key
  f64 gate
  f64 env
  f64 rl         ( noise cells: air L, air R, objects, the gust and squall noises )
  f64 rr
  f64 ro
  f64 rg
  f64 rs
  f64 ph         ( the swell's phase, cycles )
  f64 g1         ( gust noise low-passes, 0.5 Hz )
  f64 g2
  f64 s1         ( squall noise low-passes, 3 Hz )
  f64 s2
  f64 w1         ( W through lags of 0.1, 0.3, 0.5, 0.9 and 3 s )
  f64 w3
  f64 w5
  f64 w9
  f64 w30
  f64 al1        ( air: band-passes and one-zero memories, a side )
  f64 al2
  f64 ar1
  f64 ar2
  f64 azl
  f64 azr
  f64 da1        ( door A: band-pass, envelope, oscillator phase )
  f64 da2
  f64 dae
  f64 dap
  f64 db1        ( door B )
  f64 db2
  f64 dbe
  f64 dbp
  f64 x11        ( wires 1 and 2: band-passes )
  f64 x12
  f64 x21
  f64 x22
  f64 lv         ( leaves: the slow level, the 200 Hz and 4 kHz one-poles )
  f64 lh
  f64 ll
  f64 ml1        ( rumble: 200 Hz low-passes and 25 Hz high-pass, a side )
  f64 ml2
  f64 mlh
  f64 mr1
  f64 mr2
  f64 mrh
;

ustruct: WindParams
  f64 speed
  f64 swing
  f64 rate       ( swells a second )
  f64 gust
  f64 air
  f64 whistle
  f64 doors
  f64 leaves
  f64 width
  f64 atk        ( seconds )
  f64 rel
  f64 gain
  f64 seed       ( 0..99: which noise this instance plays; 0 as before )
  f64 rumble
  ( derived - block-prepare )
  f64 ka
  f64 kr
  f64 kg         ( one-poles: 0.5 Hz, 3 Hz )
  f64 ks
  f64 ng         ( gust and squall noise normalisers )
  f64 ns
  f64 k1         ( lags: 0.1, 0.3, 0.5, 0.9, 3 s )
  f64 k3
  f64 k5
  f64 k9
  f64 k30
  f64 kd5        ( one-poles: 0.5 Hz, 0.1 Hz, 0.07 Hz, 200 Hz, 4 kHz )
  f64 kd1
  f64 klv
  f64 k200
  f64 k4k
  f64 g800       ( fixed band-passes: 800, 400, 200 Hz )
  f64 g400
  f64 g200
  f64 kr200      ( rumble one-poles: 200 Hz, 25 Hz )
  f64 kr25
;

( hz sr -- k : a one-pole's coefficient for a corner )
dsp: wind-k | hz sr -- k |
  1.0  -6.283185307179586 hz f* sr f/ exp  f-
;

( secs sr -- k : a one-pole's coefficient for a time constant )
dsp: wind-kt | secs sr -- k |
  1.0  -1.0 secs sr f* f/ exp  f-
;

( ctx state params -- )
dsp: wind-block-prepare | ctx:Ctx state params:WindParams |
  params.atk ctx.sr wind-kt -> params.ka
  params.rel ctx.sr wind-kt -> params.kr
  0.5 ctx.sr wind-k -> params.kg
  3.0 ctx.sr wind-k -> params.ks
  ( two cascaded one-poles pass uniform noise with spread sqrt[k / 12] )
  0.12  params.kg 12.0 f/ fsqrt  f/ -> params.ng
  0.12  params.ks 12.0 f/ fsqrt  f/ -> params.ns
  0.1 ctx.sr wind-kt -> params.k1
  0.3 ctx.sr wind-kt -> params.k3
  0.5 ctx.sr wind-kt -> params.k5
  0.9 ctx.sr wind-kt -> params.k9
  3.0 ctx.sr wind-kt -> params.k30
  0.5 ctx.sr wind-k -> params.kd5
  0.1 ctx.sr wind-k -> params.kd1
  0.07 ctx.sr wind-k -> params.klv
  200.0 ctx.sr wind-k -> params.k200
  4000.0 ctx.sr wind-k -> params.k4k
  800.0 ctx.sr svf-g -> params.g800
  400.0 ctx.sr svf-g -> params.g400
  200.0 ctx.sr svf-g -> params.g200
  200.0 ctx.sr wind-k -> params.kr200
  25.0 ctx.sr wind-k -> params.kr25
;

( ctx state params -- )
dsp: wind-note-on | ctx:Ctx state:WindState params:WindParams |
  ctx.pitch -> state.key
  1.0 -> state.gate
  state.rl&  ctx.chan 5.0 f* 1.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.rr&  ctx.chan 5.0 f* 2.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.ro&  ctx.chan 5.0 f* 3.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.rg&  ctx.chan 5.0 f* 4.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.rs&  ctx.chan 5.0 f* 5.0 f+ params.seed 101.0 f* f+  rand-seed-once
;

( ctx state params -- )
dsp: wind-note-off | ctx state:WindState params |
  0.0 -> state.gate
;

( ctx state params -- )
dsp: wind-note-expr | ctx:Ctx state:WindState params |
  ctx.pitch -> state.key
;

( p x k -- y : a one-pole low-pass step on the cell at p )
dsp: wind-lp | p x k -- y |
  p f@64 | s |
  s  x s f- k f*  f+ | y |
  y p f!64
  y
;

( p x k -- : the same step, kept only in the cell )
dsp: wind-lag | p x k |
  p f@64 | s |
  s  x s f- k f*  f+  p f!64
;

( s1p s2p x g d -- bp : one TPT band-pass step, unity gain at the centre;
  d is 1 / 2Q )
dsp: wind-bp | s1p s2p x g d -- bp |
  s1p f@64 | s1 |
  s2p f@64 | s2 |
  2.0 d f* | d2 |
  x  d2 g f+ s1 f*  f-  s2 f-  1.0 d2 g f* f+ g g f* f+  f/ | hp |
  g hp f*  s1 f+ | bp |
  g bp f*  s2 f+ | lp |
  g hp f* bp f+  s1p f!64
  g bp f* lp f+  s2p f!64
  bp d2 f*
;

( ctx state params -- w : the wind speed, 0..1; updates the lagged copies )
dsp: wind-speed | ctx:Ctx state:WindState params:WindParams -- w |
  state.ph  params.rate ctx.inv-sr f*  f+ ffrac | ph |
  ph -> state.ph
  params.speed  params.swing 0.25 f*  ph 2.0 f* sinpi f*  f+ | x |
  state.g1& state.rg& rand-b params.kg wind-lp | ga |
  state.g2& ga params.kg wind-lp params.ng f* params.gust f* | gn |
  state.s1& state.rs& rand-b params.ks wind-lp | sa |
  state.s2& sa params.ks wind-lp params.ns f* params.gust f* | sn |
  x 0.5 f+ | xg |
  x 0.4 f- 0.0 fmax 8.0 f* | xs |
  x  gn  xg xg f* 0.125 f-  f*  f+  sn xs xs f* f*  f+  0.0 1.0 fclamp | w |
  state.w1& w params.k1 wind-lag
  state.w3& w params.k3 wind-lag
  state.w5& w params.k5 wind-lag
  state.w9& w params.k9 wind-lag
  state.w30& w params.k30 wind-lag
  w
;

( p a lo hi k -- e : a door's envelope, a raised cosine across the window
  lo..hi of wind speed a, low-passed by k on the cell at p )
dsp: wind-window | p a lo hi k -- e |
  a lo hi fclamp lo f-  hi lo f- f/ 0.5 f* | t |
  ( t runs 0..0.5 over the window; cos 2pi [t - 1/4] peaks in the middle )
  t 0.25 f- 2.0 f* 0.5 f+ sinpi | c |
  p c k wind-lp
;

( io ctx state params -- : one voice, one host sample. )
dsp: k-wind-voice | io:Io ctx:Ctx state:WindState params:WindParams -- |
  state.gate 0.5 f>  params.ka  params.kr  select | k |
  state.env  state.gate state.env f- k f*  f+ | env |
  env -> state.env
  ctx state params wind-speed | w |
  state.rl& rand-b | nl |
  state.rr& rand-b | nr0 |
  nl  nr0 nl f- params.width f*  f+ | nr |
  state.ro& rand-b | no |
  ( air: noise x [W + 0.2], 800 Hz Q 1, a one-zero rising with W )
  w 0.2 f+ | wa |
  wa 0.6 f* 0.0 0.99 fclamp | cz |
  state.al1& state.al2& nl wa f* params.g800 0.5 wind-bp | bl |
  state.ar1& state.ar2& nr wa f* params.g800 0.5 wind-bp | br |
  bl  state.azl cz f*  f-  0.2 f* params.air f* | airl |
  bl -> state.azl
  br  state.azr cz f*  f-  0.2 f* params.air f* | airr |
  br -> state.azr
  ( doors: Q 40 bands, buzzing in a window of wind speed )
  state.dae& state.w1 0.35 0.6 params.kd5 wind-window | ea |
  state.dbe& state.w3 0.25 0.5 params.kd1 wind-window | eb |
  state.dap  30.0 200.0 ea f* f+ ctx.inv-sr f*  f+ ffrac | pa |
  pa -> state.dap
  state.dbp  20.0 100.0 eb f* f+ ctx.inv-sr f*  f+ ffrac | pb |
  pb -> state.dbp
  state.da1& state.da2& no params.g400 0.0125 wind-bp  ea f* 2.0 f*  pa 2.0 f* sinpi f* | da |
  state.db1& state.db2& no params.g200 0.0125 wind-bp  eb f* 2.0 f*  pb 2.0 f* sinpi f* | db |
  ( wires: Q 60 whistles on centres that rise with W; the note moves them )
  state.key 60.0 f- 12.0 f/ exp2 | tr |
  1000.0 1000.0 state.w9 f* f+ tr f*  ctx.sr 0.45 f* fmin ctx.sr svf-g | gw1 |
  600.0 400.0 state.w5 f* f+ tr f*  ctx.sr 0.45 f* fmin ctx.sr svf-g | gw2 |
  state.x11& state.x12& no gw1 0.008333333333333333 wind-bp  state.w9 state.w9 f* 2.0 f* f* | x1 |
  state.w5 0.12 f+ | w5 |
  state.x21& state.x22& no gw2 0.008333333333333333 wind-bp  w5 w5 f* 1.2 f* f* | x2 |
  ( leaves: noise above a falling threshold, 200 Hz .. 4 kHz )
  state.lv& state.w30 0.3 f+ params.klv wind-lp | lv |
  1.0 0.4 lv f* f- | th |
  no th fmax th f-  th f* | sp |
  state.lh& sp params.k200 wind-lp | spl |
  state.ll& sp spl f- params.k4k wind-lp  lv 0.2 f- 0.0 fmax f*  0.8 f* params.leaves f* | lf |
  ( a narrow band keeps little of white noise's power: about sqrt Q back )
  da params.doors f* 6.0 f* | dad |
  db params.doors f* 6.0 f* | dbd |
  x1 params.whistle f* 8.0 f* | x1g |
  x2 params.whistle f* 8.0 f* | x2g |
  ( pans, Farnell's: L cos, R sin of a quarter turn times p )
  airl
    dad 0.955 sinpi f*  f+
    dbd 0.515 sinpi f*  f+
    x1g 0.82 sinpi f*  f+
    x2g 0.64 sinpi f*  f+
    lf 0.855 sinpi f*  f+ | yl |
  airr
    dad 0.455 sinpi f*  f+
    dbd 0.015 sinpi f*  f+
    x1g 0.32 sinpi f*  f+
    x2g 0.14 sinpi f*  f+
    lf 0.355 sinpi f*  f+ | yr |
  ( rumble: independent noise a side, low, following the slow lag of W )
  state.w30 0.6 f* 0.4 f+  params.rumble f* 30.0 f* | rg |
  state.ml1& nl params.kr200 wind-lp | mla |
  state.ml2& mla params.kr200 wind-lp | mlb |
  mlb  state.mlh& mlb params.kr25 wind-lp  f-  rg f* | rml |
  state.mr1& nr0 params.kr200 wind-lp | mra |
  state.mr2& mra params.kr200 wind-lp | mrb |
  mrb  state.mrh& mrb params.kr25 wind-lp  f-  rg f* | rmr |
  yl rml f+ | ylm |
  yr rmr f+ | yrm |
  env params.gain f* 3.6 f* | g |
  io.out-l  ylm g f*  f+ -> io.out-l
  io.out-r  yrm g f*  f+ -> io.out-r
;
