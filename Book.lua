local ADDON, ns = ...
local L = ns.L

-- Where the page is shown: a tab of the game's spellbook (beside its own, as What's Training does), opened by
-- Wanderer's menu, a key or /wtraining; or, when the spellbook cannot be opened (in a fight), a window of its
-- own. The launcher's word pulses while something that counts can be learned now; a short notice at a new
-- level (an option, off).

local W = Wanderer
local U = W and W.Util
local Skin = W and W.Skin

local ICON = "Interface\\Icons\\INV_Misc_Book_07"
local HEAD = 58 -- the page's heading in the spellbook

local overlay, launcher, window
local trainerOpen = false
local attention = false

local function Settings() return W and W.Settings and W.Settings("training") or nil end

-- Drawn again a moment after a change (many come at once); the launcher's word kept in step.
local function Refresh()
	if not ns.class then return end
	attention = ns.Build().sums.now.count > 0
	ns.Draw()
end
local refresh = U and U.Debounce and U.Debounce(0.2, Refresh) or Refresh
function ns.Changed() refresh() end

function ns.Attention() return attention end
function ns.AtClassTrainer() return trainerOpen and #ns.TrainerServices() > 0 end

-- The window of its own -------------------------------------------------------------------------------------------

local function Window()
	if window then return window end
	window = Skin.CreateWindow("WandererTrainingWindow", "MEDIUM")
	Skin.Dress(window, { "CENTER", UIParent, "CENTER", 0, 20 }, "trainingPos")
	window:SetSize(720, 680)
	local _, _, margin = Skin.Header(window, "Wanderer", L.HEADING)
	window.margin = margin
	window:HookScript("OnShow", function(self)
		self:SetScale(Skin.Scale())
		ns.PlacePage(self, margin + 44, margin)
	end)
	Skin.Get(window):Layout()
	return window
end

-- The spellbook's tab -----------------------------------------------------------------------------------------------

local function Book() return PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame end

local function ShowOverlay(on)
	if not overlay then return end
	overlay:SetShown(on)
	if launcher then launcher.active:SetShown(on) launcher.normal:SetShown(not on) end
	if on then
		if window then window:Hide() end
		ns.PlacePage(overlay.content, 0, 0)
	end
end

-- The tab, beside the book's own (and What's Training's when it is there).
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
	if overlay or not book then return end
	-- The page over the book, with its heading.
	overlay = CreateFrame("Frame", "WandererTrainingBook", PlayerSpellsFrame)
	overlay:SetAllPoints(book)
	overlay:SetFrameLevel(book:GetFrameLevel() + 20)
	overlay:EnableMouse(true)
	overlay:Hide()
	local ground = overlay:CreateTexture(nil, "BACKGROUND")
	ground:SetAllPoints()
	ground:SetColorTexture(0.06, 0.05, 0.04, 0.97)
	local kicker = Skin.CreateKicker(overlay, "Wanderer")
	overlay.content = CreateFrame("Frame", nil, overlay)
	overlay.content:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, -HEAD)
	overlay.content:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 0, 14)
	local title = Skin.CreateText(overlay, "GameTooltipHeaderText", 1, 0.82, 0)
	title:SetText(L.HEADING)
	-- (the heading over the page's left edge, the page centered)
	kicker:SetPoint("BOTTOMLEFT", overlay.content, "TOP", -330, 26)
	title:SetPoint("TOPLEFT", kicker, "BOTTOMLEFT", 0, -3)
	-- The tab.
	launcher = CreateFrame("Button", "WandererTrainingLauncher", PlayerSpellsFrame)
	launcher:SetSize(44, 32)
	launcher:SetFrameLevel(book:GetFrameLevel() + 25)
	launcher.icon = launcher:CreateTexture(nil, "ARTWORK")
	launcher.icon:SetSize(34, 33)
	launcher.icon:SetPoint("BOTTOM", -1, 0)
	launcher.icon:SetTexture(ICON)
	launcher.normal = Art(launcher, "spellbook-Tab-Frame-C60")
	launcher.active = Art(launcher, "spellbook-Tab-Frame-Glow-C60")
	launcher.active:Hide()
	launcher:SetScript("OnClick", function()
		if U.PlaySound then U.PlaySound("IG_SPELLBOOK_OPEN") end
		ShowOverlay(not overlay:IsShown())
	end)
	Skin.Tooltip(launcher, L.TAB_TOOLTIP)
	-- The book's own tabs take the page back; the book closed, the page goes with it.
	local hooked = {}
	local function HookTabs()
		local tabs = book.CategoryTabSystem
		for _, child in ipairs(tabs and { tabs:GetChildren() } or {}) do
			if not hooked[child] and child.HookScript then
				hooked[child] = true
				child:HookScript("OnClick", function() ShowOverlay(false) end)
			end
		end
		PlaceLauncher()
	end
	book:HookScript("OnShow", HookTabs)
	book:HookScript("OnHide", function() ShowOverlay(false) end)
	HookTabs()
end

-- Opening ---------------------------------------------------------------------------------------------------------

local function OpenBook()
	if InCombatLockdown and InCombatLockdown() then return false end
	if not Book() and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_PlayerSpells") end
	if not Book() then return false end
	Attach()
	if not PlayerSpellsFrame:IsShown() then
		if PlayerSpellsUtil and PlayerSpellsUtil.OpenToSpellBookTab then
			pcall(PlayerSpellsUtil.OpenToSpellBookTab)
		else
			pcall(ShowUIPanel, PlayerSpellsFrame)
		end
	end
	if not PlayerSpellsFrame:IsShown() then return false end
	ShowOverlay(true)
	return true
end

function ns.Open()
	if not ns.class then return end
	if not OpenBook() then Window():Show() end
end

function ns.Toggle()
	if overlay and overlay:IsVisible() then
		pcall(HideUIPanel, PlayerSpellsFrame)
		return
	end
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
	if not (settings and settings.remind and W.Toast) then return end
	local sums = ns.Build(level).sums
	if sums.now.count > 0 then W.Toast(L.TITLE, L.REMIND_TEXT:format(sums.now.count, ns.MoneyText(sums.now.price)), { duration = 6 }) end
end

function ns.Init()
	if not (W and W.RegisterExtension) then return end
	if (W.API or 1) < 6 then return W.Print(L.NEEDS_WANDERER) end
	W.RegisterExtension({
		key = "training",
		addon = ADDON,
		title = L.ADDON,
		news = L.NEWS_LINES,
		defaults = { remind = false },
		launcher = { label = L.TITLE, open = function() ns.Toggle() end, attention = function() return ns.Attention() end },
		options = function(o)
			o.Header(L.ADDON)
			o.Button(L.TITLE, L.OPEN, L.OPEN_DESC, function()
				o.CloseSettings()
				ns.Open()
			end)
			o.Checkbox("training", "remind", L.REMIND, L.REMIND_DESC)
		end,
	})
	SLASH_WANDERERTRAINING1 = "/wtraining"
	SLASH_WANDERERTRAINING2 = "/wtrain"
	SlashCmdList.WANDERERTRAINING = function() ns.Toggle() end
	if W.OnComparisonChanged then W.OnComparisonChanged(ns.Changed) end
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_MONEY", "UPDATE_FACTION", "SKILL_LINES_CHANGED",
		"SPELL_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED", "PET_BAR_UPDATE", "TRAINER_SHOW", "TRAINER_CLOSED", "TRAINER_UPDATE",
		"CHARACTER_POINTS_CHANGED", "ADDON_LOADED" }) do
		pcall(events.RegisterEvent, events, event)
	end
	events:SetScript("OnEvent", function(_, event, arg)
		if event == "ADDON_LOADED" then
			if arg == "Blizzard_PlayerSpells" then Attach() end
			return
		end
		if event == "PLAYER_LOGIN" then
			ns.LoadCharacter()
			ns.SeedWays()
			if Book() then Attach() end
		elseif event == "TRAINER_SHOW" then
			trainerOpen = true
		elseif event == "TRAINER_CLOSED" then
			trainerOpen = false
		elseif event == "PET_BAR_UPDATE" or event == "SPELLS_CHANGED" then
			ns.NoteTomes()
		elseif event == "PLAYER_LEVEL_UP" then
			C_Timer.After(1, function() LevelUp(tonumber(arg)) end)
		end
		ns.Changed()
	end)
end

if W and W.WhenLoaded then W.WhenLoaded(ADDON, ns.Init) elseif W and W.Print then W.Print(L.NEEDS_WANDERER) end
