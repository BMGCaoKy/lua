require "common.commodity"

function Commodity:requestCanBuy(itemIndex, player)
    local commodity = self:GetCommodity(itemIndex)
    local result = false
    result = self:enoughMoney(commodity, player)
    if result then
        self:sendBuyResult(player, self:buyShop(commodity, player))
    else
        self:sendBuyResult(player, "ack_of_money")
    end
end

function Commodity:enoughMoney(item, player)
    local coin = Coin:getCoin(item.coinName)
    local coinItem = coin and coin.item
    if coinItem and next(coinItem) then
	    local isCanRemove = {result = true}
        Trigger.CheckTriggers(player:cfg(), "IS_CAN_REMOVE_ITEM", {obj1 = player, isCanRemove = isCanRemove, iconName = item.coinName})
        if not isCanRemove.result then
            return true
        end
        if Coin:consumeCoin(item.coinName, player, item.price) then
            return true
        end
        local total, retItems = player:searchTypeItemsFromBag("tag", item.coinName)
        if total < item.price then
            return false
        end
        player:consumeBagItems(item.price, retItems, "buy_shop")
        return true
    end
    return player:payCurrency(item.coinName, item.price, false, false, "buy_shop")
end

function Commodity:sendBuyResult(player, msg)
    player:sendPacket({
        pid = "SendBuyCommodityResult",
        msg = msg
    })
end

function Commodity:buyShop(item, player)
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
    local block = item.meta or item.blockName
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