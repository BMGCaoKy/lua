local ShopBase = Shop.GetType("Base")
local setting = require "common.setting"

--客户端显示可能会用到的字段，价格除外
function ShopBase:getShowInfo()
    local infos = {
        rewards = {},
        price = {},
        cdSource = nil
    }
    for k, reward in pairs(self.rewardParams.reward or {}) do
        local rewardCfg = false
        if reward.type == "Item" then
            rewardCfg = setting:fetch("item", reward.name)
        elseif reward.type == "Entity" then
            rewardCfg = setting:fetch("entity", reward.name)
        elseif reward.type == "Event" then
            if reward.cfg then
                rewardCfg = setting:fetch("shop", reward.cfg)
            end
        end
        local desc = rewardCfg and (rewardCfg.itemintroduction or rewardCfg.desc) or false
        local rewardName = rewardCfg and (rewardCfg.itemname or rewardCfg.name) or false
        local rewardIcon = rewardCfg and rewardCfg.icon or false
        if reward.rewardIcon then
            rewardIcon = reward.rewardIcon
        end
        if reward.desc then
            desc = reward.desc
        end
        if reward.rewardName then
            rewardName = reward.rewardName
        end
        table.insert(infos.rewards, {
            icon = rewardIcon,
            desc = desc,
            name = rewardName,
            count = reward.count or 1,
            bg = reward.bg or "",
            type = reward.type,
            isMainProp = reward.isMainProp
        })
    end
    --特殊价格只有在满足购买条件的情况下才显示
    local showPrice = self.price
    if self.specialPrice and self:checkPriceEnough(self.specialPrice, Me) then
        showPrice = self.specialPrice
    end
    for coinName, priceCount in pairs(showPrice) do
        table.insert(infos.price, {
            icon = Coin:iconByCoinName(coinName),
            count = priceCount,
            coinName = coinName
        })
    end
    return infos
end

-- 购买预处理
function ShopBase:preBuy(packet)
    if self.preBuyFunc then

    end
end