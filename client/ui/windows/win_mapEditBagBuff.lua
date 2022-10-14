local setting = require "common.setting"
local itemSetting = require "editor.setting.item_setting"
local editorSetting = require "editor.setting"
local loadTimer

function M:init()
	WinBase.init(self, "bagBuffList.json")
	self:initUIName()
	self.items = {}
	self:initUI()
end

function M:initUI()
	self.grid:InitConfig(20, 30, 9)
	self.title:SetText(Lang:toText("select_buff_effect"))
	self:fetchAllBuff()
end

local function getNameByFullName(fullName)
	assert(type(fullName) == "string", fullName)
	local splitRet = Lib.splitString(fullName, "/")
	local len = #splitRet
	local name = len > 0 and splitRet[len]
	return name
end

local function CreateItem(type, fullName, args)
    local item = EditorModule:createItem(type, fullName, args)
    local cfg = item:cfg()
    return item, cfg
end

function M:initUIName()
	self.title = self:child("bagBuffList-title")
	self.grid = self:child("bagBuffList-buffGrid")
end

function M:newBuffItemUI(icon, name)
	local itemUI = GUIWindowManager.instance:LoadWindowFromJSON("buffSelectCell.json")
	itemUI:child("buffSelectCell-icon"):SetImage(icon)
	local text = Lang:toText(name)
	if Lib.getStringLen(text) > 10 then
		text = Lib.subString(text, 8) .. "..."
	end
	itemUI:child("buffSelectCell-name"):SetText(text)
	return itemUI
end

function M:selectBuff(idx)
	local selectIdx = self.selectIdx
	if selectIdx then
		local selectItemUI = self.items[selectIdx].ui
		if selectItemUI then
			selectItemUI:child("buffSelectCell-select"):SetVisible(false)
		end
	end
	local itemUI = self.items[idx].ui
	if itemUI then
		itemUI:child("buffSelectCell-select"):SetVisible(true)
	end
	self.selectIdx = idx
end

function M:fetchAllBuff()
	self.grid:RemoveAllItems()
	local items = Clientsetting.getData("buff")
	local idx = 1
	if not items then
		return
	end
    local maxIdx = #items
    local function fetch()
        for _ = idx, maxIdx do
            local itemName = items[idx]
            local type
            local name = itemName
            local icon
            if itemName.name then
                name =  itemName.name
                type = itemName.type
                icon = itemName.icon
            end
            local item, cfg
            item, cfg = CreateItem(type or "block", name, {
				icon = icon
			})

			local cell = self:newBuffItemUI(item:icon(), item:getNameText() or "123")
			self.items[idx] = {
				ui = cell,
				item = item
			}
			local index = idx
			self:subscribe(cell, UIEvent.EventButtonClick, function()
				self:selectBuff(index)
			end)
			self.grid:AddItem(cell)
            idx = idx + 1
            if idx > maxIdx then
                return false
            end
            return true
        end
        return false
    end
	fetch()
    loadTimer = World.Timer(1, fetch)
end

function M:getSelectItem()
	if self.selectIdx then
		local item = self.items[self.selectIdx].item
		local newItemName = itemSetting:copyBuffItem(item:full_name())		
		return CreateItem("item", newItemName), true
	end
end

function M:onOpen()
	self:selectBuff(1)
end

function M:onClose()
	if loadTimer then
		loadTimer()
		loadTimer = nil
	end
end