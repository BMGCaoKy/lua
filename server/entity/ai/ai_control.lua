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
local AIStateBehaviors = require("entity.ai.ai_state_behaviors")
local entity_camp = require "entity.entity_camp"
require("entity.ai.ai_state_control")

local traceback = traceback
local math = math
local mrand = math.random
local mmax = math.max
local mmin = math.min
local msin = math.sin
local mcos = math.cos
local PI = math.pi
local pairs = pairs
local ipairs = ipairs
local lossEnemyTime = 40

local function newAIState(self, stateClass)
	local state = Lib.derive(stateClass)
	state:init(self)
	return state
end

function AIControl:setAiData(key, value)
	local entity = self:getEntity()
	local aiData = entity:data("aiData")
	if key == "chaseDistance" then
		self.maxVisualDis = value
	end
	aiData[key] = value
end

function AIControl:aiData(key)
	local entity = self:getEntity()
	local aiData = entity:data("aiData")
	return aiData[key]
end

function AIControl:initAIData()
	-- local entity = self:getEntity()
	-- local aiData = entity:data("aiData")
end

function AIControl:loadDataByCfg()
	local entity = self:getEntity()
	local config = entity:cfg()
	self:initAIData()
	self:setAiData("bhvEnter", config.bhvEnter)
	self:setAiData("sightRange", config.sightRange or 1000)
	self:setAiData("followMinDisSqr", config.followOwnerDistance and config.followOwnerDistance * config.followOwnerDistance or 100)
	self:setAiData("followLegalDisSqr", config.followLegalDistance and config.followLegalDistance * config.followLegalDistance or 400)
	self:setAiData("followForceTpDisSqr", config.followForceTpDistance and config.followForceTpDistance * config.followForceTpDistance)
	self:setAiData("chaseDistance", config.chaseDistance)
	self:setAiData("chaseDisSqr", config.chaseDistance and config.chaseDistance * config.chaseDistance)
	self:setAiData("patrolDistance", config.patrolDistance)
	self:setAiData("maxVisualAngle", config.maxVisualAngle)
	self:setAiData("chaseNearTarget", config.chaseNearTarget)
	self:setAiData("nextChaseInterval", config.nextChaseInterval)
	self:setAiData("skills", config.skills)
	self:setAiData("skillList", config.skillList or config.skillInfoList)
	self:setAiData("followEntityDistanceWhenHasTarget", config.followEntityDistanceWhenHasTarget)
	self:setAiData("followEntityDistanceWhenNotTarget", config.followEntityDistanceWhenNotTarget)
	self:setAiData("followEntityMinDistanceWhenHasTarget", config.followEntityMinDistanceWhenHasTarget)
	self:setAiData("followEntityMinDistanceWhenNotTarget", config.followEntityMinDistanceWhenNotTarget)
	self:setAiData("idleProb", config.idleProb)
	self:setAiData("idleTime", config.idleTime)
	self:setAiData("idleAction", config.idleAction)
	self:setAiData("homeSize", config.homeSize)
	self:setAiData("isAIGoHomePos", config.isAIGoHomePos)
	self:setAiData("lossEnemyTime", config.lossEnemyTime)
	self:setAiData("chaseInterval", config.chaseInterval)
	self:setAiData("chaseSkill", config.chaseSkill)
	self:setAiData("autoAttack", config.autoAttack)
	self:setAiData("attackNpc", config.attackNpc)
	self:setAiData("hatredTransfer", config.hatredTransfer)
	self:setAiData("minAttackHate", config.minAttackHate)
	self:setAiData("hateWay", config.hateWay)
	self:setAiData("followEntityDistance", config.followEntityDistance)
	self:setAiData("avoidCliff", config.avoidCliff)
	self:setAiData("avoidCliffHight", config.avoidCliffHight)
	self:setAiData("meetCliffBackRun", config.meetCliffBackRun)
	self:setAiData("meetCollisionBackRun", config.meetCollisionBackRun)
	self:setAiData("meetCollisionEmptyRun", config.meetCollisionEmptyRun)
	self:setAiData("enableNavigate", config.enableNavigate)
	self:setAiData("enableMeshNavigate", config.enableMeshNavigate)
	self:setAiData("withoutYaw", config.withoutYaw)
	self:setAiData("aiArrivedTransition", config.aiArrivedTransition)
	self:setAiData("skillPriority", config.skillPriority)
	self:setAiData("forceGoHomeVariable", config.forceGoHomeVariable)
	self:setAiData("forceFixedRoute", config.forceFixedRoute)
	self:setAiData("disableAIStancePos",config.disableAIStancePos)
	entity.loadAIDataFinish = true
end

function AIControl:start()
	local entity = self:getEntity()
	self:loadDataByCfg()
	self.maxVisualDis = self:aiData("chaseDistance") or 1
	self.visualAngle = self:aiData("maxVisualAngle")  or 90
	self.chaseNearTarget = self:aiData("chaseNearTarget") or false
	self.nextChaseInterval = self:aiData("nextChaseInterval") or 40
	self.skillMinAttackDis = 999
	local machine = self:aiData("stateMachine")
	if machine then
		machine:close()
	end
	
	if self:aiData("enableStateMachine") == false then
		return
	end

	machine = AIStateMachine.create(self)
	self:setAiData("stateMachine", machine)

	local stateAttack, stateChase, stateGoHome, stateIdle, stateMoveTo, stateRandMove,stateFixedRoute, stateFollowEntity, stateBehaviors

	if self:getHomeSize() then
		self:setAiData("homePos", entity:getPosition())
		stateGoHome = newAIState(self, AIStateGoHome)
	end
	if self:aiData("skills") or self:aiData("skillList") then
		stateAttack = newAIState(self, AIStateAttack)
	end

	if self:aiData("chaseDistance") then
		stateChase = newAIState(self, AIStateChase)
	end
	
	if self:aiData("patrolDistance") then
		stateRandMove = newAIState(self, AIStateRandMove)
	end
	if self:aiData("followEntityDistanceWhenHasTarget") or self:aiData("followEntityDistanceWhenNotTarget") then
		local target = self:getFollowTarget()
		if not target then
			self:setFollowTarget(entity:owner())
		end
		stateFollowEntity = newAIState(self, AIStateFollowEntity)
	end
	if self:aiData("route") and #self:aiData("route") >= 2 then
		stateFixedRoute	= newAIState(self, AIStateFixedRoute)
	end
	local bhvTrigger = self:aiData("bhvEnter")
	if bhvTrigger then
		self:setAiData("bhvRunning", bhvTrigger)
		stateBehaviors = newAIState(self, AIStateBehaviors)
	end

	if stateChase or stateRandMove or stateGoHome then
		stateMoveTo = newAIState(self, AIStateMoveTo)
	end
	stateIdle = newAIState(self, AIStateIdle)
	local list = {
			stateIdle, 
			stateBehaviors,
			stateRandMove, 
			stateFixedRoute,
			stateMoveTo, 
			stateChase, 
			stateAttack, 
			stateGoHome, 
			stateFollowEntity,
		}
	for _, state in pairs(list) do
		machine:addState(state)
		machine:addTransition(state, stateBehaviors, AIEvaluator.ShouldDoBehaviors)
		machine:addTransition(state, stateFollowEntity, AIEvaluator.ShouldFollowEntity)
		machine:addTransition(state, stateGoHome, AIEvaluator.ShouldGoHome)
		machine:addTransition(state, stateAttack, AIEvaluator.CanAttackEnemy)
		machine:addTransition(state, stateChase, AIEvaluator.HasEnemy)
		machine:addTransition(state, stateFixedRoute, AIEvaluator.canMoveRoute)
		machine:addTransition(state, stateMoveTo, AIEvaluator.HasTargetPos)
		machine:addTransition(state, stateRandMove, function(control)
			return mrand() >= (self:aiData("idleProb") or 0.5)
		end)
		machine:addTransition(state, stateIdle, AIEvaluator.True)
	end

	if entity:cfg().meetCollisionBackRun then
		local yaw = assert(self:aiData("StartRunYaw") or 0, "not the yaw")
		local pos = entity:getPosition()
		local value = -1 * yaw * 3.14159 / 180
		local c = math.cos(value);
		local s = math.sin(value);
		local forwardDir = Lib.v3(s, 0, c) * 100
		self:setTargetPos(pos + forwardDir, true)
	end
	machine:setState(stateIdle)
end

function AIControl:getMachine()
	return self:aiData("stateMachine")
end

function AIControl:stop()
	self:setTargetPos(nil, false)
	local machine = self:getMachine()
	if machine then
		machine:close()
	end
	local entity = self:getEntity()
	if entity then
		entity.isMoving = false
	end
end

function AIControl:continue()
	if self.active then
		return
	end
	self.active = true
	local machine = self:getMachine()
	if machine then
		machine:doTransition()
	end
end

function AIControl:pause()
	if self:canPause() then
		self.active = false
	end
end

function AIControl:isActive()
	return self.active
end

function AIControl:setTargetPos(pos, enable)
	local entity = self:getEntity()
	if not entity or not entity:isValid() then
		return
	end
	if pos then
		self:face2Pos(pos)
		self.targetPos = pos
		if self:aiData("enableNavigate") then
			self:setNavigate2Pos(pos)
		end
	else
		enable = false
	end
	self.enableTargetPos = enable
	self.isMeshNavigation = self:aiData("enableMeshNavigate") and enable or false
	if not enable then
		entity.isMoving = enable
		entity:syncPosDelay()
	end
end

function AIControl:face2Pos(pos)
	local entity = self:getEntity()
	if self:aiData("withoutYaw") then
	else
		entity:face2Pos(pos)
	end
end

function AIControl:getTargetPos()
	return self.enableTargetPos and self.targetPos or nil
end

function AIControl:setChaseTarget(target)
	if target then
		self.chaseTarget = target.objID
	else
		self.chaseTarget = 0
	end	
end

function AIControl:markSightedEnemy(enemy)
	local entity = self:getEntity()
	local sightedEnemies = entity:data("sightedEnemies")
	sightedEnemies[enemy.objID] = World.Now()
end

function AIControl:canSeeEnemy(enemy)
	local entity = self:getEntity()
	local sightedEnemies = entity:data("sightedEnemies")
	local now = World.Now()
	local enemyID = enemy.objID
	local _lossEnemyTime = self:aiData("lossEnemyTime")
	if (sightedEnemies[enemyID] or 0) > now - (_lossEnemyTime or lossEnemyTime) then
		local chaseDis = self:getAIChaseDis() or 0
		return entity:distanceSqr(enemy) <= chaseDis * chaseDis
	end
	if not self:canSeeEntity(enemy) then
		sightedEnemies[enemyID] = nil
		return false
	end
	sightedEnemies[enemyID] = now
	return true
end

local AIEventHandler = {}
function AIEventHandler.onHurt(self, from, damage)
	local entity = self:getEntity()
	local enemyID = from.objID
    local owner = from:owner()
    if owner and self:aiData("hatredTransfer") then--hatredTransfer仇恨转移到主人身上
        self:addHatred(owner.objID, damage)
    else
        self:addHatred(enemyID, damage)
    end
	-- TODO
	self:markSightedEnemy(from)
	local target = self:getMaxHatredEntity()
	if target and target.objID == enemyID then
		self:face2Pos(from:getPosition())
	end
end

function AIEventHandler.arrived_target_pos(self)
	self:getEntity():onAIArrived()
	self:setTargetPos(nil)
	local cfg = self:getEntity():cfg()
	if self:aiData("aiArrivedTransition") then
		local machine = self:getMachine()
		if machine then
			machine:doTransition()
		end
	end
end

function AIEventHandler.move_meet_cliff(self)
	self:clearHatred(self.chaseTarget)
	self:setChaseTarget(nil)
	if self:aiData("meetCliffBackRun") then
		local pos = self:getBackTargetByPos(self:getTargetPos())
		self:setTargetPos(pos, true)
		
		local curState = self:getCurState()
		if curState then
			curState.endTime = World.Now() + math.random(20, 40)
		end
	end
end

-- todo modify
function AIEventHandler.move_meet_collision(self)
	local pos
	local cfg = self:getEntity():cfg()
	if self:aiData("meetCollisionEmptyRun") then 
		return
	elseif self:aiData("meetCollisionBackRun") then
		pos = self:getBackTargetByPos(self:getTargetPos())
	elseif cfg.meetCollisionSkill and cfg.meetCollisionSkill.fullName then
		local countLimit = cfg.meetCollisionSkill.countLimit or 1
		local meetCollisionCount = self:aiData("collisionCount") and self:aiData("collisionCount") + 1 or 1
		if meetCollisionCount >= countLimit then
			meetCollisionCount = 0
			Lib.logDebug("collision skill", cfg.meetCollisionSkill.fullName)
			Skill.Cast(cfg.meetCollisionSkill.fullName, {needPre = true}, self:getEntity())
		else
			pos = self:getTurnTargetByPos(self:getTargetPos())
		end
		self:setAiData("collisionCount", meetCollisionCount)
	elseif cfg.meetCollisionTransfer and cfg.meetCollisionTransfer.posList and #cfg.meetCollisionTransfer.posList > 0 then
		--撞墙传送
		local context = {obj1=self:getEntity(), canTransfer = true}
		Trigger.CheckTriggers(self:getEntity():cfg(), "AI_CAN_TRANSFER", context)
		if not context.canTransfer then
			return false
		end
		local countLimit = cfg.meetCollisionTransfer.countLimit or 1
		local meetCollisionCount = self:aiData("collisionCount") and self:aiData("collisionCount") + 1 or 1
		if meetCollisionCount >= countLimit then
			meetCollisionCount = 0
			local entity = self:getEntity()
			local index = math.random(1, #cfg.meetCollisionTransfer.posList)
			Lib.logDebug("collision transfer index", index)
			entity:setMapPos(entity.map, cfg.meetCollisionTransfer.posList[index])
			local machine = self:getMachine()
			if machine then
				machine:doTransition()
			end
		end
		self:setAiData("collisionCount", meetCollisionCount)
	else
		pos = self:getTurnTargetByPos(self:getTargetPos())
	end
	if not pos then
		return
	end
	self:setTargetPos(pos, true)
	self:getEntity().endTime = World.Now() + math.random(20, 40)
end

function AIEventHandler.ai_status_change(self, isRunning)
	ai_control_mgr:controlEventHandle("ai_status_change", self, isRunning)
end

function AIControl:handleEvent(event, ...)
	-- print("AIControl handle event", event, ...)
	local entity = self:getEntity()
	if not entity or not entity:isValid() or not entity:getPosition() then
		return
	end
	local machine = self:getMachine()
	if machine then
		Profiler:begin("AIStateMachine.onEvent."..event)
		local ok, ret = pcall(machine.onEvent, machine, event, ...)
		Profiler:finish("AIStateMachine.onEvent."..event)
		if ok and ret then
			return
		end
	end
	local handler = AIEventHandler[event]
	if handler then
		Profiler:begin("AIEventHandler."..event)
		handler(self, ...)
		Profiler:finish("AIEventHandler."..event)
	else
		print("no handler for ai event", event, ...)
	end
end

function AIControl:ai_event(event, ...)
	local entity = self:getEntity()
	if not entity or not entity:isValid() or entity.curHp <= 0 or not entity:getPosition() then
		return
	end
	if not string.find(entity.name, "elf") then
		--print("AIControl ai_event", entity.objID, entity.name, event, ...)
	end
	local context = {obj1 = entity}
	for k, v in ipairs({...}) do
		context[string.format("params%d",k)] = v
	end
	Profiler:begin("TriggerAIEvent."..event:upper())
	Trigger.CheckTriggers(entity:cfg(), event:upper(), context)
	Profiler:finish("TriggerAIEvent."..event:upper())
	if context.ignore then
		return
	end
	self:handleEvent(event, ...)
end

function AIControl:addHatred(objID, value, hateWay)
	local hatred = self:getEntity():data("aiHatred")
	local data = hatred[objID]
	self:calcHatred(objID)
	if not data then
		hatred[objID] = {value = value, time = World.Now(), hateWay = hateWay}
	else
		data.value = data.value + value
		data.time = World.Now()
		data.hateWay = hateWay or data.hateWay
	end
end

function AIControl:calcHatred(objID)
	local entity = self:getEntity()
	local hatred = entity:data("aiHatred")
	local data = hatred[objID]
	if not data then
		return 0
	end
	-- 仇恨方式1忽视衰减
	-- 默认为衰减
	local hateWay = data.hateWay
	if hateWay == 1 then
		return data.value
	end
	if not hateWay and self:aiData("hateWay") == 1 then
		return data.value
	end

	local now = World.Now()
	local value = math.floor(data.value * (math.pow(1 - 0.1, math.floor((now - data.time) / 20))))
	if value < 1 then
		hatred[objID] = nil
		return 0
	end
	data.value = value
	data.time = now
	return value
end

function AIControl:clearHatred(objID)
	local entity = self:getEntity()
	if not objID then
		entity:setData("aiHatred", nil)
	else
		entity:data("aiHatred")[objID] = nil
	end
end

function AIControl:getMaxHatredEntity()
	Profiler:begin("AIControl.getMaxHatredEntity")
	local entity = self:getEntity()
	local chaseDis = self:getAIChaseDis()
	local attackNpc = self:aiData("attackNpc")
	local hatred = entity:data("aiHatred")
	local curWorld = World.CurWorld
	local minAttackHate = self:aiData("minAttackHate")
	local ret, maxValue = nil, minAttackHate or 0
	for objID in pairs(hatred) do
		local target = curWorld:getObject(objID)
		if not target or not target:isValid() or target.curHp <= 0 then
			hatred[objID] = nil
			goto continue
		elseif not attackNpc and not target.isPlayer then
			goto continue
		elseif not entity:canAttack(target) then
			goto continue
		elseif not self:canSeeEnemy(target) then
			goto continue
		end
		local value = self:calcHatred(objID)
		if value > maxValue then
			ret, maxValue = target, value
		end
		::continue::
	end
	Profiler:finish("AIControl.getMaxHatredEntity")
	return ret
end

function AIControl:getNearestEnemy()
	Profiler:begin("AIControl.getNearestEnemy")
	local entity = self:getEntity()
	local config = entity:cfg()
	local chaseDis = self:getAIChaseDis()
	local attackNpc = self:aiData("attackNpc")
	local _lossEnemyTime = self:aiData("lossEnemyTime")
	Profiler:begin("AIControl.getEntitiesInSight")
	local enemyList = self:getEntitiesInSight()
	Profiler:finish("AIControl.getEntitiesInSight")
	local lossTime = World.Now() - (_lossEnemyTime or lossEnemyTime)
	local curWorld = World.CurWorld
	local enemy, minDisSqr = nil, chaseDis * chaseDis
	for objID, time in pairs(entity:data("sightedEnemies")) do
		if time > lossTime then
			local target = curWorld:getObject(objID)
			if target and target:isValid() and target.curHp > 0 then
				enemyList[#enemyList + 1] = target
			end
		end
	end
	for _, target in pairs(enemyList) do
		if (attackNpc or target.isPlayer) and entity:canAttack(target) then
			local disSqr = entity:distanceSqr(target)
			if disSqr <= minDisSqr then
				enemy, minDisSqr = target, disSqr
			end
		end
	end
	Profiler:finish("AIControl.getNearestEnemy")
	return enemy
end

function AIControl:getEnemy()
	Profiler:begin("AIControl.getEnemy")
	local enemy = self:getMaxHatredEntity()
	if not enemy and self:aiData("autoAttack") then
		enemy = self:getNearestEnemy()
	end
	Profiler:finish("AIControl.getEnemy")
	return enemy
end

local function canCastSkillToTarget(entity, target, skill, packet, cfg)
	local attackDis = cfg and cfg.attackDis or skill.attackDis or 0
	if entity:distanceSqr(target) > attackDis * attackDis then
		return false
	elseif cfg and cfg.sameLevel and math.abs(entity:getPosition().y - target:getPosition().y) > 1 then
		return false
	elseif not skill:canCast(packet, entity) then
		return false
	elseif not cfg then
		return true
	end
	local hpRate = entity.curHp / entity:prop("maxHp")
	return (cfg.hpRateMin or 0) < hpRate and hpRate <= (cfg.hpRateMax or 1)
end

local function getCastableSkills(self, targets, isCheck)
	Profiler:begin("AIControl.getCastableSkills")
	local entity = self:getEntity()
	local startPos = entity:getPosition()
	local packets = {}
	for k, target in pairs(targets) do
		packets[k] = {
			targetID = target.objID,
			startPos = startPos,
			targetPos = target:getPosition(),
		}
	end
	local list = {}
	for _, name in ipairs(self:aiData("skills") or {}) do
		local skill = Skill.Cfg(name)
		for k, target in pairs(targets) do
			local packet = packets[k]
			if canCastSkillToTarget(entity, target, skill, packet) then
				if isCheck then return true end
				list[#list + 1] = {
					name = name, skill = skill,	target = target, packet = packet,
				}
			end
			local attackDis
			local skillAttackDis = skill.range and (skill.range) / 2 or (attackDis or 0)
			if skill.range and attackDis and skill.range < attackDis then
				skillAttackDis  = skill.range
			end
			if self.skillMinAttackDis > skillAttackDis then
				self.skillMinAttackDis = skillAttackDis
			end
		end
	end
	for _, cfg in ipairs(self:aiData("skillList") or {}) do
		local skill = Skill.Cfg(cfg.fullName)
		for k, target in pairs(targets) do
			local packet = packets[k]
			if canCastSkillToTarget(entity, target, skill, packet, cfg) then
				if isCheck then return true end
				list[#list + 1] = {
					name = cfg.fullName, skill = skill,	target = target, packet = packet,cfg = cfg,
				}
			end
			local attackDis = cfg.attackDis
			local skillAttackDis = skill.range and (skill.range) / 2 or (attackDis or 0)
			if skill.range and attackDis and skill.range < attackDis then
				skillAttackDis  = skill.range
			end
			if self.skillMinAttackDis > skillAttackDis then
				self.skillMinAttackDis = skillAttackDis
			end
		end
	end
	Profiler:finish("AIControl.getCastableSkills")
	return (not isCheck) and list
end

function AIControl:canCastSkillToTarget(target)
	return getCastableSkills(self, { target }, true)
end

function AIControl:getCastableSkill(target)
	return getCastableSkills(self, { target })
end

function AIControl:getCastableSkillAndTarget()
	Profiler:begin("AIControl.getCastableSkillAndTarget")
	local targets = { self:getMaxHatredEntity() }
	if self:aiData("autoAttack") then
		targets[#targets + 1] = self:getNearestEnemy()
	end
	local castables = getCastableSkills(self, targets)
	if #castables == 0 then
		Profiler:finish("AIControl.getCastableSkillAndTarget")
		return
	end
	local entity = self:getEntity()
	local priorityMap = self:aiData("skillPriority") or {}
	for _, cfg in ipairs(self:aiData("skillList") or {}) do
		priorityMap[cfg.fullName] = cfg.priority
	end
	if not next(priorityMap) then
		local data = castables[1]
		Profiler:finish("AIControl.getCastableSkillAndTarget")
		return data.skill, data.target, data.packet, data.cfg
	end

	local priorities, skills = {}, {}
	for i, data in ipairs(castables) do
		local name = data.name
		local priority = priorityMap[name] or 0
		local list = skills[priority]
		if not list then
			list = {}
			skills[priority] = list
			priorities[#priorities + 1] = priority
		end
		list[#list + 1] = data
	end
	table.sort(priorities, function (p1, p2) return p1 > p2 end)
	for _, priority in pairs(priorities) do
		for _, data in ipairs(skills[priority]) do
			if data.skill:canCast(data.packet, entity) then
				Profiler:finish("AIControl.getCastableSkillAndTarget")
				return data.skill, data.target, data.packet, data.cfg
			end
		end
	end
	Profiler:finish("AIControl.getCastableSkillAndTarget")
end

function AIControl:randPosInHomeArea()
	local pos = self:aiData("homePos")
	if not pos then
		return nil
	end
	local y = pos.y
	local homeSize = self:getHomeSize()
	if not homeSize then
		return nil
	end
	local entity = self:getEntity()
	Profiler:begin("AIControl.randPosInHomeArea")
	local minX, maxX = pos.x - homeSize / 2, pos.x + homeSize / 2
	local minZ, maxZ = pos.z - homeSize / 2, pos.z + homeSize / 2
	local patrolDis = self:aiData("patrolDistance")
	if patrolDis then
		pos = entity:getPosition()
		minX, maxX = mmax(minX, pos.x - patrolDis), mmin(maxX, pos.x + patrolDis)
		minZ, maxZ = mmax(minZ, pos.z - patrolDis), mmin(maxZ, pos.z + patrolDis)
	end
	local x = minX + mrand() * (maxX - minX)
	local z = minZ + mrand() * (maxZ - minZ)
	Profiler:finish("AIControl.randPosInHomeArea")
	return Lib.v3(x, y, z)
end

function AIControl:randPosNearBy(maxDis)
	local entity = self:getEntity()
	local pos = entity:getPosition()
	local len = maxDis * mmax(mrand(), 0.01)
	local rad = mrand() * 2 * PI
	local dx, dz = len * msin(rad), len * mcos(rad)
	return Lib.v3(pos.x + dx, pos.y, pos.z + dz)
end

function AIControl:getTurnTargetByPos(pos)
	if not pos then
		return
	end
	local entity = self:getEntity()
	local curPos = entity:getPosition()
	local dx = pos.x - curPos.x
	local dz = pos.z - curPos.z
	local sign = mrand() < 0.5 and 1 or -1
	return Lib.v3(curPos.x - dz * sign, curPos.y, curPos.z + dx * sign)
end

function AIControl:getBackTargetByPos(pos)
	if not pos then
		return
	end
	local entity = self:getEntity()
	local curPos = entity:getPosition()
	local dx = (pos.x - curPos.x)
	local dy = (pos.y - curPos.y)
	local dz = (pos.z - curPos.z)
	return Lib.v3(curPos.x - dx, curPos.y - dy, curPos.z - dz)
end

function AIControl:getHomeSize()
	local entity = self:getEntity()
	local config = entity:cfg()
	return self:aiData("homeSize") or config.homeSize
end

function AIControl:getHomePos()
	local entity = self:getEntity()
	return self:aiData("homePos")
end

function AIControl:getCurState()
	local machine = self:getMachine()
	if machine then
		return machine:getCurState()
	end
end

function AIControl:getLastState()
	local machine = self:getMachine()
	if machine then
		return machine:getLastState()
	end
end

function AIControl:isGoHomePos()
	return self:aiData("isAIGoHomePos")
end

function AIControl:getAiGroup()
	return self:aiData("AIGroup")
end

function AIControl:getID()
	local entity = self:getEntity()
	return entity.objID
end

function AIControl:getGroupStopFlag()
	return self:aiData("groupStopFlag")
end

function AIControl:setGroupStopFlag(status)
	self:setAiData("groupStopFlag", status)
end

function AIControl:getFollowTarget(ignoreSwitch)
	local meID = self:getID()
	local target = self:aiData("followTarget")

	if not ignoreSwitch and self:aiData("followSwtich") == false then 
		return nil
	end

	if target and target:isValid() and meID ~= target.objID then
		return target
	end
	return nil
end

function AIControl:setFollowSwitch(followSwtich)
	self:setAiData("followSwtich", followSwtich)
end

function AIControl:setFollowTarget(entity,followSwtich)
	local meID = self:getID()
	local lastFollowTarget = self:getFollowTarget(true)
	if lastFollowTarget then
		local followInfoData = lastFollowTarget:data("followInfo")
		local indexs = followInfoData.indexs or {}
		if indexs[meID] then
			if lastFollowTarget == entity then
				return
			end
			local i = 1
			followInfoData.count = followInfoData.count - 1
			indexs[meID] = nil
			for key, index in pairs(indexs or {}) do
				indexs[key] = i
				i = i + 1
			end
		end
	end
	self:setAiData("followTarget", entity)
	if followSwtich ~= nil then 
		self:setFollowSwitch(followSwtich)
	end
	if not entity then
		return
	end
	local curFollowInfoData = entity:data("followInfo")
	curFollowInfoData.count = (curFollowInfoData.count or 0) + 1
	curFollowInfoData.indexs = curFollowInfoData.indexs or {}
	curFollowInfoData.indexs[meID] = curFollowInfoData.count
end

function AIControl:setAIChaseDisFactor(factor)
	if self:getAIChaseDisFactor() ~= factor then
		self:setAiData("chaseFactor", factor)
		self.maxVisualDis = self:getAIChaseDis()
	end
end

function AIControl:getAIChaseDisFactor()
	return self:aiData("chaseFactor") or 1
end

function AIControl:getEntityCfgValue(key)
	return self:getEntity():cfg()[key]
end

function AIControl:getAIChaseDis()
	local baseChaseDis = self:aiData("chaseDistance") or 0
	return baseChaseDis * self:getAIChaseDisFactor()
end

function AIControl:canPause()
	if self:getFollowTarget() then
		return false
	end
	return true
end

function AIControl:getMinSkillAttackDis()
	return self.skillMinAttackDis ~= 999 and self.skillMinAttackDis or 0
end

function AIControl:isInForceGoHomeState()
	local forceGoHomeTimeEnd = self:getEntity().forceGoHomeTimeEnd
	return forceGoHomeTimeEnd and (forceGoHomeTimeEnd > World.Now())
end

function AIControl:loadParams(params)
	for key, value in pairs(params or {}) do
		-- todo check legal
		self:setAiData(key, value)
	end
end

--[[
	params = {
		skillKey = xx, -- must
		fullName = xx, -- must
		priority = xx -- must
		sameLevel = xx,
		attackDis = xx,
	}
]]
function AIControl:addSkill(params)
	self:aiData("skillList")[params.skillKey] = params
end

function AIControl:removeSkill(skillKey)
	self:aiData("skillList")[skillKey] = nil
end

function AIControl:removeSkillWithFullName(fullName)
	if not fullName then
		return
	end
	for key, cfg in pairs(self:aiData("skillList")) do
		if cfg.fullName and (cfg.fullName == fullName) then
			self:removeSkill(key)
		end
	end
end

function AIControl:removeAllSkill()
	self:setAiData("skillList", {})
end

local function getStancePos(target, followIndex, followCount)
	local default = {
		[1] = {
			{0, 0, -2}
		},
		[2] = {
			{0.5, 0, -2}, {-0.5, 0, -2}
		},
		[3] = {
			{1.5, 0, -2}, {0, 0, -2}, {-1.5, 0, -2}
		},
		[4] = {
			{1.5, 0, -2}, {0, 0, -2}, {-1.5, 0, -2}, {0, 0, 2}
		},
		[5] = {
			{2, 0, -2}, {0, 0, -2}, {-2, 0, -2}, {-1, 0, 2}, {1, 0, 2}
		},
	}
	local stanceCfg = default
	stanceCfg = target:cfg().stanceCfg or stanceCfg
	if not stanceCfg[followCount] then
		return Lib.v3(0, 0, -2)
	end
	local posArray = stanceCfg[followCount][followIndex] 
	return Lib.v3(posArray[1], posArray[2], posArray[3])
end

function AIControl:getFollowTargetPos()
	--todo 可能需要根据宠物的个数，和序号围绕在主人周围
	local target = self:getFollowTarget()
	if not target then
		return
	end
	if self:aiData("disableAIStancePos") then
		return target:getPosition()
	end
	local followInfoData = target:data("followInfo")
	local followIndex = followInfoData.indexs[self:getID()]
	local count = followInfoData.count
	local pos = getStancePos(target, followIndex, count)
	if target.isMoving and self:aiData("walkMovingDiffPos") and self:aiData("runMovingDiffPos") then
		if target.movingStyle < 2 then
			pos.x = pos.x + self:aiData("walkMovingDiffPos").x
			pos.z = pos.z + self:aiData("walkMovingDiffPos").z
		else
			pos.x = pos.x + self:aiData("runMovingDiffPos").x
			pos.z = pos.z + self:aiData("runMovingDiffPos").z
		end
	end
	local aroundPos = Lib.posAroundYaw(pos, target:getRotationYaw())
	return aroundPos + target:getPosition()
end
---------------------------------- SELECT TARGET AI -------------------------------------------
local targetFilters = {}

function targetFilters.flt_is_enemy(context, tar)
	return context.me:getValue("camp") ~= tar:getValue("camp")
end

function targetFilters.flt_is_main_role(context, tar)
	return tar.isPlayer
end

function targetFilters.flt_insight(context, tar)
	local disSqr = context.me:distanceSqr(tar)
	local sight = context.control:aiData("sightRange")
	return disSqr <= sight * sight
end

function targetFilters.flt_can_castskill(context, tar)
	return context.control:canCastSkillToTarget(tar)
end

function targetFilters.flt_no_block(context, tar)
	local colliGroupTar = tar:getCollisionGroup()
	local colliGroupMe = context.me:getCollisionGroup()
	local mask = Bitwise64.Not(Bitwise64.Or(colliGroupTar, colliGroupMe))
	return not context.me:aabbSweepTest(tar:getPosition(), mask)
end

local campFilters = {} -- ignore group, and return true if ignore filter
function campFilters.flt_is_enemy(myCamp, tarCamp)	
	return myCamp ~= tarCamp -- ignore filter
end

function campFilters.flt_is_main_role(myCamp, tarCamp)
	return tarCamp == Define.CAMP_PLAYER_DEF
end

local targetSelectors = {}
function targetSelectors.min_move(context, tar)
	context.tar = tar-- todo
end
function targetSelectors.min_dis(context, tar)
	if not context.tar or context.me:distanceSqr(context.tar) > context.me:distanceSqr(tar) then		
		context.tar = tar
	end
end
function targetSelectors.min_blood(context, tar)
	context.tar = tar-- todo
end

local function FiltTargetPass(context, tar, filtFuns)
	for _, fltFn in ipairs(filtFuns) do
		if not fltFn(context, tar)  then
			return false
		end
	end
	return true
end

function AIControl:selectTarget(selector, filters)
	local entity = self:getEntity()
	local filtFuns = {}
	local ignoreTbl = {}
	local myCamp = entity:getValue("camp")

	local function filtCamp(camp)	
		for _, flt in ipairs(filters) do
			local fltFn = campFilters[flt]
			if fltFn and not fltFn(myCamp, camp) then
				return false
			end
		end
		return true
	end

	local selectFn = assert(targetSelectors[selector], "no selector "..selector)
	local context = { me = entity, control = self, tar = nil }
	local entitys = entity_camp.getAllEntitys(filtCamp)
	for _, unit in ipairs(entitys) do
		if FiltTargetPass(context, unit, filtFuns) then
			selectFn(context, unit)
		end
	end
	return context.tar and context.tar.objID
end