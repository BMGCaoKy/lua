---用于兼容Lib的BindableEvent子类
---代码中出现的self.super为BindableEvent
---Owner为Event
local BindableEventLib = BindableEventLib

function BindableEventLib:Call(Bind, ...)
    local Args = Bind:GetBindData("Args")
    local NewArgs = table.pack(...)
    local n = Args.n
    local m = NewArgs.n
    for i = 1, m do
        Args[n+i] = NewArgs[i]
    end
    local ok, ret = self.super.Call(self, Bind, table.unpack(Args, 1, n + m))

    if not ok then
        local EventName = self:GetEventName()
        perror("Error event callback:", EventName, ret)

        --此if分支意义不明, 原Lib发射事件时带有的逻辑
        local object = Bind:GetBindData("Object")
        Lib.sendErrMsgToChat(object, ret)

        local Stack = Bind:GetBindData("Stack")
        if Stack then
            print(Stack)
        end
    end

    return ok, ret
end

function BindableEventLib:Emit(...)
    if not self:ExistBind() then
        local EventName = self:GetEventName()
        DataCacheContainer.pushDataCache(EventName, ...)
        return
    end

    return self.super.Emit(self, ...)
end

function BindableEventLib:Bind(Function, ...)
    local Stack = Lib.getCallTag()
    return self:BindWithStack(Function, Stack, ...)
end

function BindableEventLib:BindWithStack(Function, Stack, ...)
    local NewBind = self.super.Bind(self, Function)
    NewBind:SetBindData("Stack", Stack)
    NewBind:SetBindData("Args", table.pack(...))

    local EventName = self:GetEventName()
    Lib.checkAndPopEventData(EventName)

    --这里的BindID可能是Locking状态下的无效ID
    --但是在Lib原本事件注册逻辑中便没有考虑是否会返回的为有效ID
    --比较难受, 不清楚旧项目中有多少点用到了该ID
    local BindID = NewBind:GetBindData("BindID")
    return NewBind, BindID
end

function BindableEventLib:GetBindByID(ID)
    local Bind = self.__Binds[ID]
    if not Bind then
        return
    end

    return Bind
end

function BindableEventLib:UnbindByID(ID)
    local Bind = self.__Binds[ID]
    if not Bind then
        return
    end

    Bind:Destroy()
end

function BindableEventLib:SetBindByID(ID)
    local Bind = self.__Binds[ID]
    if not Bind then
        return
    end

    Bind:Destroy()
end


