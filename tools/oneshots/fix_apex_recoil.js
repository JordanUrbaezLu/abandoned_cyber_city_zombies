// Raise Apex gun recoil to match the map's current guns (user 2026-07-06: "increase recoil to
// match current guns"). References: t9_ak74u (SMG) pitch -52.5..105 yaw +-105 CS 1500 GK +-17.5;
// s1_tac19 (pump SG) pitch 105..140 GK 61..79. Edits the APEX_BO3.gdt BASE blocks only - run
// gen_apex_up.js AFTER this so the _up clones inherit.
const fs = require('fs');
const P = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data/zeroy/APEX_BO3.gdt';
let text = fs.readFileSync(P, 'utf8');

const TUNE = {
  // SMG full-auto -> AK-74u pattern
  apex_alternator: { adsViewKickPitchMin: -52.5, adsViewKickPitchMax: 105, adsViewKickYawMin: -105, adsViewKickYawMax: 105,
                     hipViewKickPitchMin: -52.5, hipViewKickPitchMax: 105, hipViewKickYawMin: -105, hipViewKickYawMax: 105,
                     adsViewKickCenterSpeed: 1500, hipViewKickCenterSpeed: 1500,
                     adsGunKickPitchMin: -17.5, adsGunKickPitchMax: 17.5, adsGunKickYawMin: -17.5, adsGunKickYawMax: 17.5 },
  // SMG burst-y -> slightly softer than AK-74u
  apex_prowler:    { adsViewKickPitchMin: -40, adsViewKickPitchMax: 95, adsViewKickYawMin: -90, adsViewKickYawMax: 90,
                     hipViewKickPitchMin: -40, hipViewKickPitchMax: 95, hipViewKickYawMin: -90, hipViewKickYawMax: 90,
                     adsViewKickCenterSpeed: 1500, hipViewKickCenterSpeed: 1500,
                     adsGunKickPitchMin: -15, adsGunKickPitchMax: 15, adsGunKickYawMin: -15, adsGunKickYawMax: 15 },
  // semi-auto marksman -> strong per-shot kick (MK14-ish), no more zero gunkick
  apex_g2a4:       { adsViewKickPitchMin: 60, adsViewKickPitchMax: 105, adsViewKickYawMin: -70, adsViewKickYawMax: 70,
                     hipViewKickPitchMin: 60, hipViewKickPitchMax: 105, hipViewKickYawMin: -70, hipViewKickYawMax: 70,
                     adsGunKickPitchMin: -12, adsGunKickPitchMax: 12, adsGunKickYawMin: -12, adsGunKickYawMax: 12 },
  // full-auto energy rifle: real yaw + stop the instant recenter (CS 2000 felt like no recoil)
  apex_beam_rifle: { adsViewKickYawMin: -50, adsViewKickYawMax: 50, hipViewKickYawMin: -50, hipViewKickYawMax: 50,
                     adsViewKickCenterSpeed: 1500, hipViewKickCenterSpeed: 1500,
                     adsGunKickPitchMin: -12, adsGunKickPitchMax: 12, adsGunKickYawMin: -12, adsGunKickYawMax: 12 },
  // one-pump lever shotgun: heavy kick (tac19-ward), fix the inverted yaw range (-75..-95)
  apex_peacekeeper:{ adsViewKickPitchMin: 90, adsViewKickPitchMax: 120, adsViewKickYawMin: -60, adsViewKickYawMax: 60,
                     hipViewKickPitchMin: 90, hipViewKickPitchMax: 120, hipViewKickYawMin: -60, hipViewKickYawMax: 60,
                     adsGunKickPitchMin: 45, adsGunKickPitchMax: 60, adsGunKickYawMin: -30, adsGunKickYawMax: 30 },
};

for (const [gun, vals] of Object.entries(TUNE)) {
  const hdr = new RegExp('"' + gun + '_zm"\\s*\\(\\s*"[a-z]+\\.gdf"\\s*\\)');
  const m = text.match(hdr);
  if (!m) throw new Error('no block for ' + gun);
  const start = m.index;
  const next = text.slice(start + 10).search(/"apex_[a-z0-9_]+"\s*\(\s*"[a-z]+\.gdf"\s*\)/);
  const end = next < 0 ? text.length : start + 10 + next;
  let block = text.slice(start, end);
  let set = 0;
  for (const [f, v] of Object.entries(vals)) {
    const re = new RegExp('("' + f + '"\\s+)"[^"]*"');
    if (re.test(block)) { block = block.replace(re, '$1"' + v + '"'); set++; }
    else console.log(`  WARN ${gun}: ${f} not found`);
  }
  text = text.slice(0, start) + block + text.slice(end);
  console.log(`${gun}: ${set} recoil fields set`);
}
fs.writeFileSync(P, text);
console.log('APEX_BO3.gdt recoil updated');
