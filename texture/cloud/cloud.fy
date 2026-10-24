( cloud.fy - CLOUD: a granular voice that turns any sample into a bed.
  Hold a note and eight grains read the file around a slowly moving play
  head, transposed by the note from ROOT.  A user machine [Slab docs/25];
  the DSP is in kernel.fy.  LOAD on the waveform swaps the source; the
  default is a VSCO 2 CE violin section holding A4 [440 Hz; VSCO files it as A3]. )

include "kernel.fy"
include "machines/lib/manifest.fy"

: manifest
  "CLOUD" voice-sample machine*
  "k-cloud-voice"       render!
  "cloud-note-on"       note-on!
  "cloud-note-off"      note-off!
  "cloud-block-prepare" block-prepare!
  6 voices!
  stereo
  CloudState.size  state-size!
  CloudParams.size params-size!
  640.0 panel-w!

  "source" CloudParams.src CloudParams.src-len CloudParams.src-sr "assets/strings-a4.wav" asset
  "SOURCE" "source" waveform-display

  "HEAD" "POSITION" "cloud-position" CloudParams.position 0.0 1.0 0.3 curve-lin knob
  "HEAD" "SCAN"     "cloud-scan"     CloudParams.scan -2.0 2.0 0.1 curve-lin knob
  "HEAD" "SPRAY"    "cloud-spray"    CloudParams.spray 0.0 1.0 0.1 curve-pow knob

  "GRAIN" "SIZE"    "cloud-grain"    CloudParams.grain-ms 10.0 500.0 120.0 curve-exp knob
  "GRAIN" "DENSITY" "cloud-density"  CloudParams.density 1.0 64.0 16.0 curve-exp knob
  "GRAIN" "REVERSE" "cloud-reverse"  CloudParams.reverse 0.0 1.0 0.0 curve-lin knob

  "PITCH" "PITCH"   "cloud-pitch"    CloudParams.pitch -24.0 24.0 0.0 curve-lin knob
  "PITCH" "JITTER"  "cloud-jitter"   CloudParams.jitter 0.0 12.0 0.2 curve-pow knob
  "PITCH" "ROOT"    "cloud-root"     CloudParams.root 24.0 96.0 69.0 curve-lin knob
  "PITCH" "KEY"     "cloud-key"      CloudParams.keytrack 1.0 switch
    "OFF" 0.0 opt  "ON" 1.0 opt  as-button

  "AMP" "WIDTH"   "cloud-width" CloudParams.width 0.0 1.0 0.7 curve-lin knob
  "AMP" "ATTACK"  "cloud-atk"   CloudParams.atk 0.01 20.0 0.8 curve-exp knob
  "AMP" "RELEASE" "cloud-rel"   CloudParams.rel 0.01 20.0 2.5 curve-exp knob
  "AMP" "GAIN"    "cloud-gain"  CloudParams.gain 0.0 1.0 0.5 curve-pow knob as-fader

  "HEAD" 3 strip
  "GRAIN" 3 strip
  "PITCH" 4 strip
  "AMP" 4 strip
  1.0 row
    1.0 cell  "SOURCE" 1.0 item
  1.0 row
    3.0 cell  "HEAD" 1.0 item
    3.0 cell  "GRAIN" 1.0 item
    4.0 cell  "PITCH" 1.0 item
    4.0 cell  "AMP" 1.0 item

  machine-desc
;
