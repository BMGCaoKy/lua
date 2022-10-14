local AIStateMachine = require("entity.ai.ai_state_machine")
local AIStateAttack = require("entity.ai.ai_state_attack")
local AIStateChase = require("entity.ai.ai_state_chase")
local AIStateGoHome = require("entity.ai.ai_state_gohome")
local AIStateIdle = require("entity.ai.ai_state_idle")
local AIStateMoveTo = require("entity.ai.ai_state_moveto")
local AIStateRandMove = require("entity.ai.ai_state_randmove")
local AIEvaluator = require("entity.ai.ai_evaluator")
local AIStateFixedRoute = require("entity.ai.ai_state_fixed_route")
local AIStateFollowEntity = require("entity.ai.ai_state_follow_entity")
local AIStateBase = require("entity.ai.ai_state_base")

local function newAIState(self, stateClass)
	local state = Lib.derive(stateClass)
	state:init(self)
	return state
end

local stateClassMap = {
	GOHOME = AIStateGoHome,
	IDLE = AIStateIdle,
	RANDMOVE = AIStateRandMove,
	MOVETO = AIStateMoveTo,
	AIStateFollowEntity = AIStateFollowEntity,
	FIXEDROUTE = AIStateFixedRoute,
	CHASE = AIStateChase,
	ATTACK = AIStateAttack,
}

local evaluatorProductInface = {} -- 生成默认参数
local ParamsProductInface = {} -- 返回默认评估函数

function evaluatorProductInface:GOHOME()
	return AIEvaluator.ShouldGoHome
end

function evaluatorProductInface.IDLE()
	return AIEvaluator.True
end

function evaluatorProductInface.RANDMOVE(control)
	return function ()
		local mrand = math.random
		return mrand() >= (control:aiData("idleProb") or 0.5)
	end
end

function evaluatorProductInface.MOVETO()
	return AIEvaluator.HasTargetPos
end

function evaluatorProductInface.AIStateFollowEntity()
	return AIEvaluator.ShouldFollowEntity
end

function evaluatorProductInface.FIXEDROUTE()
	return AIEvaluator.canMoveRoute
end

function evaluatorProductInface.CHASE()
	return AIEvaluator.HasEnemy
end

function evaluatorProductInface.ATTACK()
	return AIEvaluator.CanAttackEnemy
end

-----------------------目前只用状态机能开启的最少参数-----------------------------
function ParamsProductInface.GOHOME(control, entityCfg)
	local homePos = control:getEntity():getPosition()
	control:setAiData("homePos", homePos)
	control:setAiData("homeSize", entityCfg.homeSize or 10)
end

function ParamsProductInface.IDLE(control, entityCfg)
end

function ParamsProductInface.RANDMOVE(control, entityCfg)
	control:setAiData("patrolDistance", entityCfg.patrolDistance or 10)
end

function ParamsProductInface.MOVETO(control, entityCfg)
end

function ParamsProductInface.AIStateFollowEntity(control, entityCfg)
	control:setAiData("followEntityDistanceWhenHasTarget", entityCfg.followEntityDistanceWhenHasTarget or 5)
	control:setAiData("followEntityDistanceWhenNotTarget", entityCfg.followEntityDistanceWhenNotTarget or 2)
	control:setAiData("followAutoAdjustMotion", true)
	-- control:setAiData("chaseDistance", entityCfg.patrolDistance or 10)
end

function ParamsProductInface.FIXEDROUTE(control, entityCfg)
	local pos = control:getEntity():getPosition()
	local pos2 = {
		x = pos.x + 4,
		y = pos.y, 
		z = pos.z, 
	} 
	control:setAiData("route", {pos, pos2})
end

function ParamsProductInface.CHASE(control, entityCfg)
	control:setAiData("chaseDistance", entityCfg.chaseDistance or 10)
	control:setAiData("autoAttack", true)
end

function ParamsProductInface.ATTACK(control, entityCfg)
	control:setAiData("skillList", entityCfg.skillList or {})
end

-------------------------------------------------------
function AIControl:getSingleMachine()
	local stateMachine = self:getMachine()
	if not stateMachine then
		stateMachine = AIStateMachine.create(self)
		self:setAiData("stateMachine", stateMachine)
	end
	return stateMachine
end

function AIControl:delState(name)
	local stateMachine = self:getMachine()
	stateMachine:delCompleteState(name)
end

-- 用户自定义的name不能和系统的name冲突
function AIControl:addState(name, params, enterEvaluatorFunc)
	local function getStateBodyByName(name)
		local stateClass = stateClassMap[name]
		return stateClass
	end

	local stateMachine = self:getSingleMachine()
	if stateMachine:getState(name) then
		Lib.logWarning(string.format("state: [%s] already exist, can not add", name))
		return
	end

	local aiStateClass = getStateBodyByName(name)
	if not aiStateClass then
		Lib.logError(string.format("can not fid state[%s]", name))
		return
	end
	local state = newAIState(self, aiStateClass)
	name = state.NAME
	if not name then
		Lib.logError(string.format("state must have NAME"))
		return
	end
	
	local productParamsFunc = ParamsProductInface[name]
	if productParamsFunc then
		productParamsFunc(self, self:getEntity():cfg())
	end
	self:loadParams(params)
	local transitions = stateMachine.transitions
	local evaluatorFunc = evaluatorProductInface[name]
	evaluatorFunc = evaluatorFunc and evaluatorFunc(self) or nil
	stateMachine:addCompleteState(state, enterEvaluatorFunc or evaluatorFunc)
end

-- todo 状态转移选择
function AIControl:addCustomState(name, params, enterEvaluatorFunc)
	local stateMachine = self:getSingleMachine()
	if not stateMachine:getState("IDLE") then
		Lib.logDebug(string.format("state: [%s] auto add", "IDLE"))
		self:addState("IDLE")
		stateMachine:setState(stateMachine:getState("IDLE"))
	end
	self:addState(name, params, enterEvaluatorFunc)
end

-- todo添加蓝图状态机
function AIControl:addTrggerState()

end

-- 设置状态机优先级
function AIControl:setStatePriority(name, priority)
	local stateMachine = self:getSingleMachine()
	stateMachine:setStatePriority(name, priority)
end

local function init()
	local dirPath = "script_server.custom_ai"
	local loadPath =  Root.Instance():getGamePath() .. "lua/script_server/custom_ai"
	local ret = lfs.attributes(loadPath,"mode")
	if not ret or ret ~= "directory" then
		return
	end
	for file in lfs.dir(loadPath) do
		if file ~= "." and file ~= ".." then
			local f = loadPath .. '/' .. file
			local attr = lfs.attributes(f)
			local fileName = string.gsub(file, ".lua$", "")
			if attr.mode == "file" and file ~= fileName then
				local loadf = dirPath .. '.' .. fileName
				local state = require(loadf)
				local AIState = Lib.derive(AIStateBase, state)
				stateClassMap[fileName] = AIState
				stateClassMap[fileName].NAME = fileName
			end
		end
	end
end

function AIControl.addStateMachine(name, state)
	if type(state) ~= "table" then
		return
	end
	local AIState = Lib.derive(AIStateBase, state)
	stateClassMap[name] = AIState
	stateClassMap[name].NAME = name
end

init()