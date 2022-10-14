local changedLava = L("changedLava", {})
local lastChangedLava = L("lastChangedLava", nil)
local tickTimer = L("tickTimer", nil) 
local waitToSmooth = L("waitToSmooth", {}) 
local waitToDry = L("waitToDry", {}) 
local World_CurWorld = World.CurWorld
local lavaRuinCfg = World.cfg.lavaRuinsBlock
local lavaTickTimer = World.cfg.lavaTickTimer or 20
local lavaDefaultRuinsBlock = lavaRuinCfg and lavaRuinCfg.default or false
local blocksCanRuinedOrNot = lavaRuinCfg and lavaRuinCfg.blocks
local FULL_LAVA_ID = L("FULL_LAVA_ID", {})
local AIR_BLOCK = "/air"
local heighDirToId = L("heighDirToId", {}) 
local idToHeighDir = L("idToHeighDir", {}) 
local noLavaArea = L("noLavaArea", {}) 
 
local LAVA_DIR = {
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
local LAVA_SPREAD_DIR = {
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
local LAVA_DRY_DIR = {
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
4 = lava
0~3, 5~8 = changedPos ↓↓↓
x^
	6 7 8
	3 4 5
	0 1 2 ->z
↑↑↑

lava heigh: 7 ~ 0, 7 is lowest
]]
local MaxLavaHeigh = 8
local maxLavaDir = 10

local function getHeighDirKey(heigh, dir)
	return 100 * heigh + dir
end

function LavaMgr.IsLava(id)
	return idToHeighDir[id] and true or false
end

local function canRuinedByLava(id)
	local fullName = Block.GetIdCfg(id).fullName
	if fullName == AIR_BLOCK then 
		return true
	end
	if blocksCanRuinedOrNot and blocksCanRuinedOrNot[fullName] then 
		return blocksCanRuinedOrNot[fullName]
	end
	return lavaDefaultRuinsBlock
end

local function getLavaHeighDirById(id)
	local tb = idToHeighDir[id]
	if tb then 
		return tb.heigh, tb.dir
	end
	if canRuinedByLava(id) then 
		return -2, -2
	end
	return -1, -1
end

local function getLavaByHeighDir(heigh, dir)
	return heighDirToId[getHeighDirKey(heigh, dir)]
end

local function getSpreadToPos(pos, dir)
	if dir == LAVA_DIR.LD then 
		return {x = pos.x - 1, y = pos.y, z = pos.z - 1}, 2
	elseif dir == LAVA_DIR.CD then 
		return {x = pos.x - 1, y = pos.y, z = pos.z}, 1
	elseif dir == LAVA_DIR.RD then 
		return {x = pos.x - 1, y = pos.y, z = pos.z + 1}, 2
	elseif dir == LAVA_DIR.LM then 
		return {x = pos.x, y = pos.y, z = pos.z - 1}, 1
	elseif dir == LAVA_DIR.CM then 
		return {x = pos.x, y = pos.y, z = pos.z}, 0
	elseif dir == LAVA_DIR.RM then 
		return {x = pos.x, y = pos.y, z = pos.z + 1}, 1
	elseif dir == LAVA_DIR.LT then 
		return {x = pos.x + 1, y = pos.y, z = pos.z - 1}, 2
	elseif dir == LAVA_DIR.CT then 
		return {x = pos.x + 1, y = pos.y, z = pos.z}, 1
	elseif dir == LAVA_DIR.RT then 
		return {x = pos.x + 1, y = pos.y, z = pos.z + 1}, 2
	elseif dir == LAVA_DIR.NY then 
		return {x = pos.x, y = pos.y - 1, z = pos.z}
	elseif dir == LAVA_DIR.PY then 
		return {x = pos.x, y = pos.y + 1, z = pos.z}
	else
		assert(false, "Invalid lava dir will spread to")
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

function LavaMgr.AddLavaCfg(cfg)
	if not cfg.lavaCfg then return end
	local lavaCfg = cfg.lavaCfg
	idToHeighDir[cfg.id] = {heigh = lavaCfg.heigh, dir = lavaCfg.dir}
	heighDirToId[getHeighDirKey(lavaCfg.heigh, lavaCfg.dir)] = cfg.id

	if lavaCfg.heigh == MaxLavaHeigh then 
		FULL_LAVA_ID = cfg.id
	end
end

function LavaMgr.Tick()
	if next(changedLava) then 
		lastChangedLava = changedLava
		changedLava = {}
		for _, lava in pairs(lastChangedLava) do
			LavaMgr.Update(lava.map, lava.pos, lava.drying)
		end
		LavaMgr.Smooth()

	end
	if not next(changedLava) then 
		tickTimer = nil
	end
end

function LavaMgr.AddChangedPos(map, pos, originPos, drying)
	if not map then return end
	if World.cfg.enableLavaSpread == false then return end

	if type(map) == "string" then
		map = World_CurWorld:getMap(map)
	end
	if not originPos and not LavaMgr.IsLava(map:getBlockConfigId(pos)) then --理应是水方块被替换的情况
		LavaMgr.DryUp(map, pos)
	else
		local key = mapPosKey(map, pos)
		if changedLava[key] and changedLava[key].drying == nil and drying then return end

		changedLava[key] = {
			map = map,
			pos = pos,
			originPos = originPos,
			drying = drying,
		}
	end

	if not tickTimer then 
		tickTimer = World.Timer(lavaTickTimer, function ()
			LavaMgr.Tick()
			return next(changedLava) and true
		end)
	end
end

function LavaMgr.AddNoLavaArea(map, center, radius)
	local id = mapPosKey(map, center)
	noLavaArea[id] = {
		map = map,
		center = center,
		radius = radius,
	}

	for k,v in pairs(changedLava) do
		if LavaMgr.IsInNoLavaArea(map, center, v.pos) then 
			changedLava[k] = nil
		end
	end
	if not next(changedLava) then 
		tickTimer = nil
	end

	LavaMgr.RemoveLavaInArea(map, center, radius)
	return id
end

function LavaMgr.DelNoLavaArea(id)
	noLavaArea[id] = nil
end

function LavaMgr.RemoveLavaInArea(map, center, radius)
	map = World_CurWorld:getMap(map)
	for offsetX = -radius, radius do 
		for offsetZ = math.abs(offsetX) - radius, radius - math.abs(offsetX) do
			local pos = { x = center.x + offsetX, y = center.y, z = center.z + offsetZ}
			if LavaMgr.IsLava(map:getBlockConfigId(pos)) then 
				map:setBlockConfigId(pos, 0)
			end
		end
	end
end

function LavaMgr.IsInNoLavaArea(map, pos)
	for _, area in pairs(noLavaArea) do
		if map == area.map and area.center.y == pos.y and Lib.getPosXZAbsoluteDistance(area.center, pos) <= area.radius then 
			return true
		end
	end
end

local function aroundHasHigherLava(map, pos, heigh, dir)
	for _, dir in pairs({0,1,2,3,5,6,7,8}) do 
		local offset = 0
		if dir == 0 or dir == 2 or dir == 6 or dir == 8 then 
			offset = 1 
		end
		if getLavaHeighDirById(map:getBlockConfigId(getSpreadToPos(pos, dir))) > heigh + offset then
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

function LavaMgr.Update(map, pos, drying)
	if not map then return end

	map = World_CurWorld:getMap(map)
	local blockId = map:getBlockConfigId(pos)
	if LavaMgr.IsLava(blockId) and LavaMgr.IsInNoLavaArea(map, pos) then 
		map:setBlockConfigId(pos, 0)
		return
	end

	local heigh, dir = getLavaHeighDirById(blockId)
	if heigh < 0 then --非水方块
		return
	end

	local headPos = getSpreadToPos(pos, LAVA_DIR.PY)
	local headId = map:getBlockConfigId(headPos)
	local headHeigh, headDir = getLavaHeighDirById(headId)
	if heigh == MaxLavaHeigh then --pos处为瀑布
		if headHeigh == 0 then --上方的水即将干涸，也可能处于水堆边缘，暂不确定保持现状或进入干涸
			LavaMgr.Spread(map, pos)
		elseif headHeigh < 0 then --上方已干涸，pos也进入干涸
			LavaMgr.DryUp(map, pos)
		else
			LavaMgr.Spread(map, pos)
		end
		return
	end

	if heigh == MaxLavaHeigh - 1 then --水源，向下方或四周扩散
		LavaMgr.Spread(map, pos)
		return
	end

	if drying then 
		LavaMgr.DryUp(map, pos, drying)
		return
	end

	-- 非水源/瀑布
	local flag = aroundHasHigherLava(map, pos, heigh, dir)
	if flag then -- 向下方或四周扩散
		LavaMgr.Spread(map, pos)
	else -- 干涸
		LavaMgr.DryUp(map, pos)
	end
end

local function getSpreadDirs(map, pos, dir, heigh)
	if pos.y <= 0 then 
		return LAVA_SPREAD_DIR[dir]
	end
	local checkRadius = 5
	if heigh < MaxLavaHeigh - 1 then 
		checkRadius = 5 - (MaxLavaHeigh - heigh)
	end
	if checkRadius <= 0 then 
		return LAVA_SPREAD_DIR[dir]
	end

	for i = 1, checkRadius do 
		local dirs = {}
		for dz = -i, i do 
			local dx = i - math.abs(dz)
			local id = map:getBlockConfigId({x = pos.x + dx, y = pos.y - 1, z = pos.z + dz})
			if id == 0 or LavaMgr.IsLava(id) then 
				if dx > 0 then 
					dirs[LAVA_DIR.CT] = true
				end
				if dz < 0 then 
					dirs[LAVA_DIR.LM] = true
				elseif dz > 0 then 
					dirs[LAVA_DIR.RM] = true
				end
			end

			dx = math.abs(dz) - i
			id = map:getBlockConfigId({x = pos.x + dx, y = pos.y - 1, z = pos.z + dz})
			if id == 0 or LavaMgr.IsLava(id) then 
				if dx < 0 then 
					dirs[LAVA_DIR.CD] = true
				end
				if dz < 0 then 
					dirs[LAVA_DIR.LM] = true
				elseif dz > 0 then 
					dirs[LAVA_DIR.RM] = true
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
	return LAVA_SPREAD_DIR[dir]
end

function LavaMgr.Spread(map, pos)
	local footPos = getSpreadToPos(pos, LAVA_DIR.NY)
	local footBlockId = map:getBlockConfigId(footPos)
	if LavaMgr.IsLava(footBlockId) or canRuinedByLava(footBlockId) then --下方空则形成瀑布
		if footPos.y >= 0 then 
			addSmoothPos(map, footPos, FULL_LAVA_ID)
			LavaMgr.AddChangedPos(map, footPos, footPos, true)
	   	end
		return
	end

	local blockId = map:getBlockConfigId(pos)
	local heigh, dir = getLavaHeighDirById(blockId)
	local dirs = getSpreadDirs(map, pos, dir, heigh)

	local function checkSpread(spreadTo)
		local newPos, heighDown = getSpreadToPos(pos, spreadTo)
		if LavaMgr.IsInNoLavaArea(map, newPos) then 
			return
		end

		if heigh >= MaxLavaHeigh then 
			heigh = MaxLavaHeigh - 1
		end
		local newHeigh = heigh - heighDown
		if newHeigh <= MaxLavaHeigh and newHeigh >= 0 then 
			local newDir = calSpreadDir(dir, spreadTo)
			local oldBlockId = map:getBlockConfigId(newPos)
			local oldBlockHeigh, oldDir = getLavaHeighDirById(oldBlockId)
			if oldBlockHeigh >= 0 and oldBlockHeigh > newHeigh then --高位水不被低位水覆盖
				newHeigh = oldBlockHeigh
				newDir = oldDir
			end

			if canRuinedByLava(oldBlockId) or (LavaMgr.IsLava(oldBlockId) and newHeigh >= 0 and heigh > newHeigh) then 
				local newId = getLavaByHeighDir(newHeigh, newDir)
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
	if spreadSuccDirs[LAVA_DIR.CD] then 
		if spreadSuccDirs[LAVA_DIR.LM] then 
			checkSpread(LAVA_DIR.LD)
		end
		if spreadSuccDirs[LAVA_DIR.RM] then 
			checkSpread(LAVA_DIR.RD)
		end
	end
	if spreadSuccDirs[LAVA_DIR.CT] then 
		if spreadSuccDirs[LAVA_DIR.LM] then 
			checkSpread(LAVA_DIR.LT)
		end
		if spreadSuccDirs[LAVA_DIR.RM] then 
			checkSpread(LAVA_DIR.RT)
		end
	end
end

function LavaMgr.DryUp(map, pos, drying)
	local blockId = map:getBlockConfigId(pos)
	local heigh, dir = getLavaHeighDirById(blockId)
	if heigh == 0 then 
		addDryPos(map, pos, 0)

		local footPos = getSpreadToPos(pos, LAVA_DIR.NY)
		local footBlockId = map:getBlockConfigId(footPos)
		if LavaMgr.IsLava(footBlockId) then 
			LavaMgr.AddChangedPos(map, footPos)
		end
	elseif heigh > 0 then 
		local nCenterBlock 
		if dir == LAVA_DIR.NY then --瀑布
			nCenterBlock = getLavaByHeighDir(MaxLavaHeigh - 2, LAVA_DIR.CM)
		elseif dir ~= LAVA_DIR.CM then --水面先变平
			nCenterBlock = getLavaByHeighDir(heigh, LAVA_DIR.CM)
		else --再下降水面高度
			nCenterBlock = getLavaByHeighDir(heigh - 1, LAVA_DIR.CM)
		end
		if nCenterBlock then 
			addDryPos(map, pos, nCenterBlock)
			LavaMgr.AddChangedPos(map, pos, nil, true)
		end
	end

	for _, spreadTo in pairs(LAVA_DRY_DIR[dir] or {0,1,2,3,5,6,7,8}) do 
		local toPos = getSpreadToPos(pos, spreadTo)
		local blockId = map:getBlockConfigId(toPos)
		local tHeigh, tDir = getLavaHeighDirById(blockId)
		if LavaMgr.IsLava(blockId) then 
			if tHeigh < heigh or heigh < 0 then 
				LavaMgr.AddChangedPos(map, toPos, nil, true)
			else
				LavaMgr.AddChangedPos(map, toPos)
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

function LavaMgr.Smooth()
	for k, v in pairs(waitToDry) do 
		v.map:setBlockConfigId(v.pos, v.id)
	end
	waitToDry = {}

	if not next(waitToSmooth) then 
		return
	end
	
	for k, v in pairs(waitToSmooth) do
		if LavaMgr.IsLava(v.id) then
			LavaMgr.onLavaFlow(v.map, v.pos)
		end
		v.map:setBlockConfigId(v.pos, v.id)
	end

	for _, lava in pairs(waitToSmooth) do
		local map = lava.map
		local cPos = lava.pos
		local cBlockId = map:getBlockConfigId(cPos)
		if not LavaMgr.IsLava(cBlockId) then 
            goto continue
        end

		local cHeigh, cDir = getLavaHeighDirById(cBlockId)
		local lHeigh = getLavaHeighDirById(map:getBlockConfigId(getSpreadToPos(cPos, LAVA_DIR.LM)))
		local rHeigh = getLavaHeighDirById(map:getBlockConfigId(getSpreadToPos(cPos, LAVA_DIR.RM)))
		local tHeigh = getLavaHeighDirById(map:getBlockConfigId(getSpreadToPos(cPos, LAVA_DIR.CT)))
		local dHeigh = getLavaHeighDirById(map:getBlockConfigId(getSpreadToPos(cPos, LAVA_DIR.CD)))
		local xDir = calSmoothDir(tHeigh, dHeigh, cHeigh);
		local zDir = calSmoothDir(rHeigh, lHeigh, cHeigh);
		local smoothDir = xDir and zDir and 3 * (xDir + 1) + zDir + 1 or cDir

		local lavaId = getLavaByHeighDir(cHeigh, smoothDir)
		if LavaMgr.IsLava(lavaId) then
			LavaMgr.onLavaFlow(map, cPos)
			map:setBlockConfigId(cPos, lavaId)
			LavaMgr.AddChangedPos(map, cPos)
		end

        ::continue::
	end

	local lcw_same_as_wts = true
	for key, value in pairs(lastChangedLava) do
		if not changedLava[key] then
			lcw_same_as_wts = false
		end
	end
	if lcw_same_as_wts then
		for key, value in pairs(changedLava) do
			if not lastChangedLava[key] then
				lcw_same_as_wts = false
			end
		end
	end

	if lcw_same_as_wts then
		changedLava = {}
	end

	waitToSmooth = {}
end

function LavaMgr.onLavaFlow(map, pos)
    if World.isClient then
        return
    end
    Block.onLavaFlow(map, pos)
end

RETURN()