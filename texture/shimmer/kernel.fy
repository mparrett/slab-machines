( kernel.fy - SHIMMER: a long hall whose own tail is pitch-shifted and fed
  back into it, so every pass climbs [or falls] another INTERVAL.

  Signal path, per sample:
    in -> LO CUT -> + shimmer return -> 4 diffusion allpasses per side
       -> 8-line FDN [hall lengths, Hadamard mix, per-line decay and
          damping, lines 1 and 6 modulated] -> wet
    wet -> two-tap pitch shifter [delay-line, triangular crossfade]
        -> TONE lowpass, a fixed 150 Hz highpass, x AMOUNT, tanh
        -> the shimmer return, one sample later
  The ring helpers and the Hadamard come from the factory reverb
  [kernels/07-effects/reverb.fy]; the tank is its HALL, without the
  velvet matrix, BASS or the gate.

  BEND adds -12 .. +12 semitones to INTERVAL.  The switch steps; BEND
  glides, so automating it slides the whole tail between intervals.

  The shifter reads its ring at two delays half a window apart.  Each
  delay sweeps the window at the rate the ratio needs [ratio - 1 samples
  per sample], and each tap fades to zero where it wraps, so the gains
  sum to 1 at every sample.

  FREEZE sets every line's gain to 1 and its damping off, mutes the
  input and the return, and stops the tank LFO with lines 1 and 6 read at
  whole samples, since a fractional read loses top end every pass: the
  Hadamard is orthonormal, so the tank then holds what it has
  indefinitely.

  One packed buffer, sized for SIZE 2.0 at 96 kHz:
    region  offset  cap         region  offset  cap
    ap-l0        0    516       f0        9776   5852
    ap-l1      516    908       f1       15628   7188  modulated
    ap-l2     1424   1388       f2       22816   8340
    ap-l3     2812   1860       f3       31156   9660
    ap-r0     4672    572       f4       40816  11060
    ap-r1     5244   1020       f5       51876  12396
    ap-r2     6264   1532       f6       64272  13908  modulated
    ap-r3     7796   1980       f7       78180  15396
                                ps-l     93576   9600
                                ps-r    103176   9600
                                total   112776 -> 1.18 s at 96 kHz )

include "kernels/07-effects/reverb.fy"

:: PS-CAP 9600.0 ;
:: PS-L 93576.0 ;
:: PS-R 103176.0 ;

ustruct: ShimState
  f64 buf        ( host-injected ring base pointer )
  f64 buf-len
  f64 seeded
  f64 lfo-s  f64 lfo-c
  f64 lc-l   f64 lc-r          ( LO CUT states )
  f64 apl0-pos f64 apl1-pos f64 apl2-pos f64 apl3-pos
  f64 apr0-pos f64 apr1-pos f64 apr2-pos f64 apr3-pos
  f64 fpos 8                   ( line heads )
  f64 fdz 8                    ( damping states )
  f64 ps-pos                   ( shifter write head, both sides )
  f64 ps-ph                    ( shifter phase, 0 .. 1 )
  f64 st-l   f64 st-r          ( return TONE lowpass )
  f64 sh-l   f64 sh-r          ( return 150 Hz highpass )
  f64 fb-l   f64 fb-r          ( the return, fed in next sample )
;

ustruct: ShimParams
  ( user-facing )
  f64 space      ( SIZE 0.5 .. 2.0 )
  f64 decay      ( seconds, RT60 )
  f64 damp-hz
  f64 diff
  f64 amount     ( shimmer return 0 .. 1 )
  f64 semis      ( INTERVAL in semitones )
  f64 bend       ( BEND: semitones added to INTERVAL, -12 .. 12 )
  f64 tone-hz    ( return lowpass )
  f64 win-s      ( shifter window, seconds )
  f64 mod-depth  f64 mod-rate
  f64 lowcut-hz
  f64 width
  f64 mix
  f64 freeze     ( 0 off, 1 on )
  ( derived )
  f64 ap-len 8
  f64 flen 8
  f64 fg 8
  f64 damp-a  f64 lc-a  f64 tone-a  f64 sh-a
  f64 ap-g  f64 in-g  f64 fb-g
  f64 ps-w  f64 ps-inc
  f64 mod-k  f64 mod-spl
;

( base cap fs -- len : a ring length at this rate and SIZE, whole samples. )
dsp: shm-len | base cap fs -- len |
  base fs f* 2.0 cap 64.0 f- fclamp floor
;

dsp: shim-block-prepare
  | ctx:Ctx state params:ShimParams |
  ctx.sr | sr |
  sr 0.000020833333333 f* params.space f* | fs |
  113.0 516.0 fs shm-len params.ap-len& 0.0 f!i
  211.0 908.0 fs shm-len params.ap-len& 1.0 f!i
  331.0 1388.0 fs shm-len params.ap-len& 2.0 f!i
  449.0 1860.0 fs shm-len params.ap-len& 3.0 f!i
  127.0 572.0 fs shm-len params.ap-len& 4.0 f!i
  239.0 1020.0 fs shm-len params.ap-len& 5.0 f!i
  367.0 1532.0 fs shm-len params.ap-len& 6.0 f!i
  479.0 1980.0 fs shm-len params.ap-len& 7.0 f!i
  1447.0 5852.0 fs shm-len | l0 |   1781.0 7188.0 fs shm-len | l1 |
  2069.0 8340.0 fs shm-len | l2 |   2399.0 9660.0 fs shm-len | l3 |
  2749.0 11060.0 fs shm-len | l4 |  3083.0 12396.0 fs shm-len | l5 |
  3461.0 13908.0 fs shm-len | l6 |  3833.0 15396.0 fs shm-len | l7 |
  l0 params.flen& 0.0 f!i  l1 params.flen& 1.0 f!i
  l2 params.flen& 2.0 f!i  l3 params.flen& 3.0 f!i
  l4 params.flen& 4.0 f!i  l5 params.flen& 5.0 f!i
  l6 params.flen& 6.0 f!i  l7 params.flen& 7.0 f!i
  params.freeze 0.5 f> | fz |
  params.decay 0.1 fmax | rt |
  fz 1.0 l0 rt sr vb-loop-g select params.fg& 0.0 f!i
  fz 1.0 l1 rt sr vb-loop-g select params.fg& 1.0 f!i
  fz 1.0 l2 rt sr vb-loop-g select params.fg& 2.0 f!i
  fz 1.0 l3 rt sr vb-loop-g select params.fg& 3.0 f!i
  fz 1.0 l4 rt sr vb-loop-g select params.fg& 4.0 f!i
  fz 1.0 l5 rt sr vb-loop-g select params.fg& 5.0 f!i
  fz 1.0 l6 rt sr vb-loop-g select params.fg& 6.0 f!i
  fz 1.0 l7 rt sr vb-loop-g select params.fg& 7.0 f!i
  fz 1.0  1.0  -6.2831853 params.damp-hz f* sr f/ exp  f-  select -> params.damp-a
  1.0  -6.2831853 params.lowcut-hz f* sr f/ exp  f- -> params.lc-a
  1.0  -6.2831853 params.tone-hz f* sr f/ exp  f- -> params.tone-a
  1.0  -6.2831853 150.0 f* sr f/ exp  f- -> params.sh-a
  params.diff 0.6 f* -> params.ap-g
  fz 0.0 1.0 select -> params.in-g
  ( 0.7: at AMOUNT 1 and DECAY 20 s a chord blooms about 3 dB over the
    plain hall instead of 6, and stays under full scale.  The tank's gain
    grows about as sqrt(DECAY), so past 20 s the return shrinks to match
    and the cascade can't run away. )
  20.0 rt f/ fsqrt 1.0 fmin | fb-cap |
  fz 0.0 params.amount 0.7 f* fb-cap f* select -> params.fb-g
  params.win-s sr f* 64.0 PS-CAP 4.0 f- fclamp floor | w |
  w -> params.ps-w
  params.semis params.bend f+ 0.083333333333333 f* exp2 1.0 f- w f/ -> params.ps-inc
  fz 0.0 params.mod-rate 6.2831853 f* sr f/ select -> params.mod-k
  params.mod-depth fs f* -> params.mod-spl
;

( ctx state params -- : runs every block; seeds the oscillator once. )
dsp: shim-prepare
  | ctx state:ShimState params:ShimParams |
  state.seeded 0.5 f< 1.0 state.lfo-c select -> state.lfo-c
  1.0 -> state.seeded
;

( --- the tank --------------------------------------------------------- )

( state params buf xl xr -- il ir : four diffusion allpasses per side. )
dsp: shm-diffuse | state:ShimState params:ShimParams buf xl xr -- il ir |
  params.ap-g | g |
  buf 0.0 state.apl0-pos& params.ap-len& 0.0 f@i xl g vb-ap | a1 |
  buf 516.0 state.apl1-pos& params.ap-len& 1.0 f@i a1 g vb-ap | a2 |
  buf 1424.0 state.apl2-pos& params.ap-len& 2.0 f@i a2 g vb-ap | a3 |
  buf 2812.0 state.apl3-pos& params.ap-len& 3.0 f@i a3 g vb-ap
  buf 4672.0 state.apr0-pos& params.ap-len& 4.0 f@i xr g vb-ap | b1 |
  buf 5244.0 state.apr1-pos& params.ap-len& 5.0 f@i b1 g vb-ap | b2 |
  buf 6264.0 state.apr2-pos& params.ap-len& 6.0 f@i b2 g vb-ap | b3 |
  buf 7796.0 state.apr3-pos& params.ap-len& 7.0 f@i b3 g vb-ap
;

( state params buf off i -- v : line i's oldest sample. )
dsp: shm-rd | state:ShimState params:ShimParams buf off i -- v |
  buf  off state.fpos& i f@i f+  f@i
;

( state params buf off i m -- v : line i read m samples early, linear. )
dsp: shm-rdm | state:ShimState params:ShimParams buf off i m -- v |
  params.flen& i f@i | len |
  state.fpos& i f@i 1.0 f+ m f+ | r0 |
  r0 len  r0  r0 len f-  fsel-lt  0.0 len 2.0 f- fclamp | r |
  buf off r f+ f@i | s0 |
  r 1.0 f+ | r1 |
  r1 len  r1  r1 len f-  fsel-lt | rw |
  buf off rw f+ f@i | s1 |
  s0  s1 s0 f-  r ffrac f*  f+
;

( state params i v -- d : line i's decay and damping. )
dsp: shm-dec | state:ShimState params:ShimParams i v -- d |
  v params.fg& i f@i f* | u |
  state.fdz& i f@i | z |
  z  u z f-  params.damp-a f*  f+ | zn |
  zn state.fdz& i f!i
  zn
;

( state params buf off i x -- : write line i and advance its head. )
dsp: shm-wr | state:ShimState params:ShimParams buf off i x -- |
  state.fpos& i f@i | p |
  x  buf off p f+  f!i
  p params.flen& i f@i vb-next state.fpos& i f!i
;

( state params buf il ir ma mb -- wl wr : one FDN sample. )
dsp: shm-fdn | state:ShimState params:ShimParams buf il ir ma mb -- wl wr |
  state params 0.0  state params buf 9776.0 0.0 shm-rd  shm-dec | d0 |
  state params 1.0  state params buf 15628.0 1.0 ma shm-rdm  shm-dec | d1 |
  state params 2.0  state params buf 22816.0 2.0 shm-rd  shm-dec | d2 |
  state params 3.0  state params buf 31156.0 3.0 shm-rd  shm-dec | d3 |
  state params 4.0  state params buf 40816.0 4.0 shm-rd  shm-dec | d4 |
  state params 5.0  state params buf 51876.0 5.0 shm-rd  shm-dec | d5 |
  state params 6.0  state params buf 64272.0 6.0 mb shm-rdm  shm-dec | d6 |
  state params 7.0  state params buf 78180.0 7.0 shm-rd  shm-dec | d7 |
  d0 d2 f+ d4 f- d6 f- 0.5 f*
  d1 d3 f+ d5 f- d7 f- 0.5 f* | wl wr |
  d0 d1 d2 d3 d4 d5 d6 d7 vb-h8 | y0 y1 y2 y3 y4 y5 y6 y7 |
  il 0.5 f* | jl |
  ir 0.5 f* | jr |
  state params buf 9776.0 0.0  y0 jl f+  shm-wr
  state params buf 15628.0 1.0 y1 jr f+  shm-wr
  state params buf 22816.0 2.0 y2 jl f+  shm-wr
  state params buf 31156.0 3.0 y3 jr f+  shm-wr
  state params buf 40816.0 4.0 y4 jl f+  shm-wr
  state params buf 51876.0 5.0 y5 jr f+  shm-wr
  state params buf 64272.0 6.0 y6 jl f+  shm-wr
  state params buf 78180.0 7.0 y7 jr f+  shm-wr
  wl wr
;

( --- the shifter and the return ---------------------------------------- )

( buf off pos d -- v : ring read d samples behind the write head, linear. )
dsp: shm-ps-rd | buf off pos d -- v |
  pos d f- | r0 |
  r0 0.0  r0 PS-CAP f+  r0  fsel-lt | r |
  r floor | i0 |
  i0 1.0 f+ | j |
  j PS-CAP j 0.0 fsel-lt | i1 |
  buf off i0 f+ f@i | s0 |
  buf off i1 f+ f@i | s1 |
  s0  s1 s0 f-  r i0 f-  f*  f+
;

( state params buf wl wr -- pl pr : both sides shifted by INTERVAL; writes
  this sample's wet into the rings. )
dsp: shm-shift | state:ShimState params:ShimParams buf wl wr -- pl pr |
  state.ps-pos | pp |
  state.ps-ph params.ps-inc f+ | q |
  q q floor f- | ph1 |
  ph1 -> state.ps-ph
  ph1 0.5 f+ | q2 |
  q2 q2 floor f- | ph2 |
  params.ps-w | w |
  1.0 ph1 f- w f* 2.0 f+ | da |
  1.0 ph2 f- w f* 2.0 f+ | db |
  1.0  ph1 2.0 f* 1.0 f- fabs  f- | ga |
  1.0 ga f- | gb |
  buf PS-L pp da shm-ps-rd ga f*  buf PS-L pp db shm-ps-rd gb f*  f+
  buf PS-R pp da shm-ps-rd ga f*  buf PS-R pp db shm-ps-rd gb f*  f+
  wl  buf PS-L pp f+  f!i
  wr  buf PS-R pp f+  f!i
  pp PS-CAP vb-next -> state.ps-pos
;

( state params pl pr -- : TONE lowpass, the 150 Hz highpass, AMOUNT and a
  tanh bound, stored as next sample's return. )
dsp: shm-return | state:ShimState params:ShimParams pl pr -- |
  state.st-l | tl0 |
  tl0  pl tl0 f-  params.tone-a f*  f+ | tl |
  tl -> state.st-l
  state.sh-l | hl0 |
  hl0  tl hl0 f-  params.sh-a f*  f+ | hl |
  hl -> state.sh-l
  tl hl f- params.fb-g f* tanh-fast -> state.fb-l
  state.st-r | tr0 |
  tr0  pr tr0 f-  params.tone-a f*  f+ | tr |
  tr -> state.st-r
  state.sh-r | hr0 |
  hr0  tr hr0 f-  params.sh-a f*  f+ | hr |
  hr -> state.sh-r
  tr hr f- params.fb-g f* tanh-fast -> state.fb-r
;

( io ctx state params -- : one stereo sample. )
dsp: k-shim-tick | io:Io ctx state:ShimState params:ShimParams -- |
  state.buf& p@64 | buf |
  io.in-l | xl |
  io.in-r | xr |
  ( LO CUT, a one-pole highpass, then the return )
  state.lc-l | zl |
  zl  xl zl f-  params.lc-a f*  f+ | ll |
  ll -> state.lc-l
  state.lc-r | zr |
  zr  xr zr f-  params.lc-a f*  f+ | lr |
  lr -> state.lc-r
  xl ll f- params.in-g f* state.fb-l f+ | ul |
  xr lr f- params.in-g f* state.fb-r f+ | ur |
  ( the tank LFO: a magic-circle pair )
  state.lfo-s params.mod-k state.lfo-c f* f+ | ls |
  state.lfo-c params.mod-k ls f* f- | lc |
  ls -> state.lfo-s
  lc -> state.lfo-c
  ls 1.0 f+ 0.5 f* params.mod-spl f* | ma0 |
  lc 1.0 f+ 0.5 f* params.mod-spl f* | mb0 |
  params.freeze 0.5 f> | fz |
  fz ma0 floor ma0 select | ma |
  fz mb0 floor mb0 select | mb |
  state params buf ul ur shm-diffuse | il ir |
  state params buf il ir ma mb shm-fdn | wl wr |
  state params buf wl wr shm-shift | pl pr |
  state params pl pr shm-return
  ( WIDTH, mid/side, and the mix )
  wl wr f+ 0.5 f* | m |
  wl wr f- 0.5 f* params.width f* | s |
  1.0 params.mix f- | dg |
  xl dg f*  m s f+ params.mix f*  f+ -> io.out-l
  xr dg f*  m s f- params.mix f*  f+ -> io.out-r
;
