#!/usr/bin/env node
// prep_scientist_numbers_from_rip.js - turns a ripped BO1 numbers-station wav into the
// Scientist's proximity-hum loop (docs/44). The AUTHENTIC replacement for the synthesized
// placeholder that tools/gen_scientist_numbers_wav.js writes into the repo:
//   in : a PCM wav rip (any rate/channels; the BO1Sounds pack files are stereo 47991Hz)
//   out: 48kHz / 16-bit / MONO, seam-crossfaded (150ms) seamless loop, peak-normalized
// The OUTPUT goes INSTALL-SIDE ONLY (tools-root sound_assets\acc\fx\) - it is unlicensed
// Treyarch audio, so it never enters git (asset-portability rules); the repo keeps the
// synth wav so a fresh clone still builds + sounds. Alias/code need no change - same path.
//
// Usage: node tools/prep_scientist_numbers_from_rip.js <src.wav> <dst.wav> [seconds]
const fs = require('fs');
const [src, dst, secondsArg] = process.argv.slice(2);
if (!src || !dst) {
  console.error('usage: node prep_scientist_numbers_from_rip.js <src.wav> <dst.wav> [seconds]');
  process.exit(1);
}
const OUT_SR = 48000, XFADE_S = 0.15;

// --- parse (chunk walk, PCM16 only) ---
const b = fs.readFileSync(src);
if (b.toString('ascii', 0, 4) !== 'RIFF') throw new Error('not a RIFF wav');
let pos = 12, fmt = null, data = null;
while (pos + 8 <= b.length) {
  const id = b.toString('ascii', pos, pos + 4), sz = b.readUInt32LE(pos + 4);
  if (id === 'fmt ') fmt = { tag: b.readUInt16LE(pos + 8), ch: b.readUInt16LE(pos + 10), rate: b.readUInt32LE(pos + 12), bits: b.readUInt16LE(pos + 22) };
  if (id === 'data') { data = b.subarray(pos + 8, pos + 8 + sz); }
  pos += 8 + sz + (sz % 2);
}
if (!fmt || !data) throw new Error('missing fmt/data chunk');
if (fmt.tag !== 1 || fmt.bits !== 16) throw new Error(`need PCM16, got tag ${fmt.tag} bits ${fmt.bits}`);

// --- stereo -> mono float ---
const frames = Math.floor(data.length / 2 / fmt.ch);
const mono = new Float64Array(frames);
for (let i = 0; i < frames; i++) {
  let acc = 0;
  for (let c = 0; c < fmt.ch; c++) acc += data.readInt16LE((i * fmt.ch + c) * 2);
  mono[i] = acc / fmt.ch / 32768;
}

// --- resample to 48k (linear) ---
const wantS = secondsArg ? parseFloat(secondsArg) : frames / fmt.rate;
const outN = Math.min(Math.round(wantS * OUT_SR), Math.round((frames / fmt.rate) * OUT_SR));
const res = new Float64Array(outN);
const step = fmt.rate / OUT_SR;
for (let i = 0; i < outN; i++) {
  const x = i * step, i0 = Math.floor(x), a = x - i0;
  res[i] = mono[Math.min(i0, frames - 1)] * (1 - a) + mono[Math.min(i0 + 1, frames - 1)] * a;
}

// --- seam crossfade (equal-power) ---
const xf = Math.round(XFADE_S * OUT_SR);
for (let i = 0; i < xf; i++) {
  const a = i / xf;
  res[outN - xf + i] = res[outN - xf + i] * Math.cos(a * Math.PI / 2) + res[i] * Math.sin(a * Math.PI / 2);
}

// --- normalize to -3dB peak + write PCM16 mono 48k ---
let peak = 0;
for (let i = 0; i < outN; i++) peak = Math.max(peak, Math.abs(res[i]));
const gain = peak > 0 ? (0.707 / peak) : 1;
const pcm = Buffer.alloc(outN * 2);
for (let i = 0; i < outN; i++)
  pcm.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(res[i] * gain * 32767))), i * 2);

const hdr = Buffer.alloc(44);
hdr.write('RIFF', 0); hdr.writeUInt32LE(36 + pcm.length, 4); hdr.write('WAVE', 8);
hdr.write('fmt ', 12); hdr.writeUInt32LE(16, 16); hdr.writeUInt16LE(1, 20);
hdr.writeUInt16LE(1, 22); hdr.writeUInt32LE(OUT_SR, 24); hdr.writeUInt32LE(OUT_SR * 2, 28);
hdr.writeUInt16LE(2, 32); hdr.writeUInt16LE(16, 34);
hdr.write('data', 36); hdr.writeUInt32LE(pcm.length, 40);
fs.writeFileSync(dst, Buffer.concat([hdr, pcm]));
console.log(`wrote ${dst}: ${(outN / OUT_SR).toFixed(1)}s mono 48k loop (src ${fmt.ch}ch@${fmt.rate}, peak-normalized -3dB, ${Math.round(XFADE_S * 1000)}ms seam xfade)`);
