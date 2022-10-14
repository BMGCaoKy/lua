local SkillBase = Skill.GetType("Base")
local PlaceBlock = Skill.GetType("PlaceBlock")
local setting = require "common.setting"
local Build = require "editor_buildSetting"

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

local pointList = {}
do
	local addFunc = function(tb)
		if not tb then
			return
		end
		if #tb > 0 then
			for _, p in pairs(tb) do
				table.insert(pointList, p)
			end
		elseif tb.x then
			table.insert(pointList, tb)
		end
	end
	local teams = World.cfg.team
	for _, team in pairs(teams or {}) do
		local rebirthPos = team.rebirthPos
		local startPos = team.startPos
		addFunc(rebirthPos)
		addFunc(startPos)
	end
	addFunc(World.cfg.initPos)
	addFunc(World.cfg.startPos)
	addFunc(World.cfg.revivePos)
end

local function canBulidTower(from, key, pos)
    local map = from.map
    local buildingConfigs = setting:fetch("building")
    local config = buildingConfigs[key]
    local rotateDeg = from:getRotationYaw()
    local mapName = map and map.name
	if not config or not pos then 
		return false
    end

	local intPos = {math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)}

	local deg = math.floor((rotateDeg or 0 + 45) % 360 / 90) * 90
	local degIdx = deg / 90 + 1

	local offset = config.offset or {0,0,0}
	local function rotate(blockPos, deg)
		local oldX = blockPos.x
		local oldZ = blockPos.z
		if deg == 90 then 
			blockPos.x = -oldZ
			blockPos.z = oldX
		elseif deg == 180 then 
			blockPos.x = -oldX
			blockPos.z = -oldZ
		elseif deg == 270 then
			blockPos.x = oldZ
			blockPos.z = -oldX 
		end
    end 
    
    local blockPos = {}
	local checkAir = config.checkAir
	for _, info in pairs(config.blocks or {}) do
		blockPos.x = info.pos[1] + offset[1]
		blockPos.y = info.pos[2] + offset[2]
		blockPos.z = info.pos[3] + offset[3]
		local _ = deg ~= 0 and rotate(blockPos, deg)
		blockPos.x = blockPos.x + intPos[1]
		blockPos.y = blockPos.y + intPos[2]
		blockPos.z = blockPos.z + intPos[3]
		if checkAir and map:getBlockConfigId(blockPos) ~= 0 then 
			goto continue
		end

		local id 
		if type(info.blockName) == "string" then 
			id = info.blockName and Block.GetNameCfgId(info.blockName) or nil
		elseif type(info.blockName) == "table" then 
			id = info.blockName[degIdx] and Block.GetNameCfgId(info.blockName[degIdx]) or nil
		elseif type(info.blockId) == "number" then
			id = info.blockId
		elseif type(info.blockId) == "table" then
			id = info.blockId[degIdx]
        end
        
        if not id then
            goto continue
        end

        local haveBlock = false
        for _, position in pairs(pointList) do
            if position.map == mapName then
                local pos = {}
                for x= math.floor(position.x - 0.4), math.floor(position.x + 0.4) do
                    for z = math.floor(position.z - 0.4), math.floor(position.z + 0.4) do
                        for i = -1, 1 do
                            pos.x = x
                            pos.z = z
                            pos.y = math.floor(position.y) + i
                            if pos.x == blockPos.x and pos.y == blockPos.y and pos.z == blockPos.z then
                                haveBlock = true
                            end
                        end
                    end
                end
            end
        end

        if haveBlock then
            return false
        end
		::continue::
    end
    return true
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
	packet.blockId = sloter:block_id()
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
	if placeBlockCfg.canBeReplace and not isPlaceUp then --如果是放置可以被替代的方块，必须从上面放
		return false
	end
	if blockCfg.canBeReplace and map:getBlockConfigId(blockPos) == sloter:block_id() then --同一种不发生替换
		return false
	end

	if not (isPlaceUp and blockCfg.canBeReplace) and not blockCfg.dontBeCheckFullCub and placeBlockCfg.checkPlaceFullCube then
		if not blockCfg.texture or #blockCfg.texture ~= 6 or blockCfg.isOpaqueFullCube == false then
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
	--
	local haveBlock = false
	local targetPos = Lib.v3add(blockPos, packet.sideNormal)
	for _, position in pairs(pointList) do
		if position.map == map.name then
			local pos = {}
			for x= math.floor(position.x - 0.4), math.floor(position.x + 0.4) do
				for z = math.floor(position.z - 0.4), math.floor(position.z + 0.4) do
					for i = -1, 1 do
						pos.x = x
						pos.z = z
						pos.y = math.floor(position.y) + i
						if pos.x == targetPos.x and pos.y == targetPos.y and pos.z == targetPos.z then
							haveBlock = true
						end
					end
				end
			end
		end
	end
	if haveBlock then
		Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("cant_place_block"), 20)
		return false
	end

	local fullName = setting:id2name("block", sloter:block_id())
	local teamId = from:getValue("teamId")
	if teamId and (fullName == "myplugin/defenceTower" or fullName == "myplugin/defenceWall") then
		local key = fullName == "myplugin/defenceTower" and Build.GetDefenceTowerFullName(teamId) or Build.GetDefenceWallFullName(teamId)
		if not canBulidTower(from, key, targetPos) then
			Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("cant_place_block"), 20)
			return false
		end
	end
	--
	return true
end

local canPutInWater = World.cfg.canBlockPutInWater
function PlaceBlock:singleCast(packet, from)
	local id
	if self.test then
		id = Block.GetNameCfgId(from.map.cfg.placeTestBlock)
	else
		local sloter = from:getHandItem()
		id = sloter:block_id()
	end
	local block_cfg = Block.GetIdCfg(id)
	local changers = block_cfg.changers
	if type(changers) == "table" then
		local sideNormal = packet.sideNormal
		local snKey = string.format("%d:%d:%d", sideNormal.x, sideNormal.y, sideNormal.z)
		if not changers[snKey] then
			return false
		end
		id = Block.GetNameCfgId(changers[snKey])
	end
	local pos
	if canPutInWater and WaterMgr.IsWater(from.map:getBlockConfigId(packet.blockPos)) then 
		pos = packet.blockPos
	else
		pos = Lib.v3add(packet.blockPos, packet.sideNormal)
	end
	from.map:setBlockConfigId(pos, id)
	SkillBase.singleCast(self, packet, from)
end
