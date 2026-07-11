// Minimal uncompressed-TIFF -> PNG converter (little-endian, 8-bit, chunky RGB/RGBA).
// Also prints color stats (alpha? background color? outline color?). Downsamples to ~220px wide.
const fs = require("fs");
const zlib = require("zlib");

const inPath = process.argv[2];
const outPath = process.argv[3];
if (!inPath || !outPath) { console.error("usage: node tiff2png.js <in.tiff> <out.png>"); process.exit(2); }

const buf = fs.readFileSync(inPath);
const le = buf.toString("ascii", 0, 2) === "II";
const u16 = (o) => le ? buf.readUInt16LE(o) : buf.readUInt16BE(o);
const u32 = (o) => le ? buf.readUInt32LE(o) : buf.readUInt32BE(o);

const ifd = u32(4);
const nEntries = u16(ifd);
const tags = {};
const typeSize = { 1: 1, 3: 2, 4: 4 };
for (let i = 0; i < nEntries; i++) {
  const e = ifd + 2 + i * 12;
  const tag = u16(e), type = u16(e + 2), count = u32(e + 4);
  const ts = typeSize[type] || 1;
  const total = ts * count;
  const readAt = (off, k) => type === 3 ? u16(off + k * 2) : type === 4 ? u32(off + k * 4) : buf[off + k];
  let vals = [];
  const base = total <= 4 ? e + 8 : u32(e + 8);
  for (let k = 0; k < count; k++) vals.push(readAt(base, k));
  tags[tag] = vals;
}
const W = tags[256][0], H = tags[257][0];
const bps = tags[258] || [8];
const compression = (tags[259] || [1])[0];
const photometric = (tags[262] || [2])[0];
const spp = (tags[277] || [bps.length])[0];
const stripOffsets = tags[273];
const stripCounts = tags[279];
const rowsPerStrip = (tags[278] || [H])[0];
const planar = (tags[284] || [1])[0];
const extraSamples = tags[338] || [];

console.log(`  dims=${W}x${H} spp=${spp} bps=${bps.join(",")} compression=${compression} photometric=${photometric} planar=${planar} extraSamples=[${extraSamples.join(",")}] strips=${stripOffsets.length}`);
if (compression !== 1) { console.log("  !! COMPRESSED - this minimal reader only does uncompressed"); process.exit(3); }
if (planar !== 1) { console.log("  !! planar config != chunky - unsupported"); process.exit(3); }

// assemble raw pixels into an RGBA buffer
const px = Buffer.alloc(W * H * 4);
let outRow = 0;
for (let s = 0; s < stripOffsets.length; s++) {
  let off = stripOffsets[s];
  const rows = Math.min(rowsPerStrip, H - outRow);
  for (let r = 0; r < rows; r++) {
    for (let x = 0; x < W; x++) {
      const R = buf[off++], G = buf[off++], B = buf[off++];
      let A = 255;
      if (spp >= 4) A = buf[off++];
      const di = ((outRow + r) * W + x) * 4;
      px[di] = R; px[di + 1] = G; px[di + 2] = B; px[di + 3] = A;
    }
  }
  outRow += rows;
}

// stats: corners (bg), and the brightest non-bg pixels (outline)
const corner = (x, y) => { const i = (y * W + x) * 4; return [px[i], px[i+1], px[i+2], px[i+3]]; };
const corners = [corner(2,2), corner(W-3,2), corner(2,H-3), corner(W-3,H-3)];
let sr=0,sg=0,sb=0, maxLum=-1, maxCol=[0,0,0], hasAlphaVariation=false, a0=px[3];
const step = Math.max(1, Math.floor((W*H)/40000));
let n=0;
for (let i=0;i<W*H;i++){ if(i%step)continue; const o=i*4; sr+=px[o];sg+=px[o+1];sb+=px[o+2]; const lum=px[o]*0.3+px[o+1]*0.59+px[o+2]*0.11; if(lum>maxLum){maxLum=lum;maxCol=[px[o],px[o+1],px[o+2]];} if(px[o+3]!==a0)hasAlphaVariation=true; n++; }
console.log(`  corners(bg)=${corners.map(c=>`(${c[0]},${c[1]},${c[2]},a${c[3]})`).join(" ")}`);
console.log(`  avgRGB=(${Math.round(sr/n)},${Math.round(sg/n)},${Math.round(sb/n)}) brightestPixel=(${maxCol.join(",")}) alphaVaries=${hasAlphaVariation}`);

// downsample (nearest) to ~220 wide and write PNG (RGB, on a mid-gray so we can see white AND dark art)
const OW = 220, OH = Math.max(1, Math.round(H * OW / W));
const rows = [];
for (let y=0;y<OH;y++){
  const line = Buffer.alloc(1 + OW*3); line[0]=0;
  const sy = Math.min(H-1, Math.floor(y*H/OH));
  for (let x=0;x<OW;x++){
    const sx = Math.min(W-1, Math.floor(x*W/OW));
    const o=(sy*W+sx)*4; const a=px[o+3]/255;
    // composite over mid-gray 128 so both white and dark outlines are visible
    line[1+x*3]   = Math.round(px[o]*a + 128*(1-a));
    line[1+x*3+1] = Math.round(px[o+1]*a + 128*(1-a));
    line[1+x*3+2] = Math.round(px[o+2]*a + 128*(1-a));
  }
  rows.push(line);
}
function chunk(type, data){ const len=Buffer.alloc(4); len.writeUInt32BE(data.length); const t=Buffer.from(type,"ascii"); const crc=Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([t,data]))>>>0); return Buffer.concat([len,t,data,crc]); }
function crc32(b){ let c=~0; for(let i=0;i<b.length;i++){ c^=b[i]; for(let k=0;k<8;k++) c = (c>>>1) ^ (0xEDB88320 & -(c&1)); } return ~c; }
const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(OW,0); ihdr.writeUInt32BE(OH,4); ihdr[8]=8; ihdr[9]=2; // RGB
const idat = zlib.deflateSync(Buffer.concat(rows));
const png = Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk("IHDR",ihdr), chunk("IDAT",idat), chunk("IEND",Buffer.alloc(0))]);
fs.writeFileSync(outPath, png);
console.log(`  wrote ${outPath} (${OW}x${OH})`);
