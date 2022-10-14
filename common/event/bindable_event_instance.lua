---用于兼容Instance的BindableEvent子类
---代码中出现的self.super为BindableEvent
--local BindableEvent = BindableEvent
local BindableEventInstance = BindableEventInstance

--事件的第一个参数均为Instance本身
function BindableEventInstance:IsConnect()
    return self:GetNamespace() == "EngineConnect"
end

--事件的第一个参数均为Instance本身
function BindableEventInstance:Emit(...)
    if not self:IsValid() then
        return
    end
    local Owner = self:GetOwner()
    BindableEventInstance.super.Emit(self, Owner, ...)
end

local needSetCheckTouchEvent = {
    part_touch_part_begin = true,
    part_touch_part_end = true,
    part_touch_entity_begin = true,
    part_touch_entity_end = true,
    OnCollisionBegin = true,
    OnCollisionEnd = true,
}

function BindableEventInstance:Bind(Function)
    local NewBind = BindableEventInstance.super.Bind(self, Function)
    self:GetPool():OnBind(self)

    local EventName = self:GetEventName()
    local Owner = self:GetOwner()
    if needSetCheckTouchEvent[EventName] and Owner.setCheckTouchEvent then
        Owner:setCheckTouchEvent(true)
    end

    return NewBind
end

function BindableEventInstance:OnBindDestroy()
    BindableEventInstance.super.OnBindDestroy(self)
    self:GetPool():OnBindDestroy(self)
end