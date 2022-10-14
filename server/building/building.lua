--[[
用于批量建筑/生产方块，目前只在服务端有效
支持热更
]]
local setting = require "common.setting"

-- pos：外部认为的建筑起始点/原点
-- config.offset：对pos进行偏移，一般用默认值。可用于热更对下次建筑原点进行偏移
-- rotateDeg：对偏移后的pos旋转，如果方块侧面并不是四面相同的，则要把config.blocks中的blockId配置为数组
function Building.DoBuild(key, map, pos, rotateDeg)
	local config = setting:fetch("building", key)
	if not config or not pos then 
		return
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


	local startPos = {math.floor(pos.x + offset[1]), math.floor(pos.y + offset[2]), math.floor(pos.z + offset[3])}
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
		if id then
			map:setBlockConfigId(blockPos, id)
		end
		::continue::
	end
end
