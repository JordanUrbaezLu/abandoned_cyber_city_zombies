// Comprehensive docs renumber + cross-ref rewrite. Run with: node renumber.js [--apply]
const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const REPO = 'c:\\Users\\jorda\\Repositories\\abandoned_cyber_city_zombies';
const MEMORY = 'C:\\Users\\jorda\\.claude\\projects\\c--Users-jorda-Repositories-abandoned-cyber-city-zombies\\memory';
const APPLY = process.argv.includes('--apply');

// ---- SURVIVOR renumber: oldNum -> newNum (00,01 unchanged; KB stays named) ----
const survivorNum = {
  '03':'02','04':'03','05':'04','06':'05','07':'06','08':'07','11':'08','12':'09','13':'10',
  '14':'11','15':'12','17':'13','19':'14','20':'15','22':'16','23':'17','24':'18','28':'19',
  '29':'20','33':'21','34':'22','35':'23','37':'24','41':'25','43':'26','44':'27','46':'28',
  '47':'29','48':'30','50':'31','53':'32','54':'33','55':'34','56':'35','57':'36','58':'37',
  '59':'38','60':'39','00':'00','01':'01',
};
// full old survivor filenames -> new filenames
const survivorFiles = {
  '00_overview.md':'00_overview.md','01_toolchain.md':'01_toolchain.md',
  '03_layout.md':'02_layout.md','04_progression_and_skills.md':'03_progression_and_skills.md',
  '05_weapons.md':'04_weapons.md','06_mechanics.md':'05_mechanics.md','07_replayability.md':'06_replayability.md',
  '08_milestones.md':'07_milestones.md','11_enemies.md':'08_enemies.md','12_boss_items.md':'09_boss_items.md',
  '13_perks.md':'10_perks.md','14_controls_and_hud.md':'11_controls_and_hud.md','15_coop_rules.md':'12_coop_rules.md',
  '17_reference_maps_study.md':'13_reference_maps_study.md','19_stock_api_verification.md':'14_stock_api_verification.md',
  '20_requirements_checklist.md':'15_requirements_checklist.md','22_community_techniques.md':'16_community_techniques.md',
  '23_launch_runbook.md':'17_launch_runbook.md','24_test_session.md':'18_test_session.md','28_lui_pipeline.md':'19_lui_pipeline.md',
  '29_atmosphere_and_materials.md':'20_atmosphere_and_materials.md','33_adding_a_gun_runbook.md':'21_adding_a_gun_runbook.md',
  '34_flags_reference.md':'22_flags_reference.md','35_sound_plan.md':'23_sound_plan.md','37_punishing_middle_design.md':'24_punishing_middle_design.md',
  '41_weapon_stats_table.md':'25_weapon_stats_table.md','43_lockdown_challenge_room.md':'26_lockdown_challenge_room.md',
  '44_stock_models.md':'27_stock_models.md','46_trench_systems_guide.md':'28_trench_systems_guide.md',
  '47_exo_suit_plan.md':'29_exo_suit_plan.md','48_abyss_descent.md':'30_abyss_descent.md','50_vague_ui_language.md':'31_vague_ui_language.md',
  '53_economy_sources.md':'32_economy_sources.md','54_pap_pricing_tiers.md':'33_pap_pricing_tiers.md','55_release_runbook.md':'34_release_runbook.md',
  '56_bo2_to_bo3_asset_porting.md':'35_bo2_to_bo3_asset_porting.md','57_player_guide.md':'36_player_guide.md',
  '58_transfer_vault.md':'37_transfer_vault.md','59_steam_workshop_marketing.md':'38_steam_workshop_marketing.md','60_armory.md':'39_armory.md',
};
// ---- DELETED docs -> redirect target (full old filename -> new target filename) ----
const deletedFiles = {
  '02_learning_path.md':'01_toolchain.md','09_language_and_publishing.md':'34_release_runbook.md',
  '10_today_quickstart.md':'17_launch_runbook.md','16_gsc_reference.md':'14_stock_api_verification.md',
  '18_first_build_checklist.md':'34_release_runbook.md','21_weapon_import_sources.md':'21_adding_a_gun_runbook.md',
  '26_compliance_audit.md':'15_requirements_checklist.md','27_ui_plan.md':'11_controls_and_hud.md',
  '29_overhaul_checklist.md':'10_perks.md','30_perk_gdt_radiant_spec.md':'21_adding_a_gun_runbook.md',
  '31_ape_perk_gdt_walkthrough.md':'21_adding_a_gun_runbook.md','32_box_weapon_import_staging.md':'21_adding_a_gun_runbook.md',
  '36_map_tightening_research.md':'BO3_MAPMAKING_KB.md','38_lab_tunnel_led_safe_research.md':'BO3_MAPMAKING_KB.md',
  '39_all_guns_perk_handling_plan.md':'21_adding_a_gun_runbook.md','40_lighting_blocker_report.md':'BO3_MAPMAKING_KB.md',
  '42_round_progress_ring_research.md':'11_controls_and_hud.md','45_underground_blackmarket_design.md':'30_abyss_descent.md',
  '49_dev_mode_consolidation.md':'22_flags_reference.md','49_hud_modernization.md':'19_lui_pipeline.md',
  '51_sfx_checklist.md':'23_sound_plan.md','52_model_upgrade_checklist.md':'09_boss_items.md',
  '56_private_release_cheatsheet.md':'34_release_runbook.md','perk_abilities.md':'10_perks.md',
};
// bare `docs/NN` -> new token. Survivors use survivorNum; deleted-primary redirect:
const deletedNum = {
  '02':'01','09':'34','10':'17','16':'14','18':'34','21':'21','26':'15','27':'11','30':'21','31':'21',
  '32':'21','36':'BO3_MAPMAKING_KB','38':'BO3_MAPMAKING_KB','39':'21','40':'BO3_MAPMAKING_KB','42':'11',
  '45':'30','49':'22','51':'23','52':'09',
};
const numMap = Object.assign({}, deletedNum, survivorNum); // survivor wins on shared numbers (29,56)

const allFileMap = Object.assign({}, survivorFiles, deletedFiles);

// regexes
const fnameRe = /\b(\d{2}_[a-z0-9_]+\.md|perk_abilities\.md)\b/g;
const bareRe = /docs\/(\d{2})(?![0-9_])/g;

function rewrite(text) {
  let n = 0;
  // filename-form refs first (more specific)
  text = text.replace(fnameRe, (m) => {
    if (allFileMap[m] && allFileMap[m] !== m) { n++; return allFileMap[m]; }
    return m;
  });
  // bare docs/NN
  text = text.replace(bareRe, (m, num) => {
    const t = numMap[num];
    if (!t) return m;
    if (t === 'BO3_MAPMAKING_KB') { n++; return 'docs/BO3_MAPMAKING_KB.md'; }
    if (t !== num) { n++; return 'docs/' + t; }
    return m;
  });
  return { text, n };
}

// build fileset
function walk(dir, exts, out) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, exts, out);
    else if (exts.some(x => e.name.endsWith(x))) out.push(p);
  }
}
const files = [];
walk(path.join(REPO, 'docs'), ['.md'], files);
walk(path.join(REPO, 'scripts'), ['.gsc', '.csc'], files);
for (const f of ['CLAUDE.md','README.md','ONBOARDING.md','ROADMAP.md','SETUP_WINDOWS.md','MISSING_REQUIREMENTS.md','CHANGELOG.md','CREDITS.md','REQUIREMENTS.md','ToDoList.md','Notes.md'])
  { const p = path.join(REPO, f); if (fs.existsSync(p)) files.push(p); }
if (fs.existsSync(MEMORY)) walk(MEMORY, ['.md'], files);

// CHANGELOG.md is append-only history — do NOT rewrite past entries' refs (would falsify the
// record and redirect to deleted docs). It gets a top note instead (added separately).
const EXCLUDE = new Set(['CHANGELOG.md']);

let totalRefs = 0, filesChanged = 0;
const report = [];
for (const f of files) {
  if (EXCLUDE.has(path.basename(f))) continue;
  let text = fs.readFileSync(f, 'utf8');
  const { text: nt, n } = rewrite(text);
  if (n > 0 && nt !== text) {
    totalRefs += n; filesChanged++;
    report.push(`${n}\t${path.relative(REPO, f) || f}`);
    if (APPLY) fs.writeFileSync(f, nt);
  }
}

// ---- H1 header fix + git mv for survivor docs (apply only) ----
let h1fixed = 0, moved = 0;
const docsDir = path.join(REPO, 'docs');
for (const [oldName, newName] of Object.entries(survivorFiles)) {
  if (oldName === newName) continue; // 00,01,KB unchanged
  const oldPath = path.join(docsDir, oldName);
  if (!fs.existsSync(oldPath)) { console.log('MISSING survivor: ' + oldName); continue; }
  const newNum = newName.slice(0, 2);
  // fix H1 (line 1): "# 05 - X" / "# docs/05 — X" -> new number
  let text = fs.readFileSync(oldPath, 'utf8');
  const lines = text.split(/\n/);
  const before = lines[0];
  lines[0] = lines[0].replace(/^(#\s+)(docs\/)?(\d{2})\b/, (m, h, d, num) => h + newNum);
  if (lines[0] !== before) h1fixed++;
  if (APPLY) fs.writeFileSync(oldPath, lines.join('\n'));
  // git mv
  if (APPLY) {
    try { cp.execSync(`git -C "${REPO}" mv -f "docs/${oldName}" "docs/${newName}"`, { stdio: 'pipe' }); moved++; }
    catch (e) { console.log('git mv FAILED ' + oldName + ' -> ' + newName + ': ' + e.message.split('\n')[0]); }
  }
}

report.sort((a,b)=>parseInt(b)-parseInt(a));
console.log(report.join('\n'));
console.log(`\n=== ${totalRefs} refs rewritten across ${filesChanged} files; ${h1fixed} H1s fixed; ${moved} files git-mv'd (apply=${APPLY}) ===`);
