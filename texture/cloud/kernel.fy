( kernel.fy - CLOUD: a granular voice over a loaded sample.  Each held
  note runs eight grains read from the file around a play head; the note
  transposes them from ROOT.

  POSITION is where the head starts in the file, 0 .. 1, and SCAN moves it
  while the note holds [1 = the file's own speed, negative backwards, 0
  stays].  Each grain starts within SPRAY of the head [a share of the
  file], lasts GRAIN ms, plays at PITCH plus a random JITTER, runs
  backwards with probability REVERSE and pans within WIDTH.  DENSITY
  grains a second, capped by the eight slots.

  A grain stores its start, speed, length and pan on launch, so knob moves
  shape new grains without moving sounding ones [kernels/07-effects/
  buffer.fy, whose reader and grain envelope this reuses].  Grains never
  cross the file's ends: a grain is shortened to fit a short file, and a
  start past either end wraps round, as the head does, rather than
  stacking at the edge.  The overlap is normalised by its square root, as
  grains of a sustained sound add in power. )

include "kernels/07-effects/buffer.fy"

ustruct: CgGrain f64 pos f64 age f64 length f64 speed f64 pan ;

ustruct: CloudState
  f64 gate  f64 env  f64 vel
  f64 rate       ( the note's ratio from ROOT )
  f64 head       ( play head, source samples )
  f64 timer  f64 next  f64 rng
  CgGrain g0 CgGrain g1 CgGrain g2 CgGrain g3
  CgGrain g4 CgGrain g5 CgGrain g6 CgGrain g7
;

ustruct: CloudParams
  ( user-facing )
  f64 position  f64 scan  f64 spray
  f64 grain-ms  f64 density
  f64 pitch  f64 jitter  f64 reverse  f64 width
  f64 atk  f64 rel
  f64 root  f64 keytrack
  f64 gain
  ( the host-loaded source: pointer, length, rate )
  f64 src  f64 src-len  f64 src-sr
  ( derived )
  f64 grain-n  f64 period  f64 base-rate  f64 scan-k
  f64 ka  f64 kr
;

dsp: cloud-block-prepare | ctx:Ctx state p:CloudParams -- |
  ctx.sr | sr |
  sr p.density 0.5 64.0 fclamp f/ -> p.period
  p.grain-ms 0.001 f* sr f*  p.period 7.8 f*  fmin 16.0 fmax -> p.grain-n
  p.src-sr 1.0 fmax sr f/ | br |
  br -> p.base-rate
  p.scan br f* -> p.scan-k
  ( ATTACK and RELEASE are seconds to within 60 dB: ln 1000 time constants )
  1.0  -6.907755278982137 p.atk sr f* f/ exp  f- -> p.ka
  1.0  -6.907755278982137 p.rel sr f* f/ exp  f- -> p.kr
;

( ctx state params -- )
dsp: cloud-note-on | ctx:Ctx s:CloudState p:CloudParams |
  1.0 -> s.gate
  ctx.vel -> s.vel
  p.root 69.0 f- 12.0 f/ exp2 440.0 f* | root-hz |
  p.keytrack 0.5 f>  ctx.hz root-hz f/  1.0  select -> s.rate
  p.position 0.0 1.0 fclamp p.src-len f* -> s.head
  0.0 -> s.timer
  s.rng&  ctx.chan 7.0 f* 21.0 f+  rand-seed-once
;

( ctx state params -- )
dsp: cloud-note-off | ctx s:CloudState p |
  0.0 -> s.gate
;

( g s p slot launch r1 r2 r3 r4 -- l r : one grain slot; launches the
  next grain when it is this slot's turn. )
dsp: cg-grain | g:CgGrain s:CloudState p:CloudParams slot launch r1 r2 r3 r4 -- l r |
  p.src-len | len |
  s.rate  p.pitch r2 p.jitter f* f+ 12.0 f/ exp2 f*  p.base-rate f* | rate |
  p.grain-n  len 8.0 f- rate f/  fmin | gn |
  gn rate f* | span |
  s.head  r1 p.spray f* len f*  f+ | x |
  len span f- 4.0 f- 4.0 fmax | hi |
  hi 4.0 f- 1.0 fmax | room |
  x 4.0 f- | u |
  u  u room f/ floor room f*  f-  4.0 f+ | wrapped |
  x 4.0 f>=  x hi f<=  and  x wrapped select | start |
  r4 p.reverse f< | rev |
  launch s.next slot f= and | fire |
  fire  rev start span f+ start select  g.pos select -> g.pos
  fire 0.0 g.age select -> g.age
  fire gn g.length select -> g.length
  fire  rev rate fneg rate select  g.speed select -> g.speed
  fire r3 p.width f* g.pan select -> g.pan
  g.age g.length f< g.length 1.0 f> and mask>f | on |
  g.age g.length 1.0 fmax f/ | phase |
  1.0 phase 6.283185307179586 f* cos f- 0.5 f* on f* | env |
  g.length p.period f/ 1.0 fmax fsqrt | norm |
  env norm f/ | amp |
  g.pos g.age g.speed f* f+ | pos |
  p.src& p@64 len pos bf-read amp f* | y |
  y 1.0 g.pan f- 0.5 f* fsqrt f*
  y 1.0 g.pan f+ 0.5 f* fsqrt f*
  g.age 1.0 f+ g.length 1.0 f+ fmin -> g.age
;

( io ctx state params -- : one voice, one host sample. )
dsp: k-cloud-voice | io:Io ctx:Ctx s:CloudState p:CloudParams -- |
  s.gate 0.5 f>  p.ka  p.kr  select | k |
  s.env  s.gate s.env f- k f*  f+ | e0 |
  ( a release reaches true zero, so the voice can go idle )
  e0 1.0e-7 f<  s.gate 0.5 f<  and  0.0 e0 select | env |
  env -> s.env
  s.timer 0.0 f<=  env 1.0e-6 f>  and  p.src-len 64.0 f>  and | launch |
  s.rng& rand-b | r1 |
  s.rng& rand-b | r2 |
  s.rng& rand-b | r3 |
  s.rng& rand-u | r4 |
  s.g0& s p 0.0 launch r1 r2 r3 r4 cg-grain | l0 q0 |
  s.g1& s p 1.0 launch r1 r2 r3 r4 cg-grain | l1 q1 |
  s.g2& s p 2.0 launch r1 r2 r3 r4 cg-grain | l2 q2 |
  s.g3& s p 3.0 launch r1 r2 r3 r4 cg-grain | l3 q3 |
  s.g4& s p 4.0 launch r1 r2 r3 r4 cg-grain | l4 q4 |
  s.g5& s p 5.0 launch r1 r2 r3 r4 cg-grain | l5 q5 |
  s.g6& s p 6.0 launch r1 r2 r3 r4 cg-grain | l6 q6 |
  s.g7& s p 7.0 launch r1 r2 r3 r4 cg-grain | l7 q7 |
  l0 l1 f+ l2 f+ l3 f+ l4 f+ l5 f+ l6 f+ l7 f+ | gl |
  q0 q1 f+ q2 f+ q3 f+ q4 f+ q5 f+ q6 f+ q7 f+ | gr |
  launch s.next 1.0 f+ 8.0 f/ ffrac 8.0 f* s.next select -> s.next
  launch s.timer p.period f+ s.timer select 1.0 f- -1.0 fmax -> s.timer
  ( SCAN: the head moves at the file's rate times SCAN, wrapping )
  p.src-len 1.0 fmax | len |
  s.head p.scan-k f+ | h |
  h  h len f/ floor len f*  f- -> s.head
  ( x2: level with the factory sampler playing the source at the same GAIN )
  env s.vel f* p.gain f* 2.0 f* | g |
  io.out-l  gl g f*  f+ -> io.out-l
  io.out-r  gr g f*  f+ -> io.out-r
;
