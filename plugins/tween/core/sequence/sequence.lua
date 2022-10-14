local extends = require "core.tools".extends
local XPCall = require "core.tools".XPCallByPackArgs
local new = require "core.tools".new
local enum = require "core.enum"
local super = require "core.base.tweenBase"

---@class Sequence : TweenBase
local sequence = extends(super) 

sequence.status = nil   ---@type SequenceStatus
sequence.operator = nil ---@type SequenceOperator
sequence.isSequence = true

function sequence:init(tid)
    super.init(self, tid)
end

function sequence:destroy()
    super.destroy(self)
    self.status:destroy()
    self.operator._sequence = nil
end

function sequence:_onUpdate(deltaTime)
    local status = self.status

    local obj = status:cur()
    local objType = type(obj)

    if objType == "number" then
        status:setDelay(obj)
        status:moveToNext()
    elseif objType == "table" then
        if obj.isTween then
            status:updateForTweener(obj, deltaTime)
        elseif obj.isCallBack then
            XPCall(obj.callBack, obj.args)
            status:moveToNext()
        elseif obj.isTweenList then
            status:updateForTweenerList(obj, deltaTime)
        end
    end
end

function sequence:_onLooping()
    self.status:restart()
    if self.params.loopType == enum.loopType.Yoyo then
        
    end
end

function sequence:add(v)
    self.status:add(v)
end

function sequence:_createStatus(params)
    return new(require"core.sequence.status", params)
end

function sequence:_createOperator(tid)
    return new(require"core.sequence.operator", self, tid)
end

return sequence