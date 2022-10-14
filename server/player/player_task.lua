
function Player:isTaskFinished(task)
	local finishData = self:data("taskFinish")[task.group.fullName]
	if not finishData then
		return false
	end
	return finishData[task.key] ~= nil
end

function Player:checkTaskCondition(task)
	if task.needLevel and self:getValue("level") < task.needLevel then
		return false, {"task.needlevel", task.needLevel}
	end
	if task.needTask then
		local task = Player.GetTask(task.needTask, task.group)
		if not self:isTaskFinished(task) then
			return false, {"task.needTask", task.fullName}
		end
	end
	return true
end

function Player:getTaskData(task)
	local td = self:data("task")[task.fullName]
	local finishData = self:data("taskFinish")[task.group.fullName] or {}
	if not td and not self:checkTaskCondition(task) then
		return nil
	end
	local data = {
		name = task.fullName,
		show = task.show,
		status = task.status,
	}
	if finishData[task.key] then
		data.show = true
		data.status = 3
		return data
	end
	if td then
		data.targets = {}
		for index, tar in ipairs(td.targets) do
			data.targets[index] = tar.process
		end
		local canFinish = self.CheckTaskHint(task.fullName, data.targets)
		data.show = td.show
		data.status = canFinish and 2 or td.status
	end
	if data.status == 1 then
		self:startTask(task.fullName)
	end
	return data
end

function Player:getGroupTask(group)
	local cfg = assert(Player.Tasks[group], group)
	if cfg.sequenced then	-- 线性任务
		for _, task in ipairs(cfg.tasks) do
			return {self:getTaskData(task)}
		end
		return {}
	end
	-- 并行任务
	local list = {}
	for _, task in ipairs(cfg.tasks) do
		list[#list+1] = self:getTaskData(task)
	end
	return list
end

function Player:getTaskList()
	local list = {}
	for _, cfg in pairs(Player.Tasks) do
		if cfg.showOrder then
			list[#list+1] = {
				name = cfg.fullName,
				tasks = self:getGroupTask(cfg.fullName),
			}
		end
	end
	table.sort(list, function (a,b)
			return Player.Tasks[a.name].showOrder > Player.Tasks[b.name].showOrder
		end)
	return list
end

function Player:startTask(fullName)
	local task = assert(Player.TaskMap[fullName], fullName)
	if task.times~="loop" and self:isTaskFinished(task) then
		return false, "task.alreadyfinished"
	end
	local targetData = self:data("task")
	if targetData[fullName] then
		return false, "task.alreadystarted"
	end
	local ok, msg = self:checkTaskCondition(task)
	if not ok then
		return false, msg
	end
	if task.group.sequenced and task.index>1 then
		local lastTask = task.group.tasks[task.index-1]
		if not self:isTaskFinished(lastTask) then
			return false, {"task.needTask", lastTask.fullName}
		end
	end
	local td = {
		task = task,
		status = 1,
		show = true,
		targets = {},
	}
	targetData[fullName] = td
	for index, tt in ipairs(task.targets) do
		td.targets[index] = self:initTarget(tt)
	end
	for _, cfg in pairs(task.buffs or {}) do
		self:addBuff(cfg.path, cfg.time)
	end
	Trigger.CheckTriggersOnly(self:cfg(), "START_TASK", {obj1 = self, name = fullName})
	self:syncTask(task)
	self:bhvLog("task_start", string.format("%s start task %s", self.name, fullName), fullName)
	return true
end

function Player:checkTaskStatus(fullName)
	local task = assert(Player.TaskMap[fullName], fullName)
	local finishData = T(self:data("taskFinish"), task.group.fullName)
	local key = task.key
	local times = task.times
	local today = tonumber(Lib.getYearDayStr(os.time()))
	local toWeek = tonumber(Lib.getYearWeekStr(os.time()))
	if not finishData[key] then
		return
	end
	if times == "once" then
		return
	elseif times == "loop" then
		finishData[key] = nil
	elseif times == "daily" and tonumber(finishData[key]) ~= today then
		finishData[key] = nil
	elseif times == "weekly" and tonumber(finishData[key]) ~= toWeek then
		finishData[key] = nil
	end
end

function Player:finishTask(fullName)
	local taskData = self:data("task")
	local td = taskData[fullName]
	if not td then
		return false, "task.notstarted"
	end
	for _, tar in ipairs(td.targets) do
		if tar.index then
			return false, "task.notfinished"
		end
	end
	local related = {}	-- 行为日志关联标记
	local args = {
		reward = td.task.reward,
		cfg = td.task.group,
		related = related,
		check = true
	}
	if not self:reward(args) then
		return false, "task.clean.backpack"
	end
	taskData[fullName] = nil
	local finishData = T(self:data("taskFinish"), td.task.group.fullName)
	finishData[td.task.key] = tonumber(td.task.times == "weekly" and Lib.getYearWeekStr(os.time()) or Lib.getYearDayStr(os.time()))
	for _, cfg in pairs(td.task.buffs or {}) do
		self:removeTypeBuff("fullName", cfg.path)
	end
	Trigger.CheckTriggersOnly(self:cfg(), "FINISH_TASK", {obj1 = self, name = fullName})
	self:bhvLog("task_finish", string.format("%s finish task %s", self.name, fullName), fullName, related)
	args.check = false
	self:reward(args)
	self:checkTaskStatus(fullName)
	self:syncTask(td.task)
	return true
end

function Player:abortTask(fullName)
	local taskData = self:data("task")
	local td = taskData[fullName]
	if not td then
		return
	end
    taskData[fullName] = nil
	for _, cfg in pairs(td.task.buffs or {}) do
		self:removeTypeBuff("fullName", cfg.path)
	end
    Trigger.CheckTriggersOnly(self:cfg(), "ABORT_TASK", {obj1 = self, name = fullName})
    self:bhvLog("task_abort", string.format("%s abort task %s", self.name, fullName), fullName, {})
	self:syncTask(td.task)
end

function Player:syncTask(task)
	local packet = self:getTaskData(task)
	packet.pid = "SyncTask"
	self:sendPacket(packet)
end
