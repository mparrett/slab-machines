( kernel.fy - modal: a body that something strikes, scrapes, rolls on or
  rubs, per voice, in stereo.

  The sound is split into what excites the body and what resonates, so
  every exciter plays every material.

    body     24 damped modes [Slab's kernels/10-physical/modal.fy, the
             exact step].  MATERIAL sets their series and their loss:
               WOOD   a free bar's ratios, ((2n + 3) / 3)^2; the high modes
                      die fast [loss rising with f^2]
               STONE  a dense, scattered series, all of it short: grit
               METAL  a plate's stretched series, ((n + 1.2) / 1.2)^1.17,
                      ringing long
               GLASS  a sparse high series, bright and fairly long; ice
               HIDE   a circular membrane's Bessel ratios
             The first mode is the note's pitch times SIZE.  DECAY scales
             every T60, and DAMP tilts the loss: more takes the top off
             sooner.  POSITION is where the body is excited, from the end
             or edge [0] to the middle [0.5]; each mode is driven by its
             shape there, so a centre hit loses the even modes, and a
             centre hit on HIDE drives only its round modes.
    strike   a raised-cosine force of HARD's contact time, from 6 ms
             [felt, dull] to 0.06 ms [steel, bright]; a harder hit is a
             shorter one too [Hertz].  The impulse is the same at any HARD,
             so HARD changes the colour and not the weight.  BOUNCE lets it
             fall again: up to 8 more strikes, each lower and sooner, on a
             gravity timeline.
    scrape   while the note is held: noise low-passed by SPEED [150 Hz
             to 7 kHz], plus bumps from the surface at SPEED x ROUGH.
    roll     while held: a low rumble at SPEED, an out-of-round wobble,
             and bumps where ROUGH lets them.
    rub      while held: stick-slip, a force that builds and snaps back
             at a rate set by SPEED, made unsteady by ROUGH: creaks,
             squeals, a bow.
    drop     DROP bends every mode's pitch up at a hard hit and lets it
             fall back over about 40 ms, as a struck head or plate does
             [the first-order rotation bend of Slab's kit, so the step
             stays stable].
    rattle   RATTLE buzzes when the body swings past a threshold: noise
             gated by the output, high-passed - a loose part.
    vary     VARY moves the strike point and detunes each mode a little
             on every hit, from a seeded stream, so repeats differ.
    output   the modes' velocity, seen from two points and spread by
             WIDTH, through TONE's low-pass.  HARD's contact sets how
             bright it is.

  Clean-room, from the literature: modal synthesis [Adrien 1991], the free
  bar's and plate's series [Fletcher and Rossing], contact time [Hertz],
  and van den Doel's scraping and rolling models [2001].  The material
  constants are estimates set by measurement. )

include "kernels/00-primitives/ctx.fy"
include "kernels/00-primitives/math.fy"
include "kernels/00-primitives/rand.fy"
include "kernels/10-physical/modal.fy"
include "kernels/10-physical/bessel.fy"

:: MN 24 ;   ( modes )

ustruct: ModalState
  f64 q 24   f64 v 24
  f64 c 24   f64 sw 24   f64 ws 24   f64 rho 24
  f64 b1 24  f64 b2 24
  f64 w2 24                         ( w^2, for the glide )
  f64 phi 24                        ( drive at the excitation point )
  f64 wl 24  f64 wr 24              ( radiation to each side )
  f64 gate
  f64 env                           ( the held exciters' level )
  f64 vel
  f64 t                             ( samples into the strike; -1 none )
  f64 tlen                          ( the strike's contact, samples )
  f64 amp                           ( its force )
  f64 bn                            ( bounces left )
  f64 bgap                          ( the gap before the next, samples )
  f64 bt                            ( samples until it )
  f64 dl                            ( the glide, a fraction of each mode's pitch )
  f64 rn                            ( noise cells: excitation, variation, rattle )
  f64 rv
  f64 rr
  f64 n1  f64 n2                    ( the excitation's low-passes )
  f64 bump                          ( a bump's force, decaying )
  f64 ph                            ( rub and roll phase )
  f64 rh                            ( rattle high-pass )
  f64 tl  f64 tr                    ( tone low-passes )
  f64 gain
  f64 trim                          ( the level before GAIN, for the rattle's gate )
  f64 seedv                         ( the SEED the noise cells were seeded from )
  ( the hit, for the mode stages )
  f64 k-f0  f64 k-s0  f64 k-s1  f64 k-sq  f64 k-tilt
  f64 k-a  f64 k-b  f64 k-jit  f64 k-pos  f64 k-hide  f64 k-fny
;

ustruct: ModalParams
  f64 material   ( 0 wood, 1 stone, 2 metal, 3 glass, 4 hide )
  f64 scale      ( x the note's pitch: SIZE; not `size`, which would shadow ModalParams.size )
  f64 decay      ( x every T60 )
  f64 damp       ( 0..1: high-mode loss, 0.5 as the material )
  f64 pos        ( 0..0.5: end or edge to middle )
  f64 excite     ( 0 strike, 1 scrape, 2 roll, 3 rub )
  f64 hard       ( 0..1: contact 6 ms to 0.06 ms )
  f64 speed      ( 0..1: the held exciters' speed )
  f64 rough      ( 0..1: the surface's bumps )
  f64 bounce     ( 0..1 )
  f64 drop       ( 0..1 )
  f64 rattle     ( 0..1 )
  f64 vary       ( 0..1 )
  f64 width      ( 0..1 )
  f64 tone       ( Hz )
  f64 gain
  f64 seed       ( 0..99: which noise this instance plays )
  ( derived - block-prepare )
  f64 sr  f64 inv-sr
  f64 ktone
  f64 kn                            ( scrape and roll low-pass )
  f64 kbump                         ( a bump's decay per sample )
  f64 pbump                         ( a bump's chance per sample )
  f64 gbump                         ( its size )
  f64 rate                          ( rub rate, Hz; roll wobble, Hz )
  f64 krh                           ( rattle high-pass, 2 kHz )
  f64 ka  f64 kr                    ( held exciters' attack and release )
  f64 kdl                           ( the glide's fall per sample )
  f64 k30                           ( rub wobble low-pass, 30 Hz )
;

( hz sr -- k : a one-pole's coefficient for a corner )
dsp: md-k | hz sr -- k |
  1.0  -6.283185307179586 hz f* sr f/ exp  f-
;

( p a0 a1 a2 a3 a4 -- y : the value for material p )
dsp: sel5 | p a0 a1 a2 a3 a4 -- y |
  a0  p 0.5 f> a1 rot select  p 1.5 f> a2 rot select
  p 2.5 f> a3 rot select  p 3.5 f> a4 rot select
;

( p x k -- y : a one-pole low-pass step on the cell at p )
dsp: md-lp | p x k -- y |
  p f@64 | s |
  s  x s f- k f*  f+ | y0 |
  ( flushed below -300 dB, so a tail never turns denormal )
  y0 fabs 1.0e-15 f> mask>f y0 f* | y |
  y p f!64
  y
;

dsp: md-block-prepare | ctx:Ctx state params:ModalParams -- |
  ctx.sr -> params.sr
  ctx.inv-sr -> params.inv-sr
  params.tone ctx.sr 0.45 f* fmin ctx.sr md-k -> params.ktone
  2000.0 ctx.sr md-k -> params.krh
  params.speed | s |
  params.excite 1.5 f<
    150.0 7000.0 s s fsqrt f* f* f+
    15.0 300.0 s f* f+  select  ctx.sr md-k -> params.kn
  ( scrape bumps: short and many; roll bumps: longer and few )
  params.excite 1.5 f<  0.75 0.97 select -> params.kbump
  params.excite 1.5 f<  400.0 30.0 select  s f* params.rough f* ctx.inv-sr f* -> params.pbump
  params.excite 1.5 f<  3.0 4.0 select -> params.gbump
  params.excite 2.5 f<  0.5 6.0 s f* f+  8.0 300.0 s 1.3 pow f* f+  select -> params.rate
  1.0  -1.0 0.015 ctx.sr f* f/ exp  f- -> params.ka
  1.0  -1.0 0.06 ctx.sr f* f/ exp  f- -> params.kr
  -1.0 0.04 ctx.sr f* f/ exp -> params.kdl
  30.0 ctx.sr md-k -> params.k30
;

( ctx state params -- : note-on part 1, the hit's constants )
dsp: md-key | ctx:Ctx state:ModalState params:ModalParams -- |
  ( a changed SEED reseeds the noise cells, which seed only from 0 )
  params.seed state.seedv f= | same |
  same state.rn 0.0 select -> state.rn
  same state.rv 0.0 select -> state.rv
  same state.rr 0.0 select -> state.rr
  params.seed -> state.seedv
  state.rn&  ctx.chan 5.0 f* 21.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.rv&  ctx.chan 5.0 f* 22.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.rr&  ctx.chan 5.0 f* 23.0 f+ params.seed 101.0 f* f+  rand-seed-once
  params.material | p |
  ctx.vel 0.0 1.0 fclamp | vel |
  vel -> state.vel
  1.0 -> state.gate
  ctx.hz params.scale f* 20.0 fmax | f0 |
  f0 -> state.k-f0
  params.sr 0.45 f* -> state.k-fny
  p 1.5 0.5 1.2 1.0 1.0 sel5 -> state.k-a
  p 2.0 1.25 1.17 1.7 1.0 sel5 -> state.k-b
  p 0.01 0.15 0.03 0.015 0.01 sel5 -> state.k-jit
  p 3.5 f> mask>f -> state.k-hide
  p 0.3 0.0 0.6 0.4 0.2 sel5 -> state.k-tilt
  ( where it is excited, moved a little each hit by VARY )
  state.rv& rand-b params.vary f* 0.08 f*  params.pos f+ 0.02 0.5 fclamp -> state.k-pos
  ( loss: T60 at f0 and at the top reference, then sigma = s0 + s1 f^sq )
  p 0.45 0.1 3.5 1.8 0.6 sel5 params.decay f* t60>sigma | sa |
  p 0.04 0.02 1.2 0.5 0.1 sel5 params.decay f*
    0.5 params.damp f- 4.0 f* exp2 f* t60>sigma sa fmax | sb |
  p 2.0 1.0 1.0 1.0 2.0 sel5 | sq |
  sq -> state.k-sq
  4000.0 f0 2.0 f* fmax | fh |
  fh sq pow  f0 sq pow  f- 1.0 fmax | span |
  sb sa f- span f/ -> state.k-s1
  sa  state.k-s1 f0 sq pow f*  f- 0.0 fmax -> state.k-s0
  ( the strike: contact time, shorter for a harder hit; the same impulse at any HARD )
  0.006  0.01 params.hard pow f*  1.3 0.5 vel f* f-  f* params.sr f* 2.0 fmax | tl |
  tl -> state.tlen
  params.excite 0.5 f<  0.0 -1.0 select -> state.t
  2.0 vel 1.2 pow f* tl f/ -> state.amp
  params.excite 0.5 f<  params.bounce 8.0 f* 0.5 f+ floor  0.0 select -> state.bn
  0.08 0.4 params.bounce f* f+ params.sr f* -> state.bgap
  state.bgap -> state.bt
  params.excite 0.5 f<  params.drop 0.06 f* vel f*  0.0 select -> state.dl
  0.0 -> state.bump
  ( level: the material and exciter trims )
  p 0.84 0.86 0.78 0.82 0.51 sel5
  params.excite 0.5 f<  1.0
    params.excite 1.5 f<  0.0175  params.excite 2.5 f<  0.0113 0.0134 select  select  select f*
  dup -> state.trim
  params.gain f* -> state.gain
;

( state params i -- : build mode i of the hit [i a literal in each stage] )
dsp: md-mode | state:ModalState params:ModalParams i -- |
  params.inv-sr | h |
  i 1.0 f+ | n |
  ( the series: a power law, or the membrane's Bessel table; each mode
    jittered by the material and by VARY )
  i state.k-a f+ state.k-a f/ log2 state.k-b f* exp2 | pl |
  state.k-hide 0.5 f>  memb-ratio i f@i  pl  select | r0 |
  state.rv& rand-b  state.k-jit params.vary 0.02 f* f+ f*  1.0 f+  r0 f* | r |
  i 0.5 f<  1.0 r select state.k-f0 f* | fr |
  fr state.k-fny f< mask>f | live |
  fr state.k-fny fmin 6.283185307179586 f* | w |
  w h zoh-coefs | c sw ws b1 b2 |
  c state.c& i f!i  sw state.sw& i f!i  ws state.ws& i f!i
  b1 state.b1& i f!i  b2 state.b2& i f!i
  w w f* state.w2& i f!i
  state.k-s0  state.k-s1 fr state.k-sq pow f* f+  h f* fneg exp state.rho& i f!i
  ( the drive: the mode's shape at the excitation point, tilted down the series )
  state.k-hide 0.5 f>  i 0.95 state.k-pos 1.9 f* f- memb-shape-at  n state.k-pos f* sinpi  select
    r -1.0 state.k-tilt f* pow f*  live f* state.phi& i f!i
  ( two listening points, spread by WIDTH )
  n 0.31 f* sinpi | ml |
  n 0.43 f* sinpi | mr |
  ml mr f+ 0.5 f* | mid |
  ml mid f- params.width f* mid f+ live f* state.wl& i f!i
  mr mid f- params.width f* mid f+ live f* state.wr& i f!i
  0.0 state.q& i f!i  0.0 state.v& i f!i
;

dsp: md-modes-0 | ctx state:ModalState params -- |
  0.0 12 [ | i |  state params i md-mode  i 1.0 f+ ] times drop
;
dsp: md-modes-1 | ctx state:ModalState params -- |
  12.0 12 [ | i |  state params i md-mode  i 1.0 f+ ] times drop
;

( ctx state params -- : excite this voice. )
dsp: md-note-on | ctx state params |
  ctx state params call: md-key
  ctx state params call: md-modes-0
  ctx state params call: md-modes-1
;

( ctx state params -- )
dsp: md-note-off | ctx state:ModalState params |
  0.0 -> state.gate
;

( state params -- f : the strike, with its bounces )
dsp: md-strike | state:ModalState params:ModalParams -- f |
  state.t | t |
  t state.tlen f/ | u |
  t 0.0 f>=  u 1.0 f< and | in |
  in  state.amp 0.5 f* 1.0 u 2.0 f* cospi f- f*  0.0 select | f |
  t 0.0 f>=  t 1.0 f+  t select | t1 |
  ( a bounce: lower by the restitution, and sooner by it, as a ball's )
  state.bt 1.0 f- | bt |
  bt 0.0 f<=  state.bn 0.5 f> and | go |
  0.45 0.35 params.bounce f* f+ | e |
  go 0.0 t1 select -> state.t
  go state.amp e f* state.amp select -> state.amp
  go state.bn 1.0 f- state.bn select -> state.bn
  go state.bgap e f* state.bgap select | gap |
  gap -> state.bgap
  go gap bt select -> state.bt
  go  state.dl params.drop 0.06 f* state.vel f* e f* fmax  state.dl  select  params.kdl f* -> state.dl
  f
;

( state params u -- b : a surface bump starting at chance pbump, decaying )
dsp: md-bump | state:ModalState params:ModalParams u -- b |
  u params.pbump f<  state.rn& rand-u params.gbump f*  state.bump params.kbump f*  select | b |
  b -> state.bump
  b
;

( state params -- f : scraping and rolling: filtered noise and bumps;
  rolling adds an out-of-round wobble )
dsp: md-scrape | state:ModalState params:ModalParams -- f |
  state.rn& rand-b | n |
  state.n1& n params.kn md-lp | a |
  state.n2& a params.kn md-lp | b |
  state params state.rn& rand-u md-bump | bp |
  state.ph params.rate params.inv-sr f* f+ ffrac | ph |
  ph -> state.ph
  params.excite 1.5 f<
    a 1.2 f* bp f+
    b 3.0 f*  1.0 params.rough 0.8 f* ph sin2pi f* f+ f*  bp f+  select
;

( state params -- f : stick-slip: a force that builds and snaps back,
  at a rate made unsteady by ROUGH )
dsp: md-rub | state:ModalState params:ModalParams -- f |
  state.rn& rand-b | n |
  state.n1& n params.k30 md-lp | wob |
  params.rate  1.0 params.rough 2.0 f* wob f* f+  f* params.inv-sr f*  0.0 fmax | dp |
  state.ph dp f+ ffrac | ph |
  ph -> state.ph
  ph 0.5 f- 2.0 f*  n 0.15 f* f+
;

( state params -- f : a held exciter under its envelope )
dsp: md-held | state:ModalState params:ModalParams -- f |
  state.gate 0.5 f>  params.ka params.kr  select | k |
  state.env  state.gate state.env f- k f*  f+ | env |
  env -> state.env
  params.excite 2.5 f<  [ state params md-scrape ]  [ state params md-rub ]  ifte | x |
  x env f* state.vel f*
;

( io ctx state params -- : one voice, one host sample.  Output ACCUMULATES. )
dsp: k-modal-voice | io:Io ctx state:ModalState params:ModalParams -- |
  params.excite 0.5 f<
    [ state params md-strike ]
    [ state params md-held ]
  ifte params.sr f* | f |
  state.dl | dl |
  params.inv-sr | h |
  0.0 0.0 0.0 MN [ | i ol or |
    state.q& i f@i | q |  state.v& i f@i | v |
    state.c& i f@i | c0 |  state.sw& i f@i | sw0 |  state.ws& i f@i | ws0 |
    state.w2& i f@i | w2 |
    c0 ws0 h f* dl f* f- | c |
    sw0  c0 h f* sw0 f- dl f* f+ | sw |
    ws0  ws0 w2 h f* c0 f* f+ dl f* f+ | ws |
    state.phi& i f@i f f* | fi |
    state.rho& i f@i | r |
    c q f*  sw v f* f+  r f*  state.b1& i f@i fi f* f+ | qn |
    ws q f* fneg  c v f* f+  r f*  state.b2& i f@i fi f* f+ | vn |
    qn state.q& i f!i  vn state.v& i f!i
    i 1.0 f+
    ol state.wl& i f@i vn f* f+
    or state.wr& i f@i vn f* f+ ] times | i ol or |
  ol state.gain f* | yl0 |
  or state.gain f* | yr0 |
  ( the rattle: noise gated by how far the body swings past 0.05 before
    GAIN, so the fader doesn't change how much it rattles )
  ol or f+ 0.5 f* state.trim f* fabs 0.05 f- 0.0 fmax | over |
  state.rr& rand-b over f* params.rattle f* params.gain f* 0.8 f* | z |
  z  state.rh& z params.krh md-lp  f- | buzz |
  state.tl& yl0 buzz f+ params.ktone md-lp | yl |
  state.tr& yr0 buzz f+ params.ktone md-lp | yr |
  io.out-l yl f+ -> io.out-l
  io.out-r yr f+ -> io.out-r
;
