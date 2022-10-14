local BindableEventWindow = BindableEventWindow

--用于兼容Window的BindableEvent子类
--代码中出现的self.super为BindableEvent
--Owner为ui_handler.lua中的instance

--UI事件的第一个参数均为窗口实例表
function BindableEventWindow:Emit(...)
    local Owner = self:GetOwner()
    self.super.Emit(self, Owner, ...)
end

function BindableEventWindow:Bind(Function)
    local NewBind = self.super.Bind(self, Function)
    self:GetPool():OnBind(self)
    return NewBind
end

function BindableEventWindow:OnBindDestroy()
    self.super.OnBindDestroy(self)
    self:GetPool():OnBindDestroy(self)
end