( kernel.fy - opndac: the FM chip's channel 6 in DAC mode, where the
  sound driver's Z80 wrote 8-bit samples to it by hand.

  There was no sample clock: the driver looped, writing a byte every so
  many Z80 cycles, so the rate was whatever the loop came to [RATE] and
  wobbled with bus contention [JITTER].  Each write is the nearest source
  sample, with no interpolation, rounded to 8 bits and held until the
  next.  LEVEL scales before the rounding, as a driver's software volume
  did, so a quieter sample is a coarser one.  The byte becomes the 9-bit
  DAC value and leaves through the same DAC as the FM channels: CHIP and
  PAN are opn's.  One voice: a new note cuts the last.

  Keymap layout and zone search are the factory sampler's. )

include "kernels/06-voices/sampler.fy"

ustruct: DacState
  f64 start
  f64 end
  f64 pos        ( source sample index )
  f64 step       ( source samples per write )
  f64 wacc       ( toward the next write )
  f64 jit        ( this interval's stretch )
  f64 rng
  f64 hold       ( the 9-bit DAC value )
  f64 gain
;

ustruct: DacParams
  ( keymap - injected by the host )
  f64 pool
  f64 zones
  f64 zone-count
  f64 edits
  ( user-facing )
  f64 rate       ( Hz )
  f64 jitter     ( 0..1: the share of an interval a write can drift )
  f64 level
  f64 tune
  f64 root
  f64 pan
  f64 chip
  f64 gain
  ( derived )
  f64 winc       ( writes per host sample )
;

( x m -- x mod m )
dsp: dac-mod | x m -- y |
  x  x m f/ floor m f*  f-
;

( ctx state params -- )
dsp: dac-block-prepare | ctx:Ctx state params:DacParams |
  params.rate 1000.0 32000.0 fclamp ctx.sr f/ -> params.winc
;

( ctx state params -- )
dsp: dac-note-on | ctx:Ctx state:DacState params:DacParams |
  params.zones& p@64 | zt |
  ctx.pitch | key |
  zt key ctx.vel 127.0 f* 0.0 0.0 zone-find | k |
  k 0.0 f>= | hit |
  k 0.0 fmax 19.0 f* | c |
  hit  zt c f@i  4.0  select | start |
  hit  zt c 1.0 f+ f@i  0.0  select | len |
  zt c 2.0 f+ f@i | zsr0 |
  zsr0 0.5 f<  13000.0  zsr0  select | zsr |
  zt c 7.0 f+ f@i | zroot |
  zroot 0.0  params.root zroot fsel-lt | root |
  params.edits& p@64 | ed:ZoneEdits |
  zt c 8.0 f+ f@i  ed.level& k 0.0 fmax f@i db>lin  f* -> state.gain
  key params.tune f+  ed.tune& k 0.0 fmax f@i f+  root f- 0.08333333333333333 f* exp2 | ratio |
  start -> state.start
  start len f+ -> state.end
  start -> state.pos
  zsr ratio f*  params.rate 1000.0 32000.0 fclamp f/ -> state.step
  ( write the first byte now )
  1.0 -> state.wacc
  1.0 -> state.jit
;

( ctx state params -- : the DAC plays a sample out; key-off doesn't stop
  it.  The store is a no-op: a dsp word must do something. )
dsp: dac-note-off | ctx state:DacState params |
  state.hold -> state.hold
;

( io ctx state params -- )
dsp: k-dac-voice | io:Io ctx state:DacState params:DacParams -- |
  params.pool& p@64 | buf |
  state.wacc params.winc state.jit f/ f+ | wa |
  wa 1.0 f>= | wr |
  wr  wa 1.0 f-  wa  select -> state.wacc
  ( the next interval's drift, from a small LCG )
  state.rng 1103515245.0 f* 12345.0 f+ 2147483648.0 dac-mod | r2 |
  wr  r2  state.rng  select -> state.rng
  r2 2147483648.0 f/ 2.0 f* 1.0 f- params.jitter f* 0.5 f* 1.0 f+ | j |
  wr  j  state.jit  select -> state.jit
  ( the write: nearest sample, 8 bits, to the 9-bit DAC value )
  state.pos | p |
  p state.end f< | live |
  buf p floor f@i state.gain f* params.level f* 128.0 f* 0.5 f+ floor -128.0 127.0 fclamp 2.0 f* | v |
  wr  live v 0.0 select  state.hold  select | h |
  h -> state.hold
  wr  p state.step f+  p  select -> state.pos
  ( the DAC, as opn's )
  h 0.0 f< | neg |
  params.chip 0.5 f< | ym2612 |
  ym2612  neg h 7.0 f- h select  h  select | on |
  ym2612  neg -8.0 0.0 select  0.0  select | muted |
  params.pan 1.5 f<  on  muted  select | l |
  params.pan 0.5 f>  on  muted  select | r |
  params.gain 256.0 f/ | g |
  io.out-l  l g f*  f+ -> io.out-l
  io.out-r  r g f*  f+ -> io.out-r
;
