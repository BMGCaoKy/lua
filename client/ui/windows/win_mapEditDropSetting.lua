local entitySetting = require "editor.setting.entity_setting"
local blockSetting = require "editor.setting.block_setting"
local editorSetting = require "editor.setting"
local entity_obj = require "editor.entity_obj"
local setting = require "common.setting"

local cell_pool = {}
local keyIndex = {
	type = 1,
	count = 2,
	args = 3,
	fullName = 4,
    icon = 5,
}
local DropData = {
	{
	    [keyIndex.type] = "item",
		[keyIndex.count] = 2,
		[keyIndex.args] = 1,
		[keyIndex.fullName] = "myplugin/bridge_egg"
	},
	{
	    [keyIndex.type] = "item",
		[keyIndex.count] = 2,
		[keyIndex.args] = 1,
		[keyIndex.fullName] = "myplugin/bridge_egg"
	}
}

local function fetchCell()
	local ret = table.remove(cell_pool)
	if not ret then
		ret = UIMgr:new_widget("cell","widgetSettingItem_edt.json")
	end
	return ret
end

local function CreateItemData(type, fullName, args)
    local item = EditorModule:createItem(type, fullName, args)
    local cfg = item:cfg()
    return item, cfg
end

local function selectCell(self, cell, item)
    if self.lastSelect then
        self.lastSelect:receiver():onClick(false, "")
        self.lastSelect:receiver()._btn_close:SetVisible(false)
    end
    self.lastSelect = cell
	if cell then
		cell:receiver():onClick(true, "set:setting_global.json image:check_equip_show_click.png")
		cell:receiver()._btn_close:SetVisible(true)
	end

    self:child("SettiSetting-Layout-RewardLayout-Details-Icon"):SetImage(item and item:icon())
    self:child("SettiSetting-Layout-RewardLayout-Details-Name"):SetText(item and Lang:toText(item:getNameText() or ""))
    local list = self:child("Setting-Desc-List")
    list:ClearAllItem()
    local attrs = Lib.splitString(item and item:getDescText() or "", "&")
    local yOffset = 0
	local w = list:GetPixelSize().x
	local h = list:GetPixelSize().y
    for index, attr in pairs(attrs) do
        local stAttr = GUIWindowManager.instance:CreateGUIWindow1("StaticText", string.format("ShopItem-Tip-Desc-%d", index))
		stAttr:SetWordWrap(true)
        if string.find(attr, "=") then
            local kvPair = Lib.splitString(attr, "=")
            stAttr:SetText(Lang:formatText(kvPair))
        else
            stAttr:SetText(Lang:formatText(attr))
        end
		stAttr:SetWidth({ 0, w })
		local height = stAttr:GetTextStringHigh()
        stAttr:SetHeight({ 0, height })
        stAttr:SetXPosition({ 0, 0 })
        stAttr:SetYPosition({ 0, yOffset})
		yOffset = yOffset + height
        list:AddItem(stAttr)
    end
	list:SetMoveAble(yOffset > h)
end

local function createItem(self, grid, index, data)
    local cell = fetchCell()
    local numBtn = cell:receiver()._cs_bottom
    local delBtn = cell:receiver()._btn_close
    local nameText = cell:receiver()._lb_bottom
    local img = cell:receiver()._img_item
    local bg = cell:receiver()._img_bg
    local item, cfg = CreateItemData(data[keyIndex.type], data[keyIndex.fullName], {
        icon = data[keyIndex.icon]
    })
    img:SetImage(item:icon() or "")
    local isBuff = cfg.isBuff or cfg.isAttach
    numBtn:SetVisible(not isBuff)
    cell:receiver()._bottom_text:SetText("X" .. data[keyIndex.count])
    nameText:SetVisible(true)
    nameText:SetText(Lang:toText(item:getNameText() or ""))
    cell:setData("index", index)
    self:subscribe(delBtn, UIEvent.EventButtonClick, function()
        table.remove(DropData, index)
        self:refreshDrop()
    end)
    self:subscribe(bg, UIEvent.EventWindowTouchUp, function()
        selectCell(self, cell, item)
    end)
    self:subscribe(numBtn, UIEvent.EventButtonClick, function()
        UILib.openCountUI(data[keyIndex.count], function(num, sliderUI, isInfinity)
            self:updateBasicEquipNum(index, num)
        end, true)
    end)
    if index == 1 then
        selectCell(self, cell, item)
    end
    return cell
end

function M:refreshDrop()
    self.lastSelect = nil
    local grid = self.gridView
    grid:RemoveAllItems()
    for i = 1, #DropData do
        self:addItem(i)
    end
	if #DropData == 0 then
		selectCell(self)
        self.repBtn:SetEnabledRecursivly(false)
        self.repText:SetText(Lang:toText(""))
	else
        self.repBtn:SetEnabledRecursivly(true)
        self.repText:SetText(Lang:toText("win.Edit.map.Drop.setting.show.btn"))
    end
end

function M:updateBasicEquipNum(index, num)
    local tb = DropData[index]
    tb[keyIndex.count] = num
    self:refreshDrop()
end

function M:addItem(index)
    local grid = self.gridView
    local itemWnd = createItem(self, grid, index, DropData[index])
    grid:AddItem(itemWnd)
    self.repBtn:SetEnabledRecursivly(true)
    self.repText:SetText(Lang:toText("win.Edit.map.Drop.setting.show.btn"))
end

function M:addBasicEquip(item, isBuff)
    local tb = {[keyIndex.fullName] = item:cfg().fullName or item:full_name(), [keyIndex.count] = 1, [keyIndex.args] = 1, [keyIndex.type] = item:type(),
        [keyIndex.icon] = item:icon()
    }
    table.insert(DropData, tb)
    self:addItem(#DropData)
end

function M:replaceBasicEquip(item, isBuff, index)
    local tb = {[keyIndex.fullName] = item:cfg().fullName or item:full_name(), [keyIndex.count] = 1, [keyIndex.args] = 1, [keyIndex.type] = item:type(),
        [keyIndex.icon] = item:icon()
    }
    DropData[index] = tb
    self:refreshDrop()
end

function M:init()
    WinBase.init(self, "dropSettingItem_edt.json")
    self.repText = self:child("SettiSetting-Layout-RewardLayout-Details-Btn-Txt")
	self:initEvent()
	self:initWndLayout()
end

function M:initEvent()
	self:subscribe(self:child("Setting-Layout-RewardLayout-Add"), UIEvent.EventButtonClick, function()
        UI:openMultiInstanceWnd("mapEditItemBagSelect", {setDropItem = true, backFunc = function(item, isBuff)
            self:addBasicEquip(item, isBuff)
        end})
    end)

    self.repBtn = self:child("SettiSetting-Layout-RewardLayout-Details-Btn")
    self:subscribe(self.repBtn, UIEvent.EventButtonClick, function()
        UI:openMultiInstanceWnd("mapEditItemBagSelect", {setDropItem = true, backFunc = function(item, isBuff)
            local index = self.lastSelect:data("index")
            self:replaceBasicEquip(item, isBuff, index)
        end})
    end)
end

function M:initWndLayout()
	self.gridView = self:child("SettiSetting-Layout-RewardLayout-gridView")
	local grid = self.gridView 
	grid:InitConfig(0, 15, 4)
	grid:SetAutoColumnCount(false)

	self:child("Setting-Layout-RewardLayout-Title"):SetText(Lang:toText("win.Edit.map.Drop.setting.title"))
	self:child("Setting-Layout-RewardLayout-AddTxt"):SetText(Lang:toText("win.Edit.map.Drop.setting.addBtn"))
	self:child("Setting-Layout-RewardLayout-ItemLayoutBG-Text"):SetText(Lang:toText("win.Edit.map.Drop.setting.dropTitle"))
	self:child("SettiSetting-Layout-RewardLayout-Details-Txt"):SetText(Lang:toText("win.Edit.map.Drop.setting.show.title"))
	self:child("SettiSetting-Layout-RewardLayout-Details-Btn-Txt"):SetText(Lang:toText("win.Edit.map.Drop.setting.show.btn"))
end

function M:initData()
    if self.params.itemType == "block" then
        DropData = Lib.copy(blockSetting:getCfgByKey(self.params.fullName, self.params.propItem.pos.propKey) or {})
    else
        DropData = entity_obj:Cmd("getDropItem", self.params.id) or {}
    end
end

function M:onSave()
    if self.params.itemType ~= "block" then
        entity_obj:Cmd("setDropItem", self.params.id, DropData)
    end
end

function M:getDropData()
    return DropData
end

function M:onOpen(params)
	self:setContentXPosition({0, 131})
	self.params = params
	self:initData()
	self:refreshDrop()
end

function M:onReload(reloadArg)

end

function M:onClose()
    self:onSave()
end

function M:setContentXPosition(x)
	self:child("Setting-Layout-RewardLayout"):SetXPosition(x)
end

return M