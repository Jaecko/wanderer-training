local _, ns = ...
local L = ns.L

-- What you play, to count what is worth buying: one or more ways of your class (a branch of its talents; the
-- feral druid's bear and cat apart), chosen by you and kept for this character. Never a wall: a spell of another
-- way is shown apart, can be bought, and counted if you say so. Most spells serve every way (healing, utility,
-- the spells every level asks for); only those of one way are said below. A spell nobody named (some of Forever's
-- own) is for everyone.

local W = Wanderer

-- The ways of each class: its key, its talent tree, and the words that name it (Wanderer's branch names).
ns.WAYS = {
	WARRIOR = { { key = "arms", tree = 1, branch = "ARMS" }, { key = "fury", tree = 2, branch = "FURY" },
		{ key = "protection", tree = 3, branch = "PROTECTION" } },
	PALADIN = { { key = "holy", tree = 1, branch = "HOLY" }, { key = "protection", tree = 2, branch = "PROTECTION" },
		{ key = "retribution", tree = 3, branch = "RETRIBUTION" } },
	HUNTER = { { key = "beast", tree = 1, branch = "BEAST_MASTERY" }, { key = "marks", tree = 2, branch = "MARKSMANSHIP" },
		{ key = "survival", tree = 3, branch = "SURVIVAL" } },
	ROGUE = { { key = "assassination", tree = 1, branch = "ASSASSINATION" }, { key = "combat", tree = 2, branch = "COMBAT" },
		{ key = "subtlety", tree = 3, branch = "SUBTLETY" } },
	PRIEST = { { key = "discipline", tree = 1, branch = "DISCIPLINE" }, { key = "holy", tree = 2, branch = "HOLY" },
		{ key = "shadow", tree = 3, branch = "SHADOW" } },
	SHAMAN = { { key = "elemental", tree = 1, branch = "ELEMENTAL" }, { key = "enhancement", tree = 2, branch = "ENHANCEMENT" },
		{ key = "restoration", tree = 3, branch = "RESTORATION" } },
	MAGE = { { key = "arcane", tree = 1, branch = "ARCANE" }, { key = "fire", tree = 2, branch = "FIRE" },
		{ key = "frost", tree = 3, branch = "FROST" } },
	WARLOCK = { { key = "affliction", tree = 1, branch = "AFFLICTION" }, { key = "demonology", tree = 2, branch = "DEMONOLOGY" },
		{ key = "destruction", tree = 3, branch = "DESTRUCTION" } },
	DRUID = { { key = "balance", tree = 1, branch = "BALANCE" }, { key = "bear", tree = 2, branch = "FERAL", scale = "BEAR" },
		{ key = "cat", tree = 2, branch = "FERAL", scale = "CAT" }, { key = "restoration", tree = 3, branch = "RESTORATION" } },
}

-- The spells of one way (or a few) only, by their first rank: every later rank follows it.
ns.ONLY = {
	MAGE = {
		[116] = { "frost" }, [10] = { "frost" }, [120] = { "frost" }, [13031] = { "frost" }, [400640] = { "frost" }, -- Frostbolt, Blizzard, Cone of Cold, Ice Barrier, Ice Lance
		[143] = { "fire" }, [2948] = { "fire" }, [2120] = { "fire" }, [12505] = { "fire" }, [13018] = { "fire" }, -- Fireball, Scorch, Flamestrike, Pyroblast, Blast Wave
		[401502] = { "fire", "frost" }, -- Frostfire Bolt
		[5143] = { "arcane" }, -- Arcane Missiles
	},
	DRUID = {
		[2912] = { "balance" }, [16914] = { "balance" }, [24974] = { "balance" }, -- Starfire, Hurricane, Insect Swarm
		[99] = { "bear" }, [5229] = { "bear" }, [5211] = { "bear" }, [779] = { "bear" }, [6808] = { "bear" }, [6807] = { "bear" }, -- Demoralizing Roar, Enrage, Bash, Swipe, Maul
		[5209] = { "bear" }, [22842] = { "bear" }, [9634] = { "bear" }, [414644] = { "bear" }, -- Challenging Roar, Frenzied Regeneration, Dire Bear Form, Lacerate
		[5221] = { "cat" }, [1822] = { "cat" }, [1850] = { "cat" }, [3029] = { "cat" }, [1082] = { "cat" }, [8998] = { "cat" }, -- Shred, Rake, Dash, Claw, Cower
		[9492] = { "cat" }, [1079] = { "cat" }, [22568] = { "cat" }, [6785] = { "cat" }, [5225] = { "cat" }, [9005] = { "cat" }, -- Rip, Ferocious Bite, Ravage, Track Humanoids, Pounce
		[6783] = { "cat" }, [5215] = { "cat" }, [20719] = { "cat" }, [5217] = { "cat" }, -- Prowl, Feline Grace, Tiger's Fury
		[740] = { "restoration" }, -- Tranquility
	},
	HUNTER = { [19434] = { "marks" }, [19506] = { "marks" }, [20909] = { "survival" } }, -- Aimed Shot, Trueshot Aura, Counterattack
	PALADIN = { [25780] = { "protection" }, [20927] = { "protection" }, [20473] = { "holy" }, [20915] = { "retribution" } }, -- Righteous Fury, Holy Shield, Holy Shock, Seal of Command
	PRIEST = { [17311] = { "shadow" }, [596] = { "holy", "discipline" }, [2060] = { "holy", "discipline" }, [15430] = { "holy" } }, -- Mind Flay, Prayer of Healing, Greater Heal, Holy Nova
	ROGUE = { [399956] = { "assassination" }, [53] = { "assassination", "subtlety" }, [8676] = { "assassination", "subtlety" } }, -- Mutilate, Backstab, Ambush
	SHAMAN = { [8232] = { "enhancement" }, [1064] = { "restoration" }, [17354] = { "restoration" } }, -- Windfury Weapon, Chain Heal, Mana Tide Totem
	WARLOCK = { [18879] = { "affliction" }, [17962] = { "destruction" }, [18867] = { "destruction" }, [6353] = { "destruction" } }, -- Siphon Life, Conflagrate, Shadowburn, Soul Fire
	WARRIOR = { [21551] = { "arms" }, [23892] = { "fury" }, [23923] = { "protection" }, [6572] = { "protection" }, -- Mortal Strike, Bloodthirst, Shield Slam, Revenge
		[2565] = { "protection" }, [871] = { "protection" } }, -- Shield Block, Shield Wall
}

function ns.Ways() return ns.WAYS[ns.class] or {} end

-- A way's name in your language (Wanderer's words: "Fire", "Feral Combat (bear)").
function ns.WayName(way)
	local name = L["BRANCH_" .. way.branch]
	if way.scale then name = L.UPGRADE_SCALE_IN:format(name, L["UPGRADE_SCALE_" .. way.scale]) end
	return name
end

-- The ways chosen for this character ({ key = true }), or nil: not chosen yet (everything counts meanwhile).
function ns.Chosen()
	local db = ns.DB()
	if db.ways and next(db.ways) then return db.ways end
	return nil
end

-- A way taken or left (none left: everything counts again).
function ns.ToggleWay(key)
	local db = ns.DB()
	db.ways = db.ways or {}
	if db.ways[key] then
		db.ways[key] = nil
	else
		db.ways[key] = true
	end
	ns.Changed()
end

-- What Wanderer already knows of what you play (your choice there, never a guess): its ways, when it names
-- one branch (or the bear, the cat); nil when it names several at once or nothing.
function ns.FromPlayChoice()
	if not (W and W.PlayChoice and W.PlayChoices) then return nil end
	local id = W.PlayChoice()
	if not id then return nil end
	for _, choice in ipairs(W.PlayChoices()) do
		if choice.id == id and choice.label:find(" / ", 1, true) then return nil end
	end
	local branch, scale = tostring(id):match("^(%d+):?(%a*)$")
	branch = tonumber(branch)
	if not branch then return nil end
	local ways = {}
	for _, way in ipairs(ns.Ways()) do
		if way.tree == branch and (scale == "" or way.scale == scale) then ways[way.key] = true end
	end
	return next(ways) and ways or nil
end

-- (a first look: Wanderer's choice, when it names your way)
function ns.SeedWays()
	local db = ns.DB()
	if db.ways or db.waysSeeded then return end
	db.waysSeeded = true
	db.ways = ns.FromPlayChoice()
end

-- The first rank of a spell: earlier ranks followed (a required spell of the same name), the same for every rank.
local roots = {}
function ns.Root(spell)
	local id = spell.id
	if roots[id] then return roots[id] end
	local root, current, steps = id, spell, 0
	-- (the names not loaded yet: the spell itself for now, asked again later)
	if not (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) then return id end
	while current and current.requiredIds and steps < 30 do
		local name = C_Spell.GetSpellName(current.id)
		local before
		for _, required in ipairs(current.requiredIds) do
			local other = ns.byId[required]
			if other and name and C_Spell.GetSpellName(required) == name then before = other end
		end
		if not before then break end
		root, current, steps = before.id, before, steps + 1
	end
	roots[id] = root
	return root
end

-- The ways a spell serves: { key = true }, or nil for every way.
function ns.SpellWays(spell)
	local only = ns.ONLY[ns.class]
	local root = ns.Root(spell)
	local list = only and (only[root] or only[spell.id])
	if not list then return nil end
	local ways = {}
	for _, key in ipairs(list) do ways[key] = true end
	return ways
end

-- Whether a spell is of what you play (everything, before any choice).
function ns.InMyWays(spell)
	local chosen = ns.Chosen()
	local ways = ns.SpellWays(spell)
	if not (chosen and ways) then return true end
	for key in pairs(ways) do if chosen[key] then return true end end
	return false
end
