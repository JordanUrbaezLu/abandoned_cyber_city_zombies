// resample48k.js <in.wav> <out.wav> - PCM16 WAV any-rate -> 48kHz/16-bit (same channel count).
// Catmull-Rom (4-tap cubic) interpolation - no ffmpeg on this box (BO3 custom sounds must be 48k/16-bit).
const fs = require('fs');

const [, , inPath, outPath] = process.argv;
if (!inPath || !outPath) { console.error('usage: node resample48k.js in.wav out.wav'); process.exit(1); }

const buf = fs.readFileSync(inPath);
if (buf.toString('ascii', 0, 4) !== 'RIFF' || buf.toString('ascii', 8, 12) !== 'WAVE') throw new Error('not a RIFF/WAVE file');

// Walk chunks for fmt + data (files often carry LIST/INFO chunks between them).
let pos = 12, fmt = null, dataOff = -1, dataLen = 0;
while (pos + 8 <= buf.length) {
  const id = buf.toString('ascii', pos, pos + 4);
  const size = buf.readUInt32LE(pos + 4);
  if (id === 'fmt ') {
    fmt = {
      tag: buf.readUInt16LE(pos + 8),
      channels: buf.readUInt16LE(pos + 10),
      rate: buf.readUInt32LE(pos + 12),
      bits: buf.readUInt16LE(pos + 22),
    };
  } else if (id === 'data') { dataOff = pos + 8; dataLen = size; }
  pos += 8 + size + (size % 2); // chunks are word-aligned
}
if (!fmt || dataOff < 0) throw new Error('fmt/data chunk not found');
if (fmt.tag !== 1 || fmt.bits !== 16) throw new Error(`need PCM16 input (tag=${fmt.tag} bits=${fmt.bits})`);

const OUT_RATE = 48000;
const ch = fmt.channels;
const inFrames = Math.floor(dataLen / (2 * ch));
const ratio = fmt.rate / OUT_RATE;
const outFrames = Math.floor(inFrames * OUT_RATE / fmt.rate);
console.log(`${inPath}: ${fmt.rate}Hz ${ch}ch ${inFrames} frames -> ${OUT_RATE}Hz ${outFrames} frames`);

const samp = (f, c) => {
  if (f < 0) f = 0;
  if (f >= inFrames) f = inFrames - 1;
  return buf.readInt16LE(dataOff + (f * ch + c) * 2);
};

const out = Buffer.alloc(outFrames * ch * 2);
for (let i = 0; i < outFrames; i++) {
  const x = i * ratio;
  const i1 = Math.floor(x);
  const t = x - i1;
  for (let c = 0; c < ch; c++) {
    const p0 = samp(i1 - 1, c), p1 = samp(i1, c), p2 = samp(i1 + 1, c), p3 = samp(i1 + 2, c);
    // Catmull-Rom
    let v = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t);
    if (v > 32767) v = 32767; else if (v < -32768) v = -32768;
    out.writeInt16LE(Math.round(v), (i * ch + c) * 2);
  }
}

// Plain 44-byte-header PCM16 WAV out.
const hdr = Buffer.alloc(44);
hdr.write('RIFF', 0, 'ascii'); hdr.writeUInt32LE(36 + out.length, 4); hdr.write('WAVE', 8, 'ascii');
hdr.write('fmt ', 12, 'ascii'); hdr.writeUInt32LE(16, 16); hdr.writeUInt16LE(1, 20); hdr.writeUInt16LE(ch, 22);
hdr.writeUInt32LE(OUT_RATE, 24); hdr.writeUInt32LE(OUT_RATE * ch * 2, 28); hdr.writeUInt16LE(ch * 2, 32); hdr.writeUInt16LE(16, 34);
hdr.write('data', 36, 'ascii'); hdr.writeUInt32LE(out.length, 40);
fs.writeFileSync(outPath, Buffer.concat([hdr, out]));
console.log(`wrote ${outPath} (${44 + out.length} bytes)`);
