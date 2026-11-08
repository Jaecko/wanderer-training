local _, ns = ...

-- The way to a trainer: the game's own pin on its map. The places are positions in the world (Data/Places.lua):
-- the game turns them into its maps' coordinates, Forever's changed maps (Stormwind's harbor) included.

local W = Wanderer
local U = W and W.Util

local SIDES = { Alliance = "A", Horde = "H" }

-- The name of the place there (a city, a zone), for the words of a tooltip.
function ns.PlaceName(continent, x, y)
	local map = U.WorldToMap(continent, x, y)
	return map and U.MapName(map) or nil
end

local function Pin(place)
	local map, x, y = U.WorldToMap(place[3], place[4], place[5])
	return map and U.Go(map, x, y) or false
end

-- Where you stand in the world: continent, x, y (nil inside an instance).
local function Here()
	local x, y, continent = U.Here()
	if not x or (continent ~= 0 and continent ~= 1) then return nil end
	return continent, x, y
end

-- The closest of these places of your side (the same continent first); nil when none.
local function Closest(places)
	local side = SIDES[ns.side]
	local continent, x, y = Here()
	local best, bestDistance
	for _, place in ipairs(places or {}) do
		if place[2] == side or place[2] == "B" then
			local distance = math.huge
			if continent and place[3] == continent then distance = (place[4] - x) ^ 2 + (place[5] - y) ^ 2
			elseif continent then distance = 1e12 end
			if not bestDistance or distance < bestDistance then best, bestDistance = place, distance end
		end
	end
	return best
end

-- A trainer of your class in the place you stand (the town card speaks of it only then): on your continent,
-- and within NEAR_TRAINER yards (an inn with no trainer: none, never the capital's far away).
local NEAR_TRAINER = 600
function ns.ClassTrainerHere()
	local place = Closest(ns.CLASS_TRAINERS[ns.class])
	local continent, x, y = Here()
	if not (place and continent and place[3] == continent) then return nil end
	if (place[4] - x) ^ 2 + (place[5] - y) ^ 2 > NEAR_TRAINER * NEAR_TRAINER then return nil end
	return place
end

-- The closest trainer of your class, pinned: true when the game took the pin.
-- (none known for your side, Forever's Horde paladins or Alliance shamans: said so, rather than a failed pin)
function ns.PinClassTrainer()
	local place = Closest(ns.CLASS_TRAINERS[ns.class])
	if not place then
		W.Print(ns.L.PIN_NONE)
		return true
	end
	return Pin(place)
end

-- A weapon master (the closest of those teaching it), pinned.
function ns.PinMaster(npcs)
	local places = {}
	for _, npc in ipairs(npcs or {}) do
		local where = ns.MASTER_PLACES[npc]
		if where then places[#places + 1] = { npc, where[1], where[2], where[3], where[4] } end
	end
	local place = Closest(places)
	return place and Pin(place) or false
end

-- A master's name (in your language when known) and where he stands.
function ns.MasterText(npc)
	local names = ns.MASTER_NAMES[npc] or {}
	local locale = GetLocale and GetLocale() or "enUS"
	local name = names[locale] or (locale == "esMX" and names.esES) or names.enUS or ("#" .. npc)
	local where = ns.MASTER_PLACES[npc]
	local place = where and ns.PlaceName(where[2], where[3], where[4])
	return place and (name .. " (" .. place .. ")") or name
end
