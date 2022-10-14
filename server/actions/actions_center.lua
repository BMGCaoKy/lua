local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions

function Actions.SendToCenterPlayer(data, params, context)
    if not ATProxy.isReady then
        return 
    end
    ATProxy.Instance():sendToPlayer(params.id, params.data)
end

function Actions.GotoTargetServer(data, params, context)
    if not ATProxy.isReady then
        return 
    end
    ATProxy.Instance():sendToCenter({
        pid = "GotoTargetServer",
        id = params.userId,
        targetUserId = params.targetUserId
    })
end

function Actions.UpdatePlayerInfo(data, params, context)
    if not ATProxy.isReady then
        return 
    end
    local player = assert(params.player, "no player(UpdatePlayerInfo)")
    ATProxy.Instance():sendToCenter({
        pid = "UpdatePlayerInfo",
        id = player.platformUserId,
        info = player:viewEntityInfo("centerInfo")
    })
end

function Actions.CenterIsReady(data, params, context)
    return ATProxy.isReady
end