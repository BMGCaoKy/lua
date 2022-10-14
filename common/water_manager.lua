local changedWater = L("changedWater", {})
local lastChangedWater = L("lastChangedWater", nil)
local tickTimer = L("tickTimer", nil) 
local waitToSmooth = L("waitToSmooth", {}) 
local waitToDry = L("waitToDry", {}) 
local World_CurWorld = World.CurWorld
local waterRuinCfg = World.cfg.waterRuinsBlock
local waterTickTimer = World.cfg.waterTickTimer or 5
local waterDefaultRuinsBlock = waterRuinCfg and waterRuinCfg.default or false
local blocksCanRuinedOrNot = waterRuinCfg and waterRuinCfg.blocks
local FULL_WATER_ID = L("FULL_WATER_ID", {})
local AIR_BLOCK = "/air"
local heighDirToId = L("heighDirToId", {}) 
local idToHeighDir = L("idToHeighDir", {}) 
local noWaterArea = L("noWaterArea", {}) 
local sourceWaterBlockId = L("sourceWaterBlockId", 0) 
 
-- 无限水源：放置水源方块后，向外扩散流动的水若其有两个面触碰到了水源方块，则其自身变为水源方块
local function setBlockConfigId(map, pos, id)
	if id == 0 then
		map:setBlockConfigId(pos, id)
	end
	
    local nBlockPos, sBlockPos, eBlockPos, wBlockPos = 
        Lib.v3add(pos, {x = 1,y = 0,z = 0}), Lib.v3add(pos, {x = -1,y = 0,z = 0}), Lib.v3add(pos, {x = 0,y = 0,z = 1}), Lib.v3add(pos, {x = 0,y = 0,z = -1})
	local ncfg, sCfg, eCfg, wCfg = map:getBlock(nBlockPos),map:getBlock(sBlockPos),map:getBlock(eBlockPos),map:getBlock(wBlockPos)
    local sourceCount = 0
    if ncfg.id == sourceWaterBlockId then
        sourceCount = sourceCount + 1
    end
    if sCfg.id == sourceWaterBlockId then
        sourceCount = sourceCount + 1
    end
    if eCfg.id == sourceWaterBlockId then
        sourceCount = sourceCount + 1
    end
    if wCfg.id == sourceWaterBlockId then
        sourceCount = sourceCount + 1
    end
	if sourceCount < 2 then
		map:setBlockConfigId(pos, id)
		return
	end
	map:setBlockConfigId(pos, sourceWaterBlockId)
end

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

local function getHeighDirKey(heigh, dir)
	return 100 * heigh + dir
end

function WaterMgr.IsWater(id)
	return idToHeighDir[id] and true or false
end

local function canRuinedByWater(id)
	local cfg = Block.GetIdCfg(id)
	if not cfg then
		return
	end
	local fullName = cfg.fullName
	if fullName == AIR_BLOCK then 
		return true
	end
	if blocksCanRuinedOrNot and blocksCanRuinedOrNot[fullName] then 
		return blocksCanRuinedOrNot[fullName]
	end
	return waterDefaultRuinsBlock
end

local function getWaterHeighDirById(id)
	local tb = idToHeighDir[id]
	if tb then 
		return tb.heigh, tb.dir
	end
	if canRuinedByWater(id) then 
		return -2, -2
	end
	return -1, -1
end

local function getWaterByHeighDir(heigh, dir)
	return heighDirToId[getHeighDirKey(heigh, dir)]
end

local function getSpreadToPos(pos, dir)
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
	return Lib.v3Hash(pos, map)
end

function WaterMgr.AddWaterCfg(cfg)
	if not cfg.waterCfg then return end
	local waterCfg = cfg.waterCfg
	idToHeighDir[cfg.id] = {heigh = waterCfg.heigh, dir = waterCfg.dir}
	heighDirToId[getHeighDirKey(waterCfg.heigh, waterCfg.dir)] = cfg.id

	if waterCfg.heigh == MaxWaterHeigh then 
		FULL_WATER_ID = cfg.id
	end

	if cfg.waterCfg.sourceWater then
		sourceWaterBlockId = cfg.id
	end
end

function WaterMgr.Tick()
	if next(changedWater) then 
		lastChangedWater = changedWater
		changedWater = {}
		for _, water in pairs(lastChangedWater) do
			WaterMgr.Update(water.map, water.pos, water.drying)
		end
		WaterMgr.Smooth()

	end
	if not next(changedWater) then 
		tickTimer = nil
	end
end

function WaterMgr.AddChangedPos(map, pos, originPos, drying)
	if not map then return end
	if World.cfg.enableWaterSpread == false then return end

	if type(map) == "string" then
		map = World_CurWorld:getMap(map)
	end
	if not originPos and not WaterMgr.IsWater(map:getBlockConfigId(pos)) then --理应是水方块被替换的情况
		WaterMgr.DryUp(map, pos)
	else
		local key = mapPosKey(map, pos)
		if changedWater[key] and changedWater[key].drying == nil and drying then return end

		changedWater[key] = {
			map = map,
			pos = pos,
			originPos = originPos,
			drying = drying,
		}
	end

	if not tickTimer then 
		tickTimer = World.Timer(waterTickTimer, function ()
			WaterMgr.Tick()
			return next(changedWater) and true
		end)
	end
end

function WaterMgr.AddNoWaterArea(map, center, radius)
	local id = mapPosKey(map, center)
	noWaterArea[id] = {
		map = map,
		center = center,
		radius = radius,
	}

	for k,v in pairs(changedWater) do
		if WaterMgr.IsInNoWaterArea(map, center, v.pos) then 
			changedWater[k] = nil
		end
	end
	if not next(changedWater) then 
		tickTimer = nil
	end

	WaterMgr.RemoveWaterInArea(map, center, radius)
	return id
end

function WaterMgr.DelNoWaterArea(id)
	noWaterArea[id] = nil
end

function WaterMgr.RemoveWaterInArea(map, center, radius)
	map = World_CurWorld:getMap(map)
	for offsetX = -radius, radius do 
		for offsetZ = math.abs(offsetX) - radius, radius - math.abs(offsetX) do
			local pos = { x = center.x + offsetX, y = center.y, z = center.z + offsetZ}
			if WaterMgr.IsWater(map:getBlockConfigId(pos)) then 
				map:setBlockConfigId(pos, 0)
			end
		end
	end
end

function WaterMgr.IsInNoWaterArea(map, pos)
	for _, area in pairs(noWaterArea) do
		if map == area.map and area.center.y == pos.y and Lib.getPosXZAbsoluteDistance(area.center, pos) <= area.radius then 
			return true
		end
	end
end

local function aroundHasHigherWater(map, pos, heigh, dir)
	for _, dir in pairs({0,1,2,3,5,6,7,8}) do 
		local offset = 0
		if dir == 0 or dir == 2 or dir == 6 or dir == 8 then 
			offset = 1 
		end
		if getWaterHeighDirById(map:getBlockConfigId(getSpreadToPos(pos, dir))) > heigh + offset then
			return true
		end
	end
	return false
end

local function addSmoothPos(map, pos, id)
	waitToSmooth[mapPosKey(map, pos)] = {
		map = map, 
		pos = pos,
		id = id 
	}
end

local function addDryPos(map, pos, id)
	if not waitToSmooth[mapPosKey(map, pos)] then 
		waitToDry[mapPosKey(map, pos)] = {
			map = map, pos = pos, id = id
		}
	end
end

function WaterMgr.Update(map, pos, drying)
	if not map then return end

	map = World_CurWorld:getMap(map)
	local blockId = map:getBlockConfigId(pos)
	if WaterMgr.IsWater(blockId) and WaterMgr.IsInNoWaterArea(map, pos) then 
		map:setBlockConfigId(pos, 0)
		return
	end

	local heigh, dir = getWaterHeighDirById(blockId)
	if heigh < 0 then --非水方块
		return
	end

	local headPos = getSpreadToPos(pos, WATER_DIR.PY)
	local headId = map:getBlockConfigId(headPos)
	local headHeigh, headDir = getWaterHeighDirById(headId)
	if heigh == MaxWaterHeigh then --pos处为瀑布
		if headHeigh == 0 then --上方的水即将干涸，也可能处于水堆边缘，暂不确定保持现状或进入干涸
			WaterMgr.Spread(map, pos)
		elseif headHeigh < 0 then --上方已干涸，pos也进入干涸
			WaterMgr.DryUp(map, pos)
		else
			WaterMgr.Spread(map, pos)
		end
		return
	end

	if heigh == MaxWaterHeigh - 1 then --水源，向下方或四周扩散
		WaterMgr.Spread(map, pos)
		return
	end

	if drying then 
		WaterMgr.DryUp(map, pos, drying)
		return
	end

	-- 非水源/瀑布
	local flag = aroundHasHigherWater(map, pos, heigh, dir)
	if flag then -- 向下方或四周扩散
		WaterMgr.Spread(map, pos)
	else -- 干涸
		WaterMgr.DryUp(map, pos)
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
			local upBlockId = map:getBlockConfigId({x = pos.x + dx, y = pos.y, z = pos.z + dz})
			if not WaterMgr.IsWater(upBlockId) then 
            	goto CAL_END
			end
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
			local upBlockId = map:getBlockConfigId({x = pos.x + dx, y = pos.y, z = pos.z + dz})
			if not WaterMgr.IsWater(upBlockId) then 
            	goto CAL_END
			end
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
    ::CAL_END::
	return WATER_SPREAD_DIR[dir]
end

function WaterMgr.Spread(map, pos)
	local footPos = getSpreadToPos(pos, WATER_DIR.NY)
	local footBlockId = map:getBlockConfigId(footPos)
	if WaterMgr.IsWater(footBlockId) or canRuinedByWater(footBlockId) then --下方空则形成瀑布
		if footPos.y >= 0 then 
			addSmoothPos(map, footPos, FULL_WATER_ID)
			WaterMgr.AddChangedPos(map, footPos, footPos, true)
	   	end
		return
	end

	local blockId = map:getBlockConfigId(pos)
	local heigh, dir = getWaterHeighDirById(blockId)
	local dirs = getSpreadDirs(map, pos, dir, heigh)

	local function checkSpread(spreadTo)
		local newPos, heighDown = getSpreadToPos(pos, spreadTo)
		if WaterMgr.IsInNoWaterArea(map, newPos) then 
			return
		end

		if heigh >= MaxWaterHeigh then 
			heigh = MaxWaterHeigh - 1
		end
		local newHeigh = heigh - heighDown
		if newHeigh <= MaxWaterHeigh and newHeigh >= 0 then 
			local newDir = calSpreadDir(dir, spreadTo)
			local oldBlockId = map:getBlockConfigId(newPos)
			local oldBlockHeigh, oldDir = getWaterHeighDirById(oldBlockId)
			if oldBlockHeigh >= 0 and oldBlockHeigh > newHeigh then --高位水不被低位水覆盖
				newHeigh = oldBlockHeigh
				newDir = oldDir
			end

			if canRuinedByWater(oldBlockId) or (WaterMgr.IsWater(oldBlockId) and newHeigh >= 0 and heigh > newHeigh) then 
				local newId = getWaterByHeighDir(newHeigh, newDir)
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

function WaterMgr.DryUp(map, pos, drying)
	local blockId = map:getBlockConfigId(pos)
	local heigh, dir = getWaterHeighDirById(blockId)
	if heigh == 0 then 
		addDryPos(map, pos, 0)

		local footPos = getSpreadToPos(pos, WATER_DIR.NY)
		local footBlockId = map:getBlockConfigId(footPos)
		if WaterMgr.IsWater(footBlockId) then 
			WaterMgr.AddChangedPos(map, footPos)
		end
	elseif heigh > 0 then 
		local nCenterBlock 
		if dir == WATER_DIR.NY then --瀑布
			nCenterBlock = getWaterByHeighDir(MaxWaterHeigh - 2, WATER_DIR.CM)
		elseif dir ~= WATER_DIR.CM then --水面先变平
			nCenterBlock = getWaterByHeighDir(heigh, WATER_DIR.CM)
		else --再下降水面高度
			nCenterBlock = getWaterByHeighDir(heigh - 1, WATER_DIR.CM)
		end
		if nCenterBlock then 
			addDryPos(map, pos, nCenterBlock)
			WaterMgr.AddChangedPos(map, pos, nil, true)
		end
	end

	for _, spreadTo in pairs(WATER_DRY_DIR[dir] or {0,1,2,3,5,6,7,8}) do 
		local toPos = getSpreadToPos(pos, spreadTo)
		local blockId = map:getBlockConfigId(toPos)
		local tHeigh, tDir = getWaterHeighDirById(blockId)
		if WaterMgr.IsWater(blockId) then 
			if tHeigh < heigh or heigh < 0 then 
				WaterMgr.AddChangedPos(map, toPos, nil, true)
			else
				WaterMgr.AddChangedPos(map, toPos)
			end
		end
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

function WaterMgr.Smooth()
	for k, v in pairs(waitToDry) do 
		setBlockConfigId(v.map, v.pos, v.id)
		-- v.map:setBlockConfigId(v.pos, v.id)
	end
	waitToDry = {}

	if not next(waitToSmooth) then 
		return
	end
	
	for k, v in pairs(waitToSmooth) do
		if WaterMgr.IsWater(v.id) then
			WaterMgr.onWaterFlow(v.map, v.pos)
		end
		setBlockConfigId(v.map, v.pos, v.id)
		-- v.map:setBlockConfigId(v.pos, v.id)
	end

	for _, water in pairs(waitToSmooth) do
		local map = water.map
		local cPos = water.pos
		local cBlockId = map:getBlockConfigId(cPos)
		if not WaterMgr.IsWater(cBlockId) then 
            goto continue
        end

		local cHeigh, cDir = getWaterHeighDirById(cBlockId)
		local lHeigh = getWaterHeighDirById(map:getBlockConfigId(getSpreadToPos(cPos, WATER_DIR.LM)))
		local rHeigh = getWaterHeighDirById(map:getBlockConfigId(getSpreadToPos(cPos, WATER_DIR.RM)))
		local tHeigh = getWaterHeighDirById(map:getBlockConfigId(getSpreadToPos(cPos, WATER_DIR.CT)))
		local dHeigh = getWaterHeighDirById(map:getBlockConfigId(getSpreadToPos(cPos, WATER_DIR.CD)))
		local xDir = calSmoothDir(tHeigh, dHeigh, cHeigh);
		local zDir = calSmoothDir(rHeigh, lHeigh, cHeigh);
		local smoothDir = xDir and zDir and 3 * (xDir + 1) + zDir + 1 or cDir

		local waterId = getWaterByHeighDir(cHeigh, smoothDir)
		if WaterMgr.IsWater(waterId) then
			WaterMgr.onWaterFlow(map, cPos)
			setBlockConfigId(map, cPos, waterId)
			-- map:setBlockConfigId(cPos, waterId)
			WaterMgr.AddChangedPos(map, cPos)
		end

        ::continue::
	end

	local lcw_same_as_wts = true
	for key, value in pairs(lastChangedWater) do
		if not changedWater[key] then
			lcw_same_as_wts = false
		end
	end
	if lcw_same_as_wts then
		for key, value in pairs(changedWater) do
			if not lastChangedWater[key] then
				lcw_same_as_wts = false
			end
		end
	end

	if lcw_same_as_wts then
		changedWater = {}
	end

	waitToSmooth = {}
end

function WaterMgr.onWaterFlow(map, pos)
    if World.isClient then
        return
    end
    Block.onWaterFlow(map, pos)
end

RETURN()