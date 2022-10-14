local status = {} ---@class TweenBaseStatus

status._params = nil
status._delayTime = nil
status._paused = nil
status._isInSequence = nil
status._playCount = nil

function status:init(params)
    self._params = params
    self._isInSequence = false
    self:reset()
end

function status:reset()
    self:restart()
    self._playCount = 0
end

function status:restart()
    self._delayTime = self._params.delayTime
    self._paused = false
end

---设置是否暂停
---@param value boolean
function status:setPause(value)
    self._paused = value
end

---添加延迟时间
function status:setDelay(value)
    self._delayTime = value
end

function status:setIsInSequence(value)
    self._isInSequence = value
end

function status:addPlayCount()
    self._playCount = self._playCount + 1
end

function status:active()
    return  not self:isDelaying() 
        and not self:isPaused()
end

function status:playCount()
    return self._playCount
end

function status:isPaused()
    return self._paused
end

function status:isDelaying()
    return self._delayTime > 0
end

function status:isInSequence()
    return self._isInSequence
end

function status:isLooping()
    local loopCount = self._params.loopCount

    if loopCount == -1 then
        return true
    end
    
    return self:playCount() < loopCount
end

---@return boolean
function status:update(deltaTime)
    if self:isPaused() then
        return false
    end

    if self:isDelaying() then
        self._delayTime = math.max(0, self._delayTime - deltaTime)
        return false
    end

    return true
end

---@return boolean
function status:isStepCompleted() error("没有实现本方法") end

return status