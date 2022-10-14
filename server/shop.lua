require "common.shop"

local _session = L("_session", 0)

local limitType = {
    COMMON = 0,
    PERSONAL = 1
}

function Shop:AllocSession()
    local session = _session + 1
    _session = session
    return session
end

function Shop:getGoodsData(player)
	return T(player.vars, "goodsInfo")
end

function Shop:requestCanBuy(itemindex, player, count)
    local shop = assert(self.shops[itemindex], itemindex)
    local context = {
        obj1 = player,
        canBuy = true,
        itemtype = shop.itemType,
        itemName = shop.itemName
    }
    Trigger.CheckTriggers(player:cfg(), "PREPROCESS_BUY_APPSHOP", context)
    if not context.canBuy then
        return
    end
    Shop:tryBuyShop(itemindex, player, count)
end

function Shop:checkLimit(shop, player, count)
    local limit = shop.limit
    if shop.limit == -1 then
        return true, "gui_buy_goods_successful", limit
    end
    if shop.limitType == limitType.COMMON and limit >= count then
        limit = limit - count
        return true, "gui_buy_goods_successful", limit
    elseif shop.limitType == limitType.PERSONAL and limit >= count then
        player.vars.goodsLimitTime = os.time()
        local goodsInfo = Shop:getGoodsData(player)
        limit = limit - T(goodsInfo, shop.index, 0)
        if limit >= count then
            goodsInfo[shop.index] = goodsInfo[shop.index] + count
            return true, "gui_buy_goods_successful", limit
        end
    end
    player:sendPacket({
        pid = "ShopGoodIsLimit",
        index = shop.index,
        shopType = "shop",
    })
    return false, "gui_str_app_shop_insufficient_inventory", limit
end

function Shop:checkAddBag(shop, player, count)
    local itemType = shop.itemType
    if itemType == "Item" then
        if player:tray():add_item(shop.itemName, shop.num * count, nil, true) then
            return true
        end
    elseif itemType == "Block" then
        if player:tray():add_item("/block", shop.num * count, function(_item)
            _item:set_block(shop.itemName)
        end, true) then
            return true
        end
    else
        return true
    end
    return false, "gui_str_app_shop_inventory_is_full"
end

function Shop:checkMoney(shop, player, count)
    local coin = Coin:getCoin(Coin:coinNameByCoinId(shop.coinId))
    local item = coin and coin.item
    if item and next(item) then
        return Coin:consumeCoin(coin.coinName, player, shop.price * count)
    else
        return player:payCurrency(coin.coinName, shop.price * count, false, false, "buy_appshop")
    end
end

function Shop:buy(shop, player, count, limit)
    local function sendBuyResult(result, limit, failMsg)
        if result then
            local _limit, msg, succeed = Shop:buyShop(shop, player, count)
            self:sendBuyResult(player, shop.index, _limit, msg, succeed)
        else
            self:resetLimit(player, shop, count, limit)
            self:sendBuyResult(player, shop.index, limit, failMsg)
        end
    end
    if shop.coinId == 0 then
        local session = Shop:AllocSession()
        Shop:registerBuyEvent(player.platformUserId, sendBuyResult, session, limit, "app_shop_ack_of_money")
        local cost = shop.price * count
        if cost <= 0 then
            self.requestBuyResult(player.platformUserId, true, session)
        else
            Lib.payMoney(player, shop.index, shop.coinId, cost, function(isSuccess)
                self.requestBuyResult(player.platformUserId, isSuccess, session)
            end,count)
        end
    else
        sendBuyResult(Shop:checkMoney(shop, player, count), limit, "game_shop_ack_of_money")
    end
end

function Shop:buyShop(shop, player, count)
	local succeed = true
    local limit = shop.limit
    local context = { obj1 = player,itemType = shop.itemType, itemName = shop.itemName, num = shop.num * count , addItem = true, msg = "gui_buy_goods_successful", shop = shop, limit = limit}
    Trigger.CheckTriggers(player:cfg(), "ENTITY_BUY_APPSTOP", context)
    if not context.addItem then
        return context.limit, context.msg, succeed
    end
    if player then
        if shop.itemType == "Item" then
            player:tray():add_item(shop.itemName, shop.num * count, nil, false, "buy_appshop")
        elseif shop.itemType == "Block" then
            player:tray():add_item("/block", shop.num * count, function(item)
                item:set_block(shop.itemName)
            end, false, "buy_appshop")
        else
            player:addCurrency(shop.itemName, shop.num * count, "buy_appshop")
        end
    end
    if shop.limit ~= -1 then
        if shop.limitType == limitType.PERSONAL then
            local goodsInfo = Shop:getGoodsData(player)
            limit = limit - (goodsInfo[shop.index] or 0)
        else
            limit = math.max(shop.limit - count, 0)
            shop.limit = limit
        end
    end
    return limit, context.msg, succeed
end

function Shop:tryBuyShop(index, player, count)
    local shop = assert(self.shops[index], index)
    local ok, msg, limit = self:checkLimit(shop, player, count)
    if not ok then
        self:sendBuyResult(player, index, limit, msg)
        return
    end
    ok, msg = self:checkAddBag(shop, player, count)
    if not ok then
        self:resetLimit(player, shop, count, limit)
        self:sendBuyResult(player, index, limit, msg)
        return
    end
    Shop:buy(shop, player, count, limit)
end

function Shop:registerBuyEvent(platformUserId, event, session, ...)
    local typ = type(event)
    if typ == "function" then
        local ary = table.pack(...)
        self.buyResults[session] = table.pack(event, ary)
    else
        local function func(result, userId)
            local player = Game.GetPlayerByUserId(userId)
            if not player then
                return
            end
            Trigger.CheckTriggers(player:cfg(), event, { obj1 = player, result = result })
            Trigger.CheckTriggers(nil, event, { obj1 = player, result = result })
        end
        local ary = table.pack(platformUserId)
        self.buyResults[session] = table.pack(func, ary)
    end
end

function Shop.requestBuyResult(platformUserId, result, session)
    local func, arg = table.unpack(Shop.buyResults[session])
    arg = arg or {}
    Shop.buyResults[session] = nil
    if func then
        func(result, table.unpack(arg))
    end
end

function Shop:sendBuyResult(player, itemIndex, limit, msg, succeed, forceUpdate)
    player:sendPacket({
        pid = "SendBuyShopResult",
        itemIndex = itemIndex,
        limit = limit,
        msg = msg,
        succeed = succeed or false,
        forceUpdate = forceUpdate
    })
	succeed = succeed or false
	Trigger.CheckTriggers(player:cfg(), "ENTITY_BUY_RESULT", { obj1 = player, itemIndex = itemIndex, msg = msg , succeed = succeed})
end

function Shop:resetLimit(player, shop, count, limit)
    if shop.limit == -1 then
        return
    end
    if shop.limitType == limitType.COMMON and limit >= count then
        shop.limit = limit
    elseif shop.limitType == limitType.PERSONAL then
        local goodsInfo = T(player.vars, "goodsInfo")
        T(goodsInfo, shop.index, 0)
        goodsInfo[shop.index] = goodsInfo[shop.index] - count
    end
end

function Shop:resetBuyCountByIndex(player, index)
    local shop = self.shops[index]
    if not shop then return end 

    if shop.limitType == limitType.PERSONAL then
        local goodsInfo = T(player.vars, "goodsInfo")
        goodsInfo[shop.index] = nil
        Shop:sendBuyResult(player, index, shop.limit, "", false, true)
    end
end