local widget_base = require "ui.widget.widget_base"
local isEditor =  World.CurWorld.isEditor

local M = Lib.derive(widget_base)
local selectType = {
	Replace = 0,
	Cover = 1
}

local needResetImgItemSize = true
function M:init(_path, _preStr, _selectType)
	local path = _path or "widget_cell.json" -- 兼容之前�
	local preStr = _preStr or "widget_cell" -- 兼容之前�

	widget_base.init(self, path)

	self._img_frame = self:child(preStr .. "-img_frame") -- 底板/外框
	self._img_frame_select = self:child(preStr .. "-img_frame_select") -- 选中外框效果
	self._img_item = self:child(preStr .. "-img_item")
	self._img_item_bg = self:child(preStr .. "-img_item_bg")
	self._img_item_position = { x = self._img_item:GetXPosition(), y = self._img_item:GetYPosition()}
	self._img_item_size = self._img_item:GetPixelSize()
	self._img_item_isReset = false
	self._actor_item = self:child(preStr .. "-actor_item")
	self._lb_bottom = self:child(preStr .. "-lb_bottom")
	self._lock_alpha = self:child(preStr .. "-img_closeitem")
    self._img_locked = self:child("widget_cell-Lock")
	self._cs_bottom = self:child(preStr .. "-cs_bottom")
	self._img_frame_masking = self:child(preStr .. "-img_masking")
	self._img_frame_sign = self:child(preStr .. "-img_sign")
	self._img_frame_select_cover = self:child(preStr .. "-img_frame_select_cover")
    self._top_text = self:child(preStr .. "-Top-Type")
	self._img_frame_1 = self:child(preStr .. "-img_frame_1")--�����
	self._smallIcon = self:child(preStr .. "-widget-cell-samll")
    self._text_limit = self:child(preStr .. "-text-limit")--�����ı�
    self._btn_close = self:child(preStr .. "-btn-close")
    self._img_bg = self:child(preStr .. "-img-bg")
    self._bottom_text = self:child(preStr .. "-bottom-text")--ȫ��װ��item
    self._name_tip = self:child(preStr .. "-name_tip")
    self._fold_btn = self:child(preStr .. "-fold_Btn")
	if isEditor then
		self._lb_bottom:SetVisible(false)
	end
	self._img_item:setEnableLongTouch(true)
	self.cell_var = nil
	self.isClick = false
    self._select_type = _selectType and selectType[_selectType] or selectType.Replace
end

function M:refresh()
	if needResetImgItemSize and not self._img_item_isReset then
		self._img_item_isReset = true
		local pixel = self:root():GetPixelSize()
		self._img_item:SetArea({ 0, 0 }, { 0, 0 }, { 0, pixel.y - 18 }, { 0, pixel.y - 18 })
	end
end

function M:RESET(val)
	self:root():PlayEffect1("")
	self._img_item:SetImage("")
	self._img_frame:SetVisible(true)
	self._lb_bottom:SetText("")
	self._cs_bottom:SetText("")
	if self._img_item_bg then
		self._img_item_bg:SetImage("")
	end
	if self._img_frame_sign then
		self._img_frame_sign:SetImage("")
	end
	if self._actor_item then
		self._actor_item:SetActor1("")
	end
    if self.gridView then
        self.gridView:invoke("CLEAN")
    end
end
--
function M:SET_BASE_ICON()
	local path = self.cell_var
	if path and self._img_item then
		self._img_item:SetImage(path)
	end
end

function M:RESET_OUTER_FRAME()
	if self._img_frame_select then
		self._img_frame_select:SetVisible(self.cell_var and true or false)
	end
end

function M:SET_ICON_BY_PATH()
	local iconPath = self.cell_var
	if not iconPath then
		return
	end
	self._img_item:SetImage(iconPath)
end
--
function M:RESET_CONTENT()
	self._img_item:SetImage("")
end

function M:ITEM_FULLNAME()
	local item_class = Item.CreateItem(self.cell_var)
	if item_class then
		self._img_item:SetImage(item_class:icon())
	end
end

function M:ITEM_BLOCK_ID()
	local itemObj = Item.CreateItem("/block", 1, function(itemData)
		itemData:set_block_id(self.cell_var)
	end)
	if itemObj then
		self._img_item:SetImage(itemObj:icon())
	end
end

function M:UPDATE_NEED_RESET_ITEM_SIZE()
	if self.cell_var == false then
		needResetImgItemSize = false
		self._img_item_isReset = false
		self._img_item:SetArea(self._img_item_position.x, self._img_item_position.y,
			{ 0, self._img_item_size.x }, { 0, self._img_item_size.y })
	else
		needResetImgItemSize = true
	end
end

function M:ITEM_SLOTER()
	local cell_var = self.cell_var
	if not cell_var then
		return
	end
	local icon = ""
	if cell_var.is_block and cell_var:is_block() and cell_var.block_icon then
		icon = cell_var:block_icon(cell_var:block_id())
	elseif cell_var.icon then
		icon = cell_var:icon()
	end
	if self.isClick then
		if cell_var:cfg() and cell_var:cfg().selectIcon then
			icon = cell_var:cfg().selectIcon
		end
	end
	self._img_item:SetImage(icon)
	local container = cell_var:container()
	if container then
		local currentCapacity = cell_var:getValue("currentCapacity") or container.initCapacity or 0
		local maxCapacity = container.maxCapacity + (cell_var:getValue("extCapacity") or 0)
		local totalCapacity = container.isShowTotal and (container.totalCapacity or Player.CurPlayer:tray():find_item_count(container.reloadName, container.reloadBlock)) or maxCapacity
		self._cs_bottom:SetText(currentCapacity .. "/" .. totalCapacity)
	end
	if not cell_var:isShowCount() then
		return
	end
	if cell_var:stack_count() > 0 then
		self._lb_bottom:SetText(math.tointeger( cell_var:stack_count() ))
	end
end

function M:DIY_ITEM_SIZE(width, height)
	self._img_item:SetArea({ 0, 0 }, { 0, 0 }, { 0, width }, { 0, height })
end

function M:DIY_ITEM(icon, own, need)
	local cell_var = self.cell_var
	assert(not cell_var:null())
	self._img_item:SetImage(icon or cell_var:icon())
	if own and need then
		self._cs_bottom:SetText(Lib.switchNum(own) .. "/" .. Lib.switchNum(need))
	elseif own or need then
		self._lb_bottom:SetText(Lib.switchNum(own or need))
	else
		self._cs_bottom:SetText("")
	end
end

function M:SHOW_FRAME()
	self._img_frame:SetVisible(self.cell_var and true or false)
end

function M:SHOW_MASKING(mask)
	if self._img_frame_masking then
		self._img_frame_masking:SetVisible(self.cell_var)
	end
end

function M:SHOW_EFFECT()
	local cell_var = self.cell_var
	local effect = cell_var:cfg().showEffect
	if effect then
		self:root():PlayEffect1(effect)
	end
end

function M:FRAME_IMAGE(icon, stretch)
	if icon then
		self._img_frame:SetImage(icon)
	end
    if stretch and type(stretch) then
        self._img_frame:SetProperty("StretchType", "NineGrid")
        self._img_frame:SetProperty("StretchOffset", stretch)
    end
end

function M:FRAME_SELECT_IMAGE(icon, stretch)
	if icon and self._select_type == selectType.Replace then
		self._img_frame_select:SetImage(icon)
	elseif icon and self._select_type == selectType.Cover then
		self._img_frame_select_cover:SetImage(icon)
	end
	if stretch and type(stretch) == "string" then
		if self._select_type == selectType.Replace then
			self._img_frame_select:SetProperty("StretchType", "NineGrid")
			self._img_frame_select:SetProperty("StretchOffset", stretch)
		elseif self._select_type == selectType.Cover then
			self._img_frame_select_cover:SetProperty("StretchType", "NineGrid")
			self._img_frame_select_cover:SetProperty("StretchOffset", stretch)
		end
	end
end

function M:SHOW_LOCKED(lock, lockImage, area)
	if lockImage and self._img_locked then
		self._img_locked:SetImage(lockImage)
	end
	if lock ~= nil then
		self._lock_alpha:SetVisible(lock)
	else
		self._lock_alpha:SetVisible(self.cell_var and true or false)
	end
    if area and self._img_locked then
        self._img_locked:SetArea(table.unpack(area))
    end
end

function M:FRAME_SIZE(width, height)
	self:root():SetArea({ 0, 0 }, { 0, 0 }, { 0, width }, { 0, height })
end

function M:FRAME_AREA(xPos, yPos, width, height)
	self:root():SetArea(xPos or { 0, 0 }, yPos or { 0, 0 }, width or { 0, 64 }, height or { 0, 64 })
end

function M:ACTOR_ITEM(actorName, action)
	self._img_item:SetImage("")
	if actorName then
		self._actor_item:SetActor1(actorName, action or "idle")
		self._actor_item:SetProperty("ActorWindowRotateY", "-20")
		self._actor_item:SetActorScale(0.8)
	end
end

function M:ITEM_SIGN(signIcon)
	if self._img_frame_sign then
		self._img_frame_sign:SetImage(signIcon)
	end
end


function M:LD_BOTTOM_COLOR(color)
	self._lb_bottom:SetTextColor(color or self.cell_var)
end

function M:CS_BOTTOM(text)
	self._cs_bottom:SetText(text or self.cell_var)
end

function M:CS_BOTTOM_COLOR(color)
	self._cs_bottom:SetTextColor(color or self.cell_var)
end

function M:LD_BOTTOM(text, font)
	if text then
		self._lb_bottom:SetText(text)
		if font then
			self._lb_bottom:SetProperty("Font", font)
		end
	else
		self._lb_bottom:SetText(self.cell_var or "")
	end
end

function M:TOP_TEXT(text)
    self._top_text:SetText(Lang:toText(text or ""))
end

function M:SELECT_TYPE(type)
    self._select_type = type and selectType[type] or selectType.Replace
end

function M:POS()
	local pos = self.cell_var
    if not self.cell_var then
        pos = { x = 0, y = 0 }
    end
    self._root:SetXPosition({0, pos.x})
    self._root:SetYPosition({0, pos.y})
end

function M:SHOW_STAR_LEVEL(level, icon, width, height)
	local cell_var = self.cell_var
	if not cell_var then
		return
	end
	self.gridView = UIMgr:new_widget("grid_view")
    self.gridView:invoke("MOVE_ABLE", false)
	self.gridView:invoke("TOUCHABLE", false)
	self.gridView:invoke("AUTO_COLUMN", false)
	self.gridView:invoke("INIT_CONFIG", 0, 0, 1)
	self.gridView:invoke("AREA", { 0, 10 }, { 0, 10 }, { 0.5, 0 }, { 1, -20 })
	self:root():AddChildWindow(self.gridView)
	for i = 1, level or 0 do
		local image = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "widget_cell_level_" .. i)
		image:SetArea({ 0, 0 }, { 0, 0 }, { 0, width or 10 }, { 0, height or 10 })
		image:SetImage(icon or "")
		image:SetTouchable(false)
		self.gridView:invoke("ITEM", image)
	end
end

function M:SET_BG()
	if self.cell_var and self._img_item_bg then 
		self._img_item_bg:SetImage(Lib.getItemBgImage(self.cell_var) or "")
	end
end

function M:SET_ITEM_AREA()
	self._img_item:SetArea(table.unpack(self.cell_var))
end

function M:SET_STACK_COUNT(stackCount)
    self._lb_bottom:SetText(math.tointeger(stackCount))
end

function M:SET_IMG_ENABLE(isEnable)
    self._img_item:SetEnabled(isEnable)
end

function M:setImgEnable(isEnable)
    self._img_item:SetEnabled(isEnable)
end

function M:onInvoke(key, val, ...)
	local fn = M[key]
	assert(type(fn) == "function", key)
	self.cell_var = val
	self:refresh()
	fn(self, ...)
end

function M:setCellTip(showText)
	local isShow = showText ~= ""
	self._name_tip:SetVisible(isShow)
	local text = Lang:toText(showText)
	if #text > 15 then
		text = text:sub(1, 15) .. "..."
	end
	if isShow then
		local width = self._name_tip:GetFont():GetTextExtent(text, 1.0) + 50
		self._name_tip:SetWidth({0 , width })
		self._name_tip:SetText(text)
	end
end

function M:onClick(isClick, image)
	if self._select_type == selectType.Replace then
		local targetImage = self._img_frame_select or self._img_frame
		if image then
			targetImage:SetImage(image)
		end
		targetImage:SetVisible(isClick)
	elseif self._select_type == selectType.Cover then
		self._img_frame_select_cover:SetVisible(isClick)
	end
	self.isClick = isClick
end

return M
