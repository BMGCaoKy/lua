local toThousandthString = Lib.toThousandthString
local maxScoreBit = 10000000

local cachekey = "world"
local isOpen = false

require "common.cache.user_info_cache"

function M:init()
	WinBase.init(self, "WorldRank.json")

	self.RankList = self:child("WorldRank-List")
	self.MyRank = self:child("WorldRank-context-me")
	self.RankList:SetMoveAble(false)
	self.queue = {}
	self.cachekey = "world"

	Lib.subscribeEvent(Event.EVENT_RECEIVE_RANK_DATA, function(rankType)
		if rankType == self.showRankType then
			self:refresh()
		end
	end)
	Lib.subscribeEvent(Event.EVENT_USER_INFO_CACHE_ACCOMPLISH, function(key)
		if isOpen and key == self.cachekey then
			local rankType = self.showRankType
			local rankData = Rank.GetRankData(rankType)
			self:refreshRankList(self.RankList, rankData[1])
			self:refreshMyRank(Rank.GetMyRanks(rankType), Rank.GetMyScores(rankType))
		end
    end)
end

function M:onOpen(rankType)
	isOpen = true
	WinBase.onOpen(self)
	Rank.RequestRankData(rankType)
	if rankType == self.showRankType then
		return
	end
	self.showRankType = rankType
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
	self:child("WorldRank-Title-Name"):SetText(Lang:toText("world.rank.title"))
	self:child("WorldRank-rank"):SetText(Lang:toText("world.rank.rank"))
	self:child("WorldRank-Title-name"):SetText(Lang:toText("world.rank.name"))
	self:child("WorldRank-Title-number"):SetText(Lang:toText("world.rank.number"))
	self:child("WorldRank-Score"):SetText(Lang:toText("world.rank.score"))
end

function M:refresh()
	local rankType = self.showRankType
	local rankData = Rank.GetRankData(rankType)
	local MyRankData = Rank.newMyScores[self.rankName] or {}
	local typeData = rankData[1] or {}
	self.queue = {}
	local userId = CGame.instance:getPlatformUserId() or 0
	self.queue[userId] = true
	for i = 1, #typeData do
		local data = typeData[i]
		self.queue[data.userId or 0] = true
	end
	local mapid = {}
	for id,_ in pairs(self.queue) do
		mapid[#mapid + 1] = id
	end
	UserInfoCache.LoadCacheByUserIds(mapid, function()
		Lib.emitEvent(Event.EVENT_USER_INFO_CACHE_ACCOMPLISH, cachekey)
	end)
end

function M:refreshMyRank(myRank, myScore)
	local numberColor = { 108.0/255, 152.0/255, 183.0/255}
	--排名
	local rankWdg = self:child("WorldRank-Me-rank")
	rankWdg:SetTextColor(numberColor)
	local rankTh = myRank[1]
	if not rankTh or rankTh > 1000 or rankTh <= 0 then
		rankTh = "1000+"
	elseif rankTh > 100 then
		rankTh = "100+"
	end
	local star = math.floor((myScore[1] or 0) / maxScoreBit)
	local score = math.fmod(myScore[1] or 0, maxScoreBit)
	rankWdg:SetText(rankTh)
	--星星
	local starWdg = self:child("WorldRank-number")
	starWdg:SetTextColor(numberColor)
	starWdg:SetText(star or 0)
	--积分
	local scoreWdg = self:child("WorldRank-score")
	scoreWdg:SetTextColor(numberColor)
	scoreWdg:SetText(score or 0)
	--姓名头像
	local nameWdg = self:child("WorldRank-Me-name")
	nameWdg:SetTextColor(numberColor)
	nameWdg:SetText("")
	local headImg = self:child("WorldRank-Me-headImg")
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
		rankItem:SetArea({ 0, 10 }, { 0, 0 }, { 1, 0 }, { 0, 50 })
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
	rankItem:setData("userId", data.userId)

	local BgImages = {"Bg-two.png"}    
	rankItem:child("RankItem-bg"):SetImage("set:worldrank.json image:"..(BgImages[rank] or "Bg_one.png"))

	local nameColor = { 180.0/255, 64.0/255, 64.0/255} 

	local nameWdg = rankItem:child("RankItem-name")
	nameWdg:SetTextColor(nameColor)
	nameWdg:SetText(data.name)

	local star = math.floor((data.score or 0 )/ maxScoreBit) --2147483647 16777216
	local score = math.fmod((data.score  or 0 ), maxScoreBit)

	local numberColor = { 180.0/255, 104.0/255, 15.0/255}  
	local scoreWdg = rankItem:child("RankItem-score")
	scoreWdg:SetVisible(true)
	scoreWdg:SetTextColor(numberColor)
	scoreWdg:SetText(score or 0)

	local starWdg = rankItem:child("RankItem-number")
	starWdg:SetTextColor(numberColor)
	starWdg:SetText(star or 0)
	rankItem:child("RankItem-star"):SetImage("set:worldrank.json image:star.png")

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
		rankImageWdg:SetImage(self:getNumberImage(rank))
	end

	--头像
	local headImg = rankItem:child("RankItem-headImg")
	self:setHeadImg(headImg, data.userId)
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
	local numStr = {"RankOne.png", "two.png", "there.png"}
	local str = numStr[num] or "zero"
	return "set:worldrank.json image:"..str
end

return M
