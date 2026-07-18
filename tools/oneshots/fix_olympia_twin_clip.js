// One-shot (2026-07-12): heal the Olympia twin clipSize drift.
//
// The base-gun buff set t6_olympia / t6_olympia_up clipSize 2 -> 4 (skye_t6_olympia.gdt,
// CHANGELOG "clip+reserve doubled"), but the 6 acc variant twins in acc_weapon_variants.gdt
// were cloned in the clip-2 era and never updated - so pulling the Olympia from the box and
// having the variant engine swap you onto a twin (recoil50 / fastreload axes) "switched to
// the old GDT": the clip dropped 4 -> 2 (user report 2026-07-12). maxAmmo/startAmmo already
// mirror the base (13 mags base / 21 mags _up, ammoCountClipRelative 1), so ONLY clipSize
// drifted. This patches clipSize 2 -> 4 inside exactly the 6 named twin entries.
//
// Usage: node tools/oneshots/fix_olympia_twin_clip.js <gdt-path> [<gdt-path> ...]
//   (run on BOTH the repo copy and the install-side authoritative copy, then gdtdb /update)
//
// Entry-scoped: each edit is bounded to the segment between the entry's header line
// ("name" ( "bulletweapon.gdf" )) and the NEXT entry header - never a global replace.

'use strict';
const fs = require('fs');

const ENTRIES = [
    't6_olympia_acc_fastreload',
    't6_olympia_acc_recoil50',
    't6_olympia_acc_recoil50_fastreload',
    't6_olympia_up_acc_fastreload',
    't6_olympia_up_acc_recoil50',
    't6_olympia_up_acc_recoil50_fastreload',
];

const files = process.argv.slice(2);
if (!files.length) {
    console.error('usage: node fix_olympia_twin_clip.js <gdt-path> [...]');
    process.exit(1);
}

for (const file of files) {
    let text = fs.readFileSync(file, 'utf8');
    let patched = 0;
    for (const name of ENTRIES) {
        const header = `"${name}" ( "bulletweapon.gdf" )`;
        const start = text.indexOf(header);
        if (start < 0) throw new Error(`${name}: entry not found in ${file}`);
        // end of this entry = the next entry header ('" ( "' only appears on header lines)
        let end = text.indexOf('" ( "', start + header.length);
        if (end < 0) end = text.length;
        const seg = text.slice(start, end);
        const before = '"clipSize" "2"';
        const after = '"clipSize" "4"';
        const hits = seg.split(before).length - 1;
        if (hits !== 1) throw new Error(`${name}: expected exactly 1 clipSize "2", found ${hits} in ${file}`);
        text = text.slice(0, start) + seg.replace(before, after) + text.slice(end);
        patched++;
    }
    fs.writeFileSync(file, text);
    console.log(`${file}: patched clipSize 2 -> 4 on ${patched} Olympia twin entries`);
}
