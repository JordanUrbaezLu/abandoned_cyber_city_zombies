// Executable replica of _acc_weapon_variants (post wonder-twins): subset resolver + per-gun filter.
const DIMS = [['recoil50'], ['fastreload'], ['turbo']];
function buildSuffixes() {
  const radix = DIMS.map(d => d.length + 1); const total = radix.reduce((a, b) => a * b, 1); const out = [];
  for (let n = 0; n < total; n++) { let rem = n, s = '_acc', any = false; for (let d = 0; d < DIMS.length; d++) { const c = rem % radix[d]; rem = Math.floor(rem / radix[d]); if (c > 0) { s += '_' + DIMS[d][c - 1]; any = true; } } if (any) out.push(s); }
  return out;
}
const suffixes = buildSuffixes();
const GUNS = ['s1_tac19','t6_fiveseven','t9_ak47','s1_ae4','t9_semiauto_cosplay','s4_ppsh41_base','t9_grav','t6_olympia','t9_ak74u','t9_m60','t9_rpd','s1_rw1','s1_mk14','s1_mors','t9_xm4','t9_streetsweeper','apex_peacekeeper','apex_alternator','apex_prowler','apex_g2a4','s1_cel3','apex_beam_rifle','s1_mahem','thundergun','elemental_bow_demongate'];
const TRIO = ['s1_mahem', 'thundergun', 'elemental_bow_demongate'];
function upName(g) { return g === 'thundergun' ? 'thundergun_upgraded' : g + '_up'; }
function formBakes(gun, form, suffix) {
  if (suffix.includes('turbo') && gun !== 'apex_beam_rifle') return false;
  if (TRIO.includes(gun)) {
    if (suffix !== '_acc_fastreload') return false;
    if (gun === 'elemental_bow_demongate' && form !== gun) return false;
  }
  return true;
}
const allow = new Set();
for (const g of GUNS) for (const form of [g, upName(g)]) for (const s of suffixes) {
  if (!formBakes(g, form, s)) continue;
  allow.add(form + s);
}
console.log('allow-list size:', allow.size, '(expect 132 + 8 turbo + 5 wonder = 145)');

// subset resolver replica
function desired(stem, tokens) {
  const n = tokens.length, total = 1 << n;
  for (let count = n; count >= 1; count--) {
    for (let mask = 1; mask < total; mask++) {
      let bits = 0; for (let i = 0; i < n; i++) if (mask & (1 << i)) bits++;
      if (bits !== count) continue;
      let suffix = '_acc'; for (let i = 0; i < n; i++) if (mask & (1 << i)) suffix += '_' + tokens[i];
      if (allow.has(stem + suffix)) return stem + suffix;
    }
  }
  return stem;
}
const cases = [
  // the critical wonder cases: fastreload must be reachable even with recoil50/turbo active
  [['recoil50','fastreload'], 's1_mahem', 's1_mahem_acc_fastreload'],
  [['recoil50','fastreload'], 'thundergun', 'thundergun_acc_fastreload'],
  [['recoil50','fastreload'], 'thundergun_upgraded', 'thundergun_upgraded_acc_fastreload'],
  [['recoil50','fastreload','turbo'], 'elemental_bow_demongate', 'elemental_bow_demongate_acc_fastreload'],
  [['fastreload'], 's1_mahem_up', 's1_mahem_up_acc_fastreload'],
  [['recoil50'], 's1_mahem', 's1_mahem'],                       // no recoil twin for the trio -> base
  [['recoil50'], 'thundergun_upgraded', 'thundergun_upgraded'],
  [['fastreload','turbo'], 'elemental_bow_demongate', 'elemental_bow_demongate_acc_fastreload'],
  // regression: normal guns + havoc unchanged
  [['recoil50','fastreload','turbo'], 'apex_beam_rifle', 'apex_beam_rifle_acc_recoil50_fastreload_turbo'],
  [['recoil50','turbo'], 't9_ak47', 't9_ak47_acc_recoil50'],
  [['recoil50','fastreload'], 't9_grav_up', 't9_grav_up_acc_recoil50_fastreload'],
  [['turbo'], 's1_mors', 's1_mors'],
  [['recoil50','fastreload'], 'apex_beam_rifle_up', 'apex_beam_rifle_up_acc_recoil50_fastreload'],
];
let ok = true;
for (const [tokens, stem, want] of cases) {
  const got = desired(stem, tokens);
  const pass = got === want; if (!pass) ok = false;
  console.log((pass ? '  ok  ' : '  FAIL') + ' [' + tokens.join('+') + '] ' + stem + ' -> ' + got + (pass ? '' : ' (want ' + want + ')'));
}
// stem-strip safety on all names
function stem(name) { for (const s of suffixes) if (name.endsWith(s)) return name.slice(0, name.length - s.length); return name; }
let ok3 = true;
for (const nme of allow) {
  const st = stem(nme);
  const valid = GUNS.includes(st) || GUNS.some(g => st === upName(g));
  if (!valid) { console.log('  BAD STEM: ' + nme + ' -> ' + st); ok3 = false; }
}
console.log('resolver:', ok ? 'PASS' : 'FAIL', '| stem-strip on', allow.size, 'twins:', ok3 ? 'PASS' : 'FAIL');
