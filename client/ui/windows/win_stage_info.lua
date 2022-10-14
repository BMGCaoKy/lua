local stars = {}
local scoreStyles = {}
function M:init()
    WinBase.init(self, "StageInfo.json")

    self.top_info = self:child("StageInfo-Top-GridView")
    self.top_info:InitConfig(30, 30, 3)
    self.top_info:SetAutoColumnCount(false)
    self.top_info:SetMoveAble(false)
    self.right_info = self:child("StageInfo-Right-Info")
    self.stars = self:child("StageInfo-Stars")
    self.stars:SetMoveAble(false)
    self.stars:InitConfig(5, 5, 3)
    self.scoreContent = self:child("StageInfo-Score-Content")
    self.score = self:child("StageInfo-Right-Score")
    self.style_score = self:child("StageInfo-Right-Score-Style")
    self.style_score:SetMoveAble(false)
    self.style_score:SetAutoColumnCount(false)
    self.score:SetText("")
    self.stageBtn = self:child("StageInfo-Stage-Btn")
    self.stageBtn:SetVisible(false)
    self.rowSize = 0
    self.timer = nil
    self.time = 0
    self.stage = nil
    self.chapter = nil
    self.top = {}
    Lib.subscribeEvent(Event.EVENT_UPDATE_STAGE_SCORE, function(score, pyramid, oldScore)
        self:updateScore(score, pyramid, oldScore)
    end)
    Lib.subscribeEvent(Event.EVENT_UPDATE_STAGE_STAR, function(star)
        self:updateStar(star)
    end)
    Lib.subscribeEvent(Event.EVENT_UPDATE_STAGE_TOP_INFO, function(key, value, textKey)
        self:updateInfo(key, value, textKey)
    end)
    Lib.subscribeEvent(Event.EVENT_STAGE_TIME_END, function(regId)
        self:endTimeDeal(regId)
    end)
end

function M:onOpen(info)
    self:onClose()
    local chapterId = info.chapterId
    local stage = info.stage
    self.fullName = info.fullName
    self.chapter = Stage.GetStageCfg(self.fullName, chapterId)
    self.stage = Stage.GetStageCfg(self.fullName, chapterId, stage)
    self.cfg = Stage.GetStageCfg(self.fullName)
    self.warnTime = self.cfg.warnTime and self.cfg.warnTime / 20
    self.regId = info.regId
    self.modName = info.modName
    self:updateTopInfo()
    self:updateRightInfo()
    self.openArgs = table.pack(info)
    local chapterIcon = self.cfg.chapterIcon
    if chapterIcon then
        local btnIcon = type(chapterIcon) == "string" and ResLoader:loadImage(self.cfg, self.cfg.chapterIcon) or "set:app_shop.json image:app_shop_has_get"
        self.stageBtn:SetVisible(true)
        self.stageBtn:SetImage(btnIcon)
        self:unsubscribe(self.stageBtn)
        self:subscribe(self.stageBtn, UIEvent.EventWindowClick, function()
            Stage.LoadEnableChapters(Me, self.fullName, "win_stage")
        end)
    end
end

local function createInfo(key, icon, textKey, value)
    local win = GUIWindowManager.instance:CreateGUIWindow1("Layout", "Stage-Info-" .. key)
    win:SetArea({ 0, 0 }, { 0, 0 }, { 0, 135 }, { 0, 35 })
    win:SetVerticalAlignment(1)
    win:SetProperty("StretchType", "NineGrid")
    win:SetProperty("StretchOffset", "17 17 10 10")
    win:SetBackImage("set:plumber_pass.json image:num_bg.png")
    local wicon = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Stage-Info-Icon-" .. key)
    wicon:SetArea({ 0, -18 }, { 0, 0 }, { 0, 45 }, { 0, 45 })
    wicon:SetVerticalAlignment(1)
    wicon:SetImage(icon or "")
    win:AddChildWindow(wicon, wicon:GetName(), 0)
    local text = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Stage-Info-Text-" .. key)
    text:SetArea({ 0, 35 }, { 0, 0 }, { 0, 50 }, { 1, 0 })
    text:SetProperty("Font", "HT18")
    text:SetProperty("TextVertAlignment", "Centre")
    text:SetText(textKey and Lang:toText({ textKey, value }) or value)
    win:AddChildWindow(text, text:GetName(), 1)
    return win
end

function M:updateTopInfo()
    self.rowSize = 0
    local topInfos = self.chapter and self.chapter.topInfo or {}
    for i, info in ipairs(topInfos) do
        repeat
            if info.key == "time" then
                break
            end
            local icon = ResLoader:loadImage(self.cfg, info.icon) or ""
            local win = createInfo(info.key or i, icon, info.textKey, info.value)
            self:addTopInfo(info.key or i, win)
        until true
    end
    self.time = math.floor(self.stage.time and self.stage.time / 20 or 600)
    if (self.chapter.showTime == nil and true or self.chapter.showTime) and self.time > 0 then
        local icon = self.cfg.timeIcon and ResLoader:loadImage(self.cfg, self.cfg.timeIcon) or "set:other.json image:time_icon"
        local win = createInfo("time", icon, false, self.time)
        local timeText = win:GetChildByIndex(1)
        self:addTopInfo("time", win)
        self:timeIn(timeText, false, self.modName, self.regId)
    end
end

function M:updateRightInfo()
    local h = 0
    local star = self.stage.star
    if star then
        self.stars:SetVisible(true)
        self.stars:InitConfig(5, 5, star.count or 3)
        for i = 1, star.count or 3 do
            local icon = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Stage-RightInfo-Star" .. i)
            local defaultIcon = star.defaultIcon and ResLoader:loadImage(self.cfg, star.defaultIcon)
            icon:SetArea({ 0, 0 }, { 0, 0 }, { 0, 50 }, { 0, 50 })
            icon:SetImage(defaultIcon or "set:PirateIco.json image:no_light_star")
            stars[i] = { icon = icon, star = star }
            self.stars:AddItem(icon)
        end
        h = h + self.stars:GetHeight()[2] + 5
    end
    self.scoreContent:SetYPosition({ 0, h })
    h = h + self.scoreContent:GetHeight()[2] + 5
    self.stageBtn:SetYPosition({ 0, h })
end

function M:addTopInfo(key, win)
    self.top[key] = win
    self.rowSize = self.rowSize + 1
    self.top_info:InitConfig(30, 30, self.rowSize)
    self.top_info:AddItem(win)
end

function M:timeIn(timeText, interval, modName, regId)
    timeText:SetText(self.time)
    local rate = interval and math.max(math.floor(self.time / 60), 1) or 1
    local function tick()
        self.time = math.max(self.time - rate, 0)
        timeText:SetText(self.time)
        if self.time <= 0 then
            if regId and modName then
                Me:doRemoteCallback(modName, "key", type(regId) == "table" and regId.regId_TimeEnd or regId)
            end
            return false
        end
        if self.warnTime and self.time == self.warnTime then
            timeText:SetTextColor({ 255 / 255, 0 / 255, 0 / 255 })
            Me:doRemoteCallback(modName, "warn", type(regId) == "table" and regId.regId_TimeNearlyEnd or regId)
        end
        return true
    end
    self.timer = World.Timer(interval or 20, tick)
end

function M:updateScore(score, pyramid, oldScore)
    if self.scoreTimer then
        self.scoreTimer()
        self.scoreTimer = nil
    end
    if pyramid then
        oldScore = oldScore or 0
        local rate = math.max(math.floor((score - oldScore) / math.min(self.time, 60)), 1)
        self.score:SetText(oldScore)
        self.scoreTimer = World.Timer(1, function()
            oldScore = math.min(oldScore + rate, score)
            self:setScoreText(oldScore)
            if oldScore >= score then
                return false
            end
            return true
        end)
    else
        self:setScoreText(score)
    end
end

function M:updateStyleScore(score, styles)
    local s = score == 0 and  "000000" or tostring(score)
    local styleLen = #scoreStyles
    local oldLen = s:len()
    s = string.rep("0", styleLen - oldLen) .. s
    local len = s:len()
    if len <= styleLen then
        for i = -styleLen, -1 do
            i = math.abs(i)
            local str = i > (styleLen - oldLen) and string.sub(s, i, i) or "0"
            scoreStyles[i]:SetImage(str ~= "" and ResLoader:loadImage(self.cfg, styles[str]) or "0")
        end
    else
        for i = 1, len - #scoreStyles do
            local scoreText = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Score-Image-" .. i)
            scoreText:SetArea({ 0, 0 }, { 0, 0 }, { 0, 26 }, { 0, 33 })
            table.insert(scoreStyles, scoreText)
            self.style_score:InitConfig(0, 0, #scoreStyles)
            self.style_score:AddItem(scoreText)
        end
        self:updateStyleScore(score, styles)
    end
end

function M:setScoreText(score)
    score = math.max(score, 0)
    local scoreStyle = self.cfg.scoreStyle
    if scoreStyle then
        self:updateStyleScore(score, scoreStyle)
    else
        self.score:SetText(score)
    end
end

function M:updateStar(star)
    for i, bool in pairs(star) do
        local info = stars[i]
        local starInfo = info.star
        local lightIcon = starInfo.lightIcon and ResLoader:loadImage(self.cfg, starInfo.lightIcon)
        local defaultIcon = starInfo.defaultIcon and ResLoader:loadImage(self.cfg, starInfo.defaultIcon)
        local image = bool and (lightIcon or "set:PirateIco.json image:light_star") or (defaultIcon or "set:PirateIco.json image:no_light_star")
        info.icon:SetImage(image)
    end
end

function M:updateInfo(key, value, textKey)
    local win = self.top[key]
    if not win or key == "time" then
        return
    end
    local text = win:GetChildByIndex(1)
    text:SetText(textKey and Lang:toText({ textKey, value }) or value)
end

function M:endTimeDeal(regId)
    if self.timer then
        self.timer()
        self.timer = nil
    end
    local timeWin = self.top.time and self.top.time:GetChildByIndex(1)
    if not timeWin or self.time <= 0 then
        return
    end
    self:timeIn(timeWin, 1, "stageTime", regId)
end

function M:onClose()
    if self.timer then
        self.timer()
        self.timer = nil
    end
    if self.scoreTimer then
        self.scoreTimer()
        self.scoreTimer = nil
    end
    self.top = {}
    self.time = 0
    self.regId = nil
    self.modName = nil
    self.top_info:RemoveAllItems()
    self.stars:RemoveAllItems()
end

return M