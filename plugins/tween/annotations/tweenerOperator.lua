---@class TweenerOperator : TweenBaseOperator
local operator = {}

---@return TweenerOperator
function operator:setAutoKill(value) end

---@param count number
---@param loopType LoopType
---@overload fun(loopCount : number) : TweenerOperator
---@return TweenerOperator
function operator:setLoops(count, loopType) end

---@return TweenerOperator
function operator:setTimeScale(value) end

---@return TweenerOperator
function operator:delay(value) end

---@return TweenerOperator
function operator:onStart(callBack, ...) end

---@return TweenerOperator
function operator:onFinish(callBack, ...) end

---@return TweenerOperator
function operator:onUpdate(callBack, ...) end