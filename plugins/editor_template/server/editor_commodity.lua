local limitType = {"person", "team"}
Commodity.limitData = {person = {}, team = {}}
function Commodity:limit(commodity, player, check)
    local itemIndex = commodity.index
    local lt = commodity.limit > 0 and limitType[commodity.limitType]
    if not lt then
        return true
    end
    local limitData = self.limitData[lt]
    local data = T(limitData, player.platformUserId)
    local teamId = player:getValue("teamId")
    if lt == "team" and teamId ~= 0 then
        data = T(limitData, teamId)
    end
    if not check then
        data[itemIndex] = (data[itemIndex] or 0) + 1
    end
    local limit = commodity.limit
    return (not limit) and true or (limit > (data[itemIndex] or 0))
end

function Commodity:requestCanBuy(itemIndex, player)
    local commodity = self:GetCommodity(itemIndex)
    local itemName = commodity.itemName
    local block = commodity.meta or commodity.blockName
    if not player:data("tray"):add_item(itemName, commodity.num, itemName == "/block" and function(_item)
        if tonumber(block) then
            _item:set_block_id(block)
        else
            _item:set_block(block)
        end
    end, true) then
        self:sendBuyResult(player, "gui_str_app_shop_inventory_is_full", itemIndex, false)
        return false
    end
    if  commodity.limitType and not self:limit(commodity, player, true) then
        self:sendBuyResult(player, "insufficient_inventory", itemIndex, false)
        return
    end
    local result = false
    local function sendResult(result)
        if result then
            self:sendBuyResult(player, self:buyShop(commodity, player), itemIndex, true)
        else
            self:sendBuyResult(player, "ack_of_money", itemIndex, false)
        end
    end
    if commodity.coinName == "gDiamonds" then
        if World.CurWorld.isEditorEnvironment then
            player:sendTip(3, "can_not_buy_in_test", 40)
            return
        end
        local wallet = player:data("wallet") or {}
        local gDiamonds = wallet.gDiamonds and wallet.gDiamonds.count or 0
        if commodity.price > gDiamonds then
            self:sendBuyResult(player, "ack_of_money", itemIndex, false)
        else
            local session = Shop:AllocSession()
            Shop:registerBuyEvent(player.platformUserId, sendResult, session)
            AsyncProcess.BuyGoods(player.platformUserId, 1, 0, commodity.price, session, Shop.requestBuyResult)
        end
        return
    end
    sendResult(self:enoughMoney(commodity, player))
    if commodity.limitType and not self:limit(commodity, player, true) then
        -- self:sendBuyResult(player, "insufficient_inventory", itemIndex, false)
        player:sendPacket({
            pid = "SendBuyCommodityShopIsLimit",
            index = itemIndex
        })
    end
end

function Commodity:buyShop(item, player)
    self:limit(item, player)
    local itemName = item.itemName
    local context = {
        itemName = itemName,
        coinName = item.coinName,
        num = item.num,
        price = item.price,
        obj1 = player,
        additem = true,
        msg = ""
    }
    Trigger.CheckTriggers(player:cfg(), "ENTITY_BUY_COMMODITY", context)
    if context.additem == false then
        return context.msg
    end
    local blockName, meta = item.blockName, item.meta
    local replaceItem = {
        itemName = itemName,
        blockName = blockName,
        meta = meta,--no more use!
    }
    local needReplace = player:checkReplaceBuyItem(replaceItem)
    if needReplace then
        meta = replaceItem.meta
        blockName = replaceItem.blockName
        itemName = replaceItem.itemName
    end
    local block = meta or blockName
    if not player:data("tray"):add_item(itemName, item.num, itemName == "/block" and function(_item)
        if tonumber(block) then
            _item:set_block_id(block)
        else
            _item:set_block(block)
        end
    end, true) then
        return "gui_str_app_shop_inventory_is_full"
    end
    player:data("tray"):add_item(itemName, item.num, itemName == "/block" and function(_item)
        if tonumber(block) then
            _item:set_block_id(block)
        else
            _item:set_block(block)
        end
    end, false, "buy_shop")
    return "gui_buy_goods_successful"
end

function Commodity:sendBuyResult(player, msg, index, result)
    player:sendPacket({
        pid = "SendBuyCommodityResult",
        msg = msg,
        index = index,
        result = result
    })
end