--------------------------------- client entitys 
--[[
{
    [mapID] = {
        [objID] = {
            propInfo...,
            boundingBox = xxx,  -- 用来粗略判断entityTouch时是否是真的有touch
            isPlayer = false,
            isClientEntity = true 
            eventCallbackFunc = {
                eventType = function xxxxx
            },
            globalCallbackFunc = function xxxxx
        }
    }
}
--]]
-- TODO 暂时假定所有客户端entity都不会动，暂未处理会动的。
-- TODO 客户端entity与技能/导弹的交互。
--------------------------------- 
local type = type
local World_CurWorld = World.CurWorld
local Entity_GetCfg = Entity.GetCfg
local Lib_copy = Lib.copy
local Lib_isPosInRegion = Lib.isPosInRegion

local enableClientEntity = World.cfg.enableClientEntity
local event = {
    TOUCH = "EVENT_TOUCH"
}

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

--------------------------------- packet check func
local function getLogicInfo(self, packet)
    if not checkEnable() then
        return false
    end
    local mapId, clientEntityObjId = packet.mapId, packet.clientEntityObjId
    if not mapId or not clientEntityObjId or mapId~=(self.map and self.map.id or -1) then
        return false
    end
    local map_clientEntitys = self:data("clientEntitys")[mapId]
    if not map_clientEntitys then
        return false
    end
    local clientEntityInfo = map_clientEntitys[clientEntityObjId]
    if not clientEntityInfo then
        return false
    end
    return clientEntityInfo, mapId, clientEntityObjId
end

local function getCallbackFunc(clientEntityInfo, eventType)
    local eventCallbackFunc = clientEntityInfo.eventCallbackFunc
    if not eventCallbackFunc then
        return false
    end
    return eventCallbackFunc[eventType]
end

--------------------------------- local func
--[[ 
-- propInfo 可选属性
fullName, -- 必须 
propInfo.pos, -- 建议要。不配默认是{x = 0,  y = 0, z = 0}。
actorName, -- 建议要。默认是boy.actor
name, 
rotationYaw, 
rotationPitch, 
rotationRoll, 
skin, 
curHp
curVp
headText, 
entityUI, 
boundingBox, 物体在场景中的碰撞范围 {[1]=scale,[2]=min,[3]=max}。不配默认是位置+碰撞盒形成的范围。

eventCallbackFunc = 
{
    [EVENT_TOUCH] = function(mapId, objID, fullName)
}
globalCallbackFunc = function(eventType, mapId, objID, fullName)
]]
local function buildClientEntityInfo(propInfo, cfg)
    local ret = Lib_copy(propInfo)
    if not ret.pos then
        ret.pos = {x = 0,y = 0,z = 0}
    end
    if not ret.boundingBox then
        if cfg.boundingVolume then
            ret.boundingBox = CollisionUtil.parseBoundingVolumn2Box(ret.pos, cfg.boundingVolume)
        else
            ret.boundingBox = {[1] = 1, [2] = ret.pos, [3] = ret.pos}
        end
    end
    if not ret.cfgName then
        ret.cfgName = cfg.fullName
    end
    if not ret.actorName then
        ret.actorName = "boy.actor"
    end
    if not ret.curHp then
        ret.curHp = 9999999
    end
    ret.isPlayer = false
    ret.isClientEntity = true
    return ret
end

--------------------------------- logic func
function Player:createMapClientEntity(map, entityInfo, globalCallbackFunc) 
    self:createMapClientEntitys(map, {[1] = entityInfo}, globalCallbackFunc)
end

function Player:createMapClientEntitys(map, entitysInfo, globalCallbackFunc) 
    if not globalCheck(map) then
        return
    end
    if not entitysInfo then
        print("create client entity but get bad value : empty entitysInfo ")
        return
    end
    local clientEntitys = self:data("clientEntitys") 
    local mapId = map.id
    local map_clientEntitys = clientEntitys[mapId]
    if not map_clientEntitys then
        map_clientEntitys = {}
        clientEntitys[mapId] = map_clientEntitys
    end
    local packet_entitysInfo = {}
    local temp_eventCallbackFuncs = {}
	for key, info in pairs(entitysInfo) do 
        assert(info.fullName, "want create client entity, but not fullName. key = ", key, ", infoValue = ", Lib.v2s(info))
		local cfg = Entity_GetCfg(info.fullName) 
        local temp = buildClientEntityInfo(info, cfg)
		local objID = World_CurWorld:nextObjectID() 
        temp.objID = objID
        temp_eventCallbackFuncs[objID] = temp.eventCallbackFunc
        temp.eventCallbackFunc = nil
		map_clientEntitys[objID] = temp
		packet_entitysInfo[objID] = temp 
	end 
	self:sendPacket({ 
        pid = "CreateMapClientEntitys", 
        mapId = mapId,
		entitysInfo = packet_entitysInfo,
    }) 
    for objID, func in pairs(temp_eventCallbackFuncs) do
        map_clientEntitys[objID].eventCallbackFunc = func
        map_clientEntitys[objID].globalCallbackFunc = globalCallbackFunc
    end
end 
 
function Player:removeMapClientEntity(map, objID, removeValue) 
    self:removeMapClientEntitys(map, {[1] = objID}, removeValue) 
end

function Player:removeMapClientEntitys(map, objIDs, removeValue) 
    if not globalCheck(map) then
        return
    end
    if not objIDs then
        print("remove client entity but get bad value : empty objIDs")
        return
    end
    local map_clientEntitys = self:data("clientEntitys")[map.id]
    if not map_clientEntitys then
        return
    end
    removeValue = not (removeValue == false)
    if removeValue then
        for _, id in pairs(objIDs) do
            map_clientEntitys[id] = nil
        end
    end
	self:sendPacket({
        pid = "RemoveMapClientEntitys",
        mapId = map.id,
        objIDs = objIDs,
        removeValue = removeValue
	})
end
 
function Player:clearMapClientEntity(map, removeValue) 
    if not globalCheck(map) then
        return
    end
    removeValue = not (removeValue == false)
    if removeValue then
        self:data("clientEntitys")[map.id] = nil
    end
	self:sendPacket({
        pid = "ClearMapClientEntity",
        mapId = map.id,
        removeValue = removeValue
	})
end

function Player:clearAllClientEntity(removeValue) 
    if not checkEnable() then
        return
    end
    removeValue = not (removeValue == false)
    if removeValue then
        self:setData("clientEntitys", {})
    end
	self:sendPacket({
        pid = "ClearAllClientEntity",
        removeValue = removeValue
	})
end

--------------------------------- client packet logic func
function Player:checkClientEntityInLegalRange(packet)
    local clientEntityInfo = getLogicInfo(self, packet)
    if not clientEntityInfo then
        return false
    end
    local rangeMin, rangeMax = clientEntityInfo.boundingBox[2], clientEntityInfo.boundingBox[3]
    local maxImcRange = self:cfg().posSyncDelay * self:prop().moveSpeed
    local selfBoundBox = self:getBoundingBox()
    local v3Range = selfBoundBox[3] - selfBoundBox[2]
    if not Lib_isPosInRegion({min = {x = rangeMin.x - maxImcRange - v3Range.x, y = rangeMin.y - maxImcRange - v3Range.y, z = rangeMin.z - maxImcRange - v3Range.z}, 
                                    max = {x = rangeMax.x + maxImcRange + v3Range.x, y = rangeMax.y + maxImcRange + v3Range.y, z = rangeMax.z + maxImcRange + v3Range.z}}, self:getPosition()) then
        return false
    end
    -- todo ex check

    return true
end

function Player:touchClientEntity(packet)
    local clientEntityInfo, mapId, clientEntityObjId = getLogicInfo(self, packet)
    if not clientEntityInfo then
        return false
    end
    local fullName = clientEntityInfo.fullName
    local globalCallbackFunc = clientEntityInfo.globalCallbackFunc
    local eventCallbackFunc = getCallbackFunc(clientEntityInfo, event.TOUCH)
    if eventCallbackFunc then
        eventCallbackFunc(mapId, clientEntityObjId, fullName)
    end
    if globalCallbackFunc then
        clientEntityInfo.globalCallbackFunc(event.TOUCH, mapId, clientEntityObjId, fullName)
    end
end



















