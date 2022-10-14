local AIEvaluator = L("AIEvaluator", {})

function AIEvaluator.HasEnemy(control)
	local enemy = control:getEnemy()
	if not enemy then
		return false
	end
	local aiData = control:getEntity():data("aiData")
	aiData.enemy = enemy
	return true
end

function AIEvaluator.ShouldDoBehaviors(control)
	return control:aiData("bhvRunning")
end

function AIEvaluator.ShouldFollowEntity(control)
	local target = control:getFollowTarget()
	if not target then
		--Lib.logWarning("AIEvaluator.ShouldFollowEntity: not target")
		return false
	end
	local entity = control:getEntity()
	local followEntityDistanceWhenHasTarget = control:aiData("followEntityDistanceWhenHasTarget") or 5
	local followEntityDistanceWhenNotTarget = control:aiData("followEntityDistanceWhenNotTarget") or 0.5

	if target.objID == entity.objID then
		--Lib.logWarning("AIEvaluator.ShouldFollowEntity: target is self")
		return false
	end

	local ret = true
	local hasEnemy = AIEvaluator.HasEnemy(control)
	 -- 处于follow的时候，targetPos不是目标的位置，有可能是环绕的。所以需要用getTargetPos拿pos
	local targetPos = Lib.copy(control:getFollowTargetPos() or target:getPosition())
	local entityPos = Lib.copy(entity:getPosition())
	local dirY = Lib.v3cut(targetPos, entityPos).y
	if (not entity:cfg().canFly and (dirY > 0)) or ((dirY < 0) and entity.onGround) then -- 和c++判断保持一致
		targetPos.y = 0
		entityPos.y = 0
	end
	local distanceSqr = Lib.getPosDistanceSqr(entityPos, targetPos)
	local followEntityMinDistanceWhenHasTarget = control:aiData("followEntityMinDistanceWhenHasTarget") or followEntityDistanceWhenHasTarget
	local followEntityMinDistanceWhenNotTarget = control:aiData("followEntityMinDistanceWhenNotTarget") or followEntityDistanceWhenNotTarget
	local followEntityMaxDistance = followEntityDistanceWhenNotTarget
	local followEmtityMinDistance = followEntityMinDistanceWhenNotTarget
	if hasEnemy then 
		followEntityMaxDistance = followEntityDistanceWhenHasTarget
		followEmtityMinDistance = followEntityMinDistanceWhenHasTarget
	end

	if distanceSqr <= followEntityMaxDistance * followEntityMaxDistance then 
		if distanceSqr < followEmtityMinDistance * followEmtityMinDistance then 
			ret = false
		else 
			local lastState = control:getLastState()
			local lastStateName = lastState and lastState.NAME	
			if lastStateName == "AIStateFollowEntity" then 
				ret = true
			else 
				ret = false
			end
		end
	end
	return ret
end

function AIEvaluator.CanAttackEnemy(control)
	local curTime = World.Now()
	local entity = control:getEntity()
	local aiData = entity:data("aiData")
	if aiData.castableSkill and curTime - aiData.attackTime < 60 then
		local target = aiData.skillTarget
		local ret1 = target and target:isValid() and true or false
		local cfg = aiData.skillCfg
		local skill = aiData.castableSkill
		local attackDis = cfg and cfg.attackDis or skill.attackDis or 0
		ret1 = ret1 and aiData.castableSkill:canCast({
			targetID = target.objID,
			targetPos = target:getPosition(),
			startPos = entity:getPosition()
		}, entity) or false
		ret1 = ret1 and entity:distanceSqr(target) < attackDis * attackDis
		if ret1 and entity:canAttack(target) then
			return true
		end
	end
	local skill, target, packet, cfg = control:getCastableSkillAndTarget()
	if not skill or not target or not target:isValid() or not entity:canAttack(target) then
		return false
	end
	aiData.castableSkill = skill
	aiData.skillTarget = target
	aiData.skillCfg = cfg
	aiData.attackTime = curTime
	return true
end

function AIEvaluator.HasTargetPos(control)
	return control:getTargetPos() ~= nil
end

function AIEvaluator.canMoveRoute(control)
	if ((#control:aiData("route")) < 2) and (not control:aiData("forceFixedRoute")) then
		return false
	end
	local homeC = AIEvaluator.InHomeArea(control)
	local hasEnemy = AIEvaluator.HasEnemy(control)
	return homeC and not hasEnemy
end

function AIEvaluator.HasHome(control)
	return control:getEntity():data("aiData").homePos ~= nil
end

function AIEvaluator.InHomeArea(control)
	local entity = control:getEntity()
	local curPos = entity:getPosition()
	if not curPos then
		return false
	end
	local homePos = entity:data("aiData").homePos
	if not homePos then
		return true
	end
	local homeSize = control:getHomeSize()
	if not homeSize then
		return true
	end
	local lx, lz = homeSize / 2, homeSize / 2
	local dx, dz = curPos.x - homePos.x, curPos.z - homePos.z
	return -lx <= dx and dx <= lx and -lz <= dz and dz <= lz
end

function AIEvaluator.ShouldGoHome(control)
	if not AIEvaluator.InHomeArea(control) then
		return true
	end
	local entity = control:getEntity()
	local goHomeAddCondition = control:getEntityCfgValue("goHomeAddCondition")
	local lastState = control:getLastState()
	local lastStateName = lastState and lastState.NAME
	if goHomeAddCondition == "notEnemy" then
		if lastStateName == "CHASE" or lastStateName == "ATTACK" then
			return not AIEvaluator.HasEnemy(control)
		end
	end
	return false
end

function AIEvaluator.Random(control)
	return math.random() < 0.5
end

function AIEvaluator.HaveTowPoint(control)
	return control:getEntity():data("StraightPoint")
end


function AIEvaluator.True(control)
	return true
end

function AIEvaluator.False(control)
	return false
end

RETURN(AIEvaluator)
