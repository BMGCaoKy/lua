local ReportAttr = T(Config, "ReportAttr")

-------------------工具函数start-----------------------
local function getCurrency(player, coinName)
    return player:getCurrency(coinName, true) or {}
end
-----------------工具函数end------------------------------

function ReportAttr.coins_num(player)
    return getCurrency(player, "gold").count or 0
end

function ReportAttr.gcube_num(player)
    return getCurrency(player, "gDiamonds").count or 0
end

function ReportAttr.online_time(player)
    local loginTs = player:getLoginTs()
    return os.time() - loginTs
end
