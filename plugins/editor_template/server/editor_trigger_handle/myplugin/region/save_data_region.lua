local PluginTrigger = T(Trigger, "PluginTrigger") 
local M = L("save_data_region", Lib.derive(PluginTrigger))

local function addBuff(player, entityID, buffName, time)
    player:sendPacket({
        pid = "AddBuff",
        name = buffName,
        objID = entityID,
        time = time
    })
end

local function changeActor(player, entityID, name)
	local packet = {
		pid = "ChangeActor",
		objID = entityID,
		name = name,
    }
	player:sendPacket(packet)
end

function M:REGION_ENTER(context)
    local entity = context.obj1
    local region = context.region
    if not entity or not entity:isValid() or not entity.isPlayer then
        return
    end
    if Game.GetState() ~= "GAME_GO" then
        return
    end
    local owner = self:getVar(region, "owner")
    local savePos = Lib.v3add(owner:getPosition(), {x = 1, y = 1, z = 0})
    local posKey = savePos.x .. "," .. savePos.y .. "," .. savePos.z
    local savePointMap = self:getVar(entity, "savePoint") or {}
    if savePointMap[posKey] then
        return
    end
    addBuff(entity, entity.objID, "myplugin/save_point_sound", 30)
    addBuff(entity, owner.objID, "myplugin/save_pos", 60)
    entity:setRebirthPos(savePos)
    savePointMap[posKey] = true
    self:setVar(entity, "savePoint", savePointMap)
    changeActor(entity, owner.objID, owner:cfg().changeActorName)
end

print("test")
return RETURN(M)