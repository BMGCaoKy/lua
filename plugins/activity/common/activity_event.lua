---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by bell.
--- DateTime: 2020/3/25 22:21
---

if World.isClient then
    Event.EventMustLotteryDelete = Event.register("EventMustLotteryDelete")
    Event.EventMustLotteryResult = Event.register("EventMustLotteryResult")
    Event.EventLuckyLotteryResult =  Event.register("EventLuckyLotteryResult")
    Event.EventCommonActivityOpenChestResult =  Event.register("EventCommonActivityOpenChestResult")
    Event.EventCommonActivityRefreshChest =  Event.register("EventCommonActivityRefreshChest")
    Event.EventCommonActivityLayoutHide =  Event.register("EventCommonActivityLayoutHide")
    Event.EventLuckyLotteryDiscountCd =   Event.register("EventLuckyLotteryDiscountCd")
    Event.EventTipNeedBackPack =   Event.register("EventTipNeedBackPack")
    Event.EventBlindBoxOpenResult =   Event.register("EventBlindBoxOpenResult")
    Event.EventBlindBoxInit =   Event.register("EventBlindBoxInit")
else

end