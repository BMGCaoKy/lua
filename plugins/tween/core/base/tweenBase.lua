local tweenBase = {} ---@class TweenBase
local new = require "core.tools".new

tweenBase._tid = nil
tweenBase._isStarted = false
tweenBase._isFinished =false
tweenBase._isDestroyed = false

tweenBase.params = nil
tweenBase.status = nil
tweenBase.operator = nil
tweenBase.isTween = true

function tweenBase:init(tid)
    self._tid = tid
    self.params = self:_createParams()
    self.status = self:_createStatus(self.params)
    self.operator = self:_createOperator(tid)
end

function tweenBase:start()
    self._isStarted = true
    self.params:start()
end

function tweenBase:finish()
    self._isFinished = true
    self.params:finish()
end

function tweenBase:destroy()
    self._isDestroyed = true
    self.operator._tweenBase = nil
    self.operator._isValid = nil
end

function tweenBase:reset()
    self.status:reset()
    self:restart()
end

function tweenBase:restart()
    self._isStarted = false
    self._isFinished = false
end

function tweenBase:isStarted()
    return self._isStarted
end

function tweenBase:isFinished()
    return self._isFinished
end

function tweenBase:tid()
    return self._tid
end

---缓动更新
---@param deltaTime number
function tweenBase:update(deltaTime)
    if not self.operator:isValid() then
        self:destroy()
        return
    end
    local params = self.params
    local status = self.status

    deltaTime = deltaTime * self.params.timeScale

    status:update(deltaTime)

    if status:active() then
        if not self:isStarted() then
            self:start()
        end

        self:_onUpdate(deltaTime)
        params:update()
    end

    if status:isStepCompleted() and not self:isFinished() then
        status:addPlayCount()
        params:stepCompleted()

        if status:isLooping() then
            self:_onLooping()
        else
            self:finish()
        end
    end
end

---该缓动是否已经死亡
---@return boolean
function tweenBase:canKill()
    return self._isDestroyed or (self:isFinished() and self.params.autoKill)
end

---@protected
function tweenBase:_onUpdate(deltaTime)
end

---@protected
function tweenBase:_onLooping()
end

---@protected
---@return TweenBaseParams
function tweenBase:_createParams()
    return new(require"core.base.params")
end

---@protected
---@return TweenBaseStatus
function tweenBase:_createStatus(params)
    return new(require"core.base.status", params)
end

---@protected
---@return TweenBaseOperator
function tweenBase:_createOperator(tid)
    return new(require"core.base.operator", self, tid)
end

return tweenBase