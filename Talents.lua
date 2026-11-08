local _, ns = ...
local L = ns.L

-- Your talents planned, point by point, in the order you will take them: the three branches of your class side
-- by side as the game's talent window draws them, read from the game itself (Wanderer's TalentTree). A click
-- adds the next point to a talent (as the game would allow it: five points in a branch for each row, the talent
-- an arrow comes from full first, 51 points in all); a right click takes its last point back (and the points
-- that needed it). Your own talents in gold, the plan's in blue; under the branches, the next talent of the plan
-- and the level it comes at. Kept for each character. At a new level, the talent to take said once (an option).

local W = Wanderer
local U = W and W.Util
local Skin = W and W.Skin
local Safe, Clean = U and U.Safe, U and U.Clean

local MOST = 51 -- talent points at level 60
local FIRST_LEVEL = 10 -- the first point
local PER_ROW = 5 -- points in a branch before its next row opens
local CELL, GAP = 36, 10 -- a talent's square, the room around it
local BRANCH_GAP = 28
local PLANNED = Skin.COLORS.blue

local window, view
local tree -- the game's tree as last read: { nodes, names, byId, from (node -> the nodes leading to it) }

local Settings = ns.Settings

local function Plan()
	local db = ns.DB()
	db.talentPlan = type(db.talentPlan) == "table" and db.talentPlan or {}
	return db.talentPlan
end

local function ReadTree()
	local read = W.TalentTree and W.TalentTree()
	if not read then
		tree = nil
		return nil
	end
	local byId, from = {}, {}
	for _, node in ipairs(read.nodes) do byId[node.id] = node end
	for _, node in ipairs(read.nodes) do
		for _, target in ipairs(node.opens) do
			from[target] = from[target] or {}
			table.insert(from[target], node.id)
		end
	end
	tree = { nodes = read.nodes, names = read.names, byId = byId, from = from }
	return tree
end

-- The rules ------------------------------------------------------------------------------------------------------

-- The ranks a list of points gives: node -> ranks; the points in each branch, by row.
local function Ranks(steps, upTo)
	local ranks, rows = {}, { {}, {}, {} }
	for index = 1, upTo or #steps do
		local node = tree.byId[steps[index]]
		if node then
			ranks[node.id] = (ranks[node.id] or 0) + 1
			rows[node.branch][node.tier] = (rows[node.branch][node.tier] or 0) + 1
		end
	end
	return ranks, rows
end

-- Whether one more point can go to a node after these ranks.
local function Allowed(node, ranks, rows, count)
	if count >= MOST or (ranks[node.id] or 0) >= node.most then return false end
	local below = 0
	for tier = 1, node.tier - 1 do below = below + (rows[node.branch][tier] or 0) end
	if below < PER_ROW * (node.tier - 1) then return false end
	for _, before in ipairs(tree.from[node.id] or {}) do
		local need = tree.byId[before]
		if need and (ranks[before] or 0) < need.most then return false end
	end
	return true
end

-- The plan kept only as far as the rules allow it, point by point (a point taken back can close others).
local function Check(steps)
	local kept = {}
	local ranks, rows = {}, { {}, {}, {} }
	for _, id in ipairs(steps) do
		local node = tree.byId[id]
		if node and Allowed(node, ranks, rows, #kept) then
			kept[#kept + 1] = id
			ranks[id] = (ranks[id] or 0) + 1
			rows[node.branch][node.tier] = (rows[node.branch][node.tier] or 0) + 1
		end
	end
	return kept
end

local function SpellOf(node)
	local info = node.spell and C_Spell and Safe(C_Spell.GetSpellInfo, node.spell)
	if type(info) == "table" then return Clean(info.name), Clean(info.iconID) end
	return nil, nil
end

-- The next point of the plan you have not taken: its node, its rank, the level it comes at; nil when none.
function ns.NextTalent()
	if not (tree or ReadTree()) then return nil end
	local steps, seen = Check(Plan()), {}
	for index, id in ipairs(steps) do
		local node = tree.byId[id]
		if node then
			seen[id] = (seen[id] or 0) + 1
			if seen[id] > node.ranks then return node, seen[id], FIRST_LEVEL + index - 1 end
		end
	end
	return nil
end

-- Drawing ----------------------------------------------------------------------------------------------------

local function Draw()
	if not (window and window:IsShown()) then return end
	if not ReadTree() then
		view.empty:Show()
		for _, button in ipairs(view.buttons) do button:Hide() end
		view.footer:SetText("")
		return
	end
	view.empty:Hide()
	-- (the plan as the rules keep it, for the drawing only: saved on your clicks alone, so a tree read too early
	-- never cuts it)
	local steps = Check(Plan())
	local ranks, rows = Ranks(steps)
	-- The branches side by side: each as wide as its columns.
	local columns, tiers = { 0, 0, 0 }, 0
	for _, node in ipairs(tree.nodes) do
		columns[node.branch] = math.max(columns[node.branch], node.column)
		tiers = math.max(tiers, node.tier)
	end
	local left = { 0 }
	for branch = 2, 3 do left[branch] = left[branch - 1] + columns[branch - 1] * (CELL + GAP) + BRANCH_GAP end
	for branch = 1, 3 do
		local title = view.titles[branch]
		local points = 0
		for _, node in ipairs(tree.nodes) do if node.branch == branch then points = points + (ranks[node.id] or 0) end end
		title:SetText((tree.names[branch] or tostring(branch)) .. "  " .. Skin.Colorize(points, "muted"))
		title:ClearAllPoints()
		title:SetPoint("TOPLEFT", view, "TOPLEFT", left[branch], 0)
	end
	for index, node in ipairs(tree.nodes) do
		local button = view.buttons[index] or view.MakeButton()
		view.buttons[index] = button
		button.node = node
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", view, "TOPLEFT", left[node.branch] + (node.column - 1) * (CELL + GAP), -(26 + (node.tier - 1) * (CELL + GAP)))
		local _, icon = SpellOf(node)
		button.icon:SetTexture(icon or 134400)
		local have, plan = node.ranks, ranks[node.id] or 0
		local open = Allowed(node, ranks, rows, #steps) or plan > 0 or have > 0
		button.icon:SetDesaturated(not open)
		button.icon:SetAlpha(open and 1 or 0.45)
		if have > 0 then
			button.edges.Color(Skin.COLORS.gold[1], Skin.COLORS.gold[2], Skin.COLORS.gold[3], 0.9)
		elseif plan > 0 then
			button.edges.Color(PLANNED[1], PLANNED[2], PLANNED[3], 0.9)
		else
			button.edges.Color(1, 1, 1, 0.15)
		end
		local shown = math.max(have, plan)
		button.rank:SetText(shown > 0 and (shown .. "/" .. node.most) or "")
		if plan > have then button.rank:SetTextColor(PLANNED[1], PLANNED[2], PLANNED[3]) else button.rank:SetTextColor(Skin.COLORS.gold[1], Skin.COLORS.gold[2], Skin.COLORS.gold[3]) end
		button:Show()
	end
	for index = #tree.nodes + 1, #view.buttons do view.buttons[index]:Hide() end
	view:SetSize(left[3] + columns[3] * (CELL + GAP), 26 + tiers * (CELL + GAP))
	window:SetSize(view:GetWidth() + Skin.Margin() * 2 + 16, view:GetHeight() + 160)
	-- Under the branches: the plan's count, the next talent.
	local node, rank, level = ns.NextTalent()
	local parts = { L.PLAN_POINTS:format(#steps, MOST) }
	if node then
		local name = SpellOf(node) or "?"
		parts[#parts + 1] = L.PLAN_NEXT:format(name, rank, level)
	end
	view.footer:SetText(table.concat(parts, U.SEPARATOR))
end

-- The plan kept: drawn here and on the book's page (its link says whether one is planned).
local function Save(steps)
	ns.DB().talentPlan = steps
	Draw()
	ns.Draw(true)
end

local function Add(node)
	local steps = Check(Plan())
	local ranks, rows = Ranks(steps)
	if Allowed(node, ranks, rows, #steps) then
		steps[#steps + 1] = node.id
		Skin.Play("click")
		return Save(steps)
	end
	Skin.Play("refuse")
end

-- Its last point taken back, and those that needed it.
local function Remove(node)
	local steps = Plan()
	for index = #steps, 1, -1 do
		if steps[index] == node.id then
			table.remove(steps, index)
			break
		end
	end
	Save(Check(steps))
end

-- The plan started from your talents as they are: row by row in each branch, the order the rules allow.
local function FromYours()
	if not (tree or ReadTree()) then return end
	local list = {}
	for _, node in ipairs(tree.nodes) do
		for _ = 1, node.ranks do list[#list + 1] = node end
	end
	table.sort(list, function(a, b)
		if a.tier ~= b.tier then return a.tier < b.tier end
		if a.branch ~= b.branch then return a.branch < b.branch end
		return a.column < b.column
	end)
	local steps = {}
	for _, node in ipairs(list) do steps[#steps + 1] = node.id end
	Save(Check(steps))
end

local function Create()
	window = Skin.CreateWindow("WandererTrainingTalents", "MEDIUM")
	Skin.Sounds(window, Skin.SOUNDS.open, Skin.SOUNDS.close)
	Skin.Dress(window, { "CENTER", UIParent, "CENTER", 0, 40 }, "trainingTalentsPos")
	local _, title, margin = ns.Header(window, L.PLAN_TITLE)
	view = CreateFrame("Frame", nil, window)
	view:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 8, -16)
	view.titles, view.buttons = {}, {}
	for branch = 1, 3 do view.titles[branch] = Skin.Text(view, "GameFontNormal", "gold") end
	function view.MakeButton()
		local button = CreateFrame("Button", nil, view)
		button:SetSize(CELL, CELL)
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetPoint("TOPLEFT", 1, -1)
		button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
		button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		button.edges = Skin.Edges(button, 1, 1, 1, 0.15)
		button.rank = Skin.CreateText(button, "NumberFontNormalSmall")
		button.rank:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, -4)
		local hover = button:CreateTexture(nil, "HIGHLIGHT")
		hover:SetAllPoints(button.icon)
		hover:SetColorTexture(1, 1, 1, 0.12)
		button:SetScript("OnClick", function(self, mouse)
			if mouse == "RightButton" then Remove(self.node) else Add(self.node) end
		end)
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if self.node.spell then GameTooltip:SetSpellByID(self.node.spell) else GameTooltip:AddLine("?") end
			GameTooltip:AddLine(L.PLAN_TIP, Skin.COLORS.blue[1], Skin.COLORS.blue[2], Skin.COLORS.blue[3], true)
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function() GameTooltip:Hide() end)
		return button
	end
	view.empty = Skin.Text(window, "GameTooltipText", "muted")
	view.empty:SetPoint("TOP", window, "TOP", 0, -120)
	view.empty:SetText(L.PLAN_NONE)
	view.footer = Skin.Text(window, "GameTooltipText", "text")
	view.footer:SetPoint("TOPLEFT", view, "BOTTOMLEFT", 0, -10)
	view.footer:SetJustifyH("LEFT")
	local yours = Skin.Button(window, L.PLAN_FROM_YOURS, FromYours)
	yours:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", margin, margin)
	Skin.Tooltip(yours, L.PLAN_FROM_YOURS_DESC)
	local clear = Skin.Button(window, L.PLAN_CLEAR, function()
		Skin.Ask(L.PLAN_CLEAR_ASK, function()
			Save({})
		end)
	end)
	clear:SetPoint("LEFT", yours, "RIGHT", 8, 0)
	-- (its foot full of buttons: the "?" in the heading)
	Skin.Help(window, L.PLAN_HELP, "HEADING")
	window:SetSize(720, 520)
	window:HookScript("OnShow", function(self)
		self:SetScale(Skin.FitScale(self))
		Draw()
	end)
	window:HookScript("OnSizeChanged", function()
		local skin = Skin.Get(window)
		if skin then skin:Layout() end
	end)
	Skin.Get(window):Layout()
end

function ns.ToggleTalents()
	if not window then Create() end
	window:SetShown(not window:IsShown())
end

-- Your talents changed (a point spent, a reset): drawn again; at a new level, the talent to take said once.
function ns.TalentsChanged()
	tree = nil
	Draw()
end

function ns.TalentsAtLevel(level)
	local settings = Settings()
	if not (settings and settings.talentsReminder and level and level >= FIRST_LEVEL) then return end
	local node, rank, at = ns.NextTalent()
	if not (node and at <= level) then return end
	-- (every point already spent elsewhere: nothing to take now)
	local free = U.Clean(U.Safe(UnitCharacterPoints, "player"))
	if free and free < 1 then return end
	local name, icon = SpellOf(node)
	W.Toast(L.PLAN_TOAST:format(name or "?"), L.PLAN_TOAST_TEXT:format(rank, tree.names[node.branch] or ""),
		{ kicker = "Wanderer", duration = 6, icon = icon })
end
