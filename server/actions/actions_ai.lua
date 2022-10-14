local BehaviorTree = require("common.behaviortree")
local Actions = BehaviorTree.Actions
require "world.world"
local setting = require "common.setting"

--Lib.dbgp_ = function (context, ...) if context.trigger == "MercenaryCommon" then print(...) end end

function Actions.StartAI(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    entity:startAI()
end

function Actions.StopAI(data, params, context)
    local entity = params.entity
    if ActionsLib.isInvalidEntity(entity) then
        return
    end
    entity:stopAI()
end

function Actions.PauseAI(data, params, context)
	local control = params.entity:getAIControl()
	if control then
		control:pause()
	end
end

function Actions.ContinueAI(data, params, context)
	local control = params.entity:getAIControl()
	if control then
		control:continue()
	end
end

function Actions.EnableAITargetPos(data, params, context)
    params.entity:enableAITargetPos(params.enable)
end

function Actions.SetAITargetPos(data, params, context)
    params.entity:setAITargetPos(params.targetPos, params.enable)
end

function Actions.SetChaseTarget(data, params, context)
	local control = params.entity:getAIControl()
	if not control then 
		return
	end
	control:setChaseTarget(params.targetObj)
end

function Actions.TriggerAIEvent(data, params, context)
	local control = params.entity:getAIControl()
	if control then
		local args = params.params
		control:handleEvent(params.event, args and table.unpack(args, 1, args.n))
	end
end

function Actions.SetAiData(data, params, context)
    if not params.key then
        return
    end
    local entity = params.entity
    local data = entity:data("aiData")
    data[params.key] = params.value

end

function Actions.GetMaxHatredEntity(data, params, context)
    local control = params.entity:getAIControl()
    if not control then
        return nil
    end
    local target = control:getMaxHatredEntity()
    return target
end

function Actions.ClearAIHatred(data, params, context)
	local control = params.entity:getAIControl()
	if control then
		control:clearHatred(params.objID)
	end
end

function Actions.AddAIHatred(data, params, context)
	local control = params.entity:getAIControl()
	local target = params.target
	if control and target and target.objID then
		control:addHatred(target.objID, params.value)
	end
end

function Actions.GetAIHatred(data, params, context)
	local control = params.entity:getAIControl()
	local target = params.target
	if control and target and target.objID then
		return control:calcHatred(target.objID)
	end
end

function Actions.SetFollowTarget(data, params, context)
	local control = params.entity:getAIControl()
	control:setFollowTarget(params.target)
end

function Actions.SetAIChaseDisFactor(data, params, context)
	local control = params.entity:getAIControl()
	control:setAIChaseDisFactor(params.factor)
end

------------------ ai behaviors ---------------------------
-- 是否锁定目标在timeout时间内
function Actions.AI_HoldTarget(data, params, context)
	local nowt = World.Now()
	local timeout = params.timeout or -1
	if timeout >= 0 and nowt > (context.target_lock_time or 0) + timeout then
		return false
	end
	local targetId = context.locked_target	
	local target = World.CurWorld:getObject(targetId)
	if not (target and target:isValid() and target:getValue("isAlive")) then
		context.locked_target = nil
		targetId = nil
	end
	--Lib.dbgp_(context, "HoldTarget "..tostring(targetId))
	return targetId ~= nil
end
-- 选择并锁定目标
function Actions.AI_LockTarget(data, params, context)
	local entity = context.obj1
	local control = entity:getAIControl()
	local selector = params.select_target
	local filters = params.filters
	local target = control:selectTarget(selector, filters)
	--Lib.dbgp_(context, "locktarget "..tostring(target))
	if target then
		--control:SetAiData("locked_target", target)
		context.locked_target = target
		context.target_lock_time = World.Now()
		return true
	end
	return false
end

-- 追逐目标
function Actions.AI_ChaseTarget(data, params, context)
	local entity = context.obj1
	local control = entity:getAIControl()
	local targetId = context.locked_target--control:aiData("locked_target")
	local target = World.CurWorld:getObject(targetId)
	if target then
		local disSqr = entity:distanceSqr(target)
		if disSqr <= (control:aiData("chaseDisSqr") or 20) then
			control:setChaseTarget(nil)
			--Lib.dbgp_(context, "chase arrived "..disSqr)
			return false
		end
		if not context.chaseLevel or context.chaseLevel <= 2 then
			context.chaseLevel = 2
			control:setChaseTarget(target)
			--Lib.dbgp_(context, "chase ok "..disSqr)
		end
		return true
	end
	return false
end
-- 巡逻
function Actions.AI_Patrol(data, params, context)
	local entity = context.obj1
	local control = entity:getAIControl()
	local patrolRange = control:aiData("patrolDistance") or 100
	local nowt = World.Now()
	if nowt >= (context.patrolEndTime or 0) then	
		local targetPos = control:randPosInHomeArea()
		if not targetPos then
			targetPos = control:randPosNearBy(patrolRange)
		end
		if targetPos then
			control:setTargetPos(targetPos, true)
			context.patrolEndTime = nowt + (control:aiData("patrolInterval") or 10)
		end
	end
end
-- 发呆
function Actions.AI_Daze(data, params, context)
	local entity = context.obj1
	local control = entity:getAIControl()
	local nowt = World.Now()
	if context.dazeEndTime then
		if nowt >= context.dazeEndTime then	
			context.dazeEndTime = nil
			return false
		end
		return true
	end
	if nowt < (context.nextDazableTime or 0) then
		return false
	end
	context.dazeEndTime = nowt + (control:aiData("dazeDuration") or 10) -- 发呆持续
	context.nextDazableTime = context.dazeEndTime + (control:aiData("dazeInterval") or 10) -- 发呆间隔
	return true
end
-- 攻击locked target
function Actions.AI_AttackTarget(data, params, context)
	local entity = context.obj1
	local control = entity:getAIControl()
	local targetId = context.locked_target--control:aiData("locked_target")
	local target = World.CurWorld:getObject(targetId)
	local nowt = World.Now()
	if target then
		if nowt < (context.skillCastEndTime or 0) then
			return true
		end
		local castables = control:getCastableSkill(target)
		if not castables or #castables == 0 then
			return false
		end
		local castable = castables[math.random(#castables)] -- random skill
		local skill, skillCfg = castable.skill, castable.cfg
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

		local packet = {
			targetID = targetId,
			targetPos = targetPos,
			startPos = startPos,
			cdTime = skillCfg and skillCfg.cdTime,
			needPre = true
		}
		if not skill:canCast(packet, entity) then
			return false
		end
		local fullName = skill.fullName
		if skill.startAction and skill.startAction ~= "" and skill.startActionTime and skill.startActionTime > 0 then
			local packet = {
				pid = "StartSkill",
				name = fullName,
				fromID = entity.objID,
				touchTime = skill.startActionTime or 20,
			}
			entity:sendPacketToTracking(packet)

			local entityId = entity.objID
			World.Timer(skill.startActionTime or 20, function()
				--Lib.logDebug("AI cast skill", fullName, entity.name, entity.objID)
				local entity = World.CurWorld:getObject(entityId)
				if entity then
					Skill.Cast(fullName, packet, entity)
				end
			end)
		else
			Skill.Cast(fullName, packet, entity)
		end

		local castActionTime = skillCfg and skillCfg.castActionTime or skill.castActionTime or 20
		castActionTime = castActionTime > 0 and castActionTime or 20
		context.skillCastEndTime = (castActionTime > 0 and castActionTime or 20) + (skill.startActionTime or 0)
		return true
	end
	return false
end

function Actions.AI_Follow(data, params, context)
	local entity = context.obj1
	local control = entity:getAIControl()
	local target = entity:owner()
	local failRet = params.no_failure and true or false
	if not target then
		return failRet
	end
	local aiData = entity:data("aiData")	
	local disSqr = entity:distanceSqr(target)
	if disSqr <= aiData.followMinDisSqr then
		return failRet
	end
	if disSqr > aiData.followLegalDisSqr then
		context.chaseLevel = 3
		context.isFollow = true
		control:setFollowTarget(target)
		control:setTargetPos(control:getFollowTargetPos(target), true)
		--Lib.dbgp_(context, "follow legal "..disSqr)
	else
		if not context.chaseLevel then
			context.chaseLevel = 1
			context.isFollow = true
			control:setFollowTarget(target)
			control:setTargetPos(control:getFollowTargetPos(target), true)
			--Lib.dbgp_(context, "follow min "..disSqr)
		else
			--Lib.dbgp_(context, "follow fail "..disSqr)
		end
	end
	local tpDisSqr = aiData.followForceTpDisSqr
	if tpDisSqr and disSqr >= tpDisSqr then
		entity.isMoving = false
		entity:setMapPos(target.map, control:getFollowTargetPos(target))
		control:setTargetPos(nil)
	end
	return true
end
