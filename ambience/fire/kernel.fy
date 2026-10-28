( kernel.fy - fire: a hearth or campfire, per voice, in stereo.

  Farnell's model [Designing Sound, Practical 11: Fire]: three layers from
  white noise, summed, then heard through broad body resonances.

    crackle  short ticks at random, CRACKLE a second on average: noise
             through a band-pass of Q 1 at a random 1.5..16 kHz, under a
             ramp of 0..TICK ms [30 by default], squared; a short TICK
             makes sharper, drier pops.  CLUMP gathers the ticks into
             bursts [a burst runs about 0.25 s, 15% of the time] at the
             same average rate: kindling, not hardwood.  SPREAD mixes
             their sizes: most pops shrink and a few grow up to 5x,
             longer and lower, as a split in resinous wood.  Broad and quiet: a ringing or
             low pop reads as a stick breaking, not a fire.  SNAP is
             their level.
    hiss     noise above 1 kHz, gated by 1 Hz low-passed noise raised to
             the fourth power, so it comes in bursts and mostly rests.
             FLICKER scales the gate before the power: more, longer
             bursts.
    roar     the lapping of the flames: noise through a 30 Hz band-pass
             of Q 5, driven into a clip at 0.9 and high-passed at 25 Hz
             either side - the clip makes the flapping.
    body     the mix of the three at 0.2 / 0.3 / 0.6 is heard through
             Farnell's four copies' filters, two a side: L band-passes
             1200 Hz Q 0.6 and high-passes 1 kHz, R band-passes 2600 Hz
             Q 0.4 and 600 Hz Q 0.2.  Each side runs its own noise, so
             the field is wide; WIDTH 0 gives R the L noise.
    pops     each tick rises over 0.7 ms, or a quarter of a shorter
             ramp, rather than jumping: a tick that starts at full level
             in one sample is a digital click, heard as the audio
             breaking.  The quarter keeps short ticks at full level.
    bed      BED: the fire's low body, which the body filters remove: two
             noises, one a side, low-passed twice at 150 Hz and high-passed
             at 25, breathing by a 0.2 Hz noise [about 1.5 dB].  It skips
             the body filters and ignores WIDTH: its sides stay apart.
    lap      LAP: the clipped lapping, which the body filters reduce to a
             flutter, let past them in mono and low-passed at 400 Hz: the
             woof of burning gas, so the low end reads as flame, not air.
    tone     a final low-pass, the distance knob: far fires lose their
             top first.
    fades    ATTACK and RELEASE in seconds: a fire catching, a fire
             guttering out. )

include "kernels/00-primitives/ctx.fy"
include "kernels/00-primitives/math.fy"
include "kernels/00-primitives/rand.fy"
include "kernels/04-filters/coeffs.fy"

ustruct: FireState
  f64 gate
  f64 env
  f64 rl         ( noise cells: L, R, the hiss gates, the events )
  f64 rr
  f64 rgl
  f64 rgr
  f64 re
  f64 rk         ( noise cell: bursts and pop sizes )
  f64 act        ( 1 inside a burst )
  f64 cal        ( each side's pop size )
  f64 car
  f64 cel        ( crackle ramps and lengths in samples, band coefficients )
  f64 cer
  f64 cnl
  f64 cnr
  f64 cgl
  f64 cgr
  f64 cl1        ( crackle band-passes )
  f64 cl2
  f64 cr1
  f64 cr2
  f64 hgl        ( hiss: gate low-passes, 1 kHz high-pass state )
  f64 hgr
  f64 hpl
  f64 hpr
  f64 ll1        ( roar: 30 Hz band-passes, the two 25 Hz high-passes )
  f64 ll2
  f64 lr1
  f64 lr2
  f64 lal
  f64 lar
  f64 lbl
  f64 lbr
  f64 b1a        ( body filters: L 1200 and 1 kHz high-pass, R 2600 and 600 )
  f64 b1b
  f64 b2h
  f64 b3a
  f64 b3b
  f64 b4a
  f64 b4b
  f64 rb         ( noise cell: the bed's breath )
  f64 bb         ( breath low-pass )
  f64 dl1        ( bed: 150 Hz low-passes and 25 Hz high-pass, a side )
  f64 dl2
  f64 dlh
  f64 dr1
  f64 dr2
  f64 drh
  f64 lpm        ( lap low-pass )
  f64 tl         ( tone low-pass, a side )
  f64 tr
;

ustruct: FireParams
  f64 crackle    ( ticks a second )
  f64 snap       ( crackle level )
  f64 roar
  f64 hiss
  f64 flicker
  f64 tone       ( Hz )
  f64 width
  f64 atk
  f64 rel
  f64 gain
  f64 seed       ( 0..99: which noise this instance plays; 0 as before )
  f64 tick       ( longest crackle ramp, ms )
  f64 clump      ( 0..1: ticks gathered into bursts )
  f64 spread     ( 0..1: pop sizes from even to a few big ones )
  f64 bed        ( the low body's level )
  f64 lap        ( the lapping past the body filters )
  ( derived - block-prepare )
  f64 ka
  f64 kr
  f64 k1         ( one-pole coefficients: 1 Hz, 25 Hz, 1 kHz, TONE )
  f64 k25
  f64 k1k
  f64 ktone
  f64 tick-s
  f64 kend       ( per-sample chances a burst ends, starts )
  f64 kstart
  f64 k400
  f64 patk       ( pop rise, samples )
  f64 k150
  f64 kbr        ( breath low-pass and its normaliser )
  f64 nbr
  f64 g30        ( band-pass coefficients: 30, 1200, 2600, 600 Hz )
  f64 g1200
  f64 g2600
  f64 g600
;

( hz sr -- k : a one-pole's coefficient )
dsp: fire-k | hz sr -- k |
  1.0  -6.283185307179586 hz f* sr f/ exp  f-
;

( ctx state params -- )
dsp: fire-block-prepare | ctx:Ctx state params:FireParams |
  1.0  -1.0 params.atk ctx.sr f* f/ exp  f- -> params.ka
  1.0  -1.0 params.rel ctx.sr f* f/ exp  f- -> params.kr
  1.0 ctx.sr fire-k -> params.k1
  25.0 ctx.sr fire-k -> params.k25
  1000.0 ctx.sr fire-k -> params.k1k
  params.tone ctx.sr fire-k -> params.ktone
  params.tick 1000.0 f/ -> params.tick-s
  ( bursts last 0.25 s on average and fill 15% of the time )
  ctx.inv-sr 0.25 f/ -> params.kend
  ctx.inv-sr 0.25 f/ 0.15 f* 0.85 f/ -> params.kstart
  30.0 ctx.sr svf-g -> params.g30
  1200.0 ctx.sr svf-g -> params.g1200
  2600.0 ctx.sr svf-g -> params.g2600
  600.0 ctx.sr svf-g -> params.g600
  0.0007 ctx.sr f* -> params.patk
  150.0 ctx.sr fire-k -> params.k150
  400.0 ctx.sr fire-k -> params.k400
  0.2 ctx.sr fire-k -> params.kbr
  ( a one-pole passes uniform noise with spread sqrt[k / 6] )
  params.kbr 6.0 f/ fsqrt -> params.nbr
;

( ctx state params -- )
dsp: fire-note-on | ctx:Ctx state:FireState params:FireParams |
  1.0 -> state.gate
  state.rl&   ctx.chan 5.0 f* 11.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.rr&   ctx.chan 5.0 f* 12.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.rgl&  ctx.chan 5.0 f* 13.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.rgr&  ctx.chan 5.0 f* 14.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.re&   ctx.chan 5.0 f* 15.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.rk&   ctx.chan 5.0 f* 16.0 f+ params.seed 101.0 f* f+  rand-seed-once
  state.rb&   ctx.chan 5.0 f* 17.0 f+ params.seed 101.0 f* f+  rand-seed-once
;

( ctx state params -- )
dsp: fire-note-off | ctx state:FireState params |
  0.0 -> state.gate
;

( s1p s2p x g d -- bp : one TPT band-pass step, unity gain at the centre;
  d is 1 / 2Q )
dsp: fire-bp | s1p s2p x g d -- bp |
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

( p x k -- y : a one-pole low-pass step on the cell at p )
dsp: fire-lp | p x k -- y |
  p f@64 | s |
  s  x s f- k f*  f+ | y |
  y p f!64
  y
;

( p x k -- y : a one-pole high-pass, x less its low-pass )
dsp: fire-hp | p x k -- y |
  x  p x k fire-lp  f-
;

( left len -- e : the crackle's envelope, the falling ramp squared )
dsp: fire-env | left len -- e |
  left len 1.0 fmax f/ | r |
  r r f*
;

( io ctx state params -- : one voice, one host sample. )
dsp: k-fire-voice | io:Io ctx:Ctx state:FireState params:FireParams -- |
  state.gate 0.5 f>  params.ka  params.kr  select | k |
  state.env  state.gate state.env f- k f*  f+ | env |
  env -> state.env
  state.rl& rand-b | nl |
  state.rr& rand-b | nr0 |
  nr0  nl nr0 f- 1.0 params.width f- f*  f+ | nr |
  ( crackle ticks, a side each: a new tick restarts the ramp )
  ( bursts: a telegraph switching in and out; inside one the chance
    rises by 1 / 0.15, so the average rate holds.  CLUMP 0 is the plain
    rate, and the cell is separate so the ticks' draws are unchanged. )
  state.rk& rand-u | uk |
  state.act 0.5 f>  uk params.kend f< 0.0 1.0 select  uk params.kstart f< 1.0 0.0 select  select -> state.act
  1.0 params.clump f-  params.clump 6.666666666666667 f* state.act f*  f+ | burst |
  params.crackle ctx.inv-sr f*  burst f* | pchance |
  state.re& rand-u | ul |
  state.re& rand-u | ur |
  state.re& rand-u | ua |
  state.re& rand-u | ub |
  ul pchance f< | popl |
  ur pchance f< | popr |
  ( a 1.5..16 kHz centre and a 0..TICK ms ramp, as Farnell's random 30 )
  ua 14500.0 f* 1500.0 f+  ctx.sr 0.45 f* fmin | fa |
  ub params.tick-s f* ctx.sr f* 1.0 fmax | la |
  ( sizes: 5 u^4 has mean 1, so SPREAD keeps the average pop; the big
    ones run up to twice as long and 60% lower, all exactly 1 at 0 )
  state.rk& rand-u | usl |
  state.rk& rand-u | usr |
  1.0 params.spread f-  usl usl f* usl f* usl f* 5.0 f* params.spread f*  f+ | al |
  1.0 params.spread f-  usr usr f* usr f* usr f* 5.0 f* params.spread f*  f+ | ar |
  al 1.0 f- 0.25 f* 0.0 fmax | bigl |
  ar 1.0 f- 0.25 f* 0.0 fmax | bigr |
  la 1.0 bigl f+ f* | lal |
  la 1.0 bigr f+ f* | lar |
  fa 1.0 bigl 0.6 f* f- f* | fal |
  fa 1.0 bigr 0.6 f* f- f* | far |
  popl  al  state.cal  select -> state.cal
  popr  ar  state.car  select -> state.car
  popl  lal  state.cnl  select -> state.cnl
  popl  lal  state.cel 1.0 f- 0.0 fmax  select -> state.cel
  popl  fal ctx.sr svf-g  state.cgl  select -> state.cgl
  popr  lar  state.cnr  select -> state.cnr
  popr  lar  state.cer 1.0 f- 0.0 fmax  select -> state.cer
  popr  far 0.8 f* ctx.sr svf-g  state.cgr  select -> state.cgr
  state.cel state.cnl fire-env  state.cnl state.cel f-  state.cnl 0.25 f* params.patk fmin 1.0 fmax  f/ 1.0 fmin f* | el |
  state.cer state.cnr fire-env  state.cnr state.cer f-  state.cnr 0.25 f* params.patk fmin 1.0 fmax  f/ 1.0 fmin f* | er |
  state.cl1& state.cl2& nl state.cgl 0.5 fire-bp  el f* state.cal f* | cl |
  state.cr1& state.cr2& nr state.cgr 0.5 fire-bp  er f* state.car f* | cr |
  ( hiss: a 1 kHz high-pass, gated by a 1 Hz low-pass of noise to the
    fourth power.  Farnell's x10 and x600 assume Pd's scale; here the gate
    is normalised to unit spread first, sqrt[k / 6] for uniform noise. )
  state.rgl& rand-b | gnl |
  state.rgr& rand-b | gnr |
  params.flicker 1.2 f*  params.k1 6.0 f/ fsqrt f/ | gm |
  state.hgl& gnl params.k1 fire-lp  gm f* | gl |
  state.hgr& gnr params.k1 fire-lp  gm f* | gr |
  gl gl f* | gl2 |
  gr gr f* | gr2 |
  ( the gate to the fourth power can spike 20 dB in a rare burst; a soft
    cap at 4 holds those near 12 dB over a typical one and takes under
    0.3 dB off the usual ones )
  gl2 gl2 f* | gl4 |
  gr2 gr2 f* | gr4 |
  gl4  gl4 0.25 f* dup f* 1.0 f+ fsqrt  f/ | gcl |
  gr4  gr4 0.25 f* dup f* 1.0 f+ fsqrt  f/ | gcr |
  state.hpl& nl params.k1k fire-hp  gcl f* | hl |
  state.hpr& nr params.k1k fire-hp  gcr f* | hr |
  ( roar: 30 Hz Q 5, x100, high-pass, clip, high-pass, x0.6 )
  state.ll1& state.ll2& nl params.g30 0.1 fire-bp  100.0 f* | ral |
  state.lr1& state.lr2& nr params.g30 0.1 fire-bp  100.0 f* | rar |
  state.lal& ral params.k25 fire-hp  -0.9 0.9 fclamp | sal |
  state.lar& rar params.k25 fire-hp  -0.9 0.9 fclamp | sar |
  state.lbl& sal params.k25 fire-hp  0.6 f* | lapl |
  state.lbr& sar params.k25 fire-hp  0.6 f* | lapr |
  ( the mix: Farnell's 0.3 hiss and 0.6 roar at the default knobs; the
    crackle louder than his 0.2, as the normalised hiss is louder too )
  cl params.snap f* 3.0 f*  hl params.hiss f* 0.75 f*  f+  lapl params.roar f* 1.5 f*  f+ | xl |
  cr params.snap f* 3.0 f*  hr params.hiss f* 0.75 f*  f+  lapr params.roar f* 1.5 f*  f+ | xr |
  ( body: two of the four copies' filters a side; 0.4 matches his 4 x 0.2 )
  state.b1a& state.b1b& xl params.g1200 0.8333333333333334 fire-bp | b1 |
  state.b2h& xl params.k1k fire-hp | b2 |
  state.b3a& state.b3b& xr params.g2600 1.25 fire-bp | b3 |
  state.b4a& state.b4b& xr params.g600 2.5 fire-bp | b4 |
  ( bed: low noise a side, breathing, outside the body filters )
  state.rb& rand-b | nb |
  state.bb& nb params.kbr fire-lp  params.nbr f/ | br |
  1.0 br 0.18 f* f+ 0.0 fmax  params.bed f* 40.0 f* | bg |
  state.dl1& nl params.k150 fire-lp | dla |
  state.dl2& dla params.k150 fire-lp | dlb |
  state.dlh& dlb params.k25 fire-hp  bg f* | bedl |
  state.dr1& nr0 params.k150 fire-lp | dra |
  state.dr2& dra params.k150 fire-lp | drb |
  state.drh& drb params.k25 fire-hp  bg f* | bedr |
  state.lpm& lapl lapr f+ 0.5 f* params.k400 fire-lp  params.lap f* 4.0 f* | lapm |
  b1 b2 f+ 0.4 f*  bedl f+  lapm f+ | yl0 |
  b3 b4 f+ 0.4 f*  bedr f+  lapm f+ | yr0 |
  state.tl& yl0 params.ktone fire-lp | yl |
  state.tr& yr0 params.ktone fire-lp | yr |
  env params.gain f* | g |
  io.out-l  yl g f*  f+ -> io.out-l
  io.out-r  yr g f*  f+ -> io.out-r
;
