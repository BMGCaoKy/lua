local MapEffectMgr = L("MapEffectMgr", {})
local ADD_EFFECT        =       1
local DEL_EFFECT        =       2



MapEffectMgr.effectName2Id = {}
MapEffectMgr.effectId = 1
MapEffectMgr.effects = {}  -- [map.id] -> effectInfos
MapEffectMgr.sendPacketTimer = {}
local function getKey(pos, effectName)
    return pos.x .. "," .. pos.y .. "," .. pos.z .. effectName
end

local function sendEffectPacket(player, effectPackArray, status)
    local effectName2Id = MapEffectMgr.effectName2Id
    local id = MapEffectMgr.effectId
    for key, info in pairs(effectPackArray) do
        local effectName = info.effectName
        if not effectName2Id[effectName] then
            effectName2Id[effectName] = id
            info.id = id
            MapEffectMgr.effectId = id + 1
        else
            local playerEffectNameId = player:data("effectNameId")
            -- 判断客户端有没有缓冲effectName,没有就发送完整的,有只发送对应的id
            info.id = playerEffectNameId[effectName]
            if not info.id then
                playerEffectNameId[effectName] = effectName2Id[effectName]
                info.id = effectName2Id[effectName]
            else
                info.effectName = nil
            end
        end
    end
    local mapID = player.map.id
    if status == ADD_EFFECT then
        player:sendPacket({
            pid = "playMapEffect",
            packet = effectPackArray,
            mapID = mapID
        })
    else
        player:sendPacket({
            pid = "delMapEffect",
            packet = effectPackArray,
            mapID = mapID
        })
    end

end

local function updatePlayerEffect(player, effectPackArray, status)
    sendEffectPacket(player, Lib.copy(effectPackArray), status)
end

function MapEffectMgr:getMapEffects(map)
    local mapID = map.id
    if not mapID then
        return {}
    end
    local effects = self.effects[mapID]
    if not effects then
        effects = {}
        self.effects[mapID] = effects
    end
    return effects
end

function MapEffectMgr:sendEffectList(player)
    if not player or not player.isPlayer or not player:isValid() then
        return
    end
    local map = player.map
    if not map then
        return
    end 
    local effects = self:getMapEffects(map)
    local effectPackArray = {}
    for k , effectData in pairs(effects) do
        local time = effectData.time -  World.CurWorld:getTickCount()
        if time > 0 or effectData.time == -1 then
            table.insert(effectPackArray, {
                effectName = effectData.effectName,
                time = effectData.time,
                pos = effectData.pos,
            })
        else
            effects[k] = nil
        end
    end 
    if #effectPackArray == 0 then
        return
    end
    updatePlayerEffect(player, effectPackArray, ADD_EFFECT)
end

function MapEffectMgr:addEffect(map, pos, effectName, time)
    if not map then
        return
    end

    -- 储存map当前的特效在服务器
    local effects = self:getMapEffects(map)
    local key = getKey(pos, effectName)
    local saveEffectTab = {
        pos = pos,
        effectName = effectName,
        time = time ~= -1 and (time + World.CurWorld:getTickCount()) or time
    }
    effects[key] = saveEffectTab
    local allPlayer = map.players or {}
    -- 修改玩家的特效信息增量式
    local effectPackArray = {
        {
            pos = pos,
            effectName = effectName,
            time = time,
        }
    }
    for _, player in pairs(allPlayer) do
        updatePlayerEffect(player, effectPackArray, ADD_EFFECT)
    end
end

function MapEffectMgr:delEffect(map, pos, effectName)
    if not map then
        return
    end
    pos = {
        x = pos.x,
        y = pos.y,
        z = pos.z
    }
    local key = getKey(pos, effectName)
    local effects = self:getMapEffects(map)
    if not effects[key] then
        return
    end
    effects[key] = nil
    local effectPackArray = {
        {
            pos = pos,
            effectName = effectName,
        }
    }
    local allPlayer = map.players or {}
    for _, player in pairs(allPlayer) do
        updatePlayerEffect(player, effectPackArray, DEL_EFFECT)
    end
end

function MapEffectMgr:onObjectEnterMap(object)
    if not object.isPlayer then
        return
    end 
    local mapEffectTimer = object:data("main").mapEffectTimer
    if mapEffectTimer then
        mapEffectTimer()
        object:data("main").mapEffectTimer = nil
    end
    object:data("main").mapEffectTimer = object:timer(5, function()
        self:sendEffectList(object)
    end)
end

function MapEffectMgr:onObjectLeaveMap(object)
    if not object.isPlayer then
        return
    end
    local mapEffectTimer = object:data("main").mapEffectTimer
    if mapEffectTimer then
        mapEffectTimer()
        object:data("main").mapEffectTimer = nil
    end
end

RETURN(MapEffectMgr)
