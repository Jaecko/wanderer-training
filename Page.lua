local _, ns = ...
local L = ns.L

-- The page: what you play (its ways, a click takes or leaves one), the three sums (now, the next level that
-- brings something, everything left) and your gold beside them, then everything in sections: to learn now, an
-- earlier rank first, the next level, the levels after (each with its sum), the weapon skills, the demon
-- tomes, what asks a talent, what is of another way, what is set aside, what is learned (if asked). One page,
-- shown in the spellbook's tab or in a window of its own (Book.lua).

local W = Wanderer
local U = W and W.Util
local Skin = W and W.Skin

local WIDTH = 660
local TOP = 196 -- the ways, the sums, the gold
local BOTTOM = 40 -- the buttons
local ROW = 30

local page, list, view = nil, nil, {}
local rows = {} -- what the table shows
local model

-- The sections ------------------------------------------------------------------------------------------------

local CHIPS = {
	now = { "CHIP_NOW", "green" }, missing = { "CHIP_MISSING", "gold" }, talent = { "CHIP_TALENT", "blue" },
	known = { "CHIP_KNOWN", "green" },
}

local function SortByLevel(a, b)
	if a.level ~= b.level then return a.level < b.level end
	return (a.name or "") < (b.name or "")
end

-- A heading with its count and its sum.
local function Heading(text, entries)
	local price = 0
	for _, entry in ipairs(entries) do if entry.counts then price = price + entry.price end end
	local said = text .. "  ·  " .. #entries
	if price > 0 then said = said .. "  ·  " .. ns.MoneyText(price) end
	return { header = said }
end

local function Row(entry)
	local name = entry.name or ""
	if entry.sub then name = name .. "  " .. U.Colorize("(" .. entry.sub .. ")", 0.56, 0.53, 0.46) end
	local color = entry.status == "known" and Skin.COLORS.muted or (entry.ignored or entry.offSpec) and Skin.COLORS.soft or nil
	local row = { name = name, icon = entry.icon, quality = entry.quality, color = color or Skin.COLORS.text, entry = entry }
	if entry.kind == "weapon" then
		local masters = {}
		for _, npc in ipairs(entry.masters or {}) do masters[#masters + 1] = ns.MasterText(npc) end
		row.tip = { entry.name, L.TAUGHT_BY:format(table.concat(masters, ", ")), L.PIN_MASTER_HINT }
	else
		row.link = entry.link
	end
	return row
end

local function Gather()
	wipe(rows)
	local db = ns.DB()
	local groups = { now = {}, missing = {}, next = {}, later = {}, weapons = {}, tomes = {}, talent = {}, offSpec = {}, ignored = {},
		known = {} }
	for _, entry in ipairs(model.entries) do
		local into
		if entry.status == "known" then
			into = db.showKnown and groups.known
		elseif entry.ignored then
			into = groups.ignored
		elseif entry.status == "talent" then
			into = groups.talent
		elseif entry.offSpec then
			into = groups.offSpec
		elseif entry.kind == "weapon" then
			into = groups.weapons
		elseif entry.kind == "tome" then
			into = groups.tomes
		elseif entry.status == "now" then
			into = groups.now
		elseif entry.status == "missing" then
			into = groups.missing
		elseif entry.level == model.next then
			into = groups.next
		else
			into = groups.later
		end
		if into then into[#into + 1] = entry end
	end
	local function Section(title, entries)
		if not entries[1] then return end
		table.sort(entries, SortByLevel)
		rows[#rows + 1] = Heading(title, entries)
		for _, entry in ipairs(entries) do rows[#rows + 1] = Row(entry) end
	end
	Section(L.SECTION_NOW, groups.now)
	Section(L.SECTION_MISSING, groups.missing)
	if model.next then Section(L.SECTION_LEVEL:format(model.next), groups.next) end
	-- The levels after, each with its own sum.
	table.sort(groups.later, SortByLevel)
	local level, chunk = nil, {}
	local function Flush()
		if chunk[1] then Section(L.SECTION_LEVEL:format(level), chunk) end
		chunk = {}
	end
	for _, entry in ipairs(groups.later) do
		if entry.level ~= level then
			Flush()
			level = entry.level
		end
		chunk[#chunk + 1] = entry
	end
	Flush()
	Section(L.SECTION_WEAPONS, groups.weapons)
	Section(L.SECTION_TOMES, groups.tomes)
	Section(L.SECTION_TALENT, groups.talent)
	Section(L.SECTION_OFFSPEC, groups.offSpec)
	Section(L.SECTION_IGNORED, groups.ignored)
	Section(L.SECTION_KNOWN, groups.known)
end

-- A row's chip and its button.
local function ChipOf(entry)
	if entry.quest then return L.CHIP_QUEST, "blue" end
	if entry.ignored then return L.CHIP_IGNORED, "grey" end
	if entry.offSpec then return L.CHIP_OFFSPEC, "grey" end
	if entry.forced and entry.status ~= "known" then return L.CHIP_COUNTED, "gold" end
	local chip = CHIPS[entry.status]
	if chip then return L[chip[1]], chip[2] end
	return nil
end

local function ActionOf(entry)
	if entry.status == "known" then return nil end
	if entry.ignored then return L.RESTORE, function() ns.Ignore(entry.key, false) end end
	if entry.offSpec then return L.COUNT, function() ns.Count(entry.key, true) end end
	if entry.forced then return L.UNCOUNT, function() ns.Count(entry.key, false) end end
	if entry.status == "talent" then return nil end
	return L.IGNORE, function() ns.Ignore(entry.key, true) end
end

local function DrawList()
	if not list then return end
	local offset = list:Clamp(#rows)
	for index, line in ipairs(list.rows) do
		local row = rows[index + offset]
		local entry = row and row.entry
		local values, chip, tone, actionText, action
		if entry then
			values = { level = tostring(entry.level), price = entry.price > 0 and U.Coins(entry.price) or "-" }
			chip, tone = ChipOf(entry)
			actionText, action = ActionOf(entry)
		end
		line:Fill(row, false, values, chip, tone, actionText, action)
	end
	list.empty:SetShown(#rows == 0)
end

-- The top: the ways, the sums, the gold ------------------------------------------------------------------------

local function DrawWays()
	local chosen = ns.Chosen()
	for _, button in ipairs(view.ways) do
		local on = chosen and chosen[button.way.key] or false
		button.ground:SetColorTexture(on and 0.54 or 1, on and 0.43 or 1, on and 0.07 or 1, on and 0.9 or 0.04)
		button.caption:SetTextColor(on and 1 or 0.85, on and 0.96 or 0.75, on and 0.84 or 0.5)
	end
	view.waysHint:SetShown(chosen == nil)
end

local function DrawSums()
	local sums = model.sums
	local function Fill(card, caption, sum)
		card.caption:SetText(U.Upper(caption))
		card.amount:SetText(sum and U.Coins(sum.price) or "-")
		card.count:SetText(sum and L.SUM_COUNT:format(sum.count) or "")
	end
	Fill(view.sumNow, L.SUM_NOW, sums.now)
	Fill(view.sumNext, model.next and L.SUM_NEXT:format(model.next) or L.SUM_NEXT_NONE, model.next and sums.next or nil)
	Fill(view.sumAll, L.SUM_ALL, sums.all)
	-- Your gold beside them: what is missing, for now then for the next level.
	local money = GetMoney and GetMoney() or 0
	local now, nextPrice = sums.now.price, sums.now.price + sums.next.price
	local text
	if money < now then
		text = L.MONEY_NOW:format(U.Coins(money), U.Coins(now - money))
	elseif model.next and money < nextPrice then
		text = L.MONEY_NEXT:format(U.Coins(money), U.Coins(nextPrice - money), model.next)
	elseif model.next then
		text = L.MONEY_ENOUGH:format(U.Coins(money), model.next)
	else
		text = L.MONEY_ENOUGH_ALL:format(U.Coins(money))
	end
	view.money:SetText(text)
	local goal = model.next and nextPrice or now
	local share = goal > 0 and math.min(1, money / goal) or 1
	view.moneyBar:SetWidth(math.max(1, (WIDTH - 2) * share))
	view.moneyBar:SetColorTexture(share >= 1 and 0.31 or 1, share >= 1 and 0.78 or 0.7, share >= 1 and 0.43 or 0.25, 0.85)
end

local function DrawBottom()
	local db = ns.DB()
	view.known:Refresh()
	view.weapons:SetLabel(db.noWeapons and L.WEAPONS_COUNT or L.WEAPONS_IGNORE)
	local trainer = ns.AtClassTrainer()
	view.learn:SetShown(trainer)
	if trainer then
		local count = #ns.TrainerServices()
		view.learn:SetText(L.LEARN:format(count))
		view.learn:Fit()
		view.learn:SetEnabled(count > 0)
	end
end

function ns.Draw()
	if not (page and page:IsVisible() and ns.class) then return end
	model = ns.Build()
	DrawWays()
	DrawSums()
	Gather()
	DrawList()
	DrawBottom()
end

-- Built once ----------------------------------------------------------------------------------------------------

local function Card(parent, x)
	local card = Skin.Panel(parent)
	card:SetSize(208, 74)
	card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -78)
	card.caption = Skin.Caps(card, "", "gold")
	card.caption:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -10)
	card.amount = Skin.Text(card, "GameFontHighlightLarge", "text")
	card.amount:SetPoint("TOPLEFT", card.caption, "BOTTOMLEFT", 0, -8)
	card.count = Skin.Text(card, "GameTooltipTextSmall", "muted")
	card.count:SetPoint("TOPLEFT", card.amount, "BOTTOMLEFT", 0, -5)
	return card
end

function ns.BuildPage()
	if page then return page end
	page = CreateFrame("Frame", "WandererTrainingPage", UIParent)
	page:SetWidth(WIDTH)
	page:Hide()
	-- What you play.
	local caps = Skin.Caps(page, L.WAYS, "gold")
	caps:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -6)
	Skin.Tooltip(caps, L.WAYS_DESC)
	view.ways = {}
	local previous
	for _, way in ipairs(ns.Ways()) do
		local button = Skin.SmallButton(page, ns.WayName(way), function()
			ns.ToggleWay(way.key)
		end, L.WAYS_DESC, 24)
		button.way = way
		if previous then button:SetPoint("LEFT", previous, "RIGHT", 6, 0) else button:SetPoint("TOPLEFT", caps, "BOTTOMLEFT", 0, -8) end
		view.ways[#view.ways + 1] = button
		previous = button
	end
	view.waysHint = Skin.Text(page, "GameTooltipTextSmall", "muted")
	view.waysHint:SetPoint("TOPLEFT", caps, "BOTTOMLEFT", 0, -38)
	view.waysHint:SetWidth(WIDTH)
	view.waysHint:SetJustifyH("LEFT")
	view.waysHint:SetText(L.WAYS_NONE)
	-- The three sums.
	view.sumNow = Card(page, 0)
	view.sumNext = Card(page, 226)
	view.sumAll = Card(page, 452)
	Skin.Tooltip(view.sumNow, L.SUM_NOW_DESC)
	Skin.Tooltip(view.sumNext, L.SUM_NEXT_DESC)
	Skin.Tooltip(view.sumAll, L.SUM_ALL_DESC)
	-- Your gold.
	view.money = Skin.Text(page, "GameTooltipText", "soft")
	view.money:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -164)
	local track = page:CreateTexture(nil, "BORDER")
	track:SetPoint("TOPLEFT", view.money, "BOTTOMLEFT", 0, -6)
	track:SetSize(WIDTH, 3)
	track:SetColorTexture(1, 1, 1, 0.08)
	view.moneyBar = page:CreateTexture(nil, "ARTWORK")
	view.moneyBar:SetPoint("LEFT", track, "LEFT")
	view.moneyBar:SetHeight(3)
	-- Everything, in sections.
	list = Skin.Table(page, {
		width = WIDTH, rows = 40, rowHeight = ROW, action = 110, nameTitle = L.COL_NAME,
		columns = { { key = "level", title = L.COL_LEVEL, width = 50 }, { key = "price", title = L.COL_PRICE, width = 110 } },
		onClick = function(row, mouse)
			local entry = row.entry
			if not entry then return end
			if entry.kind == "weapon" and mouse ~= "RightButton" then
				if not ns.PinMaster(entry.masters) and W.Print then W.Print(L.PIN_FAILED) end
				return
			end
			if mouse == "RightButton" then ns.EntryMenu(entry) end
		end,
		onDraw = DrawList,
	})
	list:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -TOP)
	list.empty:SetText(L.EMPTY)
	-- The buttons.
	view.pin = Skin.SmallButton(page, L.PIN_TRAINER, function()
		if not ns.PinClassTrainer() and W.Print then W.Print(L.PIN_FAILED) end
	end, L.PIN_TRAINER_DESC, 26)
	view.pin:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 6)
	view.weapons = Skin.SmallButton(page, L.WEAPONS_IGNORE, function()
		local db = ns.DB()
		db.noWeapons = not db.noWeapons or nil
		ns.Changed()
	end, L.WEAPONS_DESC, 26)
	view.weapons:SetPoint("LEFT", view.pin, "RIGHT", 8, 0)
	view.known = Skin.Check(page, L.SHOW_KNOWN, function() return ns.DB().showKnown end, function(value)
		ns.DB().showKnown = value or nil
		ns.Changed()
	end, L.SHOW_KNOWN_DESC)
	view.known:SetPoint("LEFT", view.weapons, "RIGHT", 14, 0)
	view.learn = Skin.Button(page, L.LEARN:format(0), function()
		ns.LearnServices()
	end, "main", 160)
	view.learn:SetHeight(30)
	view.learn:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 4)
	Skin.Tooltip(view.learn, L.LEARN_DESC)
	view.learn:Hide()
	-- As many rows as the height holds.
	page:SetScript("OnSizeChanged", function(self, _, height)
		list:Fit(math.max(ROW * 3, (height or self:GetHeight()) - TOP - BOTTOM))
	end)
	page:SetScript("OnShow", function() ns.Draw() end)
	return page
end

-- A right click on a row: what can be done with it.
function ns.EntryMenu(entry)
	U.Menu(page, function(_, root)
		root:CreateTitle(entry.name or "")
		if entry.status ~= "known" then
			if entry.ignored then
				root:CreateButton(L.RESTORE, function() ns.Ignore(entry.key, false) end)
			else
				root:CreateButton(L.IGNORE, function() ns.Ignore(entry.key, true) end)
			end
			if entry.kind == "spell" and not entry.mine then
				root:CreateButton(entry.forced and L.UNCOUNT or L.COUNT, function() ns.Count(entry.key, not entry.forced) end)
			end
		end
		if entry.kind == "weapon" then
			root:CreateButton(L.PIN_MASTER, function() if not ns.PinMaster(entry.masters) and W.Print then W.Print(L.PIN_FAILED) end end)
		else
			root:CreateButton(L.PIN_TRAINER, function() if not ns.PinClassTrainer() and W.Print then W.Print(L.PIN_FAILED) end end)
		end
	end)
end

-- The page placed in a host (the spellbook's tab, or the window): filling it, under its own heading.
function ns.PlacePage(host, top, bottom)
	ns.BuildPage()
	page:SetParent(host)
	page:ClearAllPoints()
	page:SetPoint("TOP", host, "TOP", 0, -(top or 0))
	page:SetPoint("BOTTOM", host, "BOTTOM", 0, bottom or 0)
	page:SetFrameLevel(host:GetFrameLevel() + 5)
	page:Show()
	ns.Draw()
end

function ns.PageShown() return page ~= nil and page:IsVisible() end
