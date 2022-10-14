local itemSetting = require "editor.setting.item_setting"
local buffSetting = require "editor.setting.buff_setting"

function M:init()
	WinBase.init(self, "buff_setting.json")
	self:initUIName()
	self:initUI()
end

function M:initUI()
	self.grid:InitConfig(20, 30, 9)
	self.title:SetText(Lang:toText("select_buff_effect"))
	self:subscribe(self.sureBtn, UIEvent.EventButtonClick, function()
		-- todo 
        local initbuffList = itemSetting:getTypeBuffList(self.fullName) or {}
        local usebuffList = itemSetting:getUseBuffList(self.fullName) or {}

        local ok = true
        local checkFunc = function(list, key)
            for _, buffName in pairs(list) do
                 local type = buffSetting:getCfgByKey(buffName, key)
                 if type and type == self.selectItemData.buffType then
                    ok = false
                 end
            end
        end
        checkFunc(initbuffList, "attachType")
        checkFunc(usebuffList, "type")

        if not ok then
            Lib.emitEvent(Event.EVENT_TOAST_TIP, Lang:toText("cant_add_already_buff"), 20)
            return
        end
		local desktop = GUISystem.instance:GetRootWindow() ---@type GUIWindow
		local ui = UIMgr:new_widget("leftTab")
		local function sureOnSaveBackFunc(value)
			desktop:RemoveChildWindow1(ui)
			UI:closeWnd("mapEditBuffSetting")
			if self.uperWnd then
				self.uperWnd:addBuff(self.selectItemData.fullName, value, self.selectItemData.buffType)
			end
		end
		local function cancelFunc()
			desktop:RemoveChildWindow1(ui)
		end 
		local buffItem = self.selectItemData.buffItem
		print(buffItem.title, "title|||", buffItem.descIndex)
		ui:invoke("fillData", {
			tabDataList = {
				{
					leftTabName = "editor.ui.setCount",
					widgetName = "baseProp",
					params = {
						title = buffItem.title,
						dataUIList = buffItem.dataUIList or {
							{
								-- 值
								type = "slider",
								index = buffItem.desc_index, 
								value = 3,
							},
							--{   先注释后面版本发
							--	-- 等级
							--	type = "slider",
							--	index = 3005, 
							--	value = 3,
							--},
						}
					},
				}
			},
			sureOnSaveBackFunc = sureOnSaveBackFunc,
			cancelFunc = cancelFunc,
		})
		ui:SetLevel(8)
		desktop:AddChildWindow(ui)
	end)
	
	self:subscribe(self.cancelBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd(self)
    end)
end

function M:initUIName()
	self.title = self:child("setting_edit-title")
	self.grid = self:child("Global-Lt-Grid")
	self.sureBtn = self:child("Global-Sure")
    self.cancelBtn = self:child("Global-Cancel")
	self.sureBtn:SetText(Lang:toText("global.sure"))
	self.cancelBtn:SetText(Lang:toText("global.cancel"))
end

function M:newBuffItemUI(icon, name)
	local itemUI = GUIWindowManager.instance:LoadWindowFromJSON("buffSelectCell.json") ---@type GUIWindow
	itemUI:child("buffSelectCell-icon"):SetImage(icon)
	local text = Lang:toText(name)
	if Lib.getStringLen(text) > 10 then
		text = Lib.subString(text, 8) .. "..."
	end
	itemUI:child("buffSelectCell-name"):SetText(text)
	return itemUI
end

function M:selectBuff(itemUI, buffType, buffItem)
	if not self.fullName or not buffType then
		return
	end

	local lastItemUI = self.selectItemData.itemUI
	if lastItemUI then
		lastItemUI:child("buffSelectCell-select"):SetVisible(false)
	end
	itemUI:child("buffSelectCell-select"):SetVisible(true)
	self.selectItemData = {
		fullName = itemSetting:createBuffName(self.fullName, buffType),
		itemUI = itemUI,
		buffType = buffType,
		buffItem = buffItem
	}
end

function M:fetchAllBuff()
	if not self.fullName or not self.cfg then
		return 
	end
	self.grid:RemoveAllItems()
	local cfg = self.cfg
	local editBuffList = cfg.editBuffList
	local func = Clientsetting[editBuffList]
	local buffList = {}

	if not func then
		local data = Clientsetting.getData(editBuffList)
		if data then
			buffList = data
		end
	else
		buffList = func() 
	end
	local buffTemple = Clientsetting.getBuffTemple() or {}
	for i, buffType in pairs(buffList) do
		local buffItem = buffTemple[buffType]
		if buffItem then
			local itemUI = self:newBuffItemUI(buffItem.edit_icon, buffItem.name)
			self:subscribe(itemUI, UIEvent.EventButtonClick, function()
				self:selectBuff(itemUI, buffType, buffItem)
			end)
			self.grid:AddItem(itemUI)
			if i == 1 then
				self:selectBuff(itemUI, buffType, buffItem)
			end
		end
	end
	
end

function M:onOpen(fullName, cfg, uperWnd)
	self:root():SetLevel(9)
	self.uperWnd = uperWnd
	self.selectItemData = {}
	self.fullName = fullName or "myplugin/16"
	self.cfg = cfg
	self:fetchAllBuff()
end
