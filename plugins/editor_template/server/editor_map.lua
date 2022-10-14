
local Map = World.Map
local MapServer = T(World, "MapServer", Lib.derive(Map))

function MapServer:createBlock(pos, fullName)
	local cfg = Block.GetNameCfg(fullName)
	local id = cfg.id
    self:setBlockConfigId(pos, id)
	local data = self:getOrCreateBlockData(pos)
	data.isNotPartOfMap = true
	Trigger.CheckTriggers(cfg, "BLOCK_SPAWN", {pos = pos, map = self})
	if cfg.effect then
		local effectName = "plugin/" .. cfg.plugin .. "/block/" .. cfg._name .. "/" .. cfg.effect
		MapEffectMgr:addEffect(self, pos, effectName, -1)
	end
end

function MapServer:removeBlock(pos, from)
	local function checkBreakAttachBlockEvent(pos)
		local oldId = self:getBlockConfigId(pos)
		if oldId == 0 then
			return
		end
		local posx = pos.x
		local posy = pos.y
		local posz = pos.z

		local checkPosList = {
			["1:0:0"]  = {x = posx + 1, y = posy, z = posz},
			["-1:0:0"] = {x = posx - 1, y = posy, z = posz},
			["0:1:0"]  = {x = posx, y = posy + 1, z = posz},
			["0:-1:0"]  = {x = posx, y = posy - 1, z = posz},
			["0:0:1"]  = {x = posx, y = posy, z = posz + 1},
			["0:0:-1"]  = {x = posx, y = posy, z = posz - 1},
		}
		for key, mPos in pairs(checkPosList) do
			local blockCfg = self:getBlock(mPos)
			if blockCfg.attackSide == key then
				if from then
					Trigger.CheckTriggers(nil, "BLOCK_BREAK_DROP_ITEM", {obj1 = from, pos = mPos, dropItemList = blockCfg.dropItemList})
				end
				self:setBlockConfigId(mPos, 0)
			end
		end
	end
	checkBreakAttachBlockEvent(pos)
	local blockcfg = self:getBlock(pos)
	Trigger.CheckTriggers(blockcfg, "BLOCK_REMOVED",{pos = pos, map = self})
	self:setBlockData(pos, nil)
	return self:setBlockConfigId(pos, 0)
end