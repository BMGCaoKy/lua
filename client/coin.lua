require "common.coin"
local newIcon = GUIManager:Instance():isEnabled()

function Coin:iconByCoinName(coinName)
    if coinName == "gDiamonds" then
        if newIcon then
            return "new_diamond/Diamond-icon2"
        end
        return "set:diamond.json image:Diamond-icon2.png"
    elseif coinName == "green_currency" then
        if newIcon then
            return "new_diamond/green_currency"
        end
        return "set:jail_break.json image:jail_break_currency"
    end
    local coin = assert(self.coinMapping[coinName], coinName)
    local item = coin.item
    local icon = coin.icon or coin.ceguiIcon
    if not icon and item and next(item) then
        icon = ResLoader:getIcon(item.type, item.name)
    elseif icon and newIcon then
        icon = GUILib.loadImage(icon)
    end
    return icon or ""
end

function Coin:countByCoinName(player, coinName)
    local count = 0
    local coin = assert(self.coinMapping[coinName], coinName)
    local item = coin.item
    if item and next(item) then
        count = player:tray():find_item_count(item.type == "Item" and item.name or "/block", item.name)
    else
        local currency = player:data("wallet")[coinName]
        count = currency and currency.count or 0
    end
    return count
end

function Coin:iconByCoinId(coinId)
    if coinId == 0 then
        return "set:diamond.json image:Diamond-icon2.png"
    elseif coinId == 2 then
        return "set:app_shop.json image:app_shop_gold"
    else
        local currency = Coin:GetCoinCfg()[coinId - 2]
        if currency then
            return Coin:iconByCoinName(currency.coinName)
        end
    end
    return ""
end