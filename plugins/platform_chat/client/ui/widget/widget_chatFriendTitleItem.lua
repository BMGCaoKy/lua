local widget_base = require "ui.widget.widget_base"
---@class WidgetChatFriendTitleItem : widget_base
local WidgetChatFriendTitleItem = Lib.derive(widget_base)

function WidgetChatFriendTitleItem:init()
	widget_base.init(self, "ChatFriendTitleItem.json")
	self:initUI()
	self:initEvent()
	self:initView()
end

function WidgetChatFriendTitleItem:initUI()
	self.lytFriendList = self:child("ChatFriendTitleItem-friendList")
	self.lytInfoPanel = self:child("ChatFriendTitleItem-infoPanel")
	self.imgItemBg = self:child("ChatFriendTitleItem-itemBg")
	self.txtTitleName = self:child("ChatFriendTitleItem-titleName")
	self.imgShowIcon = self:child("ChatFriendTitleItem-showIcon")
	self.imgHideIcon = self:child("ChatFriendTitleItem-hideIcon")
	self.txtItemNum = self:child("ChatFriendTitleItem-itemNum")
	self.imgRedIcon = self:child("ChatFriendTitleItem-redIcon")
	self.txtRedNum = self:child("ChatFriendTitleItem-redNum")

	self.lytFriendList:SetYPosition({0, 40})
	self.friendData = {}
	-- 玩家好友列表
	self.cellDis = 10
	self.oneCellHeight = 57
	self.itemWidth = 445
	self.lytFriendHeight = 1
	self.friendGrid = UIMgr:new_widget("grid_view", self.lytFriendList)
	self.friendGrid:SetAutoColumnCount(false)
	self.friendGrid:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
	self.friendGrid:InitConfig(0, self.cellDis, 1)
	self.friendAdapter = UIMgr:new_adapter("common",self.itemWidth,self.oneCellHeight, "chatFriendInfoItem", "ChatFriendInfoItem.json")
	self.friendGrid:invoke("setAdapter", self.friendAdapter)

	self:setRequestDataState(0)
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatFriendTitleItem:initEvent()
	self:subscribe(self.lytInfoPanel, UIEvent.EventWindowClick, function()
		if self.clickFunc then
			self.clickFunc()
		else
			self.showState = not self.showState
			self:updateListViewShow()
		end
	end)

	self:subscribe(self.friendGrid, UIEvent.EventScrollMoveChange, function()
		if not self.friendType then
			return
		end
		if not self.friendData.pageNo then
			return
		end
		local offset = self.friendGrid:GetScrollOffset()
		local minOffset = self.friendGrid:GetMinScrollOffset()
		if offset < minOffset then
			if self.friendData.pageNo < self.friendData.totalPage-1 then
				if os.time() - self.isRequestingData > 1 then
					self:setRequestDataState(os.time())
					Me:doRequestServerFriendInfo(self.friendType, self.friendData.pageNo + 1)
				end
			end
		elseif offset > 0 then
			if self.friendData.pageNo > 0 then
				if os.time() - self.isRequestingData > 1 then
					self:setRequestDataState(os.time())
					Me:doRequestServerFriendInfo(self.friendType, self.friendData.pageNo - 1)
				end
			end
		end
	end)
end

function WidgetChatFriendTitleItem:initView()
	self.friendData = {}
	self:updateRedNum(0)
end

function WidgetChatFriendTitleItem:setRequestDataState(value)
	self.isRequestingData = value
end

function WidgetChatFriendTitleItem:initItemByData(friendType)
	self.friendType = friendType
	if friendType == Define.chatFriendType.apply then
		self.txtTitleName:SetText(Lang:toText("ui.chat.friend.applyFriend"))
		self.showState = false
		self:updateListViewShow()
		self.txtItemNum:SetVisible(false)
		self.imgShowIcon:SetVisible(false)
		self.imgHideIcon:SetVisible(false)
	elseif friendType == Define.chatFriendType.game then
		self.txtTitleName:SetText(Lang:toText("ui.chat.friend.gameFriend"))
		self.showState = false
		self.txtItemNum:SetVisible(true)
		self:updateListViewShow()
	elseif friendType == Define.chatFriendType.platform then
		self.txtTitleName:SetText(Lang:toText("ui.chat.friend.platformFriend"))
		self.showState = false
		self.txtItemNum:SetVisible(true)
		self:updateListViewShow()
	end
end

function WidgetChatFriendTitleItem:setClickFunc(clickFunc)
	self.clickFunc = clickFunc
end

-- 更新红点显示
function WidgetChatFriendTitleItem:updateRedNum(redNum)
	if redNum > 0 then
		self.imgRedIcon:SetVisible(true)
		self.txtRedNum:SetText(redNum)
	else
		self.imgRedIcon:SetVisible(false)
	end
	if self.friendType == Define.chatFriendType.apply then
		self.txtItemNum:SetVisible(false)
	end
end

-- 更新列表显示隐藏
function WidgetChatFriendTitleItem:updateListViewShow()
	self.imgShowIcon:SetVisible(self.showState)
	self.imgHideIcon:SetVisible(not self.showState)
	self.lytFriendList:SetVisible(self.showState)

	local initHeight = 39
	if self.showState then
		initHeight = initHeight + self.lytFriendHeight
	end
	self._root:SetHeight({0, initHeight})
end

function WidgetChatFriendTitleItem:updateFriendItemDataList(data)
	self.friendData = data
	self:updateFriendItemList()
end

function WidgetChatFriendTitleItem:updateFriendItemList()
	self.friendAdapter:clearItems()
	local onlineNum = 0
	local totalFriendNum = self.friendData.totalSize or 0
	self.dataList = self.friendData.dataList
	for key = 1, #self.dataList do
		if self.dataList[key].status ~= 30 then
			onlineNum = onlineNum + 1
		end
		local data = {
			friendType = self.friendType,
			friendData = self.dataList[key]
		}
		self.friendAdapter:addItem(data)
	end
	self.txtItemNum:SetText(Lang:toText({"ui.chat.number", onlineNum, totalFriendNum}))
	local showCellNum = #self.dataList
	if self.friendType == Define.chatFriendType.game then
		if showCellNum > 7 then
			showCellNum = 7
		end
		self.lytFriendHeight = showCellNum*(self.cellDis + self.oneCellHeight) + self.cellDis - 20
	elseif self.friendType == Define.chatFriendType.platform then
		if showCellNum > 6 then
			showCellNum = 6
		end
		self.lytFriendHeight = showCellNum*(self.cellDis + self.oneCellHeight) + self.cellDis + 40
	end
	self.lytFriendList:SetHeight({0, self.lytFriendHeight})
	self.friendGrid:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
	self.friendAdapter:notifyDataChange()
	self:updateListViewShow()
end
return WidgetChatFriendTitleItem


