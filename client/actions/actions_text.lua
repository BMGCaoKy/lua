local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

local windowType = "WindowsLook/StaticText"

local function isText(instance)
	if Actions.IsInvalidWindow(instance, 1) then return end
	if instance.__windowType == windowType then
		return true
	else
		Lib.logError("there is a invalid instance !!!", instance.__windowType,  windowType)
		return false
	end
end

function Actions.SetTextContext(data, params, context)
	local instance = params.instance
	local text = params.text
	if not isText(instance) or Actions.IsInvalidStr(text) then
		return 
	end
	instance:getWindow():setText(Lang:toText(text) or "")
end

function Actions.SetTextSize(data, params, context)
	local instance = params.instance
	local size = params.size
	if not size or type(size) ~= "number" or size < 8 or size >72 then
		Lib.logError("Actions.SetTextSize:there is a invalid size !!!", size)
		return
	end
	if isText(instance) then
		instance:getWindow():setFontSize(params.size or 12)
	end
end

function Actions.SetTextColor(data, params, context)
	local instance = params.instance
	local color = params.color
	if not isText(instance) or Actions.IsInvalidColor(color) then
		return
	end
	instance:getWindow():setTextColours(Color3.fromRGB(color.r,color.g,color.b))
end

function Actions.SetIsShowBackground(data, params, context)
	local instance = params.instance
	local isShow = params.isShow
	if not isText(instance) or Actions.IsInvalidBool(isShow) then
		return
	end
	instance:getWindow():setBackgroundEnabled(isShow or false)
end

function Actions.SetIsShowFrame(data, params, context)
	local instance = params.instance
	local isShow = params.isShow
	if not isText(instance) or Actions.IsInvalidBool(isShow) then
		return
	end
	instance:getWindow():setFrameEnabled(isShow or false)
end

function Actions.GetTextContext(data, params, context)
	local instance = params.instance
	if isText(instance) then
		return instance:getWindow():getText()
	end
end

function Actions.IsText(data, params, context)
	local instance = params.instance
	if instance.__windowType == windowType then
		return true
	else
		return false
	end
end