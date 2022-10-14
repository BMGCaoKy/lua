local fullName
local chapterId
local stage
local nextStage

local function createScoreImage(self, score)
    if self.content then
        GUIWindowManager.instance:DestroyGUIWindow(self.content)
    end

    local sw = 48
    local sh = 74
    local scoreStr = tostring(score)

    local content = GUIWindowManager.instance:CreateGUIWindow1("Layout", "Score-Conten")
    content:SetVerticalAlignment(1)
    content:SetHorizontalAlignment(1)
    self.scoreBg:AddChildWindow(content)
    self.content = content

    local offset = 0
    local width = 0
    for i = 1, #scoreStr do
        local image = GUIWindowManager.instance:CreateGUIWindow1("StaticImage", "Score-Image-" .. i)
        image:SetHorizontalAlignment(0)
        content:AddChildWindow(image)
        local num = string.sub(scoreStr, i, i)
        image:SetImage("set:plumber_pass.json image:" .. num .. ".png")
        image:SetArea({0, offset}, {0, 0}, {0, sw}, {0, sh})
        offset = offset + sw
        width = width + sw
    end
    content:SetArea({0, 0}, {0, 0}, {0, width}, {0, sh})
end

function M:init()
    WinBase.init(self, "PlumberSettlement.json", true)
    self.starsImg = self:child("Stage-Stars")
    self.stageLb = self:child("Stage-Level")
    self.scoreBg = self:child("Stage-ScoreBg")
    self.passedLb = self:child("Stage-Passed")
    self.hightestScoreLb = self:child("Stage-HightestScore")
    self.optionsBtn = self:child("Stage-Options")
    self.replayBtn = self:child("Stage-Replay")
    self.nextStageBtn = self:child("Stage-Next")
    self.exitBtn = self:child("Stage-Exit")
    self.exitBtn2 = self:child("Stage-Edit-Back")
    self.isBackEdit = not not self.exitBtn2
    local exitBtn2Text = self.isBackEdit and Lang:toText("back.editor") or Lang:toText("game_exit")
    self.exitBtn2 = self.exitBtn2 or self:child("Stage-Exit2")
    self.starsImg = {self:child("Stage-Star_Left"), self:child("Stage-Star_Middle"), self:child("Stage-Star_Right")}

    self.passedLb:SetText(Lang:toText("stage_passed"))
    self.optionsBtn:SetText(Lang:toText("stage_options"))
    self.replayBtn:SetText(Lang:toText("stage_replay"))
    self.nextStageBtn:SetText(Lang:toText("stage_next_stage"))
    self.exitBtn2:SetText(exitBtn2Text)

    self:subscribe(self.optionsBtn, UIEvent.EventButtonClick, function()
        Stage.LoadEnableChapters(Me, fullName, "win_stage")
    end)
    self:subscribe(self.replayBtn, UIEvent.EventButtonClick, function()
        Stage.RequestStartStage(Me, fullName, chapterId, stage)
        UI:closeWnd(self)
    end)
    self:subscribe(self.nextStageBtn, UIEvent.EventButtonClick, function()
        Stage.RequestStartStage(Me, fullName, nextStage.chapterId, nextStage.stage)
        UI:closeWnd(self)
    end)
    self:subscribe(self.exitBtn, UIEvent.EventButtonClick, function()
        Stage.RequestExitStage(Me)
    end)
    self:subscribe(self.exitBtn2, UIEvent.EventButtonClick, function()
        --for editor
        if self.isBackEdit then
            local gameRootPath = CGame.Instance():getGameRootDir()
            World.Timer(5, function()
                CGame.instance:restartGame(gameRootPath, CGame.instance:getMapName(), 1, true)
                return false
            end)
        else
       --for game
            Stage.RequestExitStage(Me)
        end
    end)
    Lib.subscribeEvent(Event.EVENT_CLOSE_RELATED_WND, function()
        UI:closeWnd(self)
    end)
end

function M:onOpen(packet)
    fullName = packet.fullName
    chapterId = packet.chapterId
    stage = packet.stage
    nextStage = packet.nextStage
    local historyScore = packet.historyScore or 0
    local cfg = Stage.GetStageCfg(fullName)
    local hideOptionBtn = cfg.hideOptionBtn
    local showExitBtnAtLastStage = cfg.showExitBtnAtLastStage
    self.hightestScoreLb:SetText(Lang:toText({"stage_hightest_score", historyScore > 0 and historyScore or packet.score}))
    self.stageLb:SetText(Lang:toText({"stage_level", packet.stageName}))
    self.nextStageBtn:SetVisible(nextStage and true or false)
    self.exitBtn2:SetVisible(showExitBtnAtLastStage and not nextStage)
    createScoreImage(self, packet.score)
    for k, v in ipairs(self.starsImg) do
        v:SetImage("set:plumber_pass.json image:star_gray.png")
        if packet.stars and packet.stars[k] then
            v:SetImage("set:plumber_pass.json image:star_yellow.png")
        end
    end
    if hideOptionBtn then
        self.optionsBtn:SetVisible(false)
        self.replayBtn:SetXPosition({0, -90})
        self.nextStageBtn:SetHorizontalAlignment(1)
        self.nextStageBtn:SetXPosition({0, 90})
        self.exitBtn2:SetHorizontalAlignment(1)
        self.exitBtn2:SetXPosition({0, 90})
    end
end

return M