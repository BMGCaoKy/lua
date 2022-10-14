local widget_base = require "ui.widget.widget_base"
---@class WidgetChatNearWnd : widget_base
local WidgetChatNearWnd = Lib.derive(widget_base)

function WidgetChatNearWnd:init()
	widget_base.init(self, "ChatNearWnd.json")
	self._allEvent = {}
	self:initUI()
	self:initEvent()
end

function WidgetChatNearWnd:initUI()
	self.lytNearPanel = self:child("ChatNearWnd-nearPanel")
	self.txtNearTitle = self:child("ChatNearWnd-nearTitle")
	self.lytNearContent = self:child("ChatNearWnd-nearContent")

	-- 附近的人列表
	self.gridViewNear = UIMgr:new_widget("grid_view")
	self.gridViewNear:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
	self.gridViewNear:InitConfig(0, 7, 1)
	self.lytNearContent:AddChildWindow(self.gridViewNear)
	self.friendNearData = {}
	self.friendNearCell = {}
	
	self.txtNearTitle:SetText(Lang:toText("ui.chat.friend.near"))
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WidgetChatNearWnd:initEvent()
	self._allEvent[#self._allEvent + 1] = Lib.subscribeEvent(Event.EVENT_UPDATE_CHAT_NEAR_PLAYER, function()
		local playersInfo = Game.GetAllPlayersInfo()
		local data = {}
		for _, info in pairs(playersInfo) do
			if info.userId ~= Me.platformUserId then
				local _info = Lib.copy(UserInfoCache.GetCache(info.userId))
				if _info then
					table.insert(data, _info)
				end
			end
		end
		self:updateNearPlayerList(data)
	end)
end

function WidgetChatNearWnd:refreshNearData()
	local userIds = {}
	local playersInfo = Game.GetAllPlayersInfo()
	for _, info in pairs(playersInfo) do
		table.insert(userIds, info.userId)
	end
	UserInfoCache.LoadCacheByUserIds(userIds, "EVENT_UPDATE_CHAT_NEAR_PLAYER")
end

function WidgetChatNearWnd:updateNearPlayerList(requests)
	self:cleanNearPlayerList()
	for _, data in pairs(requests) do
		self:addOneNearPlayer(data)
	end
end

function WidgetChatNearWnd:cleanNearPlayerList()
	for index, cell in pairs(self.friendNearCell) do
		self.gridViewNear:RemoveItem(self.friendNearCell[index], true)
	end
	self.curNearNum = 0
	self.friendNearCell = {}
	self.friendNearData = {}
end

function WidgetChatNearWnd:addOneNearPlayer(data)
	self.curNearNum = self.curNearNum + 1
	local index = self.curNearNum
	self.friendNearData[index] = data
	self.friendNearCell[index] = UIMgr:new_widget("chatNearItem")
	self.friendNearCell[index]:invoke("initItemByData", data, index)
	self.gridViewNear:AddItem(self.friendNearCell[index])
end

function WidgetChatNearWnd:onDestroy()
	if self._allEvent then
		for k, fun in pairs(self._allEvent) do
			fun()
		end
	end
end

return WidgetChatNearWnd
