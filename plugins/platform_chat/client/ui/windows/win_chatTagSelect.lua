---@class WinChatTagSelect : WinBase
local WinChatTagSelect = M
---@type TagsConfig
local TagsConfig = T(Config, "TagsConfig")
local chatSetting = World.cfg.chatSetting

function WinChatTagSelect:init()
	WinBase.init(self, "ChatTagSelect.json")
	self:initUI()
	self:initEvent()
	if World.cfg.chatSetting and World.cfg.chatSetting.chatLevel then
		self:root():SetLevel(World.cfg.chatSetting.chatLevel)
	end
end

function WinChatTagSelect:initUI()
	self.lytPanel = self:child("ChatTagSelect-panel")
	self.imgPanelBg = self:child("ChatTagSelect-panelBg")
	self.imgTitleBg = self:child("ChatTagSelect-title_Bg")
	self.txtTitleName = self:child("ChatTagSelect-title_name")
	self.btnCloseBtn = self:child("ChatTagSelect-closeBtn")
	self.txtSelectTxt = self:child("ChatTagSelect-selectTxt")
	self.lytTabList = self:child("ChatTagSelect-tabList")
	self.lytItemPanel = self:child("ChatTagSelect-itemPanel")
	self.imgSelectBg = self:child("ChatTagSelect-selectBg")
	self.lytItemList = self:child("ChatTagSelect-itemList")

	self.txtTitleName:SetText(Lang:toText("ui.chat.profile.addTag"))

	self.tabGridView = UIMgr:new_widget("grid_view")
	self.tabGridView:SetMoveAble(false)
	self.tabGridView:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
	self.lytTabList:AddChildWindow(self.tabGridView)
	self.myTagData = {}
	self.curSelectTagList = {}
	self.selectCounts = 0
	self.totalCounts = 0
	self:initTabList()
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WinChatTagSelect:initEvent()
	self:subscribe(self.btnCloseBtn, UIEvent.EventButtonClick, function()
		local addList = {}
		for tagId, isSelect in pairs(self.curSelectTagList) do
			if not self.firstTagData[tagId] and isSelect then
				table.insert(addList, tagId)
			end
		end
		if next(addList) then
			UI:getWnd("chatMyProfile"):setRequestingTagData(true)
			Me:requestAddTagsList(addList, true)
		end

		local deleteList = {}
		for tagId, isSelect in pairs(self.firstTagData) do
			if not self.curSelectTagList[tagId] and isSelect then
				table.insert(deleteList, tagId)
			end
		end
		if next(deleteList) then
			UI:getWnd("chatMyProfile"):setRequestingTagData(true)
			Me:requestDeleteTagsList(deleteList, true)
		end
		self:onHide()
	end)
end

--注册event事件监听，注意这里的事件是show的时候注册，close的时候注销的，常驻事件可在initEvent里面注册
function WinChatTagSelect:subscribeEvent()
	--self._allEvent[#self._allEvent + 1] = Lib.subscribeEvent(Event.EVENT_CLOSE_PRE_BATTLE_ANIMATION, function()

	--end)
end

--界面数据初始化
function WinChatTagSelect:initView(myTagData)
	self.myTagData = myTagData
	self.curSelectTagList = {}
	for _, tagId in pairs(self.myTagData ) do
		self.curSelectTagList[tonumber(tagId)] = true
	end
	self.firstTagData = Lib.copy(self.curSelectTagList)
	self.selectCounts = #myTagData
	self.totalCounts = chatSetting.chatTagSetting.selectTagMax
	self:updateSelectTagNumShow()
	if self.curSelectTab ~= 0 then
		self:updateAdapterTagShow(self.curSelectTab)
	end
end

-- 初始化页签
function WinChatTagSelect:initTabList()
	local tagTypeList = TagsConfig:getItemsTagTypeList()
	self.tabGridView:InitConfig(1, 0, #tagTypeList)

	self.tabItems = {}
	self.lstTagContent = {}
	self.adapterTagContent = {}
	self.tagContentData = {}
	self.curSelectTab = 0
	for i, tabKey in ipairs(tagTypeList) do
		local item = self.tabItems[tabKey]
		if not item then
			item = UIMgr:new_widget("chatTagTabItem")
			item:SetArea({ 0, 0 }, { 0, 0 }, { 0, 147 }, { 0, 60 })
			self.tabGridView:AddItem(item)
			self.tabItems[tabKey] = item
		end
		item:invoke("initTabKey", tabKey, i, #tagTypeList)
		item:invoke("setTabClickFunc", function(tabKey)
			self:updateTabViewShow(tabKey)
		end)

		self.lstTagContent[tabKey] = UIMgr:new_widget("grid_view")
		self.lstTagContent[tabKey]:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
		self.lytItemList:AddChildWindow(self.lstTagContent[tabKey])

		self.lstTagContent[tabKey]:InitConfig(18, 18, 4)
		self.adapterTagContent[tabKey] = UIMgr:new_adapter("common",130,38, "chatTagSelectItem", "ChatTagSelectItem.json")
		self.lstTagContent[tabKey]:invoke("setAdapter", self.adapterTagContent[tabKey])
	end
	self:updateTabViewShow(tagTypeList[1])
end

function WinChatTagSelect:updateTabViewShow(tabKey)
	self.curSelectTab = tabKey
	for index, item in pairs(self.tabItems) do
		item:invoke("updateTabIconShow", tabKey)
		self.lstTagContent[index]:SetVisible(tabKey == index)
	end
	if not self.tagContentData[tabKey] then
		self:initTagContent(tabKey)
	end
end

function WinChatTagSelect:initTagContent(tabKey)
	local curCfg = TagsConfig:getItemsByTagType(tabKey)
	self.adapterTagContent[tabKey]:setData(curCfg)
	self.tagContentData[tabKey] = curCfg
	self:updateAdapterTagShow(tabKey)
end

function WinChatTagSelect:updateAdapterTagShow(tabKey)
	for key, _ in pairs(self.adapterTagContent[tabKey].data) do
		local tagId = self.adapterTagContent[tabKey].data[key].tagId
		self.adapterTagContent[tabKey].data[key].isSelect = self.curSelectTagList[tagId]
	end
	self.adapterTagContent[tabKey]:notifyDataChange()
end

function WinChatTagSelect:updateOneTagSelectState(tagCfg)
	if tagCfg.isSelect then
		self.curSelectTagList[tagCfg.tagId] = nil
		self.selectCounts = self.selectCounts - 1
		self:updateAdapterTagShow(tagCfg.tagType)
		self:updateSelectTagNumShow()
	else
		if self.selectCounts >= self.totalCounts then
			return
		else
			self.curSelectTagList[tagCfg.tagId] = true
			self.selectCounts = self.selectCounts + 1
			self:updateAdapterTagShow(tagCfg.tagType)
			self:updateSelectTagNumShow()
		end
	end
end

function WinChatTagSelect:updateSelectTagNumShow()
	local selectStr =  "▢FF4169E1" .. self.selectCounts
	local totalStr = "▢FF363750/" .. self.totalCounts
	local resultStr = "▢FF363750" .. Lang:toText({"ui.chat.profile.tagSelectNum",selectStr, totalStr})
	self.txtSelectTxt:SetText(resultStr)

	local redList = {}
	for tagId, isSelect in pairs(self.curSelectTagList) do
		local item = TagsConfig:getItemByTagId(tagId)
		if item then
			if redList[item.tagType] then
				redList[item.tagType] = redList[item.tagType] + 1
			else
				redList[item.tagType] = 1
			end
		end
	end
	local tagTypeList = TagsConfig:getItemsTagTypeList()
	for i, tabKey in ipairs(tagTypeList) do
		self.tabItems[tabKey]:invoke("updateRedCounts", redList[tabKey] or 0)
	end
end

function WinChatTagSelect:onHide()
	UI:closeWnd("chatTagSelect")
end

function WinChatTagSelect:onShow(isShow, myTagData)
	if isShow then
		if not UI:isOpen(self) then
			UI:openWnd("chatTagSelect", myTagData)
		else
			self:onHide()
		end
	else
		self:onHide()
	end
end

function WinChatTagSelect:onOpen(myTagData)
	self._allEvent = {}
	self:subscribeEvent()
	self:initView(myTagData)
end

function WinChatTagSelect:onClose()
	if self._allEvent then
		for k, fun in pairs(self._allEvent) do
			fun()
		end
	end
end

return WinChatTagSelect
