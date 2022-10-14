
local Status = {
    UNRECEIVED = 0,
    RECEIVED = 1,
    CURRENT = 2,
    MISS = 3,
}

local function checkImageStr(str, cfg)
    if str == "" then
        return ""
    end
    if str and str:find("set:") then
        return str
    end
    if str and cfg and cfg.plugin then
        local path = ResLoader:loadImage(cfg, str)
        return path
    end
    return nil
end

local function getItemName(data)
	local reward = data.reward and data.reward[1]
	local array = reward and reward.array
	if not reward or not array then
		return
	end
	return array[1] and array[1].desc
end

function M:init()
    WinBase.init(self, "sevenSingIn.json", true)

    local closeBtn = self:child("sevenSingIn-closeBtn")
	local titleText = self:child("sevenSingIn-titleName")
	local remainDesc = self:child("sevenSingIn-timerDesc")
	self.getItemBtn = self:child("sevenSingIn-getItem")
	self.timeText = self:child("sevenSingIn-timeText")
	self.countDownText = self:child("sevenSingIn-timerHour")
	self.itemContainer = self:child("sevenSingIn-itemContainer")
	self.itemGridView = UIMgr:new_widget("grid_view")
	self.itemContainer:AddChildWindow(self.itemGridView)
	self.itemGridView:invoke("AREA",{0 ,0 }, {0, 0}, {1, 0}, {1, 0})
	self.itemGridView:invoke("INIT_CONFIG", 10, 10, 4)
	self.getItemBtn:SetText(Lang:toText("gui.getItem"))

	titleText:SetText(Lang:toText("gui.sign.in"))

	self:subscribe(closeBtn, UIEvent.EventButtonClick, function()
		Me:sendPacket({pid = "CloseNewSignIn"})
        UI:closeWnd(self)
    end)

	self:subscribe(self.getItemBtn, UIEvent.EventButtonClick, function() --领取签到奖励
		local data = self.currentItem
		if data and data.index then
			Me:getSignInReward(data.signName, data.index, function(ok, msg)
				if ok and UI:isOpen(self) then
					self:setCanReceive(false)
					data.itemHadImg:SetVisible(true)
					data.hadMaskImg:setMask(1, 1, 0.25)
					--红点消失。
					Lib.emitEvent(Event.EVENT_SIGNIN_RED_POINT, false)
				end
			end)
		end
	end)

	self.signName = nil
	self.currentItem = nil
	self.currentIndex = nil
	self.itemWidth = (self.itemContainer:GetPixelSize().x - 30)/4
	self.itemHeight = (self.itemContainer:GetPixelSize().y - 10)/2
	
	self:setCanReceive(false)
	self:initSignInContent()
	self:startCountDown()
end

function M:onOpen()
	
end

local function checkSignIn(data)
	local today = tonumber(Lib.getYearDayStr(os.time()))
	if data.start_date == -1 or data.start_date > today then
		return false
	end
	if data.iscompleted and data.finishKey < today then
		return false
	end
	return true
end

function M:initSignInContent()
	self.itemCount = 0
	self.alreadyInit = false
	self.currentItem = nil
	for _, cfg in ipairs(Player.SignIns) do
		Me:getSignInData(cfg._name, function(uiData, signdata)
			if not UI:isOpen(self) then
				return
			end
			if signdata and checkSignIn(signdata) and not self.alreadyInit then
				self.alreadyInit = true
				local itemIndex = signdata.gift_group_index
				local items = cfg.sign_in_items
				if cfg.randomItem then
					items = cfg.sign_in_items[itemIndex]
				end
				for index, item in ipairs(items) do
					local data = {
						stauts = uiData[index],
						item = item,
						index = index,
						cfg = cfg
					}
					self:addSignItem(data)
				end
			end
			if self.currentItem then
				self:setCanReceive(true)
			end
		end)
	end
end

local theLastDay = World.cfg.signInLastDay or 7
function M:addSignItem(data)
	self.itemCount = self.itemCount + 1
	local strItemName = string.format("NewSignIn-Item-%d", self.itemCount)
    local signItem = GUIWindowManager.instance:CreateWindowFromTemplate(strItemName, "sevenSignItem.json")
	local itemHadImg = signItem:child(strItemName .."_sevenSignItem-hadImg")
	local itemDesc = signItem:child(strItemName .. "_sevenSignItem-itemDesc")
	local itemImg = signItem:child(strItemName .. "_sevenSignItem-itemImg")
	local itemDayNum = signItem:child(strItemName .. "_sevenSignItem-dayNum")
	local itemLeftBg = signItem:child(strItemName .. "_sevenSignItem-leftBg")
	local itemRightBg = signItem:child(strItemName .. "_sevenSignItem-rightBg")
	local hadMaskImg = signItem:child(strItemName .. "_sevenSignItem-hadMask")

	itemLeftBg:SetVisible(false)
	itemRightBg:SetVisible(false)
	itemHadImg:SetVisible(false)
	signItem:SetArea({ 0, 0 }, { 0, 0 }, { 0, self.itemWidth }, { 0, self.itemHeight})
	if self.itemCount == theLastDay then
		itemLeftBg:SetVisible(true)
		itemRightBg:SetVisible(true)
		itemImg:SetArea({ 0, 0 }, { 0.22, 0 }, { 0.25, 0 }, { 0.44, 0})
		itemHadImg:SetArea({ 0, 0 }, { -0.09, 0 }, { 0.25, 0 }, { 0.5, 0})
		signItem:SetArea({ 0, 0 }, { 0, 0 }, { 0, self.itemWidth*2+10 }, { 0, self.itemHeight})
	end

	itemDayNum:SetText(Lang:toText("gui.the." .. self.itemCount .. ".day"))
	itemImg:SetImage(checkImageStr(data.item and data.item.icon, data.cfg))
	itemDesc:SetText(Lang:toText(getItemName(data and data.item)))
	if data.stauts == Status.RECEIVED then
		itemHadImg:SetVisible(true)
		hadMaskImg:setMask(1, 1, 0.25)
	end
	if data.stauts == Status.CURRENT then
		self.currentItem = {
			itemHadImg = itemHadImg,
			hadMaskImg = hadMaskImg,
			index = data.index,
			signName = data.cfg._name
		}
	end
	self.itemGridView:invoke("ITEM", signItem)
end

function M:setCanReceive(whether)
	if whether then
		self.getItemBtn:SetTouchable(true)
		self.getItemBtn:SetText(Lang:toText("gui.getItem"))
		self.getItemBtn:SetNormalImage("set:team.json image:green_btn")
		self.getItemBtn:SetPushedImage("set:team.json image:green_btn")
	else
		self.getItemBtn:SetTouchable(false)
		self.getItemBtn:SetText(Lang:toText("gui.alreadyGet"))
		self.getItemBtn:SetNormalImage("set:party_pg_shop_img.json image:btn_bg.png")
		self.getItemBtn:SetPushedImage("set:party_pg_shop_img.json image:btn_bg.png")
	end
end

function M:startCountDown()
	local time = Lib.getNextDayTime() - os.time()
	if self.countDownFunc then
		self.countDownFunc()
		self.countDownFunc = nil
	end
	self.countDownFunc = World.Timer(20, function()
		time = time - 1
		if UI:isOpen(self) then
			local text = {"gui.remain",string.format("%02d:%02d:%02d",Lib.timeFormatting(time))}
			self.timeText:SetText(Lang:toText(text))
		end
		if time < 0 then
			return false
		end
		return true
	end)
end

return M