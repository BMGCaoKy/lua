local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

local function getActionName(level, index, step)
    level = level or 5
    index = index or 1
    step = step or 0
    local _, v = debug.getlocal(level + step, index)
    return v and v.type or "unknownAction"
end

function Actions.IsInvalidWindow(instance, step)
	if not instance or (instance and not instance.__windowType) then
		Lib.logError("there is a invalid window instance !!!",getActionName(nil, nil, step))
		return true
	end
end

function Actions.IsInvalidUDim2(instance, step)
	if instance then
		if instance[1] and instance[1][1] and instance[1][2] and instance[2] and instance[2][2] then
			return false
		end
	end
	Lib.logError("there is a invalid UDim2 instance !!!",getActionName(nil, nil, step), instance)
	return true
end

function Actions.IsInvalidColor(instance, step)
	if instance then
		if instance.r and instance.g and instance.b then
			return false
		end
	end
	Lib.logError("there is a invalid color instance !!!",getActionName(nil, nil, step), instance)
	return true
end

function Actions.IsInvalidRotation(instance, step)
	if instance then
		if instance.x and instance.y and instance.z then
			return false
		end
	end
	Lib.logError("there is a invalid rotation instance !!!",getActionName(nil, nil, step), instance)
	return true
end

function Actions.IsInvalidAnchor(instance, step)
	if instance then
		if instance.hAlignment and instance.vAlignment then
			return false
		end
	end
	Lib.logError("there is a invalid anchor instance !!!",getActionName(nil, nil, step), instance)
	return true
end

function Actions.IsInvalidOperator(operator, step)
	if operator == "add" or operator == "sub" then
		return false
	end
	Lib.logError("there is a invalid operator instance !!!",getActionName(nil, nil, step), operator)
	return true
end

function Actions.IsInvalidStr(str, step)
	if str and type(str)=="string" then
		return false
	end
	Lib.logError("there is a invalid string !!!",getActionName(nil, nil, step), str)
	return true
end

function Actions.IsInvalidNum(num, step)
	if num and type(num)=="number" then
		return false
	end
	Lib.logError("there is a invalid number !!!",getActionName(nil, nil, step), num)
	return true
end

function Actions.IsInvalidBool(num, step)
	if num == false or num == true then
		return false
	end
	Lib.logError("there is a invalid boolean !!!",getActionName(nil, nil, step), num)
	return true
end

function Actions.Table(node, params, context)
	return params
end
