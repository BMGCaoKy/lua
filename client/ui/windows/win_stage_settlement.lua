local fullName
local chapterId
local stage
local nextStage

function M:init()
    WinBase.init(self, "StageSettlement.json", true)
    self.stageNum_geWei = self:child("Stage-StageNum-Ge")
    self.stageNum_shiWei = self:child("Stage-StageNum-Shi")
    self.levelScoreLb = self:child("Stage-LevelScore")
    self.scoreLb = self:child("Stage-Score")
    self.totalScoreLb = self:child("Stage-TotalScore")
    self.levelTimeLb = self:child("Stage-LevelTime")
    self.totalTimeLb = self:child("Stage-TotalTime")
    self.hourLb = self:child("Stage-Hours")
    self.minuteLb = self:child("Stage-Minutes")
    self.secondLb = self:child("Stage-Seconds")
    self.exitLb = self:child("Stage-Exit-Text")
    self.replayLb = self:child("Stage-Replay-Text")
    self.nextLb = self:child("Stage-Next-Text")
    self.exitBtn = self:child("Stage-Exit")
    self.replayBtn = self:child("Stage-Replay")
    self.nextBtn = self:child("Stage-Next")

    --??????
    self:subscribe(self.exitBtn, UIEvent.EventButtonClick, function()
        Stage.RequestExitStage(Me)
        UI:closeWnd(self)
    end)
    self:subscribe(self.replayBtn, UIEvent.EventButtonClick, function()
        Stage.RequestStartStage(Me, fullName, chapterId, stage)
        UI:closeWnd(self)
    end)
    self:subscribe(self.nextBtn, UIEvent.EventButtonClick, function()
        Stage.RequestStartStage(Me, fullName, nextStage.chapterId, nextStage.stage)
        UI:closeWnd(self)
    end)
end

local function formatString(num)
    return string.format("%02d", num)
end

function M:onOpen(packet)
    fullName = packet.fullName
    chapterId = packet.chapterId
    stage = packet.stage
    nextStage = packet.nextStage
    local shiWei = math.modf(stage/10)
    local geWei = stage%10
    local stageTime = math.modf(packet.time/20)
    local totalTime = math.modf(packet.totalTime/20)
    local hours = formatString(math.modf(stageTime/3600))
    local minutes = formatString(math.modf((stageTime%3600)/60))
    local seconds = formatString(stageTime%60)
    local t_hours = formatString(math.modf(totalTime/3600))
    local t_minutes = formatString(math.modf((totalTime%3600)/60))
    local t_seconds = formatString(totalTime%60)
    local totalTime = t_hours .. ": " .. t_minutes .. ": " .. t_seconds
    local shi_imgName = "set:map_jie_suan.json image:" .. shiWei .. ".png"
    local ge_imgName = "set:map_jie_suan.json image:" .. geWei .. ".png"
    self.stageNum_shiWei:SetImage(shi_imgName)
    self.stageNum_geWei:SetImage(ge_imgName)
    self.stageNum_shiWei:SetVisible(shiWei ~= 0)
    self.stageNum_geWei:SetXPosition(shiWei ~= 0 and {0, 18} or {0, 0})
    self.levelScoreLb:SetText(Lang:toText({"stage_level_score"}))
    self.scoreLb:SetText(packet.score)
    self.totalScoreLb:SetText(Lang:toText({"stage_total_score", packet.totalScore}))
    self.levelTimeLb:SetText(Lang:toText({"stage_level_time"}))
    self.hourLb:SetText(hours)
    self.minuteLb:SetText(minutes)
    self.secondLb:SetText(seconds)
    self.totalTimeLb:SetText(Lang:toText({"stage_total_time", totalTime}))
    self.exitLb:SetText(Lang:toText({"stage_exit"}))
    self.replayLb:SetText(Lang:toText({"stage_replay"}))
    self.nextLb:SetText(Lang:toText({"stage_next"}))
    self.nextBtn:SetVisible(packet.nextStage and true or false)
end

return M