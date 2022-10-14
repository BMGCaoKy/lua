-- ============================================================================================
-- 通用Trigger
-- ============================================================================================

--"Trigger_WidgetCreate",
-- WIDGET_CREATE
--Trigger.CheckTriggers(win_instance._cfg, "WIDGET_CREATE", {instance = win_instance, rootInstance = instance})

--"Trigger_WidgetShow",
-- WIDGET_SHOWN
UI:subscribeGlobalEvent("Window/Shown", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			Trigger.CheckTriggers(instance._cfg, "WIDGET_SHOWN", {instance = instance, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_SHOWN", instance = instance})
		end
	end
)

--"Trigger_WidgetHide",
-- WIDGET_HIDDEN		
UI:subscribeGlobalEvent("Window/Hidden", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			Trigger.CheckTriggers(instance._cfg, "WIDGET_HIDDEN", {instance = instance, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_HIDDEN", instance = instance})
		end
	end
)

--"Trigger_WidgetClicked",
--WIDGET_CLICKED
UI:subscribeGlobalEvent("Window/MouseClick", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			local position = eventArgs.position
			Trigger.CheckTriggers(instance._cfg, "WIDGET_CLICKED", {instance = instance, x = position.x, y = position.y, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_CLICKED", instance = instance, x = position.x, y = position.y})
		end
	end
)

--"Trigger_WidgetHoldDown",
--WIDGET_HOLD_DOWN
UI:subscribeGlobalEvent("Window/WindowLongTouchStart", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			local position = eventArgs.position
			Trigger.CheckTriggers(instance._cfg, "WIDGET_HOLD_DOWN", {instance = instance, x = position.x, y = position.y, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_HOLD_DOWN", instance = instance, x = position.x, y = position.y})
		end
	end
)

--"Trigger_WidgetButtonPress",
--WIDGET_TOUCH_PRESS
UI:subscribeGlobalEvent("Window/MouseButtonDown", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			local position = eventArgs.position
			Trigger.CheckTriggers(instance._cfg, "WIDGET_TOUCH_PRESS", {instance = instance, x = position.x, y = position.y, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_TOUCH_PRESS", instance = instance, x = position.x, y = position.y})
		end
	end
)

--"Trigger_WidgetButtonRelease",
--WIDGET_TOUCH_RELEASE
UI:subscribeGlobalEvent("Window/MouseButtonUp", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			local position = eventArgs.position
			local startPosition = eventArgs.startPosition
			Trigger.CheckTriggers(instance._cfg, "WIDGET_TOUCH_RELEASE", {instance = instance, x = position.x, y = position.y, start_x = startPosition.x, start_y = startPosition.y, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_TOUCH_RELEASE", instance = instance, x = position.x, y = position.y, start_x = startPosition.x, start_y = startPosition.y})
		end
	end
)

--"Trigger_WidgetDrag",
--WIDGET_TOUCH_MOVE
UI:subscribeGlobalEvent("Window/MouseMove", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			local position = eventArgs.position
			Trigger.CheckTriggers(instance._cfg, "WIDGET_TOUCH_MOVE", {instance = instance, x = position.x, y = position.y, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_TOUCH_MOVE", instance = instance, x = position.x, y = position.y})
		end
	end
)

--"Trigger_WidgetDragOut",
--WIDGET_TOUCH_OUT_MOVE
UI:subscribeGlobalEvent("Window/MouseOutMove", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			local position = eventArgs.position
			Trigger.CheckTriggers(instance._cfg, "WIDGET_TOUCH_OUT_MOVE", {instance = instance, x = position.x, y = position.y, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_TOUCH_OUT_MOVE", instance = instance, x = position.x, y = position.y})
		end
	end
)

--"Trigger_WidgetDestory",
--WIDGET_DESTORY
--Trigger.CheckTriggers(cfg, "WIDGET_DESTORY", {instance = instance, rootInstance = rootInstance})

--"Trigger_WidgetEnabled",
--WIDGET_ENABLED
UI:subscribeGlobalEvent("Window/Enabled", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			Trigger.CheckTriggers(instance._cfg, "WIDGET_ENABLED", {instance = instance, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_ENABLED", instance = instance})
		end
	end
)

--"Trigger_WidgetDisabled"
--WIDGET_DISABLED
UI:subscribeGlobalEvent("Window/Disabled", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			Trigger.CheckTriggers(instance._cfg, "WIDGET_DISABLED", {instance = instance, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_DISABLED", instance = instance})
		end
	end
)

--""
--WIDGET_CAPTURE_GAINED
--文本输入框, 复选框, 单选按钮
UI:subscribeGlobalEvent("Window/InputCaptureGained", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			Trigger.CheckTriggers(instance._cfg, "WIDGET_CAPTURE_GAINED", {instance = instance, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_CAPTURE_GAINED", instance = instance})
		end
	end
)

--""
--WIDGET_CAPTURE_LOST
--文本输入框, 复选框, 单选按钮
UI:subscribeGlobalEvent("Window/InputCaptureLost", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			Trigger.CheckTriggers(instance._cfg, "WIDGET_CAPTURE_LOST", {instance = instance, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_CAPTURE_LOST", instance = instance})
		end
	end
)


-- ============================================================================================
-- 空窗口
-- ============================================================================================

-- ============================================================================================
-- 文本
-- ============================================================================================

-- ============================================================================================
-- 图片
-- ============================================================================================

-- ============================================================================================
-- 按钮
-- ============================================================================================

-- ============================================================================================
-- 进度条
-- ============================================================================================
--WIDGET_PROGRESSBAR_PROGRESSCHANGED
UI:subscribeGlobalEvent("ProgressBar/ProgressChanged", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			local progress = instance:getWindow():getProgress()
			Trigger.CheckTriggers(instance._cfg, "WIDGET_PROGRESSBAR_PROGRESSCHANGED", {instance = instance, progress = progress, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_PROGRESSBAR_PROGRESSCHANGED", instance = instance, progress = progress})
		end
	end
)

-- ============================================================================================
-- 文本输入框
-- ============================================================================================
--当输入的文本改变时
--WIDGET_EDITBOX_CHANGED
UI:subscribeGlobalEvent("Editbox/TextChanged", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			local text = instance:getWindow():getText()
			Trigger.CheckTriggers(instance._cfg, "WIDGET_EDITBOX_CHANGED", {instance = instance, text = text, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_EDITBOX_CHANGED", instance = instance, text = text})
		end
	end
)

-- ============================================================================================
-- 复选框/单选按钮
-- ============================================================================================
--当复选框切换为选中状态时
--当复选框切换为未选中状态时
UI:subscribeGlobalEvent("ToggleButton/SelectStateChanged", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			local isSelected = instance:getWindow():isSelected()
			if isSelected then
				Trigger.CheckTriggers(instance._cfg, "WIDGET_TOGGLE_SELECTED", {instance = instance, rootInstance = rootInstance})
				--Lib.pv({trigger = "WIDGET_TOGGLE_SELECTED", instance = instance})
			else
				Trigger.CheckTriggers(instance._cfg, "WIDGET_TOGGLE_NO_SELECTED", {instance = instance, rootInstance = rootInstance})
				--Lib.pv({trigger = "WIDGET_TOGGLE_NO_SELECTED", instance = instance})
			end
		end
	end
)

-- ============================================================================================
-- 滑块 - 触发上级控件的Trigger
-- ============================================================================================

UI:subscribeGlobalEvent("Thumb/ThumbMouseDown", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		local parentInstance = instance:getParent()
		if (parentInstance and parentInstance._cfg) then
			local rootInstance = parentInstance._cfg.rootInstance
			local position = eventArgs.position
			Trigger.CheckTriggers(parentInstance._cfg, "WIDGET_TOUCH_PRESS", {instance = parentInstance, x = position.x, y = position.y, rootInstance = rootInstance})
		end
	end
)

UI:subscribeGlobalEvent("Thumb/ThumbMouseUp", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		local parentInstance = instance:getParent()
		if (parentInstance and parentInstance._cfg) then
			local rootInstance = parentInstance._cfg.rootInstance
			local position = eventArgs.position
			Trigger.CheckTriggers(parentInstance._cfg, "WIDGET_TOUCH_RELEASE", {instance = parentInstance, x = position.x, y = position.y, rootInstance = rootInstance})
		end
	end
)

UI:subscribeGlobalEvent("Thumb/ThumbMouseClicked", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		local parentInstance = instance:getParent()
		if (parentInstance and parentInstance._cfg) then
			local rootInstance = parentInstance._cfg.rootInstance
			local position = eventArgs.position
			Trigger.CheckTriggers(parentInstance._cfg, "WIDGET_CLICKED", {instance = parentInstance, x = position.x, y = position.y, rootInstance = rootInstance})
		end
	end
)

-- ============================================================================================
-- 水平/垂直滑动条
-- ============================================================================================
--当滑动条的进度改变时
UI:subscribeGlobalEvent("Slider/ValueChanged", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			local value = instance:getWindow():getCurrentValue()
			Trigger.CheckTriggers(instance._cfg, "WIDGET_SLIDER_CHANGE", {instance = instance, value = value, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_SLIDER_CHANGE", instance = instance, value = value})
		end
	end
)

-- ============================================================================================
-- 滚动面板
-- ============================================================================================

-- ============================================================================================
-- 角色面板
-- ============================================================================================

-- ============================================================================================
-- 水平/垂直/网格布局容器
-- ============================================================================================
--当添加子控件时
UI:subscribeGlobalEvent("LayoutContainer/ChildAdded", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			local child = UI:getWindowInstance(eventArgs.otherWindow)
			Trigger.CheckTriggers(instance._cfg, "LAYOUTCONTAINER_CHILD_ADDED", {instance = instance, child = child, rootInstance = rootInstance})
			--Lib.pv({trigger = "LAYOUTCONTAINER_CHILD_ADDED", instance = instance, child = child})
		end
	end
)

--当移除子控件时
--[[
UI:subscribeGlobalEvent("LayoutContainer/ChildRemoved", 
	function(eventName, eventArgs)
		local instance = UI:getWindowInstance(eventArgs.window)
		if instance and instance._cfg then
			local rootInstance = instance._cfg.rootInstance
			local child = UI:getWindowInstanceOnly(eventArgs.otherWindow)
			Trigger.CheckTriggers(instance._cfg, "LAYOUTCONTAINER_CHILD_REMOVED", {instance = instance, child = child, rootInstance = rootInstance})
			--Lib.pv({trigger = "LAYOUTCONTAINER_CHILD_REMOVED", instance = instance, child = child})
		end
	end
)
]]

-- ============================================================================================
-- 收到消息（sever/client）
-- ============================================================================================
--Trigger.CheckTriggers(nil, "RECEIVE_UI_BTS_MESSAGE", {obj1 = self, msg = msg(消息号), vars = vars(参数)})


--当玩家开始触摸屏幕时
Lib.subscribeEvent(Event.EVENT_SCREEN_TOUCH_BEGIN, 
	function(x, y)
		Trigger.CheckTriggers(nil, "Screen_Touch_Begin", {x = x, y = y})
	end
)

--当玩家触摸屏幕并移动时
Lib.subscribeEvent(Event.EVENT_SCREEN_TOUCH_MOVE, 
	function(x, y)
		Trigger.CheckTriggers(nil, "Screen_Touch_Move", {x = x, y = y})
	end
)

--当玩家停止触摸屏幕时
Lib.subscribeEvent(Event.EVENT_SCREEN_TOUCH_END, 
	function(x, y)
		Trigger.CheckTriggers(nil, "Screen_Touch_End", {x = x, y = y})
	end
)
