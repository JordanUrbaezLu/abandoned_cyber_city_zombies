// GDT ammo edits (user 2026-07-05, batch 2):
//  PPSH s4_ppsh41_base_up clipSize 54->60 (PaP clip to 60).
//  Streetsweeper t9_streetsweeper_up clip 18->14, maxAmmo 12->9 (clip+mag -25%; reserve 216->126).
//  Olympia clipSize 2->4 on BOTH base + _up (double clip -> reserve auto-doubles: base 26->52, PaP 42->84).
const fs = require('fs');
const SRC = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';
function backup(f, s){ const b=f+s; if(!fs.existsSync(b)){fs.copyFileSync(f,b);console.log('  backup -> '+b.split('/').pop());} else console.log('  backup exists: '+b.split('/').pop()); }
function apply(f, edits){ let t=fs.readFileSync(f,'utf8'); for(const [re,rep,want,label] of edits){ const n=(t.match(re)||[]).length; if(n!==want) throw new Error(`ABORT ${f.split('/').pop()} "${label}": matched ${n}, expected ${want}`); t=t.replace(re,rep); console.log(`  ${label}: ${n}`);} fs.writeFileSync(f,t); }

const ppsh = SRC+'/skye_s4_ppsh-41.gdt';
console.log('PPSH clip 54->60:'); backup(ppsh,'.acc-ammo-orig');
apply(ppsh, [[/("clipSize"\s+)"54"/g, '$1"60"', 1, 'clipSize 54->60 (base_up)']]);

const ss = SRC+'/skye_t9_streetsweeper.gdt';
console.log('Streetsweeper clip/mag -25%:'); backup(ss,'.acc-ammo-orig');
apply(ss, [
  [/("clipSize"\s+)"18"/g, '$1"14"', 1, 'clipSize 18->14 (_up)'],
  [/("maxAmmo"\s+)"12"/g,  '$1"9"',  1, 'maxAmmo 12->9 (_up)'],
]);

const oly = SRC+'/skye_t6_olympia.gdt';
console.log('Olympia clip 2->4 (both blocks):'); backup(oly,'.acc-ammo-orig');
apply(oly, [[/("clipSize"\s+)"2"/g, '$1"4"', 2, 'clipSize 2->4 (base + _up)']]);

console.log('\nGDT ammo edits complete.');
