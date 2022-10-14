require "common.shop"

function Shop:getGroups(type)
    if not type then
        return self.groups
    end
    local groups = {}
    for _, t in pairs(type) do
        table.insert(groups, self.groups[t])
    end
    return groups
end

function Shop:getShop(index)
    return assert(self.shops[index], index)
end

function Shop:requestBuyStop(index, buyCount)
    local item = Shop:getShop(index)
    if not item then
        return
    end
    if item.coinId ~= 0 then
        Player:syncBuyShopGood(index, buyCount)
        return
    end

    local wallet = Me:data("wallet")
    local gDiamonds = wallet.gDiamonds and wallet.gDiamonds.count or 0
    local needDiamonds = item.price * buyCount
    --  string.sub(World.GameName or "",-1) ~= "b" 非beat 版,和编辑器启动一样， os.getenv("startFromWorldEditor") 编辑器启动winShell
	if (string.sub(World.GameName or "",-1) ~= "b") and not os.getenv("startFromWorldEditor") and (needDiamonds > gDiamonds) then
        Lib.emitEvent(Event.EVENT_BUY_APPSHOP_TIP, "gDiamonds.insufficient")
    else
        Player:syncBuyShopGood(index, buyCount)
    end
end

function Shop:responseBuyResult(index, limit, msg, forceUpdate, succeed)
    Lib.emitEvent(Event.EVENT_SEND_BUY_SHOP_RESULT, index, limit, msg, forceUpdate, succeed)
end