( kernel.fy - opn: one channel of a 16-bit console's FM chip, the
  YM2612 [and its CMOS successor, the YM3438], per voice.

  The chip runs at 53267 Hz [7.67 MHz / 144].  This voice keeps the
  chip's units and steps at the host rate with the chip's increments
  scaled to it: phase in 20 bits, the envelope's 10-bit attenuation on
  its timer [a step every 3 chip samples], the LFO's 7-bit counter.

    pitch     the driver's job: the note becomes an 11-bit F-number and a
              3-bit block, so pitch is as coarse as the chip's.  DT adds
              the chip's key-code detune, MUL its multiple [0 is 1/2].
    operator  a 10-bit phase indexes the log-sine ROM; attenuation adds
              in the log domain; the exponent ROM turns it back into a
              14-bit signed output.  OP1 feeds back on itself [FB].
    ALG       the 8 wirings.  As on the chip, OP3 hears OP2's previous
              sample: OP2 is computed after it.
    envelope  AR D1R D2R RR SL in register units, KS scaling by key
              code; attack is exponential, the rest linear in dB.  Below
              -94 dB the operator is off.  TL attenuates in 0.75 dB steps.
    LFO       one triangle counter for PM [through PMS's shift tables]
              and AM [AMS, on operators with AM set].
    output    the carriers sum, each >> 5, into a 9-bit channel value:
              the DAC's resolution, so a quiet channel is coarse.  VOL
              and velocity add to the carriers' TL, as a driver's volume
              did, so they reach the DAC that way.
    CHIP      YM2612: the channel is on the DAC one slot in four and its
              sign the other three [Nuked-OPN2's DAC model], which leaves
              a step at every zero crossing and a faint sign-square in a
              muted speaker.  YM3438: clean.  The idle offset is taken
              out, as the console's output capacitor did, so a silent
              channel is 0.0.
    PAN       left, both or right: the chip had no in-between.

  Not modelled: SSG-EG, channel 3's per-operator frequencies, and the
  chip's one-sample pipeline delays other than OP2 -> OP3.
  Reference: Nuked-OPN2 [ym3438.c], Nuke.YKT, LGPL-2.1+. )

include "kernels/00-primitives/ctx.fy"
include "kernels/00-primitives/math.fy"
include "tables.fy"

ustruct: OpnState
  f64 key
  f64 vel
  f64 alive      ( 0 until the first note: a fresh voice starts silent )
  f64 bend
  ( the driver's pitch registers )
  f64 fnum
  f64 block
  f64 kcode
  ( per operator, OP1..OP4 )
  f64 ph 4       ( 20-bit phase )
  f64 lvl 4      ( envelope attenuation 0..1023 )
  f64 est 4      ( 0 attack / 1 decay / 2 sustain / 3 release )
  ( OP1's last two outputs for feedback; OP2's last for OP3 )
  f64 o1a
  f64 o1b
  f64 o2p
  ( envelope timer and LFO counter, in chip time )
  f64 eacc
  f64 etimer
  f64 lacc
  f64 lcnt
;

( Per operator, 10 values each, OP1 first: AR D1R D2R RR SL TL KS MUL DT
  AM.  Field k of operator i is ops[i * 10 + k]. )
ustruct: OpnParams
  f64 ops 40
  f64 alg
  f64 fb
  f64 ams
  f64 pms
  f64 lfo        ( 0 off, 1..8 the chip's 8 rates )
  f64 pan        ( 0 left / 1 both / 2 right )
  f64 chip       ( 0 YM2612 / 1 YM3438 )
  f64 vol        ( TL added to the carriers, 0..127 )
  f64 vel-amt    ( 0..1: velocity's share of up to 32 TL steps )
  f64 tune       ( semitones )
  f64 gain
  ( derived - block-prepare )
  f64 chip-inc   ( chip samples per host sample )
  f64 eg-inc     ( envelope steps per host sample )
  f64 lfo-per    ( chip samples per LFO step )
;

( x k -- floor[x / 2^k] : the chip's right shift, negatives included )
dsp: opn-shr | x k -- y |
  x  k fneg fexp2i  f* floor
;

( x m -- x mod m, for m > 0 and any x )
dsp: opn-mod | x m -- y |
  x  x m f/ floor m f*  f-
;

( op k params -- v : field k of operator op )
dsp: opn-op@ | op k params:OpnParams -- v |
  params.ops& op 10.0 f* k f+ f@i
;

( ctx state params -- )
dsp: opn-block-prepare | ctx:Ctx state params:OpnParams |
  53267.04 ctx.sr f/ -> params.chip-inc
  53267.04 3.0 f/ ctx.sr f/ -> params.eg-inc
  opn-lfo-cycles  params.lfo 1.0 f- 0.0 7.0 fclamp  f@i 1.0 f+ -> params.lfo-per
;

( state params -- : the note, bend and TUNE as F-number, block and key
  code, the way a sound driver set them: the block that keeps the
  F-number in 11 bits, rounded. )
dsp: opn-freq | state:OpnState params:OpnParams |
  state.key state.bend f+ params.tune f+ 69.0 f- 12.0 f/ exp2 440.0 f* | f |
  ( the F-number at block 0: f * 2^21 / fs )
  f 2097152.0 f* 53267.04 f/ | k |
  k 2047.5 f/ log2 floor 1.0 f+ 0.0 7.0 fclamp | b |
  k b fneg fexp2i f* 0.5 f+ floor 0.0 2047.0 fclamp | fn |
  fn -> state.fnum
  b -> state.block
  opn-fn-note fn 7.0 opn-shr f@i  b 4.0 f* f+ -> state.kcode
;

( state params op -- rate : the envelope rate for op's stage, with key
  scaling, 0..63; 0 when the stage's register is 0 )
dsp: opn-rate | state:OpnState params:OpnParams op -- rate |
  state.est& op f@i | s |
  op 0.0 params opn-op@ | ar |
  op 1.0 params opn-op@ | d1 |
  op 2.0 params opn-op@ | d2 |
  op 3.0 params opn-op@ 2.0 f* 1.0 f+ | rr |
  s 0.5 ar  s 1.5 d1  s 2.5 d2 rr  fsel-lt fsel-lt fsel-lt | r |
  state.kcode  3.0 op 6.0 params opn-op@ f-  opn-shr | ksv |
  r 2.0 f* ksv f+ 63.0 fmin | rate |
  r 0.5 f<  0.0  rate  select
;

( state params op -- : key-on for one operator: attack from where the
  envelope is [from silence on a fresh voice], the phase from 0, and at
  attack rates 62-63 the level jumps to full. )
dsp: opn-op-on | state:OpnState params:OpnParams op |
  state.alive 0.5 f<  1023.0  state.lvl& op f@i  select | l |
  0.0  state.est& op f!i
  0.0  state.ph& op f!i
  state params op opn-rate | rate |
  rate 62.0 f>=  0.0  l  select  state.lvl& op f!i
;

( ctx state params -- )
dsp: opn-note-on | ctx:Ctx state:OpnState params:OpnParams |
  ctx.pitch -> state.key
  ctx.vel -> state.vel
  0.0 -> state.bend
  state params opn-freq
  state params 0.0 opn-op-on
  state params 1.0 opn-op-on
  state params 2.0 opn-op-on
  state params 3.0 opn-op-on
  1.0 -> state.alive
;

( ctx state params -- : key-off: every operator to release )
dsp: opn-note-off | ctx state:OpnState params |
  3.0 state.est& 0.0 f!i
  3.0 state.est& 1.0 f!i
  3.0 state.est& 2.0 f!i
  3.0 state.est& 3.0 f!i
;

( ctx state params -- : a pitch bend is a new F-number, as drivers did )
dsp: opn-note-expr | ctx:Ctx state:OpnState params:OpnParams |
  ctx.pitch state.key f- -> state.bend
  state params opn-freq
;

( state params op tk shl tlow -- : one operator's envelope.  tk: 1.0 when
  the envelope timer stepped this sample, a number rather than a mask, as
  it crosses a word boundary; shl: the timer's lowest set bit + 1
  [0 when it is 0]; tlow: its low 2 bits. )
dsp: opn-eg-op | state:OpnState params:OpnParams op tk shl tlow |
  state.est& op f@i | s |
  state.lvl& op f@i | l |
  state params op opn-rate | rate |
  rate 2.0 opn-shr | r4 |
  ( rates below 48 step on some timer ticks, 48+ on all, by more )
  r4 shl f+ 16.0 opn-mod | sum |
  sum 12.0 f=  1.0
    sum 13.0 f=  rate 1.0 opn-shr 2.0 opn-mod
      sum 14.0 f=  rate 2.0 opn-mod  0.0  select
    select
  select | inc-lo |
  opn-stephi  rate 4.0 opn-mod 4.0 f*  tlow f+  f@i  r4 f+ 11.0 f- 4.0 fmin | inc-hi |
  rate 48.0 f<  inc-lo inc-hi  select | inc0 |
  tk 0.5 f>  rate 0.5 f> and  inc0  0.0  select | inc |
  rate 62.0 f>= | rmax |
  l 1008.0 f>= | off |
  op 4.0 params opn-op@ | sl |
  sl 14.5 f>  62.0  sl 2.0 f*  select | slv |
  inc 0.5 f> | stepping |
  ( attack: toward 0 by a share of the distance; done at 0 )
  l  l fneg 1.0 f-  inc fexp2i f*  32.0 f/ floor  f+ | la |
  stepping rmax not and  la  l  select | l-att |
  l 0.5 f<  1.0  0.0  select | s-att |
  ( decay to SL, then sustain; release; linear steps of 2^[inc - 1] )
  l  inc 1.0 f- fexp2i  f+ | lstep |
  l 4.0 opn-shr slv f= | at-sl |
  at-sl  l  stepping off not and  lstep l select  select | l-dec |
  at-sl  2.0  1.0  select | s-dec |
  stepping off not and  lstep  l  select | l-rest |
  s 0.5 f<  l-att  s 1.5 f<  l-dec  l-rest  select  select | l2 |
  s 0.5 f<  s-att  s 1.5 f<  s-dec  s  select  select | s2 |
  ( a stage other than attack that falls below -94 dB is off )
  s 0.5 f>  off and | gone |
  gone  1023.0  l2 1023.0 fmin  select  state.lvl& op f!i
  gone  3.0  s2  select  state.est& op f!i
;

( state params f12 op -- inc : the operator's phase step per chip sample
  from the 12-bit F-number [after PM], block, DT and MUL )
dsp: opn-inc | state:OpnState params:OpnParams f12 op -- inc |
  f12 state.block fexp2i f* 4.0 f/ floor | base |
  op 8.0 params opn-op@ | dt |
  dt 4.0 opn-mod | dtl |
  state.kcode 28.0 fmin | kc |
  ( the chip ORs [DT = 3] with DT's bit 1: it adds 0, 2 or 3 )
  kc 2.0 opn-shr 9.0 f+  dtl 1.5 f> dtl 0.0 select  f+ | sum |
  opn-detune  sum 2.0 opn-mod 4.0 f*  kc 4.0 opn-mod f+  f@i  9.0 sum 1.0 opn-shr f-  opn-shr | det0 |
  dtl 0.5 f<  0.0  det0  select | det |
  dt 3.5 f>  det fneg  det  select | sdet |
  base sdet f+ 131072.0 opn-mod | bf |
  op 7.0 params opn-op@ | mul |
  mul 0.5 f<  1.0  mul 2.0 f*  select | multi |
  bf multi f* 1.0 opn-shr 1048576.0 opn-mod
;

( state params op mod eg-am vadd -- out : one operator's 14-bit output.
  mod is in phase units [1024 a cycle]; vadd adds to TL, for carriers. )
dsp: opn-op | state:OpnState params:OpnParams op mod eg-am vadd -- out |
  op 9.0 params opn-op@ 0.5 f>  eg-am  0.0  select | am |
  state.lvl& op f@i  am f+  op 5.0 params opn-op@ 8.0 f* f+  vadd 8.0 f* f+  1023.0 fmin | egout |
  state.ph& op f@i 10.0 opn-shr mod f+ 1024.0 opn-mod | idx |
  idx 8.0 opn-shr | hi |
  idx hi 256.0 f* f- | lo |
  hi 2.0 opn-mod 0.5 f>  255.0 lo f-  lo  select | q |
  opn-logsin q f@i  egout 4.0 f* f+  8191.0 fmin | level |
  level 8.0 opn-shr | e |
  opn-exp  255.0 level e 256.0 f* f- f-  f@i 1024.0 f+ 4.0 f*  e opn-shr | mag |
  hi 1.5 f>  mag fneg  mag  select
;

( state op inc params -- : advance one operator's phase by a host sample )
dsp: opn-advance | state:OpnState op inc params:OpnParams |
  state.ph& op f@i  inc params.chip-inc f* f+  1048576.0 opn-mod  state.ph& op f!i
;

( io ctx state params -- : one channel, one host sample. )
dsp: k-opn-voice | io:Io ctx state:OpnState params:OpnParams -- |
  ( LFO: a 7-bit counter, AM a triangle of it, PM its top 5 bits )
  state.lacc params.chip-inc f+ | la |
  la params.lfo-per f>= | lst |
  lst  la params.lfo-per f-  la  select -> state.lacc
  lst  state.lcnt 1.0 f+ 128.0 opn-mod  state.lcnt  select | lc |
  params.lfo 0.5 f<  0.0  lc  select | lcnt |
  lcnt -> state.lcnt
  lcnt 63.5 f>  lcnt 64.0 f-  63.0 lcnt f-  select 2.0 f* | amraw |
  amraw  opn-am-shift params.ams 0.0 3.0 fclamp f@i  opn-shr | eg-am |
  lcnt 2.0 opn-shr | lpm |
  ( envelope timer: 12 bits, a step every 3 chip samples )
  state.eacc params.eg-inc f+ | ea |
  ea 1.0 f>= | tick |
  tick  ea 1.0 f-  ea  select -> state.eacc
  tick  state.etimer 1.0 f+ 4096.0 opn-mod  state.etimer  select | et |
  tick mask>f | tk |
  et -> state.etimer
  ( its lowest set bit, counted up from 1 )
  0.0
  et 2.0 opn-mod 0.5 f< 1.0 0.0 select f+
  et 4.0 opn-mod 0.5 f< 1.0 0.0 select f+
  et 8.0 opn-mod 0.5 f< 1.0 0.0 select f+
  et 16.0 opn-mod 0.5 f< 1.0 0.0 select f+
  et 32.0 opn-mod 0.5 f< 1.0 0.0 select f+
  et 64.0 opn-mod 0.5 f< 1.0 0.0 select f+
  et 128.0 opn-mod 0.5 f< 1.0 0.0 select f+
  et 256.0 opn-mod 0.5 f< 1.0 0.0 select f+
  et 512.0 opn-mod 0.5 f< 1.0 0.0 select f+
  et 1024.0 opn-mod 0.5 f< 1.0 0.0 select f+
  et 2048.0 opn-mod 0.5 f< 1.0 0.0 select f+ | tz |
  et 0.5 f<  0.0  tz 1.0 f+  select | shl |
  et 4.0 opn-mod | tlow |
  state params 0.0 tk shl tlow opn-eg-op
  state params 1.0 tk shl tlow opn-eg-op
  state params 2.0 tk shl tlow opn-eg-op
  state params 3.0 tk shl tlow opn-eg-op
  ( PM: the F-number moved by the LFO through PMS's shift tables )
  state.fnum | fn |
  fn 4.0 opn-shr | fh |
  lpm 16.0 opn-mod | l16 |
  l16 7.5 f>  15.0 l16 f-  l16  select | ll |
  params.pms 0.0 7.0 fclamp | pms |
  pms 8.0 f* ll f+ | si |
  fh  opn-lfo-sh1 si f@i  opn-shr  fh  opn-lfo-sh2 si f@i  opn-shr  f+ | fm0 |
  pms 5.5 f>  fm0 pms 5.0 f- fexp2i f*  fm0  select 2.0 opn-shr | fm |
  lpm 15.5 f>  fm fneg  fm  select | dfm |
  fn 2.0 f* dfm f+ 4096.0 opn-mod | f12 |
  ( the driver's volume and velocity, on the carriers' TL )
  params.alg 0.0 7.0 fclamp | alg |
  1.0 state.vel f- params.vel-amt f* 32.0 f* floor params.vol f+ | vadd |
  ( OP1, with feedback from its last two outputs )
  params.fb 0.5 f<  0.0  state.o1a state.o1b f+  10.0 params.fb f-  opn-shr  select | fbm |
  opn-car1 alg f@i | c1 |
  state params 0.0 fbm eg-am  vadd c1 f*  opn-op | o1 |
  state.o1a -> state.o1b
  o1 -> state.o1a
  ( OP3 before OP2: it hears OP2's previous sample )
  opn-c3-1 alg f@i o1 f*  opn-c3-2 alg f@i state.o2p f*  f+  1.0 opn-shr | m3 |
  opn-car3 alg f@i | c3 |
  state params 2.0 m3 eg-am  vadd c3 f*  opn-op | o3 |
  opn-c2-1 alg f@i o1 f*  1.0 opn-shr | m2 |
  opn-car2 alg f@i | c2 |
  state params 1.0 m2 eg-am  vadd c2 f*  opn-op | o2 |
  o2 -> state.o2p
  opn-c4-1 alg f@i o1 f*  opn-c4-2 alg f@i o2 f* f+  opn-c4-3 alg f@i o3 f* f+  1.0 opn-shr | m4 |
  state params 3.0 m4 eg-am  vadd  opn-op | o4 |
  ( the carriers into the 9-bit channel value )
  o1 5.0 opn-shr c1 f*  o2 5.0 opn-shr c2 f* f+  o3 5.0 opn-shr c3 f* f+  o4 5.0 opn-shr f+
  -256.0 255.0 fclamp | acc |
  ( the DAC.  YM2612: +4 or -3 around the value with the idle +4 taken
    out, so a gap of 7 at zero; a muted side carries 0 or -8 by sign )
  acc 0.0 f< | neg |
  params.chip 0.5 f< | ym2612 |
  ym2612  neg acc 7.0 f- acc select  acc  select | on |
  ym2612  neg -8.0 0.0 select  0.0  select | muted |
  params.pan 1.5 f<  on  muted  select | l |
  params.pan 0.5 f>  on  muted  select | r |
  params.gain 256.0 f/ | g |
  io.out-l  l g f*  f+ -> io.out-l
  io.out-r  r g f*  f+ -> io.out-r
  ( phases on by a host sample's worth of chip samples )
  state 0.0  state params f12 0.0 opn-inc  params opn-advance
  state 1.0  state params f12 1.0 opn-inc  params opn-advance
  state 2.0  state params f12 2.0 opn-inc  params opn-advance
  state 3.0  state params f12 3.0 opn-inc  params opn-advance
;
