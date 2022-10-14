local setting = require "common.setting"
local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions

function Actions.IsWatch(data, params, context)
    ---是否为跟随进入模式
    local player = params.player
    if not player or not player:isValid() or not player.isPlayer then
        return
    end
    return player:isWatch()
end