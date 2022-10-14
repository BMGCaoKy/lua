local guiMgr = L("guiMgr", GUIManager:Instance())
if not guiMgr:isEnabled() then
	print("useNewUI: false")
	return
end
print("begin init ui_handler")

--require "common.profiler"
--require "common.profiler_lib"

UI.usePool = guiMgr:isUseUIPool()
UI.windowPool = {}

local winMgr = L("winMgr", CEGUIWindowManager:getSingleton())
---@type table<number, CEGUILayout>
local windowInstanceMap = T(UI, "windowInstanceMap")
local sceneWindowsMap = T(UI, "sceneWindowsMap")
local sceneWindowOpenParamsMap = T(UI, "sceneWindowOpenParamsMap")
local windowOpenParamsMap = T(UI, "windowOpenParamsMap")
local globalEventHandlerMap = T(UI, "globalEventHandlerMap")
local waitCloseSceneWindowMap = T(UI, "waitCloseSceneWindowMap")
local Recorder = T(Lib, "Recorder")

require "ui.ui_load_resgroup"
UI:loadPluginsUIResGroupDir()

--guiMgr:setResGroupDir("asset:gui_layouts", Root.Instance():getGamePath().."asset/gui/layouts")
--guiMgr:setResGroupDir("asset:gui_imagesets", Root.Instance():getGamePath().."asset/gui/imagesets")
--guiMgr:setResGroupDir("asset:gui_fonts", Root.Instance():getGamePath().."asset/gui/fonts")
--guiMgr:setResGroupDir("asset:gui_looknfeel", Root.Instance():getGamePath().."asset/gui/looknfeel")
--guiMgr:setResGroupDir("asset:gui_schemes", Root.Instance():getGamePath().."asset/gui/schemes")
--guiMgr:setResGroupDir("asset:gui_animations", Root.Instance():getGamePath().."asset/gui/animations")

guiMgr:loadSchemeFile("WindowsLook.scheme")
if PlatformUtil.isPlatformWindows() then
	guiMgr:loadSchemeFile("Engine.scheme")
else
	guiMgr:loadSchemeFile("EngineMobile.scheme")
end

local function isAlive(window)
	return window and winMgr:isAlive(window)
end

local function getWindowInstance(window)
	if(window) then
		return UI:getWindowInstance(window)
	else
		return nil
	end
end

local function setWindowInstance(instance)
	if(instance) then
		return instance.__window
	else
		return nil
	end
end

local function getWindowInstanceChilds(childs)
	for i = 1,#childs do
		childs[i] = getWindowInstance(childs[i])
	end
	return childs
end

local function getVector2(vector2)
	return Lib.v2(vector2.x, vector2.y)
end

local function getVector3(vector3)
	return Lib.v3(vector3.x, vector3.y, vector3.z)
end
local function getSizeUDim2(data)
	return Lib.udim2(data.width[1], data.width[2], data.height[1], data.height[2])
end

local function getPositionUDim2(data)
	return Lib.udim2(data[1][1], data[1][2], data[2][1], data[2][2])
end

local function getColor3(color)
	return Lib.ucolor3(color.r, color.g, color.b)
end

local function getBool(value)
	return Lib.toBool(value)
end

local function getNumber(value)
	return tonumber(value)
end

local function getVector3formQuaternion(value)
	local params = Lib.deserializerStrQuaternion(value)
	local w,x,y,z = 1,0,0,0
    if type(params) == "table" and params.w and params.x and params.y and params.z then
        w,x,y,z = params.w, params.x, params.y, params.z
    end
	local v = CEGUIQuaternion.toEulerAnglesDegrees(w,x,y,z)
	return Lib.v3(v.x, v.y, v.z)
end

local function checkWindowParamsValid(...)
	local params = table.pack(...)
	if not params[1] or type(params[1]) ~= "userdata"  then
		return false
	end
	return true
end

function UI:findWindow(windowName, resGroup)
    return guiMgr:findLayoutFile(windowName..".layout", resGroup or "layouts")
end

function UI:loadWindow(windowName, resGroup)
    return guiMgr:loadLayoutFile(windowName..".layout", resGroup or "layouts")
end

local EventMap = {
	onTextChanged = "TextChanged",
	onFontChanged = "FontChanged",
	onAlphaChanged = "AlphaChanged",
	onIDChanged = "IDChanged",
	onActivated = "Activated",
	onDeactivated = "Deactivated",
	onShown = "Shown",
	onHidden = "Hidden",
	onEnabled = "Enabled",
	onDisabled = "Disabled",
	onClippedByParentChanged = "ClippedByParentChanged",
	onDestroyedByParentChanged = "DestroyedByParentChanged",
	onInheritsAlphaChanged = "InheritsAlphaChanged",
	onAlwaysOnTopChanged = "AlwaysOnTopChanged",
	onInputCaptureGained = "InputCaptureGained",
	onInputCaptureLost = "InputCaptureLost",
	onInvalidated = "Invalidated",
	onRenderingStarted = "RenderingStarted",
	onRenderingEnded = "RenderingEnded",
	onDestructionStarted = "DestructionStarted",
	onDragDropItemEnters = "DragDropItemEnters",
	onDragDropItemLeaves = "DragDropItemLeaves",
	onDragDropItemDropped = "DragDropItemDropped",
	onWindowRendererAttached = "WindowRendererAttached",
	onWindowRendererDetached = "WindowRendererDetached",
	onTextParsingChanged = "TextParsingChanged",
	onMarginChanged = "MarginChanged",
	onMouseEntersArea = "MouseEntersArea",
	onMouseLeavesArea = "MouseLeavesArea",
	onMouseEntersSurface = "MouseEntersSurface",
	onMouseLeavesSurface = "MouseLeavesSurface",
	onMouseMove = "MouseMove",
	onMouseOutMove = "MouseOutMove",
	onMouseWheel = "MouseWheel",
	onMouseButtonDown = "MouseButtonDown",
	onMouseButtonUp = "MouseButtonUp",
	onMouseClick = "MouseClick",
	onMouseDoubleClick = "MouseDoubleClick",
	onMouseTripleClick = "MouseTripleClick",

	onWindowTouchDown = "WindowTouchDown",
	onWindowTouchMove = "WindowTouchMove",
	onWindowTouchUp = "WindowTouchUp",
	onWindowClick = "WindowClick",
	onWindowDoubleClick = "WindowDoubleClick",
	onWindowLongTouchStart = "WindowLongTouchStart",
	onWindowLongTouchEnd = "WindowLongTouchEnd",

	onKeyDown = "KeyDown",
	onKeyUp = "KeyUp",
	onCharacterKey = "CharacterKey",
	onSized = "Sized",
	onParentSized = "ParentSized",
	onMoved = "Moved",
	onHorizontalAlignmentChanged = "HorizontalAlignmentChanged",
	onVerticalAlignmentChanged = "VerticalAlignmentChanged",
	onRotated = "Rotated",
	onChildAdded = "ChildAdded",
	onChildRemoved = "ChildRemoved",
	onZOrderChanged = "ZOrderChanged",
	onNonClientChanged = "NonClientChanged",
	onSelectStateChanged = "SelectStateChanged",
	onValidationStringChanged = "ValidationStringChanged",
	onSliderValueChanged = "ValueChanged",
	onReadOnlyModeChanged = "ReadOnlyModeChanged",
	onMaskedRenderingModeChanged = "MaskedRenderingModeChanged",
	onMaximumTextLengthChanged = "MaximumTextLengthChanged",
	onTextSelectionChanged = "TextSelectionChanged",
	onEditboxFull = "EditboxFull",
	onTextAccepted = "TextAccepted",
	onContentPaneChanged = "ContentPaneChanged",
	onAutoSizeSettingChanged = "AutoSizeSettingChanged",
	onContentPaneScrolled = "ContentPaneScrolled",
	onAutoSizeSettingChanged = "AutoSizeSettingChanged",
}

local NewEventMap = {
	OnStateChanged = "SelectStateChanged",
	OnTouchPinch = "TouchPinch",
	OnTouchRotate = "TouchRotate",
	OnChildRemoved = "ChildRemoved",
	OnChildAdded = "ChildAdded",
	OnShown = "Shown",
	OnHidden = "Hidden",
	OnTouchDown = "WindowTouchDown",
	OnTouchMove = "WindowTouchMove",
	OnTouchUp = "WindowTouchUp",
	OnClick = "WindowClick",
	OnTextChanged = "TextChanged",
	OnFontChanged = "FontChanged",
	OnValueChanged = "ValueChanged",
	OnDestroy = "DestructionStarted",
	OnLostFocused = "EditboxLostFocused",
	OnFocused = "EditboxFocused",
}
local ReverseEventMap = {}

local function InitEventMap()
	local WindowSpace = Define.EVENT_SPACE.WINDOW
	local function Init(Map)
		for key, value in pairs(Map) do
			--翻转key-value
			if not ReverseEventMap[value] then
				ReverseEventMap[value] = {}
			end
			table.insert(ReverseEventMap[value], key)

			--注册窗口事件名
			Event:RegisterEvent(key, WindowSpace)
		end
	end

	Init(EventMap)
	Init(NewEventMap)
end

InitEventMap()

function UI:IsNewEvent(eventName)
	if NewEventMap[eventName] then
		return true
	elseif EventMap[eventName] then
		return false
	end
end
--lua2cpp
function UI:EventMap(eventName)
	if EventMap[eventName] then
		return EventMap[eventName]
	else
		return NewEventMap[eventName]
	end
end
--cpp2lua
function UI:ReverseEventMap(eventName)
	return ReverseEventMap[eventName]
end

local PropertyMap = {}

local returnFunc = {
	getWindow = getWindowInstance,
	getChildById = getWindowInstance,
	getChildRecursiveById = getWindowInstance,
	getChildAtIdx = getWindowInstance,
	getParent = getWindowInstance,
	getRootWindow = getWindowInstance,
	GetPixelPosition = getVector2,
	GetPixelSize = getVector2,
	--Clone = getWindowInstance,
	GetChildByName = getWindowInstance,
	GetChildByID = getWindowInstance,
	GetChildren = getWindowInstanceChilds,
}

local checkFunc = {
	setParent = checkWindowParamsValid
}

-- getProperty返回的是字符串类型，为了获取特定类型，使用调用成员方法，再使用getTypeFunc转换类型
local PropertyFuncMap = {
	Parent = {get = "getParent", set = "setParent", getTypeFunc = getWindowInstance, setTypeFunc = setWindowInstance},
	RelativelyPosition = {get = "getRelativelyPosition", set = "setRelativelyPosition", getTypeFunc = getVector2},
	RelativelySize = {get = "getRelativelySize", set = "setRelativelySize", getTypeFunc = getVector2},
	AbsolutelyPosition = {get = "getAbsolutelyPosition", set = "setAbsolutelyPosition", getTypeFunc = getVector2},
	AbsolutelySize = {get = "getAbsolutelySize", set = "setAbsolutelySize", getTypeFunc = getVector2},
	AlignmentFormat = {get = "getAlignmentFormat", set = "setAlignmentFormat"},
	Position = {get = "GetPosition", set = "SetPosition", getTypeFunc = getPositionUDim2},
	Size = {get = "getSize", set = "setSize", getTypeFunc = getSizeUDim2},
	NormalImage = {get = "getNormalImage", set = "setNormalImage"},
	TextBorderColor = {get = "getBorderColor", set = "setBorderColor", getTypeFunc = getColor3},
	NormalTextColor = {get = "getNormalTextColor", set = "setNormalTextColor", getTypeFunc = getColor3},
	PushedTextColor = {get = "getPushedTextColor", set = "setPushedTextColor", getTypeFunc = getColor3},
	DisabledTextColor = {get = "getDisabledTextColor", set = "setDisabledTextColor", getTypeFunc = getColor3},
	TextOffset = {get = "getTextOffset", set = "setTextOffset", getTypeFunc = getVector2},
	VerticalProgress = {get = "getVerticalProgress", set = "setVerticalProgress"},
	ReversedProgress = {get = "getReversedProgress", set = "setReversedProgress"},
	SelectionColor = {get = "getSelectionColor", set = "setSelectionColor", getTypeFunc = getColor3},
	SelectedTextColor = {get = "getSelectedTextColor", set = "setSelectedTextColor", getTypeFunc = getColor3},

	-- 滑动面板
	VerticalMovable = {get = "isMoveVerticalAble", set = "setMoveVerticalAble"},
	HorizontalMovable = {get = "isMoveHorizontalAble", set = "setMoveHorizontalAble"},
	VerticalBarPos = {get = "getVerticalScrollPosition", set = "setVerticalScrollPosition"},
	HorizontalBarPos = {get = "getHorizontalScrollPosition", set = "setHorizontalScrollPosition"},
	ShowVerticalScrollbar = {get = "isVertScrollbarAlwaysShown", set = "setShowVertScrollbar"},
	ShowHorizontalScrollbar = {get = "isHorzScrollbarAlwaysShown", set = "setShowHorzScrollbar"},
	ReboundTime = {get = "getReboundTime", set = "setReboundTime"},
	InertiaRate = {get = "getInertiaRate", set = "setInertiaRate"},
	ScrollRestrictType = {get = "getScrollRestrictType", set = "setScrollRestrictType"},
	BackgroundImage = {get = "getScrollableViewBackgroundImage", set = "setScrollableViewBackgroundImage"},
	-- 滑动面板

	--布局容器
	ChildrenSize = {get = "getChildrenSize", set = "setChildrenSize", getTypeFunc = getVector2},
	FillMaxCells = {get = "getMaxCell", set = "setMaxCell"},
	FillHorizontal = {get = "getFillHorizontal", set = "setFillHorizontal"},

    --角色窗口
	Actor = {get = "getActorName", set = "setActorName"},
	ActorAction = {get = "getSkillName", set = "setSkillName"},
	ActorScale = {get = "getActorScale", set = "setActorScale"},
	ActorPosition = {get = "getPosition", set = "setPosition", getTypeFunc = getVector3},
	ActorRotation = {get = "getRotation", set = "setRotation", getTypeFunc = getVector3},

	--特效窗口
	Effect = {get = "getEffectName", set = "setEffectName"},
	EffectPosition = {get = "getEffectPosition", set = "setEffectPosition", getTypeFunc = getVector2},
	EffectRotation = {get = "getEffectRotation", set = "setEffectRotation", getTypeFunc = getVector3},
	EffectScale = {get = "getEffectScale", set = "setEffectScale"},
	Loop = {get = "getIsLoop", set = "setIsLoop"},

	--复选框
	UnSelectedTextColor = {get = "getUnSelectedTextColor", set = "setUnSelectedTextColor", getTypeFunc = getColor3},
}

local PropertyRenderFuncMap = {
	TextColor = {get = "getTextColours", set = "setTextColours", getTypeFunc = getColor3},
	BackgroundColor = {get = "getBackgroundColor", set = "setBackgroundColor", getTypeFunc = getColor3},
	ImageColor = {get = "getImageColor", set = "setImageColor", getTypeFunc = getColor3},
	--图片控件
	FillingAngle = {get = "getFillType", set = "setFillType"},
	FillingPosition = {get = "getFillOriginAll", set = "setFillOriginAll"},
	FillingAmount = {get = "getFill", set = "setFill"},
	CounterclockWiseFilling = {get = "getAntiClockwise", set = "setAntiClockwise"},
}

local RenderFuncMap = {
	SetUrlImage = "setUrlImage",
}

local BaseWindowPropertyTypeFunc = {
	Alpha = { getTypeFunc = getNumber },
	Disabled = { getTypeFunc = getBool },
	Visible = { getTypeFunc = getBool },
	Level = { getTypeFunc = getNumber },
	TouchThrough = { getTypeFunc = getBool },
	ClippedByParent = { getTypeFunc = getBool },
	SiblingOrder = { getTypeFunc = getNumber },
	Rotation = {getTypeFunc = getVector3formQuaternion},
}

local PropertyTypeFunc = {
	["DefaultWindow"] = {},
	[Enum.WidgetType.Frame] = {},
	[Enum.WidgetType.Text] = {
		TextHorizontalFormat = { getTypeFunc = getNumber },
		TextVerticalFormat = { getTypeFunc = getNumber },
		WordWrapped = { getTypeFunc = getBool },
		WordBreak = { getTypeFunc = getBool },
		AutoTextSize = { getTypeFunc = getBool },
		AutoFrameSize = { getTypeFunc = getNumber },
		MinAutoTextSize = { getTypeFunc = getNumber },
		FontSize = { getTypeFunc = getNumber },
		FontWeight = { getTypeFunc = getNumber },
		TextBorderWidth = { getTypeFunc = getNumber },
		TextWidth = { getTypeFunc = getNumber },
		TextHeight = { getTypeFunc = getNumber },
		BackgroundEnabled = { getTypeFunc = getBool },
	},
	[Enum.WidgetType.Image] = {
		BackgroundEnabled = { getTypeFunc = getBool },
		ImageBlendMode = { getTypeFunc = getNumber },
	},
	[Enum.WidgetType.Button] = {
		FontSize = { getTypeFunc = getNumber },
		AutoTextSize = { getTypeFunc = getBool },
		MinAutoTextSize = { getTypeFunc = getNumber },
		FontWeight = { getTypeFunc = getNumber },
		WordWrapped = { getTypeFunc = getBool },
		WordBreak = { getTypeFunc = getBool },
		TextBorderWidth = { getTypeFunc = getNumber },
	},
	[Enum.WidgetType.ProgressBar] = {
		Progress = { getTypeFunc = getNumber },
	},
	[Enum.WidgetType.Editbox] = {
		ReadOnly = { getTypeFunc = getBool },
		UseMasked = { getTypeFunc = getBool },
		CharLimit = { getTypeFunc = getNumber },
		CaretPos = { getTypeFunc = getNumber },
		FontSize = { getTypeFunc = getNumber },
		FontWeight = { getTypeFunc = getNumber },
	},
	[Enum.WidgetType.Checkbox] = {
		Selected = { getTypeFunc = getBool },
		FontSize = { getTypeFunc = getNumber },
		FontWeight = { getTypeFunc = getNumber },
	},
	[Enum.WidgetType.RadioButton] = {
		Selected = { getTypeFunc = getBool },
		GroupID = { getTypeFunc = getNumber },
		FontSize = { getTypeFunc = getNumber },
		FontWeight = { getTypeFunc = getNumber },
	},
	[Enum.WidgetType.HorizontalSlider] = {
		Value = { getTypeFunc = getNumber },
		MinValue = { getTypeFunc = getNumber },
		MaxValue = { getTypeFunc = getNumber },
		WholeNumbers = { getTypeFunc = getBool },
		ClickStep = { getTypeFunc = getNumber },
		MoveByStep = { getTypeFunc = getBool },
	},
	[Enum.WidgetType.VerticalSlider] = {
		Value = { getTypeFunc = getNumber },
		MinValue = { getTypeFunc = getNumber },
		MaxValue = { getTypeFunc = getNumber },
		WholeNumbers = { getTypeFunc = getBool },
		ClickStep = { getTypeFunc = getNumber },
		MoveByStep = { getTypeFunc = getBool },
	},
	[Enum.WidgetType.ScrollableView] = {
		Resistance = { getTypeFunc = getNumber },
	},
	[Enum.WidgetType.ActorWindow] = {},
	[Enum.WidgetType.EffectWindow] = {},
	[Enum.WidgetType.HorizontalLayoutContainer] = {
		Space = { getTypeFunc = getNumber },
		ControlChildrenSize = { getTypeFunc = getBool },
	},
	[Enum.WidgetType.VerticalLayoutContainer] = {
		Space = { getTypeFunc = getNumber },
		ControlChildrenSize = { getTypeFunc = getBool },
	},
	[Enum.WidgetType.GridView] = {
		Space = { getTypeFunc = getVector2 },
		ControlChildrenSize = { getTypeFunc = getBool },
	},
}

for _, widgetTypeTab in pairs(PropertyTypeFunc) do
	for funcName, funcTab in pairs(BaseWindowPropertyTypeFunc) do
		widgetTypeTab[funcName] = funcTab
	end
end

local eventInterface = {}

local function getFromClass(className, key)
	local class = assert(rawget(_G, className), "unknow class: "..tostring(className))
	local value = class[key]
	if type(value) == "function" then
		return function(self, ...)
			if not isAlive(self.__window) then
				return
			end
			local params = table.pack(...)
			for i = 1, params.n do
				local v = select(i, ...)
				if type(v) == "table" and rawget(v, "__window") then
					params[i] = v.__window
				else
					params[i] = v
				end
			end
			if checkFunc[key] and not checkFunc[key](...) then
				return
			end
			local ret = value(self.__window, table.unpack(params, 1, params.n))
			if returnFunc[key] then
				return returnFunc[key](ret)
			end
			return ret
		 end
	elseif value ~= nil then
		return value
	end
	local i = 0
	while value == nil do
		local name = class["__parent"..i]
		if not name then
			break
		end
		value = getFromClass(name, key)
		i = i + 1
	end
	return value
end

local WINDOW_MT = {
	__index = function(instance, key)
		if eventInterface[key] then
			return eventInterface[key]
		end

		if UI:EventMap(key) and UI:IsNewEvent(key) == false then
			return instance:GetSingleBindFunction(key)
		end

		local window = instance.__window
		if not isAlive(window) then
			return nil
		end
		local winType = instance.__windowType
		PropertyMap[winType] = PropertyMap[winType] or {}
		if type(key) == "number" then
			if key ~= math.tointeger(key) then
				return nil
			elseif key < 0 or key >= window:getChildCount() then
				return nil
			end
			local child = window:getChildAtIdx(key)
			return UI:getWindowInstance(child)
		end
		if type(key) ~= "string" then
			return nil
		elseif instance.__callFunc[key] then
			return instance.__callFunc[key]
		elseif window:isChildName(key) then
			local child = window:getChildByName(key)
			return UI:getWindowInstance(child)
		-- 根据属性名调用WindowRenderer方法
		elseif PropertyRenderFuncMap[key] and instance:getWindowRenderer() and getFromClass(instance:getWindowRenderer().__name, PropertyRenderFuncMap[key].get) then
			if PropertyRenderFuncMap[key].getTypeFunc then
				return PropertyRenderFuncMap[key].getTypeFunc(instance:getWindowRenderer()[PropertyRenderFuncMap[key].get](instance:getWindowRenderer()))
			end
			return instance:getWindowRenderer()[PropertyRenderFuncMap[key].get](instance:getWindowRenderer())
		elseif PropertyFuncMap[key] and instance[PropertyFuncMap[key].get] then
			if PropertyFuncMap[key].getTypeFunc then
				return PropertyFuncMap[key].getTypeFunc(window[PropertyFuncMap[key].get](window))
			end
			return window[PropertyFuncMap[key].get](window)
		elseif PropertyMap[winType][key] or window:isPropertyPresent(key) then
			if not PropertyMap[winType][key] then
				PropertyMap[winType][key] = true
			end
			if PropertyTypeFunc[winType] and PropertyTypeFunc[winType][key] then
				local getFunc = PropertyTypeFunc[winType][key].getTypeFunc
				if getFunc then
					return getFunc(window:getProperty(key))
				end
			end
			return window:getProperty(key)
		-- 返回WindowRenderer方法
		elseif RenderFuncMap[key] and getFromClass(instance:getWindowRenderer().__name, RenderFuncMap[key]) then
			return function (wnd,...)
				return instance:getWindowRenderer()[RenderFuncMap[key]](instance:getWindowRenderer(),...)
			end
		else
			local ret = getFromClass(window.__name, key)
			if type(ret) == "function" then
				instance.__callFunc[key] = ret
			end
			return ret
		end
	end,
	__newindex = function(instance, key, value)
		local window = instance.__window
		if not isAlive(window) then
			return nil
		end
		local winType = instance.__windowType
		PropertyMap[winType] = PropertyMap[winType] or {}
		if UI:EventMap(key) and UI:IsNewEvent(key) == false then
			if value ~= nil then
				local typ = type(value)
				assert(typ == "function", "expect function, get "..typ)
				local bindableEvent = instance:GetSingleEvent(key)
				if bindableEvent then bindableEvent:Bind(value) end
			else
				instance:DestroySingleBind(key)
			end
		elseif PropertyRenderFuncMap[key] and instance:getWindowRenderer() and getFromClass(instance:getWindowRenderer().__name, PropertyRenderFuncMap[key].set) then
			if PropertyRenderFuncMap[key].setTypeFunc then
				return instance:getWindowRenderer()[PropertyRenderFuncMap[key].set](instance:getWindowRenderer(),PropertyRenderFuncMap[key].setTypeFunc(value))
			end
			return instance:getWindowRenderer()[PropertyRenderFuncMap[key].set](instance:getWindowRenderer(),value)
		elseif PropertyFuncMap[key] and instance[PropertyFuncMap[key].set] then
			if PropertyFuncMap[key].setTypeFunc then
				local v = PropertyFuncMap[key].setTypeFunc(value)
				if v then
					return window[PropertyFuncMap[key].set](window,PropertyFuncMap[key].setTypeFunc(value))
				end
			end
			return window[PropertyFuncMap[key].set](window,value)
		elseif PropertyMap[winType][key] or window:isPropertyPresent(key) then
			if not PropertyMap[winType][key] then
				PropertyMap[winType][key] = true
			end
			if(type(value) == "boolean" or type(value) == "number") then
				value = tostring(value)
			elseif type(value) == "table" and value.toCEGUIPropetryString then
				value = value:toCEGUIPropetryString()
			end
			return window:setProperty(key, value)
		else
			rawset(instance, key, value)
		end
	end,
}

--窗口类注册事件系统接口
Event:InterfaceForTable(eventInterface, Define.EVENT_SPACE.WINDOW, Define.EVENT_POOL.WINDOW)

local function child(self, name)
	local element = self:getChildElementRecursive(name)
	if element then
		return UI:getWindowInstance(element)
	end
	return nil
end

---@return CEGUILayout
---@param window CEGUIWindow
function UI:getWindowInstance(window, autoCreate)
	if not window then
		return nil
	end
	if type(window) == "number" then
		return windowInstanceMap[window]
	end
	--assert(window, "need a window or id")
	--if not window or not isAlive(window) then
	--	return nil
	--end
	local id = window:getID()
	local instance = windowInstanceMap[id]
	if not instance and autoCreate ~= false then
		---@class CEGUILayout : CEGUIWindow
		local base = {
			__window = window,
			__handlers = {},
			__windowName = window:getName(),
			__windowType = window:getType(),
			__allEvent = {},
			__callFunc = {},
			getProperties = function() return guiMgr:getWindowProperties(window) end,
			close = function(...) UI:closeWindow(instance, ...) end,
			destroy = function(...) UI:closeWindow(instance, ...) end,
			Destroy = function(...) UI:closeWindow(instance, ...) end,
			---@param self CEGUILayout
			getWindow = function(self) return window end,
			---@param self CEGUILayout
			child = function(self, name) return child(self, name) end,
			isAlive = function() return winMgr:isAlive(window) end,
			clone = function(deepCopy)
				local winInstance = UI:getWindowInstance(window:clone(deepCopy ~= false))
				local uniqueName = winMgr:generateUniqueWindowName()
				winInstance:setName(uniqueName)
				winInstance.__windowName = uniqueName
				return winInstance
			end,
			Clone = function(deepCopy)
				local winInstance = UI:getWindowInstance(window:clone(deepCopy ~= false))
				local uniqueName = winMgr:generateUniqueWindowName()
				winInstance:setName(uniqueName)
				winInstance.__windowName = uniqueName
				return winInstance
			end,
			IsValid = function()
				return winMgr:isAlive(window)
			end
		}
		---@param self CEGUILayout
		base.subscribeEvent = function(self, name, func)
			local doFunc, index = Lib.lightSubscribeEvent(Lib.getCallTag() .. "-" .. name, name, func)
			table.insert(self.__allEvent, { name = name, doFunc = doFunc, index = index, })
		end
		---@param self CEGUILayout
		base.unsubscribeAllEvent = function(self)
			for _, event in pairs(self.__allEvent) do
				event.doFunc()
			end
			self.__allEvent = {}
		end
		instance = setmetatable(base, WINDOW_MT)
		windowInstanceMap[id] = instance
	end
	return instance
end

local function releaseWindowInstance(id,...)
	local instance = windowInstanceMap[id]
	if not instance then
		return
	end
	local window = instance.__window

	if type(rawget(instance, "onDestroy")) == "function" then
		instance:onDestroy(...)
	end

	--if not isAlive(window) then
		--windowInstanceMap[id] = nil
		--return nil
	--end

	if UI.usePool then
		if not window:getParent() then
			local windowName = window:getLayoutFileName()
			if windowName ~= "" then
				UI.windowPool[windowName] = UI.windowPool[windowName] or {}
				local windowPool = UI.windowPool[windowName]
				table.insert(windowPool, window)
				--print("UI close " .. windowName .. " to pool " .. #windowPool)
			end
		end
	end

	instance:DestroySelfEvent()
	if instance.unsubscribeAllEvent then
		instance:unsubscribeAllEvent()
	end
	local cfg = instance._cfg
	if cfg then
		local rootInstance = cfg.rootInstance
		Trigger.CheckTriggers(cfg, "WIDGET_DESTORY", {instance = instance, rootInstance = rootInstance})
		--Lib.pv({trigger = "WIDGET_DESTORY", instance = instance})
	end

	local parentInstance = UI:getWindowInstance(window:getParent())
	if parentInstance then
		local parentCfg = parentInstance._cfg
		if parentCfg then
			local rootInstance = parentCfg.rootInstance
			Trigger.CheckTriggers(parentCfg, "LAYOUTCONTAINER_CHILD_REMOVED", {instance = parentInstance, child = instance, rootInstance = rootInstance})
			--Lib.pv({trigger = "WIDGET_DESTORY", instance = instance})
		end
	end

	for i = 0, window:getChildCount() - 1 do
		local childWindow = window:getChildAtIdx(i)
		local childId = childWindow:getID()
		local ok, msg
		--存在未被lua记录到windowInstanceMap中的window实例，例如__auto_container__
		if not windowInstanceMap[childId] then
			UI:releaseWindow(childWindow)
		else
			local ok, msg = xpcall(releaseWindowInstance, traceback, childId)
			if not ok then
				print("releaseWindowInstance error: "..msg)
			end
		end
	end
	windowInstanceMap[id] = nil
end

function UI:releaseWindow(window)
	if not isAlive(window) then
		return nil
	end
	for i = 0, window:getChildCount() - 1 do
		local childWindow = window:getChildAtIdx(i)
		local childId = childWindow:getID()
		local ok, msg
		if not windowInstanceMap[childId] then
			UI:releaseWindow(childWindow)
		else
			local ok, msg = xpcall(releaseWindowInstance, traceback, childId)
			if not ok then
				print("releaseWindowInstance error: "..msg)
			end
		end
	end
end

function UI:releaseWindowInstance(id)
	releaseWindowInstance(id)
end

local function loadLuaScript(instance, name)
	if CGame.instance:getEditorType() == 2 then
		return
	end

	local gamePath = Root.Instance():getGamePath():gsub("\\", "/")
	local path, chunk

	--if instance.__windowAssetRelPath and instance.__windowAssetLuaScripts then
	--	path, chunk = loadLua(instance.__windowAssetLuaScripts, gamePath .. "asset/".. instance.__windowAssetRelPath .. "?.lua")
	--else
	--	if not path then
			path, chunk = loadLua(name, gamePath .. "gui/lua_scripts/?.lua")
			if not path then
				path, chunk = loadLua(name, Root.Instance():getRootPath():gsub("\\", "/") .. "Media/CEGUI/lua_scripts/?.lua")
			end
	--	end
	--end
	--编辑器脚本文件丢失自动创建
	if not path then
		local PATH_DATA_DIR = string.gsub(Lib.combinePath(Root.Instance():getGamePath(), "gui/lua_scripts/", name), "\\", "/")
		--if instance.__windowAssetRelPath and instance.__windowAssetLuaScripts then
		--	PATH_DATA_DIR = gamePath .. "asset/".. instance.__windowAssetRelPath .. instance.__windowAssetLuaScripts
		--end
		path = string.format("%s.lua",PATH_DATA_DIR)
		chunk = string.format("print(%q)","startup ui")
		local file = io.open(path,"w+b")
		file:write(chunk)
		file:close()
	end
	assert(path, "cannot find lua script '"..name.."' in 'gui/lua_scripts' or 'Media/CEGUI/lua_scripts' folder")
	local env = setmetatable({self = instance, M = instance}, {__index = _G})
	local ret, errmsg = load(chunk, "@"..path, "bt", env)
	assert(ret, errmsg)()
	UIMgr.uiFileList[name] = {
		path = path,
		time = lfs.attributes(path, "modification")
	}
end

---@return CEGUILayout
function UI:reload(id)	-- TODO template function
	local instance = setmetatable(windowInstanceMap[id], WINDOW_MT)
	UI:loadLuaScriptByGroup(instance, instance.__windowName)
	return instance
end

---@return CEGUILayout
function UI:getWindow(name, dont_create, wndName)
	name = wndName or name
	local window = UI:isOpenWindow(name)
	if not window and not dont_create then
		window = UI:openSystemWindow(name)
		window:setVisible(false)
	end
	return window
end

function UI:isOpenWindow(name)
	local root = guiMgr:getRootWindow()
	if root:isChildName(name) then
		return UI:getWindowInstance(root:getChildByName(name))
	end
	return false
end

local RootDir = Root.Instance():getGamePath()
local triggerParser = require "common.trigger_parser"
local btsDir = RootDir .. "gui/events/"

local function loadTrigger(instance, windowName)
	if not windowName or windowName == "" then
		return
	end

	local settingPath = btsDir .. windowName .. "/setting.json"
	if not lfs.attributes(settingPath, "modification") then
		return
	end

	local setting = Lib.read_json_file(settingPath)
	if setting and setting["widget"] then
		local widgets = setting["widget"] or {}
		local rootwindow = instance.__window:getRootWindow()
		local rootwindowId = rootwindow:getID()

		if #widgets > 0 then
			instance._cfg = instance._cfg or {}
			local cfg = instance._cfg
			cfg.rootInstance = instance
			instance.vars = Vars.MakeVars("ui", cfg)
		end

		for k, v in pairs(widgets) do
			local win_instance
			local win_bts = v.btsKey
			local win_name = v.name
			if win_name == "" then
				win_instance = instance
			else
				local window = instance:getWindow():getChildByName(win_name)
				if window then
					win_instance =  UI:getWindowInstance(window)
				end
			end

			if win_instance then
				local btsPath = btsDir .. windowName .. "/" .. v.btsKey  .. ".bts"
				if lfs.attributes(btsPath, "modification") then
					win_instance._cfg = win_instance._cfg or {}
					local cfg = win_instance._cfg
					cfg.rootInstance = instance

					cfg.btsKey = v.btsKey

					local btsTime = {}
					cfg._btsTime = btsTime
					cfg._win_name = win_name

					local triggers, msg = triggerParser.parse(btsPath)
					if triggers then
						cfg.triggers = triggers
					end
					for k,v in pairs(triggers) do
						if v.type == "WIDGET_HOLD_DOWN" then
							win_instance:getWindow():setEnableLongTouch(true)
						end
					end
					Trigger.LoadTriggers(cfg)
					cfg.instance = win_instance
					win_instance.vars = Vars.MakeVars("ui", cfg)
					Trigger.CheckTriggers(win_instance._cfg, "WIDGET_CREATE", {instance = win_instance, rootInstance = instance})
					--Lib.pv({trigger = "WIDGET_CREATE", instance = win_instance})
				end
			end
		end
	end
end

local function loadLayoutAndLua(func, layoutName, instanceName, resGroup, ...)
	local window = UI:loadWindowByResGroup(layoutName, resGroup)
	if not window then
		print(layoutName .. "----" .. instanceName .. " not find")
		return
	end

	resGroup = window:getResGroup()
	window:setName(instanceName)
	window:setLayoutFileName(layoutName)
	local id = window:getID()
	-- assert(not windowInstanceMap[id], id)
	local instance = UI:getWindowInstance(window)
	instance.__windowName = instanceName
	instance.__groupName = resGroup
	if resGroup == "asset" then
		instance.__windowAssetRelPath = Lib.toFileDirName(layoutName)
		instance.__windowAssetLuaScripts = Lib.toFileName(layoutName)
	end

	local ok, ret = pcall(UI.loadLuaScriptByGroup, UI, instance, layoutName)
	if not ok then
		releaseWindowInstance(id)
	end
	assert(ok, ret)

	--window:setUsingAutoRenderingSurface(true)
	if func then
		if not func(window, instance) then
			releaseWindowInstance(id)
			return
		end
	end
	
	loadTrigger(instance, layoutName)

	if type(rawget(instance, "onOpen")) == "function" then
		instance:onOpen(...)
	end
	if AT.OnWndOpen then
		AT.OnWndOpen(layoutName, window, true)
	end
	if resGroup ~= "_layouts_" and resGroup ~= "layout_presets" then
		table.insert(windowOpenParamsMap,{layoutName,instanceName, resGroup, table.pack(...)})
	end
	Lib.emitEvent(Event.EVENT_OPEN_WINDOW, instanceName)
	return instance
end

local function loadLayoutAndLuaAsync(callback, func, layoutName, instanceName, resGroup, ...)
	assert(type(callback) == "function", type(callback))
	local openParams = table.pack(...)
	UI:loadWindowByResGroupAsync(layoutName, resGroup, function(window)
		if not window then
			print(layoutName .. "----" .. instanceName .. " not find")
			return
		end

		resGroup = window:getResGroup()
		window:setName(instanceName)
		window:setLayoutFileName(layoutName)
		local id = window:getID()
		--assert(not windowInstanceMap[id], id)
		local instance = UI:getWindowInstance(window)
		instance.__windowName = instanceName
		instance.__groupName = resGroup
		if resGroup == "asset" then
			instance.__windowAssetRelPath = Lib.toFileDirName(layoutName)
			instance.__windowAssetLuaScripts = Lib.toFileName(layoutName)
		end

		local ok, ret = pcall(UI.loadLuaScriptByGroup, UI, instance, layoutName)
		if not ok then
			releaseWindowInstance(id)
		end
		assert(ok, ret)

		--window:setUsingAutoRenderingSurface(true)
		if func then
			if not func(window, instance) then
				releaseWindowInstance(id)
				return
			end
		end

		if type(rawget(instance, "onOpen")) == "function" then
			instance:onOpen(table.unpack(openParams))
		end

		if AT.OnWndOpen then
			AT.OnWndOpen(layoutName, window, true)
		end

		Lib.emitEvent(Event.EVENT_OPEN_WINDOW, instanceName)
		if callback then
			callback(instance)
		end
	end)
end


local wndIndex = 1

---@return CEGUILayout
function UI:openWidget(widgetName, resGroup, ...)
	assert(widgetName, "need widget name")
	local instanceName = widgetName .. "_" .. wndIndex
	wndIndex = wndIndex + 1

	resGroup = resGroup or "layouts"
	local name = instanceName or widgetName

	if Recorder.CanUiShow and (not Recorder:CanUiShow(name)) then
		print("UI:openWindow blocked by Recorder", name, widgetName, instanceName)
		return
	end

	return loadLayoutAndLua(nil, widgetName, name, resGroup, ...)
end

---@return CEGUILayout
function UI:loadLayoutInstance(layoutName, resGroup)
	if not resGroup then
		resGroup = "layouts"
	end
	local window = guiMgr:loadLayoutFile(layoutName ..".layout", resGroup)
	local instanceName = winMgr:generateUniqueWindowName()
	local instance = UI:getWindowInstance(window)
	instance.__windowName = instanceName
	window:setName(instanceName)
	return instance
end

function UI:loadLuaScript(window, scriptName)
	local id = window:getID()
	assert(windowInstanceMap[id])
	UI:loadLuaScriptByGroup(window, scriptName)
end

---@return CEGUILayout
function UI:loadScriptLayout(scriptName, layoutName, resGroup)
	if not resGroup then
		resGroup = "layouts"
	end
	if not layoutName then
		layoutName = scriptName
	end
	local instance = self:loadLayoutInstance(layoutName, resGroup)
	instance.__groupName = resGroup
	local ok, ret = pcall(UI.loadLuaScriptByGroup, UI, instance, scriptName)
	if not ok then
		releaseWindowInstance(instance:getID())
		return
	end
	return instance
end

---@return CEGUILayout
function UI:openWindow(windowName, instanceName, resGroup, ...)
	assert(windowName, "need window name")
	resGroup = resGroup or "layouts"
	local name = instanceName or windowName

	if Recorder.CanUiShow and (not Recorder:CanUiShow(name)) then
		print("UI:openWindow blocked by Recorder", name, windowName, instanceName)
		return
	end

	local root = guiMgr:getRootWindow()

	if root:isChildName(name) then --already exist
		--print(name, "already exist")
		local window = root:getChildElement(name)
		return self:getWindowInstance(window),true
	end

	return loadLayoutAndLua(
		function(window)
			root:addChild(window)
			return true
		end,
		windowName, name, resGroup, ...)
end

function UI:openWindowAsync(callback, windowName, instanceName, resGroup, ...)
	--Profiler:begin("openWindow")
	assert(windowName, "need window name")
	resGroup = resGroup or "layouts"
	local name = instanceName or windowName

	if Recorder.CanUiShow and (not Recorder:CanUiShow(name)) then
		print("UI:openWindow blocked by Recorder", name, windowName, instanceName)
		return
	end

	local root = guiMgr:getRootWindow()
	if root:isChildName(name) then --already exist
		return
	end

	loadLayoutAndLuaAsync(callback, function(window)
		root:addChild(window)
		return true
	end, windowName, name, resGroup, ...)
end

---@return CEGUILayout
function UI:openCustomWindow(windowName, instanceName, ...)
	return UI:openWindow(windowName, instanceName, "layouts", ...)
end

function UI:openCustomWindowAsync(callback,windowName, instanceName, ...)
	return UI:openWindowAsync(callback,windowName, instanceName, "layouts", ...)
end

---@return CEGUILayout
function UI:openSystemWindow(windowName, instanceName, ...)
	return UI:openWindow(windowName, instanceName, "_layouts_", ...)
end

function UI:openSystemWindowAsync(callback,windowName, instanceName, ...)
	return UI:openWindowAsync(callback,windowName, instanceName, "_layouts_", ...)
end

function UI:closeWindow(instanceOrName, ...)
	local instance
	if type(instanceOrName) == "table" then
		instance = instanceOrName
	elseif type(instanceOrName) == "string" then
		instance = UI:isOpenWindow(instanceOrName)
		for k,v in ipairs(windowOpenParamsMap) do
			local name = v[2] or v[1]
			if name == instanceOrName then
				table.remove(windowOpenParamsMap,k)
				break
			end
		end
	end

	if not instance then
		return
	end
	local window = instance.__window
	assert(window, "invalid window instance")
	if type(rawget(instance, "onClose")) == "function" then
		instance:onClose(...)
	end
	if not isAlive(window) then
		return
	end
	Lib.emitEvent(Event.EVENT_CLOSE_WINDOW, window:getName())
	guiMgr:getRootWindow():removeChild(window)

	if UI.usePool then
		World.Timer(1, function()
			releaseWindowInstance(window:getID())
		end)
	else
		World.Timer(1, function()
			releaseWindowInstance(window:getID())
			World.Timer(1, window.destroy, window)
		end)
	end
end

function UI:handleWindowEvent(window, eventName, ...)
	local id = window and window:getID()
	local instance = windowInstanceMap[id]
	--print("UI.handleWindowEvent", window, id, eventName, instance, ...)
	if not instance then
		--print("cannot find window instance", window, id, eventName, ...)
		return
	end
	local args = {...}   --window,position.d_x,position.d_y,moveDelta.d_x,moveDelta.d_y,touchID
	if eventName == "WindowDestroy" then
		releaseWindowInstance(id)	-- TODO
	elseif eventName == "ReloadLayout" then
		local scene_ui_id = instance.__sceneUIID or 0
		local scene_ui_windowName = instance.__sceneUIWindowName or nil
		if scene_ui_id > 0 then
			UI:reloadSceneUI(scene_ui_windowName, scene_ui_id)
		end
	else
		instance:EmitEvent(eventName, ...)
	end
end

local EVENT_WINDOW = Define.EVENT_POOL.WINDOW
function UI:subscribeGlobalEvent(eventName, handler)
	assert(type(eventName) == "string", "invalid event name")
	assert(handler, "need handler for global event:"..eventName)
	local bindableEvent = Event:GetExtraEvent(EVENT_WINDOW, eventName, "Engine")
	bindableEvent:SetNoMulticast()
	bindableEvent:Bind(handler)
	guiMgr:subscribeGlobalEvent(eventName)
end

function UI:unsubscribeGlobalEvent(eventName)
	assert(type(eventName) == "string", "invalid event name")
	guiMgr:unsubscribeGlobalEvent(eventName)
	local bindableEvent = Event:GetExtraEvent(EVENT_WINDOW, eventName, "Engine", true)
	if bindableEvent then
		bindableEvent:DestroySingleBind()
	end
end

function UI:handleGlobalEvent(eventName, ...)
	local bindableEvent = Event:GetExtraEvent(EVENT_WINDOW, eventName, "Engine", true)
	if not bindableEvent then
		print("handleUIGlobalEvent cannot get handler", eventName)
		return
	end

	bindableEvent:Emit(eventName, ...)
end

function UI:openSceneWindow(windowName, instanceName, args, resGroup, ...)
	assert(windowName, "need window name")
	local name = instanceName or windowName
	assert(not sceneWindowsMap[name], "scene window '"..name.."' already exist")
	resGroup = resGroup or "layouts"

	if waitCloseSceneWindowMap[name] then
		waitCloseSceneWindowMap[name][1]()
		waitCloseSceneWindowMap[name][2]()
	end
	local sceneWindow
	local instance = loadLayoutAndLua(function(window, instance)
			sceneWindow = guiMgr:createSceneWindow(name, window, args.position, args.rotation, args.width, args.height, args.isCullBack, args.objID, args.flags, args.showDistance or 128)
			if not sceneWindow then
				window:destroy()
				return nil
			end
			sceneWindow.window = instance
			sceneWindowsMap[name] = sceneWindow
			return true
		end, windowName, instanceName, resGroup, ...)

	return sceneWindow, instance
end

function UI:openCustomSceneWindow(windowName, instanceName, args, ...)
	return UI:openSceneWindow(windowName, instanceName, args, "layouts", ...)
end

function UI:openSystemSceneWindow(windowName, instanceName, args, ...)
	return UI:openSceneWindow(windowName, instanceName, args, "_layouts_", ...)
end

function UI:closeSceneWindow(instanceName)
	local sceneWindow = guiMgr:getSceneWindow(instanceName)
	if not sceneWindow or waitCloseSceneWindowMap[instanceName] then
		return
	end
	local window = sceneWindow:getWindow()
	local instance = UI:getWindowInstance(window)
	if instance and type(rawget(instance, "onClose")) == "function" then
		instance:onClose(instanceName)
	end
	Lib.emitEvent(Event.EVENT_CLOSE_WINDOW, instanceName)
	local closeFunc = function()
		guiMgr:destroySceneWindow(instanceName, true)
		waitCloseSceneWindowMap[instanceName] = nil
	end
	if UI.usePool then
		if window then
			closeFunc = function()
				releaseWindowInstance(window:getID())
				guiMgr:destroySceneWindow(instanceName, true)
				waitCloseSceneWindowMap[instanceName] = nil
			end
			waitCloseSceneWindowMap[instanceName] = table.pack(
				World.Timer(1, closeFunc),
				closeFunc
			)
		else
			waitCloseSceneWindowMap[instanceName] = table.pack(
				World.Timer(1, closeFunc),
				closeFunc
			)
		end
	else
		waitCloseSceneWindowMap[instanceName] = table.pack(
			World.Timer(1, closeFunc),
			closeFunc
		)
	end

	sceneWindowsMap[instanceName] = nil
end

--Warning: This usage is NOT RECOMMENDED!!!
--open window and DO NOT CHECK CHILD OR ADD CHILD
function UI:openWindowOnly(windowName, instanceName, resGroup, ...)
	assert(windowName, "need window name")
	local name = instanceName or windowName
	local group = resGroup or "layouts"
	return loadLayoutAndLua(nil, windowName, instanceName, resGroup, ...)
end

function UI:openSystemWindowOnly(windowName, instanceName, ...)
	return UI:openWindowOnly(windowName, instanceName, "_layouts_", ...)
end

function UI:hideAllWindow(excluded)
    excluded = excluded or ""
    local excludedMap = {}
    if type(excluded) == "table" then
        for _, excludedName in pairs(excluded) do
            excludedMap[excludedName] = true
        end
    else
        excludedMap[excluded] = true
    end
	local root = UI.root
	if not root then
		return
	end

	local allOpenWnds = {}
	local count = root:getChildCount()
	for index = 0, count - 1 do
		local wnd = root:getChildAtIdx(index)
		local name = wnd:getName()
        if not excludedMap[name] and wnd:isVisible() then
            wnd:hide()
            allOpenWnds[name] = true
        end
    end

	return function ()
		local count = root:getChildCount()
		for index = 0, count - 1 do
			local wnd = root:getChildAtIdx(index)
			local name = wnd:getName()
			if allOpenWnds[name] and not wnd:isVisible() then
				wnd:show()
			end
		end
    end
end

---@return CEGUILayout
local function createWindow(type, name)
	local window = winMgr:createWindow(type, name)
	--if not isAlive(window) then
	--	return
	--end
	local instance = UI:getWindowInstance(window)
	instance.__windowName = name
	return instance
end

function UI:destroyWindow(instance, ...)
	local window = instance.__window
	assert(window, "invalid window instance")
	if type(rawget(instance, "onClose")) == "function" then
		instance:onClose(...)
	end
	if not isAlive(window) then
		return
	end
	Lib.emitEvent(Event.EVENT_CLOSE_WINDOW, window:getName())
	World.Timer(1, function()
		releaseWindowInstance(window:getID())
		World.Timer(1, window.destroy, window)
	end)
end

function UI:createWindow(name, type)
	return createWindow(type or "Engine/DefaultWindow", name)
end

function UI:createButton(name)
	return createWindow("Engine/Button", name)
end

function UI:createStaticImage(name)
	return createWindow("Engine/StaticImage", name)
end

function UI:createStaticText(name)
	return createWindow("Engine/StaticText", name)
end

if not UI.root and guiMgr:isEnabled() then
	UI.root = UI:getWindowInstance(guiMgr:getRootWindow())
	UI.Root = UI:getWindowInstance(guiMgr:getRootWindow())
	UI.initMainGui = false
end

function UI:openSceneUI(windowName, scene_ui_id, ...)
	if not windowName then
		return
	end
	local layoutName = string.sub(string.gsub(windowName, "asset/", ""), 0, -8)
	local name = layoutName
	local resGroup = "asset"
	local window = self:loadWindowByResGroup(layoutName, resGroup)
	if not window then
		print(windowName .. "----" .. name .. " not find")
		return
	end

	resGroup = window:getResGroup()
	window:setName(name)
	local id = window:getID()
	local instance = UI:getWindowInstance(window)
	instance.__windowName = name
	instance.__groupName = resGroup
	if resGroup == "asset" then
		instance.__windowAssetRelPath = Lib.toFileDirName(layoutName)
		instance.__windowAssetLuaScripts = Lib.toFileName(layoutName)
	end
	local ok, ret = pcall(UI.loadLuaScriptByGroup, UI, instance, layoutName)
	if not ok then
		releaseWindowInstance(id)
	end
	assert(ok, ret)

	local bind_ret = guiMgr:setSceneUILayoutWindow(scene_ui_id, window)
	if not bind_ret then
		window:destroy()
		return nil
	end

	loadTrigger(instance, name)

	instance.__sceneUIID = scene_ui_id
	instance.__sceneUIWindowName = windowName
	if type(rawget(instance, "onOpen")) == "function" then
		instance:onOpen(...)
	end
	table.insert(sceneWindowOpenParamsMap,{windowName, scene_ui_id, table.pack(...)})
	Lib.emitEvent(Event.EVENT_OPEN_WINDOW, name, scene_ui_id)
	return window, instance
end

function UI:closeSceneUI(scene_ui_id, ...)
	local window = guiMgr:getSceneUILayoutWindow(scene_ui_id)
	if not window then
		return
	end
	local instance = UI:getWindowInstance(window)
	if not instance then
		return
	end

	if type(rawget(instance, "onClose")) == "function" then
		instance:onClose(...)
	end
	for k,v in ipairs(sceneWindowOpenParamsMap) do
		if v[2] == scene_ui_id then
			table.remove(sceneWindowOpenParamsMap,k)
			break
		end
	end
	guiMgr:clearSceneUILayoutWindow(scene_ui_id)
	Lib.emitEvent(Event.EVENT_CLOSE_WINDOW, window:getName(), scene_ui_id)
	World.Timer(1, function()
		releaseWindowInstance(window:getID())
		World.Timer(1, window.destroy, window)
	end)
end

function UI:reloadSceneUI(scene_ui_windowName, scene_ui_id, ...)
	UI:closeSceneUI(scene_ui_id)
	World.Timer(3, function()	-- 珠海业务要求关闭场景ui要做一帧延迟, 因为调的是closeSceneUI所以要做延迟
		UI:openSceneUI(scene_ui_windowName, scene_ui_id)
	end)
end

function UI:reloadAllSceneUI()
	local paramsMap = UI.sceneWindowOpenParamsMap
	sceneWindowOpenParamsMap = {}
	UI.sceneWindowOpenParamsMap = sceneWindowOpenParamsMap
	for _,params in ipairs(paramsMap) do
		UI:reloadSceneUI(params[1],params[2],table.unpack(params[3]))
	end
end

function UI:reloadUI(windowName,instanceName, resGroup, params)
	local name = instanceName or windowName
	UI:closeWindow(name)
	World.Timer(2, function()
		UI:openWindow(windowName, instanceName, resGroup, table.unpack(params))
	end)
end

function UI:reloadAllUI()
	local paramsMap = UI.windowOpenParamsMap
	windowOpenParamsMap = {}
	UI.windowOpenParamsMap = windowOpenParamsMap
	for _,params in ipairs(paramsMap) do
		UI:reloadUI(params[1],params[2],params[3],params[4])
	end
end

function UI:SetWindowHide(name, hide)
	local wnd = self:getWindow(name, true) or sceneWindowsMap[name]
	if not wnd then
		return
	end
    if hide then
        wnd:hide()
    else
        wnd:show()
    end
end

function UI:SetWindowsAlphaToZero(names, setZero)
	local root = UI.root
	if not root then
		return
	end

	local count = root:getChildCount()
	for index = 0, count - 1 do
		local wnd = root:getChildAtIdx(index)
        if names[wnd:getName()] then
            if setZero then
		        wnd:setAlpha(0)
		    else
		        wnd:setAlpha(1)
		    end
        end
    end
end

function UI:HideAllWindowsExcept(whiteList, wndAsKey)
	self:RestoreAllWindows()

	local excepts = {}
	if wndAsKey then
		for wnd in pairs(whiteList) do
			table.insert(excepts, wnd:getName())
		end
	else
		for name in pairs(whiteList) do
			table.insert(excepts, name)
		end
	end
	self.restoreHideWindowsFunc = self:hideAllWindow(excepts)
end

function UI:RestoreAllWindows()
	if not self.restoreHideWindowsFunc then
		return
	end
	self.restoreHideWindowsFunc()
	self.restoreHideWindowsFunc = nil
end

function UI:GetAllWindowNames()
    local ret = {}
    local root = UI.root
	if not root then
		return ret
	end

	local count = root:getChildCount()
	for index = 0, count - 1 do
		local wnd = root:getChildAtIdx(index)
		if wnd:isVisible() then
			table.insert(ret, wnd:getName())
		end
    end
    return ret
end

local function updateRootInstance(rootInstance, window)
	if not rootInstance then
		return
	end
	local id = window:getID()
	local instance = windowInstanceMap[id]
	if instance and instance._cfg then
		instance._cfg.rootInstance = rootInstance
	end

	for i = 0, window:getChildCount() - 1 do
		local childWindow = window:getChildAtIdx(i)
		updateRootInstance(rootInstance, childWindow)
	end
end

function UI:addChild(parentInstance, childInstance)
	--先执行c++的addChild
	local parentWindow = parentInstance:getWindow()
	local childWindow = childInstance:getWindow()
	parentWindow:addChild(childWindow)

	--已存在相同名字的子控件时，addChild会失败
	if not childWindow:getParent() == parentWindow then
		return
	end

	--找到现在的rootInstance
	local rootWindow = parentWindow
	local rootInstance = parentInstance
	while not rootInstance._cfg.rootInstance == rootInstance do
		rootWindow = rootWindow:getParent()
		if not rootWindow then
			return
		end
		rootInstance = windowInstanceMap[rootWindow:getID()]
	end

	--递归更新所有子控件的rootInstance
	updateRootInstance(rootInstance, childWindow)
end

function UI:clearWindowPool()
	for _, pool in pairs(UI.windowPool) do
		for _, window in pairs(pool) do
			if isAlive(window) then
				window:destroy()
			end
		end
	end
	UI.windowPool = {}
end

-- TODO: set as UI field?
local sessionSeed = 0
local asyncLoadList = {}
function UI:loadWindowAsync(callback, windowName, resGroup)
	assert(type(callback) == "function", type(callback))
	local session = sessionSeed + 1
	sessionSeed = session
	asyncLoadList[session] = {
		session = session,
		windowName = windowName,
		resGroup = resGroup,
		callback = callback,
	}
	guiMgr:loadLayoutFileAsync(session, windowName..".layout", resGroup or "layouts")
end

function asyncLoadLayoutDone(session, window)
	local data = asyncLoadList[session]
	if not data then
		if window then
			window:destroy()
		end
	end
	-- TODO: pcall and more check?
	data.callback(window)
end

--==================================================================================================
--[[
CreateGUIWindow		创建一个UI布局的实例
getGUIWindow		根据InstanceName返回窗口实例
closeWindow			传入一个窗口实例来关闭窗口
openSceneWindow		打开一个UI布局作为场景UI
closeSceneWindow	根据InstanceName关闭场景UI
createGUIWidget		直接创建一个UI控件
]]

function UI:CreateGUIWindow(layoutPath, windowName, ...)
	local resGroup = "layouts"
	local name = windowName or layoutPath

	local window = self:loadWindowByResGroup(layoutPath, resGroup)
	if not window then
		print(layoutPath .. "----" .. " not find")
		return
	end

	resGroup = window:getResGroup()
	window:setName(name)
	local id = window:getID()
	local instance = UI:getWindowInstance(window)
	instance.__windowName = name
	instance.__groupName = resGroup
	if resGroup == "asset" then
		instance.__windowAssetRelPath = Lib.toFileDirName(layoutPath)
		instance.__windowAssetLuaScripts = Lib.toFileName(layoutPath)
	end
	local ok, ret = pcall(UI.loadLuaScriptByGroup, UI, instance, layoutPath)
	if not ok then
		UI:releaseWindowInstance(id)
	end

	loadTrigger(instance, layoutPath)

	return instance
end

--function UI:GetGUIWindow()
--end

--function UI:CloseWindow()
--end

--function UI:OpenSceneWindow()
--end

--function UI:CloseSceneWindow()
--end

require "ui.ui_load_api"
