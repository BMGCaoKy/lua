---
---支付助手：
---对外开发消耗金魔方接口，默认的确认支付弹窗
---
local payHelper = {}

local awaitConfirmNote = L("awaitConfirmNote", {})
local cancelPaymentCallBack = L("cancelPaymentCallBack", {})

---支付魔方
---@param uniqueId number 标识商品的唯一id
---@param price number 价格
---@param callback function 购买是否成功的回调
function payHelper:payMoney(player, uniqueId, price, callBack)
    if price <= 0 then
        print("The price paid must be greater than 0 !")
        return false
    end
    if not player or not player.isPlayer or not player:isValid() then
        print("PayHelper.payMoney: not player !")
        return false
    end
    local platformId = player.platformUserId
    local call = awaitConfirmNote[platformId]
    if call and World.Now() < call.endTime then
        print("There is a payment order waiting to be confirmed !")
        return false
    end
    call = {
        func = callBack,
        uniqueId = tonumber(uniqueId) or 0,
        price = price,
        endTime = World.Now() + 200, --防止重复弹窗时间，10s
    }
    awaitConfirmNote[platformId] = call

    -- 提示支付弹窗
    player:sendPacket({
        pid = "PromptPayment",
        price = price
    })
    return true
end

---注册取消支付订单时触发的回调函数
function payHelper:registerCancelCallBack(player, callBack)
    if not player or not player.isPlayer or not player:isValid() then
        return
    end
    if not callBack or type(callBack) ~= "function" then
        return
    end
    cancelPaymentCallBack[player.platformUserId] = callBack
end

function payHelper:confirmedPayMoney(player)
    -- 确认支付
    if not player or not player:isValid() then
        print("Player does not exist !")
        return
    end
    local platformUserId = player.platformUserId
    local call = awaitConfirmNote[platformUserId]
    if not call then
        print("Payment order has been processed !")
        return
    end
    awaitConfirmNote[platformUserId] = nil
    cancelPaymentCallBack[platformUserId] = nil
    Lib.payMoney(player, call.uniqueId, 0, call.price, call.func)
end

function payHelper:cancelPayMoney(player)
    -- 取消支付
    if not player or not player:isValid() then
        print("Player does not exist !")
        return
    end
    local platformUserId = player.platformUserId
    local call = awaitConfirmNote[platformUserId]
    if not call then
        print("Payment order has been paocessed !")
        return
    end
    awaitConfirmNote[platformUserId] = nil
    -- 如果注册取消订单回调函数就触发
    local cancelCallBack = cancelPaymentCallBack[platformUserId]
    if not cancelCallBack then
        return
    end
    cancelPaymentCallBack[platformUserId] = nil
    cancelCallBack()
end

local engine_module = require "common.engine_module"
engine_module.insertModule("PayHelper", payHelper)

RETURN(payHelper)