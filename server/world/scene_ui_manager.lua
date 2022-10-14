local self = SceneUIManager
local mapUI = T(self, "mapUI", {})
local mapUIKey = T(self, "mapUIKey", {})

function SceneUIManager.AddSceneUI(map, key, name, width, height, rotate, position, openParams)
    assert(not mapUIKey[key], key)
    local mapId = map.id
    mapUIKey[key] = "map" .. mapId
    local uiData = {
        uiCfg = {
            name = name,
            width = width,
            height = height,
            rotate = rotate,
            position = position,
        },
        openParams = openParams,
    }
    local curMapUI = mapUI[mapId] or {}
    curMapUI[key] = uiData
    mapUI[mapId] = curMapUI
    map:broadcastPacket({
        pid = "AddSceneUI",
        key = key,
        mapId = mapId,
        uiData = uiData,
    })
end

function SceneUIManager.RemoveSceneUI(map, key)
    if not mapUIKey[key] then
        return
    end
    local mapId = map.id
    local curMapUI = mapUI[mapId]
    if not curMapUI or not curMapUI[key] then
        return
    end
    mapUIKey[key] = nil
    curMapUI[key] = nil
    map:broadcastPacket({
        pid = "RemoveSceneUI",
        mapId = mapId,
        key = key,
    })
end

function SceneUIManager.RefreshSceneUI(map, key, openParams)
    local mapId = map.id
    assert(mapUIKey[key], key)
    local curMapUI = assert(mapUI[mapId], mapId)
    local uiData = assert(curMapUI[key], key)
    uiData["openParams"] = openParams
    map:broadcastPacket({
        pid = "RefreshSceneUI",
        mapId = mapId,
        key = key,
        openParams = openParams,
    })
end

local function sendAllSceneUI(player, pid)
    local map = player.map
    local mapId = map.id
    local curMapUI = mapUI[mapId]
    if not curMapUI then
        return
    end
    local packet = {
        pid = pid,
        mapId = mapId,
        curMapUI = curMapUI,
    }
    player:timer(1, player.sendPacket, player, packet)
end

function SceneUIManager.OnPlayerEnterMap(player)
    sendAllSceneUI(player, "ShowAllSceneUI")
end

function SceneUIManager.OnPlayerLeaveMap(player)
    sendAllSceneUI(player, "CloseAllSceneUI")  
end

function SceneUIManager.AddEntitySceneUI(objID, key, name, width, height, rotate, position, openParams)
    assert(not mapUIKey[key], key)
    local entity = assert(World.CurWorld:getEntity(objID), objID)
    local entityUI = entity:data("entityUI")
    local sceneUI = entityUI.sceneUI or {}
    assert(not sceneUI[key], key)
    local uiData = {
        uiCfg = {
            name = name,
            width = width,
            height = height,
            rotate = rotate,
            position = position,
        },
        openParams = openParams,
    }
    mapUIKey[key] = "entity-" .. objID
    sceneUI[key] = uiData
    entityUI.sceneUI = sceneUI
    entity:sendPacketToTracking({
        pid = "AddEntitySceneUI",
        objID = objID,
        key = key,
        uiData = uiData,
    }, true)
end

function SceneUIManager.RemoveEntitySceneUI(objID, key)
    if not mapUIKey[key] then
        return
    end
    local entity = assert(World.CurWorld:getEntity(objID), objID)
    local sceneUI = entity:data("entityUI").sceneUI
    if not sceneUI or not sceneUI[key] then
        return
    end
    mapUIKey[key] = nil
    sceneUI[key] = nil
    entity:sendPacketToTracking({
        pid = "RemoveEntitySceneUI",
        objID = objID,
        key = key,
    }, true)
end

function SceneUIManager.RefreshEntitySceneUI(objID, key, openParams)
    assert(mapUIKey[key], key)
    local entity = assert(World.CurWorld:getEntity(objID), objID)
    local sceneUI = entity:data("entityUI").sceneUI
    local uiData = assert(sceneUI[key], key)
    uiData["openParams"] = openParams
    entity:sendPacketToTracking({
        pid = "RefreshEntitySceneUI",
        objID = objID,
        key = key,
        openParams = openParams,
    }, true)
end

function SceneUIManager.AddEntityHeadUI(objID, name, width, height, openParams)
    local entity = assert(World.CurWorld:getEntity(objID), objID)
    local entityUI = entity:data("entityUI")
    local uiData = {
        uiCfg = {
            name = name,
            width = width,
            height = height,
        },
        openParams = openParams,
    }
    entityUI.headUI = uiData
    entity:sendPacketToTracking({
        pid = "AddEntityHeadUI",
        objID = objID,
        uiData = uiData,
    }, true)
end

function SceneUIManager.RemoveEntityHeadUI(objID)
    local entity = assert(World.CurWorld:getEntity(objID), objID)
    local entityUI = entity:data("entityUI")
    if not entityUI.headUI then
        return
    end
    entityUI.headUI = nil
    entity:sendPacketToTracking({
        pid = "RemoveEntityHeadUI",
        objID = objID,
    }, true)
end

function SceneUIManager.RefreshEntityHeadUI(objID, openParams)
    local entity = assert(World.CurWorld:getEntity(objID), objID)
    local entityUI = entity:data("entityUI")
    local headUI = assert(entityUI.headUI)
    headUI["openParams"] = openParams
    entity:sendPacketToTracking({
        pid = "RefreshEntityHeadUI",
        objID = objID,
        openParams = openParams,
    }, true)
end

RETURN(SceneUIManager)
