
local SkillBase = Skill.GetType("Base")
local PlaceBlock = Skill.GetType("PlaceBlock")

PlaceBlock.isClick = true

function PlaceBlock:cast(packet, from)
	local sloterBlockCfg = nil
	if packet.blockId then
		sloterBlockCfg = Block.GetIdCfg(packet.blockId)
	end
	if sloterBlockCfg and sloterBlockCfg.placeBlockSound then
		from:playSound(sloterBlockCfg.placeBlockSound, sloterBlockCfg)
	end
	SkillBase.cast(self, packet, from)
end

function PlaceBlock.recalcSideNormal(yaw, pos)
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
	if from and from.isPlayer and from:isWatch() then
		return false
	end
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
	packet.blockId = sloter:block_id()
	if map:getBlockConfigId(blockPos) == 0 then
		return false
	end
	local clickDis = from:cfg().clickBlockDistance
	if clickDis and Lib.getPosDistance(from:getPosition(), blockPos) > clickDis then
		return false
	end
	local pos = Lib.v3add(blockPos, packet.sideNormal)
	if map:getBlockConfigId(pos) ~= 0 and not map:getBlock(pos).canReplace then
		return false
	end
	local list = map:getTouchEntities(pos, Lib.v3add(pos, {x = 1, y = 1, z = 1}))
	if not packet.isRecalced and #list == 1 and list[1].objID == from.objID then
		packet.sideNormal = PlaceBlock.recalcSideNormal(from:getRotationYaw(), blockPos)
		packet.isRecalced = true
		return self:canCast(packet, from)
	elseif #list ~= 0 then
		return false
	end
	local cfg = Block.GetIdCfg(sloter:block_id())
	if not cfg then
		return false
	end
	if cfg.canPlaceFace and packet.sideNormal then
		local face = Block.getBlockFace(packet.sideNormal)
		local find = false
		for _, v in ipairs(cfg.canPlaceFace) do
			if v == face then
				find = true
				break
			end
		end
		if not find then
			return false
		end
	end
	return true
end

function PlaceBlock:singleCast(packet, from)
	local id
	if self.test then
		id = Block.GetNameCfgId(from.map.cfg.placeTestBlock)
	else
		local sloter = from:getHandItem()
		id = sloter:block_id()
	end
	local pos = Lib.v3add(packet.blockPos, packet.sideNormal)
	from.map:setBlockConfigId(pos, id)
	SkillBase.singleCast(self, packet, from)
end
