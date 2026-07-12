// build_lui_bytecode.js - compile a HavokScript (T7) Lua chunk to bytecode and
// splice it into an outer LUI source file as a `\ddd` string constant.
//
// WHY (docs/40 "THE WORKING RECIPE"): retail BO3 usermap LUI can use Lua io/os,
// but L3akMod (a) blocks `io`/`os` in rawfile SOURCE and (b) chokes on bytecode
// RAWFILES. The workaround: compile the io/os logic to T7 HKS bytecode with
// tools/hksc, embed those bytes as a string constant inside a NORMAL source .lua
// (which names only whitelist-clean globals), and at runtime undump it via
// `load(reader)` (HKS load is 5.1-strict + bytecode-only, so the reader form is
// required). HavokScript locks the stdlib by default -> the chunk must call
// `EnableGlobals()` before touching io/os.
//
// Usage:
//   node tools/build_lui_bytecode.js <chunk.lua> <outer_template.lua> <outer_out.lua>
//
// The outer template must contain the marker `@@ACC_LUI_BYTECODE@@` exactly once
// (inside a Lua string literal, e.g. `local BC = "@@ACC_LUI_BYTECODE@@"`). It is
// replaced with the compiled chunk's bytes as `\ddd` (3-digit, zero-padded)
// escapes. Everything else in the template is left verbatim.
//
// Exit non-zero on any failure (so build_map.ps1 can gate on it).

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const [chunkSrc, outerTpl, outerOut] = process.argv.slice(2);
if (!chunkSrc || !outerTpl || !outerOut) {
  console.error('usage: node build_lui_bytecode.js <chunk.lua> <outer_template.lua> <outer_out.lua>');
  process.exit(2);
}

const HKSC = path.join(__dirname, 'hksc', 'hksc.exe');
const MARKER = '@@ACC_LUI_BYTECODE@@';

function die(msg) { console.error('[build_lui_bytecode] FAIL: ' + msg); process.exit(1); }

if (!fs.existsSync(HKSC)) die('missing compiler ' + HKSC + ' (see tools/hksc/README.md)');
if (!fs.existsSync(chunkSrc)) die('missing chunk source ' + chunkSrc);
if (!fs.existsSync(outerTpl)) die('missing outer template ' + outerTpl);

// 1. compile chunk -> bytecode (temp .luac next to the output)
const luac = outerOut + '.luac.tmp';
try {
  execFileSync(HKSC, ['-s', '-o', luac, chunkSrc], { stdio: 'pipe' });
} catch (e) {
  die('hksc failed on ' + chunkSrc + ': ' + (e.stderr ? e.stderr.toString() : e.message));
}
const bc = fs.readFileSync(luac);
fs.unlinkSync(luac);

// sanity: T7 HKS header (\x1bLua, ver 0x51, format 0x0e)
if (!(bc[0] === 0x1b && bc[1] === 0x4c && bc[2] === 0x75 && bc[3] === 0x61 && bc[4] === 0x51 && bc[5] === 0x0e)) {
  die('compiled output is not T7 HKS bytecode (header ' + [...bc.slice(0, 6)].map(b => b.toString(16)).join(' ') + ')');
}

// 2. bytecode -> \ddd escaped Lua string (3-digit, unambiguous in Lua 5.1)
let esc = '';
for (const x of bc) esc += '\\' + String(x).padStart(3, '0');

// 3. splice into the outer template
const tpl = fs.readFileSync(outerTpl, 'latin1');
if (tpl.indexOf(MARKER) < 0) die('outer template has no ' + MARKER + ' marker');
if (tpl.indexOf(MARKER) !== tpl.lastIndexOf(MARKER)) die('outer template has more than one ' + MARKER + ' marker');
const out = tpl.replace(MARKER, esc);
fs.writeFileSync(outerOut, out, 'latin1');

console.log('[build_lui_bytecode] ' + path.basename(chunkSrc) + ' -> ' + bc.length + ' bytes bytecode -> ' + path.basename(outerOut) + ' (' + esc.length + ' escaped chars)');
