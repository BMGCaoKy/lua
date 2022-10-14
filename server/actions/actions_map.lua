local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

function Actions.CreateMap(data, params, context)
    local name = params.name
    if ActionsLib.isEmptyString(name) then
        return
    end
    return World.CurWorld:createDynamicMap(name)
end

function Actions.GetStaticMap(data, params, context)
    local name = params.name
    if ActionsLib.isEmptyString(name) then
        return nil
    end
    local map = World.staticList[name]
    if not map and params.create then
        map = World.CurWorld:getOrCreateStaticMap(params.name)
    end
    return map
end

function Actions.CloseMap(data, params, context)
	params.map:close()
end

function Actions.GetMapPlayer(data, params, context)
	local list = {}
	for _, player in pairs(params.map.players) do
		list[#list+1] = player
	end
	return list
end

function Actions.GetMapNpc(data, params, context)
	local list = {}
	for _, obj in pairs(params.map.objects) do
		if obj.isEntity and not obj.isPlayer then
			list[#list+1] = obj
		end
	end
	return list
end

function Actions.GetMapInitPos(data, params, context)
    return params.map and params.map.cfg.initPos or nil
end

function Actions.GetMapConfig(data, params, context)
    local cfg = Lib.readGameJson("map/" .. params.name .. "/setting.json")
    return cfg and cfg[params.key]
end

function Actions.MoveMapPlayerTo(data, params, context)
    local currentMap = params.map
    if ActionsLib.isInvalidMap(currentMap, "CurrentMap") then
        return
    end
    local targetMap =  World.CurWorld:getMap(params.newmap)
    if ActionsLib.isInvalidMap(targetMap, "TargetMap") then
        return
    end
    currentMap:movePlayersTo(targetMap, params.pos)
end

function Actions.EnterMap(data, params, context)
    local entity = params.entity
    local targetMap = params.map
    if ActionsLib.isInvalidEntity(entity) or ActionsLib.isEmptyString(targetMap) then
        return
    end
    if type(targetMap) == "string" then
        targetMap = World.CurWorld:getOrCreateStaticMap(targetMap)
    end
    if ActionsLib.isInvalidMap(targetMap) then
        return
    end
    entity:setMapPos(targetMap, params.pos or targetMap.cfg.initPos, params.ry, params.rp)
end

function Actions.GetEntityMapId(data, params, context)
    local entity = params.entity
    if not entity or not entity:isValid() then
        return false
    end
    local map = entity.map
    if not map or not map:isValid() then
        return false
    end
	return map.id
end

function Actions.GetEntityMapName(data, params, context)
    local entity = params.entity
    if not entity or not entity:isValid() then
        return false
    end
    local map = entity.map
    if not map or not map:isValid() then
        return false
    end
    return map.name
end

function Actions.AddRegion( data, params, context )
    return World.CurWorld:getMap(params.map):addRegion(params.region.min, params.region.max, params.regionCfg)
end

function Actions.IsMapVaild( data, params, context )
	return World.CurWorld:getMap(params.map):isValid()
end

function Actions.RemoveRegion( data, params, context )
	World.CurWorld:getMap(params.map):removeRegion(params.key)
end

function Actions.SetRegionOwner(data, params, context)
	local region = params.region
	local owner = params.owner
	if not region then
		return false
	end
	region.owner = owner
	return owner
end

function Actions.GetRegionOwner(data, params, context)
	local region = params.region
	if not region then
		return false
	end
	return region.owner
end

function Actions.GetRandomPosInRegion(data, params, context)
    local map = World.CurWorld:getMap(params.map)
    local posArray = map:getRandomPosInRegion(1, not params.isIncludeCollision, params.regionKey, params.region)
    return posArray[1] + Lib.v3(0.5, 0.1, 0.5)
end

function Actions.FillBlockMask( data, params, context )
	local entity = params.entity
    if not entity or not entity.isPlayer then
        return
    end
    local packet ={
        pid = "FillBlockMask",
        min = params.min,
		max = params.max,
        id = params.id,
	}
	entity:sendPacket(packet)
end

function Actions.CreateDuplication(data, params, context)
    local name = params.name
    if ActionsLib.isEmptyString(name) then
        return
    end
    return World.CurWorld:createDynamicMap(name, true) -- params[2]: closeWhenEmpty
end

function Actions.EnterDuplication(data, params, context)
    local entity, map = params.entity, params.map
    if ActionsLib.isInvalidPlayer(entity) or ActionsLib.isEmptyString(map, "Map") then
        return
    end
    if type(map) == "string" then
        map = World.CurWorld:createDynamicMap(map, true) -- params[2]: closeWhenEmpty
    end
    if ActionsLib.isInvalidMap(map) then
        return
    end
    entity:setMapPos(map, params.pos or map.cfg.initPos, params.ry, params.rp)
    return map
end

function Actions.LeaveDuplication(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidPlayer(entity) then
        return
    end
    local saveMapPos = entity.saveMapPos
    entity:setMapPos(World.CurWorld:getOrCreateStaticMap(saveMapPos.map), saveMapPos)
end

function Actions.IsStaticMap(data, params, context)
    return params.map.static
end

function Actions.GetAllRegion(data, params, context)
    local map = params.map
    if not map then
        return {}
    end
    local ret = {}
    for _, region in pairs(map:getAllRegion()) do
        table.insert(ret, region)
    end
    return ret
end

function Actions.GetRegionByName(data, params, context)
    local map = params.map
    local name = params.name
    if not map or not name then
        return nil
    end
    return map:getRegion(name)
end

function Actions.GetRegionCenter(data, params, context)
    local region = params.region
    return region and Lib.getRegionCenter(region) or nil
end

function Actions.GetRegionMin(data, params, context)
    local region = params.region
    return region and region.min or nil
end

function Actions.GetRegionMax(data, params, context)
    local region = params.region
    return region and region.max or nil
end

function Actions.GetRegionKey(data, params, context)
    local region = params.region
    return region and region.key or nil
end

function Actions.IsPosInRegion(data, params, context)
    local pos = params.pos
    local region = params.region
    if ActionsLib.isNil(pos, "Position") or ActionsLib.isInvalidRegion(region) then
        return false
    end
    return Lib.isPosInRegion(region, pos)
end