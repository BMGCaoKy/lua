local handles = T(Player, "PackageHandlers")

function handles:BuyShop(packet)
    Shop.BuyByClient(packet, self)
end

function Player:refreshShopRecord()
    local record = self:getValue("recordShopTimes")
    for shopName, info in pairs(record) do
        if info.num and info.num > 0 then
            local cfg = Shop.Cfg(shopName)
            if cfg and cfg.limit and cfg.limit.refreshType then
                if cfg.limit.refreshType == "day" then
                    if not Lib.isSameDay(info.ts, os.time()) then
                        self:resetRecordShop(shopName)
                    end
                else
                    --其他的刷新类型也在这里扩展
                end
            end
        end
    end
end

function Player:noticeNotEnoughMoney(coinName, shopName)
    Lib.logError("money cost error:", coinName, shopName)
    self:sendPacket({
        pid = "NoticeNotEnoughMoney",
        coinName = coinName
    })
end

function Player:showMsgTip(tips)
    self:sendTip(3, tips, 40)
end