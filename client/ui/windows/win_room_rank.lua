
local cachekey = "room"
local isOpen = false


require "common.cache.user_info_cache"

function M:init()
	WinBase.init(self, "roomRank.json")

	self.RankList = self:child("RoomRank-Context-ranks")
	self.MyRank = self:child("RoomRank-context-me")
	self.RankList:SetMoveAble(false)
	self.queue = {}
	self.cachekey = "room"

	Lib.subscribeEvent(Event.EVENT_UPDATA_NEW_RANK, function(rankName)
		if rankName ~=  self.rankName then
			 return
		end
		self:refresh()
	end)

	Lib.subscribeEvent(Event.EVENT_USER_INFO_CACHE_ACCOMPLISH, function(key)
		if isOpen and key == self.cachekey then
			local rankData = Rank.RanksList[self.rankName] or {}
			local MyRankData = Rank.newMyScores[self.rankName] or {}
			self:refreshRankList(self.RankList, rankData)
			self:refreshMyRank(MyRankData)
		end
    end)

end

function M:onOpen(rankName)
	isOpen = true
	WinBase.onOpen(self)
	self.rankName = rankName
	self:refresh()
	self:refreshTextLang()
end

function M:onClose()
	isOpen = false
end

function M:show()
	WinBase.show(self)
end

function M:refreshTextLang()
	local config = {}
	self:child("RoomRank-Title-Name"):SetText(Lang:toText("room.rank.Title"))
	self:child("RoomRank-Title-rank"):SetText(Lang:toText("room.rank.rank"))
	self:child("RoomRank-Title-name"):SetText(Lang:toText("room.rank.name"))
	self:child("RoomRank-Title-number"):SetText(Lang:toText("room.rank.number"))
	self:child("RoomRank-Title-score"):SetText(Lang:toText("room.rank.score"))
end

function M:refresh()
	local rankData = Rank.RanksList[self.rankName] or {}
	local MyRankData = Rank.newMyScores[self.rankName] or {}
	self.queue = {}
	local userId = CGame.instance:getPlatformUserId() or 0
	self.queue[userId] = true
	for i = 1, #rankData do
		local data = rankData[i]
		self.queue[data.id or 0] = true
	end
	local mapid = {}
	for id,_ in pairs(self.queue) do
		mapid[#mapid + 1] = id
	end
	UserInfoCache.LoadCacheByUserIds(mapid, function()
		Lib.emitEvent(Event.EVENT_USER_INFO_CACHE_ACCOMPLISH, cachekey)
	end)
end

function M:refreshMyRank(rankData)
	local numberColor = { 108.0/255, 152.0/255, 183.0/255}
	local data = rankData.myscores or {}

	local nameWdg = self:child("RoomRank-Me-name")
	nameWdg:SetTextColor(numberColor)

	local myrank = self:child("RoomRank-Me-rank")
	myrank:SetTextColor(numberColor)
	myrank:SetText(rankData.myrank or "10+")

	local mystar = self:child("RoomRank-number")
	mystar:SetTextColor(numberColor)
	mystar:SetText(data.star or 0)

	local myscore = self:child("RoomRank-score")
	myscore:SetTextColor(numberColor)
	myscore:SetText(data.score or 0)

	local headImg = self:child("RoomRank-Me-headImg")
	self:setHeadImg(headImg, CGame.instance:getPlatformUserId(), nameWdg)
end

function M:refreshRankList(rankList, rankData)
	if not rankList or not rankData then
		return
	end
	rankList:ClearAllItem()
	rankList:SetProperty("BetweenDistance", 3)
	for i = 1, #rankData do
		local rankItem = GUIWindowManager.instance:LoadWindowFromJSON("RankItem.json")
		rankItem:SetArea({ 0, 10 }, { 0, 0 }, { 1, 0 }, { 0, 38 })
		self:updateRankItem(rankItem, rankData[i])
		rankList:AddItem(rankItem)
	end
	rankList:SetTouchable(true)
	rankList:LayoutChild()
end

function M:updateRankItem(rankItem, data)
	if not data then
		return
	end
	local rank = data.rank
	rankItem:setData("userId", data.id)

	local itemBg = rankItem:child("RankItem-bg")
	local BgImages = {"scorebgo.png"}    
	itemBg:SetImage("set:room_rank.json image:"..(BgImages[rank] or "scorebg.png"))
	itemBg:SetProperty("StretchOffset", "170 30 0 0")

	local nameColor = { 132.0/255, 143.0/255, 143.0/255}

	local nameWdg = rankItem:child("RankItem-name")
	nameWdg:SetTextColor(nameColor)
	nameWdg:SetText(data.name or "")

	local Score = data.score

	local numberColor = { 108.0/255, 152.0/255, 183.0/255}
	local scoreWdg = rankItem:child("RankItem-score")
	scoreWdg:SetVisible(true)
	scoreWdg:SetTextColor(numberColor)
	scoreWdg:SetText(Score.score or 0)

	local starWdg = rankItem:child("RankItem-number")
	starWdg:SetTextColor(numberColor)
	starWdg:SetText(Score.star or 0)
	rankItem:child("RankItem-star"):SetImage("set:roomrankitem.json image:star.png")

	local numRankWdg = rankItem:child("RankItem-ranknum")
	local rankImageWdg = rankItem:child("RankItem-rankImg")
	if (rank > 3) then
		numRankWdg:SetVisible(true)
		rankImageWdg:SetVisible(false)
		numRankWdg:SetTextColor(numberColor)
		numRankWdg:SetText(rank)
	else
		numRankWdg:SetVisible(false)
		rankImageWdg:SetVisible(true)
		rankImageWdg:SetArea({0.052,0},{0,0},{0.052,0},{1,0})
		rankImageWdg:SetImage(self:getNumberImage(rank))
	end

	local headImg = rankItem:child("RankItem-headImg")
	self:setHeadImg(headImg, data.id)
end

function M:setHeadImg(headImg, userId, nameWdg)
	 if not userId then
		return
	 end
	 local cache = UserInfoCache.GetCache(userId)
	 if not cache then
		return
	 end
	 if cache.picUrl and #cache.picUrl > 0 then
		 headImg:SetImageUrl(cache.picUrl)
	 else
		 headImg:SetImage("set:default_icon.json image:header_icon")
	 end
	 if nameWdg and cache.nickName then
		nameWdg:SetText(cache.nickName)
	 end
end

function M:getNumberImage(num)
	local numStr = {"one.png", "two.png", "three.png"}
	local str = numStr[num] or "zero"
	return "set:challenge_cup.json image:"..str
end

return M
