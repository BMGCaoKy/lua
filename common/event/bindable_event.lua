local Event = Event
local BindHandler = BindHandler
local BindableEvent = BindableEvent

function BindableEvent:ctor(EventPoolID, EventName, Namespace)
    self.__PoolID = EventPoolID
    self.__EventName = EventName
    self.__Namespace = Namespace
    self.__Multicast = true --是否多播, 即允许多个绑定
    self.__Lock = false --发射事件时进入上锁状态, 发射结束解锁, 上锁状态影响事件Emit与Bind的流程
    self.__Binds = {} --<ID, BindHandler> ID仅用于销毁, 不用于查询
    self.__LockingBinds = {} --<ID, BindHandler>
    self.__SingleBind = nil --用于单播绑定
    self.__IsValid = true
end

function BindableEvent:Destroy()
    for _,Bind in pairs(self.__Binds) do
        Bind:Destroy()
    end
    if self.__SingleBind then
        self.__SingleBind:Destroy()
    end
    self.__Binds = nil
    self.__LockingBinds = nil
    self.__SingleBind = nil
    self.__IsValid = false
end

---独立出来call function以便子类重写
local ErrorLog = "BindableEvent:Emit call fail"
function BindableEvent:Call(Bind, ...)
    local Function = Bind:GetFunction()
    return Lib.XPcall(Function, ErrorLog, ...)
end

---@param ... variant 事件发射参数
---@return variant 单播事件调用返回值
function BindableEvent:Emit(...)
    if not self:IsValid() then
        Lib.logWarning("Attempt to emit a not valid event")
        return
    end
    
    if self:IsLock() then
        Lib.logWarning("Attempt to emit a emitting event")
        return
    end

    self:Lock()
    if self:IsMulticast() then
        local Binds = self.__Binds
        for _,Bind in pairs(Binds) do
            self:Call(Bind, ...)
            if not self:IsValid() then
                Lib.logWarning("Event owner be destroyed when emitting")
                break
            end
        end
        self:MoveLockingBinds()
    elseif self.__SingleBind then
        local ok, ret = self:Call(self.__SingleBind, ...)
        self:Unlock()
        if ok then return ret end --单播事件允许返回值
    end
    self:Unlock()
end

---@param Function function : 绑定函数
---@return BindHandler
function BindableEvent:Bind(Function)
    if not self:IsValid() then
        return
    end

    local NewBind = BindHandler.new(Function)

    --多播需要考虑上锁状态, 单播不考虑直接覆盖
    if self:IsMulticast() then
        local ToTable
        if self:IsLock() then
            ToTable = self.__LockingBinds
        else
            ToTable = self.__Binds
            NewBind:Activate()
        end

        local ID = #ToTable + 1
        ToTable[ID] = NewBind
        NewBind:SetDestroy(function()
            ToTable[ID] = nil
            self:OnBindDestroy()
        end)
        NewBind:SetBindData("BindID", ID)
    else
        local OldBind = self.__SingleBind
        if OldBind then OldBind:Destroy() end
        self.__SingleBind = NewBind
        NewBind:Activate()
        NewBind:SetDestroy(function()
            self.__SingleBind = nil
            self:OnBindDestroy()
        end)
    end

    return NewBind
end

function BindableEvent:OnBindDestroy()

end

function BindableEvent:MoveLockingBinds()
    if not self:IsValid() then
        return
    end
    for _ID,Bind in pairs(self.__LockingBinds) do
        local ID = #self.__Binds + 1
        self.__Binds[ID] = Bind
        Bind:Activate()
        Bind:SetDestroy(function()
            self.__Binds[ID] = nil
            self:OnBindDestroy()
        end)
        Bind:SetBindData("BindID", ID)
        self.__LockingBinds[_ID] = nil
    end
end

function BindableEvent:DestroySingleBind()
    if self.__SingleBind then
        self.__SingleBind:Destroy()
    end
end

function BindableEvent:GetSingleBindFunction()
    if self.__SingleBind then
        return self.__SingleBind:GetFunction()
    end
end

function BindableEvent:ExistBind()
    if self.__SingleBind or next(self.__Binds) or next(self.__LockingBinds) then
        return true
    end

    return false
end

function BindableEvent:GetNamespace()
    return self.__Namespace
end

function BindableEvent:GetEventName()
    return self.__EventName
end

function BindableEvent:GetPoolID()
    return self.__PoolID
end

function BindableEvent:GetPool()
    return Event:GetEventPoolById(self:GetPoolID())
end

function BindableEvent:GetOwner()
    if self:IsValid() then
        return self:GetPool():GetOwner()
    end
end

function BindableEvent:IsMulticast()
    return self.__Multicast
end

function BindableEvent:SetNoMulticast()
    self.__Multicast = false
end

function BindableEvent:Lock()
    self.__Lock = true
end

function BindableEvent:Unlock()
    self.__Lock = false
end

function BindableEvent:IsLock()
    return self.__Lock
end

function BindableEvent:IsValid()
    return self.__IsValid
end

