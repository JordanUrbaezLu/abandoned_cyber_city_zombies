// Decompress a BO3 (T7) usermap fastfile and grep for asset-name strings (packed-or-not oracle).
// Observed layout (hexdump of this build's .ff): "TAff0000" magic; block records from 0x248:
//   [u32 compressedSize][u32 decompressedSize][u32 alignedCompSize][u32 ???] then data
// Data may be raw DEFLATE (no 78xx zlib header). Walk the chain, inflate each block.
const fs = require('fs');
const zlib = require('zlib');

const ff = process.argv[2];
const needles = process.argv.slice(3);
const buf = fs.readFileSync(ff);

function inflateAny(raw) {
  try { return zlib.inflateSync(raw); } catch (e) {}
  try { return zlib.inflateRawSync(raw); } catch (e) {}
  // tolerate trailing garbage
  try { return zlib.inflateSync(raw, { finishFlush: zlib.constants.Z_SYNC_FLUSH }); } catch (e) {}
  try { return zlib.inflateRawSync(raw, { finishFlush: zlib.constants.Z_SYNC_FLUSH }); } catch (e) {}
  return null;
}

// header record looks valid?
function plausible(p) {
  if (p + 16 >= buf.length) return false;
  const cs = buf.readUInt32LE(p), ds = buf.readUInt32LE(p + 4), as = buf.readUInt32LE(p + 8);
  return cs >= 16 && cs <= 0x80000 && ds >= cs / 40 && ds <= 0x100000 && as >= cs && as - cs < 16 && p + 16 + cs <= buf.length;
}

let pos = 0x248, blocks = [], total = 0, fails = 0, resyncs = 0;
while (pos + 16 < buf.length) {
  let ok = false;
  if (plausible(pos)) {
    const csize = buf.readUInt32LE(pos);
    const asize = buf.readUInt32LE(pos + 8);
    const d = inflateAny(buf.slice(pos + 16, pos + 16 + csize));
    if (d) {
      blocks.push(d); total += d.length; ok = true;
      pos += 16 + ((asize >= csize && asize - csize < 16) ? asize : csize);
      pos = (pos + 3) & ~3;
    }
  }
  if (!ok) {
    // resync: scan forward for the next record whose data actually inflates
    fails++;
    let found = -1;
    for (let p = pos + 1; p < Math.min(pos + 0x200000, buf.length - 16); p++) {
      if (!plausible(p)) continue;
      const cs = buf.readUInt32LE(p);
      const d = inflateAny(buf.slice(p + 16, p + 16 + cs));
      if (d && d.length > 64) { found = p; break; }
    }
    if (found < 0) break;
    resyncs++;
    pos = found;
  }
}
console.log(`blocks ok=${blocks.length} fails=${fails} resyncs=${resyncs} -> ${(total / 1048576).toFixed(1)} MB decompressed (stopped at 0x${pos.toString(16)} of ${(buf.length / 1048576).toFixed(1)} MB)`);
const all = Buffer.concat(blocks);
for (const n of needles) {
  let c = 0, idx = 0;
  const nb = Buffer.from(n, 'latin1');
  while ((idx = all.indexOf(nb, idx)) !== -1) { c++; idx += nb.length; }
  console.log(`  ${n} : ${c}`);
}
