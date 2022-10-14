local EventPool = EventPool
local DEFAULT = Define.EVENT_POOL.DEFAULT
local Creator = BindableEvent.new

function EventPool:ctor(ID, Owner, EventSpace)
    self.__ID = ID
    self.__Owner = Owner
    self.__BindableEvents = {} --<Namespace, <EventName, BindableEvent>>
    self.__BindsCount = {} --<key, Count>
    self.__Locks = {} --<key, Lock>
    self.__EventCreator = Creator
    self.__PoolType = DEFAULT
    self.__EventSpace = EventSpace
    self.__Valid = true
    self:Init()
end

function EventPool:Init()
    --供子类重写
end

---@param EventName string : 事件名
---@param Namespace string : 事件作用域, 默认"Engine"
---@param NotCreate boolean : 若不存在则不创建新的BindableEvent
---@return BindableEvent
---@return boolean 是否为新创建的BindableEvent
function EventPool:GetEvent(EventName, Namespace, NotCreate)
    --将GetEvent的逻辑再封装一层到函数中是为了方便子类重写GetEvent
    if not self:CheckSpace(EventName) then
        return
    end

    return self:GetEventInner(EventName, Namespace, NotCreate)
end

local IsValidEvent = Event.IsValidEvent
function EventPool:CheckSpace(EventName)
    local EventSpace = self:GetEventSpace()
    return IsValidEvent(EventName, EventSpace)
end

function EventPool:GetEventInner(EventName, Namespace, NotCreate)
    --assert(EventName, "Get Event Not Exist EventName!!!")
    if not self:IsValid() then
        Lib.logWarning("Attempt to get a not valid event")
        return
    end
    if not Namespace then
        Namespace = "Engine"
    end
    local Events = self.__BindableEvents[Namespace]
    if not Events then
        if NotCreate  then
            return
        end

        Events = {}
        self.__BindableEvents[Namespace] = Events
    end

    local New = false
    local BindableEvent = Events[EventName]
    if not BindableEvent then
        if NotCreate then
            return
        end
        if not EventName then
            Lib.logWarning("GetEvent EventName is nil")
            return
        end

        New = true
        BindableEvent = self.__EventCreator(self:GetID(), EventName, Namespace)
        Events[EventName] = BindableEvent
    end

    return BindableEvent, New
end

function EventPool:GetID()
    return self.__ID
end

function EventPool:GetOwner()
    return self.__Owner
end

function EventPool:GetType()
    return self.__PoolType
end

function EventPool:GetEventSpace()
    return self.__EventSpace
end

function EventPool:IsValid()
    return self.__Valid
end

function EventPool:DestroySingleBind(EventName)
    local BindableEvent = self:GetEvent(EventName, "Engine", true)
    if not BindableEvent then
        return
    end

    BindableEvent:DestroySingleBind()
end

function EventPool:GetSingleBindFunction(EventName)
    local BindableEvent= self:GetEvent(EventName, "Engine", true)
    if not BindableEvent then
        return
    end

    return BindableEvent:GetSingleBindFunction()
end

local Event = Event
function EventPool:Destroy()
    --优先销毁Pool管理的事件
    for Namespace,Events in pairs(self.__BindableEvents)  do
        for EventName,BindableEvent in pairs (Events) do
            BindableEvent:Destroy()
        end
    end

    --Event销毁索引
    Event:DestroyEventPool(self)

    --最后销毁自身数据
    self.__Owner = nil
    self.__EventClass = nil
    self.__BindableEvents = nil
    self.__Valid = false
end

--处理新旧事件专用函数
--目前只写到window兼容和instance兼容, 两者均用到了这套函数, 因此把这套函数从EventPoolWindow那边搬到了这里
--key在不同的事件体系中可能存在不同的含义

function EventPool:Lock(key)
    self.__Locks[key] = true
end

function EventPool:Unlock(key)
    self.__Locks[key] = nil
end

function EventPool:IsLock(key)
    return self.__Locks[key]
end

function EventPool:GetBindCount(key)
    return self.__BindsCount[key] or 0
end

function EventPool:AddBindCount(key)
    self.__BindsCount[key] = self:GetBindCount(key) + 1
end

function EventPool:ReduceBindCount(key)
    self.__BindsCount[key] = self:GetBindCount(key) - 1
end

function EventPool:OnBind(BindableEvent)
    --在子类中重写
    --OnBind与OnBindDestroy一般仅在需要切割新旧事件处理的事件系统中会用到
    --往往会有这些特点：
    --1.当事件发射时(key1), 会通知到同义旧事件(key2)与同义新事件(key3).例子如UI事件中发射MouseClick, 会通知到onMouseClick与OnClick事件
    --2.事件的注册与销毁除了记录绑定函数外, 还需通知(c++层)下发事件
end

function EventPool:OnBindDestroy(BindableEvent)
    --在子类中重写
end

function EventPool:EmitEvent(EventName, ...)
    --在子类中重写
    local BindableEvent = self:GetEvent(EventName, "Engine", true)
    if BindableEvent then
        BindableEvent:Emit(...)
    end
end

--结束处理新旧事件函数

Event:RegisterInterface(DEFAULT, "GetEvent",function (Owner, EventName, Namespace, NotCreate)
    local Pool = Event:GetEventPool(Owner, NotCreate)
    if Pool then return Pool:GetEvent(EventName, Namespace, NotCreate) end
end)

Event:RegisterInterface(DEFAULT, "DestroySelfEvent",function (Owner)
    local Pool = Event:GetEventPool(Owner, true)
    if Pool then Pool:Destroy() end
end)

Event:RegisterInterface(DEFAULT, "DestroySingleBind",function(Owner, EventName)
    local Pool = Event:GetEventPool(Owner, true)
    if Pool then return Pool:DestroySingleBind(EventName) end
end)

Event:RegisterInterface(DEFAULT, "GetSingleBindFunction",function(Owner, EventName)
    local Pool = Event:GetEventPool(Owner, true)
    if Pool then return Pool:GetSingleBindFunction(EventName) end
end)

Event:RegisterInterface(DEFAULT, "EmitEvent",function (Owner, EventName, ...)
    local Pool = Event:GetEventPool(Owner, true)
    if Pool then Pool:EmitEvent(EventName, ...) end
end)