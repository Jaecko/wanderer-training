local ADDON, ns = ...
local L = ns.L

-- Where the page is shown: Training's own window, always (Wanderer's look), opened by Wanderer's bar and menu, a
-- key, /wtraining, or the button on the game's spellbook (where its tab was: beside the book's own tabs, as What's
-- Training's; the book itself is never opened nor touched, the game loads it, never this addon). The launcher's
-- word pulses while something that counts can be learned now; a short notice at a new level (an option, off).

local W = Wanderer
local U = W and W.Util
local Skin = W and W.Skin

local ICON = "Interface\\Icons\\INV_Misc_Book_07"

local launcher, window
local attention = false

local Settings = ns.Settings

-- Drawn again a moment after a change (many come at once); the launcher's word kept in step.
local function Refresh()
	if not ns.class then return end
	attention = ns.Build().sums.trainer.count > 0
	ns.Draw()
	ns.DrawTrainer()
end
-- (made in Init, once Wanderer is known to be recent enough)
local refresh, redraw
function ns.Changed()
	ns.Invalidate()
	if refresh then refresh() end
end

function ns.Attention() return attention end

-- Under the launcher's word: what waits at your trainer now, then at the next level that brings something.
-- Lines { text, role } (also .text, .role).
local function Line(text, role) return { text, role, text = text, role = role } end
function ns.Summary()
	if not ns.class then return nil end
	local model = ns.Build()
	local now, lines = model.sums.trainer, {}
	if now.count > 0 then
		lines[1] = Line(L.SUMMARY_NOW:format(now.count, U.Coins(now.price)), "text")
	else
		lines[1] = Line(L.SUMMARY_NOTHING, "muted")
	end
	if model.next and model.sums.next.count > 0 then
		lines[2] = Line(L.SUMMARY_NEXT:format(model.next, model.sums.next.count, U.Coins(model.sums.next.price)), "soft")
	end
	return lines
end

-- The window of its own -------------------------------------------------------------------------------------------

local function Window()
	if window then return window end
	window = Skin.CreateWindow("WandererTrainingWindow", "MEDIUM")
	Skin.Dress(window, { "CENTER", UIParent, "CENTER", 0, 20 }, "trainingPos")
	window:SetSize(960, 720)
	-- (the page says what it is in the heading: "Wanderer", then what your trainers have for you)
	local _, _, margin = ns.Header(window, L.HEADING)
	window.content = CreateFrame("Frame", nil, window)
	window.content:SetPoint("TOPLEFT", window, "TOPLEFT", margin, -(margin + 40))
	window.content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -margin, margin)
	window:HookScript("OnShow", function(self)
		self:SetScale(Skin.FitScale(self))
		ns.PlacePage(self.content)
		if launcher then launcher.active:Show() launcher.normal:Hide() end
	end)
	window:HookScript("OnHide", function()
		if launcher then launcher.active:Hide() launcher.normal:Show() end
	end)
	Skin.Get(window):Layout()
	return window
end

-- The spellbook's button ----------------------------------------------------------------------------------------
-- Where the tab was, beside the book's own tabs (and What's Training's): a click opens or closes Training's
-- window; lit while it is open.

local function Book() return PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame end

local function PlaceLauncher()
	local book = Book()
	local tabs = book and book.CategoryTabSystem
	if not (launcher and tabs) then return end
	launcher:ClearAllPoints()
	local other = _G.WhatsTrainingLauncher
	if other and other:IsShown() then
		launcher:SetPoint("LEFT", other, "RIGHT", 4, 0)
	else
		launcher:SetPoint("LEFT", tabs, "RIGHT", 8, 0)
	end
end

local function Art(button, atlas)
	local texture = button:CreateTexture(nil, "ARTWORK", nil, 1)
	if not pcall(texture.SetAtlas, texture, atlas, true) or not texture:GetAtlas() then
		texture:SetColorTexture(1, 0.82, 0, 0)
	end
	texture:SetPoint("BOTTOM", 0, 1)
	return texture
end

local function Attach()
	local book = Book()
	if launcher or not book then return end
	launcher = CreateFrame("Button", "WandererTrainingLauncher", book)
	launcher:SetSize(44, 32)
	launcher:SetFrameLevel(book:GetFrameLevel() + 25)
	launcher.icon = launcher:CreateTexture(nil, "ARTWORK")
	launcher.icon:SetSize(34, 33)
	launcher.icon:SetPoint("BOTTOM", -1, 0)
	launcher.icon:SetTexture(ICON)
	launcher.normal = Art(launcher, "spellbook-Tab-Frame-C60")
	launcher.active = Art(launcher, "spellbook-Tab-Frame-Glow-C60")
	local open = window ~= nil and window:IsShown()
	launcher.active:SetShown(open)
	launcher.normal:SetShown(not open)
	launcher:SetScript("OnClick", function()
		Skin.Play("click")
		ns.Toggle()
	end)
	Skin.Tooltip(launcher, L.TAB_TOOLTIP)
	book:HookScript("OnShow", PlaceLauncher)
	PlaceLauncher()
	ns.RefreshBook()
end

-- The button on the book only while Wanderer is on (off: nothing of Training on the game's windows).
function ns.RefreshBook()
	if launcher then launcher:SetShown(Settings() ~= nil) end
end

-- Opening ---------------------------------------------------------------------------------------------------------

-- (always the window: nothing of the game's to open, so it comes in a fight too)
function ns.Open()
	if not ns.class then return end
	local made = Window()
	if made:IsShown() then return Skin.Front and Skin.Front(made) end
	made:Show()
end

function ns.Toggle()
	if window and window:IsShown() then return window:Hide() end
	ns.Open()
end

-- Init ------------------------------------------------------------------------------------------------------------

BINDING_HEADER_WANDERERTRAINING = "Wanderer Training"
BINDING_NAME_WANDERERTRAINING_TOGGLE = L.TITLE
function WandererTraining_Toggle() ns.Toggle() end

-- A new level: what it brings, said briefly (an option).
local function LevelUp(level)
	local settings = Settings()
	if not (settings and settings.remind) then return end
	local sums = ns.Build(level).sums
	if sums.trainer.count > 0 then W.Toast(L.TITLE, L.REMIND_TEXT:format(sums.trainer.count, U.Coins(sums.trainer.price)), { kicker = "Wanderer", duration = 6 }) end
end

function ns.Init()
	if not (W and W.RegisterExtension) then return end
	-- (built on Wanderer's API 15: an older Wanderer is only asked to update, nothing of it is called)
	if (W.API or 1) < 15 then return W.Print(L.NEEDS_WANDERER) end
	refresh = U.Debounce(0.2, Refresh)
	redraw = U.Debounce(0.2, function() ns.Draw(true) end)
	W.RegisterExtension({
		key = "training",
		addon = ADDON,
		slash = "/wtraining",
		title = L.ADDON,
		news = L.NEWS_LINES,
		defaults = { remind = false, trainer = true, talentsReminder = true, naowhPanel = true, spellTips = true,
			talentsPanel = true, talentsMarks = true, talentsGuard = true, ranksAuto = true },
		launcher = { label = L.TITLE, open = function() ns.Toggle() end, attention = function() return ns.Attention() end,
			summary = function() return ns.Summary() end },
		-- (Wanderer turned on or off: the book's button with it)
		refresh = function() ns.RefreshBook() end,
		-- (the trainers' window replaced: Wanderer's own "Learn all" at the trainer steps aside)
		takes = { trainerWindow = function() local settings = Settings() return settings ~= nil and settings.trainer ~= false end },
		-- (as every page: the essentials, the talent planner, the rest folded)
		options = function(o)
			o.Button(L.TITLE, L.OPEN, L.OPEN_DESC, function()
				o.CloseSettings()
				ns.Open()
			end)
			local trainer = o.Checkbox("training", "trainer", L.TRAINER_OPTION, L.TRAINER_OPTION_DESC)
			-- (only with Naowh Training there: its panel at the class trainer)
			if ns.NaowhTraining() then
				o.Under(o.Checkbox("training", "naowhPanel", L.NAOWH_PANEL, L.NAOWH_PANEL_DESC), trainer, o.IsOn("training", "trainer"))
			end
			o.Checkbox("training", "spellTips", L.SPELL_TIPS, L.SPELL_TIPS_DESC)
			o.Checkbox("training", "ranksAuto", L.RANKS_AUTO, L.RANKS_AUTO_DESC)

			-- (both notices of a new level together: what your trainer has, the talent your plan takes)
			o.Header(L.SECTION_AT_LEVEL)
			o.Checkbox("training", "remind", L.REMIND, L.REMIND_DESC)
			o.Checkbox("training", "talentsReminder", L.PLAN_REMIND, L.PLAN_REMIND_DESC)

			o.Header(L.PLAN_TITLE)
			o.Button(L.PLAN_TITLE, L.OPEN, L.PLAN_OPEN_DESC, function()
				o.CloseSettings()
				ns.ToggleTalents()
			end)
			o.Checkbox("training", "talentsPanel", L.CALC_OPTION, L.CALC_OPTION_DESC)
			o.Checkbox("training", "talentsMarks", L.MARKS_OPTION, L.MARKS_OPTION_DESC)
			o.Checkbox("training", "talentsGuard", L.GUARD_OPTION, L.GUARD_OPTION_DESC)

			o.Header(L.RANKS_KEPT_OPTION, { advanced = true })
			o.Button(L.RANKS_KEPT_OPTION, L.RANKS_FORGET, L.RANKS_FORGET_DESC, function() ns.ForgetKeptRanks() end)
		end,
	})
	SLASH_WANDERERTRAINING1 = "/wtraining"
	SLASH_WANDERERTRAINING2 = "/wtrain"
	SlashCmdList.WANDERERTRAINING = function(text)
		local typed = (text or ""):lower()
		if typed:find("talent", 1, true) and typed:find("dump", 1, true) then return ns.TalentsDump() end
		if typed:find("talent", 1, true) then return ns.ToggleTalents() end
		ns.Toggle()
	end
	if W.OnComparisonChanged then W.OnComparisonChanged(ns.Changed) end
	ns.InitTrainer()
	ns.InitRanks()
	ns.InitSpellTips()
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_MONEY", "UPDATE_FACTION", "SKILL_LINES_CHANGED",
		"SPELL_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED", "PET_BAR_UPDATE", "TRAINER_SHOW", "TRAINER_CLOSED", "TRAINER_UPDATE",
		"CHARACTER_POINTS_CHANGED", "TRAIT_CONFIG_UPDATED", "ADDON_LOADED", "INSPECT_READY", "PLAYER_REGEN_ENABLED",
		"PLAYER_REGEN_DISABLED", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED" }) do
		pcall(events.RegisterEvent, events, event)
	end
	events:SetScript("OnEvent", function(_, event, arg, ...)
		-- (an item's data comes for every item of the game: only the demon tomes matter here)
		if event == "GET_ITEM_INFO_RECEIVED" and not (ns.IsTome(arg) and (...) ~= false) then return end
		if event == "SPELL_DATA_LOAD_RESULT" and not ns.Asked(arg) then return end
		if event == "ADDON_LOADED" then
			if arg == "Blizzard_PlayerSpells" then
				Attach()
				ns.AttachTalents()
			end
			return
		end
		-- (the talents: a player of your class inspected, a fight begun or ended, the other specialization)
		if event == "INSPECT_READY" then
			for _, unit in ipairs({ "target", "mouseover", "focus" }) do
				if U.Clean(U.Safe(UnitGUID, unit)) == arg then ns.ReadInspected(unit) break end
			end
			return
		end
		if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then return ns.TalentPanelEvent(event) end
		if event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
			ns.TalentsChanged()
			ns.SpecChanged()
			return
		end
		-- (your gold changed: the sums drawn again against it, nothing read again)
		if event == "PLAYER_MONEY" then return redraw() end
		if event == "PLAYER_LOGIN" then
			ns.LoadCharacter()
			ns.SeedWays()
			if Book() then
				Attach()
				ns.AttachTalents()
			end
		elseif event == "PET_BAR_UPDATE" or event == "SPELLS_CHANGED" then
			ns.NoteTomes()
			if event == "SPELLS_CHANGED" then ns.TalentPanelEvent(event) end
		elseif event == "PLAYER_LEVEL_UP" then
			C_Timer.After(1, function()
				LevelUp(tonumber(arg))
				ns.TalentsAtLevel(tonumber(arg))
			end)
		elseif event == "CHARACTER_POINTS_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
			ns.TalentsChanged()
		end
		ns.Changed()
	end)
end

if W and W.WhenLoaded then W.WhenLoaded(ADDON, ns.Init) elseif W and W.Print then W.Print(L.NEEDS_WANDERER) end
