local handles = T(Player, "PackageHandlers") ---@class PlayerPackageHandlers

function handles:BuySuccess(packet)
    Shop.BuySuccess(packet)
end

function handles:NoticeNotEnoughMoney(packet)
    if not packet.coinName then return end
    self:noticeNotEnoughMoney(packet.coinName)
end

function Player:noticeNotEnoughMoney(coinName, shopName)
    if coinName == "gDiamonds" then
        Interface.onRecharge(1)
    else
        self:noticeNotEnoughCoin(coinName)
    end
end

function Player:noticeNotEnoughCoin(coinName)
    Client.ShowTip(3, "ack_of_money", 40)
    --todo  业务可以重写
end

function Player:showMsgTip(tips)
    Client.ShowTip(3, tips, 40)
    --todo  业务可以重写
end