
local item_manager = require "item.item_manager"

local TradeCfg = World.cfg.tradeCfg
local PageCellNum = 9
local MaxSelected = 6
local CountDownTime = 3
local MaxPageNum = TradeCfg and TradeCfg.maxPageNum or 4
local SortGist = TradeCfg and TradeCfg.sortGist or "sortGist"
local CountDownColor = TradeCfg and TradeCfg.color or "Gold"
local SureItemBg = TradeCfg and TradeCfg.sureItemBg or "set:trade.json image:sureItem.png"

local ImageType = {
	Red = "set:red_numbers.json image:",
	Bule = "set:blue_numbers.json image:",
	Gold = "set:gold_numbers.json image:",
	Purple = "set:purple_numbers.json image:"
}

local ClickType = {
	left = 1,
	right = 2
}

local Tipdata = {
	showTypeTop = 2,
	showTime = 40
}

local function getBorderColor(r,g,b)
	return tostring(r/255) .. " " .. tostring(g/255) .. " " .. tostring(b/255) .. " 1"
end

local  sureBorder =  getBorderColor(14, 87, 23)
local  notSureBorder = getBorderColor(199, 30, 21)

local function getShowImage(digit,cfgKey)
	local cfg = cfgKey and World.cfg[cfgKey]
	local image = cfg and cfg[digit]
	if image then
		return image
	end
	local str = ImageType[CountDownColor] .. digit .. ".png"
	return str
end

local function createGridView(father, x, y ,z)
	local gridView = UIMgr:new_widget("grid_view")
    gridView:invoke("AUTO_COLUMN", false)
    gridView:invoke("INIT_CONFIG", x, y, z)
	gridView:invoke("MOVE_ABLE", false)
    father:AddChildWindow(gridView)
	return gridView
end

function M:init()
	WinBase.init(self, "trade_frame.json")

	self:child("BackpackDisplay-Title-Name"):SetText(Lang:toText("TREADE"))
	self:child("Notice-No-Text"):SetText(Lang:toText("trade.left.notice"))
	self:child("Notice-Yes-Text"):SetText(Lang:toText("trade.right.notice"))
	self:child("Notice-Sure-Text"):SetText(Lang:toText("trade.center.notice"))
	local tradeItemContainer = self:child("BackpackDisplay-Content-Container")
	local leftTopContainer = self:child("trade_frame-left-container")
	local leftDownContainer = self:child("trade_frame-down-container")
	self.topName = self:child("trade_frame-left-top-name")
	self.downName = self:child("trade_frame-left-down-name")
	self.topConfrimBtn = self:child("trade_frame-left-top-btn")
	self.downConfrimBtn = self:child("trade_frame-left-down-btn")
	self.topConfrimText = self:child("trade_frame-left-top-confrim")
	self.downConfrimText = self:child("trade_frame-left-down-Confrim")
	self.topOkImg = self:child("trade_frame-left-top-ok")
	self.downOkImg = self:child("trade_frame-left-down-ok")
	self.downBg = self:child("trade_frame-left-down")
	self.topBg = self:child("trade_frame-left-top")
	self.countDown = self:child("trade_frame-countDown")
	self.singByte = self:child("trade_frame-SingByte")
	self.tradeContent = self:child("trade_frame-Trade-Content")
	self.noticeContent = self:child("Notice-Content")
	self.noticeDetail = self:child("Notice-Detail")
	self.noticeSure = self:child("Notice-Sure")
	self.noticeYes = self:child("Notice-Yes")
	self.noticeNo = self:child("Notice-No")
	self.tradeGridView = createGridView(tradeItemContainer, 15, 10, 3)
	self.downGridView = createGridView(leftDownContainer, 10, 5, 3)
	self.topGridView = createGridView(leftTopContainer, 10, 5, 3)
	self.cellwidth1 = (leftTopContainer:GetPixelSize().x  - 20)/ 3
	self.cellHeight1 = (leftTopContainer:GetPixelSize().y - 5) / 2
	self.cellwidth2 = (tradeItemContainer:GetPixelSize().x  - 30)/ 3
	self.cellHeight2 = (tradeItemContainer:GetPixelSize().y  - 20) / 3
	self:subscribe(self.noticeYes , UIEvent.EventButtonClick, function()
		if self.sessionId then
			Me:sendPacket({pid = "AcceptTrade", sessionId = self.sessionId})
			self.sessionId = nil
		end
		UI:closeWnd(self)
	end)
	self:subscribe(self.noticeNo, UIEvent.EventButtonClick, function()
		if self.sessionId then
			Me:sendPacket({pid = "RefuseTrade", sessionId = self.sessionId})
			self.sessionId = nil
		end
		UI:closeWnd(self)
	end)
	self:subscribe(self.noticeSure, UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
	end)
	--翻页
	self.pageIndex = 1
	self:subscribe(self:child("trade_frame-Last"), UIEvent.EventButtonClick, function()
		self:updatePage(-1)
	end)
	self:subscribe(self:child("trade_frame-Next"), UIEvent.EventButtonClick, function()
		self:updatePage(1)
	end)
	--关闭交易
    self:subscribe(self:child("BackpackDisplay-Close"), UIEvent.EventButtonClick, function()
		Me:sendPacket({
			pid = "BreakTrade",
			tradeID = self.tradeID,
			breakTrade = true
		})
		UI:closeWnd(self)
	end)
	local sureBtn = self.downConfrimBtn --自己确认/取消
	self:subscribe(sureBtn, UIEvent.EventButtonClick, function()
		local isConfirm = self.isConfirm
		local img1 = isConfirm and "set:trade.json image:greenBtn.png" or "set:trade.json image:redBtn.png"
		local img2 = isConfirm and "set:trade.json image:noSureBg.png" or "set:trade.json image:sureBG.png"
		sureBtn:SetNormalImage(img1)
		sureBtn:SetPushedImage(img1)
		self.downBg:SetBackImage(img2)
		self.isConfirm = (isConfirm == false) and true
		Me:sendPacket({
			pid = "ConfirmTrade",
			tradeID = self.tradeID,
			isConfirm = self.isConfirm
		})
		self:startCountDown(self.isConfirm and self.otherConfirm)
		self:setSelectedView(self.selectCells, self.isConfirm)
		self.downName:SetProperty("TextBorderColor", self.isConfirm and sureBorder or notSureBorder)
		sureBtn:SetProperty("TextBorderColor", self.isConfirm and getBorderColor(195, 0, 0, 0) or getBorderColor(11, 61, 13))
	end)
	--对方确认/取消
	Lib.subscribeEvent(Event.EVENT_TRADE_CONFIRM, function(isConfirm)
		if UI:isOpen(self) then
			self.otherConfirm = isConfirm
			self.topOkImg:SetVisible(isConfirm)
			self.topConfrimText:SetVisible(isConfirm)
			self.topBg:SetBackImage(isConfirm and "set:trade.json image:sureBG.png" or "set:trade.json image:noSureBg.png")
			self:startCountDown(self.isConfirm and self.otherConfirm)
			self:setSelectedView(self.topCells, self.otherConfirm)
			self.topName:SetProperty("TextBorderColor", isConfirm and sureBorder or notSureBorder)
		end
	end)
	--对方选择改变
	Lib.subscribeEvent(Event.EVENT_TRADE_ITEM_CHANGE, function(tradeID, operation, data)
		if not UI:isOpen(self) then
			return
		end
		if operation == "add" then
			self.otherItems[#self.otherItems + 1] =  {
				tid = data.tid,
				slot = data.slot,
				item = data.itemData and Item.DeseriItem(data.itemData)
			}
		else
			for key, data_s in pairs(self.otherItems) do
				if data.tid == data_s.tid and data.slot == data_s.slot then
					self.otherItems[key] = nil
				end
			end
		end
		self:refreshPlayerItem(self.otherItems or {}, self.topCells)
	end)
end

function M:onOpen()

end

function M:openTrade(tradeID, userID, itemDatas)
	self.isConfirm = false
	self.otherConfirm = false
	self.tradeID = tradeID
	self.userID = userID
	self.tradeItems = {}
	self.selectItems = {}
	self.otherItems = {}
	self.pageIndex = 1
	
	self:initTradeData(itemDatas)
	self:resetStyle()
	self:resetCellList()
	self:updatePage(0)
end

function M:initTradeData(itemDatas)
	local items = {}
	for _, data in pairs(itemDatas or {}) do
		local index = #items + 1
		local item = data.seriData and Item.DeseriItem(data.seriData)
		items[index] = {
			tid = data.tid,
			slot = data.slot,
			item = item,
			selected = false
		}
	end
	table.sort(items, function(data1, data2)
		local item1, item2 = data1.item, data2.item
        local gist_1, gist_2 = item1:cfg()[SortGist], item2:cfg()[SortGist]
        if gist_1 and gist_2 then
            return gist_1 > gist_2
        end
        return false
    end)
	self.tradeItems = items
	self.maxPage = math.ceil(#items / PageCellNum)
end

function M:resetStyle()
	self.tradeContent:SetVisible(true)
	self.noticeContent:SetVisible(false)
	self.countDown:SetVisible(false)
	local downConfrimBtn = self.downConfrimBtn
	downConfrimBtn:SetVisible(true)
	downConfrimBtn:SetNormalImage("set:trade.json image:greenBtn.png")
	downConfrimBtn:SetPushedImage("set:trade.json image:greenBtn.png")
	self.topConfrimText:SetVisible(false)
	self.downConfrimText:SetVisible(false)
	self.topOkImg:SetVisible(false)
	self.downOkImg:SetVisible(false)
	self.downBg:SetBackImage("set:trade.json image:noSureBg.png")
	self.topBg:SetBackImage("set:trade.json image:noSureBg.png")
	self.topName:SetProperty("TextBorderColor", notSureBorder)
	self.downName:SetProperty("TextBorderColor", notSureBorder)

	local mapid = {Me.platformUserId, self.userID}
	UserInfoCache.LoadCacheByUserIds(mapid, function()
		if UI:isOpen(self) then
			local cache = UserInfoCache.GetCache(self.userID)
			self.topName:SetText(cache and cache.nickName or "")
			cache = UserInfoCache.GetCache(Me.platformUserId)
			self.downName:SetText(cache and cache.nickName or "")
		end
	end)	
end

function M:resetCellList()
	self.clickCell = {}
	self.tradeCells = {}
	self.topCells = {}
	self.selectCells = {}
	self.downGridView:invoke("CLEAN")
    self.topGridView:invoke("CLEAN")
    self.tradeGridView:invoke("CLEAN")
	self.selectedCount = 0
	for idx = 1, MaxSelected do
		--对方交易的item
        local cell = UIMgr:new_widget("cell")
		self.topCells[#self.topCells + 1] = cell
		cell:invoke("FRAME_SIZE", {}, self.cellwidth1 , self.cellHeight1)
		self.topGridView:invoke("ITEM", cell)
		self:refreshItem(nil, cell)
    end

	for idx = 1, MaxSelected do
		--已经选择的item
		local cell = UIMgr:new_widget("cell")
		self:setSelectedCell(cell)
	end
end

function M:setSelectedCell(cell)
	self.selectCells[#self.selectCells + 1] = cell
	cell:invoke("FRAME_SIZE", {}, self.cellwidth1 , self.cellHeight1)
	self.downGridView:invoke("ITEM", cell)
	self:refreshItem(nil, cell)

	self:subscribe(cell, UIEvent.EventWindowClick, function()
		self:resetCell(cell, ClickType.left)
		local index = cell:data("index")
		local data = index and self.tradeItems[index]
		if not data or not (data and data.selected) or self.isConfirm then
			return
		end

		local subItem = function(ok)
			if UI:isOpen(self) then
				if not ok then
					Client.ShowTip(Tipdata.showTypeTop, "trading.can.not.dele", Tipdata.showTime)
					return
				end
				self.selectedCount = self.selectedCount - 1
				cell:setData("index", nil)
				self:refreshItem(nil, cell)
				data.selected = false
				self:subSelected(index)
			end
		end
		Me:sendPacket({
			pid = "ChangTradeItem",
			tradeID = self.tradeID,
			tid = data.tid,
			slot = data.slot,
			add = false
		}, subItem)
	end)
end

function M:updatePage(add)
	local val = self.pageIndex + add
	if val < 1 or val > (self.maxPage or MaxPageNum) then
		return
	end
	self.pageIndex = val
	self:resetCell(nil, ClickType.right)
	self:child("trade_frame-Page"):SetText(self.pageIndex .. "/" .. (self.maxPage or MaxPageNum))
	self.tradeGridView:invoke("CLEAN")
	self.tradeCells = {}
	local st = (self.pageIndex - 1) * PageCellNum + 1
	local nd = self.pageIndex * PageCellNum
	for index = st, nd do
		local cell = UIMgr:new_widget("cell")
		self:setTradeCell(cell, index)
	end
end

function M:setTradeCell(cell, index)
	local data = self.tradeItems[index]
	cell:invoke("FRAME_SIZE", {}, self.cellwidth2 , self.cellHeight2)
	cell:setData("index", index)
	self.tradeGridView:invoke("ITEM", cell)
	self.tradeCells[#self.tradeCells + 1] = cell
	self:subscribe(cell, UIEvent.EventWindowClick, function()
		self:resetCell(cell, ClickType.right)
		if self.selectedCount >= MaxSelected or not data or data.selected or self.isConfirm then
			return
		end
		local addItem = function(ok)
			if UI:isOpen(self) then
				if not ok then
				Client.ShowTip(Tipdata.showTypeTop, "trade.more.cap", Tipdata.showTime)
				return
				end
				self.selectedCount = self.selectedCount + 1
				self:refreshItem(nil, cell)
				self:addSelected(index)
			end
		end
		Me:sendPacket({
			pid = "ChangTradeItem",
			tradeID = self.tradeID,
			tid = data.tid,
			slot = data.slot,
			add = true
		}, addItem)
	end)
	if data and not data.selected then
		self:refreshItem(data.item, cell)
	else
		self:refreshItem(nil, cell)
	end
end

function M:addSelected(index)
	local data = self.tradeItems[index]
	if not data or (data and data.selected)then
		return
	end
	for idx = 1, MaxSelected do
		local cell = self.selectCells[idx]
		if cell and not cell:data("index") then
			cell:setData("index", index)
			data.selected = true
			self:refreshItem(data.item, cell)
			return
		end
	end
end

function M:subSelected(index)
	local data = self.tradeItems[index]
	if not data or (data and data.selected)then
		return
	end
	local st = (self.pageIndex - 1) * PageCellNum
	local nd = self.pageIndex * PageCellNum
	if st < index and index <= nd then
		local tradeCells = self.tradeCells and self.tradeCells[index - st]
		if tradeCells and tradeCells:data("index") == index then
			self:refreshItem(data.item, tradeCells)
		end
	end
end

function M:refreshPlayerItem(items, cells)
	local idx = 1
	for _,data in pairs(items) do
		cells[idx]:setData("itemIndex", idx)
		self:refreshItem(data.item, cells[idx])
		idx = idx + 1
	end
	for i = idx, #cells do
		cells[idx]:setData("itemIndex", nil)
		self:refreshItem(nil, cells[i])
	end
end

function M:refreshItem(item, template)
    template:setData("item", item)
    local qualityCfg = TradeCfg.trayQualityFrame
    template:invoke("RESET")
    if qualityCfg then
        template:invoke("SELECT_TYPE", item, qualityCfg.selectType)
        template:invoke("FRAME_IMAGE", item, qualityCfg.defaultIcon, qualityCfg.frameStretch)
        template:invoke("FRAME_SELECT_IMAGE", item, qualityCfg.selectFrameIcon, qualityCfg.selectStretch)
    end
	if not item or item:null() then
        return
    end
	local cfg = item:cfg()
    local quality = cfg.quality
    local qualityDiff = qualityCfg.qualityFrameDiff
    if quality and qualityDiff and qualityDiff[quality] then
        template:invoke("FRAME_IMAGE", item, qualityDiff[quality].icon, qualityDiff[quality].stretch or qualityCfg.frameStretch)
    end
    template:invoke("ITEM_SLOTER", item)
    template:invoke("SHOW_EFFECT", item)
    -- 如果item配置里有showActor的字段 就显示actor
    if cfg.showActor then
        template:invoke("ACTOR_ITEM", item, cfg.showActor)
    end
    if cfg.signIcon then
        local icon = ResLoader:loadImage(cfg, cfg.signIcon)
        template:invoke("ITEM_SIGN", item, icon)
    end
end

function M:resetCell(cell, type)
    local curCell = self.clickCell[type]
	self.clickCell[type] = nil
    if curCell and curCell ~= cell then
        curCell:receiver():onClick(false)
    end
    if cell then
        cell:receiver():onClick(true)
        self.clickCell[type] = cell
    end
end

function M:setSelectedView(cells, sure)
	local qualityCfg = TradeCfg.trayQualityFrame
	for _,template in pairs(cells or {}) do
		if not template:data("item") then
			template:invoke("FRAME_IMAGE", nil, sure and SureItemBg or qualityCfg.defaultIcon, qualityCfg.frameStretch)
		end
	end
end

function M:startCountDown(start)
	if not start then
		self.countDown:SetVisible(false)
		return
	end
	self.countDown:SetVisible(true)
	local timer = self.timer
	if timer then
		timer()
		self.timer = nil
	end
	local time = CountDownTime
	local str = getShowImage(time)
	self.singByte:SetImage(str)
	local tick = function()
		time = time - 1
		local open = UI:isOpen(self)
		if time >= 0 and open then
			str = getShowImage(time)
			self.singByte:SetImage(str)
		end
		if time < 0 and open then
			self.timer = nil
		end
		return time > 0
	end
	self.timer = World.Timer(20, tick)
end

function M:showRequest(name, sessionId)
	self.sessionId = sessionId
	local msg = {"gui_request_trade", name}
	self:showMsg(msg, "Choice")
end

function M:showMsg(msg, type)
	self.countDown:SetVisible(false)
	self.tradeContent:SetVisible(false)
	self.noticeContent:SetVisible(true)
	self.noticeDetail:SetText(Lang:toText(msg))
	self.noticeSure:SetVisible(type == "Sure")
	self.noticeYes:SetVisible(type == "Choice")
	self.noticeNo:SetVisible(type == "Choice")
end

function M:onClose()
	self.sessionId = nil
end

return M