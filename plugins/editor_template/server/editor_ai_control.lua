local ai_control_mgr = require("entity.ai.ai_control_mgr")
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
local AIStateEmergency = require("editor_ai_state_emergency")
local AIStateLook = require("editor_ai_state_look")


local function newAIState(self, stateClass)
	local state = Lib.derive(stateClass)
	state:init(self)
	return state
end

function AIEvaluator.shouldEmergency(control)
	local entity = control:getEntity()
	local needEmergency = control:aiData("needEmergency")
	return needEmergency and true or false
end

function AIEvaluator.shouldLook(control)
	local entity = control:getEntity()
	local lookPlayerTime = control:aiData("lookPlayerTime")
	if not lookPlayerTime or lookPlayerTime < World.Now() then
		local playerID = control:getNearPlayer(100)
		if playerID ~= -1 then
			control:setAiData("lookID", playerID)
			return true
		end
	end
	return false
end

function AIControl:start()
	local entity = self:getEntity()
	self:loadDataByCfg()
	local config = entity:cfg()
	self.maxVisualDis = config.chaseDistance or 1
	self.visualAngle = config.maxVisualAngle or 90
	self.nextChaseInterval = config.nextChaseInterval or 40
	self.skillMinAttackDis = 999
	local aiData = entity:data("aiData")
	local machine = aiData.stateMachine
	local stand = aiData.stand
	if machine then
		machine:close()
	end
	if aiData.enableStateMachine == false then
		return
	end
	machine = AIStateMachine.create(self)
	self:setAiData("stateMachine", machine)

	local stateLook,stateAttack, stateChase, stateGoHome, stateIdle, stateMoveTo, stateRandMove,stateFixedRoute, stateFollowEntity, stateEmergency

	if self:getHomeSize() then
		self:setAiData("homePos", entity:getPosition())
		stateGoHome = newAIState(self, AIStateGoHome)
	end
	if config.skills or config.skillList and config.damage ~= 0 then
		stateAttack = newAIState(self, AIStateAttack)
	end
	if config.chaseDistance and config.damage ~= 0 then
		stateChase = newAIState(self, AIStateChase)
	end
	if config.damage == 0 then
		stateEmergency = newAIState(self, AIStateEmergency)
		stateLook = newAIState(self, AIStateLook)
		self:getEntity():cfg().idleProb = 0.7
	end

	if config.patrolDistance and not stand then
		stateRandMove = newAIState(self, AIStateRandMove)
	end
	if config.followEntityDistanceWhenHasTarget or config.followEntityDistanceWhenNotTarget then
		local target = self:getFollowTarget()
		if not target then
			self:setFollowTarget(entity:owner())
		end
		stateFollowEntity = newAIState(self, AIStateFollowEntity)
	end
	if aiData.route and #aiData.route >= 2 then
		stateFixedRoute	= newAIState(self, AIStateFixedRoute)
	end
	if stateChase or stateRandMove or stateGoHome then
		stateMoveTo = newAIState(self, AIStateMoveTo)
	end
	stateIdle = newAIState(self, AIStateIdle)
	local list = {
			stateIdle, 
			stateRandMove, 
			stateFixedRoute,
			stateMoveTo, 
			stateChase, 
			stateAttack, 
			stateGoHome, 
			stateFollowEntity,
			stateEmergency,
			stateLook,
		}
	for _, state in pairs(list) do
		machine:addState(state)
		machine:addTransition(state, stateLook, AIEvaluator.shouldLook)
		machine:addTransition(state, stateEmergency, AIEvaluator.shouldEmergency)
		machine:addTransition(state, stateFollowEntity, AIEvaluator.ShouldFollowEntity)
		machine:addTransition(state, stateGoHome, AIEvaluator.ShouldGoHome)
		machine:addTransition(state, stateAttack, AIEvaluator.CanAttackEnemy)
		machine:addTransition(state, stateChase, AIEvaluator.HasEnemy)
		machine:addTransition(state, stateFixedRoute, AIEvaluator.canMoveRoute)
		machine:addTransition(state, stateMoveTo, AIEvaluator.HasTargetPos)
		machine:addTransition(state, stateRandMove, function(control)
			return math.random() >= (control:getEntity():cfg().idleProb or 0.5)
		end)
		machine:addTransition(state, stateIdle, AIEvaluator.True)
	end

	if config.meetCollisionBackRun then
		local yaw = assert(entity:data("aiData").StartRunYaw or 0, "not the yaw")
		local pos = entity:getPosition()
		local value = -1 * yaw * 3.14159 / 180
		local c = math.cos(value);
		local s = math.sin(value);
		local forwardDir = Lib.v3(s, 0, c) * 100
		self:setTargetPos(pos + forwardDir, true)
	end
	machine:setState(stateIdle)
end

