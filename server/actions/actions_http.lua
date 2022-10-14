local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions

function Actions.LoadPlayerAppDress(data, params, context)
    local url = string.format("%s/decoration/api/v1/inner/game/user/decoration", AsyncProcess.ServerHttpHost)
    local args = {
        {"userId", params.player.platformUserId},
        {"engineVersion", EngineVersionSetting:getEngineVersion()},
    }

    AsyncProcess.HttpRequest("GET", url, args, function (response)
        if response.code == 1 and params.player:isValid() then
            Trigger.CheckTriggers(params.player:cfg(), params.event, { obj1 = params.player, response = response.data })
        end
    end, params.body)
end

function Actions.BuyGoods(data, params, context)
    assert(params.coinId <= 2, string.format("Actions.BuyGoods:This type of currency cannot be defined:%d", params.coinId))
    Lib.payMoney(params.player, params.uniqueId, params.coinId, params.price, function(isSucceed)
        Trigger.CheckTriggers(params.player:cfg(), params.event,
                { userId = params.player.platformUserId, isSucceed = isSucceed, response = params })
    end)
end
