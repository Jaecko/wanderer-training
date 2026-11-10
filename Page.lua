local _, ns = ...
local L = ns.L

-- The page of Training's window. On the left, a field to look for a spell, then everything to learn in sections
-- (to learn now, an earlier rank first, level by level, with a talent, outside what you play, set aside,
-- learned), each under a title in the book's lettering with its count and its sum; a row's signs show under the
-- mouse. On the right, what you play (the icons of your talent trees: lit when chosen), the three sums as a
-- ledger (now, the next level that brings something, everything left), your gold against them, the weapon skills
-- as tiles (a click pins their master; a sum of their own) and the demon tomes, then its buttons. Wanderer's
-- colors on the night.

local W = Wanderer
local U = W and W.Util
local Skin = W and W.Skin

local WIDTH, HEIGHT = 880, 620
local LEFT = 500 -- the list
local RIGHT_X, RIGHT = 548, 332 -- the right column
local ROW = 38
local TILE, TILE_GAP, TILE_ROW = 32, 8, 50 -- a weapon's tile, the room between two, a row with its price
local WAY = 30 -- a way's icon
local RANKS_ROOM = 44 -- the line of the old ranks, under the list
local SEARCH_ROOM = 34 -- the field to look for a spell, over the list
local LETTERING = "Fonts\\MORPHEUS.TTF" -- the book's titles (Latin letters only)
local NON_LATIN = { ruRU = true, koKR = true, zhCN = true, zhTW = true }

local page, list, view = nil, nil, {}
local rows = {} -- what the list shows
local model
local query = "" -- what is looked for (folded), "" for nothing

-- The inks, on the night of a Wanderer window.
local ink = {
	text = Skin.COLORS.text, soft = Skin.COLORS.soft, muted = Skin.COLORS.muted, title = Skin.COLORS.gold,
	rule = { 1, 0.82, 0, 0.2 }, hover = { 1, 1, 1, 0.05 }, track = { 1, 1, 1, 0.08 }, good = Skin.COLORS.good,
}

local function Ink(text, color)
	color = color or ink.text
	return U.Colorize(text, color[1], color[2], color[3])
end
local function Paint(region, color) region:SetTextColor(color[1], color[2], color[3]) end
local function Lettering(region, size)
	local font = LETTERING
	if NON_LATIN[GetLocale and GetLocale() or "enUS"] then font = _G.GameFontNormal and _G.GameFontNormal:GetFont() or "Fonts\\FRIZQT__.TTF" end
	region:SetFont(font, size, "")
end

-- Money in the ink of the page, with the coins' own icons.
local function Coins(copper, color) return U.Coins(math.max(0, copper or 0), color or ink.text) end

-- A thin rule, fading toward its end.
local function Rule(parent)
	local rule = parent:CreateTexture(nil, "ARTWORK")
	rule:SetHeight(1)
	rule:SetColorTexture(1, 1, 1, 1)
	return rule
end
local function Tint(rule)
	local c = ink.rule
	Skin.FadingRule(rule, c[4], false, c)
end

-- A window's heading (Skin.Header), a cog in it to Training's settings.
function ns.Header(window, title, margin, template)
	return Skin.Header(window, "Wanderer", title, { margin = margin, settings = "ext:training" }, template)
end

-- Looking for a spell --------------------------------------------------------------------------------------------
-- A field over the list (here and in the trainers' window): the sections holding what is typed stay, whole, each
-- row found marked by a fixed gold bar (never a pulse); the others go. Enter: the first one found in sight;
-- Escape: the field emptied.

local function Fold(text)
	text = U.Fold and U.Fold(text) or tostring(text or ""):lower()
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
-- (folded: what is looked for, folded already; "" finds everything)
function ns.Found(name, folded)
	if not folded or folded == "" then return true end
	return Fold(name):find(folded, 1, true) ~= nil
end

-- onChange(folded) at each letter, onEnter() on Enter.
function ns.SearchField(parent, onChange, onEnter)
	local field = Skin.CreateInput(parent, nil, 40, {
		hint = L.SEARCH_HINT,
		onChange = function(self) onChange(Fold(self:GetText() or "")) end,
		onEnter = function(self)
			self:ClearFocus()
			if onEnter then onEnter() end
		end,
		onEscape = function(self)
			self:SetText("")
			self:ClearFocus()
		end,
	})
	field:SetSize(200, 24)
	Skin.Tooltip(field, { L.SEARCH_HINT, L.SEARCH_DESC })
	return field
end

-- A row found: its gold bar on the left, a faint gold ground.
function ns.MarkFound(line, found)
	if not line.found then
		line.found = line:CreateTexture(nil, "ARTWORK", nil, 2)
		line.found:SetPoint("TOPLEFT", line, "TOPLEFT", 0, -3)
		line.found:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 0, 3)
		line.found:SetWidth(3)
		line.foundGround = line:CreateTexture(nil, "BACKGROUND", nil, 2)
		line.foundGround:SetAllPoints()
	end
	local gold = Skin.COLORS.gold
	line.found:SetColorTexture(gold[1], gold[2], gold[3], 1)
	line.foundGround:SetColorTexture(gold[1], gold[2], gold[3], 0.08)
	line.found:SetShown(found and true or false)
	line.foundGround:SetShown(found and true or false)
end

-- The first row found, brought into sight (two rows above it kept for its section's title).
function ns.ShowFound(shown, scrolled, folded, nameOf)
	for index, row in ipairs(shown) do
		if not row.header and ns.Found(nameOf(row), folded) then
			scrolled.offset = math.max(0, index - 3)
			return true
		end
	end
	return false
end

-- What can be done with a row --------------------------------------------------------------------------------
-- One card beside the row, the same on the page and at the trainer, opened by the row's "..." or its right
-- click: set aside (or counted again), counted anyway (or no more), the way to whom teaches it; at the trainer,
-- Learn first.

local function PinFailed(pinned) if not pinned then W.Print(L.PIN_FAILED) end end

-- The card's rows for an entry ({ text, glyph, hint, onClick, role }); opts.learn: the trainer's own Learn,
-- first; opts.noPin: at the trainer already, no way to one.
function ns.EntryActions(entry, opts)
	opts = opts or {}
	local actions = {}
	if opts.learn then actions[#actions + 1] = { text = L.LEARN_ONE, glyph = "chevron", hint = L.LEARN_DESC, onClick = opts.learn } end
	if entry and entry.status ~= "known" then
		if entry.ignored then
			actions[#actions + 1] = { text = L.COUNT_AGAIN, glyph = "back", hint = L.COUNT_AGAIN_DESC, onClick = function() ns.Ignore(entry.key, false) end }
		else
			actions[#actions + 1] = { text = L.IGNORE, glyph = "close", hint = L.IGNORE_DESC, onClick = function() ns.Ignore(entry.key, true) end }
		end
		if entry.kind == "spell" and not entry.mine and not entry.ignored then
			if entry.forced then
				actions[#actions + 1] = { text = L.UNCOUNT, glyph = "check", hint = L.UNCOUNT_DESC, onClick = function() ns.Count(entry.key, false) end }
			else
				actions[#actions + 1] = { text = L.COUNT, glyph = "plus", hint = L.COUNT_DESC, onClick = function() ns.Count(entry.key, true) end }
			end
		end
	end
	-- (a rank you know, lower than your best: in your hand, to put on a bar; it is kept at that rank there)
	if entry and entry.kind == "spell" and entry.status == "known" and ns.BestRank(entry.id) then
		actions[#actions + 1] = { text = L.RANKS_TAKE, glyph = "up", hint = L.RANKS_TAKE_DESC, onClick = function() ns.TakeRank(entry.id) end }
	end
	if entry and not opts.noPin then
		if entry.kind == "weapon" then
			actions[#actions + 1] = { text = L.PIN_MASTER, glyph = "home", hint = L.PIN_MASTER_HINT,
				onClick = function() PinFailed(ns.PinMaster(entry.masters)) end }
		else
			actions[#actions + 1] = { text = L.PIN_TRAINER, glyph = "home", hint = L.PIN_TRAINER_DESC,
				onClick = function() PinFailed(ns.PinClassTrainer()) end }
		end
	end
	return actions
end

-- The card itself, beside what opened it (at the mouse for a right click on the row).
function ns.EntryMenu(entry, owner, opts)
	local actions = ns.EntryActions(entry, opts)
	if not actions[1] then return end
	return Skin.ActionCard(owner, { title = (opts and opts.title) or (entry and entry.name) or "", rows = actions, atCursor = owner == nil })
end

-- The list ----------------------------------------------------------------------------------------------------

local function SortByLevel(a, b)
	if a.level ~= b.level then return a.level < b.level end
	return (a.name or "") < (b.name or "")
end

local function Row(entry)
	local quiet = entry.status == "known" or entry.ignored or entry.offSpec
	local name = entry.name or ""
	-- (the rank, quiet, after the name)
	if entry.sub then name = name .. "  " .. Ink(entry.sub, ink.muted) end
	-- (what the rank brings over the one before, quiet then bright)
	local gain = entry.kind == "spell" and ns.GainText(ns.RankGain(entry.id), ink.muted, entry.status == "known" and ink.muted or ink.good)
	if gain then name = name .. "   " .. gain end
	return { name = name, icon = entry.icon, quality = entry.quality, color = quiet and ink.muted or ink.text, entry = entry, link = entry.link }
end

-- A section of a list (the page's, the trainer's): nothing when empty, or when looking for a spell it does not
-- hold; else its title row ({ header, title, count, price, note }) then a row for each (rowOf). nameOf and priceOf
-- read an item (priceOf: nil when it does not count in the sum).
function ns.ListSection(into, items, title, rowOf, nameOf, priceOf, note, folded)
	if not items[1] then return end
	if folded and folded ~= "" then
		local any = false
		for _, item in ipairs(items) do any = any or ns.Found(nameOf(item), folded) end
		if not any then return end
	end
	local price = 0
	for _, item in ipairs(items) do price = price + (priceOf(item) or 0) end
	into[#into + 1] = { header = title, title = title, count = #items, price = price, note = note }
	for _, item in ipairs(items) do into[#into + 1] = rowOf(item) end
end

-- A section of the page: a breath before it, then its title (its count and sum beside) and its rows.
local function EntryName(entry) return entry.name end
local function EntryPrice(entry) return entry.counts and entry.price or nil end
local function Section(title, entries)
	table.sort(entries, SortByLevel)
	local before = #rows
	if rows[1] then rows[#rows + 1] = { header = "", spacer = true } end
	ns.ListSection(rows, entries, title, Row, EntryName, EntryPrice, nil, query)
	-- (no section after all: no breath either)
	if #rows == before + 1 then rows[#rows] = nil end
end

local function Gather()
	wipe(rows)
	local db = ns.DB()
	local groups = { now = {}, missing = {}, next = {}, later = {}, talent = {}, offSpec = {}, ignored = {}, known = {} }
	for _, entry in ipairs(model.entries) do
		local into
		if entry.kind == "weapon" or entry.kind == "tome" then
			into = nil -- (on the right)
		elseif entry.status == "known" then
			into = db.showKnown and groups.known
		elseif entry.ignored then
			into = groups.ignored
		elseif entry.status == "talent" then
			into = groups.talent
		elseif entry.offSpec then
			into = groups.offSpec
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
	Section(L.SECTION_NOW, groups.now)
	Section(L.SECTION_MISSING, groups.missing)
	if model.next then Section(L.SECTION_LEVEL:format(model.next), groups.next) end
	-- The levels after, each with its own sum.
	table.sort(groups.later, SortByLevel)
	local level, chunk = nil, {}
	for _, entry in ipairs(groups.later) do
		if entry.level ~= level then
			Section(L.SECTION_LEVEL:format(level or 0), chunk)
			chunk, level = {}, entry.level
		end
		chunk[#chunk + 1] = entry
	end
	if level then Section(L.SECTION_LEVEL:format(level), chunk) end
	Section(L.SECTION_TALENT, groups.talent)
	Section(L.SECTION_OFFSPEC, groups.offSpec)
	Section(L.SECTION_IGNORED, groups.ignored)
	Section(L.SECTION_KNOWN, groups.known)
end

-- A row's chip (what is particular about it), the same on the page and at the trainer (service: the trainer's
-- line, for its own states: learned, a later level, something else first).
function ns.EntryChip(entry, service)
	if service then
		if service.state == "used" then return nil end
		if service.later then return L.SECTION_LEVEL:format(service.later), "grey" end
		if service.state == "unavailable" then
			if service.skill then return L.CHIP_SKILL:format(service.skill), "grey" end
			return L.CHIP_MISSING, "gold"
		end
		if not entry then return nil end
	end
	if entry.quest then return L.CHIP_QUEST, "blue" end
	if entry.ignored then return L.CHIP_IGNORED, "grey" end
	if entry.offSpec then return L.CHIP_OFFSPEC, "grey" end
	if entry.forced and entry.status ~= "known" then return L.CHIP_COUNTED, "gold" end
	if entry.status == "talent" then return L.CHIP_TALENT, "blue" end
	if entry.status == "missing" and entry.skill then return L.CHIP_SKILL:format(entry.skill), "gold" end
	if entry.status == "missing" then return L.CHIP_MISSING, "gold" end
	return nil
end

-- A row under the mouse: its main action only (line.act, Learn at the trainer: over its price), and its "..."
-- (line.menu, the kit's: shown by the row itself, left of the price or of the action).
local function Hover(line)
	local over = (U.Hovered and U.Hovered(line) or line:IsMouseOver()) or (line.act ~= nil and line.act:IsMouseOver()) or (line.menu ~= nil and line.menu:IsMouseOver())
	local acting = line.act ~= nil and line.act.run ~= nil and over
	if line.act then line.act:SetShown(acting) end
	line.cells.price:SetAlpha(acting and 0 or 1)
end
ns.HoverRow = Hover

-- The row's "..." (opens(line) its card), quiet on a title.
function ns.DressMore(line, opens)
	line.menu = Skin.RowMore(line, opens, line.cells and line.cells.price)
	line.menu:HookScript("OnLeave", function() Hover(line) end)
	line:HookScript("OnEnter", function() Hover(line) end)
	line:HookScript("OnLeave", function() Hover(line) end)
end
function ns.ShowMore(line, usable)
	line.menu:SetAlpha(usable and 1 or 0)
	line.menu:EnableMouse(usable and true or false)
end

local function Dress(line)
	if line.wandererDressed then return end
	line.wandererDressed = true
	-- (its card: the same as its right click)
	ns.DressMore(line, function(self) if self.entry and self.entry.entry then ns.EntryMenu(self.entry.entry, self.menu) end end)
	line.name:SetFontObject(Skin.FontFor("GameFontNormal"))
	line.header:ClearAllPoints()
	line.header:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 4, 8)
	line.sum = Skin.Text(line, "GameFontNormal", "text")
	-- (its right edge on the prices' own: one column of sums down the page)
	local price = line.cells and line.cells.price
	if price then
		line.sum:SetPoint("BOTTOM", line, "BOTTOM", 0, 9)
		line.sum:SetPoint("RIGHT", price, "RIGHT", 0, 0)
	else
		line.sum:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", -16, 9)
	end
	line.rule = Rule(line)
	line.rule:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 4, 2)
	line.rule:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", -14, 2)
end

local function DrawList()
	if not list then return end
	local offset = list:Clamp(#rows)
	for index, line in ipairs(list.rows) do
		Dress(line)
		local row = rows[index + offset]
		local entry = row and row.entry
		local values, chip, tone
		if entry then
			values = { price = entry.price > 0 and Coins(entry.price) or Ink("-", ink.muted) }
			-- (a price seen at your trainer: a small tick before it; its tooltip says so)
			if entry.seen and entry.status ~= "known" then values.price = Skin.GlyphText("check", ink.muted, 10) .. " " .. values.price end
			chip, tone = ns.EntryChip(entry)
		end
		line:Fill(row, false, values, chip, tone)
		line.hover:SetColorTexture(ink.hover[1], ink.hover[2], ink.hover[3], ink.hover[4])
		-- Its "..." (none on a title).
		ns.ShowMore(line, entry ~= nil)
		ns.MarkFound(line, entry ~= nil and query ~= "" and ns.Found(entry.name, query))
		Hover(line)
		if line.chip:IsShown() then Paint(line.chip.text, ink.soft) end
		-- A title: the book's lettering, its count, its sum, a fine rule under it.
		local heading = row and row.header and not row.spacer
		line.rule:SetShown(heading or false)
		line.sum:SetShown(heading or false)
		if heading then
			Lettering(line.header, 17)
			line.header:SetText(row.title .. "   " .. Ink(tostring(row.count), ink.muted))
			Paint(line.header, ink.title)
			Tint(line.rule)
			line.sum:SetText(row.price > 0 and Coins(row.price) or "")
		elseif row and row.spacer then
			line.header:SetText("")
		end
	end
	list.empty:SetText(query ~= "" and L.SEARCH_NONE or L.EMPTY)
	list.empty:SetShown(#rows == 0)
end

-- The right column ---------------------------------------------------------------------------------------------

-- What you play, as a grid of two columns: each way's icon (lit when chosen), its name beside it (the room of half
-- the column: long names in every language whole). grid.height; grid:Draw(on, off) colors the names.
local GRID_ROW = 8
function ns.WaysGrid(parent, width, size)
	local grid = CreateFrame("Frame", nil, parent)
	local ways = ns.Ways()
	local cell = math.floor(width / 2)
	local rowsCount = math.ceil(#ways / 2)
	grid.height = rowsCount > 0 and rowsCount * (size + GRID_ROW) - GRID_ROW or 0
	grid:SetSize(width, math.max(1, grid.height))
	grid.buttons = {}
	for index, way in ipairs(ways) do
		local button = CreateFrame("Button", nil, grid)
		button:SetSize(cell - 6, size)
		button:SetPoint("TOPLEFT", grid, "TOPLEFT", ((index - 1) % 2) * cell, -math.floor((index - 1) / 2) * (size + GRID_ROW))
		button.way = way
		button.icon = Skin.Icon(button, size)
		button.icon:SetPoint("LEFT")
		button.icon:Set("Interface\\Icons\\" .. way.icon)
		button.glow = button:CreateTexture(nil, "BACKGROUND")
		button.glow:SetPoint("CENTER", button.icon, "CENTER")
		button.glow:SetSize(size + 20, size + 20)
		button.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
		button.glow:SetBlendMode("ADD")
		button.glow:SetVertexColor(1, 0.75, 0.25, 0.7)
		button.label = Skin.Text(button, "GameFontNormal", "text")
		button.label:SetPoint("LEFT", button.icon, "RIGHT", 9, 0)
		button.label:SetPoint("RIGHT", button, "RIGHT", 0, 0)
		button.label:SetJustifyH("LEFT")
		local label = way.scale and L["UPGRADE_SCALE_" .. way.scale] or L["BRANCH_" .. way.branch]
		button.label:SetText((label:gsub("^%l", string.upper)))
		-- (a name still too long for its room: a size smaller, rather than cut)
		if U.Measure(button.label, "GetStringWidth", 0) > cell - size - 15 then button.label:SetFontObject(Skin.FontFor("GameFontNormalSmall")) end
		button:SetScript("OnClick", function()
			Skin.Play("click")
			ns.ToggleWay(way.key)
		end)
		Skin.Tooltip(button, function() return ns.WayName(way) .. "\n\n" .. L.WAYS_DESC end)
		grid.buttons[#grid.buttons + 1] = button
	end
	function grid:Draw(onColor, offColor)
		local chosen = ns.Chosen()
		for _, button in ipairs(self.buttons) do
			local on = chosen and chosen[button.way.key] or false
			button.icon.texture:SetDesaturated(not on)
			button.icon:SetAlpha(on and 1 or 0.55)
			button.icon.edges.Color(1, 0.78, 0.2, on and 1 or 0.15)
			button.glow:SetShown(on)
			local color = on and onColor or offColor
			button.label:SetTextColor(color[1], color[2], color[3])
		end
		return chosen
	end
	return grid
end

local function DrawWays()
	view.plan.text:SetText(L.CALC_TITLE)
	view.plan:SetWidth(U.Measure(view.plan.text, "GetStringWidth", 80) + 2)
	local chosen = view.ways:Draw(ink.text, ink.muted)
	view.waysHint:SetShown(chosen == nil)
	view.sumsTitle:ClearAllPoints()
	view.sumsTitle:SetPoint("TOPLEFT", chosen == nil and view.waysHint or view.ways, "BOTTOMLEFT", 0, chosen == nil and -14 or -22)
end

local function DrawSums()
	local sums = model.sums
	local function Fill(line, caption, sum)
		line.caption:SetText(caption)
		line.amount:SetText(sum and sum.price > 0 and Coins(sum.price) or Ink("-", ink.muted))
		line.count:SetText(sum and L.SUM_COUNT:format(sum.count) or "")
	end
	Fill(view.sumNow, L.SUM_NOW, sums.now)
	Fill(view.sumNext, model.next and L.SUM_NEXT:format(model.next) or L.SUM_NEXT_NONE, model.next and sums.next or nil)
	Fill(view.sumAll, L.SUM_ALL, sums.all)
	-- (and what you left out would cost: what it saves)
	if sums.leftOut.price > 0 then
		view.sumAll.count:SetText(L.SUM_COUNT_LEFT_OUT:format(sums.all.count, Coins(sums.leftOut.price, ink.muted)))
	end
	-- Your gold against them: what is missing, for now, then for the next level.
	local money = GetMoney and GetMoney() or 0
	local now, nextPrice = sums.now.price, sums.now.price + sums.next.price
	local text
	if money < now then
		text = L.MONEY_NOW_SHORT:format(Coins(now - money))
	elseif model.next and money < nextPrice then
		text = L.MONEY_NEXT_SHORT:format(Coins(nextPrice - money), model.next)
	elseif model.next then
		text = L.MONEY_ENOUGH_SHORT:format(model.next)
	elseif money < sums.all.price then
		text = L.MONEY_ALL_SHORT:format(Coins(sums.all.price - money))
	else
		text = L.MONEY_ENOUGH_ALL_SHORT
	end
	view.gold:SetText(Coins(money))
	view.money:SetText(text)
	-- Your goal against your gold.
	local caption, amount, count = ns.GoalText(money)
	view.goal.caption:SetText(caption)
	Paint(view.goal.caption, ns.DB().goal and ink.text or ink.muted)
	view.goal.amount:SetText(amount)
	view.goal.count:SetText(count)
	local goal = model.next and nextPrice or sums.all.price
	local share = goal > 0 and math.min(1, money / goal) or 1
	view.moneyBar:SetWidth(math.max(1, (RIGHT - 2) * share))
	local tone = share >= 1 and Skin.COLORS.good or Skin.COLORS.warn
	view.moneyBar:SetColorTexture(tone[1], tone[2], tone[3], 0.9)
end

-- A weapon's tile: its icon edged by where it stands (green: to learn now; gold: a later level; faded: learned
-- or set aside), its price under it; hovered, who teaches it; a click pins the closest master.
local TONES = { now = Skin.COLORS.good, later = Skin.COLORS.warn, known = Skin.COLORS.muted }
local function Tile(index)
	view.tiles = view.tiles or {}
	if view.tiles[index] then return view.tiles[index] end
	local tile = CreateFrame("Button", nil, view.weapons)
	tile:SetSize(TILE, TILE_ROW - TILE_GAP)
	tile.icon = Skin.Icon(tile, TILE)
	tile.icon:SetPoint("TOP")
	tile.price = Skin.Text(tile, "GameFontNormalSmall", "text")
	tile.price:SetPoint("TOP", tile.icon, "BOTTOM", 0, -3)
	local hover = tile:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints(tile.icon)
	hover:SetColorTexture(1, 1, 1, 0.15)
	tile:RegisterForClicks("LeftButtonUp", "RightButtonUp") tile.padRight = true
	tile:SetScript("OnClick", function(self, mouse)
		local entry = self.entry
		if not entry then return end
		if mouse == "RightButton" then return ns.EntryMenu(entry, self) end
		PinFailed(ns.PinMaster(entry.masters))
	end)
	tile:SetScript("OnEnter", function(self)
		local entry = self.entry
		if not entry then return end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine(entry.name, ink.title[1], ink.title[2], ink.title[3])
		local state = entry.status == "known" and L.CHIP_KNOWN or entry.ignored and L.CHIP_IGNORED
			or entry.status == "now" and L.CHIP_NOW or L.SECTION_LEVEL:format(entry.level)
		GameTooltip:AddLine(state, 1, 1, 1)
		if entry.status ~= "known" then
			for _, npc in ipairs(entry.masters or {}) do GameTooltip:AddLine(L.TAUGHT_BY:format(ns.MasterText(npc)), ink.soft[1], ink.soft[2], ink.soft[3], true) end
			GameTooltip:AddLine(L.PIN_MASTER_HINT, ink.muted[1], ink.muted[2], ink.muted[3], true)
		end
		GameTooltip:Show()
	end)
	tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
	view.tiles[index] = tile
	return tile
end

-- Your other characters, in a line that opens Wanderer's window of them; the weapons follow it, or your gold.
local function DrawOthers()
	local others = W.Characters and W.Characters(true) or {}
	local total = 0
	for _, who in ipairs(others) do total = total + (who.money or 0) end
	view.others:SetShown(#others > 0)
	view.others.text:SetText(L.OTHERS_LINE:format(#others, Coins(total)))
	view.weaponsTitle:ClearAllPoints()
	view.weaponsTitle:SetPoint("TOPLEFT", #others > 0 and view.others or view.money, "BOTTOMLEFT", 0, -20)
end

local function DrawWeapons()
	local weapons = {}
	for _, entry in ipairs(model.entries) do if entry.kind == "weapon" then weapons[#weapons + 1] = entry end end
	table.sort(weapons, function(a, b) return (a.order or 0) < (b.order or 0) end)
	local perRow = math.floor((RIGHT + TILE_GAP) / (TILE + TILE_GAP))
	for index, entry in ipairs(weapons) do
		local tile = Tile(index)
		tile.entry = entry
		local faded = entry.status == "known" or entry.ignored
		tile.icon:Set(entry.icon)
		tile.icon.texture:SetDesaturated(faded)
		tile.icon:SetAlpha(faded and 0.6 or 1)
		local tone = faded and TONES.known or TONES[entry.status] or TONES.later
		tile.icon.edges.Color(tone[1], tone[2], tone[3], 1)
		tile.price:SetText(entry.status == "known" and "" or Coins(entry.price))
		tile:ClearAllPoints()
		local column, line = (index - 1) % perRow, math.floor((index - 1) / perRow)
		tile:SetPoint("TOPLEFT", view.weapons, "TOPLEFT", column * (TILE + TILE_GAP), -line * TILE_ROW)
		tile:Show()
	end
	for index = #weapons + 1, #(view.tiles or {}) do view.tiles[index]:Hide() end
	view.weapons:SetHeight(math.max(1, math.ceil(#weapons / perRow) * TILE_ROW - TILE_GAP))
	view.weaponsTitle:SetShown(weapons[1] ~= nil)
	-- (their own sum beside their title)
	local sum = model.sums.weapons
	view.weaponsSum:SetText(sum.price > 0 and Coins(sum.price) or "")
	-- The demon tomes, under the weapons: how many are left and what they cost.
	local tomes, price, left = 0, 0, 0
	for _, entry in ipairs(model.entries) do
		if entry.kind == "tome" and entry.status ~= "known" then
			left = left + 1
			if not entry.ignored then tomes, price = tomes + 1, price + entry.price end
		end
	end
	view.tomes:SetShown(left > 0)
	view.tomes.text:SetText(left > 0 and (Ink(L.SECTION_TOMES .. "   " .. tomes, ink.title) .. "   " .. Coins(price)) or "")
	view.tomes:SetSize(math.min(RIGHT, U.Measure(view.tomes.text, "GetStringWidth", 0) + 4), 16)
	-- The foot (what is learned, the pin): at the column's bottom; a column grown long (many weapons, a money
	-- sentence on two lines) keeps them under its last line instead of over it.
	local last = view.tomes:IsShown() and view.tomes or view.weapons
	local bottom, floor = last:GetBottom(), view.right:GetBottom()
	local foot = (view.known:GetHeight() or 20) + 8 + (view.pin:GetHeight() or 26) + 4
	view.known:ClearAllPoints()
	view.pin:ClearAllPoints()
	if bottom and floor and bottom - 12 < floor + foot then
		view.known:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -12)
		view.pin:SetPoint("TOPLEFT", view.known, "BOTTOMLEFT", 0, -8)
	else
		view.pin:SetPoint("BOTTOMLEFT", view.right, "BOTTOMLEFT", 0, 4)
		view.known:SetPoint("BOTTOMLEFT", view.pin, "TOPLEFT", 0, 8)
	end
end

-- The old ranks on your bars: a line under the list (the list a little shorter while it shows), its button.
local function FitList()
	list:Fit((view.listHeight or HEIGHT) - SEARCH_ROOM - (view.ranks:IsShown() and RANKS_ROOM or 0))
	view.ranks:SetWidth(list:GetWidth())
end

local function DrawRanks()
	local text = ns.RanksText()
	local was = view.ranks:IsShown()
	view.ranks:SetShown(text ~= nil)
	if text then
		view.ranks.text:SetText(text)
		view.ranks.update:SetText(ns.RanksButtonText())
		view.ranks.update:SetEnabled(ns.CanUpdateRanks())
	end
	if was ~= (text ~= nil) then FitList() end
end

-- (keep: the model as last read, only drawn again: your gold changed)
function ns.Draw(keep)
	if not (page and page:IsVisible() and ns.class) then return end
	if not (keep and model) then model = ns.Build() end
	DrawWays()
	DrawSums()
	DrawOthers()
	DrawRanks()
	Gather()
	DrawList()
	DrawWeapons()
	view.known:Refresh()
end

-- Built once ----------------------------------------------------------------------------------------------------

-- A small title of the right column, in the book's lettering, a rule under it.
local function Title(parent, text)
	local title = parent:CreateFontString(nil, "OVERLAY")
	Lettering(title, 15)
	title:SetText(text)
	Paint(title, ink.title)
	local rule = Rule(parent)
	rule:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	rule:SetWidth(RIGHT)
	Tint(rule)
	return title, rule
end

-- A line of the ledger: its caption and count on the left, its sum on the right, a rule under it.
local function Ledger(parent, anchor, gap)
	local line = CreateFrame("Frame", nil, parent)
	line:SetSize(RIGHT, 40)
	line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or 0))
	line:EnableMouse(true)
	line.caption = Skin.Text(line, "GameFontNormal", "text")
	line.caption:SetPoint("TOPLEFT", line, "TOPLEFT", 0, -5)
	line.count = Skin.Text(line, "GameFontNormalSmall", "muted")
	line.count:SetPoint("TOPLEFT", line.caption, "BOTTOMLEFT", 0, -4)
	line.amount = Skin.Text(line, "GameFontNormalLarge", "text")
	line.amount:SetPoint("RIGHT", line, "RIGHT", 0, 0)
	-- (the count stops short of the sum: a long one, cut rather than under it)
	line.count:SetPoint("RIGHT", line.amount, "LEFT", -10, 0)
	line.count:SetJustifyH("LEFT")
	if line.count.SetWordWrap then line.count:SetWordWrap(false) end
	local rule = Rule(line)
	rule:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 0, 0)
	rule:SetWidth(RIGHT)
	Tint(rule)
	return line
end

-- A button of the page (a right click too, for one that has a menu: RightClicks()).
local function PageButton(parent, text, width, height, onClick, tip)
	local button = Skin.Button(parent, text, onClick, nil, width)
	button:SetSize(width, height)
	if tip then Skin.Tooltip(button, tip) end
	function button:RightClicks() self:RegisterForClicks("LeftButtonUp", "RightButtonUp") self.padRight = true end
	return button
end

function ns.BuildPage()
	if page then return page end
	page = CreateFrame("Frame", "WandererTrainingPage", UIParent)
	page:SetSize(WIDTH, HEIGHT)
	page:Hide()
	-- On the left: everything, in sections.
	list = Skin.Table(page, {
		width = LEFT, rows = 30, rowHeight = ROW, titles = false,
		columns = { { key = "price", width = 80 } },
		onClick = function(row, mouse)
			if row.entry and mouse == "RightButton" then ns.EntryMenu(row.entry) end
		end,
		onDraw = DrawList,
	})
	list:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -SEARCH_ROOM)
	list:Fit(HEIGHT - SEARCH_ROOM)
	list.empty:SetText(L.EMPTY)
	-- Over it, the field to look for a spell.
	view.search = ns.SearchField(page, function(folded)
		query = folded
		list.offset = 0
		if model then
			Gather()
			DrawList()
		end
	end, function()
		if ns.ShowFound(rows, list, query, function(row) return row.entry and row.entry.name end) then DrawList() end
	end)
	view.search:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -2)
	-- On the right (held to the page's right side and its whole height: the page takes the room its host gives;
	-- the window's heading says what the page is).
	local right = CreateFrame("Frame", nil, page)
	right:SetWidth(RIGHT)
	view.right = right
	-- What you play: the icons of your talent trees.
	local waysTitle, waysRule = Title(right, L.WAYS)
	waysTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -6)
	view.ways = ns.WaysGrid(right, RIGHT, WAY)
	view.ways:SetPoint("TOPLEFT", waysRule, "BOTTOMLEFT", 0, -14)
	view.waysHint = Skin.Text(right, "GameFontNormalSmall", "soft")
	view.waysHint:SetPoint("TOPLEFT", view.ways, "BOTTOMLEFT", 0, -10)
	view.waysHint:SetWidth(RIGHT)
	view.waysHint:SetJustifyH("LEFT")
	view.waysHint:SetText(L.WAYS_NONE)
	-- Beside the title: your talents planned (their window), the next one when there is a plan.
	view.plan = CreateFrame("Button", nil, right)
	view.plan:SetHeight(16)
	view.plan:SetPoint("BOTTOMRIGHT", waysTitle, "BOTTOMLEFT", RIGHT, 0)
	view.plan.text = Skin.Text(view.plan, "GameFontNormalSmall", "gold")
	view.plan.text:SetPoint("RIGHT")
	view.plan:SetScript("OnClick", function() ns.ToggleTalents() end)
	Skin.Tooltip(view.plan, L.PLAN_OPEN_DESC)
	-- The three sums, as a ledger.
	local sumsTitle, sumsRule = Title(right, L.SUMS)
	view.sumsTitle = sumsTitle
	sumsTitle:SetPoint("TOPLEFT", view.ways, "BOTTOMLEFT", 0, -22)
	view.sumNow = Ledger(right, sumsRule, 2)
	view.sumNext = Ledger(right, view.sumNow)
	view.sumAll = Ledger(right, view.sumNext)
	Skin.Tooltip(view.sumNow, L.SUM_NOW_DESC)
	Skin.Tooltip(view.sumNext, L.SUM_NEXT_DESC)
	Skin.Tooltip(view.sumAll, L.SUM_ALL_DESC)
	-- A goal of your own under them: a click sets it, changes it or clears it.
	view.goal = Ledger(right, view.sumAll)
	view.goal:SetScript("OnMouseUp", function(self) ns.GoalMenu(self) end)
	Skin.Tooltip(view.goal, function() return ns.GoalTooltip() end)
	-- Your gold against them.
	local goldTitle = Title(right, L.YOUR_GOLD)
	goldTitle:SetPoint("TOPLEFT", view.goal, "BOTTOMLEFT", 0, -18)
	view.gold = Skin.Text(right, "GameFontNormal", "text")
	view.gold:SetPoint("BOTTOMRIGHT", goldTitle, "BOTTOMLEFT", RIGHT, 0)
	view.track = right:CreateTexture(nil, "BORDER")
	view.track:SetPoint("TOPLEFT", goldTitle, "BOTTOMLEFT", 0, -10)
	view.track:SetSize(RIGHT, 5)
	view.track:SetColorTexture(ink.track[1], ink.track[2], ink.track[3], ink.track[4])
	view.moneyBar = right:CreateTexture(nil, "ARTWORK")
	view.moneyBar:SetPoint("LEFT", view.track, "LEFT")
	view.moneyBar:SetHeight(5)
	view.money = Skin.Text(right, "GameFontNormalSmall", "soft")
	view.money:SetPoint("TOPLEFT", view.track, "BOTTOMLEFT", 0, -8)
	view.money:SetWidth(RIGHT)
	view.money:SetJustifyH("LEFT")
	-- Your other characters, in one line: a click opens Wanderer's window of them.
	view.others = CreateFrame("Button", nil, right)
	view.others:SetPoint("TOPLEFT", view.money, "BOTTOMLEFT", 0, -8)
	view.others:SetSize(RIGHT, 16)
	view.others.text = Skin.Text(view.others, "GameFontNormalSmall", "soft")
	view.others.text:SetPoint("LEFT")
	view.others.text:SetWidth(RIGHT)
	view.others.text:SetJustifyH("LEFT")
	if view.others.text.SetWordWrap then view.others.text:SetWordWrap(false) end
	view.others:SetScript("OnClick", function() if W.ToggleCharacters then W.ToggleCharacters() end end)
	Skin.Tooltip(view.others, L.OTHERS_DESC)
	-- The weapon skills, as tiles, their sum beside their title.
	local weaponsRule
	view.weaponsTitle, weaponsRule = Title(right, L.SECTION_WEAPONS)
	view.weaponsTitle:SetPoint("TOPLEFT", view.money, "BOTTOMLEFT", 0, -20)
	view.weaponsSum = Skin.Text(right, "GameFontNormal", "text")
	view.weaponsSum:SetPoint("BOTTOMRIGHT", view.weaponsTitle, "BOTTOMLEFT", RIGHT, 0)
	view.weapons = CreateFrame("Frame", nil, right)
	view.weapons:SetPoint("TOPLEFT", weaponsRule, "BOTTOMLEFT", 0, -10)
	view.weapons:SetSize(RIGHT, 1)
	view.tomes = CreateFrame("Button", nil, right)
	view.tomes:SetPoint("TOPLEFT", view.weapons, "BOTTOMLEFT", 0, -8)
	view.tomes.text = Skin.Text(view.tomes, "GameFontNormalSmall", "text")
	view.tomes.text:SetPoint("LEFT")
	view.tomes:SetScript("OnClick", function(self) ns.TomesMenu(self) end)
	Skin.Tooltip(view.tomes, L.TOMES_HINT)
	-- The buttons, at the foot.
	view.known = Skin.Check(right, L.SHOW_KNOWN, function() return ns.DB().showKnown end, function(value)
		ns.DB().showKnown = value or nil
		ns.Changed()
	end, L.SHOW_KNOWN_DESC)
	view.pin = PageButton(right, L.PIN_TRAINER, 160, 26, function()
		if not ns.PinClassTrainer() then W.Print(L.PIN_FAILED) end
	end, L.PIN_TRAINER_DESC)
	view.pin:SetWidth(math.max(160, (view.pin:GetFontString() and U.Measure(view.pin:GetFontString(), "GetStringWidth", 0) or 0) + 30))
	-- (above the button: beside the ways' title, it fell on the talents planned)
	view.pin:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 4)
	view.known:SetPoint("BOTTOMLEFT", view.pin, "TOPLEFT", 0, 8)
	-- Under the list: the old ranks on your bars, when there are some (a right click: a rank kept on purpose).
	view.ranks = CreateFrame("Button", nil, page)
	view.ranks:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
	view.ranks:SetSize(LEFT, RANKS_ROOM - 8)
	view.ranks:RegisterForClicks("RightButtonUp") view.ranks.padRight = true
	view.ranks:SetScript("OnClick", function(self) ns.RanksMenu(self) end)
	Skin.Tooltip(view.ranks, function() return ns.RanksTooltip() end)
	view.ranks:Hide()
	local ranksRule = Rule(view.ranks)
	ranksRule:SetPoint("TOPLEFT", view.ranks, "TOPLEFT", 4, 0)
	ranksRule:SetPoint("TOPRIGHT", view.ranks, "TOPRIGHT", -14, 0)
	Tint(ranksRule)
	view.ranks.update = PageButton(view.ranks, L.RANKS_UPDATE, 110, 26, function(self, mouse) ns.RanksClick(self, mouse) end,
		function() return ns.RanksTooltip() end)
	view.ranks.update:RightClicks()
	view.ranks.update:SetWidth(math.max(110, (view.ranks.update:GetFontString() and U.Measure(view.ranks.update:GetFontString(), "GetStringWidth", 0) or 0) + 30))
	view.ranks.update:SetPoint("BOTTOMRIGHT", view.ranks, "BOTTOMRIGHT", -14, 2)
	view.ranks.text = Skin.Text(view.ranks, "GameFontNormal", "soft")
	view.ranks.text:SetPoint("LEFT", view.ranks, "LEFT", 4, -2)
	view.ranks.text:SetPoint("RIGHT", view.ranks.update, "LEFT", -10, 0)
	view.ranks.text:SetJustifyH("LEFT")
	ns.OnRanksChanged(function() if page:IsVisible() then DrawRanks() end end)
	page:SetScript("OnShow", function() ns.Draw() end)
	return page
end

-- The demon tomes still to buy, in a card beside their line: each counted (a tick) or set aside, a click
-- changes it (the card stays, drawn again).
function ns.TomesMenu(owner)
	if not model then return end
	local actions = {}
	for _, entry in ipairs(model.entries) do
		if entry.kind == "tome" and entry.status ~= "known" then
			actions[#actions + 1] = { text = entry.name, glyph = entry.ignored and "dot" or "check", role = entry.ignored and "muted" or nil,
				right = U.CoinsWords(entry.price), hint = entry.ignored and L.COUNT_AGAIN_DESC or L.IGNORE_DESC,
				onClick = function()
					ns.Ignore(entry.key, not entry.ignored)
					model = ns.Build()
					ns.TomesMenu(owner)
				end }
		end
	end
	if not actions[1] then return end
	return Skin.ActionCard(owner, { title = L.SECTION_TOMES, rows = actions, foot = L.TOMES_HINT, width = 280 })
end

-- The page in its window, as drawn (the window is scaled already).
function ns.PlacePage(host)
	ns.BuildPage()
	page:SetParent(host)
	page:ClearAllPoints()
	page:SetPoint("CENTER", host, "CENTER", 0, 0)
	local width, height = (host:GetWidth() or 0) - 20, (host:GetHeight() or 0) - 12
	local pageWidth = width > 0 and math.min(WIDTH, width) or WIDTH
	local pageHeight = math.max(HEIGHT, height > 0 and height or HEIGHT)
	page:SetScale(1)
	page:SetSize(pageWidth, pageHeight)
	local right = view.right
	right:ClearAllPoints()
	list:SetWidth(pageWidth - (RIGHT_X - LEFT) - RIGHT)
	right:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
	view.listHeight = pageHeight
	FitList()
	page:SetFrameLevel(host:GetFrameLevel() + 5)
	-- (shown for the first time, it draws itself)
	if page:IsShown() then ns.Draw() else page:Show() end
end

-- A goal of your own ------------------------------------------------------------------------------------------------
-- A sum you save for (a name and an amount, this character's), in the ledger under the three sums: what you have
-- against it. Riding is offered in one click, its price an estimate (Forever's not confirmed), changed as you wish.

local RIDING = 900000 -- 90 gold: riding and a mount at level 40, an estimate

-- The goal set (nil: none), and a new one (nil: none any more).
function ns.Goal() return ns.DB().goal end
function ns.SetGoal(name, amount, preset)
	local db = ns.DB()
	amount = tonumber(amount)
	if name and amount and amount > 0 then
		db.goal = { name = name, amount = math.floor(amount), preset = preset }
	else
		db.goal = nil
	end
	ns.Changed()
end
ns.RIDING_ESTIMATE = RIDING

-- Its line: caption, amount, the words under it (what is left, or reached).
function ns.GoalText(money)
	local goal = ns.Goal()
	if not goal then return L.GOAL_NONE, "", L.GOAL_NONE_HINT end
	money = math.max(0, money or 0)
	local count
	if money >= goal.amount then
		count = L.GOAL_REACHED
	else
		count = L.GOAL_LEFT:format(math.floor(money * 100 / goal.amount), Coins(goal.amount - money, ink.muted))
	end
	return goal.name, Coins(goal.amount), count
end

-- (the riding goal still at its estimate: said so)
local function Estimate(goal) return goal ~= nil and goal.preset == "riding" and goal.amount == RIDING end

function ns.GoalTooltip()
	local goal = ns.Goal()
	local lines = { goal and goal.name or L.GOAL, L.GOAL_DESC }
	if Estimate(goal) then lines[#lines + 1] = { L.GOAL_RIDING_DESC, ink.muted[1], ink.muted[2], ink.muted[3] } end
	return lines
end

-- Its amount asked, in gold (the one there to start with).
local function AskAmount(name, preset, amount)
	Skin.AskText(L.GOAL_AMOUNT_ASK, tostring(math.floor((amount or 0) / 10000)), function(text)
		local gold = tonumber((tostring(text or ""):gsub(",", ".")))
		if gold and gold > 0 then ns.SetGoal(name, gold * 10000, preset) end
	end, 7)
end

-- A click on its line: a card beside it (riding or a goal of your own; once set, changed or cleared).
function ns.GoalMenu(owner)
	local goal = ns.Goal()
	local choices = {}
	if goal then
		choices[1] = { text = L.GOAL_AMOUNT, glyph = "chevron", right = U.CoinsWords(goal.amount),
			onClick = function() AskAmount(goal.name, goal.preset, goal.amount) end }
		choices[2] = { text = L.GOAL_RENAME, glyph = "chevron", onClick = function()
			Skin.AskText(L.GOAL_NAME_ASK, goal.name, function(text) ns.SetGoal(text, goal.amount, goal.preset) end, 40)
		end }
		choices[3] = { text = L.GOAL_CLEAR, glyph = "close", role = "muted", onClick = function() ns.SetGoal(nil) end }
	else
		choices[1] = { text = L.GOAL_RIDING, glyph = "plus", right = U.CoinsWords(RIDING), hint = L.GOAL_RIDING_DESC,
			onClick = function() ns.SetGoal(L.GOAL_RIDING, RIDING, "riding") end }
		choices[2] = { text = L.GOAL_OWN, glyph = "plus", onClick = function()
			Skin.AskText(L.GOAL_NAME_ASK, "", function(text) AskAmount(text, nil, 0) end, 40)
		end }
	end
	return Skin.ActionCard(owner, { title = L.GOAL, rows = choices, foot = L.GOAL_DESC, width = 280 })
end
