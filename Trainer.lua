local _, ns = ...
local L = ns.L

-- The trainers' window, Wanderer's in place of the game's (an option, on): every trainer (class, weapons,
-- professions, pets, riding) in the same window. On the left, what the trainer teaches in sections (to learn now,
-- outside what you play, set aside, later, learned), a row's button under the mouse; on the right, for a class
-- trainer, what you play (the same choice as the spellbook's page), then one big button that learns what counts,
-- the cheapest first while your gold lasts, what it costs and what is left after, everything else in a smaller
-- button, the next level's sum. The game's own window stays one click away.

local W = Wanderer
local U = W and W.Util
local Skin = W and W.Skin

local WIDTH, HEIGHT = 900, 600
local LIST = 520 -- the list's width
local GAP = 30
local ROW = 36
local SEARCH_ROOM = 34 -- the field to look for a spell, over the list
local WAY = 30

local window, list, view, reopen = nil, nil, {}, nil
local atTrainer, mode, switching = false, "wanderer", false
local rows, services = {}, {}
local query = "" -- what is looked for (folded), "" for nothing
local learned -- what the last purchase brought: { keys (name|rank of each asked), before (your gold), heard (spells learned) }
local learnedHere = false -- something learned at this trainer (ours or the game's window)
local waiting -- until when the buttons stay off after a purchase (the trainer's answer ends it)
local filters -- the game's filters, put back when the trainer is left

local Settings = ns.Settings
local function Replaces() local settings = Settings() return settings ~= nil and settings.trainer ~= false end
local function Money() return U.Clean(U.Safe(GetMoney)) or 0 end

-- The trainer's services -------------------------------------------------------------------------------------

-- (a trainer's service read as Wanderer reads it: name, rank, state, header open)
local ServiceInfo = U.TrainerService

-- Every service shown (all filters on, every header open): the game's choices kept, put back after.
-- (called on arrival and when Wanderer's window comes back, never while drawing: each change makes the game send
-- TRAINER_UPDATE, which draws)
local FILTERS = { "available", "unavailable", "used" }
local function On(value) return value == true or value == 1 end
local unclosed -- header names to close again at the next visit
local function CloseHeaders(names)
	local left = false
	for index = (U.Clean(U.Safe(GetNumTrainerServices)) or 0), 1, -1 do
		local name, _, state, open = ServiceInfo(index)
		if state == "header" and open and names[name or ""] then
			U.Safe(CollapseTrainerSkillLine, index)
			left = true
		end
	end
	return left
end

local function ShowEverything()
	if filters or not GetTrainerServiceTypeFilter then return end
	filters = {}
	for _, kind in ipairs(FILTERS) do
		local on = On(U.Safe(GetTrainerServiceTypeFilter, kind))
		filters[kind] = on and 1 or 0
		if not on then U.Safe(SetTrainerServiceTypeFilter, kind, 1) end
	end
	filters.closed = unclosed or {}
	unclosed = nil
	for index = 1, (U.Clean(U.Safe(GetNumTrainerServices)) or 0) do
		local name, _, state, open = ServiceInfo(index)
		if state == "header" and not open then filters.closed[name or ""] = true end
	end
	if next(filters.closed) then U.Safe(ExpandTrainerSkillLine, 0) end
end

local function PutFiltersBack()
	if not filters then return end
	for _, kind in ipairs(FILTERS) do
		if filters[kind] == 0 then U.Safe(SetTrainerServiceTypeFilter, kind, 0) end
	end
	-- (the trainer already gone: nothing listed, closed at the next visit)
	if next(filters.closed) and (U.Clean(U.Safe(GetNumTrainerServices)) or 0) == 0 then
		unclosed = filters.closed
	else
		CloseHeaders(filters.closed)
	end
	filters = nil
end

-- The spells of the class known by Wanderer Training, by name and rank (to know what counts).
local model
local function Entries()
	local byName = {}
	model = ns.class and ns.Build() or nil
	if not model then return byName, false end
	for _, entry in ipairs(model.entries) do
		if entry.kind == "spell" and entry.name then
			if entry.sub then byName[entry.name .. "|" .. entry.sub] = entry end
			local loose = byName[entry.name .. "|"]
			if entry.status ~= "known" and (not loose or entry.level < loose.level) then
				byName[entry.name .. "|"] = entry
			end
		end
	end
	return byName, true
end

-- { index, name, sub, icon, cost, state ("available", "unavailable", "used"), level, skill, entry }
local function Read()
	wipe(services)
	local prices = {}
	local byName = Entries()
	local mine = false
	local level = U.Clean(U.Safe(UnitLevel, "player")) or 1
	for index = 1, (U.Clean(U.Safe(GetNumTrainerServices)) or 0) do
		local name, sub, state = ServiceInfo(index)
		if name and state and state ~= "header" then
			local service = {
				index = index, name = name, sub = sub ~= "" and sub or nil, state = state,
				icon = U.Clean(U.Safe(GetTrainerServiceIcon, index)),
				cost = U.Clean(U.Safe(GetTrainerServiceCost, index)) or 0,
				level = U.Clean(U.Safe(GetTrainerServiceLevelReq, index)) or 0,
			}
			local skillName, skillRank, hasSkill = U.Safe(GetTrainerServiceSkillReq, index)
			if U.Clean(skillName) and not U.Clean(hasSkill) then service.skill = U.Clean(skillRank) end
			service.later = state == "unavailable" and service.level > level and service.level or nil
			service.entry = byName[name .. "|" .. (sub or "")] or byName[name .. "|"]
			if service.entry then
				mine = true
				if service.entry.status == "now" and state == "available" then prices[#prices + 1] = service end
			end
			services[#services + 1] = service
		end
	end
	ns.NoteDiscounts(prices)
	-- (every price it asks, kept: the sums use them from now on)
	ns.NotePrices(services)
	return mine
end

-- What counts: on a class trainer, what Wanderer Training counts (what you play, counted anyway; not set aside);
-- everything elsewhere.
local function Counts(service)
	local entry = service.entry
	if not entry then return true end
	return entry.counts
end

-- The services to buy, the cheapest first while your gold lasts (Wanderer's plan): the chosen ones, their cost,
-- all of them, what all would cost.
local function Plan(onlyCounted)
	local wanted = {}
	for _, service in ipairs(services) do
		if service.state == "available" and (not onlyCounted or Counts(service)) then wanted[#wanted + 1] = service end
	end
	local chosen, spent, total = U.TrainerPlan(wanted)
	return chosen, spent, wanted, total
end

local function Key(service) return (service.name or "") .. "|" .. (service.sub or "") end

-- Bought one a moment after the other (Wanderer's U.LearnServices: highest index first, each found again, while
-- the trainer is there and the gold lasts).
local purchase = 0 -- one chain of purchases at a time
local buying = false -- a chain under way (the buttons stay off)
-- (a purchase answered late, or a chain still under way: no second one over it)
local function Waiting() return buying or (waiting ~= nil and GetTime() < waiting) end
local function Buy(chosen)
	if not chosen[1] or buying then return end
	view.learn.plan, view.all.plan = nil, nil
	view.learn:SetEnabled(false)
	view.all:SetEnabled(false)
	for _, line in ipairs(list.rows) do
		if line.act then
			line.act.run = nil
			line.act:Hide()
			line.cells.price:SetAlpha(1)
		end
	end
	local spacing = U.LEARN_SPACING * #chosen
	learned = { keys = {}, before = Money(), heard = {}, till = GetTime() + 3 + spacing }
	for _, service in ipairs(chosen) do learned.keys[Key(service)] = true end
	learnedHere = true
	waiting = GetTime() + 2 + spacing
	purchase = purchase + 1
	buying = true
	local mine = purchase
	U.LearnServices(chosen, function()
		if mine == purchase then buying = false end
		ns.Changed()
		C_Timer.After(1, ns.Changed)
	end, function() return mine == purchase and atTrainer end)
end

-- What the last purchase really brought: the services asked for now learned (or the spells the game said were
-- learned, whichever is more), and the gold it took.
local function Learned()
	if not learned then return 0, 0 end
	local count = 0
	for _, service in ipairs(services) do
		if learned.keys[Key(service)] and service.state == "used" then count = count + 1 end
	end
	local heard = 0
	for _, times in pairs(learned.heard) do heard = math.max(heard, times) end
	return math.max(count, heard), math.max(0, learned.before - Money())
end
ns.TrainerLearned = Learned -- (tests)

-- The list ------------------------------------------------------------------------------------------------------

local function Row(service)
	local name = service.name
	if service.sub then name = name .. "  " .. Skin.Colorize(service.sub, "muted") end
	-- (what the rank brings over the one before)
	local entry = service.entry
	local gain = entry and entry.kind == "spell" and service.state ~= "used"
		and ns.GainText(ns.RankGain(entry.id), Skin.COLORS.muted, Skin.COLORS.good)
	if gain then name = name .. "   " .. gain end
	local quiet = service.state ~= "available" or not Counts(service)
	return { name = name, icon = service.icon, service = service, color = quiet and Skin.COLORS.muted or nil }
end

-- A section (the page's own way, Page.lua): its title, count and sum, a few quiet words after (note).
local function ServiceName(service) return service.name end
local function ServicePrice(service) return service.state ~= "used" and service.cost or nil end
local function Section(title, group, note)
	ns.ListSection(rows, group, title, Row, ServiceName, ServicePrice, note, query)
end

local function Gather(class)
	wipe(rows)
	local groups = { now = {}, offSpec = {}, ignored = {}, later = {}, used = {} }
	for _, service in ipairs(services) do
		local entry = service.entry
		local into
		if service.state == "used" then
			into = ns.DB().showKnown and groups.used
		elseif service.state == "unavailable" then
			into = groups.later
		elseif entry and entry.ignored then
			into = groups.ignored
		elseif class and not Counts(service) then
			into = groups.offSpec
		else
			into = groups.now
		end
		if into then into[#into + 1] = service end
	end
	table.sort(groups.later, function(a, b)
		if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
		return a.name < b.name
	end)
	Section(L.SECTION_NOW, groups.now)
	Section(L.SECTION_OFFSPEC, groups.offSpec, L.SECTION_OFFSPEC_NOTE)
	Section(L.SECTION_IGNORED, groups.ignored)
	Section(L.SECTION_LATER, groups.later)
	Section(L.SECTION_KNOWN, groups.used)
end

local function ActionOf(service)
	if service.state ~= "available" or Waiting() then return nil end
	return L.LEARN_ONE, function() Buy({ service }) end
end

local Menu -- (below)

local function Dress(line)
	if line.wandererDressed then return end
	line.wandererDressed = true
	-- Under the mouse: Learn (over the price), the "..." left of it (the same card as the right click).
	local act = Skin.SmallButton(line, "", function(self) if self.run then self.run() end end, nil, 24)
	act:SetPoint("RIGHT", line, "RIGHT", -4, 0)
	act:SetFrameLevel(line:GetFrameLevel() + 3)
	act:Hide()
	line.act = act
	act:HookScript("OnLeave", function() ns.HoverRow(line) end)
	ns.DressMore(line, function(self) if self.entry and self.entry.service then Menu(self.entry, self.menu) end end)
	line:HookScript("OnEnter", function(self)
		-- The game's own tooltip of the service.
		local service = self.entry and self.entry.service
		if service and GameTooltip.SetTrainerService then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:SetTrainerService(service.index)
			GameTooltip:Show()
		end
	end)
end

local function DrawList()
	if not list then return end
	local offset = list:Clamp(#rows)
	for index, line in ipairs(list.rows) do
		Dress(line)
		local row = rows[index + offset]
		local service = row and row.service
		local values, chip, tone, actionText, action
		if service then
			local price = service.state == "used" and "" or service.cost > 0 and U.Coins(service.cost) or "-"
			values = { price = price }
			chip, tone = ns.EntryChip(service.entry, service)
			actionText, action = ActionOf(service)
		end
		line:Fill(row, false, values, chip, tone)
		-- (a title as written: its coins would not survive the capitals)
		if row and row.header then
			line.header:SetText(row.title .. "   " .. row.count .. (row.price > 0 and ("   " .. U.Coins(row.price)) or "")
				.. (row.note and ("   " .. Skin.Colorize(row.note, "muted")) or ""))
		end
		line.act:SetLabel(actionText or "")
		line.act.run = row and action or nil
		-- Its "..." (left of the price, Learn showing over the price under the mouse).
		ns.ShowMore(line, service ~= nil and #ns.EntryActions(service.entry, { learn = action, noPin = true }) > 0)
		ns.MarkFound(line, service ~= nil and query ~= "" and ns.Found(service.name, query))
		ns.HoverRow(line)
	end
	list.empty:SetText(query ~= "" and L.SEARCH_NONE or L.TRAINER_NOTHING)
	list.empty:SetShown(#rows == 0)
end

-- A row's card (its "...", its right click): Learn, then set aside or counted anyway (a spell of the class); the
-- same card as on the page, without the way to a trainer (you are at one).
function Menu(row, owner)
	local service = row.service
	local _, learn = ActionOf(service)
	return ns.EntryMenu(service.entry, owner, { title = service.name, learn = learn, noPin = true })
end

-- The right column ---------------------------------------------------------------------------------------------

local ON, OFF = Skin.COLORS.text, Skin.COLORS.muted
local function DrawWays(class)
	local shown = class and #view.ways.buttons > 0 or false
	view.waysTitle:SetShown(shown)
	view.ways:SetShown(shown)
	view.ways:Draw(ON, OFF)
	-- (the buttons under the ways, or at the top when there are none)
	view.learn:ClearAllPoints()
	if shown then
		view.learn:SetPoint("TOPLEFT", view.ways, "BOTTOMLEFT", 0, -22)
	else
		view.learn:SetPoint("TOPLEFT", view.right, "TOPLEFT", 0, -4)
	end
end

local function DrawRight(class)
	local mine = class and ns.Chosen() ~= nil
	local chosen, spent, wanted, total = Plan(true)
	local count = #wanted
	view.learn:SetText((mine and L.LEARN_MINE or L.LEARN_EVERYTHING):format(count))
	view.learn:SetEnabled(#chosen > 0 and not Waiting())
	view.learn.plan = chosen
	-- What it costs, and what is left after (or how far your gold goes).
	view.cost.value:SetText(total > 0 and U.Coins(total) or "-")
	local money = Money()
	if count == 0 then
		view.note:SetText(L.TRAINER_NOTHING)
	elseif #chosen < count then
		view.note:SetText(L.TRAINER_SHORT:format(#chosen, count))
	else
		view.note:SetText(L.TRAINER_LEFT:format(U.Coins(money - spent)))
	end
	-- Everything, outside what you play included.
	local all, _, everything = Plan(false)
	view.all:SetShown(mine and #everything > count)
	view.all:SetEnabled(#all > 0 and not Waiting())
	view.all:SetLabel(L.LEARN_EVERYTHING:format(#everything))
	view.all.plan = all
	-- The next level, on a class trainer.
	local nextLine = false
	if class and model then
		if model.next and model.sums.next.price > 0 then
			nextLine = true
			view.nextLevel.label:SetText(L.SUM_NEXT:format(model.next))
			view.nextLevel.value:SetText(U.Coins(model.sums.next.price))
		end
	end
	view.nextLevel:SetShown(nextLine)
	local got, paid = Learned()
	view.learned:SetText((paid > 0 and got > 0) and L.TRAINER_LEARNED:format(got, U.Coins(paid)) or "")
	view.known:Refresh()
	ns.DrawTrainerRanks()
end

-- The old ranks on your bars (after learning, most often): the line, its button.
function ns.DrawTrainerRanks()
	if not (window and window:IsShown()) then return end
	local text = ns.RanksText()
	view.ranks:SetShown(text ~= nil)
	view.ranksUpdate:SetShown(text ~= nil)
	if not text then return end
	view.ranks:SetText(text)
	view.ranksUpdate:SetLabel(ns.RanksButtonText())
	view.ranksUpdate:SetEnabled(ns.CanUpdateRanks())
end

local GiveBack -- (below: the game's window back when ours fails)

local function Draw()
	local class = Read()
	view.title:SetText(U.Clean(U.Safe(UnitName, "npc")) or L.TRAINER_TITLE)
	view.money:SetText(U.Coins(Money()))
	Gather(class)
	DrawList()
	DrawWays(class)
	DrawRight(class)
end

-- Drawn safely: an error (an answer of the trainer this window does not know) gives the game's own window back,
-- so a trainer is never out of reach.
function ns.DrawTrainer()
	if not (window and window:IsShown() and atTrainer) then return end
	local ok, problem = pcall(Draw)
	if not ok then GiveBack(problem) end
end

-- Built once ----------------------------------------------------------------------------------------------------

local function Create()
	window = Skin.CreateWindow("WandererTrainingTrainer", "MEDIUM")
	Skin.Sounds(window, Skin.SOUNDS.open, Skin.SOUNDS.close)
	Skin.Dress(window, { "TOPLEFT", UIParent, "TOPLEFT", 24, -110 }, "trainingTrainerPos")
	window:SetSize(WIDTH, HEIGHT)
	local _, title, margin = ns.Header(window, L.TRAINER_TITLE, 10, "GameFontNormalLarge")
	view.title = title
	-- Your money, and the game's own window, on the right (the cross after them).
	local game = Skin.SmallButton(window, L.GAME_WINDOW, function() ns.UseGameTrainer() end, L.GAME_WINDOW_DESC)
	game:SetPoint("TOPRIGHT", window, "TOPRIGHT", -(margin + 26), -margin + 2)
	view.money = Skin.Text(window, "GameTooltipText", "soft")
	view.money:SetPoint("RIGHT", game, "LEFT", -18, 0)
	local rule = Skin.Rule(window)
	rule:SetPoint("TOPLEFT", window, "TOPLEFT", margin, -(margin + 50))
	rule:SetPoint("RIGHT", window, "RIGHT", -margin, 0)
	-- On the left, everything the trainer teaches.
	list = Skin.Table(window, {
		width = LIST, rows = 14, rowHeight = ROW, titles = false,
		columns = { { key = "price", width = 140 } },
		onClick = function(row, mouse)
			if mouse == "RightButton" and row.service then Menu(row) end
		end,
		onDraw = DrawList,
	})
	list:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -12 - SEARCH_ROOM)
	list:Fit(HEIGHT - (margin + 62) - margin - SEARCH_ROOM)
	list.empty:SetText(L.TRAINER_NOTHING)
	-- Over it, the field to look for a spell.
	view.search = ns.SearchField(window, function(folded)
		query = folded
		list.offset = 0
		ns.DrawTrainer()
	end, function()
		if ns.ShowFound(rows, list, query, function(row) return row.service and row.service.name end) then DrawList() end
	end)
	view.search:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 4, -10)
	-- On the right: what you play, the buttons, the sums.
	local width = WIDTH - margin * 2 - LIST - GAP
	local right = CreateFrame("Frame", nil, window)
	right:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", LIST + GAP, -14)
	right:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -margin, margin)
	view.right = right
	view.waysTitle = Skin.Caps(right, L.WAYS)
	view.waysTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
	view.ways = ns.WaysGrid(right, width, WAY)
	view.ways:SetPoint("TOPLEFT", view.waysTitle, "BOTTOMLEFT", 0, -12)
	-- The big button: what counts, the cheapest first while your gold lasts.
	view.learn = Skin.Button(right, "", function(self) Buy(self.plan or {}) end, "main", width)
	view.learn:SetWidth(width)
	Skin.Tooltip(view.learn, L.LEARN_DESC)
	view.cost = Skin.SummaryLine(right, nil, L.TRAINER_COST, true)
	view.cost:ClearAllPoints()
	view.cost:SetPoint("TOPLEFT", view.learn, "BOTTOMLEFT", 0, -14)
	view.cost:SetWidth(width)
	view.note = Skin.Text(right, "GameTooltipTextSmall", "muted")
	view.note:SetPoint("TOPLEFT", view.cost, "BOTTOMLEFT", 0, -6)
	view.note:SetWidth(width)
	view.note:SetJustifyH("LEFT")
	view.all = Skin.SmallButton(right, "", function(self) Buy(self.plan or {}) end, L.LEARN_EVERYTHING_DESC, 26)
	view.all:SetPoint("TOPLEFT", view.note, "BOTTOMLEFT", 0, -16)
	view.nextLevel = Skin.SummaryLine(right, nil, "")
	view.nextLevel:ClearAllPoints()
	view.nextLevel:SetPoint("TOPLEFT", view.all, "BOTTOMLEFT", 0, -20)
	view.nextLevel:SetWidth(width)
	view.learned = Skin.Text(right, "GameTooltipText", "good")
	view.learned:SetPoint("TOPLEFT", view.nextLevel, "BOTTOMLEFT", 0, -18)
	view.learned:SetWidth(width)
	view.learned:SetJustifyH("LEFT")
	-- The old ranks on your bars, under it (a right click: a rank kept on purpose).
	view.ranks = Skin.Text(right, "GameTooltipText", "soft")
	view.ranks:SetPoint("TOPLEFT", view.learned, "BOTTOMLEFT", 0, -14)
	view.ranks:SetWidth(width)
	view.ranks:SetJustifyH("LEFT")
	view.ranksUpdate = Skin.SmallButton(right, L.RANKS_UPDATE, function(self, mouse) ns.RanksClick(self, mouse) end,
		function() return ns.RanksTooltip() end, 26)
	view.ranksUpdate:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	view.ranksUpdate:SetPoint("TOPLEFT", view.ranks, "BOTTOMLEFT", 0, -8)
	view.ranks:Hide()
	view.ranksUpdate:Hide()
	ns.OnRanksChanged(ns.DrawTrainerRanks)
	-- At the foot: what is learned, shown or not.
	view.known = Skin.Check(right, L.SHOW_KNOWN, function() return ns.DB().showKnown end, function(value)
		ns.DB().showKnown = value or nil
		ns.Changed()
	end, L.SHOW_KNOWN_DESC)
	view.known:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 0)
	window:HookScript("OnShow", function(self)
		self:SetScale(Skin.FitScale(self))
		ns.DrawTrainer()
	end)
	-- Closed by hand (its cross, Escape): the trainer with it, as the game's window does.
	window:HookScript("OnHide", function()
		if switching or not atTrainer or mode ~= "wanderer" then return end
		-- (the game's filters and headers put back while the trainer still lists its services)
		PutFiltersBack()
		U.Safe(CloseTrainer)
	end)
	Skin.Get(window):Layout()
end

-- Naowh's panel ----------------------------------------------------------------------------------------------------

-- Naowh Training's "Train Now" panel is docked to the game's class trainer window; with that window out of sight,
-- the panel would stay at the screen's edge over ours, a second learning panel. While it is on, at a class trainer
-- the game's window stays where Naowh expects it (an option, on): one learning panel at a time, ours a click away.
-- Their settings are only read, their frames never touched.
local function NaowhSays(store, ...)
	local naowh = _G.NaowhForever
	local settings = type(naowh) == "table" and naowh[store]
	if type(settings) ~= "table" or type(settings.Get) ~= "function" then return false end
	for _, key in ipairs({ ... }) do
		local ok, value = pcall(settings.Get, key)
		if not (ok and value) then return false end
	end
	return true
end
local function Loaded(addon) return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addon) and true or false end

function ns.NaowhTraining() return Loaded("NaowhForever_Training") end
function ns.NaowhPanel() return ns.NaowhTraining() and NaowhSays("TrainingSettings", "enabled", "trainerPanel") end
-- (Naowh's own card after a trainer, with its rank updates: ours keeps quiet then)
function ns.NaowhRanks() return Loaded("NaowhForever_QoL") and NaowhSays("QoLSettings", "enabled", "trainerPopup", "trainerRanks") end

local function MakeWay()
	local settings = Settings()
	if not (settings and settings.naowhPanel ~= false and ns.NaowhPanel()) then return false end
	return not U.Clean(U.Safe(IsTradeskillTrainer))
end
ns.MakeWayForNaowh = MakeWay

-- A trainer of your class's spells (Naowh's panel shows only there); its list not come yet: taken as one, and
-- looked at again a moment after.
local function ClassHere()
	if (U.Clean(U.Safe(GetNumTrainerServices)) or 0) == 0 then return true end
	return Read()
end

-- The game's window --------------------------------------------------------------------------------------------

local function GameFrame() return _G.ClassTrainerFrame end

local placeGame
local function PlaceGameWindow() if placeGame then placeGame() end end

local hooked = false
local function HookGameWindow()
	local frame = GameFrame()
	if hooked or not frame then return end
	hooked = true
	placeGame = Skin.AsideGameWindow(frame, function() return atTrainer and mode == "wanderer" end)
end

-- The link beside the game's window, back to Wanderer's.
local function Reopen()
	if reopen or not GameFrame() then return reopen end
	reopen = Skin.SmallButton(UIParent, L.ADDON, function() ns.UseWandererTrainer() end)
	reopen:SetFrameStrata("HIGH")
	reopen:Hide()
	return reopen
end

-- (beside it; under it while Naowh's panel takes its side)
local function PlaceReopen()
	reopen:ClearAllPoints()
	if ns.NaowhPanel() then
		reopen:SetPoint("TOPRIGHT", GameFrame(), "BOTTOMRIGHT", 0, -6)
	else
		reopen:SetPoint("TOPLEFT", GameFrame(), "TOPRIGHT", 6, -4)
	end
end

function ns.UseGameTrainer()
	mode = "game"
	if window and window:IsShown() then
		switching = true
		window:Hide()
		switching = false
	end
	PutFiltersBack()
	PlaceGameWindow()
	if Reopen() then
		PlaceReopen()
		reopen:Show()
	end
end

function ns.UseWandererTrainer()
	mode = "wanderer"
	if reopen then reopen:Hide() end
	ShowEverything()
	PlaceGameWindow()
	if not window then Create() end
	-- (shown, it draws itself)
	if window:IsShown() then ns.DrawTrainer() else window:Show() end
end

local function Arrive()
	atTrainer = true
	learned = nil
	learnedHere = false
	HookGameWindow()
	-- The game's window: the option off, or Naowh's panel beside it (then ours one click away, by the link under it).
	local yielding = Replaces() and MakeWay() and ClassHere()
	if yielding or not Replaces() then
		mode = "game"
		if unclosed then
			CloseHeaders(unclosed)
			unclosed = nil
		end
		if yielding then
			ns.UseGameTrainer()
			-- (the game's window may come a moment later: the link with it)
			C_Timer.After(0, function()
				if not (atTrainer and mode == "game") then return end
				HookGameWindow()
				ns.UseGameTrainer()
			end)
		end
		C_Timer.After(0.5, function()
			if not atTrainer then return end
			local ok, class = pcall(Read)
			if not ok then return GiveBack(class) end
			-- (no class spells here after all, a weapon master or a riding trainer: Naowh's panel stays away, ours comes)
			if yielding and mode == "game" and not class then ns.UseWandererTrainer() end
		end)
		return
	end
	ns.UseWandererTrainer()
	-- (the game may show its own a moment later)
	C_Timer.After(0, function()
		HookGameWindow()
		PlaceGameWindow()
	end)
end

-- Learned at the game's window, older ranks left on the bars: said once, the page updates them (unless Naowh's
-- card already says it). Wanderer off: nothing said.
local function TellRanks()
	if not Settings() or ns.NaowhRanks() then return end
	local text = ns.RanksText()
	if text then W.Toast(L.RANKS_TITLE, text .. "\n" .. L.RANKS_TOAST, { kicker = "Wanderer", duration = 8 }) end
end

-- Something went wrong in our window: the game's trainer window back in its place, ours away, for this visit.
GiveBack = function(problem)
	mode = "game"
	if window and window:IsShown() then
		switching = true
		window:Hide()
		switching = false
	end
	pcall(PutFiltersBack)
	if reopen then reopen:Hide() end
	pcall(PlaceGameWindow)
	if GameFrame() then pcall(U.HideOffScreen, GameFrame(), false) end
	local frame = GameFrame()
	if atTrainer and frame and not frame:IsShown() then
		if ShowUIPanel then pcall(ShowUIPanel, frame) else frame:Show() end
	end
	-- (the error itself said, as the game says any addon's, to be found and mended)
	if problem ~= nil and geterrorhandler then pcall(geterrorhandler(), problem) end
	return problem
end
ns.GiveBackTrainer = GiveBack -- (tests)

local function Leave()
	purchase = purchase + 1
	buying = false
	if learnedHere and mode == "game" then C_Timer.After(1, TellRanks) end
	learnedHere = false
	atTrainer = false
	switching = true
	if window then window:Hide() end
	switching = false
	if reopen then reopen:Hide() end
	PutFiltersBack()
	U.HideOffScreen(GameFrame(), false)
	mode = "wanderer"
end

function ns.InitTrainer()
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "TRAINER_SHOW", "TRAINER_CLOSED", "TRAINER_UPDATE", "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB" }) do pcall(events.RegisterEvent, events, event) end
	events:SetScript("OnEvent", function(_, event)
		if event == "TRAINER_SHOW" then
			local ok, problem = pcall(Arrive)
			if not ok then GiveBack(problem) end
		elseif event == "TRAINER_CLOSED" then
			Leave()
		elseif event == "LEARNED_SPELL_IN_SKILL_LINE" or event == "LEARNED_SPELL_IN_TAB" then
			if atTrainer then learnedHere = true end
			-- (one spell may be told by both events: each counted apart, the larger kept)
			if atTrainer and learned and GetTime() <= learned.till then learned.heard[event] = (learned.heard[event] or 0) + 1 end
		elseif waiting and not buying then
			-- (the trainer answered: the buttons back; the drawing itself comes with Book.lua's refresh)
			waiting = nil
		end
	end)
end

