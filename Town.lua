local _, ns = ...
local L = ns.L

-- Wanderer's town card (API 13): what your trainer teaches now and its cost, in a town where a trainer of your
-- class stands; a click shows the way to them.

local W = Wanderer
local U = W and W.Util

-- (Init only, once Wanderer's check has passed)
function ns.InitTown()
	if not (W.TownLine and U) then return end
	W.TownLine(function()
		if not ns.class then return nil end
		local trainer = ns.Build().sums.trainer
		if trainer.count <= 0 then return nil end
		-- (only where a trainer of your class stands: never the way to a far capital from a village inn)
		if not ns.ClassTrainerHere() then return nil end
		return { text = L.TOWN_LINE:format(trainer.count, U.Coins(trainer.price)), hint = L.TOWN_LINE_HINT,
			onClick = function() ns.PinClassTrainer() end }
	end, "trainer")
end
