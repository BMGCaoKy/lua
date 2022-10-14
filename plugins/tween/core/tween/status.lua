local extends = require "core.tools".extends
local super = require "core.base.status"

---@class TweenerStatus : TweenBaseStatus
local status = extends(super) 

status._params = nil ---@type TweenerParams
status._reversed = nil
status._elapsed = nil

function status:reset()
    super.reset(self)
    self._reversed = false
end

function status:restart()
    super.restart(self)
    self._elapsed = 0
end

function status:resetForYoyo()
    self._reversed = not self._reversed
    self._elapsed = self:isReversed() and self._params.duration or 0
    if not self._reversed then
        self._delayTime = self._params.delayTime
    end
    self._paused = false
end

function status:resetForRestart()
    self._elapsed = 0
    self._delayTime = self._params.delayTime
    self._paused = false
end

function status:elapsed()
    return self._elapsed
end

function status:isReversed()
    return self._reversed
end

function status:isStepCompleted()
    local elapsed = self:elapsed()
    if elapsed < 0 or elapsed > self._params.duration then
        return true
    end
    return false
end

function status:active()
    return  not self:isDelaying()
        and not self:isStepCompleted()
        and not self:isPaused()
end

function status:update(deltaTime)
    if super.update(self, deltaTime) then
        self._elapsed = self._elapsed + self:_dir() * deltaTime
    end
end

function status:setReversed(value)
    self._reversed = value
end

---@private
function status:_dir()
    return self:isReversed() and -1 or 1
end

return function()
    return setmetatable({},{__index = status}) 
end