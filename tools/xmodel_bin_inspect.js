#!/usr/bin/env node
// xmodel_bin_inspect.js - decode a MidgetBlaster/export2bin .xmodel_bin and report
// (a) embedded strings (material names: mtl_* AND non-mtl decals - both matter, see
//     memory t7-assets-dump-prop-carving) and (b) vertex bounds via token 0x9383
//     (the OFFSET/position token; proven on the 2026-07-08 boss-item carve to measure
//     mesh seats/footprints instead of eyeballing model_z).
// Format: ASCII magic "*LZ4*" + u32le decompressedSize + raw LZ4 block (no frame).
//
// Usage: node tools/xmodel_bin_inspect.js <file.xmodel_bin> [--strings] [--bounds]
//        (no flags = both)

'use strict';
const fs = require('fs');

function lz4BlockDecompress(src, dstSize) {
    const dst = Buffer.alloc(dstSize);
    let si = 0, di = 0;
    while (si < src.length && di < dstSize) {
        const token = src[si++];
        let litLen = token >> 4;
        if (litLen === 15) { let b; do { b = src[si++]; litLen += b; } while (b === 255); }
        src.copy(dst, di, si, si + litLen);
        si += litLen; di += litLen;
        if (si >= src.length || di >= dstSize) break; // block ends with literals
        const offset = src.readUInt16LE(si); si += 2;
        let matchLen = token & 15;
        if (matchLen === 15) { let b; do { b = src[si++]; matchLen += b; } while (b === 255); }
        matchLen += 4;
        let mi = di - offset;
        for (let i = 0; i < matchLen; i++) dst[di++] = dst[mi++];
    }
    return dst.slice(0, di);
}

function decode(file) {
    const raw = fs.readFileSync(file);
    const magicIdx = raw.indexOf('*LZ4*');
    if (magicIdx < 0) throw new Error('no *LZ4* magic in ' + file);
    const dstSize = raw.readUInt32LE(magicIdx + 5);
    return lz4BlockDecompress(raw.slice(magicIdx + 9), dstSize);
}

function extractStrings(buf, minLen) {
    const out = new Set();
    let start = -1;
    for (let i = 0; i <= buf.length; i++) {
        const c = i < buf.length ? buf[i] : 0;
        const printable = c >= 0x20 && c < 0x7f;
        if (printable && start < 0) start = i;
        if (!printable) {
            if (start >= 0 && i - start >= minLen) out.add(buf.toString('ascii', start, i));
            start = -1;
        }
    }
    return [...out];
}

// Vertex positions: 4-aligned u16le token 0x9383 + u16 pad + 3 float32 at +4 (layout
// hex-verified 2026-07-09 on p7_zm_moo_server_comm_01: "83 93 00 00 <f32 f32 f32>").
function bounds(buf) {
    let n = 0;
    const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
    for (let i = 0; i + 16 <= buf.length; i += 4) {
        if (buf[i] !== 0x83 || buf[i + 1] !== 0x93 || buf[i + 2] !== 0 || buf[i + 3] !== 0) continue;
        const v = [buf.readFloatLE(i + 4), buf.readFloatLE(i + 8), buf.readFloatLE(i + 12)];
        if (!v.every(x => Number.isFinite(x) && Math.abs(x) < 20000)) continue;
        n++;
        for (let k = 0; k < 3; k++) { if (v[k] < mn[k]) mn[k] = v[k]; if (v[k] > mx[k]) mx[k] = v[k]; }
    }
    return { pad: 2, n, mn, mx };
}

const args = process.argv.slice(2);
const file = args.find(a => !a.startsWith('--'));
if (!file) { console.error('usage: node xmodel_bin_inspect.js <file.xmodel_bin> [--strings] [--bounds]'); process.exit(1); }
const wantStrings = args.includes('--strings') || !args.some(a => a === '--bounds');
const wantBounds = args.includes('--bounds') || !args.some(a => a === '--strings');

const buf = decode(file);
console.log('# decoded ' + buf.length + ' bytes from ' + file);
if (wantStrings) {
    console.log('## strings (materials etc.)');
    for (const s of extractStrings(buf, 5)) console.log(s);
}
if (wantBounds) {
    const r = bounds(buf);
    console.log('## bounds (token 0x9383, payload pad ' + r.pad + ', ' + r.n + ' verts)');
    if (r.n > 0) {
        const f = (x) => x.toFixed(1);
        console.log('min (' + r.mn.map(f).join(', ') + ')  max (' + r.mx.map(f).join(', ') + ')');
        console.log('size (' + r.mn.map((m, k) => f(r.mx[k] - m)).join(' x ') + ')  floorLift(-minZ) ' + f(-r.mn[2]));
    }
}
