
local AIStateMachine = L("AIStateMachine", {})

local msgIndex = 1
local BASE_STATE_NAME = "IDLE"
local function autoGetIndex() msgIndex = msgIndex + 1 return msgIndex end
local MSG = {
	DEL_STATES = "DEL_STATES",
}

function AIStateMachine.create(control)
	local machine = {
		control = control,
		entity = control:getEntity(),
		states = {},
		transitions = {},
		curState = nil,
		updateTimer = nil,
		msgQueue = {},
		enterEvaluators = {},
		stateCount = 0,
	}
	return setmetatable(machine, {__index = AIStateMachine})
end

function AIStateMachine:addState(state)
	self.states[state.NAME] = state
	self.stateCount = self.stateCount + 1
	if self.stateCount == 1 then
		self:setState(state)
	end
end

function AIStateMachine:delState(stateName)
	if not self.states[stateName] then
		return
	end
	self.states[stateName] = nil
	self.stateCount = self.stateCount - 1
	self:addMsgQueue(MSG.DEL_STATES)
end

function AIStateMachine:getState(stateName)
	return self.states[stateName]
end

function AIStateMachine:hasState()
	return self.stateCount > 0
end

function AIStateMachine:getCurState()
	return self.curState
end

function AIStateMachine:getLastState()
	return self.lastState
end

function AIStateMachine:addTransition(from, to, evaluator, isInsertFont)
	if not from or not to or not evaluator then
		return 
	end
	local transitions = self.transitions
	local list = transitions[from.NAME]
	if not list then
		list = {}
		transitions[from.NAME] = list
	end
	self.enterEvaluators[to.NAME] = evaluator
	if isInsertFont then
		table.insert(list, 1, {name = to.NAME, evaluator = evaluator})
	else
		list[#list + 1] = {name = to.NAME, evaluator = evaluator}
	end
end

function AIStateMachine:simpleSetState(state)
	self.curState = state
end

function AIStateMachine:setIdleState()
	if not self.states[BASE_STATE_NAME] then
		Lib.logError(string.format("can not find idle state"))
	end
	self:simpleSetState(self.states[BASE_STATE_NAME])
end

function AIStateMachine:setState(state)
	if not state then
		return
	end	
	local curState = self.curState
	if curState and curState.NAME ~= state.NAME then
		Trigger.CheckTriggers(self.entity:cfg(), "LEAVE_AI_STATE", {obj1 = self.entity, state = curState.NAME})
		curState:exit()
	end
	if not curState or curState.NAME ~= state.NAME then
		Trigger.CheckTriggers(self.entity:cfg(), "ENTER_AI_STATE", {obj1 = self.entity, state = state.NAME})
	end
	state:enter()
	self.lastState = self.curState
	self.curState = state
	local timer = self.updateTimer
	if timer then
		timer()
	end
	self.updateTimer = self.entity:lightTimer(state.NAME, 1, self.update, self)
	--Lib.logDebug("AIStateMachine:setState", self.entity.objID, state.NAME)
end

function AIStateMachine:addMsgQueue(msgType)
	self.msgQueue[#self.msgQueue + 1] = msgType
end

-- 后面不使用timer驱动状态机，而是采用消息队列
function AIStateMachine:solveMsgQueue()
	local resultFlag = false
	local curState = self.curState
	local msgQueue = self.msgQueue

	local msgFuncs = {}
	function msgFuncs.DEL_STATES()
		local curStateName = curState and curState.NAME
		if curStateName and not self.states[curStateName] then
			self:simpleSetState(nil)
			resultFlag = true
		end
	end

	for i = #msgQueue, 1, -1 do
		local msg = msgQueue[i]
		msgQueue[i] = nil
		if msgFuncs[msg] then
			msgFuncs[msg]()
		else
			Lib.logWarning(string.format("msg[%s] is not vaild value", msg))
		end
	end
	return resultFlag
end

-- timer的做法实在太危险了
function AIStateMachine:update()
	if not self.entity.loadAIDataFinish then
		self.control:loadDataByCfg() -- 兼容所有的UGC老游戏(复制过ai_control出去的)
	end
	local entity = self.entity
	if not entity:isValid() or entity.curHp <= 0 then
		return
	end
	local objID, name = entity.objID, entity.name
	local curState = self.curState
	if self.control:isInForceGoHomeState() then
		self.updateTimer = entity:lightTimer(curState.NAME, entity.forceGoHomeTimeEnd - World.Now(), self.update, self)
		return
	end
	local ok, ret = xpcall(curState.update, traceback, curState)
	if not ok then
		print("AI state machine update error!", objID, name, curState.NAME, ret)
	end
	if not entity:isValid() then	-- entity may destroyed by cast skill kill self
		return
	end
	if self:solveMsgQueue() then
		self:doTransition()
		return
	end
	--print("AI update state", curState.NAME, self.entity.objID, ret)
	if ok and ret and ret > 0 then
		local timer = self.updateTimer
		if timer then
			timer()
		end
		self.updateTimer = entity:lightTimer(curState.NAME, ret, self.update, self)
		return
	end
	self:doTransition()
end

function AIStateMachine:doTransition()
	local nextState
	local states = self.states
	local control = self.control
	local curState = self.curState
	if not control:isActive() then
		self:simpleSetState(nil)
		return
	end

	if not curState then
		Lib.logWarning(string.format("please setState before doTransition!!!!, system auto set idle"))
		self:setIdleState()
		curState = self.curState
	end 

	for _, transition in ipairs(self.transitions[curState.NAME]) do
		local state = states[transition.name]
		Profiler:begin("ai evaluator ".. transition.name)
		--Lib.logWarning(string.format("try form [%s] to [%s]", curState.NAME, state.NAME))
		if state and transition.evaluator(control) then
			Profiler:finish("ai evaluator ".. transition.name)
			nextState = state
			break
		end
		Profiler:finish("ai evaluator ".. transition.name)
	end
	self:setState(nextState)
end

function AIStateMachine:onEvent(event, ...)
	local curState = self.curState
	return curState and curState:onEvent(event, ...)
end

function AIStateMachine:close()
	local curState = self.curState
	if curState then
		curState:exit()
		self.curState = nil
		self.lastState = nil
	end
	local timer = self.updateTimer
	if timer then
		timer()
		self.updateTimer = nil
	end
	local entityData = self.control:getEntity():data("aiData")
	entityData.stateMachine = nil
end

function AIStateMachine:delCompleteState(name)
	local transitions = self.transitions
	if name == BASE_STATE_NAME then
		Lib.logWarning(string.format("can not del base state name[%s]", BASE_STATE_NAME))
		return
	end
	if not transitions or not name then
		return
	end
	transitions[name] = nil
	for fromTransitionName, transition in pairs(transitions) do
		for index, ToTransitionItem in pairs(transition) do
			-- body
			if ToTransitionItem.name == name then
				table.remove(transitions[fromTransitionName], index)
			end
		end
	end
	self:delState(name)
end

function AIStateMachine:addCompleteState(newState, enterEvaluatorFunc)
	if not enterEvaluatorFunc then
		Lib.logError(string.format("state enterEvaluatorFunc must have the function"))
	end
	for name, state in pairs(self.states or {}) do
		self:addTransition(state, newState, enterEvaluatorFunc, true)
		Lib.logDebug(string.format("state[%s] to newstate[%s]", state.NAME, newState.NAME))
	end
	for name, state in pairs(self.states or {}) do
		self:addTransition(newState, state, self.enterEvaluators[state.NAME])
		Lib.logDebug(string.format("newstate[%s] to state[%s]", newState.NAME, state.NAME))
	end
	self:addState(newState)
	Lib.logDebug(string.format("newstate[%s] to newstate[%s]", newState.NAME, newState.NAME))
	self:addTransition(newState, newState, enterEvaluatorFunc, true)
end

function AIStateMachine:setStatePriority(name, priority)
	local transitions = self.transitions
	priority = priority < 1 and 1 or priority
	for _, preStateTransitions in pairs(transitions) do
		local targetIndex
		local item
		local transitionsCount = #preStateTransitions
		local priorityIndex = priority > transitionsCount and transitionsCount or priority
		for i = 1, transitionsCount do
			if preStateTransitions[i].name == name then
				targetIndex = i
				item = preStateTransitions[i]
				break
			end
		end
		if targetIndex then
			table.remove(preStateTransitions, targetIndex)
			table.insert(preStateTransitions, priorityIndex, item)
		end
	end
end

RETURN(AIStateMachine)
