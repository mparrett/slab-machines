( kernel.fy - the sdsp machine's voice: one voice of a 16-bit console's
  sample-playback DSP [the S-DSP], playing a host-loaded keymap.

  The DSP runs at 32 kHz whatever the host rate, so the voice keeps its
  own 32 kHz clock and does everything below once per tick:

    pitch     a 14-bit pitch counter, 0x1000 plays the stored sample at
              32 kHz.  The note sets it once and it is truncated to the
              register, so it tops out just under 4x [0x3FFF]: a sample
              stored low can't be played far above its root.
    Gaussian  4-tap interpolation weighted from the DSP's 512-entry ROM
              table [sdsp-gauss], at 8 bits of the position's fraction.
              It is the muffled edge of the console's sound.
    noise     a 15-bit LFSR clocked at one of the 32 envelope rates;
              NOISE plays it in place of the sample.
    vibrato   the sound driver's, not the DSP's: a triangle on the pitch
              register, DEPTH cents at RATE Hz, after DELAY.
    envelope  11 bits, stepped at the 32 envelope rates [sdsp-period]:
              attack +32 a step [+1024 at AR 15], decay and sustain
              exponential [-1, then -1/256 of what's left].  Key-off is
              -8 a tick, about 8 ms from full; REL 1..31 slows it down to
              the exponential decrease at that rate [the GAIN register,
              which sound drivers used for longer releases].

  The ticks' output is linearly interpolated onto the host's grid.

  The sample itself is whatever the keymap holds.  The hardware stored
  samples as BRR [4-bit ADPCM]; the pack in ../assets went through a real
  BRR round trip offline [tools/brr_pack.py], so its noise is in the
  files and the voice needn't model it.

  Keymap layout and zone search are the factory sampler's
  [kernels/06-voices/sampler.fy], so the host's keymap loading, SFZ
  support and the zone list work unchanged.  Includes resolve against
  Slab's factory root. )

include "kernels/06-voices/sampler.fy"

( The S-DSP Gaussian table, 512 entries; out of 2048. )
table: sdsp-gauss 511
  f>i [
    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
    1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2
    2 2 3 3 3 3 3 4 4 4 4 4 5 5 5 5
    6 6 6 6 7 7 7 8 8 8 9 9 9 10 10 10
    11 11 11 12 12 13 13 14 14 15 15 15 16 16 17 17
    18 19 19 20 20 21 21 22 23 23 24 24 25 26 27 27
    28 29 29 30 31 32 32 33 34 35 36 36 37 38 39 40
    41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56
    58 59 60 61 62 64 65 66 67 69 70 71 73 74 76 77
    78 80 81 83 84 86 87 89 90 92 94 95 97 99 100 102
    104 106 107 109 111 113 115 117 118 120 122 124 126 128 130 132
    134 137 139 141 143 145 147 150 152 154 156 159 161 163 166 168
    171 173 175 178 180 183 186 188 191 193 196 199 201 204 207 210
    212 215 218 221 224 227 230 233 236 239 242 245 248 251 254 257
    260 263 267 270 273 276 280 283 286 290 293 297 300 304 307 311
    314 318 321 325 328 332 336 339 343 347 351 354 358 362 366 370
    374 378 381 385 389 393 397 401 405 410 414 418 422 426 430 434
    439 443 447 451 456 460 464 469 473 477 482 486 491 495 499 504
    508 513 517 522 527 531 536 540 545 550 554 559 563 568 573 577
    582 587 592 596 601 606 611 615 620 625 630 635 640 644 649 654
    659 664 669 674 678 683 688 693 698 703 708 713 718 723 728 732
    737 742 747 752 757 762 767 772 777 782 787 792 797 802 806 811
    816 821 826 831 836 841 846 851 855 860 865 870 875 880 884 889
    894 899 904 908 913 918 923 927 932 937 941 946 951 955 960 965
    969 974 978 983 988 992 997 1001 1005 1010 1014 1019 1023 1027 1032 1036
    1040 1045 1049 1053 1057 1061 1066 1070 1074 1078 1082 1086 1090 1094 1098 1102
    1106 1109 1113 1117 1121 1125 1128 1132 1136 1139 1143 1146 1150 1153 1157 1160
    1164 1167 1170 1174 1177 1180 1183 1186 1190 1193 1196 1199 1202 1205 1207 1210
    1213 1216 1219 1221 1224 1227 1229 1232 1234 1237 1239 1241 1244 1246 1248 1251
    1253 1255 1257 1259 1261 1263 1265 1267 1269 1270 1272 1274 1275 1277 1279 1280
    1282 1283 1284 1286 1287 1288 1290 1291 1292 1293 1294 1295 1296 1297 1297 1298
    1299 1300 1300 1301 1302 1302 1303 1303 1303 1304 1304 1304 1304 1304 1305 1305
  ] swap qnth i>f
;

( Ticks between envelope or noise steps, per rate 0..31; rate 0 never. )
table: sdsp-period 31
  f>i [ 1000000000 2048 1536 1280 1024 768 640 512 384 320 256 192 160 128 96
        80 64 48 40 32 24 20 16 12 10 8 6 5 4 3 2 1 ] swap qnth i>f
;

ustruct: SdspState
  ( the zone, copied at note-on; positions are pool indices )
  f64 start
  f64 end
  f64 ls
  f64 le
  f64 loop-on
  f64 oneshot
  f64 gain
  f64 gain0
  f64 key
  f64 vel
  ( playback, in stored samples )
  f64 ph
  f64 rate0      ( stored samples per tick at the note, before bend )
  f64 step       ( the same, through the pitch register )
  f64 bend
  ( the 32 kHz clock and its last two outputs )
  f64 oc
  f64 y0
  f64 y1
  ( envelope: 0..2047; mode 0 attack / 1 decay / 2 sustain / 3 release )
  f64 env
  f64 emode
  f64 ectr
  f64 nctr
  f64 lfsr
  ( driver vibrato: seconds since key-on, and the LFO's phase 0..1 )
  f64 vt
  f64 vph
;

ustruct: SdspParams
  ( keymap - injected by the host )
  f64 pool
  f64 zones
  f64 zone-count
  f64 edits
  ( user-facing )
  f64 tune       ( semitones )
  f64 root       ( MIDI note for zones whose files carry no root )
  f64 loop-mode  ( 0 the file's loop / 1 off )
  f64 ar         ( 0..15 )
  f64 dr         ( 0..7 )
  f64 sl         ( 0..7: sustain at [SL + 1] / 8 )
  f64 sr         ( 0..31, 0 holds )
  f64 rel        ( 0 key-off, 1..31 exponential at that rate )
  f64 noise      ( 0 sample / 1 noise )
  f64 nck        ( noise clock rate 0..31 )
  f64 vel-amt
  f64 level
  f64 vib-depth  ( cents, peak )
  f64 vib-rate   ( Hz )
  f64 vib-delay  ( seconds from key-on )
  ( derived - block-prepare )
  f64 tick-inc   ( ticks per host sample, 32000 / sr )
  f64 ar-p
  f64 ar-step
  f64 dr-p
  f64 sr-p
  f64 rel-p
  f64 nck-p
  f64 vib-inc    ( LFO phase per host sample )
  f64 vib-dt     ( seconds per host sample )
;

( ctx state params -- )
dsp: sdsp-block-prepare | ctx:Ctx state params:SdspParams |
  32000.0 ctx.sr f/ 1.0 fmin -> params.tick-inc
  params.ar 0.0 15.0 fclamp floor | ar |
  sdsp-period  ar 2.0 f* 1.0 f+  f@i -> params.ar-p
  ar 14.5 f>  1024.0 32.0 select -> params.ar-step
  sdsp-period  params.dr 0.0 7.0 fclamp floor 2.0 f* 16.0 f+  f@i -> params.dr-p
  sdsp-period  params.sr 0.0 31.0 fclamp floor  f@i -> params.sr-p
  params.rel 0.5 f<  1.0  sdsp-period params.rel 0.0 31.0 fclamp floor f@i  select -> params.rel-p
  sdsp-period  params.nck 0.0 31.0 fclamp floor  f@i -> params.nck-p
  params.vib-rate ctx.sr f/ -> params.vib-inc
  1.0 ctx.sr f/ -> params.vib-dt
;

( state -- : the pitch register for the current bend. )
dsp: sdsp-pitch | state:SdspState |
  state.bend 0.08333333333333333 f* exp2  state.rate0 f*  4096.0 f*  floor 0.0 16383.0 fclamp  4096.0 f/ -> state.step
;

( ctx state params -- : find the zone and start it from the top: the
  envelope at 0 in attack, as key-on does. )
dsp: sdsp-note-on | ctx:Ctx state:SdspState params:SdspParams |
  params.zones& p@64 | zt |
  ctx.pitch | key |
  zt key ctx.vel 127.0 f* 0.0 0.0 zone-find | k |
  key -> state.key
  ctx.vel -> state.vel
  k 0.0 f>= | hit |
  k 0.0 fmax | k0 |
  k0 19.0 f* | c |
  ( a miss plays an empty zone at pool index 4: guard zeros )
  hit  zt c f@i  4.0  select | start |
  hit  zt c 1.0 f+ f@i  0.0  select | len |
  zt c 2.0 f+ f@i | zsr0 |
  zsr0 0.5 f<  32000.0  zsr0  select | zsr |
  zt c 7.0 f+ f@i | zroot |
  zt c 9.0 f+ f@i | zmode |
  zt c 10.0 f+ f@i | zls |
  zt c 11.0 f+ f@i | zle |
  start -> state.start
  start len f+ -> state.end
  params.edits& p@64 | ed:ZoneEdits |
  zt c 8.0 f+ f@i  ed.level& k0 f@i db>lin  f* -> state.gain
  state.gain -> state.gain0
  ( the file's loop, unless LOOP is off or the zone is a one-shot )
  zmode 0.5 f>  zmode 1.5 f< and  zle zls f> and  params.loop-mode 0.5 f< and | lon |
  lon mask>f -> state.loop-on
  zmode 1.5 f> mask>f -> state.oneshot
  zls start f+ -> state.ls
  zle start f+ -> state.le
  zroot 0.0  params.root zroot fsel-lt | root |
  key params.tune f+  ed.tune& k0 f@i f+  root f- 0.08333333333333333 f* exp2 | ratio |
  zsr 32000.0 f/ ratio f* -> state.rate0
  0.0 -> state.bend
  state sdsp-pitch
  0.0 -> state.vt
  0.0 -> state.vph
  start -> state.ph
  0.0 -> state.oc
  0.0 -> state.y0
  0.0 -> state.y1
  0.0 -> state.env
  0.0 -> state.emode
  0.0 -> state.ectr
  0.0 -> state.nctr
  ( the LFSR resets to 0x4000, as the DSP does )
  16384.0 -> state.lfsr
  ( the panel's hit lights )
  ed.hit& k0 f@i 1.0 f+ | nh |
  hit  nh  ed.hit& k0 f@i  select  ed.hit& k0 f!i
  hit  k0  ed.last  select -> ed.last
;

( ctx state params -- : key-off: release from wherever the envelope is.
  One-shot zones [drums] play to their end. )
dsp: sdsp-note-off | ctx state:SdspState params |
  state.oneshot 0.5 f>  state.emode  3.0  select -> state.emode
;

( ctx state params -- : per-note expression: bend through the pitch
  register, gain on the zone's level. )
dsp: sdsp-note-expr | ctx:Ctx state:SdspState params |
  state.gain0 ctx.gain f* -> state.gain
  ctx.pitch state.key f- -> state.bend
  state sdsp-pitch
;

( state params tk -- : one envelope step when the 32 kHz clock ticks. )
dsp: sdsp-env | state:SdspState params:SdspParams tk |
  state.env | e |
  state.emode | m |
  ( the exponential step that decay, sustain and the slow release share )
  e 1.0 f-  e 1.0 f- 256.0 f/ floor  f- | ex |
  e params.ar-step f+ | ea |
  e 8.0 f- | ek |
  params.rel 0.5  ek ex  fsel-lt | er |
  m 0.5  ea  m 1.5 ex  m 2.5 ex er  fsel-lt fsel-lt  fsel-lt | en |
  m 0.5  params.ar-p  m 1.5 params.dr-p  m 2.5 params.sr-p params.rel-p  fsel-lt fsel-lt  fsel-lt | per |
  state.ectr 1.0 f+ | c |
  c per f>=  tk and | fire |
  fire  0.0  tk c state.ectr select  select -> state.ectr
  fire  en 0.0 2047.0 fclamp  e  select | e2 |
  e2 -> state.env
  ( attack overflows into decay; decay settles into sustain at SL )
  m 0.5 f<  fire and  en 2047.0 f> and | to-d |
  m 0.5 f>=  m 1.5 f< and  e2 256.0 f/ floor params.sl f<= and  tk and | to-s |
  to-d  1.0  to-s 2.0 m select  select -> state.emode
;

( state params tk -- y : the noise source as a signed 16-bit sample,
  stepping its LFSR at NOISE CLOCK. )
dsp: sdsp-noise | state:SdspState params:SdspParams tk -- y |
  state.nctr 1.0 f+ | nc |
  nc params.nck-p f>=  tk and | nf |
  nf  0.0  tk nc state.nctr select  select -> state.nctr
  state.lfsr | n |
  n 0.5 f* floor | h |
  n h 2.0 f* f- | b0 |
  h  h 0.5 f* floor 2.0 f* f- | b1 |
  h  b0 b1 f- fabs 16384.0 f* f+ | n2 |
  nf n2 n select | n3 |
  n3 -> state.lfsr
  ( the DSP plays it as noise * 2 in 16 bits )
  n3 2.0 f* | v |
  v 32768.0  v  v 65536.0 f-  fsel-lt  32768.0 f/
;

( state buf -- y : Gaussian interpolation at the read position. )
dsp: sdsp-gauss-read | state:SdspState buf -- y |
  state.ph | ph |
  ph floor | i |
  ph i f- 256.0 f* floor | off |
  buf i 1.0 f- f@i  sdsp-gauss 255.0 off f- f@i f*
  buf i f@i         sdsp-gauss 511.0 off f- f@i f*  f+
  buf i 1.0 f+ f@i  sdsp-gauss 256.0 off f+ f@i f*  f+
  buf i 2.0 f+ f@i  sdsp-gauss off f@i f*  f+
  2048.0 f/
;

( io ctx state params -- : one voice, one host sample. )
dsp: k-sdsp-voice | out:Io ctx state:SdspState params:SdspParams -- |
  params.pool& p@64 | buf |
  state.oc params.tick-inc f+ | oc |
  oc 1.0 f>= | tk |
  tk  oc 1.0 f-  oc  select -> state.oc
  state params tk sdsp-env
  state params tk sdsp-noise | nz |
  state buf sdsp-gauss-read | g |
  params.noise 0.5 f>  nz  g  select | s |
  s state.env f* 2048.0 f/ | y |
  ( driver vibrato: a triangle LFO, as the drivers stepped the pitch
    register up and down, after DELAY with a 0.25 s fade-in; through the
    register like any pitch, so it stays 14-bit )
  state.vt params.vib-dt f+ | vt |
  vt -> state.vt
  state.vph params.vib-inc f+ ffrac | vph |
  vph -> state.vph
  vph 0.5 f- fabs 4.0 f* 1.0 f- | tri |
  vt params.vib-delay f- 4.0 f* 0.0 1.0 fclamp | fade |
  params.vib-depth 0.01 f* tri f* fade f* | vb |
  state.bend vb f+ 0.08333333333333333 f* exp2  state.rate0 f*  4096.0 f*  floor 0.0 16383.0 fclamp  4096.0 f/ | step |
  ( advance one tick: wrap inside the loop; past the end of an unlooped
    sample the voice goes silent, as the BRR end flag does )
  state.ph | ph |
  ph step f+ | p2 |
  state.loop-on 0.5 f>  p2 state.le f>= and | wrap |
  wrap  p2 state.le state.ls f- f-  p2  select  state.end fmin | p3 |
  tk p3 ph select -> state.ph
  p3 state.end f>=  state.loop-on 0.5 f< and  tk and | ended |
  ended  0.0  state.env  select -> state.env
  ended  3.0  state.emode  select -> state.emode
  tk  state.y1  state.y0  select -> state.y0
  tk  y  state.y1  select -> state.y1
  ( onto the host grid: the tick just past, toward the newest )
  state.y0  state.y1 state.y0 f-  state.oc f*  f+ | o |
  1.0 params.vel-amt f-  state.vel params.vel-amt f*  f+ | va |
  out f@64
  o state.gain f* va f* params.level f*
  f+ out f!64
;
