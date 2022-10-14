---@class WinChatMini : WinBase
local WinChatMini = M

local UIAnimationManager = T(UILib, "UIAnimationManager") --@type UIAnimationManager
local LuaTimer = T(Lib, "LuaTimer")
local chatSetting = World.cfg.chatSetting or {}
local EmojiConfig = T(Config, "EmojiConfig")
---@type UIChatManage
local UIChatManage = T(UIMgr, "UIChatManage")

function WinChatMini:init()
	WinBase.init(self, "ChatMini.json")
	self:initUI()
	self:initEvent()
	self:subscribeEvent()
	self:initMiniPos()
end

function WinChatMini:initUI()
	self.lytContentPos = self:child("ChatMini-Content-Pos")
	self.imgContentBg = self:child("ChatMini-Content-Bg")
	self.btnGotoBottom = self:child("ChatMini-Go-Bottom")
	self.imgArray = self:child("ChatMini-array")
	self.lytMiniClose = self:child("ChatMini-Mini-Close")
	self.lytSizeControl = self:child("ChatMini-Size-Control")

	self.newMsgNum = 0
	self.horizontalAlignment = chatSetting.alignment and chatSetting.alignment.horizontalAlignment or 1
	self.verticalAlignment = chatSetting.alignment and chatSetting.alignment.verticalAlignment or 2
	self.contentItemPool = {}

	-- 小聊天窗口的列表
	self.lstContent = UIMgr:new_widget("grid_view")
	self.lstContent:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 1, 0 })
	self.lstContent:InitConfig(0, 1, 1)
	self.lytContentPos:AddChildWindow(self.lstContent)
	self.contentInfoCache = {}

	self.imgArray:SetVisible(false)
	self.btnGotoBottom:SetVisible(false)

	if World.cfg.chatSetting and World.cfg.chatSetting.chatLevel then
		self:root():SetLevel(World.cfg.chatSetting.chatLevel)
		self.lytSizeControl:SetVisible(World.cfg.chatSetting.isShowMiniSizeBtn )
	end
end

--注册按钮点击事件，常驻事件监听也可在这里添加
function WinChatMini:initEvent()
	self:subscribe(self.btnGotoBottom, UIEvent.EventButtonClick, function()
		self:gotoBottom()
	end)

	self:lightSubscribe("error!!!!! script_client win_chat lytSizeControl event : EventWindowTouchDown", self.lytSizeControl, UIEvent.EventWindowTouchDown, function()
		if self.winSizeType == Define.chatWinSizeType.smallMiniChat then
			self.winSizeType = Define.chatWinSizeType.bigMiniChat
		elseif self.winSizeType == Define.chatWinSizeType.bigMiniChat then
			self.winSizeType = Define.chatWinSizeType.smallMiniChat
		end
		self:updateWinSize()
	end)

	self:lightSubscribe("error!!!!! script_client win_chat lytMiniClose event : EventWindowTouchDown", self.lytMiniClose, UIEvent.EventWindowTouchDown, function()
		self:onHide()
	end)
end

--注册event事件监听，注意这里的事件是show的时候注册，close的时候注销的，常驻事件可在initEvent里面注册
function WinChatMini:subscribeEvent()
	self:lightSubscribe("error!!!!! script_client win_chat lstContent event : EventWindowTouchDown", self.lstContent, UIEvent.EventWindowTouchDown, function()
		self.lstTouchDown = true
	end)

	self:lightSubscribe("error!!!!! script_client win_chat lstContent event : EventWindowTouchDown", self.lstContent, UIEvent.EventWindowTouchMove, function()
		self.lstMove = true
	end)

	self:lightSubscribe("error!!!!! script_client win_chat lstContent event : EventWindowTouchDown", self.lstContent, UIEvent.EventWindowTouchUp, function()
		if self.lstTouchDown and not self.lstMove then
			UIChatManage:showChatViewByType(Define.chatWinSizeType.mainChat)
		end
		self.lstTouchDown = false
		self.lstMove = false
	end)

	Lib.lightSubscribeEvent("error!!!!! script_client win_chat Lib event : EVENT_SET_CHAT_ALIGNMENT", Event.EVENT_SET_CHAT_ALIGNMENT, function(horizontalType, verticalType, offset)
		self:setAlignmentType(horizontalType, verticalType, offset or false)
	end)

	self:subscribe(self.lstContent, UIEvent.EventScrollMoveChange, function()
		if  not self.isShow or not self.btnGotoBottom:IsVisible() then return end
		local offset = self.lstContent:GetScrollOffset()
		local minOffset = self.lstContent:GetMinScrollOffset()
		if offset <= minOffset then
			self.btnGotoBottom:SetVisible(false)
			self.newMsgNum = 0
		end
	end)
end

--界面数据初始化
function WinChatMini:initView(winSizeType)
	self.winSizeType = winSizeType or Define.chatWinSizeType.smallMiniChat
	self:updateWinSize()
end

function M:setAlignmentType(horizontalType, verticalType, offset)
	if not horizontalType then return end
	if not verticalType then return end
	self.horizontalAlignment = horizontalType
	self.verticalAlignment = verticalType
	self.alignmentOffset = offset
	self:initMiniPos()
end

function M:initMiniPos()
	self._root:SetHorizontalAlignment(self.horizontalAlignment)
	self._root:SetVerticalAlignment(self.verticalAlignment)

	local offset =chatSetting.alignment and chatSetting.alignment.offset or {0,0,0,0}
	local _off = self.alignmentOffset or offset
	self._root:SetXPosition({_off[1],_off[2]})
	self._root:SetYPosition({_off[3],_off[4]})
end

function WinChatMini:updateWinSize()
	self._root:SetBackImage("")
	local size = chatSetting.alignment and chatSetting.alignment.miniSize or {450, 250, 400}
	self._root:SetWidth({ 0, size[1] })
	if self.winSizeType == Define.chatWinSizeType.smallMiniChat then
		self._root:SetHeight({ 0, size[2] })
		self.lytSizeControl:SetBackImage("set:chat.json image:btn_0_unfold")
		Lib.emitEvent(Event.EVENT_SET_CHAT_BAR_POS, false)
		Plugins.CallTargetPluginFunc("email_system", "SetEmailBarBigState", false)
	elseif self.winSizeType == Define.chatWinSizeType.bigMiniChat then
		self._root:SetHeight({ 0, size[3] })
		self.lytSizeControl:SetBackImage("set:chat.json image:btn_0_down")
		Lib.emitEvent(Event.EVENT_SET_CHAT_BAR_POS, true)
		Plugins.CallTargetPluginFunc("email_system", "SetEmailBarBigState", true)
	end
	self:refreshWin()
end

function M:refreshWin()
	self.lstContent:InitConfig(0, 1, 1)
	self:gotoBottom()
end

local function cleanDoubleMaxInfoTable(tb)
	local tbCnt = #tb
	if tbCnt> Define.miniChatMaxCnt then
		table.remove(tb,1)
	end
end

function M:addMiniMsgInList(data)
	--未打开聊天只做数据记录，不做界面更新
	if not self.isShow then
		table.insert(self.contentInfoCache,data)
		cleanDoubleMaxInfoTable(self.contentInfoCache)
		return
	end
	local pageCnt = self.lstContent:GetItemCount()
	if pageCnt >=Define.miniChatMaxCnt then
		local item = self.lstContent:GetItem(0)
		self.lstContent:RemoveItem(item,false)
		item:invoke("initViewByData",data)
		self.lstContent:AddItem(item)
	else
		local cell
		if #self.contentItemPool>0 then
			cell = table.remove(self.contentItemPool)
		else
			cell = UIMgr:new_widget("chatContentItem")
		end
		cell:invoke("initViewByData",data)
		self.lstContent:AddItem(cell)
	end
end

--到最底部
function M:gotoBottom()
	self.btnGotoBottom:SetVisible(false)
	self.newMsgNum = 0
	World.LightTimer("lstScroll",2,function()
		self.lstContent:GoLastScroll()
	end)
end

--清空聊天item
function M:cleanMiniChatItem()
	local pageCnt = self.lstContent:GetItemCount()
	for i = 1, pageCnt do
		local item = self.lstContent:GetItem(0)
		self.lstContent:RemoveItem(item,false)
		table.insert(self.contentItemPool,item)
	end
	self.contentInfoCache = {}
end

function M:refreshMiniChatWin()
	self:cleanMiniChatItem()
	self:loadAllMiniMsgItem()
	self.lstContent:GoLastScroll()
end

function M:loadAllMiniMsgItem()
	local miniChatShowDataList = UIChatManage:getMiniChatShowDataList()
	for _, data in pairs(miniChatShowDataList) do
		self:addMiniMsgInList(data)
	end
end

function M:loadMiniMsgCache()
	local cnt = #self.contentInfoCache
	local doCnt = cnt - math.max(cnt-Define.MainChatMaxCnt,0)
	for i = 1,doCnt do
		self:addMiniMsgInList(self.contentInfoCache[cnt-doCnt+i])
	end
	--处理完成，清空缓存
	self.contentInfoCache = {}
end

-- 收到新消息，仅仅做提示
function M:receiveChatMessage(type, msg, fromname)
	local calcOffset = self.lstContent:GetScrollOffset() or 0
	local upTooFar = (calcOffset - self.lstContent:GetMinScrollOffset()) > 40

	if upTooFar and fromname ~= Me.name then
		self:addNewMsgTips()
	else
		for _, pageType in pairs(UIChatManage:getCurMiniMsgList()) do
			if pageType == type then
				self:gotoBottom()
				break
			end
		end
	end
end

--添加未读消息提示
function M:addNewMsgTips()
	if not self.newMsgNum then
		self.newMsgNum = 0
	end
	self.newMsgNum = self.newMsgNum + 1
	self.btnGotoBottom:SetVisible(true)
	self.btnGotoBottom:SetText(Lang:toText({ "ui.chat.newMsg", "▢FFAAEF16" .. self.newMsgNum}))
end

function WinChatMini:onHide()
	UI:closeWnd("chatMini")
end

function WinChatMini:onShow(isShow, winSizeType)
	if isShow then
		if not UI:isOpen(self) then
			UI:openWnd("chatMini", winSizeType)
			self:loadMiniMsgCache()
		else
			self:updateWinSize()
		end
	else
		self:onHide()
	end
end

function WinChatMini:onOpen(winSizeType)
	self.isShow = true
	self:initView(winSizeType)
end

function WinChatMini:onClose()
	self.isShow = false
end

return WinChatMini
