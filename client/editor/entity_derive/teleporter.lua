local teleporter = L("teleporter", {})
local data_state = require "editor.dataState"
local cmd = require "editor.cmd"
local state = require "editor.state"
local base = require "editor.cmds.cmd_base"
local engine = require "editor.engine"
local def = require "editor.def"
local defaultCount = 5
local offset = 0.5
local allTelePairs = L("allTelePairs", {})
local allMaxPairCounts = L("allMaxPairCounts", {})
local allCurIndexs = L("allCurIndexs", {})
local nextPairIDs = L("nextPairIDs", {})
local num = 0

local function getMapDatas(mapDatas, mapName, cfgName, default)
	if not mapDatas[mapName] then
		mapDatas[mapName] = {}
	end
	local datas = mapDatas[mapName]
	cfgName = string.find(cfgName, "1") and "oneWay" or "twoWay"
	if not datas[cfgName] then
		datas[cfgName] = default
	end
	return datas[cfgName]
end

local function setMapDatas(mapDatas, mapName, cfgName, value)
	cfgName = string.find(cfgName, "1") and "oneWay" or "twoWay"
	mapDatas[mapName][cfgName] = value
end

local function getPairID(curMap, cfg)
	local maxPairCount = getMapDatas(allMaxPairCounts, curMap, cfg, cfg and cfg.maxPairCount or defaultCount)
	local telePairs = getMapDatas(allTelePairs, curMap, cfg, {})
	local curIndex = getMapDatas(allCurIndexs, curMap, cfg, 0)
	local ret
	for i = 1, maxPairCount do
		local targetID = (curIndex + i) % maxPairCount
		if targetID == 0 then
			targetID = maxPairCount
		end
		if not telePairs[targetID] then
			ret = targetID
			break
		end
	end
	return ret
end

local function setHeadIcon(entity, pairID, order)
	local dirType = entity:cfg()._name:find("1") and 1 or 2
	local str
	local path
	if dirType == 1 then
		str = order == 1 and "in" or "out"
	end
	if dirType == 1 then
		path = "plugin/myplugin/image/"..str .. "_".. pairID ..".png"
	else
		path = "plugin/myplugin/image/out_in_" ..pairID ..".png"
	end
	entity:setHeadText(0, 0, "[P=" .. path .. "]")
	entity:updateShowName()
end

local function getRyBySide(side)
	--[[
		y   x
		↑ ↗
		|--→z
	]]
	local dir = Lib.v3normalize(side)
	local ry = 0
	if dir.y ~= 0 then
		return ry
	end
	local dirZ, dirX = dir.z, dir.x
	if dirZ ~= 0 then
		ry = dirZ == 1 and 0 or 180
	else
		ry = dirX == 1 and 270 or 90
	end
	return ry
end

local function getNewPos( entity, side, derive)
	local ry = 0
	local posOffset
	if not entity:cfg().rotateY then
		posOffset = Lib.v3(offset, 0, offset)
	else
		assert(side)
		derive.side = side
		ry = getRyBySide(side)
		if ry == 0 then
			posOffset = Lib.v3(offset, 0, 0)
		elseif ry == 90 then
			posOffset = Lib.v3(0, 0, offset)
		elseif ry == 180 then
			posOffset = Lib.v3(-offset, 0, 0)
		elseif ry == 270 then
			posOffset = Lib.v3(0, 0, -offset)
		end
	end
	local function canUseOffset()
		local pos = derive.pos
		if math.tointeger(pos.x) and math.tointeger(pos.z) then
			return true
		end
		return false
	end
	if canUseOffset() then
		derive.pos = Lib.v3add(derive.pos, posOffset)
	end
	derive.ry = ry
	return {
		pos = derive.pos,
		ry = ry,
	}
end

local function calcTelePos(cfgName, pos, ry)
	local offset = Entity.GetCfg(cfgName).dirOffset[tostring(ry)]
	assert(offset)
	return Lib.v3add(offset, pos)
end

local function addHeadTextNumber()
	num = num + 1
	return num
end

local function subHeadTextNumber()
	num = num - 1
	return num
end

function teleporter.add(entity_obj, id, derive, pos, cmdData)
	local entity, cfg, curMap, pairID, telePairs, nextPairID, targetID, newPos

	cfg = entity_obj:getCfgById(id)
	curMap = data_state.now_map_name
	entity = entity_obj:getEntityById(id)

	telePairs = getMapDatas(allTelePairs, curMap, cfg)
	nextPairID = getMapDatas(nextPairIDs, curMap, cfg)
	targetID = nextPairID or getPairID(curMap, cfg)

	local function changePosBySide()
		derive.pos = pos
		newPos = getNewPos(entity, cmdData.side, derive)
		pos = newPos.pos
		entity_obj:setPosById(id, newPos)
	end

	changePosBySide()
	derive.pairID = targetID

	local function setTelePairs(index, targetID, editorID)
		if not telePairs[targetID] then
			telePairs[targetID] = {}
		end
		telePairs[targetID][index] = editorID
	end

	if not nextPairID then --add 1st
		local function setFailed()
			handle_mp_editor_command("undo")
		end
		derive.order = 1
		setTelePairs(1, targetID, id)
		setMapDatas(nextPairIDs, curMap, cfg, targetID)
		Lib.emitEvent(Event.EVENT_SHOW_TELEPORTER_TIP, true, 1, targetID, setFailed, addHeadTextNumber())
	else --add 2nd
		local function setPariEntityData()
			local id1 = telePairs[targetID][1]
			local data1 = entity_obj:getDataById(id1)
			setTelePairs(2, targetID, id)
			derive.order = 2
			derive.teleID = id1
			derive.telePos = calcTelePos(entity_obj:getCfgById(id1), data1.pos, data1.ry)
			data1.telePos = calcTelePos(cfg, pos, newPos.ry)
			data1.teleID = id
		end
		setPariEntityData()
		setMapDatas(allCurIndexs, curMap, cfg, targetID)
		setMapDatas(nextPairIDs, curMap, cfg, nil)
		Lib.emitEvent(Event.EVENT_SHOW_TELEPORTER_TIP, true, 2, targetID, nil, addHeadTextNumber())
	end
	setHeadIcon(entity, targetID, derive.order)
end

function teleporter.del(entity_obj, id, derive)
	local cfg = entity_obj:getCfgById(id)
	local curMap = data_state.now_map_name
	local telePairs = getMapDatas(allTelePairs, curMap, cfg)
	local targetID = derive.pairID
	local teleID = derive.teleID
	derive.teleID = nil
	derive.pairID = nil
	telePairs[targetID][derive.order] = nil
	derive.order = nil
	local nextPairID = getMapDatas(nextPairIDs, curMap, cfg)
	if nextPairID then --del 1st
		setMapDatas(nextPairIDs, curMap, cfg, nil)
		telePairs[targetID] = nil
		Lib.emitEvent(Event.EVENT_SHOW_TELEPORTER_TIP, true, 0 , nil, nil, subHeadTextNumber())
	else --del 2nd
		local function delFailed()
			handle_mp_editor_command("redo")
		end
		setMapDatas(nextPairIDs, curMap, cfg, targetID)
		local data = entity_obj:getDataById(teleID)
		data.telePos = nil
		derive.telePos = nil
		data.teleID = nil
		Lib.emitEvent(Event.EVENT_SHOW_TELEPORTER_TIP, true, 1, targetID, delFailed, subHeadTextNumber())
	end
end

function teleporter.load(entity_obj, id, pos, entity)-- need to reset teleID
	local cfg = entity_obj:getCfgById(id)
	local curMap = data_state.now_map_name
	local telePairs = getMapDatas(allTelePairs, curMap, cfg, {})
	local derive = entity_obj:getDataById(id)
	local pairID = derive.pairID
	local order = derive.order
	if not telePairs[pairID] then --load 1st
		telePairs[pairID] = {}
	else --load 2nd
		local teleID = telePairs[pairID][3 - order]
		local teleDerive = entity_obj:getDataById(teleID)
		teleDerive.teleID = id
		derive.teleID = teleID
	end
	telePairs[pairID][order] = id
	setHeadIcon(entity, pairID, order)
end

function teleporter.canRedoSet(entity_obj, cfgName)
	local curMap = data_state.now_map_name
	local nextPairID = getMapDatas(nextPairIDs, curMap, cfgName)
	local targetID = nextPairID or getPairID(curMap, cfgName)
	return not not targetID
end

function teleporter.canRedoDel(entity_obj, cfgName)
	local curMap = data_state.now_map_name
	local nextPairID = getMapDatas(nextPairIDs, curMap, cfgName)
	-- can never delete a single point!
	return not nextPairID
end

function teleporter.redoDel(entity_obj, cmdDel)
	local id = cmdDel._id
	local data1 = entity_obj:getDataById(id)
	cmdDel._cfg1 = cmdDel._cfg
	cmdDel._pos1 = cmdDel._pos
	cmdDel._side1 = data1.side
	local teleID = data1.teleID
	entity_obj:delEntity(id)
	if teleID then
		local data2 = entity_obj:getDataById(teleID)
		cmdDel._cfg2 = entity_obj:getCfgById(teleID)
		cmdDel._pos2 = data2.pos
		cmdDel._side2 = data2.side
		entity_obj:delEntity(teleID)
	end
	state:set_focus(nil)
	engine:editor_obj_type("common")
	engine:set_bModify(true);
	Lib.emitEvent(Event.EVENT_SHOW_TELEPORTER_TIP, false)
	return true
end

function teleporter.undoDel(entity_obj, cmdDel)
	local pos1, cfg1, pos2, cfg2 = cmdDel._pos1, cmdDel._cfg1, cmdDel._pos2, cmdDel._cfg2
	local side1, side2 = cmdDel._side1, cmdDel._side2
	assert(pos1, cfg1)
	if pos2 then
		entity_obj:addEntity(pos2, {
			cfg = cfg2,
			side = side2,
		})
	end
	local id = entity_obj:addEntity(pos1, {
		cfg = cfg1,
		side = side1,
	})
	cmdDel._id = id
	state:set_focus({id = id}, def.TENTITY)
	engine:set_bModify(true);
	return true
end

RETURN(teleporter)
