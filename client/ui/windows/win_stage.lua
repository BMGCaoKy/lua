local fullName
local chapterInfo
local curStars
local contentArr = {}
local stageLbArr = {}
local stageStarArr = {}
local stageBtnArr = {}
local boxBtnArr = {}
local icons = {}

local function showChapters(self, show)
    icons = {}
    self.chapterContent:SetVisible(show)
    self.stageContent:SetVisible(not show)
end

local function startStage(stage)
    Stage.RequestStartStage(Me, fullName, chapterInfo.chapterCfg.id, stage)
end

local function receiveBox(star)
    for k, v in pairs(chapterInfo.archiveData.receivedStarReward or {}) do
        if v == star then
            return --已领取
        end
    end
    if star > curStars then
        return --未达标
    end
    Stage.ReceiveStarReward(Me, fullName, chapterInfo.chapterCfg.id, star)
end

local function createBoxes(self, starReward, totalStars)
    if self.boxContentV then
        GUIWindowManager.instance:DestroyGUIWindow(self.boxContentV)
    end
    boxBtnArr = {}

    self.boxContentV = GUIWindowManager.instance:CreateGUIWindow1("Layout", "Conten-Boxes")
    self.boxContentV:SetArea({ 0, 0 }, { 0, -20 }, { 0.8, 0 }, { 0, 100 })
    self.boxContentV:SetBackgroundColor({ 1, 1, 1, 1 })
    self.boxContentV:SetVerticalAlignment(2)
    self.boxContentV:SetHorizontalAlignment(1)
    self.stageContent:AddChildWindow(self.boxContentV)
    local proBarBg = GUIWindowManager.instance:CreateGUIWindow1("Layout", "Conten-Boxes-BarBg")
    proBarBg:SetArea({ 0, 0 }, { 0, 0 }, { 1, 0 }, { 0, 15 })
    proBarBg:SetBackgroundColor({ 0.5, 0.5, 0.5, 1 })
    proBarBg:SetVerticalAlignment(2)
    self.boxContentV:AddChildWindow(proBarBg)
    self.proBar = GUIWindowManager.instance:CreateGUIWindow1("Layout", "Conten-Boxes-BarBg-Bar")
    self.proBar:SetArea({ 0, 0 }, { 0, 0 }, { 0, 0 }, { 1, 0 })
    self.proBar:SetBackgroundColor({ 1, 0, 0, 1 })
    proBarBg:AddChildWindow(self.proBar)
    for k, v in ipairs(starReward) do
        local star = v.star
        local rate = star / totalStars
        local bg = GUIWindowManager.instance:CreateGUIWindow1("Layout", "Content-Boxes-Box" .. tostring(k))
        bg:SetArea({ rate, -80 }, { 0, 0 }, { 0, 80 }, { 0, 80 })
        bg:SetBackgroundColor({ 1, 0, 0, 1 })
        self.boxContentV:AddChildWindow(bg)
        local btn = GUIWindowManager.instance:CreateGUIWindow1("Button", "Content-Boxes-Box-btn" .. tostring(k))
        btn:SetArea({ 0, 0 }, { 0, 0 }, { 0, 50 }, { 0, 50 })
        btn:SetVerticalAlignment(1)
        btn:SetHorizontalAlignment(1)
        btn:SetBackgroundColor({ 0, 1, 1, 1 })
        bg:AddChildWindow(btn)
        boxBtnArr[#boxBtnArr + 1] = btn
        self:subscribe(btn, UIEvent.EventButtonClick, function()
            receiveBox(star)
        end)
    end
end

local function createStages(self)
    local chapterCfg = chapterInfo.chapterCfg
    local archiveData = chapterInfo.archiveData or {}
    showChapters(self, false)
    self.stageBgImage:SetImage(ResLoader:loadImage(chapterCfg.cfg, chapterCfg.bgImage))
    self.routeProgress:SetProgressImage(chapterCfg.route_blue)
    self.routeProgress:SetBackImage(chapterCfg.route_gray)
    self.lastChapterBtn:SetVisible(chapterCfg.cfg.showChapterCutoverBtn and chapterInfo.lastChapterId and true or false)
    self.nextChapterBtn:SetVisible(chapterCfg.cfg.showChapterCutoverBtn and chapterInfo.nextChapterId and true or false)
    for k, v in pairs(contentArr) do
        GUIWindowManager.instance:DestroyGUIWindow(v)
    end
    contentArr = {}
    stageStarArr = {}
    stageBtnArr = {}
    stageLbArr = {}

    local enableStages = chapterInfo.enableStages
    local passedStages = chapterInfo.passedStages
    local enable = {}
    local passed = {}
    local farthestStage = 1
    for _, v in ipairs(enableStages) do
        enable[v] = true
        farthestStage = farthestStage > v and farthestStage or v
    end
    for _, v in ipairs(passedStages) do
        passed[v] = true
    end
    for k, v in ipairs(chapterCfg.stages or {}) do
        if k == farthestStage then
            self.routeProgress:SetProgress(v.progressBar)
        end
        local pos = v.pos or {}
        local x = type(pos.x) == "table" and pos.x or { 0, 0 }
        local y = type(pos.y) == "table" and pos.y or { 0, 0 }
        local contentV = GUIWindowManager.instance:CreateGUIWindow1("Layout", "Conten" .. tostring(k))
        contentV:SetArea(x, y, { 0, 160 }, { 0, 155 })
        contentV:SetVerticalAlignment(pos.vAlign or 0)
        contentV:SetHorizontalAlignment(pos.hAlign or 0)
        self.stageBgImage:AddChildWindow(contentV)
        contentArr[#contentArr + 1] = contentV
        local stageBtn = GUIWindowManager.instance:CreateGUIWindow1("Button", "EnterBtn" .. tostring(k))
        stageBtn:SetArea({ 0, 0 }, { 0, -15 }, { 0, 69 }, { 0, 85 })
        stageBtn:SetVerticalAlignment(2)
        stageBtn:SetHorizontalAlignment(1)
        stageBtn:SetNormalImage("set:plumber_stage.json image:stage_unlock.png")
        stageBtn:SetPushedImage("set:plumber_stage.json image:stage_unlock.png")
        contentV:AddChildWindow(stageBtn)
        self:subscribe(stageBtn, UIEvent.EventButtonClick, function()
            Stage.RequestStartStage(Me, fullName, chapterCfg.id, k)
        end)
        if not enable[k] then --未解锁
            local lock = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Lock" .. tostring(k))
            lock:SetArea({ 0, 0 }, { 0, 20 }, { 0, 24 }, { 0, 30 })
            lock:SetImage("set:plumber_stage.json image:lock.png")
            lock:SetHorizontalAlignment(1)
            stageBtn:AddChildWindow(lock)
        else --已解锁
            local stageLevel = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "StageLevel" .. tostring(k))
            stageLevel:SetArea({ 0, 0 }, { 0, 17 }, { 1, 0 }, { 0, 20 })
            stageLevel:SetHorizontalAlignment(1)
            stageLevel:SetProperty("TextVertAlignment", "Centre")
            stageLevel:SetProperty("TextHorzAlignment", "Centre")
            stageLevel:SetProperty("Font", "HT12")
            stageLevel:SetProperty("TextShadow", "true")
            stageLevel:SetProperty("TextShadowColor", tostring(46 / 255) .. " " .. tostring(97 / 255) .. " " .. tostring(156 / 255) .. " 1")
            stageLevel:SetText(v.name)
            stageBtn:AddChildWindow(stageLevel)
            local stageData = archiveData.stages and archiveData.stages[k] or {}
            for i = 1, v.star.count or 3 do
                local star = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "starSmall" .. tostring(k))
                star:SetArea({ 0, (i - 1) * 17 + 8 }, { 0, 35 + (i - 1) % 2 * 5 }, { 0, 15 }, { 0, 16 })
                star:SetImage("set:plumber_stage.json image:star_gray_small.png")
                stageBtn:AddChildWindow(star)
                if stageData.stars and stageData.stars[i] then
                    star:SetImage("set:plumber_stage.json image:star_ye_small.png")
                end
            end
            self:showRank(v.rank, k, contentV)
            if passed[k] then --已通关
                local scoreImg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "ScoreBg" .. tostring(k))
                scoreImg:SetArea({ 0, 0 }, { 0, 0 }, { 0, 100 }, { 0, 24 })
                scoreImg:SetHorizontalAlignment(1)
                scoreImg:SetVerticalAlignment(2)
                scoreImg:SetImage("set:plumber_stage.json image:score_bg.png")
                scoreImg:SetProperty("StretchType", "LeftRight")
                scoreImg:SetProperty("StretchOffset", "10 10 0 0")
                contentV:AddChildWindow(scoreImg)
                local scoreLb2 = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Score2" .. tostring(k))
                scoreLb2:SetArea({ 0, 0 }, { 0, -1 }, { 1, 0 }, { 1, 0 })
                scoreLb2:SetText(stageData.maxScore or 0)
                scoreLb2:SetProperty("Font", "HT12")
                scoreLb2:SetProperty("TextVertAlignment", "Centre")
                scoreLb2:SetProperty("TextHorzAlignment", "Centre")
                scoreImg:AddChildWindow(scoreLb2)
            end
        end
    end
    if chapterCfg.cfg.showStarBoxBar then
        local totalStars = 0
        curStars = 0

        for _, v in pairs(chapterCfg.stages) do
            totalStars = totalStars + v.star.count
        end
        for _, v in pairs(archiveData.stages or {}) do
            curStars = curStars + v.stars or 0
        end
        local progress = curStars / totalStars
        createBoxes(self, chapterCfg.starReward, totalStars)
        self.proBar:SetWidth({ progress, 0 })
    end
end

local chaptersArr = {}
local function createChapters(self, enableChapters, cfg)
    for _, v in pairs(chaptersArr) do
        GUIWindowManager.instance:DestroyGUIWindow(v)
    end
    chaptersArr = {}

    local enable = {}
    for _, v in pairs(enableChapters) do
        enable[v] = true
    end
    for k, v in ipairs(cfg.chapters) do
        local area = v.chapter_area or {}
        local chapterBtn = GUIWindowManager.instance:CreateGUIWindow1("Button", "Chapter" .. tostring(k))
        chapterBtn:SetArea(area.x or {0, 0}, area.y or {0, 0}, area.w or {0.25, 0}, area.h or {0.25, 0})
        chapterBtn:SetVerticalAlignment(area.vAlign or 0)
        chapterBtn:SetHorizontalAlignment(area.hAlign or 0)
        self.world:AddChildWindow(chapterBtn)
        table.insert(chaptersArr, chapterBtn)
        local chapterImg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "ChapterImage" .. tostring(k))
        chapterImg:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
        chapterBtn:AddChildWindow(chapterImg)
        self:subscribe(chapterBtn, UIEvent.EventButtonClick, function()
            Stage.LoadChapter(Me, fullName, v.id, "win_stage", true)
        end)
        if enable[v.id] then
            --已解锁章节
            chapterImg:SetImage(ResLoader:loadImage(cfg, v.image.color))
        else
            --未解锁章节
            chapterImg:SetImage(ResLoader:loadImage(cfg, v.image.gray))
            local flag = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "ChapterFlag" .. tostring(k))
            local area = v.flag_area or {}
            flag:SetArea(area.x or {0, 0}, area.y or {0, 0}, area.w or {0, 80}, area.h or {0, 80})
            flag:SetVerticalAlignment(area.vAlign or 0)
            flag:SetHorizontalAlignment(area.hAlign or 0)
            flag:SetImage("set:plumber_stage.json image:stage_lock.png")
            chapterBtn:AddChildWindow(flag)
            local lock = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Lock" .. tostring(k))
            lock:SetArea({ 0, 0 }, { 0, 20 }, { 0, 24 }, { 0, 30 })
            lock:SetImage("set:plumber_stage.json image:lock.png")
            lock:SetHorizontalAlignment(1)
            flag:AddChildWindow(lock)
        end
    end
end

function M:init()
    WinBase.init(self, "Stage.json", true)

    self.chapterContent = self:child("Stage-ChapterCt")
    self.chapterBgImage = self:child("Chapter-Bgimage")
    self.chaptercloseBtn = self:child("Chapter-Close-Btn")

    self.stageContent = self:child("Stage-StageCt")
    self.stageBgImage = self:child("Stage-Bgimage")
    self.stageCloseBtn = self:child("Stage-Close-Btn")

    self.lastChapterBtn = self:child("Stage-LastChapter")
    self.nextChapterBtn = self:child("Stage-NextChapter")

    self.lifeLb = self:child("Stage-Life")
    self.starLb = self:child("Stage-Star")
    self.totalScoreLb = self:child("Stage-TotalScore")
    self.routeProgress = self:child("Stage-Route")
    self.world = self:child("Stage-World")
    self.worldTitle = self:child("Stage-World-Title")
    self.worldTitle:SetText(Lang:toText("stage_world_title"))

    self.stageEvents = self:child("Stage-Events")

    self:subscribe(self.lastChapterBtn, UIEvent.EventButtonClick, function()
        if chapterInfo.lastChapterId then
            Stage.LoadChapter(Me, fullName, chapterInfo.lastChapterId, "win_stage", true)
        end
    end)
    self:subscribe(self.nextChapterBtn, UIEvent.EventButtonClick, function()
        if chapterInfo.nextChapterId then
            Stage.LoadChapter(Me, fullName, chapterInfo.nextChapterId, "win_stage", true)
        end
    end)
    self:subscribe(self.chaptercloseBtn, UIEvent.EventButtonClick, function()
        UI:closeWnd("stage")
    end)
    self:subscribe(self.stageCloseBtn, UIEvent.EventButtonClick, function()
        showChapters(self, true)
    end)

    Lib.subscribeEvent(Event.EVENT_CLOSE_RELATED_WND, function()
        UI:closeWnd("stage")
    end)

    Lib.subscribeEvent(Event.EVENT_SHOW_STAGES, function(packet)
        chapterInfo = packet.chapterInfo
        self.lifeLb:SetText("x" .. chapterInfo.life)
        self.starLb:SetText("x" .. chapterInfo.totalStars)
        self.totalScoreLb:SetText(Lang:toText({"stage.total.score", chapterInfo.totalScore}))
        createStages(self)
    end)

    Lib.subscribeEvent(Event.EVENT_STAGES_RANK_HEAD_ICON, function(id, data)
        local icon = icons[id]
        if not icon then
            return
        end
        if data and data.picUrl and #data.picUrl > 0 then
            icon:SetImageUrl(data.picUrl)
        else
            icon:SetImage("set:default_icon.json image:header_icon")
        end
    end)
end

function M:onOpen(packet)

end

function M:updateChapterInfo(packet)
    fullName = packet.fullName
    local cfg = packet.cfg
    self.world:SetImage(ResLoader:loadImage(cfg, cfg.worldMap))
    createChapters(self, packet.enableChapters, cfg)
    showChapters(self, true)
    self:updateIconEvents(cfg.iconEvents, cfg)
end

function M:updateIconEvents(events, cfg)
    self.stageEvents:CleanupChildren()
    if not events or not (type(events) == "table") or not (#events > 0) then
        return
    end
    for i, ret in pairs(events) do
        local image = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Stage-event-" .. i)
        local size = ret.size
        local h = size and size[2] or 70
        image:SetArea({ 0, 0 }, { 0, (i - 1) * (h + 10) }, { 0, size and size[1] or 70 }, { 0, h })
        image:SetHorizontalAlignment(2)
        image:SetImage(ResLoader:loadImage(cfg, ret.icon))
        self.stageEvents:AddChildWindow(image)
        if ret.event then
            self:unsubscribe(image)
            self:subscribe(image, UIEvent.EventWindowClick, function()
                Me:sendTrigger(Me, ret.event, Me)
            end)
        end
    end
end

function M:showRank(rank, stage, parent)
    --todo 弹出每个stage的排名情况 暂定只显示一个
    if not rank or not rank.type then
        return
    end
    local size_height = 40
    local rankInfo = Rank.GetRankData(rank.type)
    local datas = rankInfo[rank.subType] or {}

    if not next(datas) then
        return
    end
    local size = math.min(rank.size, 1)
    size_height = size_height * size
    local strName = "Stage-Rank-" .. (stage or "0")
    local stageRank = GUIWindowManager.instance:CreateWindowFromTemplate(strName, "StageRank.json")
    if parent then
        local h = stageRank:GetHeight()[2] + size_height
        stageRank:SetHeight({ 0, h })
        stageRank:SetYPosition({ 0, -h / 2 })
        parent:AddChildWindow(stageRank)
    end
    for i = 1, size do
        local data = datas[i]
        self:addRank(stageRank:GetChildByIndex(0), data, i)
    end
end

function M:addRank(list, data, index)
    list:SetMoveAble(false)
    local w = 40
    local content = GUIWindowManager.instance:CreateGUIWindow1("Layout", "Content-" .. index)
    content:SetArea({ 0.0 }, { 0, 0 }, { 1, 0 }, { 0, w })
    local icon = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Content-Icon-" .. index)
    icon:SetArea({ 0, 0 }, { 0, 5 }, { 0, w }, { 0, w })
    local id = icon:getId()
    icons[id] = icon
    AsyncProcess.GetUserDetail(data.userId, function(_data)
        Lib.emitEvent(Event.EVENT_STAGES_RANK_HEAD_ICON, id, _data)
    end)
    content:AddChildWindow(icon)
    local name = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Content-Name-" .. index)
    name:SetArea({ 0, w + 10 }, { 0, 0 }, { 0.5, 0 }, { 0, w / 2 })
    name:SetText(data.name)
    name:SetTextColor({ 21 / 255, 78 / 255, 44 / 255 })
    name:SetProperty("Font", "HT14")
    content:AddChildWindow(name)
    local score = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "Content-Name-" .. index)
    score:SetArea({ 0, w + 10 }, { 0, (w / 2) }, { 0.5, 0 }, { 0, w / 2 })
    score:SetText(data.score)
    score:SetTextColor({ 255 / 255, 255 / 255, 255 / 255 })
    score:SetTextBoader({103 / 255, 143 / 255, 39 / 255})
    score:SetProperty("Font", "HT16")
    content:AddChildWindow(score)
    list:AddItem(content)
end

function M:onClose()
    icons = {}
end

return M