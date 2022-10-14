local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

function Actions.BuildUDim2(data, params, context)
	local x_scale = params.x_scale
	local x_offset = params.x_offset
	local y_scale = params.y_scale
	local y_offset = params.y_offset
	if not x_scale or not x_offset or not y_scale or not y_offset then
		Lib.logError("Actions.BuildUDim2:there is a nil value !!!")
		return
	end
	return UDim2.new(x_scale,x_offset,y_scale,y_offset)
end

function Actions.GetUDim2XScale(data, params, context)
	local udim2 = params.udim2
	if Actions.IsInvalidUDim2(udim2) then
		return
	end
	return udim2[1][1]
end

function Actions.GetUDim2XOffset(data, params, context)
	local udim2 = params.udim2
	if Actions.IsInvalidUDim2(udim2) then
		return
	end
	return udim2[1][2]
end

function Actions.GetUDim2YScale(data, params, context)
	local udim2 = params.udim2
	if Actions.IsInvalidUDim2(udim2) then
		return
	end
	return udim2[2][1]
end

function Actions.GetUDim2YOffset(data, params, context)
	local udim2 = params.udim2
	if Actions.IsInvalidUDim2(udim2) then
		return
	end
	return udim2[2][2]
end

function Actions.UDim2Operation(data, params, context)
	local firstUDim2 = params.firstUDim2
	local secondUDim2 = params.secondUDim2
	local compute = params.compute
	if Actions.IsInvalidUDim2(firstUDim2) or Actions.IsInvalidUDim2(firstUDim2) or Actions.IsInvalidOperator(compute) then
		return
	end
	firstUDim2 = UDim2.new(firstUDim2[1][1],firstUDim2[1][2],firstUDim2[2][1],firstUDim2[2][2])
	secondUDim2 = UDim2.new(secondUDim2[1][1],secondUDim2[1][2],secondUDim2[2][1],secondUDim2[2][2])
	if firstUDim2 and secondUDim2 and compute then
		local result
		if compute == "sub" then
			result = firstUDim2 - secondUDim2
		else
			result = firstUDim2 + secondUDim2
		end
		return result
	end
end