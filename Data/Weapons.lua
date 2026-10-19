local _, ns = ...

-- The weapon skills (from What's Training, MIT: see Data/WhatsTraining/LICENSE): in the order shown, the classes
-- that learn each on Forever, the level, the price (copper), the masters who teach it by side (npc ids); the
-- masters' names in each language. Made by gen_weapons.lua: do not edit by hand.
ns.WEAPONS = {
	{ skill = 196, level = 1, cost = 1000, classes = { "HUNTER", "PALADIN", "ROGUE", "SHAMAN", "WARRIOR" }, masters = { Alliance = { 11865 }, Horde = { 2704, 11868 } } },
	{ skill = 197, level = 1, cost = 1000, classes = { "HUNTER", "PALADIN", "SHAMAN", "WARRIOR" }, masters = { Alliance = { 11865 }, Horde = { 2704, 11868 } } },
	{ skill = 198, level = 1, cost = 1000, classes = { "DRUID", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARRIOR" }, masters = { Alliance = { 11865 }, Horde = { 11869 } } },
	{ skill = 199, level = 1, cost = 1000, classes = { "DRUID", "PALADIN", "SHAMAN", "WARRIOR" }, masters = { Alliance = { 11865 }, Horde = { 11869 } } },
	{ skill = 201, level = 1, cost = 1000, classes = { "HUNTER", "MAGE", "PALADIN", "ROGUE", "WARLOCK", "WARRIOR" }, masters = { Alliance = { 11867 }, Horde = { 11870 } } },
	{ skill = 202, level = 1, cost = 1000, classes = { "HUNTER", "PALADIN", "WARRIOR" }, masters = { Alliance = { 11867 }, Horde = { 11870 } } },
	{ skill = 1180, level = 1, cost = 1000, classes = { "DRUID", "HUNTER", "MAGE", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }, masters = { Alliance = { 11866, 11867, 13084 }, Horde = { 11868, 11870 } } },
	{ skill = 15590, level = 1, cost = 1000, classes = { "DRUID", "HUNTER", "ROGUE", "SHAMAN", "WARRIOR" }, masters = { Alliance = { 11865, 11866 }, Horde = { 11868 } } },
	{ skill = 227, level = 1, cost = 1000, classes = { "DRUID", "HUNTER", "MAGE", "PRIEST", "SHAMAN", "WARLOCK", "WARRIOR" }, masters = { Alliance = { 11866, 11867 }, Horde = { 2704, 11868, 11869 } } },
	{ skill = 200, level = 20, cost = 10000, classes = { "DRUID", "HUNTER", "PALADIN", "WARRIOR" }, masters = { Alliance = { 11867 }, Horde = { 11870 } } },
	{ skill = 264, level = 1, cost = 1000, classes = { "HUNTER", "ROGUE", "WARRIOR" }, masters = { Alliance = { 11866 }, Horde = { 2704, 11868 } } },
	{ skill = 266, level = 1, cost = 1000, classes = { "HUNTER", "ROGUE", "WARRIOR" }, masters = { Alliance = { 11865 }, Horde = { 11869 } } },
	{ skill = 5011, level = 1, cost = 1000, classes = { "HUNTER", "ROGUE", "WARRIOR" }, masters = { Alliance = { 11867, 13084 }, Horde = { 11870 } } },
	{ skill = 2567, level = 1, cost = 1000, classes = { "HUNTER", "ROGUE", "WARRIOR" }, masters = { Alliance = { 11866, 13084 }, Horde = { 2704, 11868 } } },
}

ns.MASTER_NAMES = {
	[2704] = { enUS = "Hanashi", ruRU = "Ханаши", koKR = "하나시", zhCN = "哈纳什", zhTW = "哈納什" },
	[11865] = { enUS = "Buliwyf Stonehand", esES = "Buliwyf Petramano", ptBR = "Bulif Manopedra", ruRU = "Бульвайф Крепкорук", koKR = "불리위프 스톤헤드", zhCN = "布里维夫·石手", zhTW = "布里維夫·石拳" },
	[11866] = { enUS = "Ilyenia Moonfire", esES = "Ilyenia Fuegolunar", ptBR = "Ilyenia Flameluna", ruRU = "Илиения Лунное Пламя", koKR = "일예니아 문파이어", zhCN = "伊琳尼雅·月火", zhTW = "伊琳尼雅·月火" },
	[11867] = { enUS = "Woo Ping", ruRU = "Ву Пинг", koKR = "우 핑", zhCN = "吴平", zhTW = "吳平" },
	[11868] = { enUS = "Sayoc", ruRU = "Сайок", koKR = "사요크", zhCN = "塞尤克", zhTW = "塞尤克" },
	[11869] = { enUS = "Ansekhwa", ruRU = "Ансеква", koKR = "안세크화", zhCN = "安塞瓦", zhTW = "安塞瓦" },
	[11870] = { enUS = "Archibald", ptBR = "Arquibaldo", ruRU = "Арчибальд", koKR = "아키발드", zhCN = "阿基巴德", zhTW = "阿基巴德" },
	[13084] = { enUS = "Bixi Wobblebonk", esES = "Bixi Tambaleapié", ptBR = "Bixi Bateagita", ruRU = "Бикси Пошатушка", koKR = "빅시 와블봉크", zhCN = "比克斯", zhTW = "比克斯" },
}
