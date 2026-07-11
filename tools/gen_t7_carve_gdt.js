#!/usr/bin/env node
// gen_t7_carve_gdt.js - author a minimal GDT for MidgetBlaster "T7 Assets" prop carves.
// Automates the proven carve recipe (memory t7-assets-dump-prop-carving, boss items 2026-07-08):
// decodes each model's LOD0 .xmodel_bin (via tools/xmodel_bin_inspect.js internals), reads the
// material names + their trailing "color:_images\\i_X_c.png" hints IN STREAM ORDER (a hint binds
// to the material that precedes it), skips materials already present in the install's GDTs, and
// emits xmodel + material (+ image, only for PNGs that actually shipped) entries.
//
// Usage:
//   node tools/gen_t7_carve_gdt.js --props <propsRoot> --gdtdir <installSourceData> \
//        --out <out.gdt> [--patterns] <map/model> [<map/model> ...]
//   --patterns : print the 7z -ir!... include args for the _images pass-B extraction and exit.
//
// Recipe rules encoded here (all proven on the 2026-07-08 items carve):
//  - xmodel: 4 LOD slots, missing LODs fall back to the last real one; BulletCollisionLOD High
//    (the ALXS PaP precedent = solid, bullet-collidable machine) - stations need real hitboxes.
//  - material: lit_plus "Geometry Plus" w/ occMap $white_ao + heatmap $gray_32_one_channel;
//    names containing decal/dirty/label/seam/peeling/grunge/stain/screw -> lit_decal "Decal"
//    (missing a decal surfaces as "no techset for surface N").
//  - images: canonical stock names resolve FREE from fastfiles - only define image.gdf entries
//    for PNGs that shipped in the slice. Image base = the color hint minus "_c" (the horseshoe
//    rule: mtl_..._iron_03 -> i_..._set_metal_*); no hint -> i_<mtl-name>. "$builtin.png" hints
//    become bare $builtins with no image entry.
'use strict';
const fs = require('fs');
const path = require('path');

// ---- args ----
const argv = process.argv.slice(2);
function opt(name) { const i = argv.indexOf(name); return i >= 0 ? argv[i + 1] : undefined; }
const propsRoot = opt('--props'), gdtDir = opt('--gdtdir'), outPath = opt('--out');
const patternsOnly = argv.includes('--patterns');
const models = argv.filter((a, i) => !a.startsWith('--') && argv[i - 1] !== '--props' && argv[i - 1] !== '--gdtdir' && argv[i - 1] !== '--out');
if (!propsRoot || models.length === 0 || (!patternsOnly && (!gdtDir || !outPath))) {
    console.error('usage: gen_t7_carve_gdt.js --props <propsRoot> --gdtdir <sourceData> --out <out.gdt> [--patterns] <map/model>...');
    process.exit(1);
}

// ---- .xmodel_bin decode (same layout as tools/xmodel_bin_inspect.js) ----
function lz4BlockDecompress(src, dstSize) {
    const dst = Buffer.alloc(dstSize);
    let si = 0, di = 0;
    while (si < src.length && di < dstSize) {
        const token = src[si++];
        let litLen = token >> 4;
        if (litLen === 15) { let b; do { b = src[si++]; litLen += b; } while (b === 255); }
        src.copy(dst, di, si, si + litLen);
        si += litLen; di += litLen;
        if (si >= src.length || di >= dstSize) break;
        const offset = src.readUInt16LE(si); si += 2;
        let matchLen = token & 15;
        if (matchLen === 15) { let b; do { b = src[si++]; matchLen += b; } while (b === 255); }
        matchLen += 4;
        let mi = di - offset;
        for (let k = 0; k < matchLen; k++) dst[di++] = dst[mi++];
    }
    return dst.slice(0, di);
}
function decode(file) {
    const raw = fs.readFileSync(file);
    const mi = raw.indexOf('*LZ4*');
    if (mi < 0) throw new Error('no *LZ4* magic: ' + file);
    return lz4BlockDecompress(raw.slice(mi + 9), raw.readUInt32LE(mi + 5));
}
function orderedStrings(buf, minLen) {
    const out = [];
    let start = -1;
    for (let i = 0; i <= buf.length; i++) {
        const c = i < buf.length ? buf[i] : 0;
        const printable = c >= 0x20 && c < 0x7f;
        if (printable && start < 0) start = i;
        if (!printable) {
            if (start >= 0 && i - start >= minLen) out.push(buf.toString('ascii', start, i));
            start = -1;
        }
    }
    return out;
}

// ---- existing-asset check: one big haystack of every install GDT ----
// NOTE: stock material GDTs live in <tools>\texture_assets (NOT source_data) - pass BOTH,
// comma-separated, or gdtdb /update dies on duplicate-asset errors (hit live 2026-07-09).
let gdtHaystack = '';
if (!patternsOnly) {
    const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap(e =>
        e.isDirectory() ? walk(path.join(d, e.name)) : (e.name.toLowerCase().endsWith('.gdt') ? [path.join(d, e.name)] : []));
    for (const dir of gdtDir.split(',')) {
        for (const f of walk(dir)) {
            if (path.resolve(f) === path.resolve(outPath)) continue; // ignore a previous run's output
            gdtHaystack += fs.readFileSync(f, 'utf8');
        }
    }
}
const existsInGdt = (name) => gdtHaystack.includes('"' + name + '"');

// ---- per-model scan ----
// Prefixes seen in real bins: mtl_/t7_ (common), sky_/global_ (the cryo pod's LED + misc -
// the "non-mtl_ materials" trap from memory t7-assets-dump-prop-carving, hit again 2026-07-09).
const MTL_RX = /^(mtl_|t7_|sky_|global_)[a-z0-9_]+$/;
const HINT_RX = /^color:_images\\\\(.+)\.png$/;
const DECAL_RX = /decal|dirty|label|seam|peeling|grunge|stain|screw/;
function surfaceType(n) {
    if (/glass/.test(n)) return 'glass';
    if (/wood/.test(n)) return 'wood';
    if (/plastic/.test(n)) return 'plastic';
    if (/rubber/.test(n)) return 'rubber';
    if (/cloth|fabric/.test(n)) return 'cloth';
    return 'metal';
}

const specs = [];
for (const mm of models) {
    const [map, model] = mm.split('/');
    const dir = path.join(propsRoot, map, model);
    const files = fs.readdirSync(dir).filter(f => /_LOD\d+\.xmodel_bin$/i.test(f))
        .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
    if (!files.length) { console.error('no LOD bins in ' + dir); process.exit(2); }
    // Scan EVERY LOD - lower LODs can use materials LOD0 never references (the dragon
    // terminal's console_monitor lives only in LOD1+; missed = "not found in gdtDB").
    const mats = new Map(); // name -> hintBase|null (first hint wins)
    for (const lodFile of files) {
        const buf = decode(path.join(dir, lodFile));
        let last = null;
        for (const s of orderedStrings(buf, 5)) {
            if (MTL_RX.test(s) && s.length >= 8) { if (!mats.has(s)) mats.set(s, null); last = s; continue; }
            const h = s.match(HINT_RX);
            if (h && last && mats.get(last) === null) mats.set(last, h[1]);
        }
    }
    specs.push({ map, model, dir, files, mats });
}

// ---- pass-B pattern mode: emit 7z include args for every image we might ship ----
if (patternsOnly) {
    const pats = new Set();
    for (const s of specs) {
        for (const [m, hint] of s.mats) {
            const base = hint ? hint.replace(/_[cegn]$/, '') : 'i_' + m;
            if (base.startsWith('$')) continue;
            pats.add(`-ir!*\\props\\${s.map}\\_images\\${base}_*`);
            pats.add(`-ir!*\\props\\${s.map}\\_images\\${base}.*`);
        }
    }
    console.log([...pats].join('\n'));
    process.exit(0);
}

// ---- GDT emit ----
const q = (s) => '"' + s + '"';
let out = '{\n';
let nMat = 0, nImg = 0, nSkip = 0;
const seenMat = new Set(), seenImg = new Set();
for (const s of specs) {
    // xmodel entry - 4 slots, pad with the last real LOD; keep the shipped filename casing.
    const rel = (f) => `_midgetblaster\\\\props\\\\${s.map}\\\\${s.model}\\\\${f}`;
    const lods = [0, 1, 2, 3].map(i => s.files[Math.min(i, s.files.length - 1)]);
    out += `\t${q(s.model)} ("xmodel.gdf")\n\t{\n`;
    out += `\t"filename" ${q(rel(lods[0]))}\n`;
    out += `\t"mediumLod" ${q(rel(lods[1]))}\n`;
    out += `\t"lowLod" ${q(rel(lods[2]))}\n`;
    out += `\t"lowestLod" ${q(rel(lods[3]))}\n`;
    out += `\t"BulletCollisionLOD" "High"\n`;
    out += `\t}\n`;

    for (const [m, hint] of s.mats) {
        if (seenMat.has(m)) continue;
        seenMat.add(m);
        if (existsInGdt(m)) { nSkip++; continue; }
        const isDecal = DECAL_RX.test(m);
        const base = hint ? hint.replace(/_[cegn]$/, '') : 'i_' + m;
        const builtin = base.startsWith('$');
        const colorImg = builtin ? base : (hint ? 'i_' + hint.replace(/^i_/, '') : base + '_c');
        // (hint keeps its own suffix - an _e emissive hint stays the colorMap; no-hint = canonical _c)
        const colorName = builtin ? base : (hint || base + '_c').replace(/^(?!i_)/, 'i_').replace(/^i_i_/, 'i_');
        nMat++;
        out += `\t${q(m)} ( "material.gdf" )\n\t{\n`;
        out += `\t\t"surfaceType" ${q(surfaceType(m))}\n`;
        out += `\t\t"template" "material.template"\n`;
        if (isDecal) {
            out += `\t\t"materialCategory" "Decal"\n\t\t"materialType" "lit_decal"\n`;
        } else {
            out += `\t\t"materialCategory" "Geometry Plus"\n\t\t"materialType" "lit_plus"\n`;
            out += `\t\t"occMap" "$white_ao"\n`;
        }
        out += `\t\t"textureAtlasRowCount" "1"\n\t\t"textureAtlasColumnCount" "1"\n`;
        out += `\t\t"usage" "<not in editor>"\n`;
        out += `\t\t"heatmap" "$gray_32_one_channel"\n`;
        if (!isDecal && !builtin) {
            out += `\t\t"normalMap" ${q(base + '_n')}\n`;
            out += `\t\t"cosinePowerMap" ${q(base + '_g')}\n`;
        }
        out += `\t\t"colorMap" ${q(colorName)}\n`;
        out += `\t\t"colorTint" "1.000000 1.000000 1.000000 1.000000"\n`;
        out += `\t\t"normalHeightScale" "1"\n\t\t"glossRangeMin" "0"\n\t\t"glossRangeMax" "13"\n`;
        out += `\t}\n`;
        // image entries - ONLY for PNGs that shipped in this slice's _images
        if (builtin) continue;
        const imgDir = path.join(propsRoot, s.map, '_images');
        const defs = [[colorName, 'diffuseMap', 'compressed high color'], [base + '_n', 'normalMap', 'compressed'], [base + '_g', 'glossMap', 'compressed']];
        for (const [img, sem, comp] of defs) {
            if (seenImg.has(img) || img.startsWith('$')) continue;
            const png = path.join(imgDir, img + '.png');
            if (!fs.existsSync(png)) continue;
            seenImg.add(img);
            nImg++;
            out += `\t${q(img)} ( "image.gdf" )\n\t{\n`;
            out += `\t\t"baseImage" ${q('model_export\\\\_midgetblaster\\\\props\\\\' + s.map + '\\\\_images\\\\' + img + '.png')}\n`;
            out += `\t\t"imageType" "Texture"\n\t\t"type" "image"\n`;
            out += `\t\t"compressionMethod" ${q(comp)}\n\t\t"semantic" ${q(sem)}\n`;
            out += `\t}\n`;
        }
    }
}
out += '}\n';
fs.writeFileSync(outPath, out);
console.log(`[gdt] ${specs.length} xmodels, ${nMat} materials authored (${nSkip} already in gdtDB), ${nImg} shipped images defined -> ${outPath}`);
