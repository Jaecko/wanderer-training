local _, ns = ...
local L = ns.L

-- What your trainers have for you, read from What's Training's data (Data/WhatsTraining) and the game: every
-- class spell, weapon skill and (warlock) demon tome, each with where it stands (learned, to learn now, its
-- earlier rank missing, its talent not taken, a later level), its price (the reputation's discount taken), and
-- whether it counts: of what you play, not set aside. Then the three sums: now, at the next level that brings
-- something, and everything left.

local W = Wanderer
local U = W and W.Util

local HONORED = 6 -- the standing that takes 10 % off at a trainer (Forever)
local DISCOUNT = 10

-- Your settings of Wanderer Training (nil: Wanderer off).
function ns.Settings() return W.Settings("training") end

-- This character's choices: the ways played, what is set aside, what counts anyway, the tomes known, the ranks
-- kept on its bars on purpose, the prices seen at its class trainer, its savings goal ({ name, amount, preset }).
function ns.DB()
	WandererTrainingDB = type(WandererTrainingDB) == "table" and WandererTrainingDB or {}
	local db = WandererTrainingDB
	db.ignored = type(db.ignored) == "table" and db.ignored or {}
	db.counted = type(db.counted) == "table" and db.counted or {}
	db.tomes = type(db.tomes) == "table" and db.tomes or {}
	db.keepRanks = type(db.keepRanks) == "table" and db.keepRanks or {}
	db.prices = type(db.prices) == "table" and db.prices or {}
	if db.goal ~= nil and not (type(db.goal) == "table" and type(db.goal.amount) == "number") then db.goal = nil end
	return db
end

-- The character, the data for it ---------------------------------------------------------------------------

local spellsByLevel, overridden = {}, {}
local tomeItems = {}
ns.byId = {}

function ns.IsTome(item) return tomeItems[item] == true end

function ns.LoadCharacter()
	ns.class = select(2, UnitClass("player"))
	ns.side = UnitFactionGroup("player")
	ns.race = select(3, UnitRace("player"))
	spellsByLevel = ns.SpellsFor(ns.class, ns.side, ns.race)
	overridden = ns.OverriddenGroups(ns.class)
	wipe(ns.byId)
	wipe(tomeItems)
	local data = ns.ClassData[ns.class]
	for _, tomes in pairs(data and data.tomesByLevel or {}) do
		for _, tome in ipairs(tomes) do tomeItems[tome.itemId] = true end
	end
	ns.Invalidate()
	ns.ForgetRoots()
	for level, spells in pairs(spellsByLevel) do
		for _, spell in ipairs(spells) do
			spell.level = level
			ns.byId[spell.id] = spell
		end
	end
	ns.ForgetFollowing()
end

-- The ranks that replace the earlier ones by themselves (the game's own doing, nothing to update on the bars).
function ns.IsOverridden(id) return overridden[id] ~= nil end

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

ns.Learned = Learned

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
	local _, standing = U.Faction(faction)
	return (standing or 0) >= HONORED
end

-- The discount (percent) of the best of these factions; a price with it, rounded as the game rounds it.
local function BestDiscount(factions)
	for _, faction in ipairs(factions or {}) do
		if faction and Honored(faction) then return DISCOUNT end
	end
	return 0
end
local function Discounted(cost, pct) return math.floor((cost * (100 - pct) + 50) / 100) end

-- (the class trainer's discount: the one seen at the last class trainer visited, a city of its own; until then, the
-- best of your class's cities)
local function ClassDiscount()
	local seen = ns.DB().discount
	if seen == 0 or seen == DISCOUNT then return seen end
	local roles = ns.TrainerFactions and ns.TrainerFactions.roles[ns.class]
	return BestDiscount(roles and roles[ns.side])
end

-- At a class trainer: its prices against the data's tell its discount (kept for the sums), when they all agree.
-- services: { { cost (the trainer's), entry = { cost (the data's) } } }
function ns.NoteDiscounts(services)
	local found
	for _, service in ipairs(services) do
		local cost, price = service.entry.cost, service.cost
		local off = cost and cost > 0 and Discounted(cost, DISCOUNT) or nil
		-- (a price too small to tell, or one the data does not know: no word from it)
		local pct = off and off ~= cost and (price == cost and 0 or price == off and DISCOUNT) or nil
		if pct then
			if found and found ~= pct then return end
			found = pct
		end
	end
	if found and ns.DB().discount ~= found then
		ns.DB().discount = found
		ns.Changed()
	end
end

-- The prices a class trainer asks (every service it lists, the later ones too), kept for this character: they
-- replace the data's (Forever may change a spell's price). services: { { cost, sub, state, entry } }.
function ns.NotePrices(services)
	local prices, changed = ns.DB().prices, false
	for _, service in ipairs(services) do
		local entry = service.entry
		-- (only the very rank: its name and its rank both the trainer's)
		local id = entry and service.state ~= "used" and entry.kind == "spell" and not entry.quest
			and (entry.sub or "") == (service.sub or "") and entry.id
		local cost = tonumber(service.cost)
		if id and cost and cost >= 0 and prices[id] ~= cost then
			prices[id] = cost
			changed = true
		end
	end
	if changed then ns.Changed() end
	return changed
end

-- A spell's price for you: the one seen at your trainer, else the data's with your discount; seen: true for the
-- trainer's.
function ns.PriceOf(id)
	local seen = ns.DB().prices[id]
	if seen then return seen, true end
	local spell = ns.byId[id]
	return Discounted(spell and spell.cost or 0, ClassDiscount()), false
end

local function MasterDiscount(npcs)
	local factions = {}
	for _, npc in ipairs(npcs or {}) do factions[#factions + 1] = ns.TrainerFactions and ns.TrainerFactions.npcs[npc] end
	return BestDiscount(factions)
end

-- Reading spells ---------------------------------------------------------------------------------------------

local asked = {}
local function Ask(id)
	if asked[id] or not (C_Spell and C_Spell.RequestLoadSpellData) then return end
	asked[id] = true
	C_Spell.RequestLoadSpellData(id)
end

function ns.Asked(id) return asked[id] == true end
ns.Ask = Ask

-- A skill of yours (the poisons' of a rogue): its rank, read by the name of the spell that teaches it.
local SKILL_SPELLS = { [40] = 2842 }
local function SkillRank(skill)
	local spell = SKILL_SPELLS[skill]
	local name = spell and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell)
	if not (name and GetNumSkillLines and GetSkillLineInfo) then return nil end
	for index = 1, (U.Clean(U.Safe(GetNumSkillLines)) or 0) do
		local lineName, header, _, rank = U.Safe(GetSkillLineInfo, index)
		if not U.Clean(header) and U.Clean(lineName) == name then return U.Clean(rank) or 0 end
	end
	if IsPlayerSpell and IsPlayerSpell(spell) then return nil end
	return 0
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
	elseif entry.missing or entry.skill then
		entry.status = "missing"
	else
		entry.status = "now"
	end
	entry.ignored = db.ignored[entry.key] and true or false
	entry.forced = not entry.mine and db.counted[entry.key] and true or false
	entry.offSpec = entry.kind == "spell" and not entry.mine and not entry.forced
	entry.counts = entry.status ~= "known" and entry.status ~= "talent" and not entry.ignored and not entry.offSpec
end

-- Everything, settled for this level (yours by default): { entries, next (the next level bringing something
-- counted), sums = { now, next, all, leftOut (set aside or outside what you play) = { price, count } } }.
local built
function ns.Invalidate() built = nil end

function ns.Build(level)
	level = level or UnitLevel("player") or 1
	local now = GetTime and GetTime() or 0
	if built and built.level == level and built.time == now then return built.model end
	local model = ns.BuildNow(level)
	built = { level = level, time = now, model = model }
	return model
end

function ns.BuildNow(level)
	local entries = {}
	local classPct = ClassDiscount()
	-- The class spells.
	for spellLevel, spells in pairs(spellsByLevel) do
		for _, spell in ipairs(spells) do
			local name, sub, icon, link = SpellText(spell.id)
			local entry = { kind = "spell", id = spell.id, key = ns.Root(spell), level = spellLevel, name = name, sub = sub,
				icon = icon, link = link, cost = spell.cost or 0, quest = spell.quest, known = ns.Known(spell.id),
				mine = ns.InMyWays(spell) }
			-- (the trainer's own price, once seen there)
			local seen = not spell.quest and ns.DB().prices[spell.id]
			entry.price = seen or Discounted(entry.cost, classPct)
			entry.seen = seen and true or false
			entry.talent = spell.requiredTalentId ~= nil and not ns.Known(spell.requiredTalentId)
			for _, required in ipairs(spell.requiredIds or {}) do
				if not ns.Known(required) then entry.missing = true end
			end
			-- (a skill too low for it: the poisons of a rogue)
			for _, need in ipairs(spell.skills or {}) do
				local rank = SkillRank(need.skill)
				if rank and rank < need.level then entry.skill = need.level end
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
					quality = quality, cost = tome.cost, price = Discounted(tome.cost, classPct), known = ns.DB().tomes[tome.itemId] == true, mine = true }
				Settle(entry, level)
				entries[#entries + 1] = entry
			end
		end
	end
	-- The sums (the weapon skills apart: a sum of their own).
	local nextLevel
	for _, entry in ipairs(entries) do
		if entry.counts and not entry.quest and entry.kind ~= "weapon" and entry.status == "later" and (not nextLevel or entry.level < nextLevel) then
			nextLevel = entry.level
		end
	end
	local sums = { now = { price = 0, count = 0 }, next = { price = 0, count = 0 }, all = { price = 0, count = 0 },
		weapons = { price = 0, count = 0 }, trainer = { price = 0, count = 0 }, leftOut = { price = 0, count = 0 } }
	local function Add(sum, entry)
		sum.price, sum.count = sum.price + entry.price, sum.count + 1
	end
	for _, entry in ipairs(entries) do
		if entry.counts and entry.kind == "weapon" then
			Add(sums.weapons, entry)
		elseif (entry.ignored or entry.offSpec) and entry.status ~= "known" and entry.status ~= "talent" and not entry.quest and entry.kind ~= "weapon" then
			-- (left out by you: what it saves)
			Add(sums.leftOut, entry)
		elseif entry.counts and not entry.quest then
			Add(sums.all, entry)
			if entry.status == "now" then Add(sums.now, entry) end
			if entry.status == "now" and entry.kind == "spell" then Add(sums.trainer, entry) end
			if entry.status == "later" and entry.level == nextLevel then Add(sums.next, entry) end
		end
	end
	return { entries = entries, next = nextLevel, sums = sums, level = level }
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
	if not taught then return end
	local function PetKnows(spell)
		if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(spell, PET) end
		return IsSpellKnown and IsSpellKnown(spell, true) or false
	end
	local db, found = ns.DB(), false
	for item, spell in pairs(taught) do
		if not db.tomes[item] and PetKnows(spell) then
			db.tomes[item] = true
			found = true
		end
	end
	if found then ns.Changed() end
end

-- Ranks on your bars ---------------------------------------------------------------------------------------------

-- The buttons of your bars keep the rank they were given: after a trainer, the old ones are told (how
-- many, which), and one click (yours, out of a fight) puts the best rank you know in their place; a rank kept on
-- purpose (a lighter heal, a cheaper bolt) stays as it is, for this character. The macros naming a rank
-- ("Fireball(Rank 3)") are found with them, listed, and rewritten on the same click (the rank's words only). And
-- what a rank brings over the one before: the first number of its description that changed ("120 > 158"), read
-- from the game's own words, so in every language.

local SLOTS = 180 -- every action slot of the bars (the pages and the stances included)

-- The ranks of a spell, from the data: a rank's id -> the ranks that follow it (their first requirement).
local following
local function Following()
	if following then return following end
	following = {}
	for id, spell in pairs(ns.byId) do
		local before = spell.requiredIds and spell.requiredIds[1]
		if before then
			following[before] = following[before] or {}
			table.insert(following[before], id)
		end
	end
	return following
end

local function Name(id) return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or nil end
local function Rank(id)
	local sub = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
	return (sub and sub ~= "") and sub or nil
end
-- (a requirement of another name is another spell, not an earlier rank; a name not known yet: trusted)
local function SameSpell(a, b)
	local first, second = Name(a), Name(b)
	return not (first and second) or first == second
end

-- The best rank you know of the spell this id is a rank of (nil: none better).
function ns.BestRank(id)
	if not ns.byId[id] or ns.IsOverridden(id) then return nil end
	local best, bestLevel = nil, ns.byId[id].level or 0
	local function Walk(from)
		for _, later in ipairs(Following()[from] or {}) do
			if SameSpell(id, later) then
				local level = ns.byId[later].level or 0
				if ns.Learned(later) and level > bestLevel then best, bestLevel = later, level end
				Walk(later)
			end
		end
	end
	Walk(id)
	return best
end

-- The next rank to learn after this one (the ranks learned since passed over; nil: none left in the data).
function ns.NextRank(id)
	local at = id
	for _ = 1, 40 do
		local after
		for _, later in ipairs(Following()[at] or {}) do
			if SameSpell(id, later) and (not after or (ns.byId[later].level or 0) < (ns.byId[after].level or 0)) then after = later end
		end
		if not after then return nil end
		if not ns.Learned(after) then return after end
		at = after
	end
	return nil
end

-- Macros naming a rank -----------------------------------------------------------------------------------------

local MACRO_LETTERS = 255 -- the most a macro holds
local function AccountMacros() return tonumber(MAX_ACCOUNT_MACROS) or 120 end

-- The words a macro names a rank with ("Fireball(Rank 3)") -> the rank's id (names and ranks loaded only).
local function RankWords()
	local words = {}
	for id in pairs(ns.byId) do
		local name, rank = Name(id), Rank(id)
		if name and rank then words[name .. "(" .. rank .. ")"] = id end
	end
	return words
end

-- Where ranks are named in a macro's text: { { first, last, id } } in order; a name inside a longer one
-- ("Heal(Rank 1)" in "Greater Heal(Rank 1)") left to the longer, a word joined to it before not taken.
local function Named(body, words)
	local found = {}
	for text, id in pairs(words) do
		local from = 1
		while true do
			local first, last = body:find(text, from, true)
			if not first then break end
			local before = first > 1 and body:sub(first - 1, first - 1) or ""
			if not before:match("[%w\128-\255]") then found[#found + 1] = { first = first, last = last, id = id } end
			from = last + 1
		end
	end
	table.sort(found, function(a, b)
		if a.first ~= b.first then return a.first < b.first end
		return a.last > b.last
	end)
	local out, reach = {}, 0
	for _, at in ipairs(found) do
		if at.first > reach then
			out[#out + 1] = at
			reach = at.last
		end
	end
	return out
end

-- Your macros (the account's and this character's) naming an older rank: { { index, name, body, new, shared,
-- fits, swaps = { { id, best } } } }; note(id, best, kept) told of each rank found.
local function ScanMacros(note)
	local macros = {}
	if not (GetNumMacros and GetMacroInfo) then return macros end
	local accounts, characters = GetNumMacros()
	local indices = {}
	for index = 1, tonumber(accounts) or 0 do indices[#indices + 1] = index end
	for index = 1, tonumber(characters) or 0 do indices[#indices + 1] = AccountMacros() + index end
	local words
	for _, index in ipairs(indices) do
		local name, _, body = GetMacroInfo(index)
		if type(body) == "string" and body:find("(", 1, true) then
			words = words or RankWords()
			local swaps = {}
			for _, at in ipairs(Named(body, words)) do
				local best = ns.BestRank(at.id)
				local kept = ns.DB().keepRanks[at.id] == true
				if best and Rank(best) then
					note(at.id, best, kept)
					if not kept then swaps[#swaps + 1] = { id = at.id, best = best, first = at.first, last = at.last } end
				end
			end
			if swaps[1] then
				-- (rewritten from the end: the places before stay where they were read)
				local new = body
				for step = #swaps, 1, -1 do
					local swap = swaps[step]
					new = new:sub(1, swap.first - 1) .. Name(swap.id) .. "(" .. Rank(swap.best) .. ")" .. new:sub(swap.last + 1)
				end
				macros[#macros + 1] = { index = index, name = name or "", body = body, new = new, shared = index <= AccountMacros(),
					fits = #new <= MACRO_LETTERS, swaps = swaps }
			end
		end
	end
	return macros
end

local scanned -- { count (the buttons to update), kept (the buttons kept), spells = { { id, best, slots, kept } },
-- macros (ScanMacros'), macroCount (those that can be rewritten) }
local listeners = {}

-- Read again at the next look; the places that show it told (a moment after: many changes come at once).
local tell = U and U.Debounce(0.2, function() for _, fn in ipairs(listeners) do fn() end end)
function ns.RanksChanged()
	scanned = nil
	if tell then tell() end
end
function ns.OnRanksChanged(fn) listeners[#listeners + 1] = fn end

function ns.OldRanks()
	if scanned then return scanned end
	local db = ns.DB()
	local bySpell, spells = {}, {}
	local count, kept = 0, 0
	local function Spell(id, best)
		local spell = bySpell[id]
		if not spell then
			spell = { id = id, best = best, slots = {}, kept = db.keepRanks[id] == true }
			bySpell[id] = spell
			spells[#spells + 1] = spell
		end
		return spell
	end
	for slot = 1, GetActionInfo and SLOTS or 0 do
		local kind, id = GetActionInfo(slot)
		if kind == "spell" and id then
			local best = ns.BestRank(id)
			if best then
				local spell = Spell(id, best)
				spell.slots[#spell.slots + 1] = slot
				if spell.kept then kept = kept + 1 else count = count + 1 end
			end
		end
	end
	-- (the ranks of the macros too: kept on purpose the same way)
	local macros = ScanMacros(function(id, best) Spell(id, best) end)
	local macroCount = 0
	for _, macro in ipairs(macros) do if macro.fits then macroCount = macroCount + 1 end end
	table.sort(spells, function(a, b) return (Name(a.id) or "") < (Name(b.id) or "") end)
	scanned = { count = count, kept = kept, spells = spells, macros = macros, macroCount = macroCount }
	return scanned
end

local function Fighting() return InCombatLockdown and InCombatLockdown() or false end
function ns.CanUpdateRanks() return not Fighting() end

local function Pickup(id)
	if C_Spell and C_Spell.PickupSpell then return C_Spell.PickupSpell(id) end
	if PickupSpell then return PickupSpell(id) end
end

-- Every old rank not kept, the best one in its place (yours, a click: never in a fight, never with something
-- held by the mouse). Gives how many buttons changed, or nil and why ("combat", "cursor", "none": the game
-- cannot).
-- The last update, to undo it: { { slot, old, new } } (the buttons changed), cleared once undone or replaced.
local lastUpdate
local UNDO_FOR = 600 -- seconds the undo stays offered

-- A spell put on a button (the spell in hand first: an empty hand would take the button away).
local placing = false -- (Training's own hand: not you choosing a rank)
local function Place(slot, id)
	placing = true
	Pickup(id)
	local placed = false
	if not GetCursorInfo or GetCursorInfo() == "spell" then
		PlaceAction(slot)
		placed = true
	end
	if ClearCursor then ClearCursor() end
	placing = false
	return placed
end

-- The buttons of the old ranks not kept (only: those of these spells) given the best rank: how many, and what changed.
local function UpdateButtons(only)
	local changed, done = 0, {}
	for _, spell in ipairs(ns.OldRanks().spells) do
		if not spell.kept and (not only or only(spell)) then
			for _, slot in ipairs(spell.slots) do
				local kind, id = GetActionInfo(slot)
				-- (still the same button: nothing moved since it was read)
				if kind == "spell" and id == spell.id and Place(slot, spell.best) then
					changed = changed + 1
					done[#done + 1] = { slot = slot, old = spell.id, new = spell.best }
				end
			end
		end
	end
	return changed, done
end

function ns.UpdateRanks()
	if Fighting() then return nil, "combat" end
	if not PlaceAction then return nil, "none" end
	if GetCursorInfo and GetCursorInfo() then return nil, "cursor" end
	local changed, done = UpdateButtons()
	-- The macros listed, rewritten (each still as it was read; one too long once rewritten left as it is).
	local rewritten = {}
	for _, macro in ipairs(EditMacro and ns.OldRanks().macros or {}) do
		local name, _, body = GetMacroInfo(macro.index)
		if macro.fits and body == macro.body and (name or "") == macro.name then
			-- (nil name and icon, as the game's macro window does: only its words change, a "?" icon stays dynamic)
			EditMacro(macro.index, nil, nil, macro.new)
			rewritten[#rewritten + 1] = { index = macro.index, old = macro.body, new = macro.new }
		end
	end
	if done[1] or rewritten[1] then lastUpdate = { at = GetTime(), changes = done, macros = rewritten } end
	ns.RanksChanged()
	return changed + #rewritten
end

-- The last update undone: each button still holding the rank it was given gets its old one back.
function ns.UndoRanks()
	if Fighting() then return nil, "combat" end
	if GetCursorInfo and GetCursorInfo() then return nil, "cursor" end
	local undo = lastUpdate
	lastUpdate = nil
	if not (undo and PlaceAction) then return nil, "none" end
	local count = 0
	for _, change in ipairs(undo.changes) do
		local kind, id = GetActionInfo(change.slot)
		if kind == "spell" and id == change.new and Place(change.slot, change.old) then count = count + 1 end
	end
	-- (a macro still as it was rewritten: its old words back)
	for _, change in ipairs(EditMacro and undo.macros or {}) do
		local _, _, body = GetMacroInfo(change.index)
		if body == change.new then
			EditMacro(change.index, nil, nil, change.old)
			count = count + 1
		end
	end
	ns.RanksChanged()
	return count
end

-- The undo offered now: how many buttons, then macros, the last update changed (nil: none to undo).
function ns.CanUndoRanks()
	if not lastUpdate then return nil end
	if GetTime() - lastUpdate.at > UNDO_FOR then
		lastUpdate = nil
		return nil
	end
	return #lastUpdate.changes, #lastUpdate.macros
end

-- A rank kept on purpose (this character), or given back to the updates.
function ns.KeepRank(id, on)
	ns.DB().keepRanks[id] = on and true or nil
	ns.RanksChanged()
end
function ns.ForgetKeptRanks()
	wipe(ns.DB().keepRanks)
	ns.RanksChanged()
end

local function RankText(id) return Rank(id) or ("#" .. id) end

-- By themselves (an option, on): when you learn a new rank, the buttons holding an older one take it, out of a
-- fight, with nothing in your hand; Shift lets it pass, one click undoes it. Only a rank just learned: a lower
-- rank you put back on a bar afterwards stays there, and a rank you place yourself is kept for good.
local autoReady = false -- (a moment after login: the game knows your spells by then)

-- The best ranks already seen by this character (a best rank not in it is a new one).
local function SeenBests()
	local db = ns.DB()
	db.ranksSeen = type(db.ranksSeen) == "table" and db.ranksSeen or {}
	return db.ranksSeen
end

function ns.AutoRanks()
	local settings = ns.Settings()
	if not (autoReady and settings and settings.ranksAuto ~= false and PlaceAction) or Fighting() then return end
	if (U.IsSkipping and U.IsSkipping()) or (GetCursorInfo and GetCursorInfo()) then return end
	scanned = nil
	local seen = SeenBests()
	local changed, done = UpdateButtons(function(spell) return not seen[spell.best] end)
	for _, spell in ipairs(ns.OldRanks().spells) do seen[spell.best] = true end
	if changed == 0 then return 0 end
	lastUpdate = { at = GetTime(), changes = done, macros = {} }
	ns.RanksChanged()
	W.Toast(changed == 1 and L.RANKS_DONE_ONE or L.RANKS_DONE:format(changed), L.RANKS_AUTO_UNDO,
		{ kicker = L.TITLE, duration = 8, onClick = function() ns.UndoRanks() end, hint = L.RANKS_UNDO_HINT })
	return changed
end

-- The ranks known at login are not new (the buttons as you left them stay so).
function ns.StartAutoRanks()
	autoReady = true
	scanned = nil
	local seen = SeenBests()
	for _, spell in ipairs(ns.OldRanks().spells) do seen[spell.best] = true end
end

-- A lower rank you put on a bar yourself is kept at that rank (said once; the update's right click gives it back).
local held, heldAt
function ns.RankInHand()
	if placing or not GetCursorInfo then return end
	local kind, _, _, id = GetCursorInfo()
	if kind == "spell" and id then held, heldAt = id, GetTime() end
end

function ns.RankPlaced(slot)
	if placing or not (held and GetActionInfo and type(slot) == "number") then return false end
	local kind, id = GetActionInfo(slot)
	if kind ~= "spell" or id ~= held or GetTime() - heldAt > 2 then return false end
	held = nil
	if not ns.BestRank(id) or ns.DB().keepRanks[id] then return false end
	ns.KeepRank(id, true)
	W.Print(((U.UsingPad and U.UsingPad()) and L.RANKS_KEPT_SAID_PAD or L.RANKS_KEPT_SAID):format(Name(id) or ("#" .. id), RankText(id)))
	return true
end

-- A lower rank taken in hand (the row's card, at Training's window), to put on a bar.
function ns.TakeRank(id)
	if Fighting() then return W.Print(L.RANKS_COMBAT) end
	Pickup(id)
end

-- The lines of the tooltip: each spell, its rank on your bars and the best you know, kept or not.
-- (nothing old left on the bars nor in the macros)
local function NothingOld()
	local old = ns.OldRanks()
	return old.count == 0 and (old.macroCount or 0) == 0
end

-- The lines of the tooltip: each spell, its rank on your bars and the best you know, kept or not; then each macro
-- and what it will name.
function ns.RanksTooltip()
	if NothingOld() and ns.CanUndoRanks() then return { L.RANKS_UNDO, { L.RANKS_UNDO_HINT, 1, 1, 1 } } end
	local lines = { L.RANKS_TITLE }
	for _, spell in ipairs(ns.OldRanks().spells) do
		if spell.slots[1] then
			local text = L.RANKS_LINE:format(Name(spell.id) or ("#" .. spell.id), RankText(spell.id), RankText(spell.best))
			if spell.kept then text = text .. "  (" .. L.RANKS_KEPT .. ")" end
			lines[#lines + 1] = spell.kept and { text, 0.6, 0.57, 0.5 } or { text, 1, 1, 1 }
		end
	end
	for _, macro in ipairs(ns.OldRanks().macros or {}) do
		for _, swap in ipairs(macro.swaps) do
			local text = L.MACROS_LINE:format(macro.name, (Name(swap.id) or ("#" .. swap.id)) .. " " .. RankText(swap.id), RankText(swap.best))
			if macro.shared then text = text .. "  (" .. L.MACROS_SHARED .. ")" end
			if not macro.fits then text = text .. "  (" .. L.MACROS_TOO_LONG .. ")" end
			lines[#lines + 1] = macro.fits and { text, 1, 1, 1 } or { text, 0.6, 0.57, 0.5 }
		end
	end
	lines[#lines + 1] = { " " }
	lines[#lines + 1] = { (U.UsingPad and U.UsingPad()) and L.RANKS_HINT_PAD or L.RANKS_HINT, 0.6, 0.57, 0.5 }
	if (ns.OldRanks().macros or {})[1] then lines[#lines + 1] = { L.MACROS_HINT, 0.6, 0.57, 0.5 } end
	if Fighting() then lines[#lines + 1] = { L.RANKS_COMBAT, 1, 0.45, 0.35 } end
	return lines
end

-- A right click: a card beside it, each spell kept at its rank (a tick) or not; a click changes it, the card stays.
function ns.RanksMenu(owner)
	local rows = {}
	for _, spell in ipairs(ns.OldRanks().spells) do
		local kept = ns.DB().keepRanks[spell.id] == true
		rows[#rows + 1] = { text = Name(spell.id) or ("#" .. spell.id), right = RankText(spell.id), glyph = kept and "check" or "dot",
			role = not kept and "muted" or nil, onClick = function()
				ns.KeepRank(spell.id, not kept)
				ns.RanksMenu(owner)
			end }
	end
	if not rows[1] then return end
	return W.Skin.ActionCard(owner, { title = L.RANKS_KEEP_TITLE, rows = rows, foot = (U.UsingPad and U.UsingPad()) and L.RANKS_FORGET_DESC_PAD or L.RANKS_FORGET_DESC, width = 280 })
end

-- Whether the line offers to undo (nothing old left, the last update still undoable).
local function Undoing() return NothingOld() and ns.CanUndoRanks() ~= nil end

-- The words of the line: "3 buttons of your bars use an older rank" (and the macros), or after an update "3
-- buttons updated" with its undo (nil: nothing to say).
function ns.RanksText()
	local old = ns.OldRanks()
	local parts = {}
	local function Say(count, one, many) if count > 0 then parts[#parts + 1] = count == 1 and one or many:format(count) end end
	if NothingOld() then
		local buttons, macros = ns.CanUndoRanks()
		if not buttons then return nil end
		Say(buttons, L.RANKS_DONE_ONE, L.RANKS_DONE)
		Say(macros or 0, L.MACROS_DONE_ONE, L.MACROS_DONE)
	else
		Say(old.count, L.RANKS_ONE, L.RANKS_MANY)
		Say(old.macroCount or 0, L.MACROS_ONE, L.MACROS_MANY)
	end
	return parts[1] and table.concat(parts, " ") or nil
end

-- The button's word: Update, or Undo just after an update.
function ns.RanksButtonText() return Undoing() and L.RANKS_UNDO or L.RANKS_UPDATE end

-- The click of the button (both places): the update or its undo, or the menu on a right click.
function ns.RanksClick(owner, mouse)
	if mouse == "RightButton" then return ns.RanksMenu(owner) end
	local changed, why
	if Undoing() then changed, why = ns.UndoRanks() else changed, why = ns.UpdateRanks() end
	if changed then return end
	if why == "combat" then W.Print(L.RANKS_COMBAT) elseif why == "cursor" then W.Print(L.RANKS_CURSOR) end
end

-- What a rank brings -----------------------------------------------------------------------------------------------

local gains = {}

local function Description(id)
	local text = C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(id)
	if text and text ~= "" then return text end
	ns.Ask(id)
	return nil
end

-- The numbers of a text, as written ("1,200", "2.5"; a sentence's last point left out).
local function Numbers(text)
	local out = {}
	for number in text:gmatch("%d[%d%.,]*") do out[#out + 1] = (number:gsub("[%.,]+$", "")) end
	return out
end

-- { before, after }: the first number that changed from the rank before (nil: a first rank, words not loaded
-- yet, or two texts that do not line up).
function ns.RankGain(id)
	if gains[id] ~= nil then return gains[id] or nil end
	local spell = ns.byId[id]
	local before = spell and spell.requiredIds and spell.requiredIds[1]
	if not before or not SameSpell(id, before) then
		gains[id] = false
		return nil
	end
	local newText, oldText = Description(id), Description(before)
	if not (newText and oldText) then return nil end
	local new, old = Numbers(newText), Numbers(oldText)
	local gain = false
	if #new == #old then
		for index = 1, #new do
			if new[index] ~= old[index] then
				gain = { old[index], new[index] }
				break
			end
		end
	end
	gains[id] = gain
	return gain or nil
end

-- The gain written: the old number quiet, a small chevron (the kit's own sheet), the new one in its color
-- ({ r, g, b }, 0 to 1).
function ns.GainText(gain, quiet, bright)
	if not gain then return nil end
	local arrow = W.Skin.GlyphText("chevron", quiet, 10)
	return U.Colorize(gain[1], quiet[1], quiet[2], quiet[3]) .. " " .. arrow .. " " .. U.Colorize(gain[2], bright[1], bright[2], bright[3])
end

-- Events ------------------------------------------------------------------------------------------------------------

function ns.InitRanks()
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_REGEN_DISABLED",
		"PLAYER_REGEN_ENABLED", "PLAYER_LOGIN", "UPDATE_MACROS" }) do
		pcall(events.RegisterEvent, events, event)
	end
	local auto = U.Debounce(0.5, function() ns.AutoRanks() end)
	pcall(events.RegisterEvent, events, "CURSOR_CHANGED")
	events:SetScript("OnEvent", function(_, event, arg)
		if event == "CURSOR_CHANGED" then return ns.RankInHand() end
		if event == "ACTIONBAR_SLOT_CHANGED" then ns.RankPlaced(arg) end
		ns.RanksChanged()
		if event == "PLAYER_LOGIN" then C_Timer.After(5, ns.StartAutoRanks) end
		if event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_SKILL_LINE" or event == "PLAYER_REGEN_ENABLED" then auto() end
	end)
end

-- Spell tooltips -------------------------------------------------------------------------------------------------
-- A line or two under a spell of your class the data knows (your spellbook, your bars, Training's rows): its next
-- rank, its level and price (the trainer's once seen there); a rank not learned yet, the price seen at your
-- trainer; a spell outside what you play, why, in one line. Lines added only, out of a fight.

local QUIET = (Wanderer and Wanderer.Skin and Wanderer.Skin.COLORS.muted) or { 0.64, 0.6, 0.52 }

-- The lines for a spell: { { text, r, g, b } } (nil: nothing to say).
function ns.SpellTipLines(id)
	local spell = id and ns.byId[id]
	if not spell or spell.quest then return nil end
	local lines = {}
	local gold = W.Skin.COLORS.gold
	local function Add(text, color) lines[#lines + 1] = { text, color[1], color[2], color[3] } end
	if ns.Learned(id) then
		local after = ns.NextRank(id)
		local later = after and ns.byId[after]
		if later and not later.quest then
			local price, seen = ns.PriceOf(after)
			local level = UnitLevel and UnitLevel("player") or 1
			local text = (later.level or 0) <= level and L.TIP_NEXT_NOW:format(U.CoinsWords(price))
				or L.TIP_NEXT_RANK:format(later.level or 0, U.CoinsWords(price))
			if seen then text = text .. "  (" .. L.PRICE_SEEN_SHORT .. ")" end
			Add(text, gold)
			local why = ns.Reason(after)
			if why then Add(why, QUIET) end
		end
	else
		local price, seen = ns.PriceOf(id)
		if seen then Add(L.PRICE_SEEN:format(U.CoinsWords(price)), gold) end
		local why = ns.Reason(id)
		if why then Add(why, QUIET) end
	end
	return lines[1] and lines or nil
end

function ns.InitSpellTips()
	local kinds = Enum and Enum.TooltipDataType
	if not (TooltipDataProcessor and kinds and kinds.Spell) then return false end
	TooltipDataProcessor.AddTooltipPostCall(kinds.Spell, function(tooltip, data)
		-- (out of a fight, the option on, never a comparison or a forbidden tooltip)
		if not ns.class or (InCombatLockdown and InCombatLockdown()) then return end
		local settings = ns.Settings()
		if not settings or settings.spellTips == false or type(data) ~= "table" then return end
		if data.type ~= nil and data.type ~= kinds.Spell then return end
		if (tooltip.IsForbidden and tooltip:IsForbidden()) or U.IsComparisonTooltip(tooltip) then return end
		local ok, lines = U.Try(ns.SpellTipLines, U.Clean(data.id))
		if not (ok and lines) then return end
		for _, line in ipairs(lines) do tooltip:AddLine(line[1], line[2], line[3], line[4], true) end
		U.ShowTooltipAgain(tooltip)
	end)
	return true
end

-- (another character's data loaded: the ranks' links and the gains read again)
function ns.ForgetFollowing()
	following = nil
	wipe(gains)
	ns.RanksChanged()
end
