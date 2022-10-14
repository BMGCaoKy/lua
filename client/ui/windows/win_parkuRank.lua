-- 功能是完整的，但暂时没用的面板
local toThousandthString = Lib.toThousandthString
local isDirty = true
local rankDirtyCall = L("rankDirtyCall")

function M:init()
	WinBase.init(self, "ParkuRank.json",true) 
	self.showRankType = nil

	self.closeButton = self:child("ParkuRank-close")
	self:subscribe(self.closeButton, UIEvent.EventButtonClick, function()
		Lib.emitEvent(Event.EVENT_SHOW_RANK, false, "parkuRank")
	end)

	self.playerList = self:child("ParkuRank-allInfo")
	self.mRank = self:child("ParkuRank-text-myRank")
	self.mScore = self:child("ParkuRank-text-myScore")

	Lib.subscribeEvent(Event.EVENT_RECEIVE_RANK_DATA, function(rankType)
		if rankType == self.showRankType then
			isDirty = true
			self:refresh()
		end
	end)

	self:buildBaseTextLang()
end

function M:buildBaseTextLang()
	self.mRank:SetText(Lang:toText("parku.rank.notranked"))
	self:child("ParkuRank-text-myRankText"):SetText(Lang:toText("parku.rank.myrank"))
	self:child("ParkuRank-text1"):SetText(Lang:toText("parku.rank.rank"))
	self:child("ParkuRank-text2"):SetText(Lang:toText("parku.rank.name"))
	self:child("ParkuRank-text3"):SetText(Lang:toText("parku.rank.score"))
	self:child("ParkuRank-title-text"):SetText(Lang:toText("parku.rank.title"))
	self:child("ParkuRank-title-text2"):SetText(Lang:toText("parku.rank.total"))
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
	if isDirty then 
		local rankType = self.showRankType
		local rankData = Rank.GetRankData(rankType)
		self:refreshRankList(self.playerList, rankData[1])
		self:refreshMyInfo(Rank.GetMyRanks(rankType), Rank.GetMyScores(rankType))
		isDirty = false
	end
end

function M:refreshMyInfo(myRanks, myScores)
	self.mRank:SetText(self:getMyRankText(myRanks[1] or 0))
	self.mScore:SetText(myScores[1] or 0)
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
	-- rankList:SetItemHeight(80)
	for i = 1, #rankData do
		local rankItem = GUIWindowManager.instance:LoadWindowFromJSON("ParkuRankItem.json")
		self:updateRankItem(rankItem, rankData[i])
		rankList:AddItem(rankItem, true)
	end
	rankList:SetAllowScroll(true)
	rankList:SetTouchable(true)
end

function M:updateRankItem(rankItem, data)
	local rank = data.rank
	rankItem:setData("userId", data.userId)

	if rank <= 3 then 
		local rankImg = rankItem:child("ParkuRankItem-rankImg")
		rankImg:SetImage("set:new_rank.json image:rank_"..rank..".png")
		rankImg:SetVisible(true)
	else
		local rankTxt =	rankItem:child("ParkuRankItem-rank")
		rankTxt:SetText(rank)
		rankTxt:SetVisible(true)
	end
	if rank == 1 then 
		rankItem:child("ParkuRankItem-bg"):SetImage("set:new_rank.json image:bg_my.png")
	end
	rankItem:child("ParkuRankItem-name"):SetText(data.name)
	rankItem:child("ParkuRankItem-score"):SetText(data.score)
end

return M
