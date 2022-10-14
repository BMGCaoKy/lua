local extends = require "core.tools".extends
local super = require "core.base.operator"

---@class SequenceOperator : TweenBaseOperator
local operator = extends(super)

operator._sequence = nil  ---@type Sequence

---@param sequence Sequence
function operator:init(sequence, tid)
	super.init(self, sequence, tid)
	self._sequence = sequence
end

---添加一个延时
---@param time number
function operator:addDelay(time)
	self._sequence:add(time)

	return self
end

---添加数个并行的的缓动
---@vararg TweenBaseOperator[]
function operator:addParallel(...)
	local tweenList = {...}
	tweenList.isOperatorList = true
	self._sequence:add(tweenList)

	return self
end

---添加一个或数个链式执行的缓动
---@vararg TweenBaseOperator[]
function operator:add(...)
	for k, tweener in ipairs({...}) do
		self._sequence:add(tweener)
	end

	return self
end

---添加一个回调函数
function operator:addCallBack(callBack, ...)
	if type(callBack) ~= "function" then
		pcall(error("请传入一个函数!"))
		return self
	end

	return self:_addCallBack(callBack, ...)
end

---添加一个回调函数，函数为空时不报错
function operator:addCallBackSafely(callBack, ...)
	if type(callBack) ~= "function" then
		return self
	end

	return self:_addCallBack(callBack, ...)
end

---@private
function operator:_addCallBack(callBack, ...)
	self._sequence:add({
		isCallBack = true,
		callBack = callBack,
		args = table.pack(...)
	})

	return self
end

return operator