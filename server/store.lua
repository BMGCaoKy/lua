require "common.store"

local _store_session = L("_session", 0)

function Store:AllocSession()
    local session = _store_session + 1
    _store_session = session
    return session
end

function Store:operation(player, storeId, itemIndex, targetIndex)
    local item = Store:getStoreItem(storeId, itemIndex)
    if item.status == Store.itemStatus.NOT_FOR_SALE then
        return
    end

    local st = self:checkStatus(storeId, itemIndex, item.status, player)
    if st == Store.itemStatus.NOT_BUY then
        self:requestCanBuy(player, storeId, itemIndex, targetIndex)
    elseif st == Store.itemStatus.NOT_USE then
        self:onItemTakeOn(player, item, targetIndex)
    elseif st == Store.itemStatus.IN_USE then
        self:onItemTakeOff(player, item, targetIndex)
    elseif st == Store.itemStatus.PRIVILEGE then
        local context = { obj1 = player, storeId = storeId, itemIndex = itemIndex, itemName = item.itemName, shopIndex = item.shopIndex }
        Trigger.CheckTriggers(player:cfg(), "STORE_ITEM_OPERATION_PRIVILEGE", context)
    end

end

function Store:checkStatus(storeId, itemIndex, status, player)
    local key = tostring(Bitwise64.Or(Bitwise64.Sl(storeId, 16), itemIndex))
    return player:data("store")[key] or status
end

function Store:onItemTakeOn(player, item , targetIndex)
    local storeItems = player:data("store") or {}
    if not item.isCoexist then
        for key, value in pairs(storeItems) do
            local storeId = Bitwise64.Sr(tonumber(key), 16)
            local itemIndex = Bitwise64.And(tonumber(key), 0xFFFF)
            if storeId == item.storeId and value == Store.itemStatus.IN_USE then
                self:onItemTakeOff(player, Store:getStoreItem(storeId, itemIndex) , targetIndex)
            end
        end
    end
    self:changeItemStatus(player, item, Store.itemStatus.IN_USE, targetIndex,"")
end

function Store:onItemTakeOff(player, item, targetIndex)
    self:changeItemStatus(player, item, Store.itemStatus.NOT_USE, targetIndex,"")
end

local function decodeStore(data)
    local newData = {}
    for k , v in pairs(data) do
        table.insert(newData,{storeId = Bitwise64.Sr(tonumber(k), 16), itemIndex = Bitwise64.And(tonumber(k), 0xFFFF), status = v})
    end
    return newData
end

local function encodeStore(data)
    local newData = {}
    for _ , v in pairs(data) do
        newData[tostring(Bitwise64.Or(Bitwise64.Sl(v.storeId, 16), v.itemIndex))] = v.status
    end
    return newData
end

function Store:changeItemStatus(player, item, status, targetIndex, msg)

    local key = tostring(Bitwise64.Or(Bitwise64.Sl(item.storeId, 16), item.index))
    local context = {obj1 = player, def = true, item = item, status = status, targetIndex = targetIndex or 0, data = decodeStore(player:data("store"))}
    Trigger.CheckTriggers(player:cfg(), "STORE_ITEM_STATUS_CHANGE", context)
    if context.def then
        player:data("store")[key] = status
        self:sendBuyResult(player.platformUserId, item.storeId, item.index, status, msg or "")
    else
        player:setData("store", encodeStore(context.data))
        player:syncStore()
    end
end

function Store:requestCanBuy(player, storeId, itemIndex, targetIndex)
    local item = Store:getStoreItem(storeId, itemIndex)
    local context = {obj1 = player, canBuy = true, itemType = item.itemType, itemName = item.itemName }
    Trigger.CheckTriggers(player:cfg(), "STORE_OPERATION_BUY_ITEM", context)
    if context.canBuy then
        Store:tryBuy(player, storeId, itemIndex, targetIndex)
    end
end

function Store:tryBuy(player, storeId, itemIndex, targetIndex)
    local item = Store:getStoreItem(storeId, itemIndex)
    local ok, msg = self:checkAddBag(item, player)
    if not ok then
        self:sendBuyResult(player.platformUserId, storeId, itemIndex, item.status, msg)
        return
    end
    Store:pay(item, player, storeId, itemIndex, targetIndex)
end

function Store:checkAddBag(item, player)
    local itemType = item.itemType
    if itemType == "Item" then
        if player:tray():add_item(item.itemName, 1, nil, true) then
            return true
        end
    elseif itemType == "Block" then
        if player:tray():add_item("/block", 1, function(_item)
            _item:set_block(item.itemName)
        end, true) then
            return true
        end
    else
        return true
    end
    return false, "gui_str_app_shop_inventory_is_full"
end

function Store:pay(item, player, storeId, itemIndex, targetIndex)

    local function sendBuyResult(result, userId, _storeId, _itemIndex, _targetIndex)
        if result then
            Store:buyResult(userId, _storeId, _itemIndex, _targetIndex)
        else
            Store:sendBuyResult(userId, _storeId, _itemIndex, Store.itemStatus.NOT_BUY,"app_shop_lack_of_money")
        end
    end

    if not self:checkBalance(player, item.coinId, item.price) then
        local event = item.coinId < 3 and "SHOW_GOTO_RECHARGE_UI" or "SHOW_GOTO_APP_SHOP_UI"
        local context = { obj1 = player, def = true}
        Trigger.CheckTriggers(player:cfg(), event, context)
        if context.def then
            Store:sendBuyResult(player.platformUserId, storeId, itemIndex, Store.itemStatus.NOT_BUY,"app_shop_lack_of_money")
        end
        return
    end
    
    if item.coinId < 3 then
        local session = Store:AllocSession()
        local uniqueId = Bitwise64.Or(Bitwise64.Sl(item.storeId, 16), item.index)
        local ary = table.pack(player.platformUserId, storeId, itemIndex, targetIndex)
        self.buyResults[session] = table.pack(sendBuyResult, ary)
        Lib.payMoney(player, uniqueId, item.coinId, item.price, function(isSuccess)
            self.requestBuyResult(player.platformUserId, isSuccess, session)
        end)
    else
        sendBuyResult(Store:checkMoney(player, item), player.platformUserId, storeId, itemIndex, targetIndex)
    end
end

function Store:checkBalance(player, coinId, price)
    local coinName = coinId < 3 and "gDiamonds" or "green_currency"
    local currency = player:getCurrency(coinName)
    return currency and currency.count >= price
end

function Store:checkMoney(player, item)
    local coin = Coin:GetCoinCfg()[1]
    local coinItem = coin and coin.item
    if coinItem and next(coinItem) then
        local total, retItems = player:searchTypeItemsFromBag("tag", coinItem.coinName)
        if total < (item.price) then
            return false
        end
        player:consumeBagItems(item.price, retItems, "buy_store")
        return true
    else
        return player:payCurrency(coin.coinName,item.price, false, false, "buy_store")
    end
end

function Store:buyResult(userId, storeId, itemIndex, targetIndex)
    local player = Game.GetPlayerByUserId(userId)
    if not player then
        return
    end
    local item = Store:getStoreItem(storeId, itemIndex)
    Store:changeItemStatus(player, item, Store.itemStatus.NOT_USE, targetIndex,"gui_buy_goods_successful")
    player:sendPacket({pid = "ShowRewardItemEffect", key = item.itemName, time = nil, count = 1, type = item.dir, time = 20 })

    Trigger.CheckTriggers(player:cfg(), "STORE_BUY_GOODS_SUCCESSFUL", {obj1= player, storeId = storeId, index = itemIndex})

end

function Store:registerBuyEvent(platformUserId, event, session, ...)
    local typ = type(event)
    if typ == "function" then
        self.buyResults[session] = table.pack(event, table.pack(platformUserId, ...))
    else
        local function func(result, userId)
            local player = Game.GetPlayerByUserId(userId)
            if not player then
                return
            end
            Trigger.CheckTriggers(player:cfg(), event, { obj1 = player, result = result })
        end
        local ary = table.pack(platformUserId)
        self.buyResults[session] = table.pack(func, ary)
    end
end

function Store.requestBuyResult(platformUserId, result, session)
    local func, arg = table.unpack(Store.buyResults[session])
    arg = arg or {}
    Store.buyResults[session] = nil
    if func then
        func(result, table.unpack(arg))
    end
end

function Store:sendBuyResult(userId, storeId, itemIndex, status, msg)
    local player = Game.GetPlayerByUserId(userId)
    if not player then
        return
    end
    player:syncStoreItemInfo(storeId, itemIndex, status, nil, msg)
end
