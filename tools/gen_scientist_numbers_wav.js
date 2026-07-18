#!/usr/bin/env node
// gen_scientist_numbers_wav.js - synthesizes the Scientist's constant "numbers" proximity
// hum (docs/44; user 2026-07-17 wanted a numbers sfx but no wav could be sourced - so we
// GENERATE one: a numbers-station-style loop of eerie digital tone-blips over a static bed
// with a low menace hum). 48kHz / 16-bit PCM / MONO / exactly 4.000s, engineered seamless:
//   - blip schedule never crosses the loop seam (no blip after 3.82s)
//   - the hum + its tremolo LFO use whole cycles over 4s (208 + 2 exactly)
//   - the noise bed crossfades its last 80ms into its first 80ms
// Output: sound_assets/acc/fx/scientist_numbers_lp.wav (repo home; copy install-side + alias
// row acc_scientist_numbers_lp in acc_audio.csv). Regenerate any time - deterministic PRNG.
const fs = require('fs');
const path = require('path');

const SR = 48000, SECONDS = 4.0, N = Math.round(SR * SECONDS);

// --- tunables ---------------------------------------------------------------
const NOISE_GAIN = 0.055;   // static bed level
const NOISE_LP   = 0.12;    // one-pole lowpass coefficient (smaller = darker hiss)
const HUM_FREQ   = 52.0;    // menace hum (52 * 4s = 208 whole cycles -> seamless)
const HUM_GAIN   = 0.05;
const HUM_LFO_HZ = 0.5;     // tremolo (2 whole cycles over the loop)
const BLIP_FREQS = [620, 740, 880, 990, 1180, 1320];   // "data" tone set
const BLIP_GAIN  = 0.21;
const BLIP_RATE_MS  = [105, 150];   // gap between blips (min,max)
const BLIP_DUR_MS   = [55, 95];
const DOUBLE_CHANCE = 0.22;         // quick echo blip
const SEAM_GUARD_S  = 0.18;         // no blip starts after SECONDS - this
const XFADE_S       = 0.08;         // noise-bed loop crossfade

// Deterministic PRNG (mulberry32) - same wav every run, no Date/random drift.
let seed = 0x5c1e4715;
function rng() {
  seed |= 0; seed = ( seed + 0x6d2b79f5 ) | 0;
  let t = Math.imul( seed ^ ( seed >>> 15 ), 1 | seed );
  t = ( t + Math.imul( t ^ ( t >>> 7 ), 61 | t ) ) ^ t;
  return ( ( t ^ ( t >>> 14 ) ) >>> 0 ) / 4294967296;
}
const pick = (arr) => arr[Math.floor(rng() * arr.length)];
const range = (lo, hi) => lo + rng() * (hi - lo);

const buf = new Float64Array(N);

// 1) static bed (lowpassed noise), crossfaded at the seam
const noise = new Float64Array(N);
let lp = 0;
for (let i = 0; i < N; i++) { lp += NOISE_LP * ((rng() * 2 - 1) - lp); noise[i] = lp; }
const xf = Math.round(XFADE_S * SR);
for (let i = 0; i < xf; i++) {
  const a = i / xf;
  noise[N - xf + i] = noise[N - xf + i] * (1 - a) + noise[i] * a;
}
for (let i = 0; i < N; i++) buf[i] += noise[i] * NOISE_GAIN;

// 2) menace hum with slow tremolo (whole cycles -> loop-safe)
for (let i = 0; i < N; i++) {
  const t = i / SR;
  const trem = 0.7 + 0.3 * Math.sin(2 * Math.PI * HUM_LFO_HZ * t);
  buf[i] += Math.sin(2 * Math.PI * HUM_FREQ * t) * HUM_GAIN * trem;
}

// 3) the numbers: semi-random tone blips with a light FM wobble + exp decay
function blip(startS, freq, durS, gain) {
  const s0 = Math.round(startS * SR), n = Math.round(durS * SR);
  for (let i = 0; i < n && s0 + i < N; i++) {
    const t = i / SR;
    const env = Math.min(1, t / 0.005) * Math.exp(-t * 9);
    const f = freq + 6 * Math.sin(2 * Math.PI * 7 * t);
    buf[s0 + i] += Math.sin(2 * Math.PI * f * t) * gain * env;
  }
}
let cursor = 0.02;
while (cursor < SECONDS - SEAM_GUARD_S) {
  const f = pick(BLIP_FREQS);
  const d = range(BLIP_DUR_MS[0], BLIP_DUR_MS[1]) / 1000;
  blip(cursor, f, d, BLIP_GAIN);
  if (rng() < DOUBLE_CHANCE) blip(cursor + 0.09, f * 1.19, d * 0.7, BLIP_GAIN * 0.6);
  cursor += range(BLIP_RATE_MS[0], BLIP_RATE_MS[1]) / 1000;
}

// 4) soft clip + PCM16
const pcm = Buffer.alloc(N * 2);
for (let i = 0; i < N; i++) {
  const v = Math.tanh(buf[i] * 1.4);
  pcm.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(v * 32767))), i * 2);
}

// RIFF/WAVE header (PCM, mono, 48k, 16-bit)
const hdr = Buffer.alloc(44);
hdr.write('RIFF', 0); hdr.writeUInt32LE(36 + pcm.length, 4); hdr.write('WAVE', 8);
hdr.write('fmt ', 12); hdr.writeUInt32LE(16, 16); hdr.writeUInt16LE(1, 20);
hdr.writeUInt16LE(1, 22); hdr.writeUInt32LE(SR, 24); hdr.writeUInt32LE(SR * 2, 28);
hdr.writeUInt16LE(2, 32); hdr.writeUInt16LE(16, 34);
hdr.write('data', 36); hdr.writeUInt32LE(pcm.length, 40);

const out = path.join(__dirname, '..', 'sound_assets', 'acc', 'fx', 'scientist_numbers_lp.wav');
fs.writeFileSync(out, Buffer.concat([hdr, pcm]));
console.log(`wrote ${out} (${((44 + pcm.length) / 1024).toFixed(1)} KB, ${SECONDS}s seamless loop @ 48k/16-bit mono)`);
