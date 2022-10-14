
local callBackModName
local regId
local item
local events

function M:init()
    WinBase.init(self, "ChallengeTimes.json", true)
    self.challengeCt = self:child("ChallengeT-Challenge-Content")
    self.challengeBtn = self:child("ChallengeT-Challenge")
    self.addBtn = self:child("ChallengeT-Add-Btn")
    self.curTimes = self:child("ChallengeT-Cur-Time")
    self.btnTitle = self:child("ChallengeT-Challenge-Title")
    self.btnTitle:SetText(Lang:toText("challenge.btn.title"))
    self.challengeTip = self:child("ChallengeT-Challenge-Tip")
    self.cost = self:child("ChallengeT-Times")

    self:subscribe(self.addBtn, UIEvent.EventButtonClick, function()
        Me:doCallBack(callBackModName, events[1], regId, {item = item})
    end)
    self:subscribe(self.challengeBtn, UIEvent.EventButtonClick, function()
        Me:doCallBack(callBackModName, events[2], regId, {item = item})
    end)
end

function M:setData(packet)
    regId = packet.regId
    callBackModName = packet.callBackModName
    events = packet.events
    local data = packet.data
    local timesLeft = data.timesLeft
    item = data.item
    local fullName, chapterId, stage = item.fullName, item.chapterId, item.stage
    local cfg = Stage.GetStageCfg(fullName)
    local stageCfg = Stage.GetStageCfg(fullName, chapterId, stage)
    self.curTimes:SetText(timesLeft .. "/" .. cfg.maxTimes)
    self.cost:SetText("x" .. stageCfg.cost)
    self.challengeTip:SetText(Lang:toText(cfg.recoverTip or ""))
end

return M