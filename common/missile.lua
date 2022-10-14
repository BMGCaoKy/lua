local setting = require "common.setting"

local CfgMod = setting:mod("missile")
local MissileCfg = nil

local CfgMT = T(Missile, "CfgMT")
CfgMT.__index = {
	width = 0.5,
	height = 0.5,
}

Missile.isMissile = true

function Missile:initCommon(params)
	self:initData()
	self._cfg = Missile.GetCfg(self:getCfgName())
	self.params = params
	self.hitEntityCount = 0
	self.hitBlockCount = 0
	self.hitNum = 0
	self:setMap(params.map)
	self:init(params)
	self:castEffect(self._cfg.initEffect)
	self:onCreate()
end

function Missile.GetCfg(cfgName)
    return assert(CfgMod:get(cfgName), cfgName)
end

function Missile:onStart()
	local cfg = self:cfg()
	self:castSkill(cfg.startSkill)
	self:castEffect(cfg.startEffect)
    self:playSound(cfg.startSound)
end

local function canAttackEntity(self, fromID, targetID)
	local from = self.world:getObject(fromID)
	if not from or not targetID then
		return false
	end
	local target = self.world:getObject(targetID)
	if not target then
		return false
	end
	local selfOwner = from:owner()
	local targetOwner = target:owner()
	if selfOwner.objID == targetOwner.objID then
		return false
	end
	local selfTeam = selfOwner:getValue("teamId")
	local targetTeam = targetOwner:getValue("teamId")
	if not World.cfg.teammateHurt and selfTeam ~= 0 and selfTeam == targetTeam then
		return false
	end
	return true
end

function Missile:onHitEntity()
	local cfg = self:cfg()
	local target = self:lastHitEntity()
	if canAttackEntity(self, self.params.fromID, target.objID) then
		self.hitNum = self.hitNum + 1
		self:castSkill(cfg.hitEntitySkill or cfg.hitSkill, {targetID = target.objID, name = self.params.cast.packet.name})
	end
	local hitEntityCount = self.hitEntityCount + 1
	self.hitEntityCount = hitEntityCount
	if (cfg.hitEntityCount and hitEntityCount >= cfg.hitEntityCount) or (cfg.hitCount and (hitEntityCount + self.hitBlockCount) >= cfg.hitCount)then
		self:vanish()
	end
end

function  Missile:onHitBlock(pos)
	local cfg = self:cfg()
	local targetPos = self:lastHitBlock()
	self.hitNum = self.hitNum + 1
	self:castSkill(cfg.hitBlockSkill or cfg.hitSkill, {targetPos = targetPos})
	self:castEffect(cfg.hitBlockEffect or cfg.hitEffect)
    self:playSound(cfg.hitBlockSound or cfg.hitSound)
	local hitBlockCount = self.hitBlockCount + 1
	self.hitBlockCount = hitBlockCount
	if (cfg.hitBlockCount and hitBlockCount >= cfg.hitBlockCount) or (cfg.hitCount and (hitBlockCount + self.hitEntityCount) >= cfg.hitCount)then
		self:vanish()
	end
    local blockcfg = self.map:getBlock(targetPos)
	if blockcfg.canHitBreak  then
		self.map:removeBlock(targetPos)
		if World.isClient and blockcfg.hitBreakEffect then
			Blockman.instance:playEffectByPos(blockcfg.hitBreakEffect.effect, targetPos, 0 ,500)
		end
	end
end

function Missile:onReboundBlock()
	local cfg = self:cfg()
	local targetPos = self:lastHitBlock()
    local blockcfg = self.map:getBlock(targetPos)
	if blockcfg.canHitBreak then
		self.map:removeBlock(targetPos)
		if World.isClient and blockcfg.hitBreakEffect then
			Blockman.instance:playEffectByPos(blockcfg.hitBreakEffect.effect, targetPos, 0 ,500)
		end
	end
end

function Missile:onTouchBlock()
end

function Missile:onVanish()
	local cfg = self:cfg()
	if not World.isClient then
		local target = self:lastHitEntity()
		local id = self.params.fromID
		local owner = id and self.world:getObject(id)
		Trigger.CheckTriggers(cfg, "MISSILE_VANISH", {obj1=target,obj2= owner,missile=self})
	end
	if self.hitNum <= 0 then
		if cfg.hitEmptySkill then
			self:castSkill(cfg.hitEmptySkill, {needPre=true})
		end
	end
	self:castSkill(cfg.vanishSkill)
	self:castEffect(cfg.vanishEffect)
	self:playSound(cfg.vanishSound)
end

function Missile:castSkill(skillName, packet)
	if not skillName then
		return
	end
	if World.isClient and not Blockman.instance.singleGame then
		return
	end
	local skill = Skill.Cfg(skillName)
	local params = self.params
	local from = self.world:getObject(params.fromID)
	local packet = packet or {}
	packet.motion = self.motion
	packet.targetID = packet.targetID or params.targetID
	packet.startPos = packet.startPos or self:getPosition()
	packet.autoCast = true
	if not packet.targetPos then
		packet.targetPos = packet.startPos + params.targetDir
	end
	local canCast = true
	local context = {targetID = packet.targetID , canCast = canCast, from = from}
	Trigger.CheckTriggers(from and from:cfg(), "ENTITY_HIT_CAST_SKILL", context)
	if context.canCast then
		Skill.DoCast(skill, packet, from)
	end
end

function Missile:castEffect(effect)
end

local function skillCfg(cfg, key, i)
	local num = cfg[key]
	if type(num)~="table" or #num==0 then
		return num
	end
	return num[i]
end

local GET_CAN_HIT_ENTITY_FUNC = {}

local function getTargetEntitysVector(allEntitys,checkFunc)
	local ret = {}
	for _, obj in pairs(allEntitys) do
		if checkFunc(obj) then
			ret[#ret + 1] = obj
		end
	end
	return ret
end
GET_CAN_HIT_ENTITY_FUNC.hitAllTeam = function(skill, missileCfg,from,allEntitys)
	return allEntitys
end
GET_CAN_HIT_ENTITY_FUNC.hitOtherTeam = function(skill, missileCfg,from,allEntitys)
	local teamId = from:getValue("teamId")
	if teamId == 0 then
		return allEntitys
	end
	local checkFunc = function(obj)
		return obj and (teamId ~= obj:getValue("teamId")) or false
	end
	return getTargetEntitysVector(allEntitys, checkFunc)
end
GET_CAN_HIT_ENTITY_FUNC.hitSelfTeam = function(skill, missileCfg,from,allEntitys)
	local teamId = from:getValue("teamId")
	if teamId == 0 then
		return {}
	end
	local checkFunc = function(obj)
		return obj and (teamId == obj:getValue("teamId")) or false
	end
	return getTargetEntitysVector(allEntitys,checkFunc)
end
--[[
	hitTargetTeamIds = {
		teamId = true,
		..
	}
]]
GET_CAN_HIT_ENTITY_FUNC.hitTargetTeam = function(skill, missileCfg, from, allEntitys)
	local hitTargetTeamIds = missileCfg.hitTargetTeamIds or skill.hitTargetTeamIds
	if not hitTargetTeamIds then
		return {}
	end
	local checkFunc = function(obj)
		if not obj or not obj:isValid() then
			return false
		end
		return hitTargetTeamIds[obj:getValue("teamId")..""]
	end
	return getTargetEntitysVector(allEntitys, checkFunc)
end

GET_CAN_HIT_ENTITY_FUNC.hitAllEntitys = function(skill, missileCfg,from,allEntitys)--can kill player and NPC
	return allEntitys
end
GET_CAN_HIT_ENTITY_FUNC.hitPlayer = function(skill, missileCfg,from,allEntitys)
	local checkFunc = function(obj)
		return obj and obj.isPlayer or false
	end
	return getTargetEntitysVector(allEntitys, checkFunc)
end
GET_CAN_HIT_ENTITY_FUNC.hitNpc = function(skill, missileCfg,from,allEntitys)
	local checkFunc = function(obj)
		return obj and (not obj.isPlayer) or false
	end
	return getTargetEntitysVector(allEntitys, checkFunc)
end

GET_CAN_HIT_ENTITY_FUNC.hitAllConfigEntity = function(skill, missileCfg, from, allEntitys)
	return allEntitys
end
--[[
	hitTargetConfigRole = [
		{
			"key1":"vaule1",
			"key2":"vaule2",
			..:..
		}
	]
]]
GET_CAN_HIT_ENTITY_FUNC.hitTargetConfigEntity = function(skill, missileCfg, from, allEntitys)
	local hitTargetConfigRole = missileCfg.hitTargetConfigRole or skill.hitTargetConfigRole
	if not hitTargetConfigRole or type(hitTargetConfigRole)~="table" then
		return allEntitys
	end
	local checkFunc = function(obj)
		if not obj or not obj:isValid() then
			return false
		end
		local cfg = obj:cfg()
		for index, kvMap in pairs(hitTargetConfigRole) do
			local canHit = true
			for key, value in pairs(kvMap) do
				if value ~= cfg[key] then
					canHit = false
					break
				end
			end
			if canHit then
				return true
			end
		end
		return false
	end
	return getTargetEntitysVector(allEntitys, checkFunc)
end

local GetMissleCanHitEnitys = function(from,entitys,missileCfg,skill)
	local hitEntitysRoles = missileCfg.hitEntitysRoles or skill.hitEntitysRoles -- save roles
	if not hitEntitysRoles or not from then
		return {}
	end
	for _, role in ipairs(hitEntitysRoles) do
		if GET_CAN_HIT_ENTITY_FUNC[role] then
			entitys = GET_CAN_HIT_ENTITY_FUNC[role](skill, missileCfg, from, entitys)
		end
	end
	-- todo ex, but just entitys
	local ret = {}
	for _, obj in pairs(entitys) do 
		ret[#ret + 1] = obj.objID
	end
	return ret
end

function Missile.SkillCast(packet, from, skill)
	local map
	if packet.mapID then
		map = World.mapList[packet.mapID]
	else
		map = from.map
	end
	if PlatformUtil.isPlatformWindows() then
		assert(map, packet.mapID)
	else
		if not map then
			Lib.logError("Missile.SkillCast not map", packet.mapID)
			return
		end
	end
	local startPos = Lib.tov3(packet.startPos)
	local targetType = skillCfg(skill, "targetType")
	local targetPos = packet.targetPos or startPos
	local missiles = {}
	local cast = {
		skill = skill,
		missiles = missiles,
		packet = packet,
	}
	local targets = {}
	if packet.isMoreTargets then
		for i,v in ipairs(targetPos) do
			targets[i] = v - startPos
			targets[i]:normalize()
		end
	else
		targets[1] = targetPos - startPos
		targets[1]:normalize()
	end
	local packetMoveSpeed = packet.moveSpeed
	local entitys = World.CurWorld:getAllEntity()
	local missileHitEntityMap = {}
	for i = 1, (skill.missileCount or 1) do
		local fd = targets[i] or targets[1]
		local cfgName = skillCfg(skill, "missileCfg", i)
		local pos = skillCfg(skill, "startPos", i)
		local tempfd = fd:copy()
		fd:normalize()
		if pos then
			local ld = Lib.v3(-fd.z, 0, fd.x)
			ld:normalize()
			pos = startPos + ld*pos.x + fd*pos.z + Lib.v3(0, pos.y, 0)
		else
			pos = startPos
		end
		if targetType == "FrontSight" then
			if packet.isMoreTargets then 
				fd = targetPos[i] - pos
			else 
				fd = targetPos - pos
			end
			fd:normalize()
		end
		local targetDir = fd
		local pitch = skillCfg(skill, "startPitch", i)
		if not fd:isZero() then
			targetDir = fd:copy()
			local sl = math.sqrt(fd.x*fd.x + fd.z*fd.z)
			local yaw = skillCfg(skill, "startYaw", i)
			if sl>0 then
				if yaw then
					local rad = math.atan(targetDir.x, targetDir.z) + math.rad(yaw)
					targetDir.x = math.sin(rad)*sl
					targetDir.z = math.cos(rad)*sl
				end
				if pitch then
					local rad = math.asin(targetDir.y) + math.rad(pitch)
					targetDir.y = math.sin(rad)
					local f = math.cos(rad)
					local yawRad = math.atan(targetDir.x, targetDir.z)
					targetDir.x = math.sin(yawRad) * f
					targetDir.z = math.cos(yawRad) * f
				end
			end
		end
		local cfg = Missile.GetCfg(cfgName)
		local l_canHitEntityVector = missileHitEntityMap[cfgName]
		if not l_canHitEntityVector then
			l_canHitEntityVector = GetMissleCanHitEnitys(from,entitys,cfg,skill)
			missileHitEntityMap[cfgName] = l_canHitEntityVector
		end
		local moveSpeed = packetMoveSpeed
		if not moveSpeed then
			local missile_useExpressionPropMap, skill_useExpressionPropMap, from_useExpressionPropMap = cfg.useExpressionPropMap or {}, skill and skill.useExpressionPropMap or {}, from:cfg().useExpressionPropMap or {}
			local missileMoveSpeedExpression = missile_useExpressionPropMap.missileMoveSpeedExpression or skill_useExpressionPropMap.missileMoveSpeedExpression or from_useExpressionPropMap.missileMoveSpeedExpression
			moveSpeed = missileMoveSpeedExpression and Lib.getExpressionResult(missileMoveSpeedExpression, {target = from, from = from, packet = packet}) or cfg.moveSpeed
		end
		local params = {
			fromID = from.objID,
			map = map,
			startPos = pos,
			targetDir = targetDir,
			startWait = skillCfg(skill, "startWait", i)//1,
			bodyYawOffset = skillCfg(skill, "bodyYawOffset", i),
			bodyPitchOffset = skillCfg(skill, "bodyPitchOffset", i),
			targetID = packet.targetID,
			index = i,
			cast = cast,
			gravity = packet.gravity or cfg.gravity,
			moveSpeed = moveSpeed,
			rotationYaw = (packet and packet.fromBodyYaw) or (from and from:getRotationYaw()) or 0,
			followTargetPosition = packet.followTargetPosition or cfg.followTargetPosition or false,
			followTargetPositionOffset = packet.followTargetPositionOffset or cfg.followTargetPositionOffset or Lib.v3(0, 0, 0),
			followTargetRotation = packet.followTargetRotation or cfg.followTargetRotation or false,
			followTargetRotationOffset = packet.followTargetRotationOffset or cfg.followTargetRotationOffset or Lib.v3(0, 0, 0),
			modelSizeScale = packet.modelSizeScale or cfg.modelSizeScale or Lib.v3(1,1,1),
			canHitEntityVector = l_canHitEntityVector,
			pitch = pitch
		}
		missiles[i] = Missile.Create(cfgName, params).objID
	end
	return cast
end

function missile_event(missile, event, ...)
	missile[event](missile, ...)
end

function CfgMod:onLoad(cfg, reload)
	setmetatable(cfg, CfgMT)
	World.CurWorld:loadMissileConfig(cfg.id, cfg)
end
