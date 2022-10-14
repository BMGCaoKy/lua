local Init = require "common.event.event_define"
local TypeToClass, RegisteredInterface, RegisteredEvent, ExtraPools = Init()

local Event = Event
local EVENT_POOL = Define.EVENT_POOL
local EVENT_SPACE = Define.EVENT_SPACE
local DEFAULT = EVENT_POOL.DEFAULT
local EventPools = {}

---声明某类型事件池持有的接口函数. 在Event:Interface系列函数中, 传参指定事件池类型将对接不同的接口函数。
---@param Type enum 事件池类型
---@param Name string 接口名
---@param InterfaceFunc function 接口函数
function Event:RegisterInterface(Type, Name, InterfaceFunc)
    assert(Type and Name and InterfaceFunc)
    RegisteredInterface[Type][Name] = InterfaceFunc
end

function Event:GetEventPool(Owner, NotCreate)
    if not Owner._EventPoolID then
        if NotCreate then
            return
        end

        local ID = Event:NewEventPool(Owner)
        Owner._EventPoolID = ID
    end

    return self:GetEventPoolById(Owner._EventPoolID)
end

--关于注册存在的问题:若定义接口在注册接口之后, 后定义的函数是无法添加到表上的
--在server和client定义接口可能存在该问题
local function Interface(Table, EventSpace ,Type)
    Table._EventPoolType = EVENT_POOL[Type]
    Table._EventSpace = EventSpace

    local DefaultInterface = RegisteredInterface[DEFAULT]
    for Name, Func in pairs(DefaultInterface) do
        Table[Name] = Func
        --rawset(Table, Name, Func)
    end
    if Type ~= DEFAULT then
        local TypeInterface = RegisteredInterface[Type]
        for Name, Func in pairs(TypeInterface) do
            Table[Name] = Func
            --rawset(Table, Name, Func)
        end
    end
end

---对一个表直接接上事件系统接口
---@param Table table 接上接口的表
---@param EventSpace enum 事件域
---@param Type enum 事件池类型
function Event:InterfaceForTable(Table, EventSpace, Type)
    Interface(Table, EventSpace, Type)
end

---对一个被视为元表的表接上事件系统接口
---@param Metatable table 接上接口的元表
---@param EventSpace enum 事件域
---@param Type enum 事件池类型
function Event:InterfaceForMetatable(Metatable, EventSpace, Type)
    local Table
    local IndexType = type(Metatable.__index)
    if IndexType == "nil" then
        Table = {}
        Metatable.__index = Table
    elseif IndexType == "function" then
        Table = {}
        local OldFunc = Metatable.__index
        local NewFunc = function(t, k)
            if Table[k] then return Table[k] end
            return OldFunc(t, k)
        end
        Metatable.__index = NewFunc
    elseif IndexType == "table" then
        Table = Metatable.__index
    end
    Interface(Table, EventSpace, Type)
end

local function NewEventMeta(Type)
    local meta = {}
    Event:InterfaceForMetatable(meta, Type)
    return meta
end

function Event:SetMetatable(Table, Type)
    return setmetatable(Table, NewEventMeta(Type))
end

function Event:GetEventPoolById(ID)
    return EventPools[ID]
end

function Event:NewEventPool(Owner, EventSpace)
    local Type = Owner._EventPoolType
    local Pool = TypeToClass[Type]
    local ID = #EventPools + 1
    if not EventSpace then
        EventSpace = Owner._EventSpace
    end
    local NewPool = Pool.new(ID, Owner, EventSpace)
    EventPools[ID] = NewPool
    return ID
end

function Event:DestroyEventPool(Pool)
    local Owner = Pool:GetOwner()
    local ID = Pool:GetID()
    Owner._EventPoolID = nil
    EventPools[ID] = nil
end

local GLOBAL = EVENT_SPACE.GLOBAL
local CustomEventTable = {} --<自定义事件名, 是否与引擎事件重名>
function Event:RegisterCustomEvent(EventName)--仅对外开放的自定义事件注册接口, 引擎不建议使用
    if CustomEventTable[EventName] ~= nil then
        return
    end
    if Event.IsValidEvent(EventName, GLOBAL) then
        CustomEventTable[EventName] = true
    else
        CustomEventTable[EventName] = false
    end
    self:RegisterEvent(EventName, GLOBAL)
end

function Event.IsValidEvent(EventName, EventSpace)
    if EventSpace == EVENT_SPACE.FREE then
        return true
    end

    local Space = RegisteredEvent[EventSpace]
    if not Space then
        return false
    end

    if not Space[EventName] then
        return false
    end

    return true
end

function Event:RegisterEvent(EventName, EventSpace)
    if not RegisteredEvent[EventSpace] then
        RegisteredEvent[EventSpace] = {}
    end

    RegisteredEvent[EventSpace][EventName] = 1
end

---@param EventNames table { Name1, Name2, ... }
function Event:RegisterEvents(EventNames, EventSpace)
    for _,EventName in pairs (EventNames) do
        self:RegisterEvent(EventName, EventSpace)
    end
end

require "common.event.event_pool"
require "common.event.bindable_event"
require "common.event.bind_handler"
require "common.event.event_pool_instance"
require "common.event.bindable_event_instance"
require "common.event.event_pool_lib"
require "common.event.bindable_event_lib"
require "common.event.event_pool_object"
require "common.event.bindable_event_object"

----------------------额外全局UI事件池接口与初始化------------------

for _, Config in pairs(ExtraPools) do
    local ID = Config.ID
    local PoolType = Config.PoolType
    local EventSpace = Config.EventSpace
    if not PoolType then
        PoolType = EventPool
    end
    local Pool = PoolType.new(ID, Event, EventSpace)
    EventPools[ID] = Pool
end

function Event:GetExtraEvent(Type, EventName, Namespace, NotCreate)
    local PoolID = ExtraPools[Type].ID
    if not PoolID then return end
    local Pool = EventPools[PoolID]
    return Pool:GetEvent(EventName, Namespace, NotCreate)
end

function Event:GetEvent(EventName, Namespace, NotCreate)
    --若EventName是与引擎重名的自定义事件, 则Namespace默认值为"Custom"
    if CustomEventTable[EventName] and not Namespace then
        Namespace = "Custom"
    end
    return Event:GetExtraEvent("GLOBAL", EventName, Namespace, NotCreate)
end

function Event:EmitEvent(EventName, ...)
    local BindableEvent = Event:GetEvent(EventName, "Engine", true)
    if BindableEvent then
        BindableEvent:Emit(...)
    end
end

local CommonEvents =
{
    "OnGameStageStart",
    "OnGameStageEnd",
    "OnEntityAdded",
    "OnEntityRemoved",
}

Event:RegisterEvents(CommonEvents, GLOBAL)
-------------------------------------------------------------