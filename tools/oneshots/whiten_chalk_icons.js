#!/usr/bin/env node
// =============================================================================
// whiten_chalk_icons.js - force the loadout HUD chalk outlines to solid WHITE.
//
// WHY (user 2026-07-05): the Aetherium loadout shows a per-gun wall-chalk outline
// (Mappings/AetheriumWeapons.lua -> AetheriumLoadout.lua). A colour audit of every
// chalk source image found 4 whose outline art is a mid-GREY sketch (avg ~166), not
// white - Tac-19, Five-Seven (B23R lookalike), MK14 (M14), Klauser (Kard). On the
// blue Aetherium panel a grey outline reads as dim/"dark blue" and is hard to see.
//
// WHAT IT DOES: rewrites each of those 4 chalk source images so every pixel is white
// (255,255,255) while KEEPING the original ALPHA channel (the outline SHAPE). The
// image asset name / GDT entry / zone line are unchanged, so the linker just re-
// converts the now-white source on the next build. Originals are backed up once to
// <file>.acc-graychalk-orig; re-running always recolours FROM that backup (idempotent).
//
// These baseImages live install-side (model_export, external packs - not in git), so
// this script is the repo-tracked, re-runnable record of the change (re-run after a
// pack reinstall). Handles uncompressed + LZW TIFF input; writes uncompressed RGBA.
//
// USAGE:  node tools/whiten_chalk_icons.js         (recolour)
//         node tools/whiten_chalk_icons.js --revert (restore the .acc-graychalk-orig backups)
// =============================================================================
const fs = require("fs"), path = require("path");
const TOOLS = process.env.TA_TOOLS_PATH || "C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130";
const REVERT = process.argv.includes("--revert");

// the 4 grey chalk source images (resolved from each gun's GDT image.gdf baseImage)
const TARGETS = [
  "model_export/skye_ports/s1_tac19/images/uts_19_wall_chalk.tiff",              // Tac-19
  "model_export/skye_ports/t6_b23r/images/mtl_t6_wpn_pistol_b2023r_wall_chalk.tiff", // Five-Seven (B23R)
  "model_export/skye_ports/t6_m14/images/mtl_t6_wpn_ar_m14_wall_chalk.tiff",     // MK14 (M14)
  "model_export/skye_ports/t6_kap40/images/mtl_t6_wpn_pistol_kard_wall_chalk.tiff", // Klauser (Kard)
];

// ---- TIFF read (uncompressed + LZW, 8-bit chunky) -> {W,H,px RGBA} ----
function readTiff(buf) {
  const le = buf.toString("ascii", 0, 2) === "II";
  const u16 = o => le ? buf.readUInt16LE(o) : buf.readUInt16BE(o);
  const u32 = o => le ? buf.readUInt32LE(o) : buf.readUInt32BE(o);
  const ifd = u32(4), nE = u16(ifd), tags = {}, tsz = { 1: 1, 3: 2, 4: 4 };
  for (let i = 0; i < nE; i++) { const e = ifd + 2 + i * 12, tag = u16(e), type = u16(e + 2), count = u32(e + 4);
    const ts = tsz[type] || 1, total = ts * count, base = total <= 4 ? e + 8 : u32(e + 8), vals = [];
    for (let k = 0; k < count; k++) vals.push(type === 3 ? u16(base + k * 2) : type === 4 ? u32(base + k * 4) : buf[base + k]);
    tags[tag] = vals; }
  const W = tags[256][0], H = tags[257][0], spp = (tags[277] || [3])[0], comp = (tags[259] || [1])[0], planar = (tags[284] || [1])[0];
  const so = tags[273], sc = tags[279], rps = (tags[278] || [H])[0], predictor = (tags[317] || [1])[0];
  if (planar !== 1 || (comp !== 1 && comp !== 5)) throw new Error("unsupported TIFF (comp=" + comp + " planar=" + planar + ")");
  function lzw(data) { const out = []; let acc = 0, nb = 0, p = 0; const CLEAR = 256, EOI = 257; let dict, ds, cw, prev;
    const reset = () => { dict = []; for (let i = 0; i < 256; i++) dict[i] = [i]; ds = 258; cw = 9; prev = null; }; reset();
    const rd = () => { while (nb < cw) { if (p >= data.length) return EOI; acc = (acc << 8) | data[p++]; nb += 8; } nb -= cw; return (acc >> nb) & ((1 << cw) - 1); };
    let code; while ((code = rd()) !== EOI) { if (code === CLEAR) { reset(); code = rd(); if (code === EOI) break; for (const b of dict[code]) out.push(b); prev = code; continue; }
      let entry = dict[code] ? dict[code] : dict[prev].concat(dict[prev][0]); for (const b of entry) out.push(b);
      if (prev !== null) dict[ds++] = dict[prev].concat(entry[0]); prev = code; if (ds + 1 >= (1 << cw) && cw < 12) cw++; } return Buffer.from(out); }
  const spb = spp * W, px = Buffer.alloc(W * H * 4); let row = 0;
  for (let s = 0; s < so.length; s++) { const rows = Math.min(rps, H - row);
    let strip = comp === 1 ? buf.slice(so[s], so[s] + (sc ? sc[s] : rows * spb)) : lzw(buf.slice(so[s], so[s] + sc[s]));
    let sp = 0;
    for (let r = 0; r < rows; r++) { if (predictor === 2) for (let x = 1; x < W; x++) for (let c = 0; c < spp; c++) strip[sp + x * spp + c] = (strip[sp + x * spp + c] + strip[sp + (x - 1) * spp + c]) & 255;
      for (let x = 0; x < W; x++) { const o = sp + x * spp, di = ((row + r) * W + x) * 4; px[di] = strip[o]; px[di + 1] = strip[o + 1]; px[di + 2] = strip[o + 2]; px[di + 3] = spp >= 4 ? strip[o + 3] : 255; } sp += spb; }
    row += rows; }
  return { W, H, px };
}

// ---- write uncompressed RGBA TIFF (straight/unassociated alpha) ----
function writeTiff(W, H, px) {
  const dataLen = W * H * 4, ifdOff = 8 + dataLen;
  const tags = [ [256,3,1,W],[257,3,1,H],[258,3,4,0],[259,3,1,1],[262,3,1,2],[273,4,1,8],[277,3,1,4],[278,3,1,H],[279,4,1,dataLen],[284,3,1,1],[338,3,1,2] ];
  const ifdSize = 2 + tags.length * 12 + 4, bpsOff = ifdOff + ifdSize;
  const buf = Buffer.alloc(bpsOff + 8);
  buf.write("II", 0, "ascii"); buf.writeUInt16LE(42, 2); buf.writeUInt32LE(ifdOff, 4);
  px.copy(buf, 8);
  buf.writeUInt16LE(tags.length, ifdOff);
  tags.forEach((t, i) => { const e = ifdOff + 2 + i * 12; buf.writeUInt16LE(t[0], e); buf.writeUInt16LE(t[1], e + 2); buf.writeUInt32LE(t[2], e + 4);
    if (t[0] === 258) buf.writeUInt32LE(bpsOff, e + 8);            // BitsPerSample -> offset to 4 shorts
    else if (t[1] === 3) buf.writeUInt16LE(t[3], e + 8);           // inline SHORT
    else buf.writeUInt32LE(t[3], e + 8); });                       // inline LONG
  buf.writeUInt32LE(0, ifdOff + 2 + tags.length * 12);             // next IFD = 0
  for (let k = 0; k < 4; k++) buf.writeUInt16LE(8, bpsOff + k * 2); // BitsPerSample = 8,8,8,8
  return buf;
}

let done = 0;
for (const rel of TARGETS) {
  const full = path.join(TOOLS, rel), bak = full + ".acc-graychalk-orig";
  if (!fs.existsSync(full) && !fs.existsSync(bak)) { console.log("SKIP (missing): " + rel); continue; }
  if (REVERT) { if (fs.existsSync(bak)) { fs.copyFileSync(bak, full); console.log("reverted " + path.basename(full)); done++; } continue; }
  if (!fs.existsSync(bak)) fs.copyFileSync(full, bak);            // back up original once
  const { W, H, px } = readTiff(fs.readFileSync(bak));            // always recolour FROM the pristine backup (idempotent)
  let opaque = 0; for (let i = 0; i < W * H; i++) { if (px[i * 4 + 3] > 8) { px[i * 4] = 255; px[i * 4 + 1] = 255; px[i * 4 + 2] = 255; opaque++; } }
  fs.writeFileSync(full, writeTiff(W, H, px));
  console.log(`whitened ${path.basename(full)}  (${W}x${H}, ${opaque} outline px -> 255,255,255, alpha kept)`);
  done++;
}
console.log(REVERT ? `\nreverted ${done} file(s).` : `\nwhitened ${done} file(s). Rebuild (.\\tools\\build_map.ps1 -GscOnly) to re-pack.`);
