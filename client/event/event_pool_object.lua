local Event = Event
local OBJECT = Define.EVENT_POOL.OBJECT

Event:RegisterInterface(OBJECT, "EmitEvent",function (Owner, EventName, ...)
    if not IS_EDITOR and not Owner.isPlayer then
        Lib.logError("In Client Only MainPlayer Can EmitEvent!!!")
        return
    end
    local Pool = Event:GetEventPool(Owner, true)
    if Pool then Pool:EmitEvent(EventName, ...) end
end)

Event:RegisterInterface(OBJECT, "GetEvent",function (Owner, EventName, Namespace, NotCreate)
    if not IS_EDITOR and not Owner.isPlayer then
        Lib.logError("In Client Only MainPlayer Can GetEvent!!!")
        return
    end
    local Pool = Event:GetEventPool(Owner, NotCreate)
    if Pool then return Pool:GetEvent(EventName, Namespace, NotCreate) end
end)

--common.object的加载时序过于靠前, 不便把这段代码放在object.lua中
--若在common中对接接口, 本脚本上方定义的接口无法成功注册到Object上
Event:InterfaceForTable(Object, Define.EVENT_SPACE.OBJECT, Define.EVENT_POOL.OBJECT)