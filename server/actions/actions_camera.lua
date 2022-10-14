local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"

function Actions.ChangeCameraView(data, params, context)
    local player = params.player or params.entity
    if not player or not player.isPlayer then
        return
	end
    local packet ={
        pid = "ChangeCameraView",
        pos = params.pos,
        pitch = params.pitch,
        yaw = params.yaw,
        distance = params.distance,
        smooth = params.smooth
    }
    player:sendPacket(packet)
end

function Actions.ChangeCameraCfg(data, params, context)
    local player = params.player
    if not player or not player.isPlayer then
        return
    end
    local packet ={
        pid = "ChangeCameraCfg",
        config = params.config,
        viewIndex = params.viewIndex,
    }
    player:sendPacket(packet)
end

