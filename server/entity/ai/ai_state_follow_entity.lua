local AIEvaluator = require("entity.ai.ai_evaluator")
local AIStateBase = require("entity.ai.ai_state_base")

local AIStateFollowEntity = L("AIStateFollowEntity", Lib.derive(AIStateBase))
AIStateFollowEntity.NAME = "AIStateFollowEntity"

local TRANSFER_DIS_SQR = 10 * 10
local transferDisSqr

local followEntityEnableDecelerate = false  -- 是否启用减速
local followEntityDecelerateModulus = 0.9 -- 减速系数
local followEntityDecelerateZoneRangeModulus = 2 -- 减速带范围系数(*速度)
local curAIMoveSpeed = 0
local followTransferWaitTime = 0 --远离后瞬移等待时间

function AIStateFollowEntity:getFollowTarget()
	local control = self.control
	return control:getFollowTarget()
end

function AIStateFollowEntity:getDisSqrTarget()
	local entity = self.control:getEntity()
	local target = self:getFollowTarget()
	local targetPos = self.control:getFollowTargetPos()
	-- get pos by targetPos first, if not, use target
 	if targetPos then
		return Lib.getPosDistanceSqr(entity:getPosition(), targetPos)
	elseif target then
		return entity:distanceSqr(target)
	end
	return math.huge
end

function AIStateFollowEntity:transferTarget()
	local target = self:getFollowTarget()
	local entity = self.control:getEntity()
	if target then
		-- 是宠物 而且 是显示才通过AI改变宠物位置
		if entity.isShowingPet == true then
			entity.isMoving = false
			entity:setMapPos(target.map, target:getPosition())
		end
		--不是宠物的
		if entity.isShowingPet == nil then
			entity.isMoving = false
			entity:setMapPos(target.map, target:getPosition())
		end
	end
end

function AIStateFollowEntity:enter()
	local control = self.control
	transferDisSqr = control:getEntityCfgValue("followEntityTransferDisSqr") or TRANSFER_DIS_SQR
	followEntityEnableDecelerate = control:getEntityCfgValue("followEntityEnableDecelerate")
	followEntityDecelerateModulus = control:getEntityCfgValue("followEntityDecelerateModulus") or followEntityDecelerateModulus
	followEntityDecelerateZoneRangeModulus = control:getEntityCfgValue("followEntityDecelerateZoneRangeModulus") or followEntityDecelerateZoneRangeModulus
	curAIMoveSpeed = control:getEntityCfgValue("moveSpeed")
	followTransferWaitTime = control:getEntityCfgValue("followTransferWaitTime") or 0
	if not self.running then 
		self.waitTime = World.Now()
	end
	self.running = true
	self.endTime = World.Now() + (control:getEntityCfgValue("followEntityFrequency") or 1)
end

function AIStateFollowEntity:checkDecelerate(control, disSqr)
	if not followEntityEnableDecelerate then
		return
	end
	local axis = curAIMoveSpeed * followEntityDecelerateZoneRangeModulus
	if axis * axis < disSqr then
		return
	end
	local entity = control:getEntity()
	entity.motion = Lib.tov3(entity.motion) * followEntityDecelerateModulus
end

function AIStateFollowEntity:autoAdjustMotion(control, disSqr)
	if not control:aiData("followAutoAdjustMotion") then
		return
	end
	local entity = control:getEntity()
	if (curAIMoveSpeed * 20) * (curAIMoveSpeed * 20) > disSqr then
		entity.motion = Lib.tov3(entity.motion) * 0.85
	elseif (curAIMoveSpeed * 50) * (curAIMoveSpeed * 50) < disSqr then
		entity.motion = Lib.tov3(entity.motion) * 1.5
	end
end

function AIStateFollowEntity:update()
    local control = self.control
	local disSqr = self:getDisSqrTarget()
	local target = self:getFollowTarget()
	local entity = control:getEntity()
	if (disSqr > transferDisSqr) and (self.waitTime + followTransferWaitTime < World.Now()) 
	or (target and entity.map ~= target.map) then
		self:transferTarget()
		control:clearHatred()
		control:setTargetPos(nil)
		self.waitTime = World.Now()
	else
		if disSqr < transferDisSqr then
				self.waitTime = World.Now()
		end
		local targetPos = self.control:getFollowTargetPos()
		control:setTargetPos(targetPos, true)
	end
	self:checkDecelerate(control, disSqr)
	self:autoAdjustMotion(control, disSqr)
	return self.endTime - World.Now()
end

function AIStateFollowEntity:onEvent(event, ...)
    if event == "arrived_target_pos" then
		local control = self.control
		local entity = control:getEntity()
		local target = self:getFollowTarget()
		if target then
			entity:setRotationYaw(target:getRotationYaw())
			entity:syncPosDelay()
		end
		return false
    end
    return false
end

function AIStateFollowEntity:exit()
	self.endTime = nil
	self.running = false
end

RETURN(AIStateFollowEntity)