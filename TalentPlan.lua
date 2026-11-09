local _, ns = ...
local L = ns.L

-- Your talents planned: the rules of the game's tree, your plans (several, each with its note, one for each of
-- your two specializations if you want), undone and done again, seen at any level, shared as a code or a
-- Wowhead link, copied from a player you inspected, compared with another. Drawn on the game's talent window
-- (TalentPanel.lua) and in Training's own window (Talents.lua). Never a point spent for you.

local W = Wanderer
local U = W and W.Util
local Safe, Clean = U and U.Safe, U and U.Clean

local MOST = 51 -- talent points at level 60
local FIRST_LEVEL = 10 -- the first point
local LAST_LEVEL = 60
local PER_ROW = 5 -- points in a branch before its next row opens
local HISTORY = 60 -- steps kept to undo, per plan, for this session
local CODE_CHARS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

ns.TALENT_MOST, ns.TALENT_FIRST_LEVEL, ns.TALENT_LAST_LEVEL = MOST, FIRST_LEVEL, LAST_LEVEL

local tree -- the game's tree as last read: { nodes, names, byId, from, order }
local listeners = {}
local undo, redo = {}, {} -- plan -> lists of steps (this session only)

-- The tree ---------------------------------------------------------------------------------------------------

-- Your tree, read once and kept until your talents change (nil while the game shows nothing yet).
function ns.TalentTreeNow()
	if tree then return tree end
	local read = W and W.TalentTree and W.TalentTree()
	if not (read and read.nodes and #read.nodes > 0) then return nil end
	local byId, from, order = {}, {}, {}
	for _, node in ipairs(read.nodes) do
		byId[node.id] = node
		order[#order + 1] = node
	end
	for _, node in ipairs(read.nodes) do
		for _, target in ipairs(node.opens or {}) do
			from[target] = from[target] or {}
			table.insert(from[target], node.id)
		end
	end
	-- (one fixed order, branch by branch, row by row: the codes and the links count on it)
	table.sort(order, function(a, b)
		if a.branch ~= b.branch then return a.branch < b.branch end
		if a.tier ~= b.tier then return a.tier < b.tier end
		if a.column ~= b.column then return a.column < b.column end
		return a.id < b.id
	end)
	for index, node in ipairs(order) do node.index = index end
	tree = { nodes = read.nodes, names = read.names or {}, byId = byId, from = from, order = order }
	return tree
end

function ns.ForgetTalentTree() tree = nil end

-- A talent's spell: its name and icon (nil, nil when the game says nothing yet).
function ns.TalentSpell(node)
	local info = node and node.spell and C_Spell and Safe(C_Spell.GetSpellInfo, node.spell)
	if type(info) == "table" then return Clean(info.name), Clean(info.iconID) end
	return nil, nil
end

-- The rules --------------------------------------------------------------------------------------------------

-- The ranks a list of points gives: node -> ranks; the points in each branch, by row.
function ns.PlanRanks(steps, upTo)
	local ranks, rows = {}, { {}, {}, {} }
	if not tree then return ranks, rows end
	for index = 1, math.min(upTo or #steps, #steps) do
		local node = tree.byId[steps[index]]
		if node then
			ranks[node.id] = (ranks[node.id] or 0) + 1
			rows[node.branch][node.tier] = (rows[node.branch][node.tier] or 0) + 1
		end
	end
	return ranks, rows
end

-- The points a branch holds below a row.
local function Below(rows, branch, tier)
	local below = 0
	for row = 1, tier - 1 do below = below + (rows[branch][row] or 0) end
	return below
end

-- Points still missing in the branch before this talent's row opens (0: open).
function ns.GateNeed(node, rows)
	return math.max(0, PER_ROW * (node.tier - 1) - Below(rows, node.branch, node.tier))
end

-- Whether one more point can go to a node after these ranks; when not, why ("full", "most", "gate", "arrow").
function ns.PlanAllowed(node, ranks, rows, count)
	if count >= MOST then return false, "most" end
	if (ranks[node.id] or 0) >= node.most then return false, "full" end
	if ns.GateNeed(node, rows) > 0 then return false, "gate" end
	for _, before in ipairs(tree.from[node.id] or {}) do
		local need = tree.byId[before]
		if need and (ranks[before] or 0) < need.most then return false, "arrow", need end
	end
	return true
end

-- A list of points kept only as far as the rules allow it, point by point (a point taken back can close others).
function ns.PlanCheck(steps)
	local kept = {}
	if not tree then return kept end
	local ranks, rows = {}, { {}, {}, {} }
	for _, id in ipairs(steps or {}) do
		local node = tree.byId[id]
		if node and ns.PlanAllowed(node, ranks, rows, #kept) then
			kept[#kept + 1] = id
			ranks[id] = (ranks[id] or 0) + 1
			rows[node.branch][node.tier] = (rows[node.branch][node.tier] or 0) + 1
		end
	end
	return kept
end

-- Steps for a set of ranks (node -> ranks): row by row across the branches, in the order the rules allow.
function ns.StepsFromRanks(ranks)
	if not tree then return {} end
	local list = {}
	for _, node in ipairs(tree.order) do
		for _ = 1, math.min(node.most, ranks[node.id] or 0) do list[#list + 1] = node end
	end
	table.sort(list, function(a, b)
		if a.tier ~= b.tier then return a.tier < b.tier end
		return a.index < b.index
	end)
	local steps = {}
	for _, node in ipairs(list) do steps[#steps + 1] = node.id end
	-- (an arrow's target may come in the same row as its source: a second pass takes what the first refused)
	local kept = ns.PlanCheck(steps)
	if #kept < #steps then
		local left, seen = {}, {}
		for _, id in ipairs(kept) do seen[id] = (seen[id] or 0) + 1 end
		for _, id in ipairs(steps) do
			if (seen[id] or 0) > 0 then seen[id] = seen[id] - 1 else left[#left + 1] = id end
		end
		for _, id in ipairs(left) do kept[#kept + 1] = id end
		kept = ns.PlanCheck(kept)
	end
	return kept
end

-- Your own ranks, as the game has them now.
function ns.YourRanks()
	local ranks = {}
	if not tree then return ranks end
	for _, node in ipairs(tree.nodes) do ranks[node.id] = node.ranks or 0 end
	return ranks
end

-- The points of a level (0 before 10, 51 at 60).
function ns.PointsAt(level)
	return math.max(0, math.min(MOST, (level or LAST_LEVEL) - FIRST_LEVEL + 1))
end

-- The plans ---------------------------------------------------------------------------------------------------

-- This character's plans: { list = { { name, steps, note } }, chosen, forSpec = { [group] = index } }; the
-- single plan of before kept as the first.
function ns.PlanStore()
	local db = ns.DB()
	local store = type(db.talentPlans) == "table" and db.talentPlans or nil
	if not store then
		store = { list = {}, chosen = 1, forSpec = {} }
		local old = type(db.talentPlan) == "table" and db.talentPlan or {}
		store.list[1] = { name = L.PLAN_FIRST_NAME, steps = old, note = "" }
		db.talentPlans = store
		db.talentPlan = nil
	end
	store.list = type(store.list) == "table" and store.list or {}
	if #store.list == 0 then store.list[1] = { name = L.PLAN_FIRST_NAME, steps = {}, note = "" } end
	for _, plan in ipairs(store.list) do
		plan.steps = type(plan.steps) == "table" and plan.steps or {}
		plan.name = type(plan.name) == "string" and plan.name ~= "" and plan.name or L.PLAN_FIRST_NAME
		plan.note = type(plan.note) == "string" and plan.note or ""
	end
	store.forSpec = type(store.forSpec) == "table" and store.forSpec or {}
	if type(store.chosen) ~= "number" or not store.list[store.chosen] then store.chosen = 1 end
	return store
end

function ns.CurrentPlan()
	local store = ns.PlanStore()
	return store.list[store.chosen], store.chosen
end

-- The plan's points as the rules keep them (the saved list itself is changed only by your clicks, so a tree
-- read too early never cuts it).
function ns.PlanSteps()
	if not ns.TalentTreeNow() then return {} end
	return ns.PlanCheck(ns.CurrentPlan().steps)
end

-- Told when a plan changes (drawn again everywhere).
function ns.OnPlanChanged(fn) listeners[#listeners + 1] = fn end

local function Told()
	for _, fn in ipairs(listeners) do pcall(fn) end
	if ns.Draw then ns.Draw(true) end
end

local function Copy(list)
	local copy = {}
	for index, value in ipairs(list or {}) do copy[index] = value end
	return copy
end

-- A new list of points for the plan shown, the one before kept to undo.
function ns.SetPlanSteps(steps, quiet)
	local plan = ns.CurrentPlan()
	undo[plan] = undo[plan] or {}
	table.insert(undo[plan], Copy(plan.steps))
	if #undo[plan] > HISTORY then table.remove(undo[plan], 1) end
	redo[plan] = {}
	plan.steps = steps
	if not quiet then Told() end
end

function ns.CanUndo() local plan = ns.CurrentPlan() return undo[plan] ~= nil and #undo[plan] > 0 end
function ns.CanRedo() local plan = ns.CurrentPlan() return redo[plan] ~= nil and #redo[plan] > 0 end

function ns.PlanUndo()
	local plan = ns.CurrentPlan()
	if not ns.CanUndo() then return false end
	redo[plan] = redo[plan] or {}
	table.insert(redo[plan], Copy(plan.steps))
	plan.steps = table.remove(undo[plan])
	Told()
	return true
end

function ns.PlanRedo()
	local plan = ns.CurrentPlan()
	if not ns.CanRedo() then return false end
	table.insert(undo[plan], Copy(plan.steps))
	plan.steps = table.remove(redo[plan])
	Told()
	return true
end

-- One more point to a talent, as the game would allow it; false and why when not.
function ns.PlanAdd(node)
	if not ns.TalentTreeNow() then return false end
	local steps = ns.PlanSteps()
	local ranks, rows = ns.PlanRanks(steps)
	local ok, why, need = ns.PlanAllowed(node, ranks, rows, #steps)
	if not ok then return false, why, need end
	steps[#steps + 1] = node.id
	ns.SetPlanSteps(steps)
	return true
end

-- Its last point taken back, and those that needed it.
function ns.PlanRemove(node)
	if not ns.TalentTreeNow() then return false end
	local steps = Copy(ns.CurrentPlan().steps)
	for index = #steps, 1, -1 do
		if steps[index] == node.id then
			table.remove(steps, index)
			ns.SetPlanSteps(ns.PlanCheck(steps))
			return true
		end
	end
	return false
end

-- The plan started from your talents as they are.
function ns.PlanFromYours()
	if not ns.TalentTreeNow() then return false end
	ns.SetPlanSteps(ns.StepsFromRanks(ns.YourRanks()))
	return true
end

function ns.PlanClear() ns.SetPlanSteps({}) end

-- Plans, each with its name and note; the one shown changed, one for each specialization.
function ns.ChoosePlan(index)
	local store = ns.PlanStore()
	if not store.list[index] then return false end
	store.chosen = index
	Told()
	return true
end

function ns.NewPlan(name, copy)
	local store = ns.PlanStore()
	local steps = copy and Copy(ns.CurrentPlan().steps) or {}
	store.list[#store.list + 1] = { name = (name and name ~= "") and name or L.PLAN_NEW_NAME:format(#store.list + 1), steps = steps, note = "" }
	store.chosen = #store.list
	Told()
	return store.chosen
end

function ns.RenamePlan(name)
	if not (name and name ~= "") then return false end
	ns.CurrentPlan().name = name
	Told()
	return true
end

function ns.SetPlanNote(note)
	ns.CurrentPlan().note = note or ""
	Told()
end

-- The plan shown taken away (the last one is only emptied).
function ns.DeletePlan()
	local store = ns.PlanStore()
	if #store.list <= 1 then
		ns.PlanClear()
		return false
	end
	local gone = store.chosen
	table.remove(store.list, gone)
	for group, index in pairs(store.forSpec) do
		if index == gone then store.forSpec[group] = nil elseif index > gone then store.forSpec[group] = index - 1 end
	end
	store.chosen = math.max(1, math.min(gone, #store.list))
	Told()
	return true
end

-- Your specialization in use (1, or 2 with the dual specialization).
function ns.SpecGroup()
	local info = _G.C_SpecializationInfo
	local group = info and info.GetActiveSpecGroup and Clean(Safe(info.GetActiveSpecGroup))
	if not group and _G.GetActiveTalentGroup then group = Clean(Safe(_G.GetActiveTalentGroup)) end
	return tonumber(group) or 1
end

-- The plan shown tied to the specialization in use (or untied); the tied plan comes back when it is used.
function ns.TiePlanToSpec(on)
	local store = ns.PlanStore()
	local group = ns.SpecGroup()
	store.forSpec[group] = on and store.chosen or nil
	Told()
end

function ns.PlanTiedTo()
	local store = ns.PlanStore()
	for group, index in pairs(store.forSpec) do
		if index == store.chosen then return group end
	end
	return nil
end

function ns.SpecChanged()
	local store = ns.PlanStore()
	local index = store.forSpec[ns.SpecGroup()]
	if index and store.list[index] and index ~= store.chosen then
		store.chosen = index
		Told()
	end
end

-- The level seen -----------------------------------------------------------------------------------------------
-- The plan as it stands at a level (nil: all of it): the drawings and the sums stop there.

ns.viewLevel = nil

function ns.SetViewLevel(level)
	if level then level = math.max(FIRST_LEVEL, math.min(LAST_LEVEL, math.floor(level))) end
	if level == LAST_LEVEL then level = nil end
	ns.viewLevel = level
	Told()
end

-- The plan's points up to the level seen.
function ns.PlanStepsSeen()
	local steps = ns.PlanSteps()
	if not ns.viewLevel then return steps end
	local seen = {}
	for index = 1, math.min(#steps, ns.PointsAt(ns.viewLevel)) do seen[index] = steps[index] end
	return seen
end

-- The next point of the plan you have not taken: its node, its rank, the level it comes at; nil when none.
function ns.NextTalent()
	if not ns.TalentTreeNow() then return nil end
	local seen = {}
	for index, id in ipairs(ns.PlanSteps()) do
		local node = tree.byId[id]
		if node then
			seen[id] = (seen[id] or 0) + 1
			if seen[id] > (node.ranks or 0) then return node, seen[id], FIRST_LEVEL + index - 1, index end
		end
	end
	return nil
end

-- Where each talent stands in the plan: node -> { first = the plan's place of its first point not taken yet,
-- planned = its ranks in the plan seen }.
function ns.PlanPlaces()
	local places = {}
	if not ns.TalentTreeNow() then return places end
	local count = {}
	for index, id in ipairs(ns.PlanStepsSeen()) do
		local node = tree.byId[id]
		if node then
			count[id] = (count[id] or 0) + 1
			local place = places[id] or {}
			place.planned = count[id]
			if not place.first and count[id] > (node.ranks or 0) then place.first = index end
			places[id] = place
		end
	end
	return places
end

-- Your points outside the plan: talents with more ranks than the plan gives them (nil when there is no plan).
function ns.OffPlan(ranks)
	if not ns.TalentTreeNow() then return nil end
	local steps = ns.PlanSteps()
	if #steps == 0 then return nil end
	local planned = ns.PlanRanks(steps)
	local off = {}
	for _, node in ipairs(tree.order) do
		local have = (ranks or ns.YourRanks())[node.id] or 0
		if have > (planned[node.id] or 0) then off[#off + 1] = { node = node, have = have, planned = planned[node.id] or 0 } end
	end
	return off
end

-- Sharing ------------------------------------------------------------------------------------------------------

-- The plan as a code: "WT1-<class>-" then one letter per point (its talent's place in the tree), in order.
function ns.PlanCode(steps)
	if not ns.TalentTreeNow() then return nil end
	local letters = {}
	for _, id in ipairs(steps or ns.PlanSteps()) do
		local node = tree.byId[id]
		if node and node.index <= #CODE_CHARS then letters[#letters + 1] = CODE_CHARS:sub(node.index, node.index) end
	end
	return "WT1-" .. (ns.class or "?") .. "-" .. table.concat(letters)
end

-- The ranks in each branch as Wowhead writes them: one digit per talent, row by row, the zeros at the end left out.
function ns.PlanWowhead(steps)
	if not ns.TalentTreeNow() then return nil end
	local ranks = ns.PlanRanks(steps or ns.PlanSteps())
	local parts = {}
	for branch = 1, 3 do
		local digits = {}
		for _, node in ipairs(tree.order) do
			if node.branch == branch then digits[#digits + 1] = tostring(math.min(9, ranks[node.id] or 0)) end
		end
		parts[branch] = (table.concat(digits):gsub("0+$", ""))
	end
	local text = table.concat(parts, "-"):gsub("%-+$", "")
	return "https://www.wowhead.com/forever/talent-calc/" .. (ns.class or ""):lower() .. "/" .. text
end

-- A code or a link read back: the plan's points, or nil and why ("class", "empty", "unknown").
function ns.ReadPlanCode(text)
	if not ns.TalentTreeNow() then return nil, "unknown" end
	text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local class, letters = text:match("^WT1%-(%u+)%-(%w*)$")
	if class then
		if ns.class and class ~= ns.class then return nil, "class" end
		local steps = {}
		for index = 1, #letters do
			local place = CODE_CHARS:find(letters:sub(index, index), 1, true)
			local node = place and tree.order[place]
			if node then steps[#steps + 1] = node.id end
		end
		steps = ns.PlanCheck(steps)
		if #steps == 0 then return nil, "empty" end
		return steps
	end
	local who, digits = text:match("talent%-calc/(%a+)/([%d%-]+)")
	if who then
		if ns.class and who:upper() ~= ns.class then return nil, "class" end
		local ranks, branch = {}, 1
		for part in (digits .. "-"):gmatch("([^%-]*)%-") do
			local place = 0
			for _, node in ipairs(tree.order) do
				if node.branch == branch then
					place = place + 1
					local digit = tonumber(part:sub(place, place))
					if digit and digit > 0 then ranks[node.id] = digit end
				end
			end
			branch = branch + 1
			if branch > 3 then break end
		end
		local steps = ns.StepsFromRanks(ranks)
		if #steps == 0 then return nil, "empty" end
		return steps
	end
	return nil, "unknown"
end

-- Another player of your class, as last inspected: { name, ranks } (nil when none).
ns.inspected = nil

function ns.ReadInspected(unit)
	if not ns.TalentTreeNow() then return end
	local _, classFile = Safe(UnitClass, unit)
	if Clean(classFile) ~= ns.class or Clean(Safe(UnitIsUnit, unit, "player")) then return end
	local config = Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID
	if not (config and C_Traits and C_Traits.GetNodeInfo) then return end
	local ranks, total = {}, 0
	for _, node in ipairs(tree.nodes) do
		local info = Safe(C_Traits.GetNodeInfo, config, node.id)
		local have = type(info) == "table" and (Clean(info.ranksPurchased) or Clean(info.currentRank)) or 0
		if have > 0 then ranks[node.id], total = have, total + have end
	end
	if total == 0 then return end
	ns.inspected = { name = Clean(Safe(UnitName, unit)) or "?", ranks = ranks }
	Told()
end

-- Comparing ---------------------------------------------------------------------------------------------------

-- What may be compared: { key, label, ranks }: your talents, each other plan, the player inspected.
function ns.CompareChoices()
	local choices = {}
	if not ns.TalentTreeNow() then return choices end
	choices[#choices + 1] = { key = "yours", label = L.COMPARE_YOURS, ranks = ns.YourRanks() }
	local store = ns.PlanStore()
	for index, plan in ipairs(store.list) do
		if index ~= store.chosen then
			choices[#choices + 1] = { key = "plan" .. index, label = plan.name, ranks = (ns.PlanRanks(ns.PlanCheck(plan.steps))) }
		end
	end
	if ns.inspected then choices[#choices + 1] = { key = "inspected", label = ns.inspected.name, ranks = ns.inspected.ranks } end
	return choices
end

-- Two sets of ranks side by side: the talents that differ ({ node, a, b }), the points to take back to go from
-- a to b, the points to add.
function ns.CompareRanks(a, b)
	local list, back, add = {}, 0, 0
	if not ns.TalentTreeNow() then return list, back, add end
	for _, node in ipairs(tree.order) do
		local left, right = a[node.id] or 0, b[node.id] or 0
		if left ~= right then
			list[#list + 1] = { node = node, a = left, b = right }
			if left > right then back = back + left - right else add = add + right - left end
		end
	end
	return list, back, add
end
