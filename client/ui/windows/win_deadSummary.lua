local strfor = string.format

local gInstance = CGame.instance
local exitBtn, watchBattleBtn, contiueBtn,
rewardTip, nameTxt, m_title, rewardTitle, rankTitle,
m_rewardProgress, m_rewardText,
m_gameReslut, m_isNextServer, m_isWatcher, m_showAll,
eliminatedTipTitle, m_deadSummaryContentEliminated, eliminatedScore

function M:init()
    WinBase.init(self, "DeadSummary.json", true)
    exitBtn = self:child("DeadSummary-Content-Exit")
    exitBtn:SetText(Lang:toText("gui.exit"))
    self:subscribe(exitBtn, UIEvent.EventButtonClick, function()
        self:exitbutton()
    end)
    watchBattleBtn = self:child("DeadSummary-Content-WatchBattle")
    watchBattleBtn:SetText(Lang:toText("dead.summary.watch.battle"))
    self:subscribe(watchBattleBtn, UIEvent.EventButtonClick, function()
        self:onWatchBattleClick()
    end)
    contiueBtn = self:child("DeadSummary-Content-Contince")
    contiueBtn:SetText(Lang:toText("gui.continue"))
    self:subscribe(contiueBtn, UIEvent.EventButtonClick, function()
        self:onContiueClick()
    end)
    rewardTip = self:child("DeadSummary-Content-Reward-Tip")
    nameTxt = self:child("DeadSummary-Content-Name")
    m_title = self:child("DeadSummary-Title")
    m_title:SetText(Lang:toText("dead.summary.title"))
    m_title:SetScale({ x = 1, y = 1, z = 1 })
    rewardTitle = self:child("DeadSummary-Content-RewardTitle")
    rewardTitle:SetText(Lang:toText("dead.summary.reward"))
    rewardTitle:SetScale({ x = 1, y = 1, z = 1 })
    rankTitle = self:child("DeadSummary-Content-RankTitle")
    rankTitle:SetText(Lang:toText("dead.summary.rank"))
    rankTitle:SetScale({ x = 1, y = 1, z = 1 })
    m_rewardProgress = self:child("DeadSummary-Content-Reward-Slider")
    m_rewardText = self:child("DeadSummary-Content-Reward-Slider-Text")
    eliminatedTipTitle = self:child("DeadSummary-Content-Eliminated-Tip")
    eliminatedTipTitle:SetText(Lang:toText("dead_summary_eliminated_title"))
    m_deadSummaryContentEliminated = self:child("DeadSummary-Content-Eliminated")
    m_deadSummaryContentEliminated:SetVisible(false)
    eliminatedScore = self:child("DeadSummary-Content-ScoreWindow"):GetChildByIndex(0)
    eliminatedScore:SetVisible(false)
end

local function getResultEntry(result)
    local item = {}
    item.name = result.name
    item.rank = tonumber(result.rank)
    item.killNum = tonumber(result.kills)
    item.reward = tonumber(result.gold)
    item.todayGetReward = tonumber(result.hasGet)
    item.canGetReward = tonumber(result.available)
    item.vip = tonumber(result.vip)
    item.score = tonumber(result.score)
    return item
end

local function getNumImage(num)
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

local function getImageByNum(rank)
    local bgImage, image, tenImage, textColor, borderColor
    borderColor = { 67 / 255, 50 / 255, 39 / 255, 1 }
    if rank == 1 then
        bgImage = "set:new_gui_material.json image:red_icon"
        textColor = { 212 / 255, 86 / 255, 86 / 255, 1 }
    elseif rank == 2 then
        bgImage = "set:new_gui_material.json image:yellow_icon"
        textColor = { 237 / 255, 208 / 255, 84 / 255, 1 }
    elseif rank == 3 then
        bgImage = "set:new_gui_material.json image:blue_icon"
        textColor = { 148 / 255, 156 / 255, 177 / 255, 1 }
    else
        bgImage = "set:new_gui_material.json image:brown_icon"
        textColor = { 1, 1, 1, 1 }
    end
    local _rank = rank % 100
    if _rank > 9 then
        tenImage = getNumImage(_rank / 10)
        image = getNumImage(_rank % 10)
    else
        image = getNumImage(_rank)
    end
    return bgImage, image, tenImage, textColor, borderColor
end

function M:onOpen(result, isNextServer, isWatcher, title, func)
    m_showAll = func
    m_gameReslut = getResultEntry(result)
    self:setIsNextServer(isNextServer)
    self:setIsWatcher(isWatcher)
    if title then
        eliminatedTipTitle:SetText(Lang:toText(title))
    end
    self:refreshUI()
	self.openArgs = table.pack(result, isNextServer, isWatcher, title, func)
end

function M:refreshUI()
    if not m_gameReslut then
        return
    end
    local rank = m_gameReslut.rank
    local reward = m_gameReslut.reward
    local name = m_gameReslut.name
    local score = m_gameReslut.score
    local killNum = m_gameReslut.killNum

    local bgImage, image, tenImage = getImageByNum(rank)
    local nextText = self:child("DeadSummary-Content-Name")
    nextText:SetText(tostring(name))

    local rewardTxt = self:child("DeadSummary-Content-Reward")
    local txt = tostring(reward)
    rewardTxt:SetText(tostring(txt))
    local todayGetReward = m_gameReslut.todayGetReward or 0
    local canGetReward = m_gameReslut.canGetReward or 0
    m_rewardProgress:SetProgress((todayGetReward / canGetReward))
    m_rewardText:SetText(strfor("%d/%d", todayGetReward, canGetReward))

    local rankBgImg = self:child("DeadSummary-Content-RankBg")
    rankBgImg:SetImage(bgImage)
    local rankImg = self:child("DeadSummary-Content-Rank")
    local doubleRank = self:child("DeadSummary-Content-DoubleRank")
    if rank > 9 then
        doubleRank:SetVisible(true)
        rankImg:SetVisible(false)
        self:child("DeadSummary-Content-DoubleRank-Ten"):SetImage(tenImage)
        self:child("DeadSummary-Content-DoubleRank-One"):SetImage(image)
    else
        doubleRank:SetVisible(false)
        rankImg:SetVisible(true)
        rankImg:SetImage(image)
    end

    local vipIconRes = ""
    if m_gameReslut.vip == 1 then
        vipIconRes = "set:summary.json image:VIP"
    elseif m_gameReslut.vip == 2 then
        vipIconRes = "set:summary.json image:VIPPlus"
    elseif m_gameReslut.vip == 3 then
        vipIconRes = "set:summary.json image:MVP"
    else
        vipIconRes = ""
    end
    self:child("DeadSummary-Content-VipIcon"):SetImage(vipIconRes)
    if killNum then
        self:showEliminated(killNum)
    end
    if score then
        eliminatedScore:SetVisible(true)
        local scoreName = eliminatedScore:GetChildByIndex(1)
        local w_score = eliminatedScore:GetChildByIndex(0)
        scoreName:SetText(Lang:toText("dead_summary_score_name"))
        w_score:SetText(score)
    end
end

function M:showEliminated(killNum)
    m_deadSummaryContentEliminated:SetVisible(true)
    local eliminatedName = self:child("DeadSummary-Content-Eliminated-RankTitle")
    eliminatedName:SetText(Lang:toText("dead_summary_eliminated_kill"))
    local _, image, tenImage = getImageByNum(killNum)
    local rankImg = self:child("DeadSummary-Content-Eliminated-Rank")
    local doubleRank = self:child("DeadSummary-Content-Eliminated-DoubleRank")
    if killNum > 9 then
        doubleRank:SetVisible(true)
        rankImg:SetVisible(false)
        self:child("DeadSummary-Content-Eliminated-DoubleRank-Ten"):SetImage(tenImage)
        self:child("DeadSummary-Content-Eliminated-DoubleRank-One"):SetImage(image)
    else
        doubleRank:SetVisible(false)
        rankImg:SetVisible(true)
        rankImg:SetImage(image)
    end
end

function M:setIsNextServer(isNextServer)
    m_isNextServer = isNextServer and isNextServer or false
    contiueBtn:SetVisible(m_isNextServer)
end

function M:setIsWatcher(isWatcher)
    m_isWatcher = isWatcher and isWatcher or false
    watchBattleBtn:SetVisible(m_isWatcher)
end

function M:exitbutton()
--    if m_showAll then
--        m_showAll()
--    end
    gInstance:exitGame()
end

function M:onWatchBattleClick()

end

function M:onContiueClick()
    UI:closeWnd(self)
    if m_isNextServer then
        gInstance:getShellInterface():nextGame()
    end
end

return M