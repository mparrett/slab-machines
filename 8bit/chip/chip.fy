( chip.fy - a game-console sound-chip voice machine.

  A user machine [Slab docs/25]: the voice is kernel.fy beside it.  A
  part is one chip channel: pulse, triangle or noise.  The classic
  layout is four tracks - two pulses, a triangle bass and noise drums.
  Pitch, level and duty move at the 60 Hz frame tick [the control! word,
  800 samples at 48 kHz]. )

include "kernel.fy"
include "machines/lib/manifest.fy"

: manifest
  "Chip" voice-sample machine*
  "k-chip-voice"       render!
  "chip-note-on"       note-on!
  "chip-note-off"      note-off!
  "chip-block-prepare" block-prepare!
  "chip-tick" 800      control!
  8 voices!
  ChipState.size  state-size!
  ChipParams.size params-size!
  560.0 panel-w!

  "WAVE" "WAVE" "chip-wave" ChipParams.wave 0.0 switch
    "PULSE" 0.0 opt  "TRI" 1.0 opt  "NOISE" 2.0 opt  as-vradio
  "WAVE" "DUTY" "chip-duty" ChipParams.duty 2.0 switch
    "12%" 0.125 opt  "25%" 0.25 opt  "50%" 0.5 opt  "75%" 0.75 opt  as-vradio
  "WAVE" "CYCLE" "chip-duty-mod" ChipParams.duty-mod 0.0 switch
    "OFF" 0.0 opt  "ON" 1.0 opt
  "WAVE" "NOISE" "chip-noise" ChipParams.noise-mode 0.0 switch
    "LONG" 0.0 opt  "SHORT" 1.0 opt
  "WAVE" 4 strip

  "ENV" "ATK" "chip-atk" ChipParams.atk-s 0.0  2.0 0.0  curve-pow knob as-fader
  "ENV" "DEC" "chip-dec" ChipParams.dec-s 0.02 4.0 0.5  curve-exp knob as-fader
  "ENV" "SUS" "chip-sus" ChipParams.sus   0.0  1.0 0.6  curve-lin knob as-fader
  "ENV" "REL" "chip-rel" ChipParams.rel-s 0.0  3.0 0.08 curve-pow knob as-fader
  "ENV" 4 strip

  "PITCH" "ARP" "chip-arp" ChipParams.arp 0.0 switch
    "OFF" 0.0 opt  "MAJ" 1.0 opt  "MIN" 2.0 opt  "OCT" 3.0 opt
    "5TH" 4.0 opt  "SUS4" 5.0 opt  "DIM" 6.0 opt  as-list
  "PITCH" "SPEED" "chip-arp-rate" ChipParams.arp-rate 1.0 8.0 2.0 int-step
  "PITCH" "OCT" "chip-oct" ChipParams.oct 2.0 switch
    "-2" -2.0 opt  "-1" -1.0 opt  "0" 0.0 opt  "+1" 1.0 opt  "+2" 2.0 opt  as-list
  "PITCH" "SWEEP" "chip-sweep" ChipParams.sweep -96.0 96.0 0.0 curve-lin knob
  "PITCH" 4 strip

  "VIB" "DEPTH" "chip-vib" ChipParams.vib 0.0 1.0 0.0 curve-pow knob as-fader
  "VIB" "RATE" "chip-vib-rate" ChipParams.vib-rate 1.0 12.0 6.0 curve-lin knob as-fader
  "VIB" "DELAY" "chip-vib-delay" ChipParams.vib-delay 0.0 1.0 0.2 curve-pow knob as-fader
  "VIB" 3 strip

  "OUT" "VEL" "chip-vel" ChipParams.vel-amt 0.0 1.0 0.0 curve-lin knob
  "OUT" "LEVEL" "chip-level" ChipParams.level 0.0 1.0 0.7 curve-pow knob as-fader
  "OUT" 2 strip

  "ENV ADSR" "ENV" adsr-display

  1.0 row
    1.0 cell  "WAVE" 1.0 item
    1.0 cell  "ENV" 1.0 item
    1.0 cell  "ENV ADSR" 1.0 item
  1.0 row
    1.0 cell  "PITCH" 1.0 item
    1.0 cell  "VIB" 1.0 item
    1.0 cell  "OUT" 1.0 item

  machine-desc
;
