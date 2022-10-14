---@class SequenceOperator : TweenBaseOperator
local operator = {}

---@return SequenceOperator
function operator:setAutoKill(value) end

---@param count number
---@param loopType LoopType
---@overload fun(loopCount : number) : SequenceOperator
---@return SequenceOperator
function operator:setLoops(count, loopType) end

---@return SequenceOperator
function operator:setTimeScale(value) end

---@return SequenceOperator
function operator:delay(value) end

---@return SequenceOperator
function operator:onStart(callBack, ...) end

---@return SequenceOperator
function operator:onFinish(callBack, ...) end

---@return SequenceOperator
function operator:onUpdate(callBack, ...) end