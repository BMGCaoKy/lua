---基础声明
local class = class
local Define = Define
local BasePool = "EventPool"
local BaseBind = "BindableEvent"
local EventPool = class(BasePool)
local BindableEvent = class(BaseBind)
local BindHandler = class("BindHandler")

local DefinePool --定义Pool类的函数
local DefineSpace --定义Space的函数
local DefineInterface --定义新接口类型
local DefineExtraPool --定义全局额外事件池

local TypeToClass = {} --字符串转Pool类型
local RegisteredInterface = {} --各个Interface类型持有的接口
local RegisteredEvent = {} --各个Space注册的事件
local ExtraPools = {} --全局特殊事件池配置

Define.EVENT_POOL = {}
Define.EVENT_SPACE = {}
local POOL = Define.EVENT_POOL --已定义的Pool类型
local SPACE = Define.EVENT_SPACE --已定义的Space类型
setmetatable(POOL, {
    __index = function(self, Key)
        return self.DEFAULT
    end
})

---@param Name string 类型的关键词, 作为Pool和Bind类的后缀
---@param Space boolean 是否创建EventSpace
---@param Interface boolean 是否创建Interface
---@param super string 父类
DefinePool = function(Name, Space, Interface, super)
    --类声明
    local Upper = string.upper(Name)
    local PoolName = BasePool .. Name
    local BindName = BaseBind .. Name
    local SuperPool
    local SuperBind
    if super then
        SuperPool = _G[BasePool .. super]
        SuperBind = _G[BaseBind .. super]
    else
        SuperPool = EventPool
        SuperBind = BindableEvent
    end
    local Pool = class(PoolName, SuperPool)
    local Bindable = class(BindName, SuperBind)

    function Pool:ctor(...)
        SuperPool.ctor(self, ...)
        self.__EventCreator = Bindable.new
        self.__PoolType = Upper
    end

    TypeToClass[Upper] = Pool
    POOL[Upper] = Upper

    if Space then
        DefineSpace(Upper)
    end

    if Interface then
        DefineInterface(Upper)
    end
end

DefineSpace = function(Name)
    SPACE[Name] = Name
    RegisteredEvent[Name] = {}
end

DefineInterface = function(Name)
    RegisteredInterface[Name] = {}
end

DefineExtraPool = function(Name, ID, EventSpace, PoolType)
    local config =
    {
        ID = ID,
        EventSpace = EventSpace,
        PoolType = PoolType,
    }
    ExtraPools[Name] = config
end

--新事件系统定义初始化, 统一在这里处理
local function Init()
    local DEFAULT = "DEFAULT"
    TypeToClass[DEFAULT] = EventPool
    POOL[DEFAULT] = DEFAULT
    DefineInterface(DEFAULT)

    --事件池类型
    DefinePool("Lib", false, false)
    DefinePool("Window", true, true)
    DefinePool("Instance", true, true)
    DefinePool("Object", true, true, "Instance")
    DefinePool("Map", true, true)

    --事件空间
    DefineSpace("FREE")
    DefineSpace("GLOBAL")
    DefineSpace("TWEEN")

    --额外事件池
    DefineExtraPool("GLOBAL", 0, SPACE.GLOBAL)
    DefineExtraPool(POOL.WINDOW, -1, SPACE.FREE)
    DefineExtraPool(POOL.LIB, -2, SPACE.FREE, EventPoolLib)
end

Init()

------------------------------------------------------------------------------

return function()
    return TypeToClass, RegisteredInterface, RegisteredEvent, ExtraPools
end
