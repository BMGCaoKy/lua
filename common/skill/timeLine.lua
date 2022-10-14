local SkillBase = Skill.GetType("Base")
local SkillTimeLine = Skill.GetType("TimeLine")
SkillTimeLine.targetType = "None"
local handleTarget = L("handleTarget", {})
local behavior = {}
SkillTimeLine.behavior = behavior
SkillTimeLine.handleTarget = handleTarget

local function getPresetsDuration(self)
    self.timerLine = self.timerLine or {}
    local len = #self.timerLine
    return self.timerLine[len] and self.timerLine[len].time or 0
end

local function hasPos(self, time)
    for _, line in pairs(self.timerLine or {}) do
        if line.time > time and line.behavior == "Pos" then
            return line
        end
    end
end

local function  hasRotate(self, time)
    for _, line in pairs(self.timerLine or {}) do
        if line.time > time and line.behavior == "Rotate" then
            return line
        end
    end
end

local function checkActionPoint(self, time)
    for _, line in pairs(self.timerLine) do
        if line.time == time then
            return line
        end
    end
end

local function getNextDisposeInterval(self, time)
    for _, line in pairs(self.timerLine) do
        if line.time > time then
            return line.time - time
        end
    end
    return 0
end

local function dispose(self, packet, from)
    local timerLineData = from:data("skill").timerLineData
    if not timerLineData.timer then 
        return false
    end
    
    local line = checkActionPoint(self, timerLineData.time)
    if line then
        local func = assert(behavior[line.behavior], line.behavior)
        func(self, packet, from, line)
    end

    local linePos = hasPos(self, timerLineData.time)
    if linePos and linePos ~= line then
        behavior.Pos(self, packet, from, linePos)
        packet.linePos = nil
    end

    local lineRotate = hasRotate(self, timerLineData.time)
    if lineRotate and lineRotate ~= line then
        behavior.Rotate(self, packet, from, lineRotate)
        packet.lineRotate = nil
    end

    local bEnd = false
    local time = getPresetsDuration(self)
    local interval = getNextDisposeInterval(self, timerLineData.time)
    if timerLineData.time >= time then
        if self.repeatTimes then 
            timerLineData.repeatTimes = timerLineData.repeatTimes + 1
            if self.repeatTimes > 0 and timerLineData.repeatTimes >= self.repeatTimes then 
                bEnd = true
            else
                packet.linePos = hasPos(self, 0)
                packet.lastLinePos = nil
                packet.lineRotate = hasRotate(self, 0)
                packet.lastLineRotate = nil
                timerLineData.time = 0
                interval = getNextDisposeInterval(self, timerLineData.time)
            end
        else
            bEnd = true
        end
    elseif interval <= 0 then 
        bEnd = true
    end
    if bEnd or (self.curHp and self.curHp <= 0) then 
        timerLineData.timer = nil
        timerLineData.time = 0
        timerLineData.repeatTimes = 0
        self:endRun(packet, from)
        return false
    end
    timerLineData.time = timerLineData.time + timerLineData.timer(interval)
    return true
end

function behavior:Pos(packet, from, vals)
    local timerLineData = from:data("skill").timerLineData
    if not packet.linePos then
        packet.linePos = hasPos(self, timerLineData.time)
        return
    end
    local func = assert(handleTarget[vals.targetType or self.targetType], vals.targetType or self.targetType)
    func(self, packet, from)
    --todo
end

function behavior:Rotate(packet, from, vals)
end

function behavior:Skill(packet, from, vals)
end

function behavior:None(packet, from, vals)
end

function SkillTimeLine:run(packet, from)
    local timerLineData = from:data("skill").timerLineData or {}
    local linePos = hasPos(self, timerLineData.time or 0)
    if linePos then
        packet.linePos = linePos
    end
    local lineRotate = hasRotate(self, timerLineData.time or 0)
    if lineRotate then
        packet.lineRotate = lineRotate
    end
    if packet.linePosValue then
        linePos = linePos or {}
        linePos.value = packet.linePosValue
    end
    from:data("skill").timerLineData = timerLineData
    timerLineData.time = 1
    timerLineData.repeatTimes = 0
    timerLineData.timer = from:timer(1, dispose, self, packet, from)
end

function SkillTimeLine:endRun(packet, from)
end

function SkillTimeLine:canCast(packet, from)
    if not SkillBase.canCast(self, packet, from) then
        return false
    end
    local timerLineData = from:data("skill").timerLineData
    if timerLineData and timerLineData.timer then
        return false
    end
    if not self.timerLine or not next(self.timerLine) then
        return false
    end
    return true
end

function SkillTimeLine:cast(packet, from)
    self:run(packet, from)
    SkillBase.cast(self, packet, from)
end