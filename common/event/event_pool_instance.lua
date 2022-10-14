---用于兼容Instance的EventPool子类
local Instance = Instance
local EventPoolInstance = EventPoolInstance

function EventPoolInstance:Init()
    self.__SignalID = {}
end

--instance旧事件不需要检测是否register, 全部放行
function EventPoolInstance:GetConnectEvent(EventName, NotCreate)
    return self:GetEventInner(EventName, "EngineConnect", NotCreate)
end

local function Emit(self, EventName, IsConnect, ...)
    if not EventName then
        return
    end

    local BindableEvent
    if IsConnect then
        BindableEvent = self:GetConnectEvent(EventName, true)
    else
        BindableEvent = self:GetEvent(EventName, "Engine", true)
    end
    if BindableEvent then
        BindableEvent:Emit(...)
    end
end

---从通过全局函数scene_event通知的事件
---@param CppEventName string C++中定义的事件名
function EventPoolInstance:EmitEvent(CppEventName, ...)
    self:Lock(CppEventName)
    local LuaEvent = Instance.ToLuaEvent(CppEventName)

    Emit(self, LuaEvent, false, ...)
    if CppEventName ~= LuaEvent then
        Emit(self, CppEventName, true, ...)
    end

    self:Unlock(CppEventName)
end

local function OnBind(self, CppEventName)
    if self:GetBindCount(CppEventName) <= 0 then
        local Owner = self:GetOwner()
        local SignalID = Owner:subscribeSceneEvent(CppEventName)
        self:SetSignalID(CppEventName, SignalID)
    end
    self:AddBindCount(CppEventName)
end

function EventPoolInstance:OnBind(BindableEvent)
    local EventName = BindableEvent:GetEventName()
    local CppEvent = Instance.ToCppEvent(EventName)
    if not CppEvent then
        return
    end

    if type(CppEvent) == "string" then
        OnBind(self, CppEvent)
    elseif type(CppEvent) == "table" then
        for _,_CppEvent in pairs(CppEvent) do
            OnBind(self, _CppEvent)
        end
    end
end

local function OnBindDestroy(self, CppEventName)
    self:ReduceBindCount(CppEventName)

    local function unsubscribe()
        if not self:IsValid() then
            return false
        end

        if self:GetBindCount(CppEventName) > 0 then
            return false
        end
        if self:IsLock(CppEventName) then
            return true
        end

        local Owner = self:GetOwner()
        local SignalID = self:GetSignalID(CppEventName)
        Owner:unsubscribeSceneEvent(CppEventName, SignalID)
        self:SetSignalID(CppEventName)
        return false
    end

    local result = unsubscribe()
    if result then
        World.Timer(1, unsubscribe)
    end
end

function EventPoolInstance:OnBindDestroy(BindableEvent)
    local EventName = BindableEvent:GetEventName()
    local CppEvent = Instance.ToCppEvent(EventName)
    if not CppEvent then
        return
    end

    if type(CppEvent) == "string" then
        OnBindDestroy(self, CppEvent)
    elseif type(CppEvent) == "table" then
        for _,_CppEvent in pairs(CppEvent) do
            OnBindDestroy(self, _CppEvent)
        end
    end
end

function EventPoolInstance:SetSignalID(Key, SignalID)
    self.__SignalID[Key] = SignalID
end

function EventPoolInstance:GetSignalID(Key)
    return self.__SignalID[Key]
end

local Event = Event
local INSTANCE = Define.EVENT_POOL.INSTANCE

--重写EventPool注册的GetEvent接口
Event:RegisterInterface(INSTANCE, "GetEvent",function (Owner, EventName, Namespace, NotCreate)
    local Pool = Event:GetEventPool(Owner, NotCreate)
    if Pool and Instance.IsLuaEvent(EventName) then
        return Pool:GetEvent(EventName, Namespace, NotCreate)
    end
end)

--instance旧事件系统, 获得connect事件专用接口
Event:RegisterInterface(INSTANCE, "GetConnectEvent",function (Owner, EventName, NotCreate)
    local Pool = Event:GetEventPool(Owner, NotCreate)
    if Pool then
        return Pool:GetConnectEvent(EventName, NotCreate)
    end
end)

--instance旧事件系统, 发射connect事件专用接口
Event:RegisterInterface(INSTANCE, "EmitConnectEvent",function (Owner, EventName, ...)
    --要兼顾全大写与全小写的情况, 在旧代码中有相关处理, 需保留
    local UpperSignal = string.upper(EventName)
    local LowerSignal = string.lower(EventName)
    local Meta
    local Upper = Owner:GetConnectEvent(UpperSignal, true)
    local Lower = Owner:GetConnectEvent(LowerSignal, true)
    if EventName ~= Upper and EventName ~= Lower then
        Meta = Owner:GetConnectEvent(EventName, true)
    end
    if Upper then Upper:Emit(...) end
    if Lower then Lower:Emit(...) end
    if Meta then Meta:Emit(...) end
end)

