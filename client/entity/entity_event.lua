local events = {}

function entity_event(entity, event, ...)
	if not string.find(entity.name, "elf") then
		--print("entity_event", entity.name, event, ...)
	end
	local func = events[event]
	if not func then
		print("no event!", event)
		return
	end
	Profiler:begin("entity_event."..event)
	func(entity, ...)
	Profiler:finish("entity_event."..event)
end

function events:playBaseActionEvent(preBaseAction, baseAction)
	--TODO
end

function events:playUpperActionEvent(preUpperAction, upperAction)
	--TODO
end

function events:onUpdateActionState()
	--TODO
end

function events:viewRangeChange(rangeSize)
	local packet = {
		pid = "SetViewRangeSize",
		objId = Me.objID,
		size = rangeSize
	}
	self:sendPacket(packet)
end

function events:onBlockChanged(oldId, newId)
	if not self.isMainPlayer then
		return
	end
	local oldCfg = Block.GetIdCfg(oldId)
	local newCfg = Block.GetIdCfg(newId)
	if not oldCfg or not newCfg then
		Lib.logError("events:onBlockChanged", "oldCfg == nil", oldCfg == nil, "newCfg == nil", newCfg == nil)
		return
	end
	if oldCfg.onBuff==newCfg.onBuff then
		return
	end
	local data = self:data("main")
	if data.blockBuff then
		self:removeClientBuff(data.blockBuff)
	end
	data.blockBuff = self:tryAddClientOnlyBuff(newCfg.onBuff)
end

function events:inBlockChanged(oldId, newId)
	local oldCfg = Block.GetIdCfg(oldId)
	local newCfg = Block.GetIdCfg(newId)
	if oldCfg.inBuff == newCfg.inBuff then
		return
	end
	local data = self:data("main")
	if data.inBlockBuff then
		self:removeClientBuff(data.inBlockBuff)
	end
	data.inBlockBuff = self:tryAddClientOnlyBuff(newCfg.inBuff)
end

function events:dropDamage(speed)
	if not self.isMainPlayer then
		return
	end
	local packet = {
		pid = "DropDamage",
		speed = speed,
	}
	self:sendPacket(packet)
end

function events:collisionEntity(objIDArray)
end

local notify = {}
function notify.ENTITY_HP_NOTIFY(add, obj1)
	if obj1.isMainPlayer and (obj1.curHp ~= obj1.maxHp) and add < 0 and obj1:cfg().damageViewBobbing then
		-- "damageViewBobbing" : [{rotate = {x = 0, y = 0, z = 10}, count = 2},{rotate = {x = 0, y = 0, z = 0}, count = 40}]
		ViewBobbingMgr.viewRotateBobbing(obj1:cfg().damageViewBobbing)
	end
end

function notify.ENTITY_VP_NOTIFY(add, obj1)
	if add == 0 then
		return
	end
	if obj1.isMainPlayer then
		Lib.emitEvent(Event.ENTITY_VP_NOTIFY, add)
	end
end

local function propNotify(event, add, obj1)
	Lib.emitEvent(Event[event], add, obj1)
	local func = notify[event]
	if func then
		func(add, obj1)
	end
end

function events:entityPropNotifyEvent(event, add)
	propNotify(event, add, self)
end

function events:moveStatusChange(entityId, newState, oldState)
	local entity = World.CurWorld:getObject(entityId)
	if not entity or not entity:isValid() or not self.isMainPlayer then
		return
	end
	entity:moveStatusChange(newState, oldState)
	Lib.emitEvent(Event.EVENT_PLAYER_MOVE_STATUS_CHANGE, newState, oldState)
	if entityId == Me.objID then
		Me:resetAutoKick()
	end
end

function events:enterRegion(id)
	-- print(Lib.v2s(World.idRegions,1))
	-- local region = assert(World.idRegions[id], id)
    -- if self.justLoginOrLogout and region.cfg.ignoreWhenLoginAndLogout then
    --     return
    -- end
	-- region:onEntityEnter(self)
	local region = World.idRegions[id]
	if region then
		region:onEntityEnter(self)
	end
end

function events:leaveRegion(id)
	-- local region = assert(World.idRegions[id], id)
    -- if self.justLoginOrLogout and region.cfg.ignoreWhenLoginAndLogout then
    --     return
    -- end
	-- region:onEntityLeave(self)
	local region = World.idRegions[id]
	if region then
		region:onEntityLeave(self)
	end
end

function events:force_meet_collidable(blockPos, objID)
	-- engine not need more, all deal in script
end
function events:entityTouchAll(entity)
	if self.isMainPlayer and entity.isClientEntity then
		self:touchClientEntity(entity)
	elseif entity.isMainPlayer and self.isClientEntity then
		entity:touchClientEntity(self)
	end

end

function events:entityApartAll(entity)
end

function events:entityEnter(entity)
	--TODO
end

function events:entityLeave(entity)
	--TODO
end

function events:entityHit(entity, hitPos, hitNormal, hitDistance)
	--TODO
end



function events:entityJumpCollided(normal, outNormal, moveRatio)

end

function events:entityTouchPartBegin(part)


end

function events:entityTouchPartUpdate(part, collidePos, normalOnSecondObject, distance)

end

function events:entityTouchPartEnd(part)


end

return events
