local _, ns = ...

-- What your trainers have for you, read from What's Training's data (Data/WhatsTraining) and the game: every
-- class spell, weapon skill and (warlock) demon tome, each with where it stands (learned, to learn now, its
-- earlier rank missing, its talent not taken, a later level), its price (the reputation's discount taken), and
-- whether it counts: of what you play, not set aside. Then the three sums: now, at the next level that brings
-- something, and everything left.

local W = Wanderer
local U = W and W.Util

local HONORED = 6 -- the standing that takes 10 % off at a trainer (Forever)
local DISCOUNT = 10

-- This character's choices: the ways played, what is set aside, what counts anyway, the tomes known.
function ns.DB()
	WandererTrainingDB = type(WandererTrainingDB) == "table" and WandererTrainingDB or {}
	local db = WandererTrainingDB
	db.ignored = type(db.ignored) == "table" and db.ignored or {}
	db.counted = type(db.counted) == "table" and db.counted or {}
	db.tomes = type(db.tomes) == "table" and db.tomes or {}
	return db
end

-- The character, the data for it ---------------------------------------------------------------------------

local spellsByLevel, overridden = {}, {}
ns.byId = {}

function ns.LoadCharacter()
	ns.class = select(2, UnitClass("player"))
	ns.side = UnitFactionGroup("player")
	ns.race = select(3, UnitRace("player"))
	spellsByLevel = ns.SpellsFor(ns.class, ns.side, ns.race)
	overridden = ns.OverriddenGroups(ns.class)
	wipe(ns.byId)
	for level, spells in pairs(spellsByLevel) do
		for _, spell in ipairs(spells) do
			spell.level = level
			ns.byId[spell.id] = spell
		end
	end
end

-- Known ------------------------------------------------------------------------------------------------------

local PLAYER = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or "spell"
local PET = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or "pet"

local function Learned(id)
	if C_SpellBook and C_SpellBook.IsSpellKnown then
		if C_SpellBook.IsSpellKnown(id, PLAYER) then return true end
		if C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(id, PLAYER, false) then return true end
		return false
	end
	return IsPlayerSpell and IsPlayerSpell(id) or false
end

-- Known: learned, or a later rank that replaced it learned.
function ns.Known(id)
	if Learned(id) then return true end
	local group = overridden[id]
	if not group then return false end
	local mine, known = 0, 0
	for index, other in ipairs(group) do
		if other == id then mine = index end
		if Learned(other) then known = index end
	end
	return mine <= known
end

-- Prices -------------------------------------------------------------------------------------------------------

local function Honored(faction)
	local data = C_Reputation and C_Reputation.GetFactionDataByID and U.Safe(C_Reputation.GetFactionDataByID, faction)
	local reaction = type(data) == "table" and U.Clean(data.reaction)
	return (reaction or 0) >= HONORED
end

-- The discount (percent) of the best of these factions; a price with it, rounded as the game rounds it.
local function BestDiscount(factions)
	for _, faction in ipairs(factions or {}) do
		if faction and Honored(faction) then return DISCOUNT end
	end
	return 0
end
local function Discounted(cost, pct) return math.floor((cost * (100 - pct) + 50) / 100) end

local function ClassDiscount()
	local roles = ns.TrainerFactions and ns.TrainerFactions.roles[ns.class]
	return BestDiscount(roles and roles[ns.side])
end

local function MasterDiscount(npcs)
	local factions = {}
	for _, npc in ipairs(npcs or {}) do factions[#factions + 1] = ns.TrainerFactions and ns.TrainerFactions.npcs[npc] end
	return BestDiscount(factions)
end
ns.MasterDiscount = MasterDiscount

-- Reading spells ---------------------------------------------------------------------------------------------

local asked = {}
local function Ask(id)
	if asked[id] or not (C_Spell and C_Spell.RequestLoadSpellData) then return end
	asked[id] = true
	C_Spell.RequestLoadSpellData(id)
end

local function SpellText(id)
	local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
	if not name then Ask(id) end
	local sub = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
	local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
	local link = C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(id)
	return name or ("#" .. id), (sub and sub ~= "") and sub or nil, icon or "Interface\\Icons\\INV_Misc_QuestionMark", link
end

-- The list ---------------------------------------------------------------------------------------------------

-- Where an entry stands and whether it counts.
local function Settle(entry, level)
	local db = ns.DB()
	if entry.known then
		entry.status = "known"
	elseif entry.talent then
		entry.status = "talent"
	elseif entry.level > level then
		entry.status = "later"
	elseif entry.missing then
		entry.status = "missing"
	else
		entry.status = "now"
	end
	entry.ignored = (db.ignored[entry.key] or (entry.kind == "weapon" and db.noWeapons)) and true or false
	entry.forced = db.counted[entry.key] and true or false
	entry.offSpec = entry.kind == "spell" and not entry.mine and not entry.forced
	entry.counts = entry.status ~= "known" and entry.status ~= "talent" and not entry.ignored and not entry.offSpec
end

-- Everything, settled for this level (yours by default): { entries, next (the next level bringing something
-- counted), sums = { now, next, all = { price, count } } }.
function ns.Build(level)
	level = level or UnitLevel("player") or 1
	local entries = {}
	local classPct = ClassDiscount()
	-- The class spells.
	for spellLevel, spells in pairs(spellsByLevel) do
		for _, spell in ipairs(spells) do
			local name, sub, icon, link = SpellText(spell.id)
			local entry = { kind = "spell", id = spell.id, key = ns.Root(spell), level = spellLevel, name = name, sub = sub,
				icon = icon, link = link, cost = spell.cost or 0, quest = spell.quest, known = ns.Known(spell.id),
				mine = ns.InMyWays(spell) }
			entry.price = Discounted(entry.cost, classPct)
			entry.talent = spell.requiredTalentId ~= nil and not ns.Known(spell.requiredTalentId)
			for _, required in ipairs(spell.requiredIds or {}) do
				if not ns.Known(required) then entry.missing = true end
			end
			Settle(entry, level)
			entries[#entries + 1] = entry
		end
	end
	-- The weapon skills of your class.
	for order, weapon in ipairs(ns.WEAPONS or {}) do
		local mineClass = false
		for _, class in ipairs(weapon.classes) do if class == ns.class then mineClass = true end end
		if mineClass then
			local name, _, icon, link = SpellText(weapon.skill)
			local masters = weapon.masters[ns.side] or {}
			local entry = { kind = "weapon", id = weapon.skill, key = "weapon:" .. weapon.skill, level = weapon.level, name = name,
				icon = icon, link = link, cost = weapon.cost, known = Learned(weapon.skill), masters = masters, order = order, mine = true }
			entry.price = Discounted(entry.cost, MasterDiscount(masters))
			Settle(entry, level)
			entries[#entries + 1] = entry
		end
	end
	-- The demon tomes (one item may teach two demons: one line).
	local data = ns.ClassData[ns.class]
	local seen = {}
	for tomeLevel, tomes in pairs(data and data.tomesByLevel or {}) do
		for _, tome in ipairs(tomes) do
			if not seen[tome.itemId] then
				seen[tome.itemId] = true
				local name, link, quality = U.ItemInfo(tome.itemId)
				local entry = { kind = "tome", id = tome.itemId, key = "tome:" .. tome.itemId, level = tomeLevel,
					name = name or U.ItemName(tome.itemId) or ("#" .. tome.itemId), icon = U.ItemIcon(tome.itemId), link = link,
					quality = quality, cost = tome.cost, price = tome.cost, known = ns.DB().tomes[tome.itemId] == true, mine = true }
				Settle(entry, level)
				entries[#entries + 1] = entry
			end
		end
	end
	-- The sums.
	local nextLevel
	for _, entry in ipairs(entries) do
		if entry.counts and entry.status == "later" and (not nextLevel or entry.level < nextLevel) then nextLevel = entry.level end
	end
	local sums = { now = { price = 0, count = 0 }, next = { price = 0, count = 0 }, all = { price = 0, count = 0 } }
	local function Add(sum, entry)
		sum.price, sum.count = sum.price + entry.price, sum.count + 1
	end
	for _, entry in ipairs(entries) do
		if entry.counts then
			Add(sums.all, entry)
			if entry.status == "now" then Add(sums.now, entry) end
			if entry.status == "later" and entry.level == nextLevel then Add(sums.next, entry) end
		end
	end
	return { entries = entries, next = nextLevel, sums = sums, level = level }
end

-- What can be learned now and counts (the bar's word pulses for it).
function ns.Attention()
	if not ns.class then return false end
	local model = ns.Build()
	return model.sums.now.count > 0
end

-- Set aside, taken back; counted anyway, no longer.
function ns.Ignore(key, on)
	ns.DB().ignored[key] = on and true or nil
	ns.Changed()
end
function ns.Count(key, on)
	ns.DB().counted[key] = on and true or nil
	ns.Changed()
end

-- The demon tomes learned: seen when the demon is out (its spells, from the tome, in its book).
function ns.NoteTomes()
	local data = ns.ClassData[ns.class]
	local taught = data and data.tomeTaughtSpells
	if not (taught and C_SpellBook and C_SpellBook.IsSpellKnown) then return end
	local db, found = ns.DB(), false
	for item, spell in pairs(taught) do
		if not db.tomes[item] and C_SpellBook.IsSpellKnown(spell, PET) then
			db.tomes[item] = true
			found = true
		end
	end
	if found then ns.Changed() end
end

-- At the trainer: the class spells to learn now that count, as the trainer lists them (by name and rank),
-- bought while the money lasts, the cheapest first; from the highest index down (the others keep theirs).
function ns.TrainerServices()
	local wanted = {}
	for _, entry in ipairs(ns.Build().entries) do
		if entry.kind == "spell" and entry.counts and entry.status == "now" and not entry.quest then
			wanted[entry.name .. "|" .. (entry.sub or "")] = entry
		end
	end
	local list = {}
	for index = 1, (U.Clean(U.Safe(GetNumTrainerServices)) or 0) do
		local name, sub, category = U.Safe(GetTrainerServiceInfo, index)
		name, sub = U.Clean(name), U.Clean(sub)
		if category == "available" and name then
			local entry = wanted[name .. "|" .. (sub or "")] or wanted[name .. "|"]
			if entry then list[#list + 1] = { index = index, cost = U.Clean(U.Safe(GetTrainerServiceCost, index)) or entry.price } end
		end
	end
	return list
end

function ns.LearnServices()
	local money = GetMoney and GetMoney() or 0
	local list = ns.TrainerServices()
	table.sort(list, function(a, b) return a.cost < b.cost end)
	local chosen, total = {}, 0
	for _, service in ipairs(list) do
		if total + service.cost <= money then
			chosen[#chosen + 1] = service.index
			total = total + service.cost
		end
	end
	table.sort(chosen, function(a, b) return a > b end)
	for _, index in ipairs(chosen) do U.Safe(BuyTrainerService, index) end
	return #chosen
end

-- Money, said briefly in the headings: "1 g 20 s" (the game's own letters).
function ns.MoneyText(copper)
	copper = math.max(0, math.floor(copper or 0))
	local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local parts = {}
	if gold > 0 then parts[#parts + 1] = gold .. " " .. (GOLD_AMOUNT_SYMBOL or "g") end
	if silver > 0 then parts[#parts + 1] = silver .. " " .. (SILVER_AMOUNT_SYMBOL or "s") end
	if rest > 0 or #parts == 0 then parts[#parts + 1] = rest .. " " .. (COPPER_AMOUNT_SYMBOL or "c") end
	return table.concat(parts, " ")
end
