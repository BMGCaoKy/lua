local misc = require "misc"
local DBHandler = require "dbhandler" ---@type DBHandler

local HomeBase = T(Game, "HomeBase")
HomeBase.__index = HomeBase

function Game.AllocateHome(player, map)
	if player.home then
		return player.home
	end
	map = assert(map or WorldServer.defaultMap)
	local region = nil
	for _, rg in pairs(map.keyRegions) do
		if not rg.home and rg.cfg and rg.cfg.isHome then
			region = rg
			break
		end
	end
	if not region then
		return nil
	end
	local home = {
		region = region,
		owner = player,
		vars = Vars.MakeVars("home", region.cfg),
		removed = false,
	}
	region.home = setmetatable(home, HomeBase)
	player.home = home
	-- set owner in HomeBase:loadData
	DBHandler:getData(player, Define.DBSubKey.HomeData, function(subKey, data)
		if player:isValid() then
			player:onGetHomeDBData(subKey, data)
		end
	end)
	return home
end

function HomeBase:loadData(text)
	local region = self.region
	if text and #text>0 then
		local data = misc.data_decode(misc.base64_decode(text))
		region.map:loadBlockData(region.min, region.max, data.data, data.len)
		Vars.LoadVars(self.vars, data.vars or {})
	end
	region:setOwner(self.owner)
	Trigger.CheckTriggers(self.owner:cfg(), "PLAYER_HOME_LOADED", { obj1 = self.owner, home = self, region = region })
end

function HomeBase:saveData()
	local region = self.region
	local data = {vars = Vars.SaveVars(self.vars)}
	data.data, data.len = region.map:saveBlockData(region.min, region.max)
	local text = misc.base64_encode(misc.data_encode(data))
	DBHandler:setData(self.owner.platformUserId, 2, text, true)
end

function HomeBase:free()
	local region = self.region
	region:removeOwner(self.owner)
	region.map:clearBlocks(region.min, region.max, false)
	self.owner.home = nil
	region.home = nil
	self.removed = true
end

