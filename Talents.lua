local _, ns = ...
local L = ns.L

-- Your talents planned, in Training's own window: the three branches of your class side by side as the game's
-- talent window draws them, read from the game itself (TalentPlan.lua has the rules and the plans). A click adds
-- the next point to a talent, a right click takes its last point back (and the points that needed it). Your own
-- talents in gold, the plan's in blue. This window comes when the game's talent window cannot (in a fight);
-- otherwise the game's window opens, with the calculator beside it (TalentPanel.lua). At a new level, the talent
-- to take is said once, after the fight if there is one (an option): a click opens the calculator.

local W = Wanderer
local U = W and W.Util
local Skin = W and W.Skin

local CELL, GAP = 36, 10 -- a talent's square, the room around it
local BRANCH_GAP = 28
local PLANNED = Skin.COLORS.blue

local window, view

local Settings = ns.Settings

local SpellOf = ns.TalentSpell

local function Draw()
	if not (window and window:IsShown()) then return end
	local tree = ns.TalentTreeNow()
	if not tree then
		view.empty:Show()
		for _, button in ipairs(view.buttons) do button:Hide() end
		view.footer:SetText("")
		return
	end
	view.empty:Hide()
	local steps = ns.PlanStepsSeen()
	local ranks, rows = ns.PlanRanks(steps)
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
		local have, plan = node.ranks or 0, ranks[node.id] or 0
		local open = ns.PlanAllowed(node, ranks, rows, #steps) or plan > 0 or have > 0
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
	-- Under the branches: the plan's name and count, the next talent.
	local node, rank, level = ns.NextTalent()
	local parts = { ns.CurrentPlan().name, L.PLAN_POINTS:format(#ns.PlanSteps(), ns.TALENT_MOST) }
	if node then parts[#parts + 1] = L.PLAN_NEXT:format(SpellOf(node) or "?", rank, level) end
	view.footer:SetText(table.concat(parts, U.SEPARATOR))
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
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp") button.padRight = true
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
			local ok
			if mouse == "RightButton" then ok = ns.PlanRemove(self.node) else ok = ns.PlanAdd(self.node) end
			Skin.Play(ok and "click" or "refuse")
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
	local yours = Skin.Button(window, L.PLAN_FROM_YOURS, function() ns.PlanFromYours() end)
	yours:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", margin, margin)
	Skin.Tooltip(yours, L.PLAN_FROM_YOURS_DESC)
	local clear = Skin.Button(window, L.PLAN_CLEAR, function()
		Skin.Ask(L.PLAN_CLEAR_ASK, function() ns.PlanClear() end)
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
	ns.OnPlanChanged(Draw)
end

-- The game's talent window with the calculator; Training's own window when the game's cannot open (a fight).
function ns.ToggleTalents()
	if window and window:IsShown() then return window:Hide() end
	if ns.OpenTalentCalculator and ns.OpenTalentCalculator() then return end
	if not window then Create() end
	window:Show()
end

-- Your talents changed (a point spent, a reset, a specialization): read again and drawn again.
function ns.TalentsChanged()
	ns.ForgetTalentTree()
	Draw()
	if ns.DrawTalentsEverywhere then ns.DrawTalentsEverywhere() end
end

-- At a new level with a point to spend: the talent the plan takes next, said once (after the fight).
function ns.TalentsAtLevel(level)
	local settings = Settings()
	if not (settings and settings.talentsReminder and level and level >= ns.TALENT_FIRST_LEVEL) then return end
	local node, rank, at = ns.NextTalent()
	if not (node and at <= level) then return end
	-- (every point already spent elsewhere: nothing to take now)
	local free = U.Clean(U.Safe(UnitCharacterPoints, "player"))
	if free and free < 1 then return end
	local name, icon = SpellOf(node)
	local tree = ns.TalentTreeNow()
	W.Toast(L.PLAN_TOAST:format(name or "?"), L.PLAN_TOAST_TEXT:format(rank, tree and tree.names[node.branch] or ""),
		{ kicker = "Wanderer", duration = 8, icon = icon, wait = 120, onClick = function() ns.ToggleTalents() end, hint = L.PLAN_TOAST_HINT })
end
