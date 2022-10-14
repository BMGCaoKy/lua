local setting = require "common.setting"
local PluginTrigger = T(Trigger, "PluginTrigger") 
local M = L("food_base", Lib.derive(PluginTrigger))

function M:USE_ITEM(context)
    local player = context.obj1
    local itemCfg = setting:fetch("item", context.itemName)
    local useAddBuffLists = itemCfg["useAddBuffList"]
    local foodBuffName = itemCfg["food_buff"]
    local buffContinueTime = itemCfg["buffContinueTime"] or 0
    local recoveHpValue = itemCfg["recoverHpStep"] or 0
    local recoveVpValue = itemCfg["recoverVpStep"] or 0

    self:AddEntityHp({entity = player, step = recoveHpValue})
    self:AddEntityVp({entity = player, step = recoveVpValue})
    player:setVar("buffContinueTime", buffContinueTime)
    if foodBuffName then
        player:addBuff(foodBuffName, buffContinueTime)
    end
    if useAddBuffLists then
        for _, buffName in pairs(useAddBuffLists) do
            self:CallTrigger({event="PLAYER_ADD_BUFF_OR_ATTACH", obj1= player, buffName = buffName})
        end
    end

end

return RETURN(M)