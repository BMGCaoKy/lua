require "server.world.map_event"
local roomGameConfig = Server.CurServer:getConfig()
local misc = require("misc")
local cjson = require("cjson")
local setting = require "common.setting"
local MapEffectMgr = require "server.world.map_effect_mgr"
local World = World ---@type World
local mapList = World.mapList
local staticList = World.staticList
---@type Map
local Map = World.Map
---@class MapServer
local MapServer = T(World, "MapServer", Lib.derive(Map))
MapServer.__index = MapServer
local NEED_SYNC_REGION_INFOS = RoomGameConfig.isDebug

--下面这个for循环请不要在业务层重写，不然会造成lua和c++调用时序混乱，有野指针风险
for k, v in pairs(MapInstanceServer) do	-- 复制MapInstanceServer导出函数（不含导出成员变量）
	if k:sub(1,2)~="__" and type(v)=="function" then
		MapServer[k] = function (self, ...)
			local obj = assert(self.obj, k)	-- map is closed
			return v(obj, ...)
		end
	end
end

local WorldServer = WorldServer ---@type WorldServer

function WorldServer:loadMap(...)
	local map = World.loadMap(self, ...)
	map.vars = Vars.MakeVars("map", map.cfg)
	return map
end

---@return Map
---@param closeWhenEmpty boolean 当地图没人时关闭
function WorldServer:createDynamicMap(name, closeWhenEmpty)
	local map = self:loadMap(self:nextMapId(), name)
    map.closeWhenEmpty = closeWhenEmpty
    map.isDynamicMap = true
    return map
end

function WorldServer:getMap(map)
	local typ = type(map)
	if typ=="string" then
		return self:getOrCreateStaticMap(map)
	elseif typ=="table" then
		return map
	elseif typ=="nil" then
		return WorldServer.defaultMap
	end
	error(typ)
end

function WorldServer:getGameMode()
    return RUN_MODE
end

--获取服务器启动参数tags
function WorldServer:getServerTags()
    return cjson.decode(roomGameConfig:getTags()) or {}
end

function WorldServer:initMap()
	-- tmp
	self.cfg.defaultMap = self.cfg.defaultMap or "map001"
	if self.cfg.defaultMap then
		WorldServer.defaultMap = self:getOrCreateStaticMap(self.cfg.defaultMap)
	end
	for _, name in ipairs(self.cfg.maps or {}) do
		self:getOrCreateStaticMap(name)
	end
end

function Map:init()
    setmetatable(self, MapServer)
    local function createEntities()
        for key, val in ipairs(self.keyEntitys or {}) do
            if not Map.isValid(self) then
                return
            end
            local derive = val.derive
            local aiData = val.derive and val.derive.aiData or nil
            local entityData = val.data
            if entityData.derive and entityData.derive.pointEntity or not entityData.cfg then
                goto continue
            end
            local entity = EntityServer.Create({
                map = self,
                name = entityData.name,
                cfgName = entityData.cfg,
                pos = entityData.pos,
                ry = entityData.ry,
                rp = entityData.rp or entityData.pitch,
                rr = entityData.rr,
                aiData = entityData.derive and entityData.derive.aiData,
                entityData = entityData,
                createByMapIndex = key,
                objPatchKey = entityData.objPatchKey,
                mapEntityIndex = key,
            })
            if not entity then
                goto continue
            end

            self:addNPC(entity, entityData.cfg)

            ::continue::
        end
    end
    local function createItems()
        for key, val in ipairs(self.keyItems or {}) do
            if not Map.isValid(self) then
                return
            end
			local item
			if val.blockID then
				item = Item.CreateItem(val.cfg, val.count or 1, function(item_data)
					item_data:set_block_id(tonumber(val.blockID))
				end)
			else
				item = Item.CreateItem(val.cfg, val.count or 1)
			end
            DropItemServer.Create({
                map = self, pos = val.pos, item = item, pitch = val.ry, yaw = val.ry,
                createByMapIndex = key, objPatchKey = val.objPatchKey
            })
        end
    end
    self.vars = Vars.MakeVars("map", self.cfg)
    self.timers[#self.timers + 1] = World.Timer(1, function()
        if not Map.isValid(self) then
            return
        end
        createEntities()
        createItems()
    end)
    self.timers[#self.timers + 1] = World.Timer(20, function()
        self:syncSpawnPlayer()
        return true
    end)
    self.timers[#self.timers + 1] = World.Timer(20, function()
        self:trySendPlayerIconInfos()
        return true
    end)

	self:setBlockUpdateDistance(self.cfg.blockUpdateDistance or 50)
    self:loadMeshPartCollision()
	World.Timer(1, function ()
		local sceneManager = World.CurWorld:getSceneManager()
		local scene = self:createScene()
        World.Timer(1, function()
            Trigger.CheckTriggers(nil, "END_MAP_LOADING", self)
        end)
	end)

end

function Map:addNPC(entity, cfg)
	
end

function MapServer:__tostring()
	return string.format("%s[%d]", self.name, self.id)
end

function MapServer:getVar(key)
    return self.vars[key]
end

function MapServer:setVar(key, value)
    self.vars[key] = value
end

function MapServer:movePlayersTo(map, pos)
	for _, player in pairs(self.players) do
		player:setMapPos(map, pos)
	end
end

function MapServer:saveBlockData(min, max)
	local bd = Map.saveBlocks(self, min, max, false)
	assert(bd)
	return misc.zlib_compress(bd), #bd
end

function MapServer:loadBlockData(min, max, zd, len)
	local bd = misc.zlib_uncompress(zd, len)
	assert(bd)
	Map.clearBlocks(self, min, max, false)
	local ok = Map.loadBlocks(self, min, max, bd)
	assert(ok)
end

function MapServer:createBlock(pos, fullName)
	pos = Lib.tov3(pos):blockPos()
	local cfg = Block.GetNameCfg(fullName)
	local id = cfg.id
	self:setBlockConfigId(pos, id)
	Trigger.CheckTriggers(cfg, "BLOCK_SPAWN", {pos = pos, map = self})
	if cfg.effect then
		local effectName = "plugin/" .. cfg.plugin .. "/block/" .. cfg._name .. "/" .. cfg.effect
		MapEffectMgr:addEffect(self, pos, effectName, -1)
	end
end

function MapServer:batchCreateBlockAtRegion(min, max, fullName)
	local cfg = Block.GetNameCfg(fullName)
    local id = cfg.id
    self:fillBlocksConfigId(min, max, id)
    local effectName
	if cfg.effect then
		effectName = "plugin/" .. cfg.plugin .. "/block/" .. cfg._name .. "/" .. cfg.effect
	end
    for _x = min.x, max.x do
        for _y = min.y, max.y do
            for _z = min.z, max.z do
                local pos = {x = _x, y = _y, z = _z}
                Trigger.CheckTriggers(cfg, "BLOCK_SPAWN", {pos = pos, map = self})
                if effectName then
                    MapEffectMgr:addEffect(self, pos, effectName, -1)
                end
            end
        end
    end
end

function MapServer:removeBlock(pos)
    local blockcfg = self:getBlock(pos)
	Trigger.CheckTriggers(blockcfg, "BLOCK_REMOVED",{pos = pos, map = self})
	self:setBlockData(pos, nil)
    if blockcfg then 
        if blockcfg.effect then
            local effectName = "plugin/" .. blockcfg.plugin .. "/block/" .. blockcfg._name .. "/" .. blockcfg.effect
            MapEffectMgr:delEffect(self, pos, effectName)
        end
        if blockcfg.removeEffect then
            local effectName = "plugin/" .. blockcfg.plugin .. "/block/" .. blockcfg._name .. "/" .. blockcfg.removeEffect
            MapEffectMgr:addEffect(self, pos, effectName, blockcfg.removeEffectTime or 20)
        end
	end

    
	local BlockAdapt = require "common.blockAdapt"
	if not BlockAdapt.SetBlockConfigIdAdapt({map = self, pos = pos, tId = 0}) then
        return false
    end
	-- if not self:setBlockConfigId(pos, 0) then
	-- 	return false
    -- end
    
	local upPos = pos + Lib.v3(0, 1, 0)
	while true do
		local downPos = self:checkBlockFall(upPos)
		if downPos==upPos then
			break
		end
		local data = self:getBlockData(upPos)
		if data~=nil then
			self:setBlockData(downPos, data)
			self:setBlockData(upPos, nil)
		end
		upPos.y = upPos.y + 1
	end
	return true
end

local floor = math.floor

local function blockPosToKey(pos)
    return floor(pos.x) .. "," .. floor(pos.y) .. "," .. floor(pos.z)
end

function MapServer:getBlockData(pos)
    local key = blockPosToKey(pos)
    return self.allBlockData[key]
end

function MapServer:getOrCreateBlockData(pos)
    local key = blockPosToKey(pos)
    local data = self.allBlockData[key]
    if data~=nil then
        return data
    end
    data = {}
    self.allBlockData[key] = data
    return data
end

function MapServer:setBlockData(pos, value)
    local key = blockPosToKey(pos)
    self.allBlockData[key] = value
end

function MapServer:triggerRegions(pos, name, context)
	if not pos then
		return
	end
	pos = Lib.tov3(pos):blockPos()
	for _, region in pairs(self.keyRegions) do
		if region.min <= pos and pos <= region.max then
			context.region = region
			context.map = self
			Trigger.CheckTriggersOnly(region.cfg, name, context)
		end
	end
end

function MapServer:addRegion(min, max, cfgName)
    local key = string.format("%s-%d", cfgName, self.lastRegionSubKey + 1)
    local new = Map.addRegion(self, key, min, max, cfgName)
    if not new then
        return
    end
    self.lastRegionSubKey = self.lastRegionSubKey + 1
    if not NEED_SYNC_REGION_INFOS then
        return new
    end
    local regionInfo = {
        id = new.cid,
        min = new.min,
        max = new.max,
    }
    self.newRegionInfos[new.key] = regionInfo
    local packet = {
        pid = "SetRegion",
        mapId = self.id,
        regionInfo = regionInfo,
    }
    self.timers[#self.timers + 1] = World.Timer(1, self.broadcastPacket, self, packet)
    return new
end

function MapServer:removeRegion(key, isCheckTrigger)
    local old = Map.removeRegion(self, key, isCheckTrigger)
    if not old then
        return
    end
    if not NEED_SYNC_REGION_INFOS then
        return old
    end
    local regionInfo = {
        id = old.cid,
    }
    if self.newRegionInfos[old.key] then
        self.newRegionInfos[old.key] = nil
    else
        self.delRegionInfos[old.key] = regionInfo
    end
    local packet = {
        pid = "DelRegion",
        mapId = self.id,
        regionInfo = regionInfo,
    }
    self.timers[#self.timers + 1] = World.Timer(1, self.broadcastPacket, self, packet)
    return old
end

---@param map MapServer
local function checkCloseMap(map)
    if not map or map.static or not map.closeWhenEmpty or next(map.players) then
        return
    end
    World.Timer(1, map.close, map)--cpp need the map obj in this frame
end

function MapServer:leaveObject(object, newMap)
    object:onLeaveMap(self)
    self.objects[object.objID] = nil
    MapEffectMgr:onObjectLeaveMap(object)
    if object.isPlayer then
        self.players[object.platformUserId] = nil
        checkCloseMap(self)
        SceneUIManager.OnPlayerLeaveMap(object)
    end
end

local sendPlayerIconInfosMap = {}
---@param object Object
local function sendPlayerIconInfos(object)
    sendPlayerIconInfosMap[object.map.id] = true
end

local function doSendPlayerIconInfos(mapId)
    local map = World:getMapById(mapId)
    if not map or not map:isValid() then
        return
    end

    local list = {}
    for playerId, player in pairs(map.players or {}) do
        table.insert(list, player.objID)
    end
    map:broadcastPacket({
        pid = "SetMapPlayerIcon",
        list = list
    })
end

local nextSendPlayerIconInfosTime = {}
function MapServer:trySendPlayerIconInfos()
    local now = os.time()
    for mapId in pairs(sendPlayerIconInfosMap) do
        if now >= (nextSendPlayerIconInfosTime[mapId] or 0) then
            sendPlayerIconInfosMap[mapId] = nil
            nextSendPlayerIconInfosTime[mapId] = now + 5
            doSendPlayerIconInfos(mapId)
            break
        end
    end
end

local function sendMapRegionInfos(self, object)
    if not NEED_SYNC_REGION_INFOS then
        return
    end
    local packet = {
        pid = "UpdateRegion",
        mapId = self.id,
        newRegionInfos = self.newRegionInfos,
        delRegionInfos = self.delRegionInfos,
    }
    self.timers[#self.timers + 1] = World.Timer(1, self.broadcastPacket, self, packet)
end

function MapServer:joinObject(object, oldMap)
    local objID = object.objID
    local isPlayer = object.isPlayer
    self.objects[objID] = object
    if isPlayer then
        self.players[object.platformUserId] = object
        if World.cfg.enableSendPlayerIcon ==  nil or World.cfg.enableSendPlayerIcon == true then 
            sendPlayerIconInfos(object)
        end

        if World.cfg.enableRegion ==  nil or World.cfg.enableRegion == true then 
            sendMapRegionInfos(self, object)
        end
    end
    CPUTimer.StartForLua("joinObject--onEnterMap")
    object:onEnterMap(self)
    CPUTimer.Stop()

    MapEffectMgr:onObjectEnterMap(object)
    if isPlayer then
        SceneUIManager.OnPlayerEnterMap(object)
    end
end

function MapServer:broadcastPacket(packet)
    WorldServer.MapBroadcastPacket(self.id, packet)
end

local function sendNodeToTranckers(obj)
    local manager = World.CurWorld:getSceneManager()
    local scene = manager:getOrCreateScene(obj.map.obj)
    scene:addCreateNodeBySpawnObj(obj)
end

local function sendObjToTrackers(obj)
    local trackers = obj:getTrackers()
    if not next(trackers or {}) then 
        return
    end

    local buffListForSameTeam ={}
    local buffListForDifTeam = {}
    if obj.spawnBuffList then 
        obj:spawnBuffList(buffListForSameTeam, true)
        obj:spawnBuffList(buffListForDifTeam, false)
    end

    local sameTeam = {}
    local diffTeam = {}
    for objId in pairs(trackers) do
        local player = World.CurWorld:getEntity(objId)
        if player then
            local team = (obj.getTeam and  obj:getTeam() == player:getTeam()) and sameTeam or diffTeam
            table.insert(team, player.platformUserId)
        end
    end

    local packet = obj:spawnInfo()

    packet.buffList = buffListForSameTeam
    WorldServer.MulticastPacket(packet, sameTeam)

    packet.buffList = buffListForDifTeam
    WorldServer.MulticastPacket(packet, diffTeam)
    sendNodeToTranckers(obj)
end

local nextSyncSpawnTime = {}
function MapServer:syncSpawnPlayer()
    CPUTimer.StartForLua("MapServer:syncSpawnPlayer")
    local now = os.time()
    for objId in pairs(self.newspawnPlayers or {}) do
        if now >= (nextSyncSpawnTime[objId] or 0) then
            nextSyncSpawnTime[objId] = now + 2
            local obj = World.CurWorld:getObject(objId)
            if obj then
                sendObjToTrackers(obj)
                obj:removeTrackers()
            end
            self.newspawnPlayers[objId] = nil
        end
    end
    CPUTimer.Stop()
end

function MapServer:syncSpawnEntity()
    CPUTimer.StartForLua("MapServer:syncSpawnEntity")
    for objId in pairs(self.newspawnEntities or {}) do
        local obj = World.CurWorld:getObject(objId)
        if obj then
            sendObjToTrackers(obj)
            obj:removeTrackers()
        end
        self.newspawnEntities[objId] = nil
    end
    CPUTimer.Stop()
end

function MapServer:close()
    for _, timer in pairs(self.timers) do
        if timer then
            timer()
        end
    end
    MapChunkMgr.saveMapChunkToDB(self)
    MapChunkMgr.clearMapMgrData(self)
    Map.close(self)
end

-- test code -- TODO DEL
-- local misc = require "misc"
-- local now_nanoseconds = misc.now_nanoseconds
-- local function getTime()
--     return now_nanoseconds() / 1000000
-- end
-- test code end

function MapServer:blockChange(chunkPos, blockPos, blockId)
    -- local beginTime = getTime() -- todo del
    MapChunkMgr.setMapChunkChange(self, chunkPos)
    -- print(" MapServer:blockChange(chunkPos, blockPos, blockId) ", getTime() - beginTime) -- todo del
end 