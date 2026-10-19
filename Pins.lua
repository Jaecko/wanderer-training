local _, ns = ...

-- The way to a trainer: the game's own pin on its map. The places are positions in the world (Data/Places.lua):
-- the game turns them into its maps' coordinates, Forever's changed maps (Stormwind's harbor) included.

local W = Wanderer
local U = W and W.Util

local SIDES = { Alliance = "A", Horde = "H" }

-- A world position on the closest map the game has for it: map, x, y (0 to 1), or nil.
local function MapPoint(continent, x, y)
	if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
	local ok, map, position = pcall(C_Map.GetMapPosFromWorldPos, continent, CreateVector2D(x, y))
	if not (ok and map and position) then return nil end
	-- (the zone under it, for a closer map)
	local info = C_Map.GetMapInfoAtPosition and select(2, pcall(C_Map.GetMapInfoAtPosition, map, position.x, position.y))
	if type(info) == "table" and info.mapID and info.mapID ~= map then
		local okZone, zone, there = pcall(C_Map.GetMapPosFromWorldPos, continent, CreateVector2D(x, y), info.mapID)
		if okZone and zone and there then return zone, there.x, there.y end
	end
	return map, position.x, position.y
end

-- The name of the place there (a city, a zone), for the words of a tooltip.
function ns.PlaceName(continent, x, y)
	local map = MapPoint(continent, x, y)
	local info = map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
	return info and info.name or nil
end

local function Pin(place)
	local map, x, y = MapPoint(place[3], place[4], place[5])
	return map and U.Pin(map, x, y) or false
end

-- Where you stand in the world: continent, x, y (nil inside an instance).
local function Here()
	local x, y, _, continent = UnitPosition("player")
	if not (x and y) or (continent ~= 0 and continent ~= 1) then return nil end
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

-- The closest trainer of your class, pinned: true when the game took the pin.
function ns.PinClassTrainer()
	local place = Closest(ns.CLASS_TRAINERS[ns.class])
	return place and Pin(place) or false
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
	local name = names[GetLocale and GetLocale() or "enUS"] or names.enUS or ("#" .. npc)
	local where = ns.MASTER_PLACES[npc]
	local place = where and ns.PlaceName(where[2], where[3], where[4])
	return place and (name .. " (" .. place .. ")") or name
end
