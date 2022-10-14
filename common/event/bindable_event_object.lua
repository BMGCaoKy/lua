---用于兼容Object的BindableEvent子类
---Owner为Object对象实例
local BindableEvent = BindableEvent
--local BindableEventInstance = BindableEventInstance
local BindableEventObject = BindableEventObject

function BindableEventObject:Bind(...)
    local EventName = self:GetEventName()
    if self:IsConnect() then
        return BindableEventObject.super.Bind(self, ...)
    else
        return BindableEvent.Bind(self, ...)
    end
end