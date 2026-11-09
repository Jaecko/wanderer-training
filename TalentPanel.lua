local _, ns = ...
local L = ns.L

-- Your talents planned, on the game's own talent window. Over each talent: its place in your plan (#12), the
-- ranks the plan gives it (blue), a tick once you took them, a fixed blue frame on the next one to take.
-- "Simulate" puts the plan under your clicks (left: one more point, right: one less) without spending anything:
-- the game's talents are not touched. Beside the window, the calculator: what the talent under the mouse really
-- changes in your own numbers (now, with one more point, at its last rank), the whole plan against your talents,
-- your plans (notes, one per specialization, undo), the level seen, a search of the talents naming a word, a
-- comparison (your talents, another plan, a player inspected), the codes to share. A point you are about to
-- apply outside the plan is said over the game's Apply button. Nothing in a fight, never a point spent for you.

local W = Wanderer
local U = W and W.Util
local Skin = W and W.Skin
local Safe, Clean = U and U.Safe, U and U.Clean

local PANEL_WIDTH = 360
local BLUE = Skin and Skin.COLORS.blue or { 0.61, 0.78, 0.96 }
local GOLD = Skin and Skin.COLORS.gold or { 1, 0.82, 0 }

local frame -- the game's talent window (PlayerSpellsFrame.TalentsFrame)
local overlay, badges, catchers = nil, {}, {}
local hooked = setmetatable({}, { __mode = "k" })
local panel, view
local simulating = false
local hovered -- the talent under the mouse
local searched = ""
local tab = "order"
local pointed -- the talent under the mouse in the order's list (framed in gold on the tree)
local ROW = 24
local compareWith = "yours"

local Settings = ns.Settings

local function Talents()
	local spells = _G.PlayerSpellsFrame
	local talents = type(spells) == "table" and spells.TalentsFrame
	if type(talents) == "table" and type(talents.HookScript) == "function" and type(talents.GetTalentButtonByNodeID) == "function" then return talents end
	return nil
end
local function InFight() return InCombatLockdown and InCombatLockdown() end
local function On() local settings = Settings() return settings ~= nil end

local function SpellName(node) return (ns.TalentSpell(node)) or "?" end
local function SpellIcon(node) return select(2, ns.TalentSpell(node)) or 134400 end

local function ButtonFor(node)
	if not frame then return nil end
	local button = Safe(frame.GetTalentButtonByNodeID, frame, node.id)
	if type(button) == "table" and button.IsShown and button:IsShown() then return button end
	return nil
end

local function ShowEdges(edges, on)
	for _, edge in ipairs(edges) do edge:SetShown(on and true or false) end
end

-- Over the game's talents ------------------------------------------------------------------------------------

local function Badge(node)
	local badge = badges[node.id]
	if badge then return badge end
	badge = CreateFrame("Frame", nil, overlay)
	badge.order = Skin.Text(badge, "NumberFontNormalSmall", "kicker")
	badge.order:SetPoint("TOPLEFT", badge, "TOPLEFT", -6, 6)
	badge.planned = Skin.CreateText(badge, "NumberFontNormal", BLUE[1], BLUE[2], BLUE[3])
	badge.planned:SetPoint("BOTTOMLEFT", badge, "BOTTOMLEFT", -6, -6)
	badge.done = Skin.Glyph(badge, "check", 14, "OVERLAY")
	badge.done:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
	badge.done:SetPoint("TOPRIGHT", badge, "TOPRIGHT", 6, 6)
	badge.next = Skin.Edges(badge, BLUE[1], BLUE[2], BLUE[3], 1)
	badge.nextFill = badge:CreateTexture(nil, "OVERLAY")
	badge.nextFill:SetAllPoints()
	badge.nextFill:SetColorTexture(BLUE[1], BLUE[2], BLUE[3], 0.28)
	badge.nextOuter = CreateFrame("Frame", nil, badge)
	badge.nextOuter:SetPoint("TOPLEFT", -3, 3)
	badge.nextOuter:SetPoint("BOTTOMRIGHT", 3, -3)
	badge.nextOuterEdges = Skin.Edges(badge.nextOuter, BLUE[1], BLUE[2], BLUE[3], 0.7)
	badge.nextLabel = Skin.CreateText(badge, "GameFontNormalSmall", BLUE[1], BLUE[2], BLUE[3])
	badge.nextLabel:SetPoint("BOTTOM", badge, "TOP", 0, 6)
	badge.nextLabel:SetText(L.NEXT_POINT)
	badge.found = Skin.Edges(badge, GOLD[1], GOLD[2], GOLD[3], 0.95)
	badges[node.id] = badge
	return badge
end

local function Catcher(node)
	local catcher = catchers[node.id]
	if catcher then return catcher end
	catcher = CreateFrame("Button", nil, overlay)
	catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp") catcher.padRight = true
	local hover = catcher:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	hover:SetColorTexture(BLUE[1], BLUE[2], BLUE[3], 0.18)
	catcher:SetScript("OnClick", function(self, mouse)
		if mouse == "RightButton" then
			if ns.PlanRemove(self.node) then Skin.Play("click") else Skin.Play("refuse") end
			return
		end
		local ok, why, need = ns.PlanAdd(self.node)
		if ok then return Skin.Play("click") end
		Skin.Play("refuse")
		ns.SayRefused(self.node, why, need)
	end)
	catcher:SetScript("OnEnter", function(self)
		ns.HoverTalent(self.node)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if self.node.spell then pcall(GameTooltip.SetSpellByID, GameTooltip, self.node.spell) end
		GameTooltip:AddLine(L.SIM_TIP, BLUE[1], BLUE[2], BLUE[3], true)
		GameTooltip:Show()
	end)
	catcher:SetScript("OnLeave", function()
		GameTooltip:Hide()
		ns.HoverTalent(nil)
	end)
	catchers[node.id] = catcher
	return catcher
end

-- The game's talent under the mouse, told to the calculator (its own clicks left alone).
local function Hook(button)
	if hooked[button] then return end
	hooked[button] = true
	button:HookScript("OnEnter", function(self)
		if simulating then return end
		local id = Clean(Safe(self.GetNodeID, self))
		local tree = ns.TalentTreeNow()
		if id and tree and tree.byId[id] then ns.HoverTalent(tree.byId[id]) end
	end)
	button:HookScript("OnLeave", function() if not simulating then ns.HoverTalent(nil) end end)
end

local function Found()
	local set = {}
	if searched ~= "" then
		for _, node in ipairs(ns.TalentsNaming(searched)) do set[node.id] = true end
	end
	return set
end

function ns.DrawOverlay()
	if not (overlay and frame and frame:IsShown()) then return end
	local tree = On() and ns.TalentTreeNow()
	if not tree then
		for _, badge in pairs(badges) do badge:Hide() end
		for _, catcher in pairs(catchers) do catcher:Hide() end
		return
	end
	local places = ns.PlanPlaces()
	local nextNode = ns.NextTalent()
	local found = Found()
	local settings = Settings() or {}
	local marks = settings.talentsMarks ~= false
	for _, node in ipairs(tree.order) do
		local button = ButtonFor(node)
		local badge, catcher = Badge(node), simulating and Catcher(node) or catchers[node.id]
		if button then
			Hook(button)
			local level = (button:GetFrameLevel() or 1) + 8
			badge:ClearAllPoints()
			badge:SetAllPoints(button)
			badge:SetFrameLevel(level)
			local place = places[node.id]
			local have = node.ranks or 0
			local planned = place and place.planned or 0
			badge.order:SetText(marks and place and place.first and ("#" .. place.first) or "")
			if (simulating or marks) and planned > have then
				badge.planned:SetText(planned .. "/" .. node.most)
			elseif simulating and planned > 0 then
				badge.planned:SetText(planned .. "/" .. node.most)
			else
				badge.planned:SetText("")
			end
			badge.done:SetShown(marks and planned > 0 and have >= planned)
			local isNext = marks and nextNode == node and not ns.viewLevel
			ShowEdges(badge.next, isNext)
			ShowEdges(badge.nextOuterEdges, isNext)
			badge.nextFill:SetShown(isNext)
			badge.nextLabel:SetShown(isNext)
			ShowEdges(badge.found, found[node.id] == true or pointed == node)
			badge:Show()
			if catcher then
				catcher:ClearAllPoints()
				catcher:SetAllPoints(button)
				catcher:SetFrameLevel(level + 1)
				catcher.node = node
				catcher:SetShown(simulating)
			end
		else
			badge:Hide()
			if catcher then catcher:Hide() end
		end
	end
end

-- The guard: what you are about to apply that the plan does not take, said over the game's Apply button.
local function Guard()
	if not (panel and frame and frame.ApplyButton) then return end
	local settings = Settings()
	local config = Clean(Safe(frame.GetConfigID, frame))
	local text
	if settings and settings.talentsGuard ~= false and config and not simulating and ns.TalentTreeNow() and C_Traits then
		local staged = Clean(Safe(C_Traits.ConfigHasStagedChanges, config))
		if staged then
			-- (the rank about to be applied against the one in force: only the new points outside the plan)
			local ranks, applied = {}, {}
			for _, node in ipairs(ns.TalentTreeNow().nodes) do
				local info = Safe(C_Traits.GetNodeInfo, config, node.id)
				if type(info) == "table" then
					ranks[node.id] = Clean(info.currentRank) or Clean(info.ranksPurchased) or 0
					applied[node.id] = Clean(info.activeRank) or 0
				end
			end
			local names = {}
			for _, entry in ipairs(ns.OffPlan(ranks) or {}) do
				if entry.have > (applied[entry.node.id] or 0) then names[#names + 1] = SpellName(entry.node) end
			end
			if #names > 0 then text = L.GUARD_OFF:format(table.concat(names, ", ")) end
		end
	end
	view.guard:SetText(text or "")
	view.guard:SetShown(text ~= nil)
end

-- The calculator beside the window ----------------------------------------------------------------------------

local function Tag(tag)
	if tag == ns.TAG_READ then return Skin.Colorize(L.TAG_READ, "good") end
	if tag == ns.TAG_UNKNOWN then return Skin.Colorize(L.TAG_UNKNOWN, "muted") end
	return Skin.Colorize(L.TAG_CALC, "blue")
end

local function LineText(line)
	if line.now and line.after then
		return L.EFFECT_LINE:format(line.label, ns.FigureText(line.now, line.unit), Skin.Colorize(ns.FigureText(line.after, line.unit), "gold")) .. "  " .. Tag(line.tag)
	elseif line.after then
		local value = line.after[1] or 0
		return L.EFFECT_GAIN:format(line.label, Skin.Colorize((value >= 0 and "+" or "") .. ns.FigureText(line.after, line.unit), "gold")) .. "  " .. Tag(line.tag)
	end
	return line.label .. "  " .. Tag(ns.TAG_UNKNOWN)
end

-- What a talent does from one rank to another, as lines.
local function EffectLines(lines, node, from, to, caption)
	local effect = ns.TalentEffect(node, from, to)
	if not effect then return end
	lines[#lines + 1] = " "
	lines[#lines + 1] = Skin.Colorize(caption, "kicker")
	lines[#lines + 1] = effect.change.text .. "  " .. Tag(ns.TAG_READ)
	for _, spell in ipairs(effect.spells) do
		for _, line in ipairs(spell.lines) do lines[#lines + 1] = Skin.Colorize(spell.name, "text") .. " · " .. LineText(line) end
		if #spell.lines == 0 then lines[#lines + 1] = Skin.Colorize(spell.name, "text") .. " · " .. Skin.Colorize(L.EFFECT_NAMED, "muted") end
	end
end

-- Why a point cannot go to a talent, in words (rows: the plan's points by row).
local function RefusalText(node, why, need, rows)
	if why == "gate" then return L.GATE_NEED:format(ns.GateNeed(node, rows), (ns.TalentTreeNow().names[node.branch] or "")) end
	if why == "arrow" and need then return L.GATE_ARROW:format(SpellName(need)) end
	if why == "most" then return L.GATE_MOST end
	if why == "full" then return L.GATE_FULL end
	return nil
end

local function WhyClosed(node, ranks, rows, count)
	local ok, why, need = ns.PlanAllowed(node, ranks, rows, count)
	if ok or why == "full" then return nil end
	return RefusalText(node, why, need, rows)
end

local function DrawEffects(lines)
	local node = hovered
	local steps = ns.PlanStepsSeen()
	local planned = ns.PlanRanks(steps)
	if not node then
		local nextNode, rank, level = ns.NextTalent()
		if not nextNode then
			lines[#lines + 1] = Skin.Colorize(L.EFFECTS_HINT, "soft")
			return
		end
		lines[#lines + 1] = Skin.Colorize(L.EFFECTS_NEXT:format(level), "kicker")
		node = nextNode
		lines[#lines + 1] = ("|T%s:18|t  %s  %s"):format(SpellIcon(node), Skin.Colorize(SpellName(node), "gold"), Skin.Colorize(L.RANK_OF:format(rank, node.most), "muted"))
		EffectLines(lines, node, rank - 1, rank, L.EFFECTS_THIS_POINT)
		lines[#lines + 1] = " "
		lines[#lines + 1] = Skin.Colorize(L.EFFECTS_HINT, "muted")
		return
	end
	local have, plan = node.ranks or 0, planned[node.id] or 0
	lines[#lines + 1] = ("|T%s:18|t  %s"):format(SpellIcon(node), Skin.Colorize(SpellName(node), "gold"))
	local rankLine = L.RANK_YOURS:format(have, node.most)
	if plan ~= have then rankLine = rankLine .. U.SEPARATOR .. Skin.Colorize(L.RANK_PLAN:format(plan, node.most), "blue") end
	lines[#lines + 1] = Skin.Colorize(rankLine, "muted")
	if have < node.most then
		EffectLines(lines, node, have, have + 1, L.EFFECTS_ONE_MORE)
		if node.most > have + 1 then EffectLines(lines, node, have, node.most, L.EFFECTS_AT_MOST:format(node.most)) end
	else
		local words = ns.TalentText(node, node.most)
		if words then
			lines[#lines + 1] = " "
			lines[#lines + 1] = Skin.Colorize(L.EFFECTS_FULL, "kicker")
			lines[#lines + 1] = words
		end
	end
	if plan ~= have and plan ~= have + 1 and plan ~= node.most then EffectLines(lines, node, have, plan, L.EFFECTS_WITH_PLAN:format(plan)) end
	local ranks, rows = ns.PlanRanks(steps)
	local why = WhyClosed(node, ranks, rows, #steps)
	if why then
		lines[#lines + 1] = " "
		lines[#lines + 1] = Skin.Colorize(why, "warn")
	end
end

local function SheetLines(lines, fromRanks, toRanks, emptyText)
	local sheet = ns.BuildSheet(fromRanks, toRanks)
	if not sheet or (#sheet.spells == 0 and #sheet.talents == 0) then
		lines[#lines + 1] = Skin.Colorize(emptyText, "soft")
		return
	end
	if #sheet.spells > 0 then
		lines[#lines + 1] = Skin.Colorize(L.SHEET_SPELLS, "kicker")
		for _, spell in ipairs(sheet.spells) do
			lines[#lines + 1] = ("|T%s:16|t  %s"):format((C_Spell and Clean(Safe(C_Spell.GetSpellTexture, spell.id))) or 134400, Skin.Colorize(spell.name, "gold"))
			for _, line in ipairs(spell.lines) do lines[#lines + 1] = "    " .. LineText(line) end
		end
		lines[#lines + 1] = " "
	end
	lines[#lines + 1] = Skin.Colorize(L.SHEET_TALENTS, "kicker")
	for _, entry in ipairs(sheet.talents) do
		local role = entry.to > entry.from and "good" or "bad"
		lines[#lines + 1] = Skin.Colorize(SpellName(entry.node), "text") .. "  " .. Skin.Colorize(entry.from .. " → " .. entry.to, role)
		if entry.change and not entry.named then lines[#lines + 1] = Skin.Colorize("    " .. entry.change.text, "soft") end
	end
end

local function DrawBuild(lines)
	local steps = ns.PlanStepsSeen()
	lines[#lines + 1] = Skin.Colorize(L.BUILD_HEAD:format(#steps, ns.viewLevel or ns.TALENT_LAST_LEVEL), "soft")
	lines[#lines + 1] = " "
	SheetLines(lines, ns.YourRanks(), (ns.PlanRanks(steps)), L.BUILD_SAME)
end

local function DrawCompare(lines)
	local chosen
	for _, choice in ipairs(ns.CompareChoices()) do
		if choice.key == compareWith then chosen = choice end
	end
	if not chosen then
		compareWith = "yours"
		return DrawCompare(lines)
	end
	local mine = ns.PlanRanks(ns.PlanStepsSeen())
	local list, back, add = ns.CompareRanks(chosen.ranks, mine)
	lines[#lines + 1] = Skin.Colorize(L.COMPARE_HEAD:format(chosen.label, ns.CurrentPlan().name), "soft")
	if #list == 0 then
		lines[#lines + 1] = " "
		lines[#lines + 1] = Skin.Colorize(L.COMPARE_SAME, "good")
		return
	end
	lines[#lines + 1] = Skin.Colorize(L.COMPARE_MOVES:format(back, add), "gold")
	lines[#lines + 1] = " "
	for _, entry in ipairs(list) do
		local role = entry.b > entry.a and "good" or "bad"
		lines[#lines + 1] = Skin.Colorize(SpellName(entry.node), "text") .. "  " .. Skin.Colorize(entry.a .. " → " .. entry.b, role)
	end
	lines[#lines + 1] = " "
	SheetLines(lines, chosen.ranks, mine, L.BUILD_SAME)
end

local function DrawPlans(lines)
	local plan = ns.CurrentPlan()
	lines[#lines + 1] = Skin.Colorize(plan.name, "gold")
	local tied = ns.PlanTiedTo()
	if tied then lines[#lines + 1] = Skin.Colorize(L.PLAN_TIED:format(tied), "blue") end
	lines[#lines + 1] = Skin.Colorize(L.PLAN_POINTS:format(#ns.PlanSteps(), ns.TALENT_MOST), "soft")
	lines[#lines + 1] = " "
	lines[#lines + 1] = plan.note ~= "" and plan.note or Skin.Colorize(L.PLAN_NO_NOTE, "muted")
end

local function DrawShare(lines)
	lines[#lines + 1] = Skin.Colorize(L.SHARE_HELP, "soft")
	if ns.inspected then
		lines[#lines + 1] = " "
		lines[#lines + 1] = Skin.Colorize(L.SHARE_INSPECTED:format(ns.inspected.name), "blue")
	end
end

local function OrderRow(index)
	local row = view.orderRows[index]
	if row then return row end
	row = CreateFrame("Button", nil, view.content)
	row:SetHeight(ROW - 2)
	row.ground = row:CreateTexture(nil, "BACKGROUND")
	row.ground:SetAllPoints()
	row.bar = row:CreateTexture(nil, "ARTWORK")
	row.bar:SetPoint("TOPLEFT")
	row.bar:SetPoint("BOTTOMLEFT")
	row.bar:SetWidth(3)
	row.bar:SetColorTexture(BLUE[1], BLUE[2], BLUE[3], 1)
	row.level = Skin.Text(row, "GameFontHighlightSmall", "muted")
	row.level:SetPoint("LEFT", row, "LEFT", 8, 0)
	row.level:SetWidth(54)
	row.level:SetJustifyH("LEFT")
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(18, 18)
	row.icon:SetPoint("LEFT", row.level, "RIGHT", 4, 0)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	row.name = Skin.Text(row, "GameFontHighlightSmall", "text")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
	row.name:SetPoint("RIGHT", row, "RIGHT", -46, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.rank = Skin.Text(row, "GameFontHighlightSmall", "soft")
	row.rank:SetPoint("RIGHT", row, "RIGHT", -22, 0)
	row.done = Skin.Glyph(row, "check", 12)
	row.done:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.done:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
	local hover = row:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	hover:SetColorTexture(1, 1, 1, 0.06)
	row:SetScript("OnEnter", function(self)
		pointed = self.node
		ns.DrawOverlay()
	end)
	row:SetScript("OnLeave", function()
		pointed = nil
		ns.DrawOverlay()
	end)
	view.orderRows[index] = row
	return row
end

-- The plan's points in the order to take them: level, talent, rank; taken ticked and quiet, the next one lit.
local function DrawOrder()
	local tree = ns.TalentTreeNow()
	local steps = ns.PlanSteps()
	local _, _, _, nextIndex = ns.NextTalent()
	local seen = {}
	for index, id in ipairs(steps) do
		local node = tree.byId[id]
		local row = OrderRow(index)
		seen[id] = (seen[id] or 0) + 1
		local rank = seen[id]
		local taken = rank <= (node.ranks or 0)
		local isNext = index == nextIndex
		local beyond = ns.viewLevel and index > ns.PointsAt(ns.viewLevel)
		row.node = node
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", view.content, "TOPLEFT", 0, -(index - 1) * ROW)
		row:SetPoint("RIGHT", view.content, "RIGHT", 0, 0)
		row.level:SetText(L.ORDER_LEVEL:format(ns.TALENT_FIRST_LEVEL + index - 1))
		row.icon:SetTexture(SpellIcon(node))
		row.icon:SetDesaturated(taken)
		row.name:SetText(SpellName(node))
		row.rank:SetText(rank .. "/" .. node.most)
		row.done:SetShown(taken)
		row.bar:SetShown(isNext)
		if isNext then
			row.ground:SetColorTexture(BLUE[1], BLUE[2], BLUE[3], 0.16)
			row.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		else
			row.ground:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.025 or 0)
			local c = Skin.COLORS[taken and "muted" or "text"]
			row.name:SetTextColor(c[1], c[2], c[3])
		end
		row:SetAlpha(beyond and 0.4 or 1)
		row:Show()
	end
	for index = #steps + 1, #view.orderRows do view.orderRows[index]:Hide() end
	view.orderHeight = #steps * ROW
	-- (the next point brought into sight when the next one changed)
	if nextIndex and view.orderNext ~= nextIndex then
		view.orderNext = nextIndex
		view.scrollTo = math.max(0, (nextIndex - 3) * ROW)
	end
end

local TABS = { effects = DrawEffects, build = DrawBuild, compare = DrawCompare, plans = DrawPlans, share = DrawShare }

function ns.DrawTalentPanel()
	if not (panel and panel:IsShown()) then return end
	local lines = {}
	local rows = false
	if InFight() then
		lines[1] = Skin.Colorize(L.TALENTS_FIGHT, "muted")
	elseif not ns.TalentTreeNow() then
		lines[1] = Skin.Colorize(L.PLAN_NONE, "muted")
	elseif tab == "order" then
		if #ns.PlanSteps() == 0 then
			lines[1] = Skin.Colorize(L.ORDER_EMPTY, "soft")
		else
			rows = true
			DrawOrder()
		end
	else
		TABS[tab](lines)
	end
	if not rows then
		for _, row in ipairs(view.orderRows) do row:Hide() end
	end
	view.body:SetShown(not rows)
	view.body:SetText(rows and "" or table.concat(lines, "\n"))
	view.body:SetHeight(math.max(20, U.Measure(view.body, "GetStringHeight", 20)))
	view.contentHeight = rows and view.orderHeight or view.body:GetHeight()
	view.content:SetHeight(math.max(20, view.contentHeight))
	local most = math.max(0, view.contentHeight - view.scroll:GetHeight())
	if rows and view.scrollTo then
		view.scroll:SetVerticalScroll(math.min(most, view.scrollTo))
		view.scrollTo = nil
	else
		view.scroll:SetVerticalScroll(math.min(view.scroll:GetVerticalScroll(), most))
	end
	-- The rows over the tabs.
	view.plans:Refresh()
	view.undo:SetAlpha(ns.CanUndo() and 1 or 0.35)
	view.redo:SetAlpha(ns.CanRedo() and 1 or 0.35)
	local level = ns.viewLevel or ns.TALENT_LAST_LEVEL
	view.level:SetText(L.LEVEL_SEEN:format(level, ns.PointsAt(level)))
	view.sim:SetText(simulating and L.SIM_STOP or L.SIM_START)
	for key, row in pairs(view.rows) do row:SetShown(key == tab) end
	view.compareBox:Refresh()
	view.inspect:SetEnabled(ns.inspected ~= nil)
	view.tie:SetText(ns.PlanTiedTo() and L.PLAN_UNTIE or L.PLAN_TIE)
	view.honesty:SetText(L.DATA_HONESTY:format((Clean(Safe(_G.GetBuildInfo))) or "?"))
end

-- (the guard with the rest: it stands on the game's window, the calculator open or not)
local function DrawAll()
	ns.DrawOverlay()
	ns.DrawTalentPanel()
	Guard()
end
ns.DrawTalentsEverywhere = DrawAll

function ns.HoverTalent(node)
	hovered = node
	pointed = tab == "order" and node or nil
	if tab ~= "effects" and tab ~= "order" and node then
		tab = "effects"
		view.tabs:Select(tab)
	end
	ns.DrawTalentPanel()
end

function ns.SayRefused(node, why, need)
	if not view then return end
	if not ns.TalentTreeNow() then return end
	local _, rows = ns.PlanRanks(ns.PlanSteps())
	local text = RefusalText(node, why, need, rows)
	if text then view.said:SetText(text) view.said:Show() C_Timer.After(4, function() if view.said:GetText() == text then view.said:Hide() end end) end
end

local function SetSimulating(on)
	simulating = on and not InFight() or false
	if not simulating then hovered = nil end
	DrawAll()
end
ns.SetSimulating = SetSimulating

local function Import()
	Skin.AskText(L.IMPORT_ASK, "", function(text)
		local steps, why = ns.ReadPlanCode(text)
		if not steps then
			W.Print(why == "class" and L.IMPORT_CLASS or L.IMPORT_BAD)
			return
		end
		ns.SetPlanSteps(steps)
		W.Print(L.IMPORT_DONE:format(#steps))
	end, 400)
end

local function MakePanel()
	panel = Skin.CreateWindow("WandererTrainingTalentPanel", "MEDIUM", _G.PlayerSpellsFrame)
	if Skin.PadWindow then Skin.PadWindow(panel, { side = true }) end
	panel:SetWidth(PANEL_WIDTH)
	panel:EnableMouse(true)
	panel:SetClampedToScreen(true)
	panel:SetPoint("TOPLEFT", _G.PlayerSpellsFrame, "TOPRIGHT", 6, 0)
	panel:SetPoint("BOTTOMLEFT", _G.PlayerSpellsFrame, "BOTTOMRIGHT", 6, 0)
	Skin.CloseButton(panel, function()
		local settings = Settings()
		if settings then settings.talentsPanel = false end
		SetSimulating(false)
		panel:Hide()
	end)
	local _, title, margin = Skin.Header(panel, "Wanderer", L.CALC_TITLE, { settings = "ext:training" })
	Skin.Help(panel, L.CALC_HELP, "HEADING")
	view = {}
	-- The plan shown, undo and done again.
	view.plans = Skin.Dropdown(panel, function()
		local list = {}
		for index, plan in ipairs(ns.PlanStore().list) do list[#list + 1] = { id = index, label = plan.name } end
		return list
	end, function() return ns.PlanStore().chosen end, function(index) ns.ChoosePlan(index) end, nil, 150, 200, L.PLAN_CHOOSE_DESC)
	view.plans:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
	view.undo = Skin.GlyphButton(panel, "undo", 14, L.UNDO, function() ns.PlanUndo() end)
	view.undo:SetPoint("LEFT", view.plans, "RIGHT", 8, 0)
	view.redo = Skin.GlyphButton(panel, "undo", 14, L.REDO, function() ns.PlanRedo() end)
	view.redo:SetPoint("LEFT", view.undo, "RIGHT", 2, 0)
	view.redo.glyph:SetTexCoord(2 / 16, 1 / 16, 0, 1)
	-- Simulate.
	view.sim = Skin.Button(panel, L.SIM_START, function() SetSimulating(not simulating) end, "main")
	view.sim:SetPoint("TOPLEFT", view.plans, "BOTTOMLEFT", 0, -10)
	view.sim:SetPoint("RIGHT", panel, "RIGHT", -margin, 0)
	Skin.Tooltip(view.sim, L.SIM_DESC)
	-- The level seen: arrows and the wheel.
	local levelRow = CreateFrame("Frame", nil, panel)
	levelRow:SetHeight(22)
	levelRow:SetPoint("TOPLEFT", view.sim, "BOTTOMLEFT", 0, -10)
	levelRow:SetPoint("RIGHT", panel, "RIGHT", -margin, 0)
	local function Step(by) ns.SetViewLevel((ns.viewLevel or ns.TALENT_LAST_LEVEL) + by) end
	local down = Skin.GlyphButton(levelRow, "back", 12, L.LEVEL_DOWN, function() Step(IsShiftKeyDown() and -10 or -1) end)
	down:SetPoint("LEFT")
	view.level = Skin.Text(levelRow, "GameFontHighlightSmall", "text")
	view.level:SetPoint("LEFT", down, "RIGHT", 6, 0)
	local up = Skin.GlyphButton(levelRow, "chevron", 12, L.LEVEL_UP, function() Step(IsShiftKeyDown() and 10 or 1) end)
	up:SetPoint("LEFT", view.level, "RIGHT", 6, 0)
	levelRow:EnableMouseWheel(true)
	levelRow:SetScript("OnMouseWheel", function(_, delta) Step(delta > 0 and 1 or -1) end)
	Skin.Tooltip(levelRow, L.LEVEL_DESC)
	-- The search.
	view.search = Skin.CreateInput(panel, nil, 40, { hint = L.SEARCH_HINT, onChange = function(self)
		searched = self:GetText() or ""
		ns.DrawOverlay()
		ns.DrawTalentPanel()
	end })
	view.search:SetPoint("TOPLEFT", levelRow, "BOTTOMLEFT", 0, -8)
	view.search:SetPoint("RIGHT", panel, "RIGHT", -margin, 0)
	-- The pages.
	view.tabs = Skin.Tabs(panel, {
		{ "order", L.TAB_ORDER }, { "effects", L.TAB_EFFECTS }, { "build", L.TAB_BUILD }, { "compare", L.TAB_COMPARE }, { "plans", L.TAB_PLANS }, { "share", L.TAB_SHARE },
	}, function(key)
		tab = key
		ns.DrawTalentPanel()
	end)
	view.tabs:SetPoint("TOPLEFT", view.search, "BOTTOMLEFT", 0, -12)
	view.tabs:Select(tab)
	local rule = Skin.Rule(panel)
	rule:SetPoint("TOPLEFT", view.tabs, "BOTTOMLEFT", 0, -2)
	rule:SetPoint("RIGHT", panel, "RIGHT", -margin, 0)
	-- Each page's buttons, at the foot.
	view.rows = {}
	local function Row(key)
		local row = CreateFrame("Frame", nil, panel)
		row:SetHeight(24)
		row:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", margin, margin + 18)
		row:SetPoint("RIGHT", panel, "RIGHT", -margin, 0)
		view.rows[key] = row
		return row
	end
	local function Line(row, list)
		local previous
		for _, button in ipairs(list) do
			button:ClearAllPoints()
			if previous then button:SetPoint("LEFT", previous, "RIGHT", 6, 0) else button:SetPoint("LEFT", row, "LEFT") end
			previous = button
		end
	end
	local build = Row("build")
	Line(build, {
		Skin.SmallButton(build, L.PLAN_FROM_YOURS, function() ns.PlanFromYours() end, L.PLAN_FROM_YOURS_DESC),
		Skin.SmallButton(build, L.PLAN_CLEAR, function() Skin.Ask(L.PLAN_CLEAR_ASK, function() ns.PlanClear() end) end),
	})
	local compare = Row("compare")
	view.compareBox = Skin.Dropdown(compare, function()
		local list = {}
		for _, choice in ipairs(ns.CompareChoices()) do list[#list + 1] = { id = choice.key, label = choice.label } end
		return list
	end, function() return compareWith end, function(key)
		compareWith = key
		ns.DrawTalentPanel()
	end, nil, 160, 260, L.COMPARE_DESC)
	view.compareBox:SetHeight(22)
	view.compareBox:SetPoint("LEFT", compare, "LEFT")
	local plans = Row("plans")
	plans:SetHeight(52)
	view.tie = Skin.SmallButton(plans, L.PLAN_TIE, function() ns.TiePlanToSpec(not ns.PlanTiedTo()) end, L.PLAN_TIE_DESC)
	local first = {
		Skin.SmallButton(plans, L.PLAN_NEW, function() Skin.AskText(L.PLAN_NEW_ASK, "", function(name) ns.NewPlan(name, false) end, 40, true) end),
		Skin.SmallButton(plans, L.PLAN_COPY, function() ns.NewPlan(L.PLAN_COPY_NAME:format(ns.CurrentPlan().name), true) end),
		Skin.SmallButton(plans, L.PLAN_RENAME, function() Skin.AskText(L.PLAN_RENAME_ASK, ns.CurrentPlan().name, function(name) ns.RenamePlan(name) end, 40) end),
	}
	local second = {
		Skin.SmallButton(plans, L.PLAN_NOTE, function() Skin.AskText(L.PLAN_NOTE_ASK, ns.CurrentPlan().note, function(note) ns.SetPlanNote(note) end, 200, true) end),
		view.tie,
		Skin.SmallButton(plans, L.PLAN_DELETE, function() Skin.Ask(L.PLAN_DELETE_ASK:format(ns.CurrentPlan().name), function() ns.DeletePlan() end) end),
	}
	Line(plans, first)
	for _, button in ipairs(first) do button:SetPoint("TOP", plans, "TOP") end
	local previous
	for _, button in ipairs(second) do
		button:ClearAllPoints()
		if previous then button:SetPoint("LEFT", previous, "RIGHT", 6, 0) else button:SetPoint("BOTTOMLEFT", plans, "BOTTOMLEFT") end
		previous = button
	end
	local share = Row("share")
	share:SetHeight(52)
	view.inspect = Skin.SmallButton(share, L.SHARE_COPY_INSPECTED, function()
		if not ns.inspected then return end
		ns.SetPlanSteps(ns.StepsFromRanks(ns.inspected.ranks))
	end, L.SHARE_COPY_INSPECTED_DESC)
	local shareFirst = {
		Skin.SmallButton(share, L.SHARE_CODE, function() Skin.ShowCopy(L.SHARE_CODE_SAY, ns.PlanCode() or "") end),
		Skin.SmallButton(share, L.SHARE_WOWHEAD, function() Skin.ShowCopy(L.SHARE_WOWHEAD_SAY, ns.PlanWowhead() or "") end),
	}
	local shareSecond = { Skin.SmallButton(share, L.SHARE_IMPORT, Import, L.SHARE_IMPORT_DESC), view.inspect }
	Line(share, shareFirst)
	for _, button in ipairs(shareFirst) do button:SetPoint("TOP", share, "TOP") end
	previous = nil
	for _, button in ipairs(shareSecond) do
		button:ClearAllPoints()
		if previous then button:SetPoint("LEFT", previous, "RIGHT", 6, 0) else button:SetPoint("BOTTOMLEFT", share, "BOTTOMLEFT") end
		previous = button
	end
	Row("effects"):SetHeight(1)
	Row("order"):SetHeight(1)
	-- Where the figures come from, at the very foot.
	view.honesty = Skin.Text(panel, "GameTooltipTextSmall", "muted")
	view.honesty:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", margin, margin)
	view.honesty:SetPoint("RIGHT", panel, "RIGHT", -margin, 0)
	view.honesty:SetJustifyH("LEFT")
	-- The page itself, scrolled by the wheel.
	view.scroll = CreateFrame("ScrollFrame", nil, panel)
	view.scroll:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -10)
	view.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -margin, margin + 18 + 60)
	view.content = CreateFrame("Frame", nil, view.scroll)
	view.content:SetSize(PANEL_WIDTH - margin * 2, 20)
	view.scroll:SetScrollChild(view.content)
	view.body = Skin.Text(view.content, "GameTooltipText", "text")
	view.body:SetPoint("TOPLEFT")
	view.body:SetWidth(PANEL_WIDTH - margin * 2)
	view.body:SetJustifyH("LEFT")
	view.body:SetJustifyV("TOP")
	view.body:SetSpacing(3)
	view.orderRows = {}
	view.scroll:EnableMouseWheel(true)
	view.scroll:SetScript("OnMouseWheel", function(self, delta)
		local most = math.max(0, (view.contentHeight or 0) - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(most, self:GetVerticalScroll() - delta * 40)))
	end)
	-- A refusal said for a moment, under the simulate button.
	view.said = Skin.Text(panel, "GameFontHighlightSmall", "warn")
	view.said:SetPoint("TOPLEFT", view.sim, "BOTTOMLEFT", 0, -2)
	view.said:SetPoint("RIGHT", panel, "RIGHT", -margin, 0)
	view.said:SetJustifyH("LEFT")
	view.said:Hide()
	-- The guard, over the game's Apply button.
	view.guard = Skin.Text(frame, "GameFontHighlightSmall", "warn")
	if frame.ApplyButton then view.guard:SetPoint("BOTTOM", frame.ApplyButton, "TOP", 0, 6) end
	view.guard:SetWidth(360)
	view.guard:Hide()
	panel:HookScript("OnShow", function() ns.DrawTalentPanel() end)
	panel:HookScript("OnHide", function() if simulating then SetSimulating(false) end end)
	Skin.Get(panel):Layout()
end

-- The two buttons on the game's window: the calculator, simulate.
local function MakeButtons()
	local open = Skin.GameButton(frame, nil, L.CALC_BUTTON, function()
		local settings = Settings()
		if settings then settings.talentsPanel = true end
		if panel:IsShown() then return Skin.Front and Skin.Front(panel) end
		panel:Show()
	end, L.CALC_BUTTON_DESC)
	if frame.SearchBox then
		open:SetPoint("RIGHT", frame.SearchBox, "LEFT", -18, 0)
	else
		open:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -20)
	end
	open:SetFrameLevel((frame.SearchBox and frame.SearchBox:GetFrameLevel() or frame:GetFrameLevel()) + 1)
	frame.wandererCalc = open
end

-- Attached once the game's talent window exists.
function ns.AttachTalents()
	if overlay then return end
	frame = Talents()
	if not (frame and Skin) then return end
	overlay = CreateFrame("Frame", nil, frame)
	overlay:SetAllPoints(frame)
	overlay:SetFrameLevel(frame:GetFrameLevel() + 1)
	MakePanel()
	MakeButtons()
	frame:HookScript("OnShow", function()
		if not On() then return panel:Hide() end
		frame.wandererCalc:Show()
		local settings = Settings()
		if settings.talentsPanel ~= false then panel:Show() end
		C_Timer.After(0, DrawAll)
	end)
	frame:HookScript("OnHide", function()
		SetSimulating(false)
		panel:Hide()
	end)
	-- The game redraws its buttons (a point staged, a tab): ours follow.
	-- (the tree read again only when its ranks may have moved: a point staged, another specialization)
	for method, reread in pairs({ UpdateConfigButtonsState = true, SetConfigID = true, LoadTalentTreeInternal = false }) do
		if type(frame[method]) == "function" then
			hooksecurefunc(frame, method, function()
				if reread then ns.ForgetTalentTree() end
				C_Timer.After(0, DrawAll)
			end)
		end
	end
	ns.OnPlanChanged(DrawAll)
	if frame:IsShown() then frame:GetScript("OnShow")(frame) end
end

-- Opens the game's talent window with the calculator (out of a fight); false when it cannot.
function ns.OpenTalentCalculator()
	if InFight() then return false end
	local util = _G.PlayerSpellsUtil
	if not (util and util.OpenToClassTalentsTab) then return false end
	local ok = pcall(util.OpenToClassTalentsTab)
	if not ok then return false end
	ns.AttachTalents()
	-- (the game may keep its talent window closed: too young a character; Training's own window then)
	if not (panel and frame and frame:IsVisible()) then return false end
	local settings = Settings()
	if settings then settings.talentsPanel = true end
	panel:Show()
	return true
end

function ns.TalentPanelEvent(event)
	if event == "PLAYER_REGEN_DISABLED" then
		if simulating then SetSimulating(false) end
		return DrawAll()
	end
	if event == "PLAYER_REGEN_ENABLED" then return DrawAll() end
	if event == "SPELLS_CHANGED" then ns.ForgetBook() end
	if frame and frame:IsShown() then C_Timer.After(0, DrawAll) end
end

-- What the calculator sees, written for a look after a /reload (/wtraining talents dump): the tree, each talent's
-- words and what they are read as, the game's window and its buttons.
function ns.TalentsDump()
	local dump = { when = date and date("%Y-%m-%d %H:%M") or "", build = Clean(Safe(_G.GetBuildInfo)), nodes = {} }
	ns.ForgetTalentTree()
	ns.ForgetTalentTexts()
	local tree = ns.TalentTreeNow()
	dump.tree = tree and #tree.order or 0
	dump.traitEntry = (C_TooltipInfo and C_TooltipInfo.GetTraitEntry) and true or false
	dump.window = Talents() ~= nil
	local found = 0
	for _, node in ipairs(tree and tree.order or {}) do
		local button = ButtonFor(node)
		if button then found = found + 1 end
		local words = ns.TalentText(node, node.most)
		local touched = {}
		for _, spell in ipairs(ns.SpellsTouched(node)) do touched[#touched + 1] = spell.name end
		dump.nodes[#dump.nodes + 1] = { id = node.id, entry = node.entry, spell = node.spell, name = SpellName(node), branch = node.branch,
			tier = node.tier, column = node.column, ranks = node.ranks, most = node.most, words = words, kind = words and ns.ChangeKind(words),
			touched = table.concat(touched, ", "), button = button ~= nil }
	end
	dump.buttons = found
	ns.DB().talentsDump = dump
	W.Print(L.DUMP_DONE:format(dump.tree, found))
end

-- A page of the calculator shown (its tab chosen).
function ns.ShowTalentTab(key)
	if not (view and (TABS[key] or key == "order")) then return end
	tab = key
	view.tabs:Select(key)
	ns.DrawTalentPanel()
end
