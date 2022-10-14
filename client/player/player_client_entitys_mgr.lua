--------------------------------- client entitys 
--[[
{
    [mapID] = {
        [objID] = {
            propInfo...,
            entity = entityObj,
                entityObj.isClientEntity = true
            map = map
        }
    }
}
--]]
---------------------------------
local mapList = T(World, "mapList")
local World_CurWorld = World.CurWorld
local bm = Blockman.instance

local enableClientEntity = World.cfg.enableClientEntity

--------------------------------- check func
local function checkMap(map)
    return map and map:isValid()
end

local function checkEnable()
    return enableClientEntity
end

local function globalCheck(map)
    if not checkEnable() then
        return false
    end
    if not checkMap(map) then
        perror("handler client entity error!!!!! map error.", map)
        return false
    end

    -- todo ex check
    return true
end
--------------------------------- local func
local function spawnInfoEntity(info, map)
    info.map = map
    if info.name == nil then
        info.name = ""
    end
    Game.EntitySpawn(Me, info, function(entity)
        info.entity = entity
        entity.isClientEntity = true
    end)
end

local function killInfoEntity(info)
    local entity = info.entity
    if entity and entity:isValid() then
        entity:onDead()
        local entityUI = info.entityUI
        if entityUI and next(entityUI) then
            SceneUIManager.RemoveEntityUI(entity.objID, entityUI)
        end
        entity:removeInteractionSphere()

        if bm:viewEntity() and bm:viewEntity().objID == entity.objID then
            bm:setViewEntity(Me)
        end
        entity:destroy("client entity destroy!")
    end
end

--------------------------------- logic func
function Player:createMapClientEntity(map, info)
    if not globalCheck(map) or not info then
        return
    end
    self:createMapClientEntitys({mapId = map.id, entitysInfo = {[1] = info}})
end

function Player:createMapClientEntitys(packet)
    local mapId = packet.mapId
    local entitysInfo = packet.entitysInfo
    if not checkEnable() or not mapId or not entitysInfo then
        return
    end
    local clientEntitys = self:data("clientEntitys") 
    local map_clientEntitys = clientEntitys[mapId]
    if not map_clientEntitys then
        map_clientEntitys = {}
        clientEntitys[mapId] = map_clientEntitys
    end
    for _, info in pairs(entitysInfo) do
        if not info.objID then
            info.objID = World_CurWorld:nextLocalID()
        end
        map_clientEntitys[info.objID] = info
        if mapList[mapId] and mapList[mapId]:isValid() then
            spawnInfoEntity(info, World:getMapById(mapId))
        end
    end
end

function Player:recreateMapClientEntitys(map)
    if not globalCheck(map) then
        return
    end
    local map_clientEntitys = self:data("clientEntitys")[map.id]
    if not map_clientEntitys then
        return
    end
    for _, info in pairs(map_clientEntitys) do
        if not info.entity or not info.entity:isValid() then
            spawnInfoEntity(info, map)
        end
    end
end

function Player:removeMapClientEntity(map, objID, removeValue)
    if not globalCheck(map) or not objID then
        return
    end
    self:removeMapClientEntitys({mapId = map.id, objIDs = {[1] = objID}, removeValue = removeValue})
end

function Player:removeMapClientEntitys(packet)
    local mapId = packet.mapId
    local objIDs = packet.objIDs
    local removeValue = packet.removeValue
    if not checkEnable() or not mapId or not objIDs then
        return
    end
    local map_clientEntitys = self:data("clientEntitys")[mapId]
    if not map_clientEntitys then
        return
    end
    for _, id in pairs(objIDs) do
        local info = map_clientEntitys[id]
        if removeValue then
            map_clientEntitys[id] = nil
        end
        killInfoEntity(info or {})
	end
end

function Player:clearMapClientEntity(packet)
    local mapId = packet.mapId
    if not checkEnable() or not mapId then
        return
    end
    local map_clientEntitys = self:data("clientEntitys")[mapId]
    if not map_clientEntitys then
        return
    end
    if packet.removeValue then
        self:data("clientEntitys")[mapId] = nil
    end
    for _, info in pairs(map_clientEntitys) do
        killInfoEntity(info)
    end
end

function Player:clearAllClientEntity(packet)
    if not checkEnable() then
        return
    end
    for _, map_clientEntitys in pairs(self:data("clientEntitys")) do
        for _, info in pairs(map_clientEntitys) do
            killInfoEntity(info)
        end
    end
    if packet.removeValue then
        self:setData("clientEntitys", {})
    end
end























