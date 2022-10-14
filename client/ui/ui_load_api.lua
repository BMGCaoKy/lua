
--local M = UI
--local guiMgr = L("guiMgr", GUIManager:Instance())

local initWidgetFunc = {}
initWidgetFunc[Enum.WidgetType.Frame] = function(widget)
	--print(Enum.WidgetType.Frame)
end
initWidgetFunc[Enum.WidgetType.Text] = function(widget)
	--print(Enum.WidgetType.Text)
	widget:setText("Here is text")
	widget:setFrameEnabled(false)
end
initWidgetFunc[Enum.WidgetType.Image] = function(widget)
	--print(Enum.WidgetType.Image)
	widget:setImage("_imagesets_|def:def_image")
	widget:setFrameEnabled(false)
end
initWidgetFunc[Enum.WidgetType.Button] = function(widget)
	--print(Enum.WidgetType.Button)
	widget:setText("Button")
end
initWidgetFunc[Enum.WidgetType.ProgressBar] = function(widget)
	--print(Enum.WidgetType.ProgressBar)
end
initWidgetFunc[Enum.WidgetType.Editbox] = function(widget)
	--print(Enum.WidgetType.Editbox)
end
initWidgetFunc[Enum.WidgetType.Checkbox] = function(widget)
	--print(Enum.WidgetType.Checkbox)
	widget:setText("Checkbox")
end
initWidgetFunc[Enum.WidgetType.RadioButton] = function(widget)
	--print(Enum.WidgetType.RadioButton)
	widget:setText("RadioButton")
end
initWidgetFunc[Enum.WidgetType.HorizontalSlider] = function(widget)
	--print(Enum.WidgetType.HorizontalSlider)
end
initWidgetFunc[Enum.WidgetType.VerticalSlider] = function(widget)
	--print(Enum.WidgetType.VerticalSlider)
end
initWidgetFunc[Enum.WidgetType.ScrollableView] = function(widget)
	--print(Enum.WidgetType.ScrollableView)
	widget:setArea2({0, 0}, {0, 0}, {0, 200}, {0, 200})
end
initWidgetFunc[Enum.WidgetType.ActorWindow] = function(widget)
	--print(Enum.WidgetType.ActorWindow)
end
initWidgetFunc[Enum.WidgetType.EffectWindow] = function(widget)
	--print(Enum.WidgetType.EffectWindow)
end

local widgetCount = 1
function UI:CreateGUIWidget(widgetType)
	local name = "widget" .. widgetCount
	widgetCount = widgetCount + 1
	local widget = UI:createWindow(name, widgetType)
	if widget and initWidgetFunc[widgetType] then
		initWidgetFunc[widgetType](widget)
	end
	return widget
end
