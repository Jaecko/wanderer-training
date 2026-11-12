local _, ns = ...
local L = ns.L

-- What a talent really changes, in your own numbers. Its words at each rank come from the game (the tooltip of
-- the talent at that rank): the numbers that move from one rank to the next are shown as "before → after".
-- The spells it names are found in your spellbook; their figures now are read from the game (cost, cast time,
-- cooldown, range, the damage or healing in their description, which on Forever already counts your talents),
-- and what the talent would make of them is calculated from the kind of change its words say (more damage or
-- healing in percent, less cost, a shorter cast or cooldown, a longer range). Every figure says where it comes
-- from: read in the game, calculated, or unknown (never guessed). Nothing is read or calculated in a fight.

local W = Wanderer
local U = W and W.Util
local Skin = W and W.Skin
local Safe, Clean = U and U.Safe, U and U.Clean

ns.TAG_READ, ns.TAG_CALC, ns.TAG_UNKNOWN = "read", "calc", "unknown"

local texts = {} -- "entry:rank" -> the talent's words at that rank
local book -- spell name (lower case) -> spell id, your spellbook as last read

function ns.ForgetTalentTexts()
	wipe(texts)
	book = nil
end

-- Words -------------------------------------------------------------------------------------------------------

-- The talent's words at a rank (its description: the longest line of its tooltip), or nil.
function ns.TalentText(node, rank)
	if not (node and node.entry) then return nil end
	rank = math.max(1, math.min(node.most or 1, rank or 1))
	local key = node.entry .. ":" .. rank
	if texts[key] ~= nil then return texts[key] or nil end
	local info = C_TooltipInfo and C_TooltipInfo.GetTraitEntry and Safe(C_TooltipInfo.GetTraitEntry, node.entry, rank)
	local best
	for _, line in ipairs(type(info) == "table" and info.lines or {}) do
		local text = Clean(line.leftText)
		if type(text) == "string" and (not best or #text > #best) then best = text end
	end
	if not best and node.spell and C_Spell and C_Spell.GetSpellDescription then
		best = Clean(Safe(C_Spell.GetSpellDescription, node.spell))
		if best == "" then best = nil end
	end
	-- (asked again later while the game has not loaded it)
	if best then texts[key] = best end
	return best
end

-- The numbers of a text, in order: { value, unit ("%" or ""), from, to (where it stands in the text) }.
function ns.TextNumbers(text)
	local list = {}
	local start = 1
	while text do
		local from, to, number = text:find("(%d+[%.,]?%d*)", start)
		if not from then break end
		-- (a trailing dot or comma ends a sentence: not part of the number; three digits after a comma or a dot
		-- are thousands, "1,200"; one or two are a fraction, "0,5" or "1.5")
		if number:find("[%.,]$") then
			number = number:sub(1, -2)
			to = to - 1
		end
		local whole, fraction = number:match("^(%d+)[%.,](%d+)$")
		local clean = number
		if whole and #fraction == 3 then clean = whole .. fraction elseif whole then clean = whole .. "." .. fraction end
		local after = text:sub(to + 1, to + 3)
		list[#list + 1] = { value = tonumber(clean) or 0, unit = after:match("^%s?%%") and "%" or "", from = from, to = to }
		start = to + 1
	end
	return list
end

local function Short(value)
	if not value then return "?" end
	if math.abs(value - math.floor(value + 0.5)) < 0.01 then return tostring(math.floor(value + 0.5)) end
	return (string.format("%.1f", value):gsub("%.0$", ""))
end

-- The talent going from one rank to another: its words at the higher rank with each number that moves written
-- "before → after" (gold), and the moves themselves ({ from, to, unit }). From rank 0, each number goes from 0.
function ns.TalentChange(node, fromRank, toRank)
	local after = ns.TalentText(node, math.max(1, toRank))
	if not after then return nil end
	local afterNumbers = ns.TextNumbers(after)
	local beforeNumbers = fromRank and fromRank > 0 and ns.TextNumbers(ns.TalentText(node, fromRank) or "") or nil
	local same = beforeNumbers and #beforeNumbers == #afterNumbers
	local moves, pieces, last = {}, {}, 1
	for index, number in ipairs(afterNumbers) do
		local before = (fromRank or 0) <= 0 and 0 or (same and beforeNumbers[index].value or nil)
		if before ~= nil and before ~= number.value and toRank > (fromRank or 0) then
			moves[#moves + 1] = { from = before, to = number.value, unit = number.unit, at = number.from }
			pieces[#pieces + 1] = after:sub(last, number.from - 1)
			pieces[#pieces + 1] = Skin.Colorize(Short(before) .. " → " .. Short(number.value), "gold")
			last = number.to + 1
		end
	end
	pieces[#pieces + 1] = after:sub(last)
	return { text = table.concat(pieces), moves = moves, words = after }
end

-- The spellbook -----------------------------------------------------------------------------------------------

local function ReadBook()
	book = {}
	local spellBook = C_SpellBook
	if not (spellBook and spellBook.GetNumSpellBookSkillLines) then return book end
	for line = 1, Clean(Safe(spellBook.GetNumSpellBookSkillLines)) or 0 do
		local info = Safe(spellBook.GetSpellBookSkillLineInfo, line)
		if type(info) == "table" and not info.shouldHide then
			local offset = Clean(info.itemIndexOffset) or 0
			for index = offset + 1, offset + (Clean(info.numSpellBookItems) or 0) do
				local item = Safe(spellBook.GetSpellBookItemInfo, index, Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player)
				local id = type(item) == "table" and Clean(item.spellID)
				local name = id and C_Spell and Clean(Safe(C_Spell.GetSpellName, id))
				if name and #name >= 3 and not (item.isPassive or (C_Spell.IsSpellPassive and Clean(Safe(C_Spell.IsSpellPassive, id)))) then
					book[name:lower()] = id
				end
			end
		end
	end
	return book
end

function ns.ForgetBook() book = nil end

-- The spells of your book a talent names, in the order they come in its words: { { id, name } }.
function ns.SpellsTouched(node)
	local words = ns.TalentText(node, node.most or 1)
	if not words then return {} end
	local lower = words:lower()
	local found = {}
	for name, id in pairs(book or ReadBook()) do
		local at = lower:find(name, 1, true)
		if at and id ~= node.spell then found[#found + 1] = { id = id, name = Clean(Safe(C_Spell.GetSpellName, id)) or name, at = at } end
	end
	table.sort(found, function(a, b) return a.at < b.at end)
	return found
end

-- Every talent that names a word (a spell, or any word of its text): the tree's nodes in order.
function ns.TalentsNaming(word)
	local found = {}
	local tree = ns.TalentTreeNow()
	word = (word or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if not tree or #word < 2 then return found end
	for _, node in ipairs(tree.order) do
		local words = ns.TalentText(node, node.most or 1) or ""
		local name = node.spell and C_Spell and Clean(Safe(C_Spell.GetSpellName, node.spell)) or ""
		if words:lower():find(word, 1, true) or name:lower():find(word, 1, true) then found[#found + 1] = node end
	end
	return found
end

-- A spell now ----------------------------------------------------------------------------------------------------

-- Its figures as the game gives them (all read in the game): cost, cast (seconds), cooldown (seconds), range
-- (yards), the first damage or healing of its description ({ low, high } or { low }).
function ns.SpellNow(id)
	local now = {}
	local spell = C_Spell
	if not spell then return now end
	local costs = spell.GetSpellPowerCost and Safe(spell.GetSpellPowerCost, id)
	local first = type(costs) == "table" and costs[1]
	if type(first) == "table" and Clean(first.cost) and Clean(first.cost) > 0 then now.cost = Clean(first.cost) end
	local info = spell.GetSpellInfo and Safe(spell.GetSpellInfo, id)
	if type(info) == "table" then
		local cast = Clean(info.castTime)
		if cast and cast > 0 then now.cast = cast / 1000 end
		local range = Clean(info.maxRange)
		if range and range > 0 then now.range = range end
	end
	local cooldown = _G.GetSpellBaseCooldown and Clean((Safe(_G.GetSpellBaseCooldown, id)))
	if cooldown and cooldown > 0 then now.cooldown = cooldown / 1000 end
	local words = spell.GetSpellDescription and Clean(Safe(spell.GetSpellDescription, id))
	if type(words) == "string" and words ~= "" then
		now.words = words
		local numbers = ns.TextNumbers(words)
		-- (the first number not a percent, and the next one when only a short word stands between: "20 to 22")
		for index, number in ipairs(numbers) do
			if number.unit == "" and number.value > 0 then
				local nextOne = numbers[index + 1]
				local between = nextOne and words:sub(number.to + 1, nextOne.from - 1) or ""
				if nextOne and nextOne.unit == "" and #between <= 5 and not between:find("[%.%(]") then
					now.amount = { number.value, nextOne.value }
				else
					now.amount = { number.value }
				end
				break
			end
		end
	end
	return now
end

-- The kind of change -------------------------------------------------------------------------------------------

-- What a talent's words say it changes, from the words of the client's language (L.EFFECT_*: lists of word
-- pieces, "|" between them): "amount" (damage or healing), "cost", "cast", "cooldown", "range", "crit",
-- "duration", or nil.
local KINDS = { "cost", "cast", "cooldown", "range", "crit", "duration", "amount" }
local KEYS = { amount = "EFFECT_AMOUNT", cost = "EFFECT_COST", cast = "EFFECT_CAST", cooldown = "EFFECT_COOLDOWN",
	range = "EFFECT_RANGE", crit = "EFFECT_CRIT", duration = "EFFECT_DURATION" }

local function Has(lower, key)
	for piece in (L[key] or ""):gmatch("[^|]+") do
		if lower:find(piece, 1, true) then return true end
	end
	return false
end

function ns.ChangeKind(words)
	local lower = (words or ""):lower()
	for _, kind in ipairs(KINDS) do
		if Has(lower, KEYS[kind]) then return kind end
	end
	return nil
end

-- A spell's figure after a talent's number moves from one value to another; { label, now, after, tag, unit }.
function ns.SpellEffect(now, kind, move)
	if not (kind and move) then return nil end
	local from, to, percent = move.from, move.to, move.unit == "%"
	local function Line(label, before, after, unit, tag)
		return { label = label, now = before, after = after, unit = unit or "", tag = tag or ns.TAG_CALC }
	end
	if kind == "amount" and percent then
		if not now.amount then return Line(L.EFFECT_LABEL_AMOUNT, nil, nil, "", ns.TAG_UNKNOWN) end
		local factor = (1 + to / 100) / (1 + from / 100)
		local before, after = {}, {}
		for index, value in ipairs(now.amount) do before[index], after[index] = value, value * factor end
		return Line(L.EFFECT_LABEL_AMOUNT, before, after)
	elseif kind == "cost" then
		if not now.cost then return Line(L.EFFECT_LABEL_COST, nil, nil, "", ns.TAG_UNKNOWN) end
		if percent then
			if from >= 100 then return nil end
			return Line(L.EFFECT_LABEL_COST, { now.cost }, { now.cost * (1 - to / 100) / (1 - from / 100) })
		end
		return Line(L.EFFECT_LABEL_COST, { now.cost }, { math.max(0, now.cost - (to - from)) })
	elseif kind == "cast" and not percent then
		if not now.cast then return Line(L.EFFECT_LABEL_CAST, nil, nil, L.UNIT_SEC, ns.TAG_UNKNOWN) end
		return Line(L.EFFECT_LABEL_CAST, { now.cast }, { math.max(0, now.cast - (to - from)) }, L.UNIT_SEC)
	elseif kind == "cooldown" and not percent then
		if not now.cooldown then return Line(L.EFFECT_LABEL_COOLDOWN, nil, nil, L.UNIT_SEC, ns.TAG_UNKNOWN) end
		local step = to - from
		-- (minutes when the cooldown is long and the talent speaks of a few units)
		if now.cooldown >= 120 and to < 10 then step = step * 60 end
		return Line(L.EFFECT_LABEL_COOLDOWN, { now.cooldown }, { math.max(0, now.cooldown - step) }, L.UNIT_SEC)
	elseif kind == "range" and not percent then
		if not now.range then return Line(L.EFFECT_LABEL_RANGE, nil, nil, L.UNIT_YARDS, ns.TAG_UNKNOWN) end
		return Line(L.EFFECT_LABEL_RANGE, { now.range }, { now.range + (to - from) }, L.UNIT_YARDS)
	elseif kind == "crit" and percent then
		return Line(L.EFFECT_LABEL_CRIT, nil, { to - from }, "%", ns.TAG_CALC)
	elseif kind == "duration" and not percent then
		return Line(L.EFFECT_LABEL_DURATION, nil, { to - from }, L.UNIT_SEC, ns.TAG_CALC)
	end
	return nil
end

-- A figure written: "20 to 22", "1.5", with its unit.
function ns.FigureText(values, unit)
	if not values then return "?" end
	local text = Short(values[1])
	if values[2] then text = L.RANGE_FMT:format(text, Short(values[2])) end
	if unit and unit ~= "" then text = text .. (unit == "%" and " %" or (" " .. unit)) end
	return text
end

-- A talent from one rank to another: { change (TalentChange), kind, spells = { { id, name, lines } } }; nil in a
-- fight or when the game says nothing of it yet.
function ns.TalentEffect(node, fromRank, toRank)
	if InCombatLockdown and InCombatLockdown() then return nil end
	if not node or toRank == fromRank then return nil end
	local low, high = math.min(fromRank, toRank), math.max(fromRank, toRank)
	local change = ns.TalentChange(node, low, high)
	if not change then return nil end
	local kind = ns.ChangeKind(change.words)
	local result = { change = change, kind = kind, spells = {}, down = toRank < fromRank }
	-- (the first number that moves is the one the talent is about)
	local move = change.moves[1]
	if result.down and move then move = { from = move.to, to = move.from, unit = move.unit } end
	for _, spell in ipairs(ns.SpellsTouched(node)) do
		local line = ns.SpellEffect(ns.SpellNow(spell.id), kind, move)
		result.spells[#result.spells + 1] = { id = spell.id, name = spell.name, lines = line and { line } or {} }
	end
	return result
end

-- A whole plan against your talents: for each spell the plan changes, its figures now and with the plan (the
-- changes of the same kind put together); the talents changed that name no spell of yours, by themselves.
-- { spells = { { id, name, lines } }, talents = { { node, from, to, change } } }; nil in a fight.
function ns.BuildSheet(fromRanks, toRanks)
	if InCombatLockdown and InCombatLockdown() then return nil end
	local tree = ns.TalentTreeNow()
	if not tree then return nil end
	local spells, order, talents = {}, {}, {}
	for _, node in ipairs(tree.order) do
		local from, to = fromRanks[node.id] or 0, toRanks[node.id] or 0
		if from ~= to then
			local effect = ns.TalentEffect(node, from, to)
			local named = false
			for _, spell in ipairs(effect and effect.spells or {}) do
				for _, line in ipairs(spell.lines) do
					named = true
					local entry = spells[spell.id]
					if not entry then
						entry = { id = spell.id, name = spell.name, lines = {}, byLabel = {} }
						spells[spell.id] = entry
						order[#order + 1] = entry
					end
					local same = entry.byLabel[line.label]
					if same and same.now and line.now and same.after and line.after and line.tag ~= ns.TAG_UNKNOWN then
						-- (a second change of the same figure: applied on top of the first, by the same ratio)
						for index, value in ipairs(same.after) do
							local before = line.now[index] or line.now[1]
							if before and before ~= 0 then same.after[index] = value * (line.after[index] or line.after[1]) / before end
						end
					elseif same and not same.now and same.after and line.after then
						same.after[1] = same.after[1] + line.after[1]
					elseif not same then
						local copy = { label = line.label, now = line.now, unit = line.unit, tag = line.tag }
						copy.after = line.after and { unpack(line.after) } or nil
						entry.byLabel[line.label] = copy
						entry.lines[#entry.lines + 1] = copy
					end
				end
			end
			talents[#talents + 1] = { node = node, from = from, to = to, change = effect and effect.change, named = named }
		end
	end
	return { spells = order, talents = talents }
end
