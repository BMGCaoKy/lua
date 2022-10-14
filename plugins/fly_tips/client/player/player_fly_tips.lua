local Player = Player
local handles = T(Player, "PackageHandlers")
local FlyTipsHelper = T(Lib, "FlyTipsHelper")

-- 收到服务端通知，发送一条提示
function handles:ClientAddOneNewFlyTips(packet)
    FlyTipsHelper:pushOneFlyTipsItem(packet.itemInfo)
end