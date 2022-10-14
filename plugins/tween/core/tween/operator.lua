local enum = require "core.enum"
local easing = require "core.easing"
local extends = require "core.tools".extends
local super = require "core.base.operator"

---@class TweenerOperator : TweenBaseOperator
local operator = extends(super) 

---@private
---@param tweener Tweener
function operator:init(tweener, tid)
    super.init(self, tweener, tid)
    self._tweener = tweener
end

---设置缓动的初始值
---@param value any
function operator:from(value)
    self._tweener.params.from = value

    return self
end

---反转本次缓动
function operator:reverses()
    self._tweener.status:setReversed(true)

    return self
end

---设置缓动类型
---@param ease EaseType 缓动类型
function operator:setEase(ease)
    if not enum.easeType[ease] then
        print(string.format("该缓动类型[ %s ]不存在!", tostring(ease)))
        return self
    end

    self._tweener.params.ease = easing[ease]

    return self
end

---设置缓动函数
---@param easeFunc fun(elapsed : number, begin : T, change : T, duration: number) : T
function operator:setEaseByFunc(easeFunc)
    if type(easeFunc) ~= "function" then
        print(error(string.format("请传入一个函数!而非一个:「%s」", type(easeFunc))))
        return self
    end

    self._tweener.params.ease = easeFunc

    return self
end

---跳过延迟提前开始
function operator:go()
    self._tweener.status:setDelay(0)
    self._tweener.status:setPause(false)

    return self
end

---取消缓动，以动画的形式
function operator:playCancel()
    self:reverses()
    self:go()
end

function operator:onStepCompleted(callBack, ...)
    self._tweener.params.onStepCompleted = callBack
    self._tweener.params.onStepCompletedArgs = table.pack(...)
    return self
end

return function()
    return setmetatable({}, {
        __index = function(self, key)
            local value = operator[key]

            if not value then
                if key == "_params" then
                    pcall(error("该缓动已经被销毁!"))
                end
            end

            return value
        end,
    })
end