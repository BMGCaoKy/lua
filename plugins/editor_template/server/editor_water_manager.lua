
local setting = require "common.setting"
local MapEffectMgr = require "server.world.map_effect_mgr"

local changedWater = L("changedWater", {})
local lastChangedWater = L("lastChangedWater", nil)
local tickTimer = L("tickTimer", nil) 
local waitToSmooth = L("waitToSmooth", {}) 
local waitToDry = L("waitToDry", {}) 
local FULL_WATER_ID = L("FULL_WATER_ID", {})
local waterSource = L("waterSource", {})
local AIR_BLOCK = "/air"
local heighDirToId = L("heighDirToId", {}) 
local idToHeighDir = L("idToHeighDir", {}) 
local noWaterArea = L("noWaterArea", {}) 
local waitToChangeBlocks = L("waitToChangeBlocks", {})
local touchWoods = L("touchWoods", {})
local onBurningWoods = L("onBurningWoods", {})

local WATER_DIR = {
	LD = 0,
	CD = 1,
	RD = 2,
	LM = 3,
	CM = 4,
	RM = 5,
	LT = 6,
	CT = 7,
	RT = 8,
	NY = 9, --垂直向负Y方向
	PY = 10, --垂直向正Y方向
}
local WATER_SPREAD_DIR = {
	[0] = {1,3},
		{1},
		{1,5},
		{3},
		{1,3,5,7},
		{5},
		{3,7},
		{7},
		{5,7},
		{1,3,5,7},
}
local WATER_DRY_DIR = {
	[0] = {0,1,3},
		{1},
		{1,2,5},
		{3},
		{0,1,2,3,5,6,7,8},
		{5},
		{3,6,7},
		{7},
		{5,7,8},
		{0,1,2,3,5,6,7,8},
}
--[[
4 = water
0~3, 5~8 = changedPos ↓↓↓
x^
	6 7 8
	3 4 5
	0 1 2 ->z
↑↑↑

water heigh: 7 ~ 0, 7 is lowest
]]
local MaxWaterHeigh = 8
local maxWaterDir = 10
local defaultWaterType = "water"
local obsidianId = Block.GetNameCfgId("myplugin/obsidian")

local function getHeighDirKey(heigh, dir)
	return 100 * heigh + dir
end

local function getBlockHardness(map, pos)
    local cfg = map:getBlock(pos)
    return cfg.breakTime or 20
end

local function getWaterType(id)
    assert(type(id)=="number")
    local cfg = Block.GetIdCfg(id)
    if cfg.waterCfg then
        return cfg.blockType or defaultWaterType
    end
end

local function getBlockType(id)
    assert(type(id)=="number")
    local cfg = Block.GetIdCfg(id)
    return cfg.blockType
end

local function isWood(id)
    assert(type(id)=="number")
    local cfg = Block.GetIdCfg(id)
    return cfg.blockType == "wood"
end

local function getTypeCfgs(id)
    local typ = getWaterType(id)
    if typ then
        return T(idToHeighDir, typ)
    end
end

local function getWaterCfg(id)
    local cfgs = getTypeCfgs(id) or {}
    return cfgs[id]
end

local function setWaterCfg(id, cfg)
    local cfgs = assert(getTypeCfgs(id), "error id")
    cfgs[id] = cfg
end

local function getTypeNoWaterArea(waterType)
    assert(waterType)
    return T(noWaterArea, waterType)
end

local function canRuinedByTypeWater(id, waterType)
    local fullName = Block.GetIdCfg(id).fullName
    if fullName == AIR_BLOCK then 
        return true
    end
    local waterRuinCfg = World.cfg.waterRuinsBlock or {}
    local typeRuin = waterRuinCfg[waterType]
    if not typeRuin then
        return false
    end
    return typeRuin[fullName]
end

local function getWaterHeighDir(id)
	local tb = getWaterCfg(id)
	if tb then 
		return tb.heigh, tb.dir
	end
	return -1, -1
end

local function saveWater(id, waterType, heigh, dir)
    local typeHeighDir = T(heighDirToId, waterType)
    typeHeighDir[getHeighDirKey(heigh, dir)] = id
    setWaterCfg(id, {heigh = heigh, dir = dir})
end

local function getWaterByHeighDir(heigh, dir, waterType)
    if waterType then
        local typeHeighDir = T(heighDirToId, waterType)
        return typeHeighDir[getHeighDirKey(heigh, dir)]
    end
end

local function getSpreadPos(pos, dir)
	if dir == WATER_DIR.LD then 
		return {x = pos.x - 1, y = pos.y, z = pos.z - 1}, 2
	elseif dir == WATER_DIR.CD then 
		return {x = pos.x - 1, y = pos.y, z = pos.z}, 1
	elseif dir == WATER_DIR.RD then 
		return {x = pos.x - 1, y = pos.y, z = pos.z + 1}, 2
	elseif dir == WATER_DIR.LM then 
		return {x = pos.x, y = pos.y, z = pos.z - 1}, 1
	elseif dir == WATER_DIR.CM then 
		return {x = pos.x, y = pos.y, z = pos.z}, 0
	elseif dir == WATER_DIR.RM then 
		return {x = pos.x, y = pos.y, z = pos.z + 1}, 1
	elseif dir == WATER_DIR.LT then 
		return {x = pos.x + 1, y = pos.y, z = pos.z - 1}, 2
	elseif dir == WATER_DIR.CT then 
		return {x = pos.x + 1, y = pos.y, z = pos.z}, 1
	elseif dir == WATER_DIR.RT then 
		return {x = pos.x + 1, y = pos.y, z = pos.z + 1}, 2
	elseif dir == WATER_DIR.NY then 
		return {x = pos.x, y = pos.y - 1, z = pos.z}
	elseif dir == WATER_DIR.PY then 
		return {x = pos.x, y = pos.y + 1, z = pos.z}
	else
		assert(false, "Invalid water dir will spread to")
	end
end

local function calSpreadDir(oldDir, spreadTo)
	if oldDir == 0 or oldDir == 2 or oldDir == 6 or oldDir == 8 then 
		return oldDir
	end
	return spreadTo
end

local function mapPosKey(map,pos)
	if type(map) == "table" then 
		return map.name .. "," .. math.floor(pos.x) .. "," .. math.floor(pos.y) .. "," .. math.floor(pos.z)
	else
		return map .. "," .. math.floor(pos.x) .. "," .. math.floor(pos.y) .. "," .. math.floor(pos.z)
	end
end

local function isInNoWaterArea(map, pos, waterType)
    if not waterType then
        return false
    end
    local typeNoWaterArea = getTypeNoWaterArea(waterType)
	for _, area in pairs(typeNoWaterArea) do
		if map == area.map and Lib.getPosDistance(pos, area.center) <= area.radius then 
			return true
		end
	end
end

local function addSmoothPos(map, pos, id)
    waitToSmooth[mapPosKey(map, pos)] = {map = map, pos = pos, id = id}
end

local function addTouchWoodPos(map, pos, id)
    local key = mapPosKey(map, pos)
    local breakTime = getBlockHardness(map, pos)
    local blocks = onBurningWoods[tostring(breakTime)] or {}
    if blocks[key] then--已在燃烧中
        return
    end
    touchWoods[key] = {map = map, pos = pos, id = id}
end

local function addChangeBlockPos(map, pos)
    waitToChangeBlocks[mapPosKey(map, pos)] = {map = map, pos = pos}
end

local function addEffectAtPos(map, pos)
    pos = Lib.v3add(pos, {x = 0.5, y = 0.5, z = 0.5})
    MapEffectMgr:addEffect(map, pos, "g2021_huoyan.effect", -1)
end

local function removeEffectAtPos(map, pos)
    pos = Lib.v3add(pos, {x = 0.5, y = 0.5, z = 0.5})
    MapEffectMgr:delEffect(map, pos, "g2021_huoyan.effect")
end

--检查周围有没有水
local function checkAroundHasWater(map, pos, waterType)
    local dirs = {WATER_DIR.CT, WATER_DIR.CD, WATER_DIR.LM, WATER_DIR.RM, WATER_DIR.PY}
    for _, dir in ipairs(dirs) do
        local newPos = getSpreadPos(pos, dir)
        local id = map:getBlockConfigId(newPos)
        if getWaterType(id) == waterType then
            return true, newPos
        end
    end
end

--查找周围最高水位的水
local function findAroundHighestWater(map, pos, waterType)
    local newPos = getSpreadPos(pos, WATER_DIR.PY)
    local id = map:getBlockConfigId(newPos)
    if (waterType and getWaterType(id) == waterType) or (not waterType and getWaterType(id)) then
        return newPos
    end
    local dirs = {WATER_DIR.CT, WATER_DIR.CD, WATER_DIR.LM, WATER_DIR.RM}
    local height, position = 0, nil
    for _, dir in ipairs(dirs) do
        local newPos = getSpreadPos(pos, dir)
        local id = map:getBlockConfigId(newPos)
        if (waterType and getWaterType(id) == waterType) or (not waterType and getWaterType(id)) then
            local h, d = getWaterHeighDir(id)
            if height < h then
                height = h
                position = newPos
            end
        end
    end
    return position
end

--灭火
local function extinguishing(map, pos)
    local breakTime = getBlockHardness(map, pos)
    local posKey = mapPosKey(map, pos)
    local temp = onBurningWoods[tostring(breakTime)]
    if temp then
        temp[posKey] = nil
    end
    if not next(temp) then
        onBurningWoods[tostring(breakTime)] = nil
    end
    removeEffectAtPos(map, pos)
end

--烧毁
local function burnDown(map, pos)
	extinguishing(map, pos)
    local cfg = map:getBlock(pos)
	if not CombinationBlock:breakBlock(cfg, pos, map) then
		map:setBlockConfigId(pos, 0)
	end
    local position = findAroundHighestWater(map, pos, "lava")
    if position then
        WaterMgr.AddChangedPos(map, position)
    end
end

--燃烧木头
local function fireWood()
    for key, block in pairs(touchWoods) do
        local breakTime = getBlockHardness(block.map, block.pos)
        local timeBlocks = T(onBurningWoods, tostring(breakTime))
        timeBlocks[key] = {map = block.map, pos = block.pos, id = block.id, startTime = World.Now()}
    end
    touchWoods = {}
    for timeStr, blocks in pairs(onBurningWoods) do
        local t = tonumber(timeStr)
        for key, block in pairs(blocks) do
            addEffectAtPos(block.map, block.pos)
        end
        World.Timer(t, function()
            local nowTime = World.Now()
            for key, block in pairs(onBurningWoods[timeStr] or {}) do
                if nowTime - block.startTime >= t then
                    burnDown(block.map, block.pos)
                end
            end
        end)
    end
end

--检查周围有没有木头
local function checkAroundWood(map, pos)
    local dirs = {WATER_DIR.CT, WATER_DIR.CD, WATER_DIR.LM, WATER_DIR.RM, WATER_DIR.PY, WATER_DIR.NY}
    for _, dir in ipairs(dirs) do
        local newPos = getSpreadPos(pos, dir)
        local id = map:getBlockConfigId(newPos)
        if isWood(id) and not checkAroundHasWater(map, newPos, "water") then
            addTouchWoodPos(map, newPos, id)
        end
    end
end

--检查周围有没有正在燃烧的木头
local function checkAroundBurningWood(map, pos)
    local dirs = {WATER_DIR.CT, WATER_DIR.CD, WATER_DIR.LM, WATER_DIR.RM, WATER_DIR.NY}
    for _, dir in ipairs(dirs) do
        local newPos = getSpreadPos(pos, dir)
        local key = mapPosKey(map,newPos)
        local temp = {}
        local breakTime = getBlockHardness(map, pos)
        local blocks = onBurningWoods[tostring(breakTime)] or {}
        if blocks[key] then
            temp[key] = newPos
        end
        for _, pos in pairs(temp) do
            extinguishing(map, pos)
        end
    end
end

local function newCreateWater(map, pos, id)
    map:setBlockConfigId(pos, id)
    local waterType = getWaterType(id)
    if waterType == "lava" then
        checkAroundWood(map, pos)
    elseif waterType == "water" then
        checkAroundBurningWood(map, pos)
    end
end

local function getSpreadDirs(map, pos, dir, heigh)
	if pos.y <= 0 then 
		return WATER_SPREAD_DIR[dir]
	end
	local checkRadius = 5
	if heigh < MaxWaterHeigh - 1 then 
		checkRadius = 5 - (MaxWaterHeigh - heigh)
	end
	if checkRadius <= 0 then 
		return WATER_SPREAD_DIR[dir]
	end

	for i = 1, checkRadius do 
		local dirs = {}
		for dz = -i, i do 
			local dx = i - math.abs(dz)
			local id = map:getBlockConfigId({x = pos.x + dx, y = pos.y - 1, z = pos.z + dz})
			if id == 0 or WaterMgr.IsWater(id) then 
				if dx > 0 then 
					dirs[WATER_DIR.CT] = true
				end
				if dz < 0 then 
					dirs[WATER_DIR.LM] = true
				elseif dz > 0 then 
					dirs[WATER_DIR.RM] = true
				end
			end

			dx = math.abs(dz) - i
			id = map:getBlockConfigId({x = pos.x + dx, y = pos.y - 1, z = pos.z + dz})
			if id == 0 or WaterMgr.IsWater(id) then 
				if dx < 0 then 
					dirs[WATER_DIR.CD] = true
				end
				if dz < 0 then 
					dirs[WATER_DIR.LM] = true
				elseif dz > 0 then 
					dirs[WATER_DIR.RM] = true
				end
			end
		end
		if next(dirs) then 
			local ret = {}
			for dir, _ in pairs(dirs) do
				ret[#ret + 1] = dir
			end
			return ret
		end
	end
	return WATER_SPREAD_DIR[dir]
end

local function spread(map, pos)
    local blockId = map:getBlockConfigId(pos)
    local waterType = getWaterType(blockId)
    if not waterType then
        return
    end
	local footPos = getSpreadPos(pos, WATER_DIR.NY)
	local footBlockId = map:getBlockConfigId(footPos)
    local footWaterType = getWaterType(footBlockId)
    if (waterType == "water" and getBlockType(footBlockId) == "lava") or (waterType == "lava" and getBlockType(footBlockId) == "water") then
        --相遇
        addChangeBlockPos(map, footPos)
        return
	elseif footWaterType == waterType or canRuinedByTypeWater(footBlockId, waterType) then --下方空则形成瀑布
		if footPos.y >= 0 then 
			addSmoothPos(map, footPos, assert(FULL_WATER_ID[waterType]))
			WaterMgr.AddChangedPos(map, footPos, footPos, true)
		end
		return
	end

	local heigh, dir = getWaterHeighDir(blockId)
    local dirs = getSpreadDirs(map, pos, dir, heigh)

	local function checkSpread(spreadTo)
		local newPos, heighDown = getSpreadPos(pos, spreadTo)
		if isInNoWaterArea(map, newPos, waterType) then 
			return
		end

		if heigh >= MaxWaterHeigh then 
			heigh = MaxWaterHeigh - 1
		end
		local newHeigh = heigh - heighDown
		if newHeigh >= 0 then 
			local newDir = calSpreadDir(dir, spreadTo)
			local oldBlockId = map:getBlockConfigId(newPos)
            local oldWaterType = getWaterType(oldBlockId)
			local oldBlockHeigh, oldDir = getWaterHeighDir(oldBlockId)
            if (waterType == "water" and getBlockType(oldBlockId) == "lava") or (waterType == "lava" and getBlockType(oldBlockId) == "water") then
                --相遇
                addChangeBlockPos(map, newPos)
                return true
            end
            if oldWaterType and oldBlockHeigh > newHeigh then --高位水不被低位水覆盖
                newHeigh = oldBlockHeigh
                newDir = oldDir
            end
			if canRuinedByTypeWater(oldBlockId, waterType) or (WaterMgr.IsWater(oldBlockId) and newHeigh >= 0 and heigh > newHeigh) then 
				local newId = getWaterByHeighDir(newHeigh, newDir, waterType)
				addSmoothPos(map, newPos, newId)
				return true
			end
		end
	end

	local spreadSuccDirs = {}
	for _, spreadTo in pairs(dirs) do 
		if checkSpread(spreadTo) then 
			spreadSuccDirs[spreadTo] = true
		end
	end
	if spreadSuccDirs[WATER_DIR.CD] then 
		if spreadSuccDirs[WATER_DIR.LM] then 
			checkSpread(WATER_DIR.LD)
		end
		if spreadSuccDirs[WATER_DIR.RM] then 
			checkSpread(WATER_DIR.RD)
		end
	end
	if spreadSuccDirs[WATER_DIR.CT] then 
		if spreadSuccDirs[WATER_DIR.LM] then 
			checkSpread(WATER_DIR.LT)
		end
		if spreadSuccDirs[WATER_DIR.RM] then 
			checkSpread(WATER_DIR.RT)
		end
	end
end

local function addDryPos(map, pos, id)
	if not waitToSmooth[mapPosKey(map, pos)] then 
		waitToDry[mapPosKey(map, pos)] = {
			map = map, pos = pos, id = id
		}
	end
end

local function dryUp(map, pos, drying)
	local blockId = map:getBlockConfigId(pos)
    local waterType = getWaterType(blockId)
	local heigh, dir = getWaterHeighDir(blockId)
	if heigh == 0 then 
		addDryPos(map, pos, 0)

		local footPos = getSpreadPos(pos, WATER_DIR.NY)
		local footBlockId = map:getBlockConfigId(footPos)
		if WaterMgr.IsWater(footBlockId) then 
			WaterMgr.AddChangedPos(map, footPos)
		end
	elseif heigh > 0 then 
		local nCenterBlock 
		if dir == WATER_DIR.NY then --瀑布
			nCenterBlock = getWaterByHeighDir(MaxWaterHeigh - 2, WATER_DIR.CM, waterType)
		elseif dir ~= WATER_DIR.CM then --水面先变平
			nCenterBlock = getWaterByHeighDir(heigh, WATER_DIR.CM, waterType)
		else --再下降水面高度
			nCenterBlock = getWaterByHeighDir(heigh - 1, WATER_DIR.CM, waterType)
		end
		if nCenterBlock then 
			addDryPos(map, pos, nCenterBlock)
			WaterMgr.AddChangedPos(map, pos, nil, true)
		end
	end

	for _, spreadTo in pairs(WATER_DRY_DIR[dir] or {0,1,2,3,5,6,7,8}) do 
		local toPos = getSpreadPos(pos, spreadTo)
		local blockId = map:getBlockConfigId(toPos)
		local tHeigh, tDir = getWaterHeighDir(blockId)
		if WaterMgr.IsWater(blockId) then 
			if tHeigh < heigh or heigh < 0 then 
				WaterMgr.AddChangedPos(map, toPos, nil, true)
			else
				WaterMgr.AddChangedPos(map, toPos)
			end
		end
	end
end

local function aroundHasHigherWater(map, pos)
    local blockId = map:getBlockConfigId(pos)
    local waterType = getWaterType(blockId)
    local heigh = getWaterHeighDir(blockId)
	for _, dir in pairs({0,1,2,3,5,6,7,8}) do 
		local offset = 0
		if dir == 0 or dir == 2 or dir == 6 or dir == 8 then 
			offset = 1 
		end
        local toDirBlockId = map:getBlockConfigId(getSpreadPos(pos, dir))
        local toDirWaterType = getWaterType(toDirBlockId)
        local toDirHeigh = getWaterHeighDir(toDirBlockId)
		if waterType == toDirWaterType and toDirHeigh > heigh + offset then
			return true
		end
	end
	return false
end

local function update(map, pos, drying)
	if not map then return end

	map = World.CurWorld:getMap(map)
	local blockId = map:getBlockConfigId(pos)
    local waterType = getWaterType(blockId)
    if not waterType then
        return
    end
	if isInNoWaterArea(map, pos, waterType) then 
		map:setBlockConfigId(pos, 0)
		return
	end

	local heigh, dir = getWaterHeighDir(blockId)
	local headPos = getSpreadPos(pos, WATER_DIR.PY)
	local headId = map:getBlockConfigId(headPos)
	local headHeigh, headDir = getWaterHeighDir(headId)
	if heigh == MaxWaterHeigh then --pos处为瀑布
		if headHeigh == 0 then --上方的水即将干涸，也可能处于水堆边缘，暂不确定保持现状或进入干涸
			spread(map, pos)
		elseif headHeigh < 0 then --上方已干涸，pos也进入干涸
			dryUp(map, pos)
		else
			spread(map, pos)
		end
		return
	end

	if heigh == MaxWaterHeigh - 1 then --水源，向下方或四周扩散
		spread(map, pos)
		return
	end

	if drying then 
		dryUp(map, pos, drying)
		return
	end

	-- 非水源/瀑布
	local flag = aroundHasHigherWater(map, pos)
	if flag then -- 向下方或四周扩散
		spread(map, pos)
	else -- 干涸
		dryUp(map, pos)
	end
end

local function calSmoothDir(pLv, nLv, cLv)
	if pLv == nLv then 
		return 0
	end	
	if pLv == -2 then --可冲毁
		return 1
	end
	if nLv == -2 then 
		return -1
	end
	if pLv == -1 then --阻挡
		return nil
	end
	if nLv == -1 then 
		return nil
	end

	return pLv > nLv and -1 or 1;
end

local function changedBlock()
    for k, v in pairs(waitToChangeBlocks) do
        v.map:setBlockConfigId(v.pos, obsidianId)
        local tPos = getSpreadPos(v.pos, WATER_DIR.PY)
        local tId = v.map:getBlockConfigId(tPos)
        if getWaterType(tId) == "water" then
            addSmoothPos(v.map, tPos, tId)
        end
    end
    waitToChangeBlocks = {}
end

local function smooth()
	for k, v in pairs(waitToDry) do 
        v.map:setBlockConfigId(v.pos, v.id)
	end
	waitToDry = {}

	if not next(waitToSmooth) then 
		return
	end
	
	for k, v in pairs(waitToSmooth) do 
		newCreateWater(v.map, v.pos, v.id)
	end

	for _, water in pairs(waitToSmooth) do
		local map = water.map
		local cPos = water.pos
		local cBlockId = map:getBlockConfigId(cPos)
        local waterType = getWaterType(cBlockId)
		if not waterType then 
            goto continue
        end

        local function checkDirRuin(dir)
            local id = map:getBlockConfigId(getSpreadPos(cPos, dir))
            if canRuinedByTypeWater(id, waterType) then
                return -2
            end
            return getWaterHeighDir(id)
        end
		local cHeigh, cDir = getWaterHeighDir(cBlockId)
		local lHeigh = checkDirRuin(WATER_DIR.LM)
		local rHeigh = checkDirRuin(WATER_DIR.RM)
		local tHeigh = checkDirRuin(WATER_DIR.CT)
		local dHeigh = checkDirRuin(WATER_DIR.CD)
		local xDir = calSmoothDir(tHeigh, dHeigh, cHeigh);
		local zDir = calSmoothDir(rHeigh, lHeigh, cHeigh);
		local smoothDir = xDir and zDir and 3 * (xDir + 1) + zDir + 1 or cDir
		local waterId = getWaterByHeighDir(cHeigh, smoothDir, waterType)
		if waterId and getWaterType(waterId) then
            newCreateWater(map, cPos, waterId)
			WaterMgr.AddChangedPos(map, cPos)
		end

        ::continue::
	end

	waitToSmooth = {}
end

local function tick()
	if next(changedWater) then 
		lastChangedWater = changedWater
		changedWater = {}
		for _, water in pairs(lastChangedWater) do
			update(water.map, water.pos, water.drying)
		end
		smooth()
        changedBlock()
        fireWood()
	end
	if not next(changedWater) then 
		tickTimer = nil
	end
end

local function removeWaterInArea(map, center, radius, waterType)
	map = World.CurWorld:getMap(map)
	for offsetX = -radius, radius do 
		for offsetZ = math.abs(offsetX) - radius, radius - math.abs(offsetX) do
			local pos = { x = center.x + offsetX, y = center.y, z = center.z + offsetZ}
            local blockId = map:getBlockConfigId(pos)
			if getWaterType(blockId) == waterType then 
				map:setBlockConfigId(pos, 0)
			end
		end
	end
end

function WaterMgr.BlockBreak(map, pos)
    map = World.CurWorld:getMap(map)
    local position = findAroundHighestWater(map, pos)
    if position then
        WaterMgr.AddChangedPos(map, position)
    end
end

function WaterMgr.BlockReplace(map, pos, oldId, newId)

    if oldId == 0 then return end

    local oldBlockType = getBlockType(oldId)
    if not oldBlockType then return end

    WaterMgr.AddChangedPos(map, pos)

    local newBlockType = getBlockType(newId)
    if not newBlockType then return end

    if oldBlockType == newBlockType then return end

    if oldBlockType ~= "lava" and oldBlockType ~= "water" then return end

    if newBlockType ~= "lava" and newBlockType ~= "water" then return end

    addChangeBlockPos(map, pos)
    changedBlock()
end

function WaterMgr.IsWater(id)
    assert(id, "this id is nil")
    local waterType = getWaterType(id)
    if waterType and #waterType > 0 then
        return true
    else
        return false
    end
end

function WaterMgr.AddNoWaterArea(map, center, radius, waterType)
    waterType = waterType or defaultWaterType
	local id = mapPosKey(map, center)

    local typeNoWaterArea = getTypeNoWaterArea(waterType)
	typeNoWaterArea[id] = {map = map, center = center, radius = radius}
	for k,v in pairs(changedWater) do
		if isInNoWaterArea(map, v.pos, v.waterType) then 
			changedWater[k] = nil
		end
	end
	if not next(changedWater) then 
		tickTimer = nil
	end

	removeWaterInArea(map, center, radius, waterType)
	return id
end

function WaterMgr.DelNoWaterArea(id, waterType)
    waterType = waterType or defaultWaterType
    local typeNoWaterArea = getTypeNoWaterArea(waterType)
    typeNoWaterArea[id] = nil
end

function WaterMgr.AddWaterCfg(cfg)
	if not cfg.waterCfg then return end
	local waterCfg = cfg.waterCfg
	local waterType = getWaterType(cfg.id)
	local heigh, dir = waterCfg.heigh, waterCfg.dir
	saveWater(cfg.id, waterType, heigh, dir)

	if waterCfg.heigh == MaxWaterHeigh then
		FULL_WATER_ID[waterType] = cfg.id
	end

    if waterCfg.source then
        waterSource[waterType] = cfg.id
    end
end

function WaterMgr.AddWaterSource(map, pos, waterType)
    map = World.CurWorld:getMap(map)
    waterType = waterType or defaultWaterType
    local waterId = waterSource[waterType]
    if waterId then
        map:setBlockConfigId(pos, waterId)
        WaterMgr.AddChangedPos(map, pos)
    end
end

function WaterMgr.AddChangedPos(map, pos, originPos, drying)
	if not map then return end

	map = World.CurWorld:getMap(map)
    local blockId = map:getBlockConfigId(pos)
	if not originPos and not WaterMgr.IsWater(blockId) then --理应是水方块被替换的情况
		dryUp(map, pos)
	else
		local key = mapPosKey(map, pos)
		if changedWater[key] and changedWater[key].drying == nil and drying then
            return
        end
        local waterType = getWaterType(blockId)
		changedWater[key] = {map = map, pos = pos, waterType = waterType, drying = drying}
	end

	if not tickTimer then
		tickTimer = World.Timer(5, function ()
			tick()
			return (next(changedWater) or next(touchWoods) or next(waitToChangeBlocks)) and true
		end)
	end
end

local function init()
    local blockCfgs = setting:fetch("block")
    for _, cfg in pairs(blockCfgs) do
        WaterMgr.AddWaterCfg(cfg)
    end
end

init()

RETURN()