local extends = require "core.tools".extends
local super = require "core.base.status"

local function foreachIn(value, handler)
    if type(value) == "table" then
        if (value.isTween and not value.isSequence) or value.isCallBack or value.isTweenOperator then
            handler(value)
        else
            for index, obj in ipairs(value) do
                foreachIn(obj, handler)
            end
        end
    else
        handler(value)
    end
end

---@param value any[]
---@param handler fun(tween : TweenBase)
local function foreachTweenIn(value, handler)
    foreachIn(value, function(obj)
        if type(obj) == "table" and obj.isTween and not value.isSequence then
            handler(obj)
        end
    end)
end

---@class SequenceStatus : TweenBaseStatus
local status = extends(super) 

status._objList = nil
status._curIndex = nil

function status:init(params)
    self._objList = {}
    super.init(self, params)
end

function status:restart()
    super.restart(self)
    self._curIndex = 1
    self:resetAllObj()
end

function status:resetAllObj()
    foreachTweenIn(self._objList, function(tween) 
        tween:reset()
    end)
end

function status:add(value)
    local obj = self:_GetObj(value)
    self:_checkIsTweenAndSet(obj)
    table.insert(self._objList, obj)
end

function status:moveToNext()
    self._curIndex = self._curIndex + 1
end

function status:cur()
    return self._objList[self._curIndex]
end

function status:isStepCompleted()
    return self._curIndex > #(self._objList)
end

---@private
---@param tweener Tweener
function status:updateForTweener(tweener, deltaTime)
    tweener:update(deltaTime)

    if tweener:isFinished() then
        self:moveToNext()
    end
end

---@private
---@param tweenerList table<number, Tweener>
function status:updateForTweenerList(tweenerList, deltaTime)
    local isAllFinished = true

    for _, tweener in ipairs(tweenerList) do
        tweener:update(deltaTime)

        if not tweener:isFinished() then
            isAllFinished = false
        end
    end

    if isAllFinished then
        self:moveToNext()
    end
end

---@param any TweenBaseOperator | any
---@return any
function status:_GetObj(any)
    if type(any) == "table" then
        if any.isTweenOperator then
            return any._tweenBase
        elseif any.isOperatorList then
            local result = { isTweenList = true }
            for index, subAny in ipairs(any) do
                result[index] = self:_GetObj(subAny)
            end
            return result
        end
    end

    return any
end

---@param any TweenBase | TweenBase[]
function status:_checkIsTweenAndSet(any)
    foreachTweenIn(any, function(tween)
        tween.status:setIsInSequence(true)
    end)
end

function status:destroy()
    foreachTweenIn(self._objList, function(tween)
        tween:destroy()
    end)
end

return status