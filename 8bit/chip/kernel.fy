( kernel.fy - the chip machine's voice, a game-console sound-chip voice: a pulse at four duty
  cycles, a 4-bit stepped triangle, or LFSR noise.

  The chips ran their control at the video frame, so this does too:
  chip-tick is the control! word, called every 800 samples [60 Hz at
  48 kHz], and it steps the envelope, the arpeggio, vibrato, the pitch
  sweep and the duty cycle.  The render word only plays the wave at the
  tick's increment and volume, so pitch and level move in frame steps,
  which is the sound.

  The envelope is linear and its output is quantized to 15 volume steps
  after velocity.  The pulse is polyBLEP: the chips' own output stages
  rolled the top off, and a naive pulse at 48 kHz aliases in a way the
  hardware didn't.  The triangle is not band-limited: its 32 steps are
  the hardware's.  The noise is the 15-bit LFSR, fed back from bit 1
  [LONG] or bit 6 [SHORT, the metallic loop], clocked at 32x the note
  up to one step a sample.  A 30 Hz coupling cap takes out the pulse's
  DC, as the console's output caps did.

  Polyphony contract as Slab's kernels/06-voices/juno.fy: note data is
  per-voice state, params are shared, the render accumulates into out.

  The includes below aren't in this folder: Slab resolves them against
  its factory root, so the machine runs from outside Slab's tree. )

include "kernels/00-primitives/ctx.fy"
include "kernels/00-primitives/math.fy"
include "kernels/01-oscillators/primitives/phase.fy"
include "kernels/01-oscillators/primitives/blep.fy"

ustruct: ChipState
  f64 phase
  f64 inc        ( per-sample phase increment, set each tick )
  f64 vol        ( quantized amplitude, set each tick )
  f64 env
  f64 stage      ( 0 attack, 1 decay/sustain )
  f64 gate
  f64 note-hz
  f64 vel        ( velocity scale, from VEL )
  f64 tick       ( ticks since note-on )
  f64 age        ( seconds since note-on )
  f64 vib-phase
  f64 sweep      ( accumulated sweep, semitones )
  f64 duty
  f64 lfsr
  f64 oc-x       ( the output coupling cap: last input, last output )
  f64 oc-y
;

ustruct: ChipParams
  ( user-facing )
  f64 wave       ( 0 pulse / 1 triangle / 2 noise - switch )
  f64 duty       ( pulse width, 0.125..0.75 - switch value )
  f64 duty-mod   ( 0 fixed / 1 cycle 12.5-25-50-25 per tick )
  f64 noise-mode ( 0 long / 1 short )
  f64 atk-s
  f64 dec-s
  f64 sus
  f64 rel-s
  f64 arp        ( 0 off / 1 maj / 2 min / 3 oct / 4 fifth / 5 sus4 / 6 dim )
  f64 arp-rate   ( ticks per arpeggio step )
  f64 sweep      ( semitones per second )
  f64 vib        ( vibrato depth, semitones )
  f64 vib-rate   ( Hz )
  f64 vib-delay  ( seconds from note-on )
  f64 oct        ( octave shift, -2..2 )
  f64 vel-amt
  f64 level
  ( derived - filled by chip-block-prepare )
  f64 inv-sr
  f64 tick-dt    ( seconds per tick )
  f64 atk-inc    ( envelope steps per tick, full scale )
  f64 dec-inc
  f64 rel-inc
  f64 arp-a      ( the arpeggio's second and third notes, semitones )
  f64 arp-b
  f64 arp-len
  f64 wave-mul   ( noise clocks at 32x the note )
  f64 tap        ( LFSR feedback tap as a divisor: bit 1 = 2, bit 6 = 64 )
  f64 oc-a
;

( ctx state params -- : derived fills, all idempotent. )
dsp: chip-block-prepare | ctx:Ctx state params:ChipParams |
  ctx.sr | sr |
  1.0 sr f/ | inv |
  inv -> params.inv-sr
  800.0 inv f* | tdt |
  tdt -> params.tick-dt
  tdt params.atk-s 0.0001 fmax f/ -> params.atk-inc
  tdt params.dec-s 0.0001 fmax f/ -> params.dec-inc
  tdt params.rel-s 0.0001 fmax f/ -> params.rel-inc
  params.arp | m |
  m 0.5 0.0  m 1.5 4.0  m 2.5 3.0  m 3.5 12.0  m 4.5 7.0  m 5.5 5.0 3.0
    fsel-lt fsel-lt fsel-lt fsel-lt fsel-lt fsel-lt -> params.arp-a
  m 0.5 0.0  m 1.5 7.0  m 2.5 7.0  m 3.5 0.0  m 4.5 12.0  m 5.5 7.0 6.0
    fsel-lt fsel-lt fsel-lt fsel-lt fsel-lt fsel-lt -> params.arp-b
  m 0.5 1.0  m 2.5 3.0  m 3.5 2.0 3.0  fsel-lt fsel-lt fsel-lt -> params.arp-len
  params.wave 1.5 1.0 32.0 fsel-lt -> params.wave-mul
  params.noise-mode 0.5 2.0 64.0 fsel-lt -> params.tap
  1.0  1.0  6.283185307179586 30.0 f* inv f*  f+  f/ -> params.oc-a
;

( ctx state params -- : start this voice.  A legato note keeps the
  envelope and the phase and slides; any other note restarts them, the
  way a write to the chip's period register restarted its sequencer. )
dsp: chip-note-on | ctx:Ctx state:ChipState params:ChipParams |
  ctx.legato 0.5 f> | leg |
  ctx.hz -> state.note-hz
  1.0  1.0 ctx.vel f-  params.vel-amt f*  f- -> state.vel
  1.0 -> state.gate
  leg state.env 0.0 select -> state.env
  leg state.stage 0.0 select -> state.stage
  leg state.age 0.0 select -> state.age
  leg state.vib-phase 0.0 select -> state.vib-phase
  leg state.phase ctx.phase select -> state.phase
  0.0 -> state.tick
  0.0 -> state.sweep
  ( the LFSR must never hold 0; the chip powered up with 1 )
  state.lfsr 0.0 f= 1.0 state.lfsr select -> state.lfsr
;

( ctx state params -- : release from the current level. )
dsp: chip-note-off | ctx state:ChipState params |
  0.0 -> state.gate
;

( ctx state params -- : one frame tick. )
dsp: chip-tick | ctx state:ChipState params:ChipParams |
  state.tick | t |
  ( arpeggio: which note of the pattern this tick plays )
  t params.arp-rate 1.0 fmax f/ floor | step |
  step params.arp-len f/ floor params.arp-len f* | base |
  step base f- | idx |
  idx 0.5 0.0  idx 1.5 params.arp-a params.arp-b fsel-lt  fsel-lt | arp |
  ( envelope: linear attack to 1, decay to SUS, release to 0 )
  state.env | e |
  e params.atk-inc f+ | ea |
  e params.dec-inc f- params.sus fmax | ed |
  state.stage 0.5  ea 1.0 fmin  ed  fsel-lt | eh |
  state.stage 0.5  ea 1.0 0.0 1.0 fsel-lt  1.0  fsel-lt -> state.stage
  e params.rel-inc f- 0.0 fmax | er |
  state.gate 0.5 er eh fsel-lt | e2 |
  e2 -> state.env
  e2 state.vel f* 15.0 f* 0.5 f+ floor 15.0 f/ -> state.vol
  ( vibrato, held off for DELAY after the note-on )
  state.age | age |
  state.vib-phase params.vib-rate params.tick-dt f* f+ ffrac | vp |
  vp -> state.vib-phase
  age params.vib-delay 0.0  vp sin2pi params.vib f*  fsel-lt | vib |
  ( pitch sweep, accumulated per tick )
  state.sweep params.sweep params.tick-dt f* f+ -96.0 96.0 fclamp | sw |
  sw -> state.sweep
  arp vib f+ sw f+ params.oct 12.0 f* f+ 12.0 f/ exp2 state.note-hz f* | hz |
  hz params.wave-mul f* params.inv-sr f* 1.0 fmin -> state.inc
  ( duty cycling: 12.5, 25, 50, 25 on successive ticks )
  t 4.0 f/ floor 4.0 f* | q |
  t q f- | k |
  k 0.5 0.125  k 1.5 0.25  k 2.5 0.5 0.25  fsel-lt fsel-lt fsel-lt | cyc |
  params.duty-mod 0.5 params.duty cyc fsel-lt -> state.duty
  t 1.0 f+ -> state.tick
  age params.tick-dt f+ -> state.age
;

( The wave at this sample, -1..1. )
dsp: chip-osc | state:ChipState params:ChipParams -- y |
  state.phase state.inc f+ | raw |
  raw wrap01 | ph |
  ph -> state.phase
  params.wave 0.5 f<
  [ ph state.inc state.duty pulse-polyblep ]
  [ params.wave 1.5 f<
    [ ( 32 steps: 15 down to 0, then 0 up to 15 )
      ph 32.0 f* floor | s |
      s 16.0  15.0 s f-  s 16.0 f-  fsel-lt  7.5 f/ 1.0 f-  1.5 f* ]
    [ ( one LFSR step each time the phase wraps; output high while bit 0 is clear )
      state.lfsr | r |
      r 0.5 f* floor | h |
      r h 2.0 f* f- | b0 |
      r params.tap f/ floor | q |
      q  q 0.5 f* floor 2.0 f*  f- | bt |
      b0 bt f- fabs 16384.0 f* h f+ | r2 |
      raw 1.0 f>=  r2 r  select | r3 |
      r3 -> state.lfsr
      r3  r3 0.5 f* floor 2.0 f*  f-  0.5  1.0 -1.0  fsel-lt ]
    ifte ]
  ifte
;

( io ctx state params -- : one voice tick. )
dsp: k-chip-voice | io ctx state:ChipState params:ChipParams |
  state params chip-osc | y |
  y state.vol f* params.level f* 0.3 f* | v |
  state.oc-y v f+ state.oc-x f-  params.oc-a f* | o |
  v -> state.oc-x
  o -> state.oc-y
  io f@64 o f+ io f!64
;
