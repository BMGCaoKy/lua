local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

function Actions.FindFrontBlock(data, params, context)
	local entity = params.entity
	local block = params.block
	if ActionsLib.isInvalidEntity(entity) or ActionsLib.isEmptyString(block, "Block") then
		return
	end
	local map = entity.map
	local name = block
	local poss = {}
	for i = 1, params.distance or 2 do
		poss[i] = entity:getFrontPos(i):blockPos()
	end
	for i = 1, params.deep or 3 do
		for _, pos in ipairs(poss) do
			pos.y = pos.y - 1
			local block = map:getBlock(pos)
			if block.fullName==name then
				return pos
			end
			if block.focusable~=false then
				return nil
			end
		end
	end
	return nil
end

function Actions.DoDamgeToBlock(data, params, context)
    Block.doDamage(params.pos, params.damage, params.owner)
end

function Actions.CreateBlock(data, params, context)
	local block = params.block
	if ActionsLib.isEmptyString(block, "Block") then
		return
	end
	local map = World.CurWorld:getMap(params.map)
	if ActionsLib.isInvalidMap(map) or ActionsLib.isNil(params.pos, "BlockPosition") then
		return
	end
	map:createBlock(params.pos, block)
end

function Actions.CreateRandomBlocksInRegion(data, params, context)
	local block = params.block
	local region = params.region
	if ActionsLib.isEmptyString(block, "Block") or ActionsLib.isInvalidRegion(region) then
		return
	end
	local map = World.CurWorld:getMap(params.map)
	if ActionsLib.isInvalidMap(map) then
		return
	end
	local minPos, maxPos = region.min, region.max
	local maxPosX, maxPosY, maxPosZ = maxPos.x, maxPos.y, maxPos.z
	local minPosX, minPosY, minPosZ = minPos.x, minPos.y, minPos.z
	local pos
	local createNum = params.creatnum
	if ActionsLib.isNil(createNum, "CreateNumber") then
		return
	end
	for i = 1,createNum do
        local num = 0
        pos = Lib.v3(math.random(minPosX, maxPosX), math.random(minPosY, maxPosY), math.random(minPosZ, maxPosZ))
        local isPos = map:getBlockConfigId(pos)
        while isPos ~= 0 do
              pos = Lib.v3(math.random(minPosX, maxPosX), math.random(minPosY, maxPosY), math.random(minPosZ, maxPosZ))
              num = num + 1
              if num > 3 then
                    break
              end
        end
        map:createBlock(pos, block)
	end
end

function Actions.CreateRandomBlocksInRegionNoRepeat(data, params, context) -- 按位置去重
	local block = params.block
	local region = params.region
	if ActionsLib.isEmptyString(block, "Block") or ActionsLib.isInvalidRegion(region) then
		return
	end
	local map = World.CurWorld:getMap(params.map)
	if ActionsLib.isInvalidMap(map) then
		return
	end
	local minPos, maxPos = region.min, region.max
	local maxPosX, maxPosY, maxPosZ = maxPos.x, maxPos.y, maxPos.z
	local minPosX, minPosY, minPosZ = minPos.x, minPos.y, minPos.z
	local maxCount = (maxPosX - minPosX + 1) * (maxPosY - minPosY + 1) * (maxPosZ - minPosZ + 1)
	local createNum = params.createNum
	if ActionsLib.isNil(createNum, "CreateNumber") then
		return
	end
	if maxCount <= createNum then
		map:batchCreateBlockAtRegion(minPos, maxPos, block)
		return
	end
	local pos
	local math_random = math.random
	local globalCalc = createNum/maxCount
	for _x = minPosX, maxPosX do
		for _y = minPosY, maxPosY do
			for _z = minPosZ, maxPosZ do
				local calc = createNum/maxCount
				if math_random() <= ((globalCalc > calc) and 0.5 or calc) then
					map:createBlock({x = _x, y = _y, z = _z}, block)
					createNum = createNum - 1
					if createNum <= 0 then
						return
					end
				end
				maxCount = maxCount - 1
			end
		end
	end
end

function Actions.FillBlocksInRegion(data,params,context)
	local block = params.block
	local region = params.region
	if ActionsLib.isEmptyString(block, "Block") or ActionsLib.isInvalidRegion(region) then
		return
	end
	local map = World.CurWorld:getMap(params.map)
	if ActionsLib.isInvalidMap(map) then
		return
	end
	map:fillBlocksInRegion(block, params.regionKey, region)
end

function Actions.ReplaceBlockInRegion(data,params,context)
	local region = params.region
	if ActionsLib.isInvalidRegion(region) then
		return
	end
	local map = World.CurWorld:getMap(params.map)
	if ActionsLib.isInvalidMap(map) then
		return
	end
	map:replaceBlockInRegion(params.region, params.replaceTb)
end

function Actions.ReplaceBlockInRegionSingle(data,params,context)
	local sourceBlock, destBlock = params.sourceBlock, params.destBlock
	if ActionsLib.isEmptyString(sourceBlock, "sourceBlock") or ActionsLib.isEmptyString(destBlock, "destBlock") then
		return
	end
	params.replaceTb = {[1] = { key = "fullName", value = sourceBlock, destBlock = destBlock}}
	Actions.ReplaceBlockInRegion(data,params,context)
end

function Actions.RemoveBlocksInRegion(data, params, context)
	local isAll = not params.blockArray
	local region = params.region
	if ActionsLib.isInvalidRegion(region) then
		return
	end
	local map = World.CurWorld:getMap(params.map)
	if ActionsLib.isInvalidMap(map) then
		return
	end
	map:removeBlocksInRegion(params.regionKey, region, isAll, params.blockArray)
end

function Actions.ClearBlocksInRegion(data, params, context)
	local region = params.region
	if ActionsLib.isInvalidRegion(region) then
		return
	end
	local map = World.CurWorld:getMap(params.map)
	if ActionsLib.isInvalidMap(map) then
		return
	end
	map:clearBlocksInRegion(params.blockArray, params.regionKey, region)
end

function Actions.GetBlockFullName(data, params, context)
	local map = World.CurWorld:getMap(params.map)
	local pos = params.pos
	if ActionsLib.isInvalidMap(map) or ActionsLib.isNil(pos, "BlockPosition") then
		return
	end
	local block = map:getBlock(pos)
	return block.fullName
end

function Actions.RemoveBlock(data, params, context)
	local blockPos = params.block
	local map = World.CurWorld:getMap(params.map)
	if ActionsLib.isInvalidMap(map) or ActionsLib.isNil(blockPos, "BlockPosition") then
		return
	end
	map:getMap(map):removeBlock(blockPos)
end

function Actions.IsBlockTouchTop(data, params, context)
	local entity = params.entity
	if not entity then
		return false
	end
	local map = entity.map
    local block = World.CurWorld:getMap(map):getBlock(params.pos)
	if not block then
		return false
	end
	local BoundingBox = entity:getBoundingBox()
	local box = { 0, 0, 0 }
	if BoundingBox then
		box = {
			math.abs(BoundingBox[2].x - BoundingBox[3].x),
			math.abs(BoundingBox[2].y - BoundingBox[3].y),
			math.abs(BoundingBox[2].z - BoundingBox[3].z)
		}
	end
	local pos1 = params.pos
	local pos2 = entity:getPosition()
	if not pos1 and not pos2 then
		return false
	end
	return pos1.y - pos2.y >= box[2]
end

function Actions.GetPosBlockId(data, params, context)
    local pos = params.pos
    local newPos = {}
    newPos.x = math.floor(pos.x)
    newPos.y = math.floor(pos.y)
    newPos.z = math.floor(pos.z)
    return World.CurWorld:getMap(params.map):getBlockConfigId(newPos)
end

function Actions.DoBuildByFullName(data, params, context)
	Building.DoBuild(params.fullName, World.CurWorld:getMap(params.map), params.pos, params.rotate)
end