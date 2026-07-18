// build_lb_lui.js - generate the two shipped leaderboard LUI files (docs/40).
//
//   tools/lui_chunks/acc_lb_rec_chunk.lua   -\
//   tools/lui_chunks/acc_lb_board_chunk.lua --+-> hksc (T7 HKS bytecode) -> \ddd string
//   tools/lui_chunks/*_outer.tpl.lua        -/    -> spliced at @@ACC_LUI_BYTECODE@@
//                                                 -> ui/uieditor/menus/hud/acc_lb_rec.lua
//                                                    ui/uieditor/menus/hud/acc_lb_board.lua
//
// Backend URL + write key come from backend/leaderboard/deployed.local.json
// (gitignored). Missing file = a warning + LOCAL-ONLY build (empty URL: the rec
// chunk skips the POST, the board chunk falls straight to the machine-local file).
//
// Chunk placeholders: @@ACC_LB_URL@@  @@ACC_LB_KEY@@  @@ACC_LB_MAPV@@ (build date).
// Re-run after editing anything under tools/lui_chunks/ (then sync + build).
// Same recipe as tools/build_lui_bytecode.js, self-contained for the two-file pair.

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const HKSC = path.join(__dirname, 'hksc', 'hksc.exe');
const CHUNKS = path.join(__dirname, 'lui_chunks');
const OUTDIR = path.join(ROOT, 'ui', 'uieditor', 'menus', 'hud');
const MARKER = '@@ACC_LUI_BYTECODE@@';

function die(msg) { console.error('[build_lb_lui] FAIL: ' + msg); process.exit(1); }

if (!fs.existsSync(HKSC)) die('missing compiler ' + HKSC + ' (see tools/hksc/README.md)');

// backend config (gitignored) - absent = local-only build
let url = '', key = '';
const cfgPath = path.join(ROOT, 'backend', 'leaderboard', 'deployed.local.json');
if (fs.existsSync(cfgPath)) {
  try {
    const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
    url = String(cfg.url || '').replace(/\/+$/, '');
    key = String(cfg.acc_key || '');
  } catch (e) { die('unparseable ' + cfgPath + ': ' + e.message); }
} else {
  console.warn('[build_lb_lui] WARN: no backend/leaderboard/deployed.local.json - building LOCAL-ONLY (no cloud POST/GET)');
}
// Reject quote-ish chars (would break the Lua splice) AND cmd-special ! / % - since the
// agent .bat runs under `setlocal EnableDelayedExpansion` (for the ?players=N GET suffix,
// docs/40), a `!` or `%` in the URL/key would be eaten as a variable and silently corrupt
// the x-acc-key POST header. Fail the build loudly instead.
if (/[\\"'!%]/.test(url) || /[\\"'!%]/.test(key)) die('url/key contain quote-ish or cmd-special (! %) chars - would break the Lua splice or the delayed-expansion agent .bat');
const mapv = new Date().toISOString().slice(0, 10);

function compileChunk(chunkFile) {
  let src = fs.readFileSync(path.join(CHUNKS, chunkFile), 'utf8');
  src = src.split('@@ACC_LB_URL@@').join(url)
           .split('@@ACC_LB_KEY@@').join(key)
           .split('@@ACC_LB_MAPV@@').join(mapv);
  const tmpSrc = path.join(CHUNKS, chunkFile + '.subst.tmp');
  const tmpOut = path.join(CHUNKS, chunkFile + '.luac.tmp');
  fs.writeFileSync(tmpSrc, src, 'utf8');
  try {
    execFileSync(HKSC, ['-s', '-o', tmpOut, tmpSrc], { stdio: 'pipe' });
  } catch (e) {
    die('hksc failed on ' + chunkFile + ': ' + (e.stderr ? e.stderr.toString() : e.message));
  } finally {
    if (fs.existsSync(tmpSrc)) fs.unlinkSync(tmpSrc);
  }
  const bc = fs.readFileSync(tmpOut);
  fs.unlinkSync(tmpOut);
  // sanity: T7 HKS header (\x1bLua, ver 0x51, format 0x0e) - matches MACHIN[A]'s
  if (!(bc[0] === 0x1b && bc[1] === 0x4c && bc[2] === 0x75 && bc[3] === 0x61 && bc[4] === 0x51 && bc[5] === 0x0e)) {
    die(chunkFile + ' compiled to non-T7-HKS bytecode (header ' + [...bc.slice(0, 6)].map(b => b.toString(16)).join(' ') + ')');
  }
  let esc = '';
  for (const x of bc) esc += '\\' + String(x).padStart(3, '0');
  return { esc, len: bc.length };
}

function splice(tplFile, esc, outFile) {
  const tpl = fs.readFileSync(path.join(CHUNKS, tplFile), 'latin1');
  if (tpl.indexOf(MARKER) < 0) die(tplFile + ' has no ' + MARKER + ' marker');
  if (tpl.indexOf(MARKER) !== tpl.lastIndexOf(MARKER)) die(tplFile + ' has more than one marker');
  fs.writeFileSync(path.join(OUTDIR, outFile), tpl.replace(MARKER, esc), 'latin1');
}

const rec = compileChunk('acc_lb_rec_chunk.lua');
splice('acc_lb_rec_outer.tpl.lua', rec.esc, 'acc_lb_rec.lua');
console.log('[build_lb_lui] acc_lb_rec.lua   <- ' + rec.len + ' bytecode bytes' + (url ? '' : ' (LOCAL-ONLY)'));

const board = compileChunk('acc_lb_board_chunk.lua');
splice('acc_lb_board_outer.tpl.lua', board.esc, 'acc_lb_board.lua');
console.log('[build_lb_lui] acc_lb_board.lua <- ' + board.len + ' bytecode bytes' + (url ? '' : ' (LOCAL-ONLY)'));

const boot = compileChunk('acc_lb_boot_chunk.lua');
splice('acc_lb_boot_outer.tpl.lua', boot.esc, 'acc_lb_boot.lua');
console.log('[build_lb_lui] acc_lb_boot.lua  <- ' + boot.len + ' bytecode bytes (the background curl agent)');

// the launcher-side agent pre-spawner (silent-terminal fix, docs/40): same URL/key
// splice, written into tools/ where the PLAY_*.bat scripts call it.
let ps = fs.readFileSync(path.join(CHUNKS, 'spawn_lb_agent.tpl.ps1'), 'utf8');
ps = ps.split('@@ACC_LB_URL@@').join(url).split('@@ACC_LB_KEY@@').join(key);
fs.writeFileSync(path.join(__dirname, 'spawn_lb_agent.ps1'), ps, 'utf8');
console.log('[build_lb_lui] tools/spawn_lb_agent.ps1 generated (launcher hidden pre-spawn)');
console.log('[build_lb_lui] backend=' + (url || '(none)') + ' map_version=' + mapv);
