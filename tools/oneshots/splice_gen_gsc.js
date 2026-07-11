// Splice the two GENERATED gsc blocks from docs/54 into their consumer GSC files, between the markers.
const fs = require('fs');
const REPO = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies';
const doc = fs.readFileSync(REPO + '/docs/54_pap_pricing_tiers.md', 'utf8');

// extract the two ```gsc ... ``` blocks (order: #1 pap_price_bucket+tier_cost, #2 acc_box_weight)
const blocks = [...doc.matchAll(/```gsc\r?\n([\s\S]*?)```/g)].map(m => m[1].replace(/\s+$/, ''));
if (blocks.length < 2) { console.error('ERROR: expected 2 gsc blocks in docs/54, got ' + blocks.length); process.exit(1); }
const papBlock = blocks[0];   // pap_price_bucket + tier_cost
const boxBlock = blocks[1];   // acc_box_weight
if (!/function pap_price_bucket/.test(papBlock) || !/function tier_cost/.test(papBlock)) { console.error('ERROR: block1 not pap/tier'); process.exit(1); }
if (!/function acc_box_weight/.test(boxBlock)) { console.error('ERROR: block2 not acc_box_weight'); process.exit(1); }

function splice(file, newBody) {
  const p = REPO + '/' + file;
  let t = fs.readFileSync(p, 'utf8');
  const eol = t.includes('\r\n') ? '\r\n' : '\n';
  const beginRe = /(^.*BEGIN GENERATED \(tools\/compute_gun_tiers\.js\) >>>.*$)/m;
  const endRe = /(^.*END GENERATED >>>.*$)/m;
  const bM = t.match(beginRe), eM = t.match(endRe);
  if (!bM || !eM) { console.error('ERROR: markers not found in ' + file); process.exit(1); }
  const bIdx = t.indexOf(bM[0]) + bM[0].length;
  const eIdx = t.indexOf(eM[0]);
  if (eIdx <= bIdx) { console.error('ERROR: end before begin in ' + file); process.exit(1); }
  const bodyLF = newBody.split(/\r?\n/).join(eol);
  const result = t.slice(0, bIdx) + eol + bodyLF + eol + t.slice(eIdx);
  fs.writeFileSync(p, result);
  const fnCount = (bodyLF.match(/^function /gm) || []).length;
  console.log(`spliced ${file}: ${bodyLF.split(/\r?\n/).length} lines, ${fnCount} function(s)`);
}

splice('scripts/zm/zm_abandoned_cyber_city/_acc_pap_levels.gsc', papBlock);
splice('scripts/zm/zm_abandoned_cyber_city/_acc_map_randomizer.gsc', boxBlock);
console.log('done.');
