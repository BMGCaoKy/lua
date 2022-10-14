require "common.skill.skill"
require "skill.base"
require "skill.melee_attack"
require "skill.break_block"
require "skill.place_block"
require "skill.click"
require "skill.use_item"
require "skill.charge"
require "skill.reload"
require "skill.skill_dropItem"
require "skill.skill_missile"
require "skill.fishing"
require "skill.buff"
require "skill.skill_ray"
require "skill.multistage"
require "skill.timeLine"
require "skill.skill_shoot"
require "skill.build_schematic"
require "skill.skill_float"

function Skill.DoCast(cfg, packet, from)
	if from and from.isPlayer and from:isWatch() then
		return
	end
	--if cfg.debug then
		print("server Skill.DoCast -", cfg.fullName, from and from.objID)
	--end

	local target = nil
	if packet.targetID then
		target = World.CurWorld:getObject(packet.targetID)
	end
	if packet.partID then
		if Instance and Instance.getByInstanceId then
			target = Instance.getByInstanceId(packet.partID)
		end
	end

	local context = {obj1=from, obj2=target, pos=packet.targetPos, fullName = cfg.fullName, blockPos = packet.blockPos, startPos = packet.startPos, sideNormal = packet.sideNormal}
	if packet.ownerID then
		context.owner = World.CurWorld:getObject(packet.ownerID)
	end	
	
	if packet.castByAI and packet.preSwingTime then 
		local castFunc = function()
			print("cast===============")
			if cfg:cast(packet, from) == false then
				return
			end
			Trigger.CheckTriggers(cfg, "SKILL_CAST", context)
			if from and cfg.objTrigger then
				Trigger.CheckTriggers(from:cfg(), cfg.objTrigger, context)
			end
		end
		World.Timer(packet.preSwingTime,castFunc)
	else
		if cfg:cast(packet, from) == false then
			return
		end
		
		Trigger.CheckTriggers(cfg, "SKILL_CAST", context)
		if from and cfg.objTrigger then
			Trigger.CheckTriggers(from:cfg(), cfg.objTrigger, context)
		end
	end
	packet.pid = "CastSkill"
	packet.fromID = from and from.objID
	packet.name = cfg.fullName
	if cfg.broadcast~=false then
		if from and from.isEntity then
			from:sendPacketToTracking(packet, true)
		else
			WorldServer.BroadcastPacket(packet)
		end
	elseif from.isPlayer then
		from:sendPacket(packet)
	end
	if cfg.castActionTime then
		local castActionTime = cfg.castActionTime or 20
		castActionTime = castActionTime > 0 and castActionTime or 20
		local swingTime = (cfg.preSwingTime or 0) + (cfg.backSwingTime or 0)
		if swingTime > castActionTime then 
			castActionTime = swingTime
		end
		World.Timer(castActionTime, function()
			if from:isValid() then
				Trigger.CheckTriggers(from:cfg(), "SKILL_CAST_FINISH", context)
			end
		end)
	end
end

function Skill.Cast(skillName, packet, from)
	local cfg = Skill.Cfg(skillName)
	packet = packet or {}
	if from.isPlayer then 
		packet.pid = "CastSkillSimulation"
		packet.objID = from and from.objID
		packet.name = skillName
		packet.ignoreNetDelay = true
		from:sendPacketToTracking(packet,true)
	else
		if not cfg:canCast(packet or {}, from) then
			return
		end
		packet.isCastBySever = true
		Skill.DoCast(cfg, packet or {}, from)
	end
end

function Skill.CastByClient(packet, from)
	local cfg = Skill.Cfg(packet.name, from)
	packet.cdTime = nil
	packet.autoCast = nil
	packet.ownerID = from.objID
	if packet.fromID~=from.objID then
		local world = from.world
		local entity = from
		from = nil
		while entity.rideOnId>0 do
			local idx = entity.rideOnIdx
			entity = world:getEntity(entity.rideOnId)
			if not entity then
				return
			end
			local rp = (entity:cfg().ridePos or {})[idx+1]
			if not rp or not rp.ctrl then
				return
			end
			if packet.fromID==entity.objID then
				from = entity
				break
			end
		end
		if not from then
			return
		end
	end
	packet.isTouch = packet.isTouch or (cfg.isTouch and not cfg.isClick)	-- （考虑双触发技能）
	if packet.isTouch then
		local data = from:data("skill")
		local aimPos = packet.aimPos
		packet = data.touchPacket
		if not packet or packet.name~=cfg.fullName or from.world:getTickCount()<data.touchTimeEnd-10 then
			return
		end
		packet.aimPos = aimPos
		data.touchPacket = nil
		data.touchTimeEnd = nil
	end
	if not cfg:canCast(packet, from) then
		if packet.isTouch then
			cfg:stop(packet, from)
			packet.pid = "StopSkill"
			from:sendPacketToTracking(packet, true)
		end
		return
	end
	Skill.DoCast(cfg, packet, from)
end

function Skill.StartByClient(packet, from)
	local cfg = Skill.Cfg(packet.name)
	local touchTime = cfg:getTouchTime(packet, from)
	if not touchTime or touchTime < 0 then
		return
	end
	packet.touchTime = touchTime
	cfg:start(packet, from)
	local data = from:data("skill")
	data.touchPacket = packet
	data.touchTimeEnd = touchTime + from.world:getTickCount()
	packet.pid = "StartSkill"
	packet.fromID = from.objID
	packet.isTouch = true
	local context = {obj1 = from, fullName = packet.name}
	Trigger.CheckTriggers(cfg, "SKILL_START_TOUCH", context)
	local target = packet.targetID and World.CurWorld:getEntity(packet.targetID)
	if target then
		Trigger.CheckTriggers(target:cfg(), "ENTITY_START_TOUCH", {obj1 = target, obj2 = from})
	end
	from:sendPacketToTracking(packet)
end

function Skill.SustainByClient(packet, from)
	local skillName = packet.name
	local cfg = Skill.Cfg(skillName)
	local touchTime = cfg:getTouchTime(packet, from)
	if not touchTime or touchTime < 0 then
		return
	end
	local data = from:data("skill")
	if not data.touchTimeEnd or (from.world:getTickCount()<data.touchTimeEnd-10) then
		return
	end

	Trigger.CheckTriggers(cfg, "SKILL_SUSTAIN_TOUCH", {obj1 = from, fullName = skillName})

	packet.pid = "SustainSkill"
	packet.fromID = from.objID
	packet.touchPacket = data.touchTimeEnd
	from:sendPacketToTracking(packet)
end

function Skill.StopByClient(packet, from)
	local tempPacket = packet
	local data = from:data("skill")
	local aimPos = packet.aimPos
	local dataPacket = data.touchPacket
	if not dataPacket and (not tempPacket or not tempPacket.isTouchStop) then
		return
	end
	local packet = dataPacket or tempPacket
	local cfg = Skill.Cfg(packet.name)
	packet.aimPos = aimPos
	cfg:stop(packet, from)
	if not packet.isTouchStop then 
		data.touchPacket = nil
		data.touchTimeEnd = nil
	end
	packet.pid = "StopSkill"
	packet.fromID = from.objID
	local context = {obj1 = from, fullName = packet.name}
	Trigger.CheckTriggers(cfg, "SKILL_STOP_TOUCH", context)
	local target = packet.targetID and World.CurWorld:getEntity(packet.targetID)
	if target then
		Trigger.CheckTriggers(target:cfg(), "ENTITY_STOP_TOUCH", {obj1 = target, obj2 = from})
	end
	from:sendPacketToTracking(packet)
end

function Skill.StartPreSwingByClient(packet,from)
	print("Skill.StartPreSwingByClient objID: " .. from.objID)
	local cfg = Skill.Cfg(packet.name, from)
	if cfg.preSwingTime <= 0 then
		return 
	end
	local context = {obj1=from, pos=packet.targetPos, fullName = cfg.fullName, blockPos = packet.blockPos, startPos = packet.startPos, sideNormal = packet.sideNormal}
	if packet.ownerID then
		context.owner = World.CurWorld:getObject(packet.ownerID)
	end
	Trigger.CheckTriggers(cfg, "SKILL_CAST_SWING", context)

	packet.pid = "StartPreSwing"
	from:sendPacketToTracking(packet, false)
end


function Skill.StopPreSwingByClient(packet,from)
	print("Skill.StopPreSwingByClient objID: " .. from.objID)
	local cfg = Skill.Cfg(packet.name, from)
	--packet.cdTime = nil
	--packet.autoCast = nil
	--packet.ownerID = from.objID
	packet.pid = "StopPreSwing"
	from:sendPacketToTracking(packet, false)
end

function Skill.StartBackSwingByClient(packet,from)
	print("Skill.StartBackSwingByClient objID: " .. from.objID)
	local cfg = Skill.Cfg(packet.name, from)

	if  cfg.preSwingTime <= 0 then
		return 
	end

	if not cfg.swingData[from.objID] then
		cfg.swingData[from.objID] = {}
	end

	local entitySwingData = cfg.swingData[from.objID]
	if not entitySwingData[cfg.fullName] then
		entitySwingData[cfg.fullName] = {}
	end

	local skillSwingData = entitySwingData[cfg.fullName]
	skillSwingData.stopBackSwingTick = World.CurWorld:getTickCount() + cfg.backSwingTime * 20

	--packet.cdTime = nil
	--packet.autoCast = nil
	--packet.ownerID = from.objID
	packet.pid = "StartBackSwing"
	from:sendPacketToTracking(packet, false)
end

function Skill.StopBackSwingByClient(packet,from)
	print("Skill.StopBackSwingByClient objID: " .. from.objID)
	local cfg = Skill.Cfg(packet.name, from)
	--packet.cdTime = nil
	--packet.autoCast = nil
	--packet.ownerID = from.objID
	packet.pid = "StopBackSwing"
	from:sendPacketToTracking(packet, false)
end


RETURN()
