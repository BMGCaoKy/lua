local widget_base = require "ui.widget.widget_base"
---@class WidgetChatPrivate : widget_base
local WidgetChatPrivate = Lib.derive(widget_base)
--- @type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")
function WidgetChatPrivate:init()
	widget_base.init(self, "ChatPrivate.json")
	self:initUI()
	self:initEvent()
end

function WidgetChatPrivate:initUI()
	self.lytHistoryPanel = self:child("ChatPrivate-historyPanel")
	self.txtHistoryTitle = self:child("ChatPrivate-historyTitle")
	self.lytHistoryContent = self:child("ChatPrivate-historyContent")
	self.lytPrivatePanel = self:child("ChatPrivate-privatePanel")
	self.imgIntimacyIcon = self:child("ChatPrivate-intimacyIcon")
	self.txtIntimacyStr = self:child("ChatPrivate-intimacyStr")
	self.txtPrivateName = self:child("ChatPrivate-privateName")
	self.btnBackBtn = self:child("ChatPrivate-backBtn")

	self.curPrivateUserId = false
	self.newMsgRedNum = {}
	self.privateHistoryData = {}
	self.privateHistoryCell = {}
	-- 历史聊天列表
	self.gridViewHistory = UIMgr:new_widget("grid_view")
	self.gridViewHistory:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
	self.gridViewHistory:InitConfig(0, 7, 1)
	self.lytHistoryContent:AddChildWindow(self.gridViewHistory)

	self.txtHistoryTitle:SetText(Lang:toText("ui.chat.friend.recent_contact"))
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatPrivate:initEvent()
	self:subscribe(self.btnBackBtn, UIEvent.EventButtonClick, function()
		UIChatManage:setCurPrivateFriend()
	end)

	Lib.subscribeEvent(Event.EVENT_UPDATE_FRIEND_PRIVATE_SHOW, function()
		self:updatePrivatePanelShow()
	end)

	Lib.subscribeEvent(Event.EVENT_RECEIVE_PRIVATE_MSG, function(extraMsgArgs)
		if (extraMsgArgs.senderUserId == Me.platformUserId) or (self.curPrivateUserId and self.curPrivateUserId == extraMsgArgs.keyId) then
			return
		end
		if self.newMsgRedNum[extraMsgArgs.keyId] then
			self.newMsgRedNum[extraMsgArgs.keyId] = self.newMsgRedNum[extraMsgArgs.keyId] + 1
		else
			self.newMsgRedNum[extraMsgArgs.keyId] = 1
		end
		self:updateHistoryListRedNum()
	end)
end

function WidgetChatPrivate:updatePrivatePanelShow()
	local curPrivateUserId = UIChatManage:getCurPrivateFriend()
	self.curPrivateUserId = curPrivateUserId
	if curPrivateUserId then
		self.lytHistoryPanel:SetVisible(false)
		self.lytPrivatePanel:SetVisible(true)

		self.txtPrivateName:SetText("")
		local detailInfo = UIChatManage:getUserDetailInfo(curPrivateUserId)
		if detailInfo then
			self:setUserDetailInfo(detailInfo)
		else
			self:listenDetailInfo(curPrivateUserId)
		end

		self.imgIntimacyIcon:SetVisible(false)
		self.txtIntimacyStr:SetVisible(false)
		UIChatManage:getFriendTopDataSpDisplay(curPrivateUserId,function(info)
			if not info then
				return
			end
			if info.txt1 then
				self.imgIntimacyIcon:SetVisible(true)
				self.txtIntimacyStr:SetVisible(true)
				self.txtIntimacyStr:SetText(info.txt1)
			end
		end)

		self.newMsgRedNum[curPrivateUserId] = 0
		self:updateHistoryListRedNum()
	else
		self.lytHistoryPanel:SetVisible(true)
		self.lytPrivatePanel:SetVisible(false)
	end
end

function WidgetChatPrivate:listenDetailInfo(platId)
	if not platId then
		Lib.logError("WidgetChatPrivate:listenDetailInfo id is nil!")
		return
	end
	if self.userDetailInfoCancel then
		self.userDetailInfoCancel()
	end
	self.userDetailInfoCancel = Lib.lightSubscribeEvent("error!!!!! EVENT_USER_DETAIL","EVENT_USER_DETAIL"..platId, function(data)
		self:setUserDetailInfo(data)
	end)
	UIChatManage:initDetailInfo(platId)
end
function WidgetChatPrivate:setUserDetailInfo(data)
	self.txtPrivateName:SetText(Lang:toText({"ui.chat.playerInfo.name", data.nickName}))
end

function WidgetChatPrivate:updateHistoryListRedNum()
	for index, cell in pairs(self.privateHistoryCell) do
		local curKeyId = self.privateHistoryCell[index]:invoke("getHistoryKeyId")
		self.privateHistoryCell[index]:invoke("updateRedNum", self.newMsgRedNum[curKeyId] or 0)
	end

	local totalNum = 0
	for keyId, val in pairs(self.newMsgRedNum) do
		totalNum = totalNum + val
	end
	Lib.emitEvent(Event.EVENT_UPDATE_PRIVATE_RED_NUM, totalNum)
end

function WidgetChatPrivate:updatePrivateHistoryList()
	self:cleanPrivateHistoryList()
	local allHistoryList = {}
	for _, data in pairs(UIChatManage.privateHistoryList) do
		table.insert(allHistoryList, data)
	end
	table.sort(allHistoryList, function(a,b)
		return a.lastMsgTime > b.lastMsgTime
	end)

	for _, data in pairs(allHistoryList) do
		self:addOneFriendPrivate(data)
	end
	self:updateHistoryListRedNum()
end

function WidgetChatPrivate:cleanPrivateHistoryList()
	for index, cell in pairs(self.privateHistoryCell) do
		self.gridViewHistory:RemoveItem(self.privateHistoryCell[index], true)
	end
	self.privateHistoryData = {}
	self.privateHistoryCell = {}
end

function WidgetChatPrivate:addOneFriendPrivate(data)
	local index = #self.privateHistoryData + 1
	self.privateHistoryData[index] = data
	self.privateHistoryCell[index] = UIMgr:new_widget("chatHistoryItem")
	self.privateHistoryCell[index]:invoke("initItemByData", data)
	self.gridViewHistory:AddItem(self.privateHistoryCell[index])

	--self.gridViewHistory:RemoveItem(self.privateHistoryCell[index], true)
end
return WidgetChatPrivate
