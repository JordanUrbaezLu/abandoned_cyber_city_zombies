// Install the user's downloaded sci-fi charge-up wav as the Havoc's fireDelay charge SFX.
// 1. Resample 44.1k mono PCM -> 48k (linear interp; pack wavs are 48k) -> sound_assets\acc\acc_havoc_charge.wav
// 2. Append an `acc_havoc_charge` alias to sound/aliases/acc_apex_weapons.csv (cloned from the
//    wpn_apex_beam_rifle_press row: same BUS_FX weapon-foley routing, 2d player-ish).
// 3. Point the beam_rifle base GDT fireDelayStartSound(Player) at it (regen _up after).
const fs = require('fs');

const SRCWAV = 'C:/Users/jorda/Downloads/freesound_community-sci-fi-charge-up-37395.wav';
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const OUTDIR = TOOLS + '/sound_assets/acc';
const OUTWAV = OUTDIR + '/acc_havoc_charge.wav';
const CSV = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies/sound/aliases/acc_apex_weapons.csv';
const GDT = TOOLS + '/source_data/zeroy/APEX_BO3.gdt';

// ---- 1. resample to 48k mono 16-bit PCM
const b = fs.readFileSync(SRCWAV);
const fi = b.indexOf(Buffer.from('fmt '));
const ch = b.readUInt16LE(fi + 10), sr = b.readUInt32LE(fi + 12), bits = b.readUInt16LE(fi + 22);
if (ch !== 1 || bits !== 16) throw new Error('expected mono 16-bit, got ch=' + ch + ' bits=' + bits);
const di = b.indexOf(Buffer.from('data'));
const ds = b.readUInt32LE(di + 4);
const inSamp = new Int16Array(ds / 2);
for (let i = 0; i < inSamp.length; i++) inSamp[i] = b.readInt16LE(di + 8 + i * 2);
const OUTRATE = 48000;
const outLen = Math.floor(inSamp.length * OUTRATE / sr);
const out = new Int16Array(outLen);
for (let i = 0; i < outLen; i++) {
  const x = i * sr / OUTRATE;
  const i0 = Math.floor(x), i1 = Math.min(i0 + 1, inSamp.length - 1), f = x - i0;
  out[i] = Math.round(inSamp[i0] * (1 - f) + inSamp[i1] * f);
}
// write canonical 44-byte-header wav
const dataBytes = out.length * 2;
const hdr = Buffer.alloc(44);
hdr.write('RIFF', 0); hdr.writeUInt32LE(36 + dataBytes, 4); hdr.write('WAVE', 8);
hdr.write('fmt ', 12); hdr.writeUInt32LE(16, 16); hdr.writeUInt16LE(1, 20); hdr.writeUInt16LE(1, 22);
hdr.writeUInt32LE(OUTRATE, 24); hdr.writeUInt32LE(OUTRATE * 2, 28); hdr.writeUInt16LE(2, 32); hdr.writeUInt16LE(16, 34);
hdr.write('data', 36); hdr.writeUInt32LE(dataBytes, 40);
fs.mkdirSync(OUTDIR, { recursive: true });
fs.writeFileSync(OUTWAV, Buffer.concat([hdr, Buffer.from(out.buffer)]));
console.log('wrote ' + OUTWAV + ' (' + (out.length / OUTRATE).toFixed(2) + 's @48k mono)');

// ---- 2. alias row (clone press, rename + new filespec)
let csv = fs.readFileSync(CSV, 'utf8');
if (!csv.includes('acc_havoc_charge')) {
  const press = csv.split(/\r?\n/).find(l => l.startsWith('wpn_apex_beam_rifle_press,'));
  if (!press) throw new Error('press template row not found');
  const cols = press.split(',');
  cols[0] = 'acc_havoc_charge';                    // Name
  cols[3] = 'acc\\acc_havoc_charge.wav';           // FileSpec
  const row = cols.join(',');
  csv = csv.replace(/\n?$/, '\n') + row + '\n';
  fs.writeFileSync(CSV, csv);
  console.log('alias added: acc_havoc_charge -> acc\\acc_havoc_charge.wav');
} else console.log('alias already present');

// ---- 3. GDT: point the charge fields at the new alias
let gdt = fs.readFileSync(GDT, 'utf8');
const m = gdt.match(/"apex_beam_rifle_zm"\s*\(\s*"[a-z]+\.gdf"\s*\)/);
const start = m.index;
const next = gdt.slice(start + 10).search(/"apex_[a-z0-9_]+"\s*\(\s*"[a-z]+\.gdf"\s*\)/);
const end = next < 0 ? gdt.length : start + 10 + next;
let block = gdt.slice(start, end);
block = block.replace(/("fireDelayStartSound"\s+)"[^"]*"/, '$1"acc_havoc_charge"');
block = block.replace(/("fireDelayStartSoundPlayer"\s+)"[^"]*"/, '$1"acc_havoc_charge"');
gdt = gdt.slice(0, start) + block + gdt.slice(end);
fs.writeFileSync(GDT, gdt);
console.log('GDT: fireDelayStartSound(Player) = acc_havoc_charge');
