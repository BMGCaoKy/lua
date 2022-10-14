---用于兼容Instance的EventPool子类
---代码中出现的self.super为EventPool
local Event = Event
local OBJECT = Define.EVENT_POOL.OBJECT

--发射事件的同时通知客户端玩家实体事件
--注意: ...参数需可序列化
Event:RegisterInterface(OBJECT, "EmitEventAsync",function (Owner, EventName, ...)
    local Pool = Event:GetEventPool(Owner, true)
    if Pool then
        Pool:EmitEvent(EventName, ...)
    end
    if not Owner.isPlayer then
        return
    end
    Owner:sendPacket({
        pid = "EventAsync",
        EventName = EventName,
        Args = {...},
    })
end)

--common.object的加载时序过于靠前, 不便把这段代码放在object.lua中
--若在common中对接接口, 本脚本上方定义的接口无法成功注册到Object上
Event:InterfaceForTable(Object, Define.EVENT_SPACE.OBJECT, Define.EVENT_POOL.OBJECT)
