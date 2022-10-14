local SkillBase = Skill.GetType("Base")
local PlaceBlock = Skill.GetType("PlaceBlock")

local function recalcSideNormal(yaw, pos)
	local deg = math.deg(math.atan(1, 3))
	yaw = yaw % 360
	local x, y, z = 0, 0, 0
	if deg < yaw and yaw <= 180 - deg then
		x = -1
	elseif 180 + deg < yaw and yaw <= 360 - deg then
		x = 1
	end
	if 270 + deg < yaw or yaw <= 90 - deg then
		z = -1
	elseif 90 + deg < yaw and yaw <= 270 - deg then
		z = 1
	end
	return Lib.v3(x, y, z)
end

function PlaceBlock:canCast(packet, from)
	local map = from.map
	local blockPos = packet.blockPos
	if not blockPos then
		return false
	elseif self.test then
		return map.cfg.placeTestBlock ~= nil
	end
	local sloter = from:getHandItem()
	if not sloter or sloter:null() or not sloter:block_id() then
		return false
	end
	if map:getBlockConfigId(blockPos) == 0 then
		return false
	end
	local clickDis = from:cfg().clickBlockDistance
	if clickDis and Lib.getPosDistance(from:getPosition(), blockPos) > clickDis then
		return false
	end
	local changers = sloter:block_cfg().changers
	if type(changers) == "table" then
		local sideNormal = packet.sideNormal
		local snKey = string.format("%d:%d:%d", sideNormal.x, sideNormal.y, sideNormal.z)
		if not changers[snKey] then
			return false
		end
		local mountBlockCfg = Block.GetIdCfg(map:getBlockConfigId(blockPos))
		if mountBlockCfg.mountBlock == false then
			return false
		end
	end
	local pos = Lib.v3add(blockPos, packet.sideNormal)
	if map:getBlockConfigId(pos) ~= 0 then
		return false
	end
	local blockCfg = Block.GetIdCfg(map:getBlockConfigId(blockPos))
	local placeBlockCfg = Block.GetIdCfg(sloter:block_id())
	local isPlaceUp = packet.sideNormal.y == 1
	if placeBlockCfg.canBeReplace and not isPlaceUp then --如果是放置可以被替代的方块，则必须从上面放
		return false
	end
	if blockCfg.canBeReplace and map:getBlockConfigId(blockPos) == sloter:block_id() then --同一种不发生替换
		return false
	end
	if not (isPlaceUp and blockCfg.canBeReplace) and not blockCfg.dontBeCheckFullCub and placeBlockCfg.checkPlaceFullCube then
		if not blockCfg.texture or #blockCfg.texture ~= 6 then
			return false
		end
	end
	local list = map:getTouchEntities(pos, Lib.v3add(pos, {x = 1, y = 1, z = 1}))
	if not packet.isRecalced and #list == 1 and list[1].objID == from.objID then
		packet.sideNormal = recalcSideNormal(from:getRotationYaw())
		packet.isRecalced = true
		return self:canCast(packet, from)
	elseif #list ~= 0 then
		return false
	end
	local block_cfg = Block.GetIdCfg(sloter:block_id())
	if not CombinationBlock:canPlace(block_cfg, pos, map) then
		return false
	end
	return true
end

local canPutInWater = World.cfg.canBlockPutInWater
function PlaceBlock:cast(packet, from)
	local map = from.map
	local id
	if self.test then
		id = Block.GetNameCfgId(map.cfg.placeTestBlock)
	else
		local sloter = from:getHandItem()
		if not sloter then
			return
		end
		id = sloter:block_id()
		sloter:consume()
	end
	local block_cfg = Block.GetIdCfg(id)
	local changers = block_cfg.changers
	local mount = false
	if type(changers) == "table" then
		local sideNormal = packet.sideNormal
		local snKey = string.format("%d:%d:%d", sideNormal.x, sideNormal.y, sideNormal.z)
		if not changers[snKey] then
			return false
		end
		local placeInfo = changers[snKey]
		local blockName = placeInfo
		if type(placeInfo) == "table" then
			local yaw = from:getRotationYaw()
			local index = math.floor(((yaw + 360) % 360 + 45) / 90)
			index = index == 0 and 4 or index
			blockName = placeInfo[index]
			block_cfg = Block.GetNameCfg(blockName)
		end
		id = Block.GetNameCfgId(blockName)
		block_cfg = Block.GetIdCfg(id)
		mount = true
	end
	local blockCfg = Block.GetIdCfg(map:getBlockConfigId(packet.blockPos))
	local pos
	local isPlaceUp = packet.sideNormal.y == 1
	if blockCfg.canBeReplace and not isPlaceUp and block_cfg.base == "huoba" then --如果火把不是正着替换草地，那就火把正方旁边
		id = Block.GetNameCfgId("myplugin/huoba")
		block_cfg = Block.GetIdCfg(id)
	end
	if (blockCfg.canBeReplace and isPlaceUp) or ( canPutInWater and WaterMgr.IsWater(map:getBlockConfigId(packet.blockPos)) ) then 
		pos = packet.blockPos
	else
		pos = Lib.v3add(packet.blockPos, packet.sideNormal)
	end
	-- todo: check
	local oldId = map:getBlockConfigId(pos)
	map:createBlock(pos, Block.GetIdCfg(id).fullName)
	Trigger.CheckTriggers(Block.GetIdCfg(oldId), "BLOCK_REPLACED", {obj1=from, pos=pos, map = map, oldId = oldId, newId = id})
	if mount then
		local blockdata = map:getOrCreateBlockData(packet.blockPos)
		local pendant = blockdata.pendant or {}
		local key = string.format("%d:%d:%d", pos.x, pos.y, pos.z)
		pendant[key] = true
		blockdata.pendant = pendant
	end
	Trigger.CheckTriggers(Block.GetIdCfg(id), "BLOCK_PLACE", {obj1=from, pos=pos})
	SkillBase.cast(self, packet, from)
    CombinationBlock:placeBlock(block_cfg, pos, map)
end