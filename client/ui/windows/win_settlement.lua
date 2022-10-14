function M:init()
    WinBase.init(self, "FinalSummary.json", true)

    self.m_finalsummary_exit = self:child("FinalSummary-Exit")
    self.m_finalsummary_Continue = self:child("FinalSummary-Continue")
    self.m_finalsummary_exit:SetText(Lang:toText("gui.exit"))
    self.m_finalsummary_Continue:SetText(Lang:toText("gui.continue"))

    self.m_isNextServer = false
    self:subscribe(self.m_finalsummary_exit, UIEvent.EventButtonClick, function()
        self:exitButton()
    end)
    self:subscribe(self.m_finalsummary_Continue, UIEvent.EventButtonClick, function()
        self:continueButton()
    end)
    self.m_selfResultEntry = nil

    self.m_ranklist = self:child("FinalSummary-AllRank-Content-List")
    self.m_rewardProgress = self:child("FinalSummary-Self-Reward-Slider-Slider")
    self.m_rewardText = self:child("FinalSummary-Self-Reward-Slider-Text")
    --result
    self.m_resultlist = {}

    self.m_finalsummary_title = self:child("FinalSummary-Title")
    self.m_finalsummary_self_rank = self:child("FinalSummary-Self-RankTitle")
    self.m_finalsummary_self_rewrad = self:child("FinalSummary-Self-RewardTitle")

    self.a_finalsummary_rank = self:child("FinalSummary-AllRank-Title-Rank")
    self.a_finalsummary_name = self:child("FinalSummary-AllRank-Title-Name")
    self.a_finalsummary_rewrad = self:child("FinalSummary-AllRank-Title-Reward")

    self.m_finalsummary_title:SetText(Lang:toText("dead.summary.title"))
    self.m_finalsummary_self_rank:SetText(Lang:toText("dead.summary.rank"))
    self.m_finalsummary_self_rewrad:SetText(Lang:toText("dead.summary.reward"))
    self.a_finalsummary_rank:SetText(Lang:toText("final.summary.rank"))
    self.a_finalsummary_name:SetText(Lang:toText("final.summary.player"))
    self.a_finalsummary_rewrad:SetText(Lang:toText("final.summary.reward"))

    self.showAll = nil
end

function M:receiveFinalSummary(result, isNextServer, func)
    self.m_resultlist = {}
    self.showAll = func
    self:getResultEntryList(result)
    self:setIsNextServer(isNextServer)
    self:refreshAllRank()
	self.reloadArg = table.pack(result, isNextServer, func)
end

function M:refreshAllRank()
    self.m_ranklist:ClearAllItem()
    self.m_ranklist:SetItemHeight(66)
    for i, iter in pairs(self.m_resultlist) do
        if iter.isSelf then
            self.m_selfResultEntry = iter
            self:refreshSelf()
        end
        local psummaryitem = GUIWindowManager.instance:CreateWindowFromTemplate("sunmaryitem" .. tostring(i), "SummaryItem.json")
        self:refreshItem(psummaryitem, iter)
        psummaryitem:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 0, 66 })
        self.m_ranklist:AddItem(psummaryitem, true)
    end
    self.m_ranklist:SetAllowScroll(true)
    self.m_ranklist:SetTouchable(true)
end

function M:refreshSelf()
    local bgimage = ""
    local image = ""
    local tenimage = ""
    bgimage, image, tenimage = self:getImageByRank(self.m_selfResultEntry.playerRank)
    local nameText = self:child("FinalSummary-Self-Name")
    nameText:SetText(self.m_selfResultEntry.playerName)
    local rankBgImage = self:child("FinalSummary-Self-RankBg")
    rankBgImage:SetImage(bgimage)
    local rankimage = self:child("FinalSummary-Self-Rank")
    local doubleRank = self:child("FinalSummary-Self-DoubleRank")
    if tonumber(self.m_selfResultEntry.playerRank) > 9 then
        doubleRank:SetVisible(true)
        rankimage:SetVisible(false)
        self:child("FinalSummary-Self-DoubleRank-Ten"):SetImage(tenimage)
        self:child("FinalSummary-Self-DoubleRank-One"):SetImage(image)
    else
        doubleRank:SetVisible(false)
        rankimage:SetVisible(true)
        rankimage:SetImage(image)
    end

    local FinalSummaryWin = "set:summary.json image:BigWinEn"
    local FinalSummaryLose = "set:summary.json image:BigLoseEn"
    local FinalSummaryDraw = "set:summary.json image:BigDogfallEn"

    if World.Lang == "zh_CN" then
        FinalSummaryWin = "set:summary.json image:BigWinCN"
        FinalSummaryLose = "set:summary.json image:BigLoseCN"
        FinalSummaryDraw = "set:summary.json image:BigDogfallCN"
    end
    local result = self:child("FinalSummary-Result")
    if self.m_selfResultEntry.isWin == 1 then
        result:SetImage(FinalSummaryWin)
    elseif self.m_selfResultEntry.isWin == 0 then
        result:SetImage(FinalSummaryLose)
    else
        result:SetImage(FinalSummaryDraw)
    end

    local rewardTxt = self:child("FinalSummary-Self-Reward")
    local txt = tostring(self.m_selfResultEntry.reward)
    rewardTxt:SetText(txt)

    self.m_rewardProgress:SetProgress(self.m_selfResultEntry.todayGetRewarld == 0 and 0 or self.m_selfResultEntry.todayGetRewarld / self.m_selfResultEntry.canGetReward)
    txt = string.format("%d/%d", self.m_selfResultEntry.todayGetRewarld, self.m_selfResultEntry.canGetReward)
    self.m_rewardText:SetText(txt)

    local vipIconRes = ""
    if self.m_selfResultEntry.vip == 1 then
        vipIconRes = "set:summary.json image:VIP"
    elseif self.m_selfResultEntry.vip == 2 then
        vipIconRes = "set:summary.json image:VIPPlus"
    elseif self.m_selfResultEntry.vip == 3 then
        vipIconRes = "set:summary.json image:MVP"
    else
        vipIconRes = ""
    end
    self:child("FinalSummary-Self-VipIcon"):SetImage(vipIconRes)
end

function M:refreshItem(psummaryitem, rankdate)
    local m_rankBgImage = psummaryitem:GetChildByIndex(0)
    local m_rankIamge = psummaryitem:GetChildByIndex(1)
    local m_name = psummaryitem:GetChildByIndex(2)
    local m_rewardIcon = psummaryitem:GetChildByIndex(3)
    local m_rewrd = psummaryitem:GetChildByIndex(4)
    local m_doubleRank = psummaryitem:GetChildByIndex(6)
    local m_doubleRankTen = m_doubleRank:GetChildByIndex(0)
    local m_doubleRankOne = m_doubleRank:GetChildByIndex(1)
    local m_result = psummaryitem:GetChildByIndex(7)
    local m_vipIcon = psummaryitem:GetChildByIndex(8)
    local m_awaldMaxIcon = psummaryitem:GetChildByIndex(9)
    local m_score = psummaryitem:GetChildByIndex(10)

    local bgimage = ""
    local image = ""
    local tenimage = ""
    bgimage, image, tenimage = self:getImageByRank(rankdate.playerRank)
    m_rankBgImage:SetImage(bgimage)
    m_name:SetText(rankdate.playerName)

    if rankdate.playerRank > 9 then
        m_doubleRank:SetVisible(true)
        m_rankIamge:SetVisible(false)
        m_doubleRankTen:SetImage(tenimage)
        m_doubleRankOne:SetImage(image)
    else
        m_doubleRank:SetVisible(false)
        m_rankIamge:SetVisible(true)
        m_rankIamge:SetImage(image)
    end

    m_result:SetVisible(true)
    if rankdate.isWin == 1 then
        m_result:SetImage("set:summary.json image:SmallWin")
    elseif rankdate.isWin == 0 then
        m_result:SetImage("set:summary.json image:SmallLose")
    else
        m_result:SetImage("set:summary.json image:SmallDogfall")
    end

    local vipIconRes = ""
    if rankdate.vip == 1 then
        vipIconRes = "set:summary.json image:VIP"
    elseif rankdate.vip == 2 then
        vipIconRes = "set:summary.json image:VIPPlus"
    elseif rankdate.vip == 3 then
        vipIconRes = "set:summary.json image:MVP"
    else
        vipIconRes = ""
    end
    m_vipIcon:SetImage(vipIconRes)
    m_awaldMaxIcon:SetVisible(rankdate.todayGetRewarld >= rankdate.canGetReward)
    m_rewrd:SetText(rankdate.reward)

    if rankdate.score then
        m_rewardIcon:SetVisible(false)
        m_rewrd:SetVisible(false)
        m_score:SetVisible(true)
        m_score:SetText(rankdate.score)
        self.a_finalsummary_rewrad:SetText("final.summary.score")
    end
end

function M:getResultEntryList(result)
    if result == nil then
        self.m_resultlist = {}
    end
    if result.own == nil or result.players == nil then
        error("The game result content missed some field.")
    end
    local userId = result.own.userId
    for _, player in pairs(result.players) do
        if (not player.name or not player.userId or not player.rank or not player.iswin or not player.gold
                or not player.hasGet or not player.available or not player.vip) then
            error("The game result content missed some field.")
        end
        local item = {}
        item.playerName = player.name
        item.playerRank = tonumber(player.rank)
        item.isWin = tonumber(player.iswin)
        item.playerKillNum = tonumber(player.skills)
        item.isSelf = player.userId == userId
        item.reward = tonumber(player.gold)
        item.todayGetRewarld = tonumber(player.hasGet)
        item.canGetReward = tonumber(player.available)
        item.vip = tonumber(player.vip)
        item.score = tonumber(player.score) or nil
        self.m_resultlist[#self.m_resultlist + 1] = item
    end

    table.sort(self.m_resultlist, function(a, b)
        if a.playerRank == b.playerRank then
            error("ERROR:rank = rank")
        end
        return a.playerRank < b.playerRank
    end)
end

function M:exitButton()
    CGame.instance:exitGame()
end

function M:continueButton()
    UI:closeWnd(self)
    self.showAll()
    if self.m_isNextServer then
        CGame.instance:getShellInterface():nextGame()
    end
end

function M:getImageByRank(rank)
    local bgimage
    if rank == 1 then
        bgimage = "set:new_gui_material.json image:red_icon"
    elseif rank == 2 then
        bgimage = "set:new_gui_material.json image:yellow_icon"
    elseif rank == 3 then
        bgimage = "set:new_gui_material.json image:blue_icon"
    else
        bgimage = "set:new_gui_material.json image:brown_icon"
    end
    local image, tenimage = ""
    local _rank = rank % 100
    if _rank > 9 then
        image = self:getNumImage((_rank % 10))
        tenimage = self:getNumImage(math.floor(_rank / 10))
    else
        image = self:getNumImage(_rank)
    end
    return bgimage, image, tenimage
end

function M:getNumImage(num)
    local image = ""
    if num == 1 then
        image = "set:new_gui_material.json image:number_one"
    elseif num == 2 then
        image = "set:new_gui_material.json image:number_two"
    elseif num == 3 then
        image = "set:new_gui_material.json image:number_three"
    elseif num == 4 then
        image = "set:new_gui_material.json image:number_four"
    elseif num == 5 then
        image = "set:new_gui_material.json image:number_five"
    elseif num == 6 then
        image = "set:new_gui_material.json image:number_six"
    elseif num == 7 then
        image = "set:new_gui_material.json image:number_seven"
    elseif num == 8 then
        image = "set:new_gui_material.json image:number_eight"
    elseif num == 9 then
        image = "set:new_gui_material.json image:number_nine"
    else
        image = "set:new_gui_material.json image:number_zero"
    end
    return image
end

function M:setIsNextServer(isNextServer)
    if isNextServer == nil then
        self.m_isNextServer = isNextServer or false
    else
        self.m_isNextServer = isNextServer
    end
    self.m_finalsummary_Continue:SetVisible(self.m_isNextServer)
end

function M:onReload(reloadArg)
	local result, isNextServer, func = table.unpack(reloadArg or {}, 1, reloadArg and reloadArg.n)
	self:receiveFinalSummary(result, isNextServer, func)
end

return M