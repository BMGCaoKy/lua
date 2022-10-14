local function tmpFun(s) return s end 
local toThousandthString = World.cfg.rankNumNoChange and tmpFun or Lib.toThousandthString
local rankDirtyCall = L("rankDirtyCall")

function M:init()
	WinBase.init(self, "Rank.json")
	self.showRankType = nil

	self.closeButton = self:child("Rank-Title-BtnClose")
	self:subscribe(self.closeButton, UIEvent.EventButtonClick, function()
		Lib.emitEvent(Event.EVENT_SHOW_RANK, false)
	end)

	self.leftRankList = self:child("Rank-LeftContent-List")
	self.leftRankIcon = self:child("Rank-LeftBottom-SelfRankIcon")
	self.leftRankIconTen = self:child("Rank-LeftBottom-SelfRankIconTen")
	self.leftRankText = self:child("Rank-LeftBottom-SelfRankText")
	self.leftScoreText = self:child("Rank-LeftBottom-SelfScore")

	self.rightRankList = self:child("Rank-RightContent-List")
	self.rightRankIcon = self:child("Rank-RightBottom-SelfRankIcon")
	self.rightRankIconTen = self:child("Rank-RightBottom-SelfRankIconTen")
	self.rightRankText = self:child("Rank-RightBottom-SelfRankText")
	self.rightScoreText = self:child("Rank-RightBottom-SelfScore")

	Lib.subscribeEvent(Event.EVENT_RECEIVE_RANK_DATA, function(rankType)
		if rankType == self.showRankType then
			self:refresh()
		end
	end)
end

function M:resetTextLang()
	self:child("Rank-Title-Text"):SetText(Lang:toText("gui_rank_default_title_name"));
	
	self:child("Rank-ViceTitle-Left-Text"):SetText(Lang:toText("gui_rank_vice_title_left_name"));
	self:child("Rank-LeftContent-Title-Rank"):SetText(Lang:toText("gui_rank_title"));
	self:child("Rank-LeftContent-Title-Name"):SetText(Lang:toText("gui_rank_player"));
	self:child("Rank-LeftContent-Title-Score"):SetText(Lang:toText("gui_rank_score"));
	self:child("Rank-LeftBottom-SelfRankName"):SetText(Lang:toText("gui_rank_day_rank"));
	self:child("Rank-LeftBottom-SelfScoreName"):SetText(Lang:toText("gui_rank_self_score"));
		
	self:child("Rank-ViceTitle-Right-Text"):SetText(Lang:toText("gui_rank_vice_title_right_name"));
	self:child("Rank-RightContent-Title-Rank"):SetText(Lang:toText("gui_rank_title"));
	self:child("Rank-RightContent-Title-Name"):SetText(Lang:toText("gui_rank_player"));
	self:child("Rank-RightContent-Title-Score"):SetText(Lang:toText("gui_rank_score"));
	self:child("Rank-RightBottom-SelfRankName"):SetText(Lang:toText("gui_rank_week_rank"));
	self:child("Rank-RightBottom-SelfScoreName"):SetText(Lang:toText("gui_rank_self_score"));
end

function M:refreshTextLang()
	local config
	local gameType, rankType = World.GameName, tostring(self.showRankType)
	local langConfig = Lib.read_csv_file(Root.Instance():getRootPath().."Media/Setting/ranklang.csv") or {}
	for _, cfg in pairs(langConfig) do
		if cfg.GameType == gameType and cfg.RankType == rankType then
			config = cfg
			break
		end
	end
	if not config then
		self:resetTextLang()
		return
	end
	self:resetTextLang()
	self:child("Rank-Title-Text"):SetText(Lang:toText(config.Title));

	self:child("Rank-ViceTitle-Left-Text"):SetText(Lang:toText(config.LeftSubTitle));
	self:child("Rank-LeftContent-Title-Score"):SetText(Lang:toText(config.LeftScore));
	self:child("Rank-LeftBottom-SelfRankName"):SetText(Lang:toText(config.LeftMyRank));
	self:child("Rank-LeftBottom-SelfScoreName"):SetText(Lang:toText(config.LeftMyScore));

	self:child("Rank-ViceTitle-Right-Text"):SetText(Lang:toText(config.RightSubTitle));
	self:child("Rank-RightContent-Title-Score"):SetText(Lang:toText(config.RightScore));
	self:child("Rank-RightBottom-SelfRankName"):SetText(Lang:toText(config.RightMyRank));
	self:child("Rank-RightBottom-SelfScoreName"):SetText(Lang:toText(config.RightMyScore));
end

function M:onOpen(rankType)
	WinBase.onOpen(self)

	rankDirtyCall = Lib.subscribeEvent(Event.EVENT_RANK_DATA_DIRTY, function(rankType)
		if rankType == self.showRankType then
			Rank.RequestRankData(rankType)
		end
	end)

	if Rank.NeedReq(rankType) then 
		Rank.RequestRankData(rankType)
	end
	self.showRankType = rankType
	self:refreshTextLang()
	self.openArgs = table.pack(rankType)
end

function M:onClose()
	if rankDirtyCall then
		rankDirtyCall()
	end
	WinBase.onClose()
end

function M:show()
	WinBase.show(self)
	self:refresh()
end

function M:refresh()
	local rankType = self.showRankType
	local rankData = Rank.GetRankData(rankType)
	self:refreshRankList(self.leftRankList, rankData[1])
	self:refreshRankList(self.rightRankList, rankData[2])
	self:refreshMyInfo(Rank.GetMyRanks(rankType), Rank.GetMyScores(rankType))
end

function M:refreshMyInfo(myRanks, myScores)
	self.leftRankIcon:SetVisible(false)
	self.leftRankIconTen:SetVisible(false)
	self.leftRankText:SetVisible(true)
	self.leftRankText:SetText(self:getMyRankText(myRanks[1] or 0))
	self.leftScoreText:SetText(toThousandthString(myScores[1] or 0))

	self.rightRankIcon:SetVisible(false)
	self.rightRankIconTen:SetVisible(false)
	self.rightRankText:SetVisible(true)
	self.rightRankText:SetText(self:getMyRankText(myRanks[2] or 0))
	self.rightScoreText:SetText(toThousandthString(myScores[2] or 0))
end

function M:getMyRankText(rank)
	if not rank or rank <= 0 or 3000 <= rank then
		return Lang:toText("gui_rank_my_rank_not_rank")
	end
	return toThousandthString(rank)
end

function M:refreshRankList(rankList, rankData)
	if not rankList or not rankData then
		return
	end
	rankList:ClearAllItem()
	rankList:SetItemHeight(80)
	for i = 1, #rankData do
		--local name = string.format("RankItem%d", i)
		local rankItem = GUIWindowManager.instance:LoadWindowFromJSON("SummaryItem.json")
		rankItem:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 0, 66 })
		self:updateRankItem(rankItem, rankData[i])
		rankList:AddItem(rankItem, true)
	end
	rankList:SetAllowScroll(true)
	rankList:SetTouchable(true)
end

function M:updateRankItem(rankItem, data)
	local rank = data.rank
	rankItem:setData("userId", data.userId)

	local BgImages = {"red_icon", "yellow_icon", "blue_icon"}
	rankItem:child("SummaryItem-RankBg"):SetImage("set:new_gui_material.json image:"..(BgImages[rank] or "brown_icon"))

	local TextColors = {
		{212.0 / 255, 86.0 / 255, 86.0 / 255 },		-- D45656
		{237.0 / 255, 208.0 / 255, 84.0 / 255 },	-- EDD054
		{148.0 / 255, 156.0 / 255, 177.0 / 255 },	-- 949CB3
	}
	local textColor = TextColors[rank] or {1, 1, 1}	-- D45656
	local boardColor = {67.0 / 255, 50.0 / 255, 39.0 / 255}

	local nameWdg = rankItem:child("SummaryItem-Name")
	nameWdg:SetTextColor(TextColors[rank] or {1, 1, 1})
	nameWdg:SetTextBoader(boardColor)
	nameWdg:SetText(data.name)
	self:subscribe(nameWdg, UIEvent.EventWindowClick, function()
		-- TODO print("on rank name wdg clicked")
	end)
	
	local scoreWdg = rankItem:child("SummaryItem-Score")
	scoreWdg:SetVisible(true)
	nameWdg:SetTextColor(TextColors[rank] or {1, 1, 1})
	nameWdg:SetTextBoader(boardColor)
	scoreWdg:SetText(toThousandthString(data.score or 0))

	local doubleRankWdg = rankItem:child("SummaryItem-DoubleRank")
	local rankImageWdg = rankItem:child("SummaryItem-Rank")
	if (rank > 9) then
		doubleRankWdg:SetVisible(true)
		rankImageWdg:SetVisible(false)
		doubleRankWdg:getAncestor():child("SummaryItem-DoubleRank-Ten"):SetImage(self:getNumberImage((rank % 100) / 10))
		doubleRankWdg:getAncestor():child("SummaryItem-DoubleRank-One"):SetImage(self:getNumberImage(rank % 10))
	else
		doubleRankWdg:SetVisible(false)
		rankImageWdg:SetVisible(true)
		rankImageWdg:SetImage(self:getNumberImage(rank))
	end
	local vipStr = {"set:summary.json image:VIP", "set:summary.json image:VIPPlus", "set:summary.json image:MVP"}
	rankItem:child("SummaryItem-VipIcon"):SetImage(vipStr[data.vip or 0] or "")

	rankItem:child("SummaryItem-Result"):SetVisible(false)
	rankItem:child("SummaryItem-Max"):SetVisible(false)
	rankItem:child("SummaryItem-Reward"):SetVisible(false)
	rankItem:child("SummaryItem-RewardIcon"):SetVisible(false)	
end

function M:getNumberImage(num)
	local numStr = {"one", "two", "three", "four", "five", "six", "seven", "eight", "nine"}
	local str = numStr[num] or "zero"
	return "set:new_gui_material.json image:number_"..str
end

return M
