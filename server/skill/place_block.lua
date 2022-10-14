
local PlaceBlock = Skill.GetType("PlaceBlock")
local SkillBase = Skill.GetType("Base")

function PlaceBlock:canCast(packet, from)
	if from and from.isPlayer and from:isWatch() then
		return false
	end
	local map = from.map
	local blockPos = packet.blockPos
	if not blockPos then
		return false
	end
	local sloter = from:getHandItem()
	if self.test then
		if not map.cfg.placeTestBlock then
			return false
		end
	else
		if not sloter or sloter:null() or not sloter:block_id() then
			return false
		end
	end
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
	local region, oo = map:getRegionValue(pos, "blockOperationOwnerOnly")
	if oo and not region:isOwner(from) then
		from:sendTip(3, "block_operation_owner_only", 40)
		return false
	elseif not oo and map.cfg.forbidPlace then
		return false
	end
	local list = map:getTouchEntities(pos, Lib.v3add(pos, {x = 1, y = 1, z = 1}))
	if #list > 0 then
		return false
	end

	if not sloter then return true end
	local block_cfg = Block.GetIdCfg(sloter:block_id())
	if not CombinationBlock:canPlace(block_cfg, pos, map) then
		return false
	end
	if block_cfg.canPlaceFace and packet.sideNormal then
		local face = Block.getBlockFace(packet.sideNormal)
		local find = false
		for _, v in ipairs(block_cfg.canPlaceFace) do
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
	end

	Block.onPlaceBlock(block_cfg, packet, from)

	SkillBase.cast(self, packet, from)
end
