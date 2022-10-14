local Signal = require "we.signal"
local Def = require "we.def"
local UIRequest = require "we.proto.request_ui"
local Meta = require "we.gamedata.meta.meta"
local VN = require "we.gamedata.vnode"
local UIProperty = require "we.logic.ui.ui_property"
local Converter = require "we.gamedata.export.data_converter"
local WindowAttrs = require "we.logic.ui.window_attrs"
local Recorder = require "we.gamedata.recorder"
local fontMgr = require "we.logic.ui.ui_font_manager"
local Lang = require "we.gamedata.lang"

local window_class = {}

local WINDOW_TYPE = {
	StaticImage = "static_image",
	Button = "button",
	StaticText = "static_text",
	Editbox = "editbox",
	Checkbox = "checkbox",
	RadioButton = "radio_button",
	HorizontalSlider = "slider",
	VerticalSlider = "slider",
	ScrollableView = "scrollable_view",
	ProgressBar = "progressbar",
	ActorWindow = "actor_window",
	EffectWindow = "effect_window",
	SliderThumb = "slider_thumb",
	VSliderThumb = "slider_thumb",
	GridView = "container",
	VerticalLayoutContainer = "container",
	HorizontalLayoutContainer = "container",
	MaskWindow = "mask_window"
}

local WINDOW_KEY_METHOD= {

	BOOL = {
		Disabled = true,
		MousePassThroughEnabled = true,
		MarginProperty = true,
		SizeConstraint = true,
		SoundTriggerRange = true,
		AutoTextScale = true,
		TextWordBreak = true,
		ClipProgress = true,
		AntiClockwise = true,
		IsUIMask = true,
		IsDisplayUIMask = true,
		ForceVertScrollbar = true,
		ForceHorzScrollbar = true,
		moveAble = true,
		BorderEnable = true,
		BorderWidth = true,
		ActorScale = true,
		enable_text_offset = true, -- not found in dev.meta
		Reverse = true,
		MoveByStep = true,
	},
	STRING = {
		Text = true,
		VertFormatting = true,
		vertFormatting = true,
		horzFormatting = true,
		FillType = true,
		FillPosition = true,
		FillArea = true,
		HorzImageFormatting = true,
		VertImageFormatting = true,
		TextBoldWeight = true,
		SkillName = true,
		-- RadioButton
		TextXPos = true,
		HorzLabelFormatting = true,
		ImageXSizeImcress = true,
		-- StaticImage
		ImageBlendMode = true,
		ImageSrcBlend = true,
		ImageDstBlend = true,
		ImageBlendOperation = true,
		effectPlayMode = true,  -- missing in dev.meta
		-- MaskWindow
		MaskType = true,
	},
	NUMBER = {
		Alpha = true,
		Volume = true,
		GroupID = true,
		RotateX = true,
		RotateY = true,
		RotateZ = true,
		PositionX = true,
		PositionY = true,
		ActorScale = true,
		MinAutoTextScale = true,
		TextXOffset = true,
		TextYOffset = true,
		effectXRotate = true,
		effectYRotate = true,
		effectZRotate = true,
		effectScale = true,
		effectXPosition = true,
		effectYPosition = true,
		SideNum = true,
	},
}

function window_class:init(node, guiWindow, modify)
	self._child_window = {}
	self._parent = nil
	self._node = node
	self._id = node.id.value
	self._type = node.__OBJ_TYPE
	self._guiWindow = guiWindow
	self:connect(modify)
	
	for _,property in pairs(UIProperty.UI_WINDOW) do
		for key,v in pairs(property) do
			local value = node[key]
			if value ~= nil then
				self:set_property(guiWindow,key,value,modify,node)
			end
		end
	end

	local children = node["children"]
	for _,child in pairs(children) do
		if guiWindow:isChildName(child.name) then
			local child_gui_window = guiWindow:getChildByName(child.name)
			self:init_children(child,child_gui_window,modify)
		end
	end	
	self:update_z_index()
end

function window_class:init_children(node, guiWindow, modify)
	local id = node.id.value
	local window = Lib.derive(window_class)
	window:init(node, guiWindow, modify)
	window:set_parent(self)
	self._child_window[id] = window
end

function window_class:parent()
	return self._parent
end

function window_class:set_parent(parent)
	self._parent = parent
end

function window_class:window_type()
	return self._type
end

function window_class:window_node()
	return self._node
end

function window_class:window_gui()
	return self._guiWindow
end

function window_class:window_child()
	return self._child_window
end

function window_class:window_is_layout(type)
	if string.find(type,"LayoutContainer") or
	   string.find(type,"GridViewContainer") or type == "GridView" then
		return true
	else
		return false
	end
end

function window_class:update_child_z_index()
	for _,child in pairs(self:window_child()) do
		child:update_z_index()
	end
end

function window_class:update_z_index()
	local z_index = self:window_gui():getZIndex();
	self:window_node().ZIndex = z_index
end

function window_class:getScrollParentWindow()
	local parent = self:parent()
	if not parent then
		return nil
	end

	local type = parent:window_type()
	if type == "ScrollableView" then
		return parent:window_gui()
	else
		return parent:getScrollParentWindow()
	end
end

function window_class:alignment_window(window, checkOffset)
	local unclippedOuterRect = window:getUnclippedOuterRect():getFresh(true)
	--x is former d_left, y is former d_top
	local pos = {
		x = unclippedOuterRect.left,
		y = unclippedOuterRect.top
	}
	local size = {
		x = unclippedOuterRect.right - unclippedOuterRect.left,
		y = unclippedOuterRect.bottom - unclippedOuterRect.top
	}

	--容器控件无子结点时调用引擎接口获取的大小为0
	--但是编辑器需要渲染一个100*100的框
	local type = self._guiWindow:getType()

	local parentWidget = window:getParent()
	if parentWidget then
		local parentUnclippedOuterRect = parentWidget:getUnclippedOuterRect():getFresh(true)
		pos.x = pos.x - parentUnclippedOuterRect.left
		pos.y = pos.y - parentUnclippedOuterRect.top
	end
	
	if checkOffset then 
		local scroll_window = self:getScrollParentWindow()
		if scroll_window then
			--[[
			local cs = scroll_window:getContentPaneArea()
			local hs = scroll_window:getHorzScrollbar()
			local vs = scroll_window:getVertScrollbar()
			local posh = hs:getScrollPosition()
			local posv = vs:getScrollPosition()

			pos.x = pos.x - (cs.left + posh)
			pos.y = pos.y - (cs.top + posv)
			]]
			local cs = scroll_window:getContentPaneArea()
			local view = scroll_window:getViewableArea()
			local hs = scroll_window:getHorzScrollbar()
			local vs = scroll_window:getVertScrollbar()
			--local posh = hs:getScrollPosition()
			--local posv = vs:getScrollPosition()
			--local scroll_size = scroll_window:getSize()
			local w = view.right - view.left --scroll_size["width"][2]
			local h = view.bottom - view.top --scroll_size["height"][2]
			local hv = hs:getUnitIntervalScrollPosition()
			local vv = vs:getUnitIntervalScrollPosition()

			--	偏移量为自由长度(底板边长减去滚动面板边长)乘滚动条的百分比

			local free_h = (cs.right > w and cs.right or w) - cs.left - w
			local free_v = (cs.bottom > h and cs.bottom or h) - cs.top - h
			pos.x = pos.x - (cs.left + free_h * hv)
			pos.y = pos.y - (cs.top + free_v * vv) 
		end
	end

	if self:window_is_layout(type) and size["x"] == 0 and size["y"] == 0 then
		--布局容器无子节点时的引擎大小为0，编辑器为了显示出来设置为100*100
		size = {x = 100, y = 100}
		local h_a = self._guiWindow:getProperty("HorizontalAlignment")
		local v_a = self._guiWindow:getProperty("VerticalAlignment")
		local h_scale = 0
		local v_scale = 0
		if h_a == "Centre" then
			h_scale = 0.5
		elseif h_a == "Right" then
			h_scale = 1
		end
		if v_a == "Centre" then
			v_scale = 0.5
		elseif v_a == "Bottom" then
			v_scale = 1
		end
		pos.x = pos.x - 100 * h_scale
		pos.y = pos.y - 100 * v_scale
	end
	local transform_pos = GUIManager.logicPosToScreenPos(pos)
	local transform_size = GUIManager.logicPosToScreenPos(size)

	UIRequest.request_sync_widget_rect(self._id, transform_pos, transform_size)

	local parent = self:parent()
	if parent and parent:window_type() == "ScrollableView" then
		local parent_window = parent:window_gui()
		local HorzScrollPosition = parent_window:getProperty("HorzScrollPosition");
		local VertScrollPosition = parent_window:getProperty("VertScrollPosition");
		local parent_node = parent:window_node()
		if parent_node then
			parent_node["VertScrollPosition"] = tonumber(VertScrollPosition)
			parent_node["HorzScrollPosition"] = tonumber(HorzScrollPosition)
		end
	end

	self:update_child(checkOffset)
end

function window_class:check_scroll_window(window)

	-- bug:滑动面板调节进度后, 去画布拖动滑动面板里的子控件时,子控件的辅助线会偏移
	-- TODO 这是个临时修改方案
	local scroll_window = self:getScrollParentWindow()
	if scroll_window then
		window:setXPosition({0,-999999})
		window:setYPosition({0,-999999})
		self:alignment_window(window, self:window_type() == "ScrollableView")

		window:setXPosition({0,999999})
		window:setYPosition({0,999999})
		self:alignment_window(window, self:window_type() == "ScrollableView")
	end
	-- TODO 这是个临时修改方案
end

function window_class:resize_window(window)
	local size = self._node["size"]
	window:setWidth({size.UDim_X.Scale,size.UDim_X.Offect})
	window:setHeight({size.UDim_Y.Scale,size.UDim_Y.Offect})
	--self:layout_item_update(window)
	self:alignment_window(window, self:window_type() == "ScrollableView")
end
function window_class:move_window(window)
	local pos = self._node["pos"]
	self:check_scroll_window(window)
	window:setXPosition({pos.UDim_X.Scale,pos.UDim_X.Offect})
	window:setYPosition({pos.UDim_Y.Scale,pos.UDim_Y.Offect})
	--self:layout_item_update(window)
	self:alignment_window(window, self:window_type() == "ScrollableView")
end

function window_class:update_window()
	self:alignment_window(self._guiWindow, true)
end


--item更新通知qt
function window_class:update_child(checkOffset)
	for _,v in pairs(self._child_window) do
		local window = v:window_gui()
		v:alignment_window(window, checkOffset)
		--v:update_child(checkOffset)	-- alignment_window中已经调用了update_child;不注释的话，末尾节点的访问次数2^n....
	end
end

--layout子节点更新及layout更新(数据)
function window_class:layout_item_update(window)
	local parent_window = window:getParent()
	if parent_window then
		local type = parent_window:getType()
		if not self:window_is_layout(type) then
			return
		end
		parent_window:update()
		local x_pos = window:getXPosition()
		local y_pos = window:getYPosition()
		self._node.pos.UDim_X.Scale = x_pos[1]
		self._node.pos.UDim_X.Offect = x_pos[2]
		self._node.pos.UDim_Y.Scale = y_pos[1]
		self._node.pos.UDim_Y.Offect = y_pos[2]

		local node_parent = VN.parent(VN.parent(self._node))
		local width = parent_window:getWidth()
		local height = parent_window:getHeight()
		node_parent.size.UDim_X.Scale = width[1]
		node_parent.size.UDim_X.Offect = width[2]
		node_parent.size.UDim_Y.Scale = height[1]
		node_parent.size.UDim_Y.Offect = height[2]
		if self:parent() then
			self:parent():layout_update()
		end
	end
end

--layout更新及layout子节点更新(数据)
function window_class:layout_update()
	local type = self._guiWindow:getType()
	if not self:window_is_layout(type) then
		return
	end
	
	self._guiWindow:update()
	local width = self._guiWindow:getWidth()
	local height = self._guiWindow:getHeight()
	
	if width[2] <= 0 then
		self._node.size.UDim_X.Offect = 100
	else
		self._node.size.UDim_X.Offect = width[2]
	end
	if height[2] <= 0 then
		self._node.size.UDim_Y.Offect = 100
	else
		self._node.size.UDim_Y.Offect = height[2]
	end

	local enable = Recorder:enable()
	Recorder:set_enable(false)
	self._node.anchor.HorizontalAlignment = self._guiWindow:getProperty("HorizontalAlignment")
	self._node.anchor.VerticalAlignment = self._guiWindow:getProperty("VerticalAlignment")
	Recorder:set_enable(enable)

	if width[2] <= 0 or height[2] <= 0 then
		return
	end
	self:alignment_window(self._guiWindow)
	for _,v in pairs(self._child_window) do
		if v then
			local window = v:window_gui()
			local node = v:window_node()
			window:update()
			local x_pos = window:getXPosition()
			local y_pos = window:getYPosition()
			node.pos.UDim_X.Scale = x_pos[1]
			node.pos.UDim_X.Offect = x_pos[2]
			node.pos.UDim_Y.Scale = y_pos[1]
			node.pos.UDim_Y.Offect = y_pos[2]
		end
	end
end

function window_class:sys_window_size()
	self._guiWindow:update()
	local window_width = self._guiWindow:getWidth()
	local window_height = self._guiWindow:getHeight()
	local node_width = self:window_node().size.UDim_X.Offect
	local node_height = self:window_node().size.UDim_Y.Offect
	if math.ceil(node_width) ~= math.ceil(window_width[2]) then
		self:window_node().size.UDim_X.Scale = window_width[1]
		self:window_node().size.UDim_X.Offect = window_width[2]
	end
	if math.ceil(node_height) ~= math.ceil(window_height[2]) then
		self:window_node().size.UDim_Y.Scale = window_width[1]
		self:window_node().size.UDim_Y.Offect = window_height[2]
	end
end
--pos or size
--UDim_X or UDim_Y
--Scale or Offect
function window_class:conversion_udim_by_dir(transform_type, transform_dir, conversion_dir)
	--拿到父窗口的大小
	local parent_size = self._guiWindow:getParent():getPixelSize()
	local length = transform_dir == "UDim_X" and parent_size.width or parent_size.height
	local node = self:window_node()[transform_type][transform_dir]

	Recorder:start()
	if conversion_dir == "Scale" then
		local offect = node.Offect
		node.Scale = node.Scale + (length == 0 and 0 or offect/length)
		node.Offect = 0
	else
		node.Offect = node.Offect + node.Scale * length
		node.Scale = 0
	end
	Recorder:stop()
end

function window_class:set_property(window, key, value, modify, node)
	--print("name--->>",self._node.name,"key ",key," value ",value)
	if key == "name" then
		if value == "" then
			local old_value = window:getName()
			node[key] = old_value
		else
			window:setName(value)
		end
	elseif key == "Visible" then
		window:setVisible(value)
	elseif key == "ClippedByParent" then
		window:setProperty("ClippedByParent",tostring(value))
		local type = window:getType()
		if type == "WindowsLook/HorizontalSlider" or type == "WindowsLook/VerticalSlider" then
			local thumb = window:getThumb()
			if thumb then
				thumb:setProperty("ClippedByParent",tostring(value))
			end
		end
	elseif key == "btn_word_warpped" then
		--除文本框之外的带文字组件的文字对齐字段
		local str = window:getProperty("HorzLabelFormatting")
		if string.sub(str,1,8) ~= "WordWrap" and value then
			window:setProperty("HorzLabelFormatting","WordWrap"..str)
		elseif string.sub(str,1,8) == "WordWrap" and not value then
			window:setProperty("HorzLabelFormatting",string.sub(str,9))
		end
	elseif key == "word_warpped" then
		local str = window:getProperty("HorzFormatting")
		if string.sub(str,1,8) ~= "WordWrap" and value then
			window:setProperty("HorzFormatting","WordWrap"..str)
		elseif string.sub(str,1,8) == "WordWrap" and not value then
			window:setProperty("HorzFormatting",string.sub(str,9))
		end
		if modify then
			self:sys_window_size()
		end
	elseif key == "HorzFormatting" then
		local str = window:getProperty("HorzFormatting")
		if string.sub(str,1,8) == "WordWrap" then 
			window:setProperty("HorzFormatting","WordWrap"..value)
		else
			window:setProperty("HorzFormatting",value)
		end
	elseif key == "VertFormatting" then
		window:setProperty("VertFormatting",value)
	elseif key == "MaskText" then
		window:setTextMasked(value);
	elseif key == "MaxTextLength" then
		window:setMaxTextLength(value)
	elseif key == "FrameEnabled" then
		window:getWindowRenderer():setFrameEnabled(value)
	elseif key == "BackgroundEnabled" then
		window:getWindowRenderer():setBackgroundEnabled(value)
	elseif key == "MaximumValue" then
		window:setProperty("MaximumValue",value)
		local cur_value = node.CurrentValue
		window:setProperty("CurrentValue",cur_value)
	elseif key == "CurrentValue" then
		local max_value = node.MaximumValue
		window:setProperty("MaximumValue",max_value)
		window:setProperty("CurrentValue",value)
	elseif key == "ReversedDirection" then
		window:getWindowRenderer():setReversedDirection(value)
		window:getWindowRenderer():performChildWindowLayout()
	elseif key == "Selected" then
		window:setSelected(value)
	elseif key == "VerticalProgress" then
		--TODO 奇怪的bug将value转string，反而无效了
		window:getWindowRenderer():setVertical(value)
	elseif key == "ReversedProgress" then
		window:getWindowRenderer():setReversed(value)
	elseif key == "Font" or key == "Font_size" then
		if fontMgr:has_font(self._node.Font) then
			window:setFont(self._node.Font .."-"..self._node.Font_size)
		end
	elseif key == "HorizontalAlignment" then
		window:setProperty(key,value)
		window:updateArea(true, true)
		self:alignment_window(window, true)
	elseif key == "VerticalAlignment" then
		window:setProperty(key,value)
		window:updateArea(true, true)
		self:alignment_window(window, true)
	elseif key == "CurrentValue" then
		window:setProperty(key,value)
		window:setProperty("progressValue",value)
	elseif key == "ReadOnly" then
		window:setReadOnly(value)
	elseif key == "HorzScrollPosition" then
		local t = window:getProperty("HorzScrollPosition")
		if math.abs(t - tonumber(value)) >= 0.01 then
			window:setProperty(key,value)
			window:updateArea(true, false)
			self:alignment_window(window, true)
		end
	elseif key == "VertScrollPosition" then
		local t = window:getProperty("VertScrollPosition")
		if math.abs(t - tonumber(value)) >= 0.01 then
			window:setProperty(key,value)
			window:updateArea(true, false)
			self:alignment_window(window, true)
		end
	elseif key == "space" then
		window:setSpace(value)
		if modify then
			self:layout_update()
		end
	elseif key == "rowSize" then
		window:setProperty(key, value)
		if modify then
			self:layout_update()
		end
	elseif key == "AutoScale" then
		if modify then
			WindowAttrs:set_auto_scale(value,node)
			window:setProperty(key,value)
			self:sys_window_size()
		end
	elseif key == "dir" then
		window:setProperty(key, value)
		self:layout_update()
	elseif key == "ControlChildrenSize" then
		window:setProperty(key,tostring(value))
		-- 容器不控制元素大小后，控件size还原
		if value == false then
			local children = self:window_child()
			for _,child in pairs(children) do
				if child then
					child:resize_window(child:window_gui())
					child:layout_item_update(child:window_gui())
				end
			end	
		end
		self:layout_update()
	elseif WINDOW_KEY_METHOD.BOOL[key] or WINDOW_KEY_METHOD.STRING[key] or WINDOW_KEY_METHOD.NUMBER[key] then  
		window:setProperty(key,tostring(value))
	else
		--print("This property is not supported")
	end
end

function window_class:create_child_guiwindow(node, gui_window)
	local meta = Meta:meta(node.__OBJ_TYPE)
	local type = meta:info()["attrs"]["Catalog"]
	local gui_type
	if node.__OBJ_TYPE == "DefaultWindow" then
		gui_type = "DefaultWindow"
	else
		gui_type = (type ~= "layout" and {"WindowsLook/"..node.__OBJ_TYPE} or {node.__OBJ_TYPE})[1]
	end
	WindowAttrs:set_pos_max_min(node)
	local name = node.name
	local child_gui_window = gui_window:createChild(gui_type,name)
	local parent_type = gui_window:getType()
	if self:window_is_layout(parent_type) then
		gui_window:update()
		local x_pos = child_gui_window:getXPosition()
		local y_pos = child_gui_window:getYPosition()
		node.pos.UDim_X.Scale = x_pos[1]
		node.pos.UDim_X.Offect = x_pos[2]
		node.pos.UDim_Y.Scale = y_pos[1]
		node.pos.UDim_Y.Offect = y_pos[2]
		WindowAttrs:set_pos_enabled(node)
		node.anchor.HorizontalAlignment = "Left"
		node.anchor.VerticalAlignment = "Top"
		WindowAttrs:set_anchor(node)
	end
	local pos_x_o = node.pos.UDim_X.Offect
	local pos_y_o = node.pos.UDim_Y.Offect
	local width_o = node.size.UDim_X.Offect
	local height_o = node.size.UDim_Y.Offect
	local pos_x_s = node.pos.UDim_X.Scale
	local pos_y_s = node.pos.UDim_Y.Scale
	local width_s = node.size.UDim_X.Scale
	local height_s = node.size.UDim_Y.Scale
	--print("x",pos_x_o,"y",pos_y_o,"width",width_o,"height",height_o)
	child_gui_window:setArea2({pos_x_s,pos_x_o},{pos_y_s,pos_y_o},{width_s,width_o},{height_s,height_o})
	if self:window_is_layout(parent_type) then
		local node_parent = VN.parent(VN.parent(node))
		gui_window:update()
		local width = gui_window:getWidth()
		local height = gui_window:getHeight()
		node_parent.size.UDim_X.Scale = width[1]
		node_parent.size.UDim_X.Offect = width[2]
		node_parent.size.UDim_Y.Scale = height[1]
		node_parent.size.UDim_Y.Offect = height[2]
	end

	local children = node.children
	for _,child in pairs(children) do
		self:create_child_guiwindow(child,child_gui_window)
	end

	return child_gui_window
end

function window_class:connect_on_insert()
	local children = self._node.children
	Signal:subscribe(children, Def.NODE_EVENT.ON_INSERT, function(index)
		--print("child-------------------->>insert??????", index)
		for idx = index, #children do
			local child_node = children[idx]
			local id = child_node.id.value
			local child_window = self._child_window[id]
			if child_window then
				local child_gui_window = child_window:window_gui()
				self:window_gui():removeChild(child_gui_window)
				self._child_window[id] = nil
			end
		end

		for idx = index, #children do
			local child_node = children[idx]
			local child_gui_window = self:create_child_guiwindow(child_node,self:window_gui())
			self:init_children(child_node, child_gui_window, true)
		end
		self:layout_update()
		--节点顺序变化后更新ZIndex
		--删除时不需要更新,添加、移动、复制粘贴只需要更新目标节点的子结点的ZIndex
		self:update_child_z_index()
	end)
end

function window_class:connect_on_remove()
	local children = self._node.children
	Signal:subscribe(children, Def.NODE_EVENT.ON_REMOVE, function(index, child)
		--print("child-------------------->>remove??????")
		local id = child.id.value
		local child_window = self._child_window[id]
		if child_window then
			local child_gui_window = child_window:window_gui()
			self:window_gui():removeChild(child_gui_window)
			if child_window:window_node().text_key then
				local key = child_window:window_node().text_key.value
				Lang:copy_text_to_temp_text(key,key.."#copy_temp")
				Lang:remove_key(key)
			end
			self._child_window[id] = nil
			self:layout_update()
		end
	end)
end

function window_class:connect_on_assign()
	Signal:subscribe(self._node, Def.NODE_EVENT.ON_ASSIGN, function(key)
		local value = self._node[key]
		self:set_property(self._guiWindow, key, value, true, self._node)
		if key == "Text" then
			if self._node["text_key"] and self._node["text_key"].value ~= "" then
				Lang:set_text(self._node["text_key"].value,value)
				if CEGUILangManager.Instance() then
					CEGUILangManager.Instance():set(self._node["text_key"].value,value)
				end
			end
		end
	end)

	Signal:subscribe(self._node, Def.NODE_EVENT.ON_MODIFY, function(path, event, index, ...)
		path = table.concat(path, "/")
		if path =="ActorName" then
			local value = self._node["SkillName"]
			local asset = self._node["ActorName"]["asset"]
			if #asset > 0 then
				self:set_property(self._guiWindow, "SkillName", value, true, self._node)
			end
		end
	end)
end

function window_class:connect_on_resize()
	local size_width = self._node["size"]["UDim_X"]
	Signal:subscribe(size_width, Def.NODE_EVENT.ON_ASSIGN, function(key)
		self:resize_window(self._guiWindow)
		self:layout_item_update(self._guiWindow)
	end)

	local size_height = self._node["size"]["UDim_Y"]
	Signal:subscribe(size_height, Def.NODE_EVENT.ON_ASSIGN, function(key)
		self:resize_window(self._guiWindow)
		self:layout_item_update(self._guiWindow)
	end)

	local pos_x = self._node["pos"]["UDim_X"]
	Signal:subscribe(pos_x, Def.NODE_EVENT.ON_ASSIGN, function(key)
		self:move_window(self._guiWindow)
		self:layout_item_update(self._guiWindow)
	end)

	local pos_y = self._node["pos"]["UDim_Y"]
	Signal:subscribe(pos_y, Def.NODE_EVENT.ON_ASSIGN, function(key)
		self:move_window(self._guiWindow)
		self:layout_item_update(self._guiWindow)
	end)

	local rotation = self._node["Rotation"]
	self._guiWindow:setProperty("Rotation",Converter(rotation,"Rotation"))
	Signal:subscribe(rotation, Def.NODE_EVENT.ON_ASSIGN, function(key)
		self._guiWindow:setProperty("Rotation",Converter(rotation,"Rotation"))
	end)
	
	local PivotX = self._node["PivotX"]
	self._guiWindow:setProperty("PivotX",tostring(PivotX["value"]))
	Signal:subscribe(PivotX, Def.NODE_EVENT.ON_ASSIGN, function(key)
		self._guiWindow:setProperty("PivotX",tostring(PivotX["value"]))
	end)
	
	local PivotY = self._node["PivotY"]
	self._guiWindow:setProperty("PivotY",tostring(PivotY["value"]))
	Signal:subscribe(PivotY, Def.NODE_EVENT.ON_ASSIGN, function(key)
		self._guiWindow:setProperty("PivotY",tostring(PivotY["value"]))
	end)
end

function window_class:connect(modify)
	self:connect_on_insert()
	self:connect_on_remove()
	self:connect_on_assign()
	self:connect_on_resize()

	local anchor_node = self._node["anchor"]
	if anchor_node then
		local h_node = anchor_node["HorizontalAlignment"]
		local v_node = anchor_node["VerticalAlignment"]
		self._guiWindow:setProperty("HorizontalAlignment",anchor_node["HorizontalAlignment"])
		self._guiWindow:setProperty("VerticalAlignment",anchor_node["VerticalAlignment"])
		self:alignment_window(self._guiWindow)
		Signal:subscribe(anchor_node, Def.NODE_EVENT.ON_ASSIGN, function()
			self._guiWindow:setProperty("HorizontalAlignment",anchor_node["HorizontalAlignment"])
			self._guiWindow:setProperty("VerticalAlignment",anchor_node["VerticalAlignment"])
			self:alignment_window(self._guiWindow)
		end)
	end

	if self._node["text_key"] and self._node["Text"] then
		local get_key = function(self)
			local path_key = self._type
			local node = self._node
			while VN.parent(node) do
				node = VN.parent(node)
				if node.__OBJ_TYPE == "LayoutCfg" then
					path_key = node.path.."."..path_key.."#"..GenUuid()
				end
			end
			return path_key
		end
		local get_path = function(self)
			local path = ""
			local node = self._node
			while VN.parent(node) do
				node = VN.parent(node)
				if node.__OBJ_TYPE == "LayoutCfg" then
					path = node.path
				end
			end
			return path
		end
		-- layout控件中的key命名规则 --  layout文件名.layout/type.name#uuid
		-- key中带有#copy_temp是复制出来，需要重新生成
		if string.find(self._node["text_key"].value,"#copy_temp") then
			local key = get_key(self)
			Lang:copy_text_from_temp_text(self._node["text_key"].value,key)
			VN.assign(self._node.text_key, "value", key, VN.CTRL_BIT.DEFAULT & (~VN.CTRL_BIT.RECORDE))
		elseif string.find(self._node["text_key"].value,".layout") then
			local text = Lang:text(self._node.text_key.value)
			if text == self._node.text_key.value then				
				Lang:copy_text_from_temp_text(self._node.text_key.value.."#copy_temp",self._node.text_key.value)
				text = Lang:text(self._node.text_key.value)
			end

			-- 找不到翻译了，只能认为当前Text是翻译
			if text == self._node.text_key.value then
				Lang:set_text(self._node.text_key.value,self._node.Text)
			else
				VN.assign(self._node,"Text",text, VN.CTRL_BIT.NONE)
			end	
		else
			-- ob7的bug导致Text变成了key，尝试修复数据
			local has_fix_ob7 = false
			local text_of_key = self._node.Text
			local pos_start,pos_end = string.find(text_of_key,".layout.")
			if pos_start then
				local text = Lang:text(text_of_key)
				if text ~= text_of_key then					
					-- 判断key路径与layout路径一致
					local is_path_key = false
					if pos_start then
						local path_in_key = string.sub(text_of_key,1,pos_end - 1)
						local asset_path = get_path(self)
						if path_in_key == asset_path then
							is_path_key = true
						end
					end
					if is_path_key then 
						self._node.text_key.value = text_of_key
						self._node.Text = text
					else
						local new_key = get_key(self)
						Lang:copy_text(text_of_key,new_key)
						self._node.text_key.value = new_key
						self._node.Text = text
					end
					has_fix_ob7 = true
				end
			end

			if not has_fix_ob7 then
				self._node.text_key.value = get_key(self)
				Lang:set_text(self._node.text_key.value,self._node.Text)	
			end	
		end
		if CEGUILangManager.Instance() then
			CEGUILangManager.Instance():set(self._node.text_key.value,self._node.Text)
		end
	end

	local soundFile = self._node["SoundFile"]
	self._guiWindow:setProperty("SoundFile",Converter(soundFile,"SoundKey"))
	Signal:subscribe(soundFile, Def.NODE_EVENT.ON_ASSIGN, function()
		self._guiWindow:setProperty("SoundFile",Converter(soundFile,"SoundKey"))
	end)

	if WINDOW_TYPE[self._type] then
		local window = require ("we.logic.ui.widgets."..WINDOW_TYPE[self._type])
		window:init(self._node,self._guiWindow,self)
		if self._type == "StaticText" then
			--Todo:屏蔽初始化时同步文本控件size，解决打开UI编辑器就有*号提示
			if modify then
				local gui_window_instance = UI:getWindowInstance(self._guiWindow, true)
				gui_window_instance.onTextChanged = function()
					self:sys_window_size()
				end
				gui_window_instance.onFontChanged = function()
					self:sys_window_size()
				end
			end
		end
	end

	if self._node.Font then
		Lib.subscribeEvent(Event.EVENT_PC_EDITOR_DELETE_FONT, function(font_name, next_font)
			if font_name == self._node.Font then
				VN.assign(self._node, "Font", next_font, VN.CTRL_BIT.DEFAULT & (~VN.CTRL_BIT.RECORDE))
				self._guiWindow:setFont(next_font.."-"..self._node.Font_size)
			end
		end)
	end

end

return window_class