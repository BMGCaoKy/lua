local loopEnum = require "core.enum".loopType
local extends = require "core.tools".extends
local super = require "core.base.tweenBase"

---@class Tweener : TweenBase
local tweener = extends(super)

tweener._getter = nil
tweener._setter = nil

tweener.params = nil ---@type TweenerParams
tweener.status = nil ---@type TweenerStatus
tweener.operator = nil ---@type TweenerOperator

---@param getter function
---@param setter function
---@param to any
---@param duration number
function tweener:init(getter, setter, to, duration, tid)
    self._tid = tid
    self._getter = getter
    self._setter = setter

    self.params = require("core.tween.params")()
    self.params:init(to, duration)
    
    self.status = require("core.tween.status")()
    self.status:init(self.params)
    
    self.operator = require("core.tween.operator")()
    self.operator:init(self)
    
    return self.operator
end

function tweener:start()
    self.params.from = self.params.from or self._getter()
    super.start(self)
end

function tweener:finish()
    self._setter(self.params.to)
    super.finish(self)
end

function tweener:destroy()
    super.destroy(self)
    self.operator._tweener = nil
end

function tweener:restart()
    super.restart(self)
    --self._setter(self.params.from)
end

---@param params TweenerParams
---@param status TweenerStatus
local function doEasing(setter, params, status)
    local elapsed = status:elapsed()
    local from = params.from
    local to = params.to
    local duration = params.duration
    local easingValue = params.ease(elapsed, from, to - from, duration)

    setter(easingValue)
end

function tweener:_onUpdate(deltaTime)
    doEasing(self._setter, self.params, self.status)
end

function tweener:_onLooping()
    if self.params.loopType == loopEnum.Yoyo then
        self.status:resetForYoyo()
    elseif self.params.loopType == loopEnum.Restart then
        self.status:resetForRestart()
    end 
end

function tweener:_createParams()
    
end

function tweener:_createStatus(params)

end

function tweener:_createOperator()

end

return function()
    return setmetatable({}, { __index = tweener })
end
