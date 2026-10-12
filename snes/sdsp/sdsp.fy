( sdsp.fy - S-DSP: a 16-bit console's sample-playback voice.

  A user machine [Slab docs/25]: the voice is kernel.fy beside it.  It
  plays a keymap like the factory sampler, through the console DSP's
  32 kHz clock, pitch register, Gaussian interpolation and envelope.
  The instruments in assets/ are short looped samples that went
  through the console's BRR codec [tools/brr_pack.py]; LOAD takes any
  WAV, FLAC or SFZ.  8 voices, as the hardware had.  Pair it with
  sdspecho for the console's echo. )

include "kernel.fy"
include "machines/lib/manifest.fy"

: manifest
  "S-DSP" voice-sample machine*
  "k-sdsp-voice"       render!
  "sdsp-note-on"       note-on!
  "sdsp-note-off"      note-off!
  "sdsp-note-expr"     note-expr!
  "sdsp-block-prepare" block-prepare!
  8 voices!
  SdspState.size  state-size!
  SdspParams.size params-size!
  760.0 panel-w!

  "brr" SdspParams.pool SdspParams.zones SdspParams.zone-count SdspParams.edits "assets/strings.wav" keymap

  "PITCH" "TUNE" "sdsp-tune" SdspParams.tune -24.0 24.0 0.0 curve-lin knob
  "PITCH" "ROOT" "sdsp-root" SdspParams.root 24.0 96.0 60.0 curve-lin knob
  "PITCH" "LOOP" "sdsp-loop" SdspParams.loop-mode 0.0 switch
    "FILE" 0.0 opt  "OFF" 1.0 opt

  ( the ADSR registers, in their own units )
  "ADSR" "AR"  "sdsp-ar"  SdspParams.ar  0.0 15.0 15.0 int-step
  "ADSR" "DR"  "sdsp-dr"  SdspParams.dr  0.0 7.0 7.0 int-step
  "ADSR" "SL"  "sdsp-sl"  SdspParams.sl  0.0 7.0 7.0 int-step
  "ADSR" "SR"  "sdsp-sr"  SdspParams.sr  0.0 31.0 0.0 int-step
  "ADSR" "REL" "sdsp-rel" SdspParams.rel 0.0 31.0 0.0 int-step

  "NOISE" "SRC" "sdsp-noise" SdspParams.noise 0.0 switch
    "SAMPLE" 0.0 opt  "NOISE" 1.0 opt
  "NOISE" "CLOCK" "sdsp-nck" SdspParams.nck 0.0 31.0 28.0 int-step

  ( the sound driver's vibrato; DEPTH 0 is off )
  "VIB" "DEPTH" "sdsp-vib-depth" SdspParams.vib-depth 0.0 100.0 0.0 curve-lin knob
  "VIB" "RATE"  "sdsp-vib-rate"  SdspParams.vib-rate 1.0 12.0 5.5 curve-lin knob
  "VIB" "DELAY" "sdsp-vib-delay" SdspParams.vib-delay 0.0 2.0 0.3 curve-lin knob

  "AMP" "VEL"   "sdsp-vel"   SdspParams.vel-amt 0.0 1.0 0.5 curve-lin knob
  "AMP" "LEVEL" "sdsp-level" SdspParams.level 0.0 1.0 0.7 curve-pow knob as-fader

  "WAVE" "brr" waveform-display
  "ZONES" "brr" zone-display
  "PITCH" 3 strip
  "ADSR" 5 strip
  "NOISE" 2 strip
  "VIB" 3 strip
  "AMP" 2 strip

  1.0 row
    2.0 cell  "WAVE" 1.0 item
    1.0 cell  "ZONES" 1.0 item
  0.0 row
    3.0 cell  "PITCH" 1.0 item
    5.0 cell  "ADSR" 1.0 item
    2.0 cell  "NOISE" 1.0 item
    3.0 cell  "VIB" 1.0 item
    2.0 cell  "AMP" 1.0 item
  machine-desc
;
