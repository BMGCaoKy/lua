local widget_base = require "ui.widget.widget_base"
---@class WidgetChatFriend : widget_base
local WidgetChatFriend = Lib.derive(widget_base)
local operationType = FriendManager.operationType
local chatSetting = World.cfg.chatSetting or {}

function WidgetChatFriend:init()
	widget_base.init(self, "ChatFriend.json")
	self:initUI()
	self:initEvent()
	self:initView()
end

function WidgetChatFriend:initUI()
	self.lytApplyPanel = self:child("ChatFriend-applyPanel")
	self.txtApplyTitle = self:child("ChatFriend-applyTitle")
	self.btnBackBtn = self:child("ChatFriend-backBtn")
	self.lytApplyContent = self:child("ChatFriend-applyContent")
	self.btnAcceptBtn = self:child("ChatFriend-acceptBtn")
	self.txtAcceptName = self:child("ChatFriend-acceptName")
	self.btnRejectBtn = self:child("ChatFriend-rejectBtn")
	self.txtRejectName = self:child("ChatFriend-rejectName")

	self.lytFriendPanel = self:child("ChatFriend-friendPanel")
	self.txtFriendTitle = self:child("ChatFriend-friendTitle")
	self.lytFriendContent = self:child("ChatFriend-friendContent")
	self.btnProfileBtn = self:child("ChatFriend-profileBtn")
	self.txtProfileName = self:child("ChatFriend-profileName")
	self.btnAddBtn = self:child("ChatFriend-addBtn")
	self.txtAddName = self:child("ChatFriend-addName")

	self.btnProfileBtn:SetVisible(false)
	self.btnAddBtn:SetVisible(false)

	self.curApplyNum = 0
	self.friendApplyData = {}
	self.friendApplyCell = {}
	-- 好友列表
	self.gridViewFriend = UIMgr:new_widget("grid_view")
	self.gridViewFriend:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
	self.gridViewFriend:InitConfig(0, 1, 1)
	self.lytFriendContent:AddChildWindow(self.gridViewFriend)
	self:initFriendTitleList()
	self.gridViewFriend:SetMoveAble(false)

	-- 好友申请列表
	self.gridViewApply = UIMgr:new_widget("grid_view")
	self.gridViewApply:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
	self.gridViewApply:InitConfig(0, 7, 1)
	self.lytApplyContent:AddChildWindow(self.gridViewApply)


	self.txtApplyTitle:SetText(Lang:toText("ui.chat.friend.apply"))
	self.txtAcceptName:SetText(Lang:toText("ui.chat.friend.agreeAll"))
	self.txtRejectName:SetText(Lang:toText("ui.chat.friend.refusedAll"))

	self.txtFriendTitle:SetText(Lang:toText("ui.chat.friend.list"))
	self.txtAddName:SetText(Lang:toText("ui.chat.friend.addFriend"))
	self.txtProfileName:SetText(Lang:toText("ui.chat.friend.myProfile"))
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatFriend:initEvent()
	self:subscribe(self.btnBackBtn, UIEvent.EventButtonClick, function()
		self.curViewType = 1
		self:updateViewType()
	end)

	self:subscribe(self.btnAcceptBtn, UIEvent.EventButtonClick, function()
		for index, val in pairs(self.friendApplyCell) do
			self:dealOneFriendApply(index, true)
		end
	end)
	self:subscribe(self.btnRejectBtn, UIEvent.EventButtonClick, function()
		for index, val in pairs(self.friendApplyCell) do
			self:dealOneFriendApply(index, false)
		end
	end)
	self:subscribe(self.btnProfileBtn, UIEvent.EventButtonClick, function()
		Lib.emitEvent(Event.EVENT_OPEN_PLAYER_INFORMATION, Me.platformUserId)
	end)
	self:subscribe(self.btnAddBtn, UIEvent.EventButtonClick, function()
		Me:clickSearchFriendBtn()
	end)

	--self:subscribe(self.gridViewFriend, UIEvent.EventScrollMoveChange, function()
	--	local offset = self.gridViewFriend:GetScrollOffset()
	--	local minOffset = self.gridViewFriend:GetMinScrollOffset()
	--end)
end

function WidgetChatFriend:initView()
	self.curViewType = 1
	self:updateViewType()
end

function WidgetChatFriend:updateProfileAndAddBtnShow()
	if chatSetting.isShowProfileBtn then
		self.btnProfileBtn:SetVisible(Me:checkChatMainProfileIsOpen())
	else
		self.btnProfileBtn:SetVisible(false)
	end
	if chatSetting.isShowAddFriendBtn then
		self.btnAddBtn:SetVisible(Me:checkChatMainFindFriendIsOpen())
	else
		self.btnAddBtn:SetVisible(false)
	end
end

function WidgetChatFriend:showMyFriendListView()
	self.curViewType = 2
	self:updateViewType()
end

function WidgetChatFriend:updateViewType()
	if self.curViewType == 2 then
		self.lytApplyPanel:SetVisible(true)
		self.lytFriendPanel:SetVisible(false)
	else
		self.lytApplyPanel:SetVisible(false)
		self.lytFriendPanel:SetVisible(true)
	end
end

function WidgetChatFriend:updateFriendApplyList(requests)
	self:cleanFriendApplyList()
	for _, data in pairs(requests) do
		self:addOneFriendApply(data)
	end
end

function WidgetChatFriend:cleanFriendApplyList()
	for index, cell in pairs(self.friendApplyCell) do
		self.gridViewApply:RemoveItem(self.friendApplyCell[index], true)
	end
	self.curApplyNum = 0
	self.friendApplyCell = {}
	self.friendApplyData = {}
	self:updateApplyRedNum()
end

function WidgetChatFriend:addOneFriendApply(data)
	self.curApplyNum = self.curApplyNum + 1
	local index = self.curApplyNum
	self.friendApplyData[index] = data
	self.friendApplyCell[index] = UIMgr:new_widget("chatFriendApplyItem")
	self.friendApplyCell[index]:invoke("initItemByData", data, index)
	self.gridViewApply:AddItem(self.friendApplyCell[index])

	local dealApplyFunc = function(index, result)
		self:dealOneFriendApply(index, result)
	end
	self.friendApplyCell[index]:invoke("setResponseApplyFunc", dealApplyFunc)
	self:updateApplyRedNum()
end

-- 同意、拒绝好友申请
function WidgetChatFriend:dealOneFriendApply(index, result)
	if result then
		AsyncProcess.FriendOperation( operationType.AGREE, self.friendApplyData[index].userId)
		Me:doRequestServerFriendInfo(Define.chatFriendType.game)
	else
		AsyncProcess.FriendOperation( operationType.REFUSE, self.friendApplyData[index].userId)
	end
	self.gridViewApply:RemoveItem(self.friendApplyCell[index], true)
	self.friendApplyCell[index] = nil
	self.friendApplyData[index] = nil
	self:updateApplyRedNum()
end

function WidgetChatFriend:updateApplyRedNum()
	local num = 0
	for key, val in pairs(self.friendApplyCell) do
		num = num + 1
	end
	self.friendTitleItem[Define.chatFriendType.apply]:invoke("updateRedNum", num)
	Lib.emitEvent(Event.EVENT_UPDATE_FRIEND_RED_NUM, num)
end

function WidgetChatFriend:initFriendTitleList()
	self.friendTitleItem = {}
	local showMyFriend = function()
		self:showMyFriendListView()
	end
	self.friendTitleItem[Define.chatFriendType.apply] = self:addFriendTitleItem(Define.chatFriendType.apply)
	self.friendTitleItem[Define.chatFriendType.apply]:invoke("setClickFunc", showMyFriend)

	self.friendTitleItem[Define.chatFriendType.game] = self:addFriendTitleItem(Define.chatFriendType.game)
	self.friendTitleItem[Define.chatFriendType.platform] = self:addFriendTitleItem(Define.chatFriendType.platform)
end

function WidgetChatFriend:addFriendTitleItem(friendType)
	local cell = UIMgr:new_widget("chatFriendTitleItem")
	cell:invoke("initItemByData",friendType)
	self.gridViewFriend:AddItem(cell)
	return cell
end

-- 初始化同玩好友
function WidgetChatFriend:initGameFriendList(data)
	self.friendTitleItem[Define.chatFriendType.game]:invoke("updateFriendItemDataList", data)
end

-- 初始化平台好友
function WidgetChatFriend:initPlatformFriendList(data)
	self.friendTitleItem[Define.chatFriendType.platform]:invoke("updateFriendItemDataList", data)
end
return WidgetChatFriend
