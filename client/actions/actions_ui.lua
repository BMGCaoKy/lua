local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

function Actions.CreateWindow(data, params, context)
	local res = params.res
	local name = params.name
	if Actions.IsInvalidStr(res) or Actions.IsInvalidStr(name) then
		return 
	end
	if name == "" or name == nil then
		local temp = string.gmatch(res, "[^/]*$")
		name = temp()
	end
	if res then
		local window,error = UI:openWindow(res, name)
		if error then
			local info = string.format("CreateWindow: A widget named %s already exists, so the name of the widget named %s cannot be set.",name,name)
			 Lib.logError(info)
			 return
		end
		return window
	end
end

function Actions.DestroyWidget(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	instance:close()

end

function Actions.IsDestoryWidget(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	local window = instance.__window
	return window:isDestroy()

end

function Actions.GetWidgetByHierarchy(data, params, context)
	local instance = params.instance
	local hierarchy = params.hierarchy
	if Actions.IsInvalidWindow(instance) or Actions.IsInvalidStr(hierarchy) then
		return 
	end
	if hierarchy == "" then
		return Instance
	end
	local window = instance:findChildByName(hierarchy)
	if window then
		return UI:getWindowInstance(window)
	end
end

function Actions.GetChildWidgetByName(data, params, context)
	local instance = params.instance
	local name = params.name
	if Actions.IsInvalidWindow(instance) or Actions.IsInvalidStr(name) then
		return 
	end
	return instance:child(name) or nil
end

function Actions.GetWindowByName(data, params, context) --查找所有的layout不区分编辑器和引擎
	local name = params.name
	if Actions.IsInvalidStr(name) then
		return 
	end
	local guiMgr = GUIManager:Instance()  
	local root = guiMgr:getRootWindow()
	if root:isChildName(name) then
		local window = root:getChildElement(name)
		return UI:getWindowInstance(window)
	end
end

function Actions.SetChildWidgetForWidget(data, params, context)
	local parentWidget = params.parentWidget
	local childWidget = params.childWidget
	if Actions.IsInvalidWindow(parentWidget) or Actions.IsInvalidWindow(childWidget) then
		return
	end
	
	local isExistChild = parentWidget:getWindow():isExistChild(childWidget:getWindow())
	if isExistChild then
		local childName = childWidget.__windowName
		local info = string.format("SetChildWidgetForWidget: A widget named %s already exists, so the name of the widget named %s cannot be set.",childName,childName)
		Lib.logError(info)
		return
	else
		UI:addChild(parentWidget, childWidget)
	end
end

function Actions.GetParentWidget(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	local parent = instance:getWindow():getParent() or nil
	if parent then
		return UI:getWindowInstance(parent)
	end
end

function Actions.IsChildWidget(data, params, context)
	local parentWidget = params.parentWidget
	local childWidget = params.childWidget
	if Actions.IsInvalidWindow(parentWidget) or Actions.IsInvalidWindow(childWidget) then
		return
	end
	return parentWidget:getWindow():isChild(childWidget:getWindow())
end

function Actions.GetWindowByWidget(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	local rootInstance = instance._cfg.rootInstance
	return rootInstance
end

function Actions.SetWindowName(data, params, context)
	local instance = params.instance
	local name = params.name
	if Actions.IsInvalidWindow(instance) or Actions.IsInvalidStr(name) then
		return
	end
	if instance:getWindow():isExistName(name) then
		local info = string.format("SetWindowName: A widget named %s already exists, so the name of the widget named %s cannot be set.",name,name)
		Lib.logError(info)
		return
	else
		instance:getWindow():setName(name)
	end
	--TODO
end

function Actions.SetWindowIsShow(data, params, context)
	local instance = params.instance
	local visible = params.visible
	if Actions.IsInvalidWindow(instance) or Actions.IsInvalidBool(visible) then
		return
	end
	instance:getWindow():setVisible(visible)
end

function Actions.SetWindowAnchor(data, params, context)
	local instance = params.instance
	local anchor = params.anchor
	if Actions.IsInvalidWindow(instance) or Actions.IsInvalidAnchor(anchor) then
		return
	end
	instance:getWindow():setHorizontalAlignment(anchor.hAlignment)
	instance:getWindow():setVerticalAlignment(anchor.vAlignment)
end

function Actions.SetWindowPos(data, params, context)
	local instance = params.instance
	local pos = params.pos
	if Actions.IsInvalidWindow(instance) or Actions.IsInvalidUDim2(pos) then
		return
	end
	instance:getWindow():setXPosition(UDim.new(pos[1][1],pos[1][2]))
	instance:getWindow():setYPosition(UDim.new(pos[2][1],pos[2][2]))
	--instance:getWindow():setPosition(UDim2.new(pos[1][1],pos[1][2],pos[2][1],pos[2][2]))--角色窗口不适用
end

function Actions.SetWindowSize(data, params, context)
	local instance = params.instance
	local size = params.size
	if Actions.IsInvalidWindow(instance) or Actions.IsInvalidUDim2(size) then
		return
	end
	instance:getWindow():setSize(UDim2.new(size[1][1],size[1][2],size[2][1],size[2][2]))
end

function Actions.SetWindowRotation(data, params, context)
	local instance = params.instance
	local rotation = params.rotation
	if Actions.IsInvalidWindow(instance) or Actions.IsInvalidRotation(rotation) then
		return
	end
	instance:getWindow():setProperty("Rotation",GUILib.deg2QuaternionStr(rotation.x, rotation.y, rotation.z))
end

function Actions.SetWindowAlpha(data, params, context)
	local instance = params.instance
	local alpha = params.alpha
	if Actions.IsInvalidWindow(instance) or Actions.IsInvalidNum(alpha) then
		return
	end
	instance:getWindow():setAlpha(alpha)
end

function Actions.SetIsClipByParentWidget(data, params, context)
	local instance = params.instance
	local isClip = params.isClip
	if Actions.IsInvalidWindow(instance) or Actions.IsInvalidBool(isClip) then
		return
	end
	instance:getWindow():setClippedByParent(isClip)
end

function Actions.SetIsDisableWidget(data, params, context)
	local instance = params.instance
	local isDisable = params.isDisable
	if Actions.IsInvalidWindow(instance) or Actions.IsInvalidBool(isDisable) then
		return
	end
	instance:getWindow():setDisabled(isDisable)
end

function Actions.SetIsAbleTouchThrough(data, params, context)
	local instance = params.instance
	local isAble = params.isAble
	if Actions.IsInvalidWindow(instance) or Actions.IsInvalidBool(isAble) then
		return
	end
	instance:getWindow():setMousePassThroughEnabled(isAble)
end

function Actions.SetIsTop(data, params, context)
	local instance = params.instance
	local isTop = params.isTop
	if Actions.IsInvalidWindow(instance) or Actions.IsInvalidBool(isTop) then
		return
	end
	instance:getWindow():setAlwaysOnTop(isTop)
end

function Actions.GetWindowIsShow(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	return instance:getWindow():isVisible()
end

function Actions.GetWindowPos(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	local xPos = instance:getWindow():getXPosition()
	local yPos = instance:getWindow():getYPosition()
	return UDim2.new(xPos[1],xPos[2],yPos[1],yPos[2])
	--return instance:getWindow():getPosition() 角色窗口不适用
end

function Actions.GetWindowSize(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	return instance:getWindow():getSize()
end

function Actions.GetWindowRotation(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	local quaternion = instance:getWindow():getRotation()
	local rotation = GUILib.quaternion2Deg(quaternion.w, quaternion.x, quaternion.y, quaternion.z)
	return {x = rotation[1], y = rotation[2], z = rotation[3]}
end

function Actions.GetWindowAlpha(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	return instance:getWindow():getAlpha()
end

function Actions.GetIsClipByParentWidget(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	return instance:getWindow():isClippedByParent()
end

function Actions.GetIsDisableWidget(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	return instance:getWindow():isDisabled()
end

function Actions.GetIsAbleTouchThrough(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	return instance:getWindow():isMousePassThroughEnabled()
end

function Actions.GetWindowXPos(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	local pos = instance:getWindow():getPixelPosition()
	return pos.x
end

function Actions.GetWindowYPos(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	local pos = instance:getWindow():getPixelPosition()
	return pos.y
end

function Actions.GetWindowWidth(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	local windowSize = instance:getWindow():getPixelSize()
	return windowSize.width
end

function Actions.GetWindowHeight(data, params, context)
	local instance = params.instance
	if Actions.IsInvalidWindow(instance) then
		return
	end
	local windowSize = instance:getWindow():getPixelSize()
	return windowSize.height
end
