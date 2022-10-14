local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

function Actions.Table(node, params, context)
	return params
end

function Actions.UpdateTeamInfo(data, params, context)
    local packet = {
        pid = "UpdateTeamInfo",
        teamID = params.teamId,
        info = {
            state = params.state
        }
    }
    WorldServer.BroadcastPacket(packet)
end

function Actions.GenerateScore(data, params, context)
    if params.score <= 40 then
        return math.ceil(10 + 0.25 * params.score)
    elseif params.score <= 70 then
        return math.ceil(20 + 0.33 * (params.score - 40))
    else
        return math.ceil(50 + 0.5 * (params.score - 70))
    end
end