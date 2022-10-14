
local chapterInfo
local stageOptions = {}
local curStage = 1
local minStage = 1

local function createStageOption(self, stage, enable, passed, big)
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "OptionCell")
    cell:SetVerticalAlignment(1)
    cell:SetHorizontalAlignment(1)
    local bg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Image")
    bg:SetArea({0, 0}, {0, 0}, {1, -46}, {1, 0})
    bg:SetHorizontalAlignment(1)
    bg:SetImage("set:challenge_tower.json image:stage_holder.png")
    cell:AddChildWindow(bg)
    local titleBg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Image")
    titleBg:SetArea({0, 0}, {12/222, 0}, {1, 0}, {41/222, 0})
    titleBg:SetProperty("StretchType", "LeftRight")
    titleBg:SetProperty("StretchOffset", "25 25 0 0")
    titleBg:SetImage("set:challenge_tower.json image:title_bg.png")
    cell:AddChildWindow(titleBg)
    local text = GUIWindowManager.instance:CreateGUIWindow1("StaticText", "stage")
    text:SetArea({0, 0}, {0, -3}, {1, 0}, {0, 25})
    text:SetTextHorzAlign(1)
    text:SetTextVertAlign(1)
    text:SetVerticalAlignment(1)
    text:SetFontSize(big and "HT20" or "HT16")
    text:SetTextBoader({0, 0, 0})
    text:SetText("Level " .. stage)
    titleBg:AddChildWindow(text)
    if passed then
        local image = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Passed" .. stage)
        image:SetImage("set:challenge_tower.json image:stage_passed.png")
        image:SetArea({0, 0}, {0, 0}, {74/204, 0}, {74/222, 0})
        image:SetVerticalAlignment(1)
        image:SetHorizontalAlignment(1)
        cell:AddChildWindow(image)
    elseif not enable then
        local mask = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Mask" .. stage)
        mask:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
        mask:SetProperty("StretchType", "NineGrid")
        mask:SetProperty("StretchOffset", "50 50 60 20")
        mask:SetImage("set:challenge_tower.json image:stage_mask.png")
        cell:AddChildWindow(mask)
        local image = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Lock" .. stage)
        image:SetArea({ 0, 0 }, { 0, 0 }, { 59/204, 0 }, { 68/222, 0 })
        image:SetImage("set:challenge_tower.json image:stage_lock.png")
        image:SetVerticalAlignment(1)
        image:SetHorizontalAlignment(1)
        cell:AddChildWindow(image)
    end
    self.optionContent:AddChildWindow(cell)
    table.insert(stageOptions, cell)
    return cell
end

local function createBoxCell(boxImage)
    local cell = GUIWindowManager.instance:CreateGUIWindow1("Layout", "BoxCell")
    cell:SetArea({0, 0}, {0, 0}, {0, 113}, {0, 85})
    local bg = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Image")
    bg:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
    bg:SetImage("set:challenge_tower.json image:box_holder.png")
    cell:AddChildWindow(bg)
    local box = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Image")
    box:SetArea({0, 0}, {0, 0}, {1, 0}, {1, 0})
    box:SetImage(boxImage or "")
    cell:AddChildWindow(box)
    return cell
end

local function showRewardBox(self, show)
    self.fightContent:SetVisible(not show)
    self.receiveContent:SetVisible(show)
    if not show then
        return
    end
    self.boxGrid:RemoveAllItems()
    local reward = chapterInfo.chapterCfg.reward or {}
    for i = 1, 6 do
        local cell
        if i <= #reward then
            local temp = reward[i]
            cell = createBoxCell("")
        else
            cell = createBoxCell()
        end
        self.boxGrid:AddItem(cell)
    end
end

local function fillOptionGrid(self)
    local chapter = chapterInfo.chapterCfg
    local archiveData = chapterInfo.archiveData or {}
    local enableStages = chapterInfo.enableStages
    local passedStages = chapterInfo.passedStages
    local enable = {}
    local passed = {}
    for _, v in ipairs(enableStages) do
        enable[v] = true
    end
    for _, v in ipairs(passedStages) do
        passed[v] = true
    end
    local count = #chapter.stages
    self.lastBtn:SetVisible(curStage > 1)
    self.nextBtn:SetVisible(curStage < count)
    for _, win in ipairs(stageOptions) do
        self.optionContent:RemoveChildWindow1(win)
    end
    local showLeft = true
    local showRight = true
    if chapter.stages and #chapter.stages == 1 then
        showLeft = false
        showRight = false
    elseif curStage == 1 then
        showLeft = false
    elseif curStage == count then
        showRight = false
    end
    local showStage = minStage + curStage - 1
    local center = createStageOption(self, showStage, enable[curStage], passed[curStage], true)
    center:SetArea({0, 0}, {0, 0}, {0, 248}, {0, 268})
    if showLeft then
        local left = createStageOption(self, showStage - 1, enable[curStage - 1], passed[curStage - 1])
        left:SetArea({0, -250}, {0, 0}, {0, 204}, {0, 222})
    end
    if showRight then
        local right = createStageOption(self, showStage + 1, enable[curStage + 1], passed[curStage + 1])
        right:SetArea({0, 250}, {0, 0}, {0, 204}, {0, 222})
    end
    showRewardBox(self, #passed > 0 and #enable == #passed and not archiveData.reward)
end

function M:init()
    WinBase.init(self, "ChallengeTower.json", true)
    self.lastBtn = self:child("ChallengeTower-Last")
    self.nextBtn = self:child("ChallengeTower-Next1")
    self.receiveBtn = self:child("ChallengeTower-ReceiveBtn")
    self.fightBtn = self:child("ChallengeTower-FightBtn")
    self.optionContent = self:child("ChallengeTower-Options")
    self.boxGrid = self:child("ChallengeTower-BoxGrid")
    self.boxGrid:InitConfig(10, 10, 6)
    self.boxGrid:SetMoveAble(false)
    self.fightContent = self:child("ChallengeTower-Fight")
    self.receiveContent = self:child("ChallengeTower-Receive")

    self:subscribe(self.lastBtn, UIEvent.EventButtonClick, function()
        if curStage <= 1 then
            return
        end
        curStage = curStage - 1
        fillOptionGrid(self)
    end)
    self:subscribe(self.nextBtn, UIEvent.EventButtonClick, function()
        if curStage >= #chapterInfo.chapterCfg.stages then
            return
        end
        curStage = curStage + 1
        fillOptionGrid(self)
    end)

    self:subscribe(self.fightBtn, UIEvent.EventButtonClick, function()
        Stage.RequestStartStage(Me, chapterInfo.fullName, chapterInfo.chapterId, curStage)
    end)

    self:subscribe(self.receiveBtn, UIEvent.EventButtonClick, function()
        local chapterId = chapterInfo.chapterId
        Stage.ReceivedChapterReward(Me, chapterInfo.fullName, chapterId, true, "win_general_options", function(success)
            if success then
                
            end
        end)
    end)

    Lib.subscribeEvent(Event.EVENT_CLOSE_RELATED_WND, function(packet)
        if not packet.show then
            UI:closeWnd("general_options")
        end
    end)
end

function M:setData(packet)
    local data = packet.data
    item = data.item
    minStage = item.min
    chapterInfo = data.chapterInfo
    chapterInfo.chapterCfg = Stage.GetStageCfg(item.fullName, item.chapterId)
    curStage = 1
    local passedStages = chapterInfo.passedStages
    local enableStages = chapterInfo.enableStages
    if #enableStages > #passedStages then
        for _, stage in ipairs(chapterInfo.enableStages) do
            curStage = stage > curStage and stage or curStage
        end
    end
    fillOptionGrid(self)
end

return M