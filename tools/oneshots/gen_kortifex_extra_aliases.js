#!/usr/bin/env node
// =============================================================================
// gen_kortifex_extra_aliases.js - emit sound/aliases/acc_kortifex_extra.csv:
// OUR alias rows for the Kortifex pack wavs the shipped west CSV leaves unwired
// (medals / boss roar / random perk / eliminations / down-revive quips / taunts).
//
// The pack ([West] Kortifex Announcer, westchief596) only aliases 12 of its 46
// wavs - the stock vox_zmba_* announcer overrides. This tool aliases 26 more so
// _acc_kortifex.gsc can play them through the SAME stock announcer registry
// (zm_audio::sndAnnouncerVoxAdd prefixes "vox_zmba_", so every name below starts
// with that). Rows are CLONED from a pack row (same 102-col layout, UIN_MOD
// template, 90/90 vol, Pauseable yes) - only Name + FileSpec change, so the
// mix/behavior exactly matches the pack's own announcer lines.
//
// UNWIRED ON PURPOSE (6): timerfrozen, cranked, timeextended, gungame (Vanguard
// mode-specific), maxarmor (no armor system), ammomod (no AAT system).
//
// Idempotent - regenerates the whole file. Usage:
//   node tools/oneshots/gen_kortifex_extra_aliases.js
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const REPO = path.resolve(__dirname, '..', '..');
const OUT = path.join(REPO, 'sound', 'aliases', 'acc_kortifex_extra.csv');
const W = 'west\\ann\\kortifex\\';   // FileSource root (tools-root sound_assets\)

// Cloned verbatim from the pack's vox_zmba_powerup_maxammo_0 row (102 cols):
// col1 Name, col4 FileSpec, col7 Template UIN_MOD, col18/19 Vol 90/90, col68 Pauseable yes.
const TEMPLATE = 'NAME,,,FILE,,,UIN_MOD,,,,,,,,,,,90,90,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,yes,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,';

const HEADER = 'Name,Behavior,Storage,FileSpec,FileSpecSustain,FileSpecRelease,Template,Loadspec,Secondary,SustainAlias,ReleaseAlias,Bus,VolumeGroup,DuckGroup,Duck,ReverbSend,CenterSend,VolMin,VolMax,DistMin,DistMaxDry,DistMaxWet,DryMinCurve,DryMaxCurve,WetMinCurve,WetMaxCurve,LimitCount,LimitType,EntityLimitCount,EntityLimitType,PitchMin,PitchMax,PriorityMin,PriorityMax,PriorityThresholdMin,PriorityThresholdMax,AmplitudePriority,PanType,Pan,Futz,Looping,RandomizeType,Probability,StartDelay,EnvelopMin,EnvelopMax,EnvelopPercent,OcclusionLevel,IsBig,DistanceLpf,FluxType,FluxTime,Subtitle,Doppler,ContextType,ContextValue,ContextType1,ContextValue1,ContextType2,ContextValue2,ContextType3,ContextValue3,Timescale,IsMusic,IsCinematic,FadeIn,FadeOut,Pauseable,StopOnEntDeath,Compression,StopOnPlay,DopplerScale,FutzPatch,VoiceLimit,IgnoreMaxDist,NeverPlayTwice,ContinuousPan,FileSource,FileSourceSustain,FileSourceRelease,FileTarget,FileTargetSustain,FileTargetRelease,Platform,Language,OutputDevices,PlatformMask,WiiUMono,StopAlias,DistanceLpfMin,DistanceLpfMax,FacialAnimationName,RestartContextLoops,SilentInCPZ,ContextFailsafe,GPAD,GPADOnly,MuteVoice,MuteMusic,RowSourceFileName,RowSourceShortName,RowSourceLineNumber';

// [ alias-name (must be vox_zmba_ + the suffix GSC registers), wav basename ]
const ROWS = [
  // multikill / streak medals (played by _acc_kortifex medal engine)
  ['vox_zmba_acc_medal_carnage_0',       'zm_cmcp_cann_zann_amcr_carnage.wav'],
  ['vox_zmba_acc_medal_slaughter_0',     'zm_cmcp_cann_zann_amsl_slaughter.wav'],
  ['vox_zmba_acc_medal_butcher_0',       'zm_cmcp_cann_zann_ambt_butcher.wav'],
  ['vox_zmba_acc_medal_massacre_0',      'zm_cmcp_cann_zann_amms_massacre.wav'],
  ['vox_zmba_acc_medal_bloodbath_0',     'zm_cmcp_cann_zann_ambl_bloodbath.wav'],
  ['vox_zmba_acc_medal_extermination_0', 'zm_cmcp_cann_zann_amex_extermination.wav'],
  ['vox_zmba_acc_medal_bigbang_0',       'zm_cmcp_cann_zann_ambg_bigbang.wav'],
  ['vox_zmba_acc_medal_excessive_0',     'zm_cmcp_cann_zann_amef_excessiveforce.wav'],
  ['vox_zmba_acc_medal_deadeye_0',       'zm_cmcp_cann_zann_amde_deadeye.wav'],
  ['vox_zmba_acc_medal_jackrabbit_0',    'zm_cmcp_cann_zann_amjr_jackrabbit.wav'],
  // boss arrival roar (2nd+ boss spawn of a round; 1st plays the dogstart sendoffs)
  ['vox_zmba_acc_roar_0',                'zm_cmcp_cann_zann_aror_painedangryroar.wav'],
  // random perk (emergency drop / glitch altar give_random_perk)
  ['vox_zmba_acc_random_perk_0',         'zm_cmcp_cann_zann_aprp_randomperk.wav'],
  // player bleed-out
  ['vox_zmba_acc_elim_0',                'zm_cmcp_cann_zann_aelm_playereliminated.wav'],
  ['vox_zmba_acc_elim_1',                'zm_cmcp_cann_zann_aelm_elimination.wav'],
  // down / revive quips
  ['vox_zmba_acc_down_0',                'zm_cmcp_cann_zann_ahpw_naughty.wav'],
  ['vox_zmba_acc_down_1',                'zm_cmcp_cann_zann_ahpw_naughtyornice.wav'],
  ['vox_zmba_acc_revive_0',              'zm_cmcp_cann_zann_ahpw_nice.wav'],
  // round-start taunt pool (holiday VG event lines - Kortifex's sardonic flavor)
  ['vox_zmba_acc_taunt_0',  'zm_cmcp_cann_krtx_ahtn_ihaveagiftforallofyo.wav'],
  ['vox_zmba_acc_taunt_1',  'zm_cmcp_cann_krtx_ahtn_itsthatmagicaltimeof.wav'],
  ['vox_zmba_acc_taunt_2',  'zm_cmcp_cann_krtx_ahtn_seasonsbeatingsmorta.wav'],
  ['vox_zmba_acc_taunt_3',  'zm_cmcp_cann_krtx_ahtn_spendyourholidayswit.wav'],
  ['vox_zmba_acc_taunt_4',  'zm_cmcp_cann_krtx_ahtn_theholidayseasonaper.wav'],
  ['vox_zmba_acc_taunt_5',  'zm_cmcp_cann_krtx_ahtn_vonlistcallsthistime.wav'],
  ['vox_zmba_acc_taunt_6',  'zm_cmcp_cann_krtx_ahtn_youllbehomeforthehol.wav'],
  ['vox_zmba_acc_taunt_7',  'zm_cmcp_cann_krtx_ahtn_youllfindnosilentnig.wav'],
  ['vox_zmba_acc_taunt_8',  'zm_cmcp_cann_zann_ahst_jinglehells.wav'],
  ['vox_zmba_acc_taunt_9',  'zm_cmcp_cann_zann_ahst_someonesbeennaughtyt.wav'],
  ['vox_zmba_acc_taunt_10', 'zm_cmcp_cann_zann_ahst_thinkyoureonthenicel.wav'],
  ['vox_zmba_acc_taunt_11', 'zm_cmcp_cann_zann_ahpw_hohoho.wav'],
];

const nCols = HEADER.split(',').length;
const lines = [HEADER, '', '#Kortifex Announcer - ACC extra lines (see _acc_kortifex.gsc)'];
for (const [name, wav] of ROWS) {
  const row = TEMPLATE.replace('NAME', name).replace('FILE', W + wav);
  const got = row.split(',').length;
  if (got !== nCols) { console.error(`FATAL: ${name} row has ${got} cols, header has ${nCols}`); process.exit(1); }
  lines.push(row);
}
fs.writeFileSync(OUT, lines.join('\n') + '\n');
console.log(`wrote ${ROWS.length} alias rows (${nCols} cols each) -> ${OUT}`);
