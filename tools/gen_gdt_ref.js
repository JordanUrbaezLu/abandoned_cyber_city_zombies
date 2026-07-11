// Generate the GDT weapon-field reference artifact HTML from gdt_fields.json.
const fs = require('fs');
const path = require('path');
const { catOrder, fields } = JSON.parse(fs.readFileSync(path.join(__dirname, 'gdt_fields.json'), 'latin1'));

// Project-proven field notes (battle-tested on Abandoned Cyber City).
const NOTES = {
  fireDelay: 'Charge-gun press-guard on the Havoc: the fire input LATCHES on press and nothing in GSC clears it. 0.1 = minimum safe value with a 50ms script poll (0.05 leaks a shot per press). A raw fireDelay is felt on EVERY first trigger pull.',
  sprintOutTime: 'THE "delay after running" field. Engine blocks firing until sprint-out completes. The Apex Havoc shipped 0.98 vs 0.3 on its siblings — fixed to 0.1 here. When a gun feels laggy out of sprint, check this first.',
  damageRange2: 'Linker ABORTS with "Damage range distances went backwards" if a non-zero damageRange2..5 exceeds minDamageRange. Cutting a gun’s range without clamping these inverts the falloff. (Hit on the Skye shotguns.)',
  minDamageRange: 'Pairs with damageRange2..5 — see the damageRange2 trap. Scaling max/min down without the dR2+ ladder aborts the link.',
  maxAmmo: 'Reserve cap — the engine CLAMPS reserve to this, so a +25% ammo perk can only be granted by swapping to a twin def with a raised cap (the removed Armory twin axis).',
  reloadTime: 'Speed Cola Mega "fastreload" twin scales this ×0.857 on top of the engine’s free +50%. Viewmodel reload anims rescale to match.',
  fireTime: 'Rate of fire. Read-only at runtime (no SetFireRate builtin exists) — per-player RoF changes require a twin def.',
  penetrateType: 'FMJ-style wall-bang. The Tac-19 baseline buff sets "large". Free to change — no anim/FX dependencies.',
  fireSound: 'If a def uses loop-fire (fireSound empty, loopFireSound* set) but the loop wavs don’t exist, the gun is SILENT. Fix: blank the loopFire fields and set per-shot fireSound (hit on Prowler/Alternator).',
  loopFireSound: 'See fireSound — loop-fire defs without shipped loop wavs must be converted to per-shot sound.',
  spinUpTime: 'RED HERRING: GDF default is 1 and it ships on every Apex gun, all of which fire instantly — inert unless the fire type actually spins up (Minigun).',
  clipSize: 'Twin swaps copy clip/stock across with cap-delta math — raising this on a twin is safe (the PaP ammo-carry recipe).',
  explosionInnerDamage: 'Fixed absolute damage — does NOT scale with rounds (the Fire Bow tap-shot falls off hard; its charged shot is script-scaled instead).',
  explosionOuterDamage: 'See explosionInnerDamage — fixed value, never round-scaled.',
  weaponClass: 'Class-based naming: BO3 stock weapon names derive from this ("ar_accurate" = ICR-1). Never "<name>_zm" at runtime — the engine strips the mode suffix.',
  fireType: '"Charge Shot" types exist here but the T7 charge pipeline is half-wired for custom guns — the Havoc uses a script-owned timer instead (fireDelay press-guard + ammo gate).',
  moveSpeedScale: 'Per-gun mobility. Multiplies with SetMoveSpeedScale — remember zm_usermap resets the player scale to 1 on every spawn.',
  worldModel: 'PaP visual swap lives here on the _up def (Apex guns use the legendary_02 skin as the packed look).',
  viewModel: 'Held-weapon def swaps visibly yank the viewmodel — twins get away with it only at perk-buy frequency, never per-combat-event.',
  ADSTransInTime: 'ADS raise feel; pairs with adsTransBlendTime (hidden). Rescales the ADS-in anim.',
  hipSpreadStandMin: 'Hip-fire accuracy floor — the Tac-19 baseline widens spread ×1.25 as its damage trade.',
};

const esc = s => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

// Group the 83 raw categories into stable super-groups for the nav.
const GROUPS = [
  ['Identity & Class', ['Misc', 'Type Options', 'Alt Mode Options', 'User Interface', 'Uncategorized']],
  ['Damage', ['Damage', 'Damage Ranges', 'Other Damage', 'Multishot Base Damage Ranges', 'Location Damage', 'Damage Models']],
  ['Ammo & Reload', ['Ammo Options', 'Ammunition', 'Reload Options']],
  ['Fire & Charge', ['Charge Shot', 'Overheating', 'State Timers']],
  ['Projectile & Explosion', ['Projectile', 'Lock On Options', 'Tracer', 'Laser', 'Beam']],
  ['Accuracy: Spread / Recoil / Sway', ['Hip Spread Settings', 'Gun Kick Settings', 'View Kick Settings', 'Sway Settings', 'Aim Assist ( Console Only )', 'Anti Quick Scope Settings']],
  ['ADS & Optics', ['ADS Options', 'ADS Settings', 'ADS Overlay Settings', 'Crosshair Options', 'Reticle Settings', 'Depth of Field Settings', 'Idle Settings']],
  ['Movement', ['Movement, Sprint, Turning', 'Sprint Movement Settings', 'LowReady Movement Settings', 'Dive to Prone Movement Settings', 'Mantle Movement Settings', 'Player Slide Movement Settings', 'Strafe Movement Settings', 'WallRun Movement Settings', 'Stand Movement Settings', 'Crouch Movement Settings', 'Prone Movement Settings', 'Riding Vehicle Settings', 'Swimming']],
  ['Melee', ['Melee Fields', 'Melee']],
  ['Models & Anims', ['XModels', 'XAnims', 'Attachments', 'Attachments.', 'Attachment Cosmetic Variants', 'Attachment Perks', 'Camo', 'Left-Hand Grip Adjustment', 'Weapon Rest', 'Mountable Weaponry']],
  ['Audio / FX / Impacts', ['Sounds', 'Crack Sound Settings', 'Rumbles', 'FX', 'Impacts', 'Water properties', 'Entity FX']],
  ['Perks & AI', ['Weapon Perks', 'AI Settings']],
  ['Gadget (shared include)', ['Gadget (shared include)']],
];
const grouped = new Map(GROUPS.map(([g]) => [g, []]));
const catToGroup = {};
for (const [g, cats] of GROUPS) for (const c of cats) catToGroup[c] = g;
const leftovers = [];
for (const c of catOrder) {
  const g = catToGroup[c];
  if (g) grouped.get(g).push(c); else leftovers.push(c);
}
if (leftovers.length) grouped.set('Other', leftovers);

const byCat = {};
for (const f of fields) (byCat[f.category] = byCat[f.category] || []).push(f);

function srcChips(sources) {
  let h = '';
  if (sources.includes('bullet')) h += '<span class="chip chip-b" title="bulletweapon.gdf">B</span>';
  if (sources.includes('projectile')) h += '<span class="chip chip-p" title="projectileweapon.gdf">P</span>';
  if (sources.includes('gadget')) h += '<span class="chip chip-g" title="gadget.h shared include">G</span>';
  return h;
}

function valueCol(f) {
  if (f.type === 'Combo' || f.type === 'ArrayCombo' || f.type === 'MultiCombo') {
    const opts = (f.options || '').split('|').map(s => s.trim()).filter(Boolean);
    if (opts.length > 8) return esc(opts.slice(0, 8).join(' | ')) + ' <span class="more">+' + (opts.length - 8) + ' more</span>';
    return esc(opts.join(' | '));
  }
  if (f.type === 'AssetCombo') return esc(f.options || '');
  if (f.type === 'CheckBox') return 'default ' + esc(f.default);
  if (f.type === 'Float' || f.type === 'Int') {
    let s = 'default ' + esc(f.default);
    if (f.min !== undefined && f.max !== undefined) s += ' · range ' + esc(f.min) + '–' + esc(f.max);
    return s;
  }
  if (f.type === 'String') return f.default ? 'default "' + esc(f.default) + '"' : '';
  return '';
}

let catSections = '';
let nav = '';
let idn = 0;
for (const [group, cats] of grouped) {
  if (!cats.length) continue;
  const gid = 'g' + (idn++);
  nav += '<div class="nav-group"><div class="nav-group-title">' + esc(group) + '</div>';
  let sect = '';
  for (const cat of cats) {
    const fl = byCat[cat] || [];
    if (!fl.length) continue;
    const cid = 'c' + cat.replace(/[^a-z0-9]/gi, '_');
    nav += '<a href="#' + cid + '" data-cat="' + cid + '">' + esc(cat) + ' <span class="nav-n">' + fl.length + '</span></a>';
    let rows = '';
    for (const f of fl) {
      const note = NOTES[f.name];
      const hay = (f.name + ' ' + (f.title || '') + ' ' + (f.tooltip || '') + ' ' + (f.options || '')).toLowerCase();
      rows += '<tr class="fr' + (f.hidden ? ' is-hidden-field' : '') + (note ? ' has-note' : '') + '" data-src="' + f.sources.join(' ') + '" data-hay="' + esc(hay) + '">'
        + '<td class="c-name"><code title="click to copy">' + esc(f.name) + '</code>' + (note ? '<span class="star" title="project-proven">★</span>' : '') + (f.hidden ? '<span class="hid" title="Show(false): real GDT key, hidden in the APE UI">hidden</span>' : '') + '</td>'
        + '<td class="c-type"><span class="t t-' + f.type.toLowerCase() + '">' + esc(f.type) + '</span></td>'
        + '<td class="c-src">' + srcChips(f.sources) + '</td>'
        + '<td class="c-val">' + valueCol(f) + '</td>'
        + '<td class="c-desc">' + (f.title ? '<span class="ttl">' + esc(f.title) + '.</span> ' : '') + esc(f.tooltip || '')
        + (note ? '<div class="note"><span class="note-k">★ field note</span> ' + esc(note) + '</div>' : '')
        + '</td></tr>';
    }
    sect += '<section class="cat" id="' + cid + '"><h3>' + esc(cat) + ' <span class="cat-n"></span></h3>'
      + '<div class="tbl-wrap"><table><thead><tr><th>field</th><th>type</th><th>src</th><th>default / options</th><th>what it does</th></tr></thead><tbody>' + rows + '</tbody></table></div></section>';
  }
  nav += '</div>';
  catSections += '<div class="group" id="' + gid + '"><h2>' + esc(group) + '</h2>' + sect + '</div>';
}

const totals = {
  all: fields.length,
  bullet: fields.filter(f => f.sources.includes('bullet')).length,
  proj: fields.filter(f => f.sources.includes('projectile')).length,
  gadget: fields.filter(f => f.sources.includes('gadget')).length,
  noted: Object.keys(NOTES).filter(n => fields.some(f => f.name === n)).length,
};

const html = `<title>BO3 Weapon GDT Field Reference</title>
<style>
:root{
  --bg:#f2f4f6; --panel:#ffffff; --panel2:#e9edf0; --ink:#22282e; --ink2:#5a6570; --line:#d5dbe1;
  --accent:#0e8d96; --accent-ink:#0b7078; --accent-soft:#d9f2f4;
  --b:#0e8d96; --b-bg:#dff2f3; --p:#9a6b12; --p-bg:#f6ecd6; --g:#6a53b0; --g-bg:#ece6f8;
  --note-bg:#f4f0e2; --note-line:#c9b96a; --hid:#8a94a0;
  --mono:"Cascadia Code","Cascadia Mono",Consolas,"SF Mono",Menlo,monospace;
  --sans:"Segoe UI",system-ui,-apple-system,sans-serif;
}
@media (prefers-color-scheme: dark){:root{
  --bg:#14171c; --panel:#1c2129; --panel2:#232a33; --ink:#d6dae1; --ink2:#8a94a0; --line:#2c343e;
  --accent:#4bd0d8; --accent-ink:#7adfe5; --accent-soft:#123b3f;
  --b:#4bd0d8; --b-bg:#123b3f; --p:#d9a54a; --p-bg:#3a2e14; --g:#a08fd8; --g-bg:#2b2440;
  --note-bg:#262316; --note-line:#8a7a32; --hid:#5a6570;
}}
:root[data-theme="dark"]{
  --bg:#14171c; --panel:#1c2129; --panel2:#232a33; --ink:#d6dae1; --ink2:#8a94a0; --line:#2c343e;
  --accent:#4bd0d8; --accent-ink:#7adfe5; --accent-soft:#123b3f;
  --b:#4bd0d8; --b-bg:#123b3f; --p:#d9a54a; --p-bg:#3a2e14; --g:#a08fd8; --g-bg:#2b2440;
  --note-bg:#262316; --note-line:#8a7a32; --hid:#5a6570;
}
:root[data-theme="light"]{
  --bg:#f2f4f6; --panel:#ffffff; --panel2:#e9edf0; --ink:#22282e; --ink2:#5a6570; --line:#d5dbe1;
  --accent:#0e8d96; --accent-ink:#0b7078; --accent-soft:#d9f2f4;
  --b:#0e8d96; --b-bg:#dff2f3; --p:#9a6b12; --p-bg:#f6ecd6; --g:#6a53b0; --g-bg:#ece6f8;
  --note-bg:#f4f0e2; --note-line:#c9b96a; --hid:#8a94a0;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.5 var(--sans)}
a{color:var(--accent-ink);text-decoration:none}
code{font-family:var(--mono)}
.top{position:sticky;top:0;z-index:20;background:var(--panel);border-bottom:1px solid var(--line);padding:10px 16px;display:flex;flex-wrap:wrap;gap:10px;align-items:center}
.brand{font-family:var(--mono);font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:var(--accent-ink);white-space:nowrap}
.brand b{color:var(--ink);font-weight:600}
.search{flex:1 1 240px;min-width:180px;position:relative}
.search input{width:100%;padding:7px 10px 7px 30px;border:1px solid var(--line);border-radius:6px;background:var(--bg);color:var(--ink);font:13px var(--mono)}
.search input:focus{outline:2px solid var(--accent);outline-offset:-1px;border-color:transparent}
.search::before{content:"/";position:absolute;left:11px;top:6px;color:var(--ink2);font:13px var(--mono)}
.filters{display:flex;gap:6px;align-items:center;flex-wrap:wrap}
.fbtn{border:1px solid var(--line);background:var(--panel2);color:var(--ink2);border-radius:999px;padding:4px 11px;font:12px var(--mono);cursor:pointer}
.fbtn[aria-pressed="true"]{color:var(--ink);border-color:var(--accent);background:var(--accent-soft)}
.fbtn:focus-visible{outline:2px solid var(--accent);outline-offset:1px}
.count{font:12px var(--mono);color:var(--ink2);white-space:nowrap}
.wrap{display:grid;grid-template-columns:250px minmax(0,1fr);gap:0;max-width:1500px;margin:0 auto}
nav.side{position:sticky;top:56px;align-self:start;height:calc(100vh - 56px);overflow-y:auto;padding:14px 8px 40px 16px;border-right:1px solid var(--line)}
.nav-group{margin-bottom:12px}
.nav-group-title{font:11px var(--mono);letter-spacing:.12em;text-transform:uppercase;color:var(--ink2);margin:0 0 4px 6px}
nav.side a{display:flex;justify-content:space-between;gap:6px;padding:3px 8px;border-radius:5px;font-size:12.5px;color:var(--ink)}
nav.side a:hover{background:var(--panel2)}
nav.side a.active{background:var(--accent-soft);color:var(--accent-ink)}
.nav-n{color:var(--ink2);font:11px var(--mono)}
main{padding:18px 22px 80px;min-width:0}
.lede{max-width:70ch;color:var(--ink2);margin:4px 0 6px}
.lede b{color:var(--ink)}
.stats{display:flex;gap:18px;flex-wrap:wrap;margin:10px 0 4px;font:12.5px var(--mono);color:var(--ink2)}
.stats b{color:var(--ink);font-weight:600}
.legend{display:flex;gap:14px;flex-wrap:wrap;align-items:center;margin:8px 0 2px;font-size:12.5px;color:var(--ink2)}
.group h2{font:600 15px var(--mono);letter-spacing:.1em;text-transform:uppercase;color:var(--accent-ink);border-bottom:1px solid var(--line);padding:26px 0 6px;margin:0 0 4px}
.cat h3{font:600 14px var(--sans);margin:18px 0 6px}
.cat-n{font:11px var(--mono);color:var(--ink2);font-weight:400}
.tbl-wrap{overflow-x:auto;border:1px solid var(--line);border-radius:8px;background:var(--panel)}
table{border-collapse:collapse;width:100%;min-width:760px}
th{font:11px var(--mono);letter-spacing:.1em;text-transform:uppercase;color:var(--ink2);text-align:left;padding:7px 10px;border-bottom:1px solid var(--line);background:var(--panel2)}
td{padding:6px 10px;border-bottom:1px solid var(--line);vertical-align:top}
tr:last-child td{border-bottom:0}
tr.fr:hover td{background:color-mix(in srgb,var(--accent) 4%,transparent)}
.c-name{white-space:nowrap}
.c-name code{font-size:12.5px;color:var(--accent-ink);cursor:copy}
.c-name code.copied{color:var(--ink)}
.star{color:var(--p);margin-left:5px;font-size:11px}
.hid{margin-left:6px;font:10px var(--mono);color:var(--hid);border:1px solid var(--line);border-radius:4px;padding:0 4px;vertical-align:1px}
.c-type .t{font:11px var(--mono);color:var(--ink2)}
.c-src{white-space:nowrap}
.chip{display:inline-block;font:600 10px var(--mono);border-radius:4px;padding:1px 5px;margin-right:3px}
.chip-b{color:var(--b);background:var(--b-bg)}
.chip-p{color:var(--p);background:var(--p-bg)}
.chip-g{color:var(--g);background:var(--g-bg)}
.c-val{font:12px var(--mono);color:var(--ink2);max-width:26ch}
.more{color:var(--accent-ink)}
.c-desc{color:var(--ink);max-width:60ch;font-size:13px}
.ttl{color:var(--ink2)}
.note{margin-top:5px;padding:6px 9px;background:var(--note-bg);border-left:3px solid var(--note-line);border-radius:0 5px 5px 0;font-size:12.5px}
.note-k{font:600 10.5px var(--mono);letter-spacing:.08em;text-transform:uppercase;color:var(--p)}
.is-hidden-field .c-name code{color:var(--hid)}
.hide{display:none}
.empty{color:var(--ink2);padding:30px 0;text-align:center;font:13px var(--mono)}
@media (max-width:900px){.wrap{grid-template-columns:1fr}nav.side{display:none}}
@media (prefers-reduced-motion:no-preference){nav.side a,.fbtn{transition:background .12s,color .12s}}
</style>
<div class="top">
  <div class="brand">BO3 <b>Weapon GDT</b> field reference</div>
  <div class="search"><input id="q" type="search" placeholder="search 1,431 fields… (name, tooltip, option)" aria-label="Search fields"></div>
  <div class="filters" role="group" aria-label="Source filters">
    <button class="fbtn" id="fb" aria-pressed="true">bullet</button>
    <button class="fbtn" id="fp" aria-pressed="true">projectile</button>
    <button class="fbtn" id="fg" aria-pressed="true">gadget</button>
    <button class="fbtn" id="fh" aria-pressed="false">show hidden</button>
    <button class="fbtn" id="fn" aria-pressed="false">★ noted only</button>
  </div>
  <div class="count" id="count"></div>
</div>
<div class="wrap">
  <nav class="side" aria-label="Categories">${nav}</nav>
  <main>
    <p class="lede">Every field a weapon <b>.gdt block</b> can carry, extracted from the mod tools’ own APE schemas
    (<code>bulletweapon.awi</code>, <code>projectileweapon.awi</code>, and the shared <code>gadget.h</code> include) — with the engine’s
    types, defaults, ranges and tooltips. Rows marked <span class="star">★</span> carry battle-tested notes from this map.
    Remember: defs are <b>baked at link time</b> — per-player differences always mean a twin def, and any edit needs
    <code>gdtdb /update</code> + a relink.</p>
    <div class="stats">
      <span><b>${totals.all}</b> fields</span>
      <span><b>${totals.bullet}</b> bulletweapon</span>
      <span><b>${totals.proj}</b> projectileweapon</span>
      <span><b>${totals.gadget}</b> gadget include</span>
      <span><b>${totals.noted}</b> ★ project-proven</span>
    </div>
    <div class="legend">
      <span><span class="chip chip-b">B</span> bulletweapon.gdf</span>
      <span><span class="chip chip-p">P</span> projectileweapon.gdf (Havoc, Blast-O-Matic)</span>
      <span><span class="chip chip-g">G</span> gadget.h shared include</span>
      <span><span class="hid">hidden</span> = valid GDT key, not shown in APE’s UI</span>
      <span>click a field name to copy it</span>
    </div>
    ${catSections}
    <div class="empty hide" id="empty">no fields match</div>
  </main>
</div>
<script>
(function(){
  var rows = Array.prototype.slice.call(document.querySelectorAll('tr.fr'));
  var cats = Array.prototype.slice.call(document.querySelectorAll('section.cat'));
  var groups = Array.prototype.slice.call(document.querySelectorAll('div.group'));
  var q = document.getElementById('q'), count = document.getElementById('count'), empty = document.getElementById('empty');
  var st = { b:true, p:true, g:true, h:false, n:false, s:'' };
  function btn(id,k){ var el=document.getElementById(id); el.addEventListener('click',function(){ st[k]=!st[k]; el.setAttribute('aria-pressed',st[k]); apply(); }); }
  btn('fb','b'); btn('fp','p'); btn('fg','g'); btn('fh','h'); btn('fn','n');
  var deb; q.addEventListener('input',function(){ clearTimeout(deb); deb=setTimeout(function(){ st.s=q.value.toLowerCase().trim(); apply(); },120); });
  document.addEventListener('keydown',function(e){ if(e.key==='/'&&document.activeElement!==q){ e.preventDefault(); q.focus(); } });
  function apply(){
    var shown=0;
    rows.forEach(function(r){
      var src=r.getAttribute('data-src');
      var okSrc=(st.b&&src.indexOf('bullet')>-1)||(st.p&&src.indexOf('projectile')>-1)||(st.g&&src.indexOf('gadget')>-1);
      var okHid=st.h||r.className.indexOf('is-hidden-field')===-1;
      var okNote=!st.n||r.className.indexOf('has-note')>-1;
      var okS=!st.s||r.getAttribute('data-hay').indexOf(st.s)>-1;
      var ok=okSrc&&okHid&&okNote&&okS;
      r.classList.toggle('hide',!ok);
      if(ok)shown++;
    });
    cats.forEach(function(c){
      var vis=c.querySelectorAll('tr.fr:not(.hide)').length;
      c.classList.toggle('hide',vis===0);
      var n=c.querySelector('.cat-n'); if(n)n.textContent='('+vis+')';
    });
    groups.forEach(function(g){ g.classList.toggle('hide', g.querySelectorAll('section.cat:not(.hide)').length===0); });
    document.querySelectorAll('nav.side a').forEach(function(a){
      var c=document.getElementById(a.getAttribute('data-cat'));
      a.classList.toggle('hide', !c || c.classList.contains('hide'));
    });
    count.textContent = shown + ' / ' + rows.length;
    empty.classList.toggle('hide', shown!==0);
  }
  document.addEventListener('click',function(e){
    var t=e.target;
    if(t.tagName==='CODE'&&t.parentElement.className==='c-name'){
      var txt=t.textContent;
      try{ navigator.clipboard.writeText(txt); }catch(err){}
      t.classList.add('copied'); setTimeout(function(){ t.classList.remove('copied'); },600);
    }
  });
  apply();
})();
</script>`;

fs.writeFileSync(path.join(__dirname, 'gdt_field_reference.html'), html, 'utf8');
console.error('wrote gdt_field_reference.html', (html.length / 1024).toFixed(0) + 'KB');
