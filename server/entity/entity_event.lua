local events = {}

function entity_event(entity, event, ...)
	if event ~= "ai_event" then
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

function events:step(pos)

end

function events:ai_event(event, ...)
	self:getAIControl():ai_event(event, ...)
end

function events:onBlockChanged(oldId, newId)
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
	local buff = data.blockBuff
	if buff then
		self:removeBuff(buff)
		data.blockBuff = nil
	end
	if newCfg.onBuff then
		data.blockBuff = self:addBuff(newCfg.onBuff)
	end
end

function events:inBlockChanged(oldId, newId)
	local oldCfg = Block.GetIdCfg(oldId)
	local newCfg = Block.GetIdCfg(newId)
	if oldCfg.inBuff == newCfg.inBuff then
		return
	end
	local data = self:data("main")
	local buff = data.inBlockBuff
	if buff then
		self:removeBuff(buff)
		data.inBlockBuff = nil
	end
	if newCfg.inBuff then
		data.inBlockBuff = self:addBuff(newCfg.inBuff)
	end
end

function events:dropDamage(speed)
	self:doDropDamage(speed)
end

function events:enterRegion(id)
	local region = assert(World.idRegions[id], id)
    if self.justLoginOrLogout and region.cfg.ignoreWhenLoginAndLogout then
        return
    end
	region:onEntityEnter(self)
end

function events:leaveRegion(id)
	local region = assert(World.idRegions[id], id)
    if self.justLoginOrLogout and region.cfg.ignoreWhenLoginAndLogout then
        return
    end
	region:onEntityLeave(self)
end

local function collisionEntityTypeFunc(collisionType, obj1, obj2)
	local cfg1 = obj1 and obj1:cfg() 
	local cfg2 = obj2 and obj2:cfg()
	Trigger.CheckTriggers(cfg1, collisionType, {obj1 = obj1, obj2 = obj2})
	Trigger.CheckTriggers(cfg2, collisionType, {obj1 = obj2, obj2 = obj1})
end

local function collisionBlockTypeFunc(collisionType, map, pos, obj1)
	local blockCfg = map:getBlock(pos)
	local obj1Cfg = obj1 and obj1:cfg() 
	Trigger.CheckTriggers(blockCfg, collisionType, { pos = pos, obj1 = obj1})
	Trigger.CheckTriggers(obj1Cfg, collisionType, { pos = pos, obj1 = obj1})
end

function events:collisionBlock(collisionType, pos, targetID)
	--local cfg,object
	local map = self.map
	-- object = World.CurWorld:getObject(targetID)
	collisionBlockTypeFunc(collisionType, map, pos, self)
end

function events:collisionEntity(objIDArray)
	for _, id in ipairs(objIDArray) do
		local object = World.CurWorld:getObject(id)
		collisionEntityTypeFunc("ENTITY_TOUCH_ALL", object, self)
	end
end

local function propNotify(event, add, obj1)
	local notify = {}
	function notify.ENTITY_HP_NOTIFY(add, obj1)
	end
	function notify.ENTITY_VP_NOTIFY(add, obj1)
		local curVp = obj1.curVp
		local maxVp = obj1:prop("maxVp")
		local old = curVp - add
		local upValue = maxVp * 0.9
		local downValue = maxVp * 0.3

		if curVp <= downValue then
			if add < 0 and curVp < 1e-8 then
				Trigger.CheckTriggers(obj1:cfg(), "ENTITY_VP_EMPTY", {obj1 = obj1})
			end
			if old > downValue and obj1.movingStyle == 2 then
				Trigger.CheckTriggers(obj1:cfg(), "ENTITY_VP_FORBID_SPRINT", {obj1 = obj1})
			end
		elseif (old == maxVp or old < upValue) and curVp >= upValue then
			Trigger.CheckTriggers(obj1:cfg(), "ENTITY_VP_RECOVERY_HP", {obj1 = obj1})
		end
	end
	local func = notify[event]
	if func and add ~= 0 then
		Trigger.CheckTriggers(obj1 and obj1:cfg(), event, {obj1 = obj1, add = add})
		func(add, obj1)
	end
end

function events:entityPropNotifyEvent(event, add)
	propNotify(event, add, self)
end

function events:moveStatusChange(entityId, newState, oldState)
	local entity = World.CurWorld:getObject(entityId)
	if not entity or not entity:isValid() then
		return
	end
	entity:moveStatusChange(newState, oldState)
end

function events:force_meet_collidable(blockPos, objID)
	-- engine not need more, all deal in script
end

function events:onPlayerTrackedOrNot(state)
	if state then 
		Trigger.CheckTriggers(self:cfg(), "TRACKED_PLAYER", {obj1 = self})
	else
		Trigger.CheckTriggers(self:cfg(), "UNTRACKED_PLAYER", {obj1 = self})
	end
end

local localSaveChunkPosArr = {}
function events:renderRangeChange(minRenderChunkPos, maxRenderChunkPos)
	local map = self.map
	if not map then
		return
	end
	MapChunkMgr.renderRangeChange(map, self, minRenderChunkPos, maxRenderChunkPos)
end

function events:entityTouchAll(entity)
	Trigger.CheckTriggersOnly(self:cfg(), "ENTITY_TOUCH_ALL", {obj1 = self, obj2 = entity})
	Trigger.CheckTriggersOnly(entity:cfg(), "ENTITY_TOUCH_ALL", {obj1 = entity, obj2 = self})
	self:EmitEvent("OnCollisionBegin", entity)
	entity:EmitEvent("OnCollisionBegin", self)
end

function events:entityApartAll(entity)
	Trigger.CheckTriggersOnly(self:cfg(), "ENTITY_APART", {obj1 = self, obj2 = entity})
	Trigger.CheckTriggersOnly(entity:cfg(), "ENTITY_APART", {obj1 = entity, obj2 = self})
	self:EmitEvent("OnCollisionEnd", entity)
	entity:EmitEvent("OnCollisionEnd", self)
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
	--TODO
end

function events:blockApart(blockPos)
	local map = self.map
	local cfg = Block.GetIdCfg(map:getBlockConfigId(blockPos))
	Trigger.CheckTriggers(cfg, "BLOCK_APART", {obj1 = self, pos = blockPos})
end

function events:blockTouch(blockPos)
	local map = self.map
	local cfg = Block.GetIdCfg(map:getBlockConfigId(blockPos))
	Trigger.CheckTriggers(cfg, "BLOCK_TOUCH", {obj1 = self, pos = blockPos})
end

function events:entityTouchPartBegin(part)
	Trigger.CheckTriggers(self:cfg(), "ENTITY_TOUCH_PART_BEGIN", {obj1 = self, part = part})
	self:EmitEvent("OnCollisionBegin", part)
end

function events:entityTouchPartUpdate(part, collidePos, normalOnSecondObject, distance)

end

function events:entityTouchPartEnd(part)
	Trigger.CheckTriggers(self:cfg(), "ENTITY_TOUCH_PART_END", {obj1 = self, part = part})
	self:EmitEvent("OnCollisionEnd", part)
end

return events