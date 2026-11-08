local _, ns = ...

-- What each trainer spell is worth to each way of its class (Specs.lua ns.InMyWays): keyed by the family's first
-- rank (what ns.Root returns); { "way"... } every rank counts for those ways, first = { "way"... } only the first rank,
-- all = true every rank for every way; a way in neither: not worth buying for it (shown apart, a click still buys
-- it). Gathered 2026-11-07 from the classic-era guides (Wowhead, Icy Veins, Warcraft Tavern) and Forever's own spells.
ns.USEFUL = ns.USEFUL or {}
local USEFUL = ns.USEFUL

-- Per-spec usefulness of the trainer spells (DRUID, SHAMAN, PALADIN).
-- Key = the family's lowest-level spell present in the class file (spellsByLevel), or the quest spell
-- (QuestSpells.lua) when that one comes earlier for every race of the class; this is what ns.Root returns.
-- Where rank 1 is known from level 1 and absent from the file (Wrath, Healing Touch, Healing Wave,
-- Lightning Bolt, Seal of Righteousness, Holy Light, Prowl, Rip, Maul...), the key is the first trainable rank
-- and `first` is never used for that family (it would mean "buy rank 2").
-- Names checked against ~/.voile-tools/forever-db2-next/SpellName.csv.

USEFUL.DRUID = {
	[1126] = { all = true }, -- Mark of the Wild
	[8921] = { "balance", "restoration", first = { "bear", "cat" } }, -- Moonfire
	[774] = { "balance", "restoration", first = { "bear", "cat" } }, -- Rejuvenation
	[467] = { all = true }, -- Thorns
	[5177] = { "balance", "restoration" }, -- Wrath (rank 1 5176 known at level 1)
	[339] = { "balance", "restoration", first = { "bear", "cat" } }, -- Entangling Roots
	[5186] = { "balance", "restoration" }, -- Healing Touch (rank 1 5185 known at level 1)
	[99] = { "bear" }, -- Demoralizing Roar
	[16689] = { "balance", first = { "bear", "cat", "restoration" } }, -- Nature's Grasp
	[5229] = { "bear" }, -- Enrage
	[8936] = { "balance", "restoration", first = { "bear", "cat" } }, -- Regrowth
	[437138] = { all = true }, -- Revive (out-of-combat resurrection, ranks 1237948-1237951)
	[5211] = { "bear", first = { "cat" } }, -- Bash
	[779] = { "bear" }, -- Swipe
	[6808] = { "bear" }, -- Maul (rank 1 6807 comes with Bear Form)
	[770] = { "balance", "restoration", first = { "bear", "cat" } }, -- Faerie Fire
	[2637] = { "balance", "restoration", first = { "bear", "cat" } }, -- Hibernate
	[2912] = { "balance", first = { "restoration" } }, -- Starfire
	[5221] = { "cat" }, -- Shred
	[20484] = { all = true }, -- Rebirth
	[16864] = { all = true }, -- Omen of Clarity
	[2908] = { first = { "balance", "bear", "cat", "restoration" } }, -- Soothe Animal
	[1822] = { "cat" }, -- Rake
	[2782] = { all = true }, -- Remove Curse
	[2893] = { all = true }, -- Abolish Poison
	[1850] = { all = true }, -- Dash
	[3029] = { "cat" }, -- Claw
	[8998] = { "cat" }, -- Cower
	[5209] = { "bear" }, -- Challenging Roar
	[9492] = { "cat" }, -- Rip (rank 1 1079 comes with Cat Form)
	[24974] = { "balance" }, -- Insect Swarm (talent)
	[740] = { "restoration", first = { "balance" } }, -- Tranquility
	[783] = { all = true }, -- Travel Form
	[22568] = { "cat" }, -- Ferocious Bite
	[6785] = { "cat" }, -- Ravage
	[5225] = { "cat" }, -- Track Humanoids
	[22842] = { "bear" }, -- Frenzied Regeneration
	[9005] = { "cat" }, -- Pounce
	[1238069] = { "bear" }, -- Primal Bite (talent, bear only)
	[9634] = { "bear", "cat" }, -- Dire Bear Form
	[20719] = { "cat" }, -- Feline Grace
	[16914] = { "balance" }, -- Hurricane
	[29166] = { all = true }, -- Innervate
	[6783] = { "cat" }, -- Prowl (rank 1 5215 comes with Cat Form)
	[414644] = { "bear" }, -- Lacerate
	[22812] = { all = true }, -- Barkskin
	[1238214] = { "restoration" }, -- Wild Growth (talent)
	[5487] = { all = true }, -- Bear Form (quest)
	[768] = { all = true }, -- Cat Form (quest)
	[18960] = { all = true }, -- Teleport: Moonglade (quest)
	[8946] = { all = true }, -- Cure Poison (quest)
	[1066] = { all = true }, -- Aquatic Form (quest)
}

USEFUL.SHAMAN = {
	[8017] = { "enhancement", first = { "elemental", "restoration" } }, -- Rockbiter Weapon
	[8042] = { "elemental", "enhancement", first = { "restoration" } }, -- Earth Shock
	[332] = { all = true }, -- Healing Wave (rank 1 331 known at level 1)
	[2484] = { all = true }, -- Earthbind Totem
	[529] = { "elemental", "restoration" }, -- Lightning Bolt (rank 1 403 known at level 1)
	[324] = { all = true }, -- Lightning Shield
	[5730] = { first = { "elemental", "enhancement", "restoration" } }, -- Stoneclaw Totem
	[8050] = { "elemental", "enhancement", first = { "restoration" } }, -- Flame Shock
	[8024] = { "enhancement", first = { "elemental", "restoration" } }, -- Flametongue Weapon
	[8075] = { all = true }, -- Strength of Earth Totem
	[2008] = { all = true }, -- Ancestral Spirit
	[408341] = { "elemental", "enhancement", first = { "restoration" } }, -- Fire Nova
	[370] = { all = true }, -- Purge
	[8071] = { all = true }, -- Stoneskin Totem (quest)
	[526] = { all = true }, -- Cure Poison
	[8143] = { all = true }, -- Tremor Totem
	[66842] = { all = true }, -- Call of the Elements
	[8056] = { "elemental", "enhancement", first = { "restoration" } }, -- Frost Shock
	[8033] = { first = { "enhancement" } }, -- Frostbrand Weapon
	[2645] = { all = true }, -- Ghost Wolf
	[8004] = { all = true }, -- Lesser Healing Wave
	[3599] = { "elemental", "enhancement", first = { "restoration" } }, -- Searing Totem (quest)
	[36936] = { all = true }, -- Totemic Recall
	[2870] = { all = true }, -- Cure Disease
	[8166] = { all = true }, -- Poison Cleansing Totem
	[437009] = { all = true }, -- Totemic Projection
	[131] = { all = true }, -- Water Breathing
	[8181] = { all = true }, -- Frost Resistance Totem
	[6196] = { all = true }, -- Far Sight
	[8190] = { "elemental", "enhancement", first = { "restoration" } }, -- Magma Totem
	[5675] = { all = true }, -- Mana Spring Totem
	[8184] = { all = true }, -- Fire Resistance Totem
	[8227] = { "enhancement", first = { "elemental", "restoration" } }, -- Flametongue Totem
	[546] = { all = true }, -- Water Walking
	[556] = { all = true }, -- Astral Recall
	[8177] = { all = true }, -- Grounding Totem
	[5394] = { all = true }, -- Healing Stream Totem (quest; 6375 for a race without the quest)
	[10595] = { all = true }, -- Nature Resistance Totem
	[20608] = { all = true }, -- Reincarnation
	[66843] = { all = true }, -- Call of the Ancestors
	[8232] = { "enhancement" }, -- Windfury Weapon
	[421] = { "elemental", first = { "enhancement", "restoration" } }, -- Chain Lightning
	[8512] = { "enhancement", "restoration", first = { "elemental" } }, -- Windfury Totem
	[6495] = { all = true }, -- Sentry Totem
	[15107] = { first = { "elemental", "enhancement", "restoration" } }, -- Windwall Totem
	[8170] = { all = true }, -- Disease Cleansing Totem
	[17354] = { "restoration" }, -- Mana Tide Totem (talent)
	[66844] = { all = true }, -- Call of the Spirits
	[1064] = { "restoration", first = { "elemental", "enhancement" } }, -- Chain Heal
	[1238299] = { "elemental" }, -- Lava Burst (talent)
	[8737] = { all = true }, -- Mail
	[8835] = { "enhancement", "restoration", first = { "elemental" } }, -- Grace of Air Totem
	[1239242] = { "restoration" }, -- Riptide (talent)
}

USEFUL.PALADIN = {
	[465] = { all = true }, -- Devotion Aura
	[19740] = { all = true }, -- Blessing of Might
	[20271] = { all = true }, -- Judgement
	[498] = { all = true }, -- Divine Protection
	[639] = { all = true }, -- Holy Light (rank 1 635 known / quest; 635 is the root for the quest race)
	[679] = { "protection", "retribution", first = { "holy" } }, -- Holy Strike
	[21082] = { all = true }, -- Seal of the Crusader
	[853] = { all = true }, -- Hammer of Justice
	[3127] = { all = true }, -- Parry
	[1152] = { all = true }, -- Purify
	[1022] = { all = true }, -- Blessing of Protection
	[633] = { all = true }, -- Lay on Hands
	[1311649] = { "protection" }, -- Seal of Fury (Forever tank seal, judgement taunts)
	[20287] = { all = true }, -- Seal of Righteousness (rank 1 20154 known at level 1)
	[19742] = { all = true }, -- Blessing of Wisdom
	[7294] = { "protection", "retribution", first = { "holy" } }, -- Retribution Aura
	[25780] = { "protection" }, -- Righteous Fury
	[1044] = { all = true }, -- Blessing of Freedom
	[20217] = { all = true }, -- Blessing of Kings
	[26573] = { "protection", "retribution", first = { "holy" } }, -- Consecration
	[879] = { all = true }, -- Exorcism
	[19750] = { all = true }, -- Flash of Light
	[19746] = { all = true }, -- Concentration Aura
	[20164] = { all = true }, -- Seal of Justice
	[10322] = { all = true }, -- Redemption (rank 1 7328 by quest for some races)
	[2878] = { all = true }, -- Turn Undead
	[1038] = { all = true }, -- Salvation (Blessing of Salvation)
	[19876] = { all = true }, -- Shadow Resistance Aura
	[19752] = { all = true }, -- Divine Intervention
	[20165] = { all = true }, -- Seal of Light
	[20915] = { "retribution" }, -- Seal of Command (talent)
	[642] = { all = true }, -- Divine Shield
	[19888] = { all = true }, -- Frost Resistance Aura
	[19891] = { all = true }, -- Fire Resistance Aura
	[20166] = { all = true }, -- Seal of Wisdom
	[19977] = { all = true }, -- Blessing of Light
	[20473] = { "holy" }, -- Holy Shock (talent)
	[750] = { all = true }, -- Plate Mail
	[4987] = { all = true }, -- Cleanse
	[24275] = { "protection", "retribution", first = { "holy" } }, -- Hammer of Wrath
	[6940] = { all = true }, -- Blessing of Sacrifice
	[2812] = { "protection", "retribution", first = { "holy" } }, -- Holy Wrath
	[20927] = { "protection" }, -- Holy Shield (talent)
	[1311590] = { "holy" }, -- Light's Vigil (Forever holy talent)
	[25782] = { all = true }, -- Greater Blessing of Might
	[25894] = { all = true }, -- Greater Blessing of Wisdom
	[25890] = { all = true }, -- Greater Blessing of Light
	[25895] = { all = true }, -- Mass Salvation
	[25898] = { all = true }, -- Greater Blessing of Kings
	[5502] = { all = true }, -- Sense Undead (quest)
	[13819] = { all = true }, -- Summon Warhorse (quest)
	[23214] = { all = true }, -- Summon Charger (quest)
}

-- Keys = the first rank as ns.Root finds it (lowest level in the class file, quest spells included).
-- Quest-taught spells (free) are listed too, all = true, so every name the Roots map can return is covered.

USEFUL.WARRIOR = {
	[6673] = { all = true }, -- Battle Shout
	[100] = { all = true }, -- Charge (ranks add rage)
	[772] = { "arms", first = { "fury", "protection" } }, -- Rend
	[6343] = { "protection", first = { "arms", "fury" } }, -- Thunder Clap
	[1715] = { first = { "arms", "fury", "protection" } }, -- Hamstring (ranks add damage only)
	[284] = { all = true }, -- Heroic Strike (78 is the starting rank, not in the file)
	[7384] = { "arms", "fury", first = { "protection" } }, -- Overpower
	[72] = { "protection", first = { "arms", "fury" } }, -- Shield Bash
	[1160] = { all = true }, -- Demoralizing Shout
	[6572] = { "protection" }, -- Revenge
	[694] = { first = { "protection" } }, -- Mocking Blow
	[845] = { all = true }, -- Cleave
	[1240193] = { "arms", "fury" }, -- Slam (Forever rank 1 at 20)
	[7386] = { all = true }, -- Sunder Armor (quest, level 10)
	[5308] = { "arms", "fury", first = { "protection" } }, -- Execute
	[6552] = { first = { "arms", "fury", "protection" } }, -- Pummel (rank 2 adds damage only)
	[20252] = { first = { "arms", "fury", "protection" } }, -- Intercept (quest, level 30; ranks add damage only)
	[23892] = { "fury" }, -- Bloodthirst
	[21551] = { "arms" }, -- Mortal Strike
	[23923] = { "protection" }, -- Shield Slam
	[3127] = { all = true }, -- Parry
	[2687] = { all = true }, -- Bloodrage
	[1310185] = { all = true }, -- Tactical Mastery (Forever, trained at 14)
	[2565] = { "protection" }, -- Shield Block
	[676] = { all = true }, -- Disarm
	[674] = { "fury", "protection" }, -- Dual Wield
	[20230] = { all = true }, -- Retaliation
	[402927] = { all = true }, -- Victory Rush
	[5246] = { all = true }, -- Intimidating Shout
	[1161] = { "protection" }, -- Challenging Shout
	[871] = { "protection" }, -- Shield Wall
	[18499] = { all = true }, -- Berserker Rage
	[1680] = { "arms", "fury" }, -- Whirlwind
	[750] = { all = true }, -- Plate Mail
	[1719] = { "arms", "fury" }, -- Recklessness
	[71] = { all = true }, -- Defensive Stance (quest)
	[355] = { all = true }, -- Taunt (quest)
	[2458] = { all = true }, -- Berserker Stance (quest)
}

USEFUL.ROGUE = {
	[1784] = { all = true }, -- Stealth
	[53] = { "assassination", "subtlety" }, -- Backstab
	[1776] = { first = { "assassination", "combat", "subtlety" } }, -- Gouge (ranks add damage only)
	[1757] = { "assassination", "combat", first = { "subtlety" } }, -- Sinister Strike (1752 is the starting rank)
	[6760] = { all = true }, -- Eviscerate (2098 is the starting rank)
	[6770] = { all = true }, -- Sap (ranks add duration)
	[5171] = { all = true }, -- Slice and Dice
	[2983] = { all = true }, -- Sprint
	[1766] = { first = { "assassination", "combat", "subtlety" } }, -- Kick (ranks add damage only)
	[8647] = { "assassination", first = { "combat", "subtlety" } }, -- Expose Armor
	[703] = { "assassination", "subtlety", first = { "combat" } }, -- Garrote
	[1966] = { all = true }, -- Feint
	[8676] = { "assassination", "subtlety" }, -- Ambush
	[3420] = { first = { "assassination", "combat", "subtlety" } }, -- Crippling Poison
	[1943] = { "assassination", "subtlety", first = { "combat" } }, -- Rupture
	[1856] = { all = true }, -- Vanish
	[5763] = { first = { "assassination", "combat", "subtlety" } }, -- Mind-numbing Poison
	[8687] = { all = true }, -- Instant Poison
	[2835] = { all = true }, -- Deadly Poison
	[408] = { all = true }, -- Kidney Shot (rank 2 = longer stun)
	[13220] = { first = { "assassination", "combat", "subtlety" } }, -- Wound Poison
	[399956] = { "assassination" }, -- Mutilate
	[921] = { all = true }, -- Pick Pocket
	[5277] = { all = true }, -- Evasion
	[674] = { all = true }, -- Dual Wield
	[3127] = { all = true }, -- Parry
	[1804] = { all = true }, -- Pick Lock
	[1725] = { all = true }, -- Distract
	[2836] = { all = true }, -- Detect Traps
	[1842] = { all = true }, -- Disarm Trap
	[1833] = { all = true }, -- Cheap Shot
	[2094] = { all = true }, -- Blind
	[6510] = { all = true }, -- Blinding Powder
	[1860] = { all = true }, -- Safe Fall
	[2842] = { all = true }, -- Poisons (quest)
}

USEFUL.HUNTER = {
	[1494] = { all = true }, -- Track Beasts
	[13163] = { all = true }, -- Aspect of the Monkey
	[1978] = { all = true }, -- Serpent Sting
	[3044] = { all = true }, -- Arcane Shot
	[1130] = { all = true }, -- Hunter's Mark
	[5116] = { all = true }, -- Concussive Shot
	[3127] = { all = true }, -- Parry
	[14260] = { all = true }, -- Raptor Strike (2973 is the starting rank)
	[13165] = { all = true }, -- Aspect of the Hawk
	[19883] = { all = true }, -- Track Humanoids
	[4187] = { all = true }, -- Great Stamina (pet skill)
	[24545] = { all = true }, -- Natural Armor (pet skill)
	[20736] = { first = { "beast", "marks", "survival" } }, -- Distracting Shot
	[136] = { all = true }, -- Mend Pet
	[2974] = { first = { "beast", "marks", "survival" } }, -- Wing Clip (ranks add damage only)
	[6197] = { all = true }, -- Eagle Eye
	[1002] = { all = true }, -- Eyes of the Beast
	[1513] = { first = { "beast", "marks", "survival" } }, -- Scare Beast
	[13795] = { all = true }, -- Immolation Trap
	[1495] = { "survival", first = { "beast", "marks" } }, -- Mongoose Bite
	[2643] = { all = true }, -- Multi-Shot
	[19884] = { all = true }, -- Track Undead
	[19434] = { "marks" }, -- Aimed Shot (trainer-taught in Forever, Marksmanship category)
	[5118] = { all = true }, -- Aspect of the Cheetah
	[781] = { "survival", first = { "beast", "marks" } }, -- Disengage
	[674] = { all = true }, -- Dual Wield
	[1499] = { all = true }, -- Freezing Trap (ranks add duration)
	[24493] = { all = true }, -- Arcane Resistance (pet skill)
	[23992] = { all = true }, -- Fire Resistance (pet skill)
	[24446] = { all = true }, -- Frost Resistance (pet skill)
	[14917] = { all = true }, -- Growl (pet skill; lower ranks are innate)
	[24492] = { all = true }, -- Nature Resistance (pet skill)
	[24488] = { all = true }, -- Shadow Resistance (pet skill)
	[3043] = { all = true }, -- Scorpid Sting
	[1462] = { all = true }, -- Beast Lore
	[19885] = { all = true }, -- Track Hidden
	[3045] = { all = true }, -- Rapid Fire
	[19880] = { all = true }, -- Track Elementals
	[13809] = { all = true }, -- Frost Trap
	[13161] = { "survival", first = { "beast", "marks" } }, -- Aspect of the Beast (Forever ranks 1299445-7 add melee AP)
	[1242634] = { "survival" }, -- Counterattack (talent; Forever rank at 30, 20909 later)
	[5384] = { all = true }, -- Feign Death
	[1543] = { all = true }, -- Flare
	[19878] = { all = true }, -- Track Demons
	[1299348] = { "marks" }, -- Trueshot Aura (talent; Forever rank at 32, 19506 later)
	[13813] = { all = true }, -- Explosive Trap
	[1293525] = { "beast" }, -- Summon Hawk (Beast Mastery talent)
	[3034] = { first = { "beast", "marks", "survival" } }, -- Viper Sting
	[13159] = { all = true }, -- Aspect of the Pack
	[8737] = { all = true }, -- Mail
	[19882] = { all = true }, -- Track Giants
	[1510] = { all = true }, -- Volley
	[1310785] = { "marks" }, -- Sniper Shot (Marksmanship talent)
	[20043] = { all = true }, -- Aspect of the Wild
	[19879] = { all = true }, -- Track Dragonkin
	[1515] = { all = true }, -- Tame Beast (quest)
	[5149] = { all = true }, -- Beast Training (quest)
	[883] = { all = true }, -- Call Pet (quest)
	[2641] = { all = true }, -- Dismiss Pet (quest)
	[6991] = { all = true }, -- Feed Pet (quest)
	[982] = { all = true }, -- Revive Pet (quest)
}

USEFUL.MAGE = {
	[1459] = { all = true }, -- Arcane Intellect
	[5504] = { all = true }, -- Conjure Water
	[116] = { "frost", "arcane", first = { "fire" } }, -- Frostbolt
	[1296017] = { all = true }, -- Comprehend Scroll
	[587] = { all = true }, -- Conjure Food
	[2136] = { all = true }, -- Fire Blast
	[143] = { "fire", first = { "frost", "arcane" } }, -- Fireball
	[5143] = { all = true }, -- Arcane Missiles
	[118] = { all = true }, -- Polymorph
	[7300] = { all = true }, -- Frost Armor
	[122] = { all = true }, -- Frost Nova
	[604] = { first = { "arcane", "fire", "frost" } }, -- Dampen Magic
	[130] = { all = true }, -- Slow Fall
	[1449] = { all = true }, -- Arcane Explosion
	[2120] = { "fire", "frost", first = { "arcane" } }, -- Flamestrike
	[1008] = { first = { "arcane", "fire", "frost" } }, -- Amplify Magic
	[475] = { all = true }, -- Remove Lesser Curse
	[1953] = { all = true }, -- Blink
	[10] = { "frost", "arcane", first = { "fire" } }, -- Blizzard
	[12051] = { all = true }, -- Evocation
	[543] = { all = true }, -- Fire Ward
	[1463] = { all = true }, -- Mana Shield
	[3561] = { all = true }, -- Teleport: Stormwind
	[3562] = { all = true }, -- Teleport: Ironforge
	[3563] = { all = true }, -- Teleport: Undercity
	[3567] = { all = true }, -- Teleport: Orgrimmar
	[6143] = { all = true }, -- Frost Ward
	[2948] = { "fire" }, -- Scorch
	[2139] = { all = true }, -- Counterspell
	[1326053] = { "frost", "arcane", first = { "fire" } }, -- Frost Blast
	[12505] = { "fire" }, -- Pyroblast (talent)
	[120] = { "frost", first = { "arcane", "fire" } }, -- Cone of Cold
	[759] = { all = true }, -- Conjure Mana Agate
	[400640] = { "frost" }, -- Ice Lance (talent)
	[1239696] = { "arcane" }, -- Arcane Blast (talent)
	[7302] = { all = true }, -- Ice Armor
	[3565] = { all = true }, -- Teleport: Darnassus
	[3566] = { all = true }, -- Teleport: Thunder Bluff
	[6117] = { all = true }, -- Mage Armor
	[1326080] = { "arcane" }, -- Arcane Wrath (talent)
	[13018] = { "fire" }, -- Blast Wave (talent)
	[3552] = { all = true }, -- Conjure Mana Jade
	[401502] = { "fire", "frost", first = { "arcane" } }, -- Frostfire Bolt
	[10059] = { all = true }, -- Portal: Stormwind
	[11416] = { all = true }, -- Portal: Ironforge
	[11417] = { all = true }, -- Portal: Orgrimmar
	[11418] = { all = true }, -- Portal: Undercity
	[13031] = { "frost" }, -- Ice Barrier (talent)
	[10053] = { all = true }, -- Conjure Mana Citrine
	[11419] = { all = true }, -- Portal: Darnassus
	[11420] = { all = true }, -- Portal: Thunder Bluff
	[10054] = { all = true }, -- Conjure Mana Ruby
}

USEFUL.WARLOCK = {
	[348] = { all = true }, -- Immolate
	[172] = { all = true }, -- Corruption
	[702] = { first = { "affliction", "demonology", "destruction" } }, -- Curse of Weakness
	[1454] = { all = true }, -- Life Tap
	[695] = { all = true }, -- Shadow Bolt
	[980] = { all = true }, -- Bane of Agony
	[5782] = { all = true }, -- Fear
	[6201] = { all = true }, -- Create Healthstone
	[696] = { all = true }, -- Demon Skin
	[1120] = { "affliction", first = { "demonology", "destruction" } }, -- Drain Soul
	[755] = { all = true }, -- Health Funnel
	[704] = { all = true }, -- Curse of Recklessness
	[689] = { all = true }, -- Drain Life
	[5697] = { all = true }, -- Unending Breath
	[693] = { all = true }, -- Create Soulstone
	[5676] = { "destruction", first = { "affliction", "demonology" } }, -- Searing Pain
	[440892] = { all = true }, -- Curse of the Elements
	[706] = { all = true }, -- Demon Armor
	[5740] = { all = true }, -- Rain of Fire
	[698] = { all = true }, -- Ritual of Summoning
	[126] = { all = true }, -- Eye of Kilrogg
	[5138] = { first = { "affliction", "demonology", "destruction" } }, -- Drain Mana
	[5500] = { all = true }, -- Sense Demons
	[18867] = { "destruction" }, -- Shadowburn (talent)
	[1714] = { first = { "affliction", "demonology", "destruction" } }, -- Curse of Tongues
	[132] = { first = { "affliction", "demonology", "destruction" } }, -- Detect Invisibility
	[710] = { all = true }, -- Banish
	[6366] = { "destruction", first = { "affliction", "demonology" } }, -- Create Firestone
	[1949] = { all = true }, -- Hellfire
	[1098] = { all = true }, -- Subjugate Demon
	[1293818] = { "destruction" }, -- Conflagrate (talent)
	[6229] = { all = true }, -- Shadow Ward
	[2362] = { all = true }, -- Create Spellstone
	[18879] = { "affliction" }, -- Siphon Life (talent)
	[5484] = { all = true }, -- Howl of Terror
	[6789] = { all = true }, -- Death Coil
	[6353] = { "destruction", first = { "affliction", "demonology" } }, -- Soul Fire
	[1293812] = { "destruction" }, -- Incinerate (talent)
	[603] = { all = true }, -- Bane of Doom
}

USEFUL.PRIEST = {
	[1243] = { all = true }, -- Power Word: Fortitude
	[2052] = { all = true }, -- Lesser Heal
	[589] = { all = true }, -- Shadow Word: Pain
	[17] = { all = true }, -- Power Word: Shield
	[591] = { "discipline", "holy", first = { "shadow" } }, -- Smite
	[586] = { all = true }, -- Fade
	[139] = { all = true }, -- Renew
	[8092] = { all = true }, -- Mind Blast
	[2006] = { "discipline", "holy", first = { "shadow" } }, -- Resurrection
	[588] = { all = true }, -- Inner Fire
	[528] = { all = true }, -- Cure Disease
	[8122] = { all = true }, -- Psychic Scream
	[2054] = { "discipline", "holy", first = { "shadow" } }, -- Heal
	[527] = { all = true }, -- Dispel Magic
	[1277371] = { "discipline", "holy", first = { "shadow" } }, -- Divine Grace (Human)
	[19236] = { all = true }, -- Desperate Prayer (racial)
	[19296] = { all = true }, -- Starshards (Night Elf)
	[2944] = { all = true }, -- Devouring Plague
	[6346] = { all = true }, -- Fear Ward
	[2061] = { all = true }, -- Flash Heal
	[14914] = { "discipline", "holy", first = { "shadow" } }, -- Holy Fire
	[453] = { all = true }, -- Mind Soothe
	[9484] = { all = true }, -- Shackle Undead
	[19261] = { all = true }, -- Touch of Weakness (racial)
	[19281] = { all = true }, -- Hex of Weakness (racial)
	[2096] = { first = { "discipline", "holy", "shadow" } }, -- Mind Vision
	[8129] = { "shadow", first = { "discipline", "holy" } }, -- Mana Burn
	[15430] = { "holy", "discipline" }, -- Holy Nova (talent)
	[17311] = { "shadow" }, -- Mind Flay (talent)
	[19308] = { all = true }, -- Shadowguard (racial)
	[14752] = { all = true }, -- Divine Spirit
	[19271] = { all = true }, -- Feedback (racial)
	[605] = { all = true }, -- Mind Control
	[596] = { "holy", "discipline" }, -- Prayer of Healing
	[976] = { all = true }, -- Shadow Protection
	[1277325] = { all = true }, -- Dark Sacrifice (Undead)
	[1277332] = { all = true }, -- Chastise (Dwarf)
	[1277634] = { all = true }, -- Contingency Plan (Gnome)
	[552] = { all = true }, -- Abolish Disease
	[1240770] = { "holy", "discipline" }, -- Binding Heal (talent)
	[1309595] = { "shadow", "discipline", first = { "holy" } }, -- Shadow Word: Death
	[1706] = { all = true }, -- Levitate
	[2060] = { "holy", "discipline" }, -- Greater Heal
	[1240720] = { "discipline", "holy" }, -- Penance (talent)
	[1240826] = { "holy", "discipline" }, -- Prayer of Mending (talent)
	[27681] = { all = true }, -- Prayer of Spirit
}

