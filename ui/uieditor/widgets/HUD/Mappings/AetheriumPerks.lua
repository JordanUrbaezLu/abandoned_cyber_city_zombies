-- ACC perk mapping for the Aetherium HUD kit.
--
-- REWIRED for Abandoned Cyber City: the perk row is driven by OUR clientuimodel masks
-- (accOwnedMask / accMegaMask, pushed by _acc_lui.gsc perk_state_watch), NOT the stock
-- hudItems.perks.* models the kit shipped with (they can't carry Mega state, and our 10th
-- perk - Electric Cherry over specialty_combat_efficiency - has no stock uimodel at all).
--
-- `bit`   = the perk's bar-bit in BOTH masks. MUST match _acc_lui.gsc perk_state_watch's
--           specialties[] order (bit 8 = PhD Flopper riding the electric-cherry pipeline,
--           bit 9 = the real Electric Cherry on specialty_combat_efficiency).
-- `image` / `imageMega` = Ronan cyberpunk icons (source_data/acc_perk_shaders.gdt, already
--           zone-listed): red = base perk, teal = Mega'd - same art the retired
--           CoD.AccPerkBar used (acc_hud.lua ACC_PERK_ICONS).
-- `name` / `cost` / `description` are ALSO read by the cursor-hint prompt (PromptPerks
--           matches machine hint text against `name`) - keep names in sync with the perk
--           machines' hint strings + acc_hud.lua AccPerkCards + _acc_perk_info.
-- `clientFieldName` AND `specialty` are kept for reference only (nothing reads either after
--           the mask rewire - the bit contract lives in `bit`, NOT in specialty order).
--
-- KNOWN LIMIT (review 2026-07-03): `cost` is STATIC - the buy prompt (PromptPerks.lua) shows
-- it as-is, but the REAL charge is dynamic: The Armory (Mule Kick Mega) discounts every buy
-- 10% (_acc_perk_info::armory_discounted). An Armory holder sees e.g. 4000 here but pays
-- 3600. The kept AccPerkCard info card (acc_hud.lua) DOES show the discounted price, so the
-- correct number is on screen. TODO(acc-verify): parse the live [Cost: N] out of
-- hudItems.cursorHintText in PromptPerks if the static prompt price ever bothers players.
--
-- NOTE: The last entry should NOT have a comma ","
CoD.AetheriumPerks = {
	{
		name = "JUGGER-NOG",
		cost = 4000,
		description = "Take more hits",
		image = "i_acc_perk_jugg_base",
		imageMega = "i_acc_perk_jugg_mega",
		megaName = "Ultimate Tank",
		megaDescription = "Take even more hits",
		benefits = { "Take more hits" },
		megaBenefits = { "Take even more hits" },
		megaFullBenefits = { "Take even more hits" },
		bit = 0,
		specialty = "specialty_armorvest",
		clientFieldName = "juggernaut"
	},
	{
		name = "QUICK REVIVE",
		cost = 2500,
		description = "Revive faster, regen sooner, self-revive solo",
		image = "i_acc_perk_revive_base",
		imageMega = "i_acc_perk_revive_mega",
		megaName = "Savior",
		megaDescription = "Revive even faster, shielded while reviving",
		benefits = { "Revive allies faster", "Health regen starts sooner", "Revive yourself solo" },
		megaBenefits = { "Revive even faster", "Regen starts even sooner", "Faster when an ally is down", "Shielded while reviving" },
		megaFullBenefits = { "Revive even faster", "Regen starts even sooner", "Revive yourself solo", "Faster when an ally is down", "Shielded while reviving" },
		bit = 1,
		specialty = "specialty_quickrevive",
		clientFieldName = "quick_revive"
	},
	{
		name = "SPEED COLA",
		cost = 3500,
		description = "Reload and fix barriers faster",
		image = "i_acc_perk_speed_base",
		imageMega = "i_acc_perk_speed_mega",
		megaName = "Sleight of Hand Expert",
		megaDescription = "Reload even faster",
		benefits = { "Reload faster", "Fix barriers faster" },
		megaBenefits = { "Reload even faster" },
		megaFullBenefits = { "Reload even faster", "Fix barriers faster" },
		bit = 2,
		specialty = "specialty_fastreload",
		clientFieldName = "sleight_of_hand"
	},
	{
		name = "DOUBLE TAP 2.0",
		cost = 3000,
		description = "Fires extra bullets, shoots faster",
		image = "i_acc_perk_doubletap_base",
		imageMega = "i_acc_perk_doubletap_mega",
		megaName = "Gun Slinger",
		megaDescription = "Extra bullets hit harder",
		benefits = { "Fires extra bullets", "Shoots faster" },
		megaBenefits = { "Extra bullets hit harder" },
		megaFullBenefits = { "Fires extra bullets", "Shoots faster", "Extra bullets hit harder" },
		bit = 3,
		specialty = "specialty_doubletap2",
		clientFieldName = "doubletap2"
	},
	{
		name = "STAMIN-UP",
		cost = 2000,
		description = "Sprint longer, move faster",
		image = "i_acc_perk_staminup_base",
		imageMega = "i_acc_perk_staminup_mega",
		megaName = "The Flash",
		megaDescription = "Move even faster",
		benefits = { "Sprint longer", "Move faster" },
		megaBenefits = { "Move even faster" },
		megaFullBenefits = { "Sprint longer", "Move even faster" },
		bit = 4,
		specialty = "specialty_staminup",
		clientFieldName = "marathon"
	},
	{
		name = "MULE KICK",
		cost = 2500,
		description = "Carry an extra gun",
		image = "i_acc_perk_mule_base",
		imageMega = "i_acc_perk_mule_mega",
		megaName = "The Armory",
		megaDescription = "More ammo each round, cheaper buys",
		benefits = { "Carry an extra gun" },
		megaBenefits = { "More ammo each round", "Cheaper buys" },
		megaFullBenefits = { "Carry an extra gun", "More ammo each round", "Cheaper buys" },
		bit = 5,
		specialty = "specialty_additionalprimaryweapon",
		clientFieldName = "additional_primary_weapon"
	},
	{
		name = "DEADSHOT",
		cost = 3500,
		description = "More headshot damage, aims at the head",
		image = "i_acc_perk_deadshot_base",
		imageMega = "i_acc_perk_deadshot_mega",
		megaName = "American Sniper",
		megaDescription = "More headshot damage, much less recoil",
		benefits = { "More headshot damage", "Aims at the head" },
		megaBenefits = { "Even more headshot dmg", "Much less recoil" },
		megaFullBenefits = { "Even more headshot dmg", "Much less recoil", "Aims at the head" },
		bit = 6,
		specialty = "specialty_deadshot",
		clientFieldName = "dead_shot"
	},
	{
		name = "WIDOW'S WINE",
		cost = 4000,
		description = "Grenades trap zombies, webbing on melee",
		image = "i_acc_perk_widows_base",
		imageMega = "i_acc_perk_widows_mega",
		megaName = "Spiderman",
		megaDescription = "Scuttle fast when low, more spider drops",
		benefits = { "Grenades trap zombies", "Webbing on melee", "Refills each round" },
		megaBenefits = { "Scuttle fast when low", "More spider drops" },
		megaFullBenefits = { "Grenades trap zombies", "Webbing on melee", "Scuttle fast when low", "More spider drops" },
		bit = 7,
		specialty = "specialty_widowswine",
		clientFieldName = "widows_wine"
	},
	{
		name = "PHD FLOPPER",
		cost = 2500,
		description = "No fall or blast damage, explode when downed",
		image = "i_acc_perk_phd_base",
		imageMega = "i_acc_perk_phd_mega",
		megaName = "PhD Slider",
		megaDescription = "Slide to explode, more explosive damage",
		benefits = { "No fall or blast damage", "Explode when downed" },
		megaBenefits = { "Slide to explode", "More explosive damage", "Move faster" },
		megaFullBenefits = { "No fall or blast damage", "Slide to explode", "Explode when downed", "More explosive damage", "Move faster" },
		bit = 8,
		specialty = "specialty_electriccherry",
		clientFieldName = "electric_cherry"
	},
	{
		name = "ELECTRIC CHERRY",
		cost = 3000,
		description = "Reload to zap zombies",
		image = "i_acc_perk_cherry_base",
		imageMega = "i_acc_perk_cherry_mega",
		megaName = "Power Surge",
		megaDescription = "Stronger faster zap, shrugs off boss zaps",
		benefits = { "Reload to zap zombies", "Emptier mag = bigger zap" },
		megaBenefits = { "Stronger, faster zap", "Shrugs off boss zaps" },
		megaFullBenefits = { "Reload to zap zombies", "Emptier mag = bigger zap", "Stronger, faster zap", "Shrugs off boss zaps" },
		bit = 9,
		specialty = "specialty_combat_efficiency",
		clientFieldName = "combat_efficiency"
	}
}
