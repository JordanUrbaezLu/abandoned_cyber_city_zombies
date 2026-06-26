#!/usr/bin/env node
// =============================================================================
// amplify_wav.js <wav> [--target-db -0.5] [--gain-db X] [--loudness-db X] [--restore]
//
// Make a 16-bit PCM WAV louder. Modes:
//   (default)        PEAK-NORMALIZE to --target-db (-0.5 dBFS): scale so the loudest
//                    sample hits the target. Clean, but useless if already near peak.
//   --loudness-db X  LOUDNESS-MAXIMIZE: apply +X dB through a tanh SOFT-CLIP limiter -
//                    raises the AVERAGE level (perceived loudness) while smoothly
//                    saturating peaks instead of hard-clipping. THE lever for music that
//                    is already peaked but sounds quiet. ~+4-6 dB is a normal master boost.
//   --gain-db X      flat gain (hard-clamped; warns clipped samples).
//   --restore        undo: copy <wav>.preamp-orig back over <wav>.
//
// Always works FROM the original: if <wav>.preamp-orig exists it reads THAT (so re-running
// with different dB is idempotent, never double-processed); else it backs the file up first.
// No ffmpeg - walks the RIFF chunks like tools/convert_wav_48k_stereo.ps1. After this, the
// SOUNDBANK must be rebuilt (game-closed) for it to take effect (streamed audio lives in the
// .sabs - memory streamed-music-swap-verify; aliases acc_ee_song/acc_brutus_music/acc_main_theme).
// =============================================================================
'use strict';
const fs = require('fs');

const file = process.argv[2];
if (!file) { console.error('usage: node tools/amplify_wav.js <wav> [--target-db -0.5] [--gain-db X] [--loudness-db X] [--restore]'); process.exit(1); }
const tdArg = process.argv.indexOf('--target-db');
const gdArg = process.argv.indexOf('--gain-db');
const ldArg = process.argv.indexOf('--loudness-db');
const targetDb = tdArg > 0 ? parseFloat(process.argv[tdArg + 1]) : -0.5;
const explicitGainDb = gdArg > 0 ? parseFloat(process.argv[gdArg + 1]) : null;
const loudnessDb = ldArg > 0 ? parseFloat(process.argv[ldArg + 1]) : null;

const bakPath = file + '.preamp-orig';

if (process.argv.includes('--restore')) {
  if (!fs.existsSync(bakPath)) { console.error('no backup to restore: ' + bakPath); process.exit(2); }
  fs.copyFileSync(bakPath, file);
  console.log(`[amplify] restored ${file} from ${bakPath}`);
  process.exit(0);
}

// Read FROM the original (backup) if it exists, so every run is from the true source.
const buf = fs.existsSync(bakPath) ? fs.readFileSync(bakPath) : fs.readFileSync(file);
if (buf.toString('ascii', 0, 4) !== 'RIFF' || buf.toString('ascii', 8, 12) !== 'WAVE') {
  console.error('not a RIFF/WAVE file'); process.exit(2);
}

// Walk sub-chunks to find 'fmt ' + 'data'.
let p = 12, fmt = null, dataOff = -1, dataLen = 0;
while (p + 8 <= buf.length) {
  const id = buf.toString('ascii', p, p + 4);
  const sz = buf.readUInt32LE(p + 4);
  const body = p + 8;
  if (id === 'fmt ') {
    fmt = { audioFormat: buf.readUInt16LE(body), channels: buf.readUInt16LE(body + 2), sampleRate: buf.readUInt32LE(body + 4), bits: buf.readUInt16LE(body + 14) };
  } else if (id === 'data') {
    dataOff = body; dataLen = sz;
  }
  p = body + sz + (sz & 1); // chunks are word-aligned
}
if (!fmt || dataOff < 0) { console.error('no fmt/data chunk'); process.exit(2); }
if (fmt.audioFormat !== 1 || fmt.bits !== 16) { console.error(`only 16-bit PCM supported (got fmt ${fmt.audioFormat}, ${fmt.bits}-bit)`); process.exit(2); }

const end = Math.min(dataOff + dataLen, buf.length - ((buf.length - dataOff) % 2));
const nSamples = Math.floor((end - dataOff) / 2);

// Measure peak.
let peak = 0;
for (let i = 0; i < nSamples; i++) {
  const s = Math.abs(buf.readInt16LE(dataOff + i * 2));
  if (s > peak) peak = s;
}
if (peak === 0) { console.log('[amplify] silent file, nothing to do'); process.exit(0); }
const peakDb = 20 * Math.log10(peak / 32768);

// Back the original up ONCE (buf is always the ORIGINAL: read from the backup if it existed).
if (!fs.existsSync(bakPath)) fs.writeFileSync(bakPath, buf);

let clipped = 0, mode, gainDb;

if (loudnessDb !== null) {
  // LOUDNESS-MAXIMIZE: +X dB through a tanh soft-clip limiter (raises average level, smoothly
  // saturates peaks instead of hard-clipping). out = L * tanh(in*gain/L).
  const gain = Math.pow(10, loudnessDb / 20), L = 32767;
  for (let i = 0; i < nSamples; i++) {
    let v = Math.round(L * Math.tanh((buf.readInt16LE(dataOff + i * 2) * gain) / L));
    if (v > 32767) v = 32767; else if (v < -32768) v = -32768;
    buf.writeInt16LE(v, dataOff + i * 2);
  }
  mode = `loudness +${loudnessDb} dB (tanh soft-clip limiter)`;
  gainDb = loudnessDb;
} else {
  // NORMALIZE (to target peak) or flat --gain-db, both hard-clamped.
  let gain;
  if (explicitGainDb !== null) gain = Math.pow(10, explicitGainDb / 20);
  else { gain = (32768 * Math.pow(10, targetDb / 20)) / peak; }
  gainDb = 20 * Math.log10(gain);
  if (gain <= 1.0001 && explicitGainDb === null) {
    console.log(`[amplify] ${file}\n  peak already ${peakDb.toFixed(1)} dBFS (>= target ${targetDb} dBFS) - already maxed; use --loudness-db X to raise perceived loudness.`);
    process.exit(0);
  }
  for (let i = 0; i < nSamples; i++) {
    let v = Math.round(buf.readInt16LE(dataOff + i * 2) * gain);
    if (v > 32767) { v = 32767; clipped++; } else if (v < -32768) { v = -32768; clipped++; }
    buf.writeInt16LE(v, dataOff + i * 2);
  }
  mode = explicitGainDb !== null ? `flat gain +${explicitGainDb} dB` : `peak-normalize to ${targetDb} dBFS`;
}

fs.writeFileSync(file, buf);
console.log(`[amplify] ${file}  (${fmt.sampleRate} Hz, ${fmt.channels}ch, 16-bit, ${(dataLen / 1048576).toFixed(1)} MB) - ${mode}`);
console.log(`  source peak ${peakDb.toFixed(1)} dBFS, applied +${gainDb.toFixed(1)} dB${clipped ? `, HARD-clipped ${clipped} samples` : ''}`);
console.log(`  backup: ${bakPath}  (node tools/amplify_wav.js ${file} --restore  to undo)`);
