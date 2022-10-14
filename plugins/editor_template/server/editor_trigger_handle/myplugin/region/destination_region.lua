local PluginTrigger = T(Trigger, "PluginTrigger") 
local M = L("destination_region", Lib.derive(PluginTrigger))

local function addBuff(player, entityID, buffName, time)
    player:sendPacket({
        pid = "AddBuff",
        name = buffName,
        objID = entityID,
        time = time
    })
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
    addBuff(entity, entity.objID, "myplugin/end_point_sound", 30)
    self:PlayAction({
        entity = owner, 
        actionName = "run", 
        actionTime = 28,
        target = entity
    })

    self:CallTrigger({
        event = "GO_TO_NEXT_MAP", 
        object = entity
    })
end

return RETURN(M)