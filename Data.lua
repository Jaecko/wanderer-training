local _, ns = ...

-- What the files of Data/WhatsTraining (What's Training's own, MIT: see its LICENSE there) need to load into
-- this addon: their class tables (ns.forClass, in their own words), filled by them. Nothing else of theirs runs.

ns.ClassData = {}
function ns.forClass(token)
	ns.ClassData[token] = ns.ClassData[token] or {}
	return ns.ClassData[token]
end

-- The class spells by level, filtered for your side and race: { [level] = { spell, ... } }.
function ns.SpellsFor(class, side, race)
	local data = ns.ClassData[class]
	local out = {}
	for level, spells in pairs(data and data.spellsByLevel or {}) do
		for _, spell in ipairs(spells) do
			local sideOk = spell.faction == nil or spell.faction == side
			local raceOk = (spell.race == nil and spell.races == nil) or spell.race == race
				or (spell.races ~= nil and (spell.races[1] == race or spell.races[2] == race))
			if sideOk and raceOk then
				out[level] = out[level] or {}
				out[level][#out[level] + 1] = spell
			end
		end
	end
	-- (the spells a quest teaches, for your race: no price, the quest said)
	for id, entries in pairs(ns.QuestSpells and ns.QuestSpells[class] or {}) do
		for _, entry in ipairs(entries) do
			local mine = false
			for _, each in ipairs(entry.races or {}) do if each == race then mine = true end end
			if mine then
				out[entry.level] = out[entry.level] or {}
				out[entry.level][#out[entry.level] + 1] = { id = id, cost = 0, quest = true }
				break
			end
		end
	end
	return out
end

-- The ranks that replace the earlier ones (most of the warrior's and the rogue's): spell id -> its group, in
-- order of rank.
function ns.OverriddenGroups(class)
	local map = {}
	local data = ns.ClassData[class]
	for _, group in ipairs(data and data.overriddenGroups or {}) do
		for _, id in ipairs(group) do map[id] = group end
	end
	return map
end
