---@class WinChatEmoji : WinBase
local WinChatEmoji = M

local chatSetting = World.cfg.chatSetting or {}
local EmojiConfig = T(Config, "EmojiConfig")
local ShortConfig = T(Config, "ShortConfig")

function WinChatEmoji:init()
	WinBase.init(self, "ChatEmoji.json")
	self:initUI()
	self:initEvent()

	if World.cfg.chatSetting and World.cfg.chatSetting.chatLevel then
		self:root():SetLevel(World.cfg.chatSetting.chatLevel)
	end
end

function WinChatEmoji:initUI()
	self.lytPanelBg = self:child("ChatEmoji-panelBg")
	self.lytTabPanel = self:child("ChatEmoji-tabPanel")
	self.lytContent = self:child("ChatEmoji-content")
	self.btnClose = self:child("ChatEmoji-Close")

	self.tabGridView = UIMgr:new_widget("grid_view")
	self.tabGridView:SetMoveAble(false)
	--self.tabGridView:InitConfig(0, 0, #chatSetting.emojiTabList)
	self.tabGridView:InitConfig(0, 0, 4)
	self.tabGridView:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
	self.lytTabPanel:AddChildWindow(self.tabGridView)
	self:initTabList()
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WinChatEmoji:initEvent()
	self:subscribe(self.btnClose, UIEvent.EventButtonClick, function()
		self:onHide()
	end)
end

--注册event事件监听，注意这里的事件是show的时候注册，close的时候注销的，常驻事件可在initEvent里面注册
function WinChatEmoji:subscribeEvent()
	--self._allEvent[#self._allEvent + 1] = Lib.subscribeEvent(Event.EVENT_CLOSE_PRE_BATTLE_ANIMATION, function()

	--end)
end

--界面数据初始化
function WinChatEmoji:initView()
	self:updateTabViewShow(self.curSelectTab)
end

-- 初始化页签
function WinChatEmoji:initTabList()
	self.tabItems = {}
	self.lstEContent = {}
	self.adapterEContent = {}
	self.eContentData = {}
	self.curSelectTab = 0
	for _, tabKey in ipairs(chatSetting.emojiTabList) do
		local item = self.tabItems[tabKey]
		if not item then
			item = UIMgr:new_widget("chatEmojiTab")
			item:SetArea({ 0, 0 }, { 0, 0 }, { 0, 108 }, { 0, 55 })
			self.tabGridView:AddItem(item)
			self.tabItems[tabKey] = item
		end
		item:invoke("initTabKey", tabKey)
		item:invoke("setTabClickFunc", function(tabKey)
			self:updateTabViewShow(tabKey)
		end)

		self.lstEContent[tabKey] = UIMgr:new_widget("grid_view")
		self.lstEContent[tabKey]:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
		self.lytContent:AddChildWindow(self.lstEContent[tabKey])

		if tabKey == Define.chatEmojiTab.FACE then
			self.lstEContent[tabKey]:InitConfig(0, 0, 6)
			self.adapterEContent[tabKey] = UIMgr:new_adapter("common",101,101, "chatEmojiItem", "ChatEmojiItem.json")
			self.lstEContent[tabKey]:invoke("setAdapter", self.adapterEContent[tabKey])
		elseif tabKey == Define.chatEmojiTab.GOODS then
			self.lstEContent[tabKey]:InitConfig(19, 5, 7)
			self.adapterEContent[tabKey] = UIMgr:new_adapter("common",70,70, "chatEmojiGoods", "ChatEmojiGoods.json")
			self.lstEContent[tabKey]:invoke("setAdapter", self.adapterEContent[tabKey])
		elseif tabKey == Define.chatEmojiTab.PET then
			self.lstEContent[tabKey]:InitConfig(6, 6, 3)
			self.adapterEContent[tabKey] = UIMgr:new_adapter("common",196,76, "chatEmojiPet", "ChatEmojiPet.json")
			self.lstEContent[tabKey]:invoke("setAdapter", self.adapterEContent[tabKey])
		elseif tabKey == Define.chatEmojiTab.SHORT then
			self.lstEContent[tabKey]:InitConfig(0, 5, 1)
			self.adapterEContent[tabKey] = UIMgr:new_adapter("common",605,30, "chatEmojiShort", "ChatEmojiShort.json")
			self.lstEContent[tabKey]:invoke("setAdapter", self.adapterEContent[tabKey])
		end
	end
	self:updateTabViewShow(Define.chatEmojiTab.FACE)
end

function WinChatEmoji:updateTabViewShow(tabKey)
	self.curSelectTab = tabKey
	for index, item in pairs(self.tabItems) do
		item:invoke("updateTabIconShow", tabKey)
		self.lstEContent[index]:SetVisible(tabKey == index)
	end
	if not self.eContentData[tabKey] then
		if tabKey == Define.chatEmojiTab.FACE then
			self:initEmojiContent(tabKey)
		elseif tabKey == Define.chatEmojiTab.GOODS then
			self:initGoodsContent(tabKey)
		elseif tabKey == Define.chatEmojiTab.PET then
			self:initPetContent(tabKey)
		elseif tabKey == Define.chatEmojiTab.SHORT then
			self:initShortContent(tabKey)
		end
	end
end

function WinChatEmoji:initEmojiContent(tabKey)
	local cfg = EmojiConfig:getItems()
	self.adapterEContent[tabKey]:setData(cfg)
	self.eContentData[tabKey] = cfg
end

function WinChatEmoji:initGoodsContent(tabKey)
	local goodList = Me:getChatAllBagItemList()
	self.adapterEContent[tabKey]:setData(goodList)
	self.eContentData[tabKey] = goodList
end

function WinChatEmoji:initPetContent(tabKey)
	local petList = Me:getChatAllPetList()
	self.adapterEContent[tabKey]:setData(petList)
	self.eContentData[tabKey] = petList
end

function WinChatEmoji:initShortContent(tabKey)
	local cfg = ShortConfig:getItems()
	self.adapterEContent[tabKey]:setData(cfg)
	self.eContentData[tabKey] = cfg
end

function WinChatEmoji:onHide()
	UI:closeWnd("chatEmoji")
end

function WinChatEmoji:onShow(isShow)
	if isShow then
		if not UI:isOpen(self) then
			UI:openWnd("chatEmoji")
		else
			self:onHide()
		end
	else
		self:onHide()
	end
end

function WinChatEmoji:onOpen()
	self._allEvent = {}
	self:subscribeEvent()
	self:initView()
end

function WinChatEmoji:onClose()
	if self._allEvent then
		for k, fun in pairs(self._allEvent) do
			fun()
		end
	end
	self.eContentData[Define.chatEmojiTab.GOODS] = nil
	self.eContentData[Define.chatEmojiTab.PET] = nil
end

return WinChatEmoji
