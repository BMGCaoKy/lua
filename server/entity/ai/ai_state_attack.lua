

local AIStateBase = require("entity.ai.ai_state_base")
local AIStateAttack = L("AIStateAttack", Lib.derive(AIStateBase))

local BEGIN_PREPARE_CAST_SKILL = 1
local BEGIN_DO_CAST_SKILL = 2
local END_CAST_SKILL = 3

AIStateAttack.NAME = "ATTACK"

function AIStateAttack:enter()
	local control = self.control
	local entity = control:getEntity()
	local aiData = entity:data("aiData")
	local skill = aiData.castableSkill
	local skillCfg = aiData.skillCfg
	self.skillCfg = skillCfg
	self.skill = skill
	self.endTime = World.Now() + (skill.prepareTime or 1)
	local target = aiData.skillTarget
	self.target = target
	local targetPos = target:getPosition()
	local startPos = entity:getPosition()
	control:setTargetPos(nil)	-- stop move

	if skillCfg then
		if skillCfg.startOffest then
			startPos = Lib.v3add(startPos, skillCfg.startOffest)
		end

		if skillCfg.sameLevel  then
			targetPos = {
				x = targetPos.x,
				y = startPos.y,
				z = targetPos.z,
			}
		end

		if skillCfg.moveTarget then
			control:setTargetPos(targetPos, true)
		end
	end

	self.packet = {
		targetID = target.objID,
		targetPos = targetPos,
		startPos = startPos,
		cdTime = skillCfg and skillCfg.cdTime,
		needPre = true,
		castByAI = true 
	}
	control:face2Pos(targetPos)
	self.moveTarget = control:getTargetPos()
	self.stage = BEGIN_PREPARE_CAST_SKILL
end

function AIStateAttack:update()
	local skill = self.skill
	local remain = self.endTime - World.Now()
	if remain > 0 then
		return remain
	elseif self.stage >= END_CAST_SKILL then
		return
	end
	local entity = self.control:getEntity()
	if not self.skill:canCast(self.packet, entity) then
		return
	end
	local fullName = skill.fullName

	if skill.startAction and skill.startAction ~= "" and skill.startActionTime and skill.startActionTime > 0 and self.stage == 1 then
		local packet = {
			pid = "StartSkill",
			name = fullName,
			fromID = entity.objID,
			touchTime = skill.startActionTime or 20,
		}
		entity:sendPacketToTracking(packet)
		self.stage = BEGIN_DO_CAST_SKILL
		return skill.startActionTime or 20
	end

	--Lib.logDebug("AI cast skill", fullName, entity.name, entity.objID)
	self.packet.preSwingTime = skill.preSwingTime or nil
	Skill.Cast(fullName, self.packet, entity)

	self.stage = END_CAST_SKILL
	local castActionTime = self.skillCfg and self.skillCfg.castActionTime or skill.castActionTime or 20
	castActionTime = castActionTime > 0 and castActionTime or 20
	local swingTime = (skill.preSwingTime or 0) + (skill.backSwingTime or 0)
	print("swingTime " , swingTime)
	if swingTime > castActionTime then 
		castActionTime = swingTime
	end
	return castActionTime
end

function AIStateAttack:exit()
	self.skill = nil
	self.target = nil
	self.control:setTargetPos(self.moveTarget, true)
	self.moveTarget = nil
end

function AIStateAttack:onEvent(event, ...)
	local eventFunc = {}
	function eventFunc.onHurt(self, ... )
		self.stage = self.skillCfg and self.skillCfg.hurtStop and END_CAST_SKILL or self.stage
    end
	if eventFunc[event] then
		eventFunc[event](self, ...)
	end
end

RETURN(AIStateAttack)
