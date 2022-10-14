local TargetsClientOper = T(Player, "Targets")
local TargetBase = T(TargetsClientOper, "Base")

function TargetBase:add()
end

function TargetBase:remove()
end

local function CreateTargetClass(typ)
    local tb = TargetsClientOper[typ]
    if not tb then
        tb = {}
        TargetsClientOper[typ] = tb
    end
    for k, v in pairs(TargetBase) do
        tb[k] = v
    end
    return tb
end

local TargetKillNpc = CreateTargetClass("KillNpc")
function TargetKillNpc:add(tar, targets)
    --todo targets客户端相关操作（添加）
    local entitys = targets or World.CurWorld:getAllEntity()
    local targetBuff = tar.targetBuff
    if not targetBuff or type(targetBuff) ~= "string" then
        return
    end
    for _, entity in pairs(entitys) do
        local cfgName = tar.cfgName
        local isHas = entity:getTypeBuff("fullName", targetBuff)
        if not isHas and (not cfgName or entity:cfg().fullName == cfgName) then
            entity:addClientBuff(targetBuff)
        end
    end
end

function TargetKillNpc:remove(tar, targets)
    --todo targets客户端相关操作（移除）
    local entitys = targets or World.CurWorld:getAllEntity()
    local targetBuff = tar.targetBuff
    if not targetBuff or type(targetBuff) ~= "string" then
        return
    end
    for _, entity in pairs(entitys) do
        local cfgName = tar.cfgName
        if not cfgName or entity:cfg().fullName == cfgName then
            entity:removeClientTypeBuff("fullName", targetBuff)
        end
    end
end

local TargetInteraction = CreateTargetClass("Interaction")
function TargetInteraction:add(tar, targets)
	local targetBuff = tar.targetBuff
    local entitys = targetBuff and targets or World.CurWorld:getAllEntity()
    for _, entity in pairs(entitys or {}) do
        local cfgName = tar.cfgName
        local isHas = entity:getTypeBuff("fullName", targetBuff)
        if not isHas and entity:cfg().fullName == cfgName then
            entity:addClientBuff(targetBuff)
        end
    end
end

function TargetInteraction:remove(tar, targets)
	local targetBuff = tar.targetBuff
    local entitys = targetBuff and targets or World.CurWorld:getAllEntity()
    for _, entity in pairs(entitys or {}) do
        local cfgName = tar.cfgName
        if entity:cfg().fullName == cfgName then
            entity:removeClientTypeBuff("fullName", targetBuff)
        end
    end
end

function Player:getTaskList(func)
    local packet = {
        pid = "TaskList"
    }
    self:sendPacket(packet, func)
end

function Player:startTask(name, func)
    local packet = {
        pid = "StartTask",
        name = name
    }
    self:sendPacket(packet, func)
end

function Player:finishTask(name, func)
    local packet = {
        pid = "FinishTask",
        name = name
    }
    self:sendPacket(packet, func)
end

function Player:abortTask(name)
    local packet = {
        pid = "AbortTask",
        name = name
    }
    self:sendPacket(packet)
end

function Player:updateClientTask(packet)
    self:checkTraceTask(packet)
    self:updateTaskHint()
    self:updateTaskTargetSign(packet)
end

function Player:updateTaskHint()
    local taskData = self:data("task")
    local hint = false
    for n, t in pairs(taskData) do
        if t.hint then
            hint = true
        end
    end
    Lib.emitEvent(Event.TASK_STATUS_CHANGE, hint)
end

function Player:checkTaskFinish(name, targets)
    local taskData = self:data("task")[name]
    if targets and Player.CheckTaskHint(name, targets) and taskData and taskData.status == 1 then
        local task = Player.GetTask(name)
        if task.finishHint ~= false then
            Lib.emitEvent(Event.TASK_FINISH_HINT, name)
        end
        self:checkAutoComplete(name)
    end
end

function Player:checkTraceTask(params)
    if params.status == 0 or params.status == 3 then
        Lib.emitEvent(Event.EVENT_ADD_TASK_TRACE)
    else
        Lib.emitEvent(Event.EVENT_UPDATE_TASK_TRACE, params.name, params.status)
    end
end

function Player:addTraceTask(name)
    local task = Player.GetTask(name)
    if task.trace and task.trace.pos then
        local traceTask = self:data("traceTask")
        table.insert(traceTask, 1, name)
        self:updateTraceTask()
    end
    if task.traceUI then
        Lib.emitEvent(Event.EVENT_ADD_TASK_TRACE, name)
    end
end

function Player:removeTaskTrace()
    local traceTask = self:data("traceTask")
    table.remove(traceTask, 1)
    self:updateTraceTask()
end

function Player:updateTraceTask()
    local map = self.map.name
    local traceTaskTimer = self:data("traceTaskTimer")
    local fullName = self:data("traceTask")[1]
    if traceTaskTimer.timer then
        traceTaskTimer.timer()
    end
    self:setGuidePosition(nil)
    if not fullName then
        return
    end
    local task = Player.GetTask(fullName)
    local trace = task.trace or {}
    if type(trace.map) == "string" and trace.map == map then
        return
    end
    self:setGuidePosition(trace.pos)
    traceTaskTimer.timer = self:timer(20, function()
        if Lib.getPosDistance(self:getPosition(), trace.pos) < (trace.range or 3) then
            self:removeTaskTrace()
            return false
        end
        return true
    end)
end

function Player:updateTaskTargetSign(params)
    local targetSign = self:data("taskTargetsSign")
    local task = Player.GetTask(params.name)
    local targets = task.targets
    targetSign[params.name] = params
    for _, tar in pairs(targets) do
        local tt = TargetsClientOper[tar.type] or TargetBase
        if params.status == 1 then
            if targetSign[params.name] then
                tt.add(self, tar)
            end
        else
            tt.remove(self, tar)
        end
    end
end

function Player:updateEntityTaskSign(entity)
    local targetSign = self:data("taskTargetsSign")
    for _, param in pairs(targetSign) do
        local task = Player.GetTask(param.name)
        local targets = task.targets
        for _, tar in pairs(targets) do
            local tt = TargetsClientOper[tar.type] or TargetBase
            if param.status == 1 then
                tt.add(self, tar, { entity })
            else
                tt.remove(self, tar, { entity })
            end
        end
    end
end

function Player:checkAutoComplete(name)
    local task = Player.GetTask(name)
    if task.autoComplete then
        self:finishTask(name, function(ret)
            if not ret.ok then
                Lib.emitEvent(Event.EVENT_CENTER_TIPS, 40, nil, nil, ret.msg)
            end
        end)
    end
end