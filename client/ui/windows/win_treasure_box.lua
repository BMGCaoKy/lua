--author:LIHAI
local curTrays = {}
local currBox = 1
local lottery = {}
local stopCdTimer = nil
local canClose = false

function M:init()
	WinBase.init(self, "TreasureBox.json")
	self.closeBtn = self:child("TreasureBox-close")
	self.atricleList = self:child("TreasureBox-items_gridview")
	self.leftBtn = self:child("TreasureBox-left")
	self.rightBtn = self:child("TreasureBox-right")
	self.openBtn = self:child("TreasureBox-open")
	self.resreshPond = self:child("TreasureBox-change")
	self.treasureBoxNum = self:child("TreasureBox-num")
	self.treasureBoxActor = self:child("TreasureBox-actor")
	self.showEffect = self:child("TreasureBox-showEffect")
	self.resreshOpendCd = self:child("TreasureBox-refrsh")
	self.refershConinIcon = self:child("TreasureBox-consumeIcon")
	self.refershConinNum = self:child("TreasureBox-refersh_num")
	self.countdown = self:child("TreasureBox-countdown")
	self.tittle = self:child("TreasureBox-tittleTextKey")
	self.introduce = self:child("TreasureBox-introduce")
	self.cost_icon = self:child("TreasureBox-cost-icon")
	self.cost_num = self:child("TreasureBox-cost-num")
	self.open_mask = self:child("TreasureBox-open_mask")
	self.resreshPondText = self:child("TreasureBox-changeTextKey")
	self.resreshOPenCdText = self:child("TreasureBox-refershName")
	self.openTreasureBoxText = self:child("TreasureBox-open-text")

	self.rewardPanel = self:child("TreasureBox-Reward")
	self.rewardList = self:child("TreasureBox-show-reward")
	self.closeRewardBtn = self:child("TreasureBox-sure-btn")

	self:subscribe(self.closeBtn, UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
	end)

	self:subscribe(self.closeRewardBtn, UIEvent.EventButtonClick, function()
		self.open_mask:SetVisible(false)
		self.rewardPanel:SetVisible(false)
		if canClose then
			UI:closeWnd(self)
			canClose = false
		end
	end)
end

function M:initTreasureBox(treasurebox)
	local curr = Me:data("treasurebox")[treasurebox.boxName]
	if not curr then
		canClose = true
		local rewardTb = treasurebox.showRewardTb
		if rewardTb and next(rewardTb)then
			self:showTreasureBoxReward(rewardTb, "treasurebox.rewardbtn.key")--传参处理不是很好后面会优化
		end
		return
	end
	local currPond = curr.pond
	local currOpencd = curr.openCD - os.time()
	local showRewardTb = treasurebox.showRewardTb
	lottery = curr.lottery

	--获取所有宝箱并排序
	self:treasureBoxSort()
	self:showTreasureBox(treasurebox.boxName)
	--奖池道具展示
	self.atricleList:RemoveAllItems()
	self.atricleList:InitConfig(21, 15, #currPond)
	self.atricleList:SetAutoColumnCount(false)
	for i,v in pairs(currPond)do
		local item = Item.CreateItem(v.data.name, 1)
		local cell = UIMgr:new_widget("cell")
		cell:setData("item", item)
		self:treasureBoxItemShow(cell, v.data.weight.."%")
		self.atricleList:AddItem(cell, true)
	end
	--宝箱标题
	self.tittle:SetText(Lang:toText(lottery.tittleKey or ""))
	--宝箱介绍
	self.introduce:SetText(Lang:toText(lottery.introduce or ""))
	--刷新奖池需消耗得 货币/魔方 icon 及数量
	self.cost_icon:SetImage(Coin:iconByCoinName(lottery.resreshPondCoinName or ""))
	self.cost_num:SetText(lottery.resreshPondCoinNum or "")
	self.resreshPondText:SetText(Lang:toText(lottery.resreshPondTextKey))
	--刷新开宝箱CD消耗品icon 及数量
	self.refershConinIcon:SetImage(Coin:iconByCoinName(lottery.resreshOpenCdCoinName) or "")
	self.refershConinNum:SetText(lottery.resreshOpenCdCoinNum or "")
	self.resreshOPenCdText:SetText(Lang:toText(lottery.resreshOpenCdTextKey))
	--宝箱模型及方向 大小（静止状态）
	self.treasureBoxActor:SetActor1(lottery.lotteryActor or "", "idle")
	self.treasureBoxActor:SetActorScale(0.4)
	--开宝箱
	self.openTreasureBoxText:SetText(Lang:toText(lottery.openTreasureBoxTextKey))
	self:unsubscribe(self.openBtn)
	self:subscribe(self.openBtn, UIEvent.EventButtonClick, function()
		self.open_mask:SetVisible(true)
		self:openCourse(lottery, currOpencd)
    end)
	--刷新当前宝箱奖池
	self:unsubscribe(self.resreshPond)
	self:subscribe(self.resreshPond, UIEvent.EventButtonClick, function()
		self:treasureBoxResresh(1)
	end)
	--刷新开宝箱CD
	self:unsubscribe(self.resreshOpendCd)
	self:subscribe(self.resreshOpendCd, UIEvent.EventButtonClick, function()
		self:treasureBoxResresh(2)
	end)
	if curr.isOpen and currOpencd > 0 then
		self.resreshPond:SetVisible(false)
		self.openBtn:SetVisible(false)
		self.resreshOpendCd:SetVisible(true)
		if stopCdTimer then
			stopCdTimer()
		end
		self:updateCountDown(currOpencd)
	else
		self.resreshPond:SetVisible(true)
		self.openBtn:SetVisible(true)
		self.resreshOpendCd:SetVisible(false)
	end

	if showRewardTb and next(showRewardTb) then
		self:showTreasureBoxReward(showRewardTb, lottery.rewardBtnTextKey)
	end
end

function M:showTreasureBoxReward(showRewardTb, textKey)
	self.rewardPanel:SetVisible(true)
	self.closeRewardBtn:GetChildByIndex(0):SetText(Lang:toText(textKey))
	self.rewardList:RemoveAllItems()
	self.rewardList:InitConfig(18, 15, #showRewardTb)
	self.rewardList:SetAutoColumnCount(false)
	for i, v in pairs(showRewardTb)do
		local item = Item.CreateItem(v.data.name, 1)
		local cell = UIMgr:new_widget("cell")
		cell:setData("item", item)
		self:treasureBoxItemShow(cell)
		self.rewardList:AddItem(cell, true)
	end
end

function M:treasureBoxItemShow(itemCell, weight)
    local item = itemCell:data("item")
	local cfg = item:cfg()
	itemCell:invoke("FRAME_SIZE", item, 100, 100)
	itemCell:invoke("SET_BASE_ICON", item:icon())
	local qualityCfg = World.cfg.trayQualityFrame
	local qualityDiff = qualityCfg.qualityFrameDiff
	itemCell:invoke("FRAME_IMAGE", item, qualityDiff[cfg.quality].icon, qualityDiff[cfg.quality].stretch)
	itemCell:invoke("TOP_TEXT", item, cfg.qualityDesc)
	itemCell:invoke("LD_BOTTOM", item, weight or "")
	itemCell:invoke("SHOW_EFFECT", item)
end

function M:treasureBoxResresh(resreshTyp)
	Me:sendPacket({
		pid = "TreasureBoxResresh",
		resreshTyp = resreshTyp,
		boxName = curTrays[currBox]:full_name()
	})
end

function M:treasureBoxSort()
	curTrays = {}
	currBox = 1
	local trayType = { Define.TRAY_TYPE.HAND_BAG, Define.TRAY_TYPE.BAG, Define.TRAY_TYPE.EXTRA_BAG, }
	local trayArray = Me:tray():query_trays(trayType)
	for _, treasure in pairs(trayArray) do
        local tray = treasure.tray
        local items = tray and tray:query_items(function(item)
            if item:cfg()["lottery"] then
                return true
            end
            return false
        end)
		for _, item in pairs(items) do
            table.insert(curTrays, item)
        end
    end
	table.sort(curTrays, function(item1, item2)
	    local type1 = Me:tray():fetch_tray(item1:tid()):type()
	    local type2 = Me:tray():fetch_tray(item2:tid()):type()
	    if type1 ~= type2 then
	        if Define.TRAY_TYPE_CLASS[type1] ~= Define.TRAY_TYPE_CLASS[type2] then
	            return Define.TRAY_TYPE_CLASS[type1] == Define.TRAY_CLASS_EQUIP and Define.TRAY_TYPE_CLASS[type2] ~= Define.TRAY_CLASS_EQUIP
	        end
	    end
	    local gist_1, gist_2 = item1:cfg()["quality"], item2:cfg()["quality"]
	    if gist_1 and gist_2 then
	        return gist_1 > gist_2
	    end
	    return false
	end)
end

function M:showTreasureBox(boxName)
	for i,v in pairs(curTrays) do
		if v:full_name() == boxName then
			local count = Me:tray():find_item_count(boxName)
			self.treasureBoxNum:SetText(count)
			currBox = i
		end
	end
	self:unsubscribe(self.rightBtn)
	self:subscribe(self.rightBtn, UIEvent.EventButtonClick, function()
		if #curTrays==1 then
			return
		end
		currBox = currBox + 1
		if not curTrays[currBox] then
			currBox = 1
		end
		Me:sendPacket({
			pid = "ShowTreasureBox",
			boxName = curTrays[currBox]:full_name()
		})
	end)
	self:unsubscribe(self.leftBtn)
	self:subscribe(self.leftBtn, UIEvent.EventButtonClick, function()
		if #curTrays==1 then
			return
		end
		currBox = currBox - 1
		if not curTrays[currBox] then
			currBox = #curTrays
		end
		Me:sendPacket({
			pid = "ShowTreasureBox",
			boxName = curTrays[currBox]:full_name()
		})
	end)
end

function M:openCourse(showData, currOpencd)
	local countDown = showData.openTime
	self.treasureBoxActor:SetActor1(showData.lotteryActor or "", showData.openAction or "idle")
	Me:playSound(showData.openSound)
	local function tick()
		countDown = countDown - 1
		if countDown <= 0 then
			self.treasureBoxActor:SetActor1(showData.lotteryActor or "", "idle")
			Me:sendPacket({
				pid = "OpenTreasureBox",
				boxName = curTrays[currBox]:full_name()
			})
			return false
		end
		return true
	end
	World.Timer(20, tick)
end

function M:updateCountDown(openCD)
	Lib.subscribeEvent(Event.REFRESG_OPEN_CD, function()
		stopCdTimer()
		self.resreshPond:SetVisible(true)
		self.openBtn:SetVisible(true)
		self.resreshOpendCd:SetVisible(false)
	end)
	local hour, minitue, second = Lib.timeFormatting(openCD)
	local countDown = openCD
	self.countdown:SetText(hour.." : "..minitue.." : "..second.."  "..Lang:toText("gui.text.free" or ""))
	local function tick()
		countDown = countDown - 1
		local c_h, c_m, c_s = Lib.timeFormatting(countDown)
		self.countdown:SetText(c_h.." : "..c_m.." : "..c_s.."  "..Lang:toText("gui.text.free" or ""))
		if countDown <= 0 then
			self.resreshPond:SetVisible(true)
			self.openBtn:SetVisible(true)
			self.resreshOpendCd:SetVisible(false)
			return false
		end
		return true
	end
	stopCdTimer = World.Timer(20, tick)
end

return M
