--用于兼容Lib.subscribeEvent系统
local Event = Event
local EventPoolLib = EventPoolLib
local CallsMeta =
{
    __index = function(tb, k)
        local EventName = tb.__EventName
        if not EventName then return end
        local BindableEvent = Event:GetExtraEvent(Define.EVENT_POOL.LIB, EventName, "Engine", true)
        if not BindableEvent then return end
        local Bind = BindableEvent:GetBindByID(k)
        if not Bind then return end
        local ret =
        {
            func = Bind:GetFunctionRaw(),
            event = EventName,
            args = Bind:GetBindData("Args"),
            stack = Bind:GetBindData("Stack"),
            index = Bind:GetBindData("ID")
        }
        --setmetatable(ret, CallMeta)
        return ret
    end,
    __newindex = function(tb, k, v)

    end
}
--用来替代Lib.getEventCall(name)逻辑的函数
function Event:GetLibCalls(EventName)
    local BindableEvent = Event:GetExtraEvent(Define.EVENT_POOL.LIB, EventName, "Engine", true)
    if not BindableEvent then
        return
    end

    local ret =
    {
        __EventName = EventName
    }
    setmetatable(ret, CallsMeta)
    return ret
end