local misc = require "misc"
require "common.missile"

-- Create供公共代码调用，故写在Missile上
function Missile.Create(cfgName, params)
    local cfg = Missile.GetCfg(cfgName)
	local world = World.CurWorld
	local missile = MissileServer.CreateMissile(cfg.id, world)
	missile:initCommon(params)
	return missile
end

function MissileServer:initData()
	Object.initData(self)
	self.vars = Vars.MakeVars("missile", self:cfg())
end

function MissileServer:onHitEntity()
	local cfg = self:cfg()
	local target = self:lastHitEntity()
	if not target then
		return
	end
	local id = self.params.fromID
    local owner = id and self.world:getObject(id)
	Trigger.CheckTriggers(target:cfg(), "ENTITY_HITTED", {obj1=target,obj2=owner,missile=self})
	Trigger.CheckTriggers(cfg, "HIT_ENTITY", {obj1=target,obj2=owner,missile=self})
	if owner then
		Trigger.CheckTriggersOnly(owner:cfg(), "HIT_ENTITY", {obj1=owner,obj2=target,missile=self})
	end
	Missile.onHitEntity(self)
end

function MissileServer:onHitPart()
	local cfg = self:cfg()
	local part = self:lastHitPart()
	if not part then
		return
	end
	local formId = self.params.fromID
	local owner = formId and self.world:getObject(formId)
	Trigger.CheckTriggers(part._cfg, "PART_HITTED", {part1 = part, obj2 = owner, missile = self})
	Trigger.CheckTriggers(cfg, "HIT_PART", {part1 = part, obj2 = owner, missile = self})
	if owner then
		Trigger.CheckTriggersOnly(owner:cfg(), "HIT_PART", {obj1 = owner, part2 = part, missile = self})
	end
end

function MissileServer:onHitBlock()
	local cfg = self:cfg()
	local pos = self:lastHitBlock()
    local blockcfg = self.map:getBlock(pos)
    local id = self.params.fromID
    local owner = id and self.world:getObject(id)
	Trigger.CheckTriggers(blockcfg, "BLOCK_HITTED", {pos=pos,obj1=owner,missile=self})
	if owner then
		Trigger.CheckTriggers(cfg, "HIT_BLOCK", {pos=pos,obj1=owner,missile=self})
		Trigger.CheckTriggersOnly(owner:cfg(), "HIT_BLOCK", {pos=pos,obj1=owner,missile=self})
	end
    Missile.onHitBlock(self)
end

function MissileServer:playSound(sound)
end

---@param packet PidPacket
function MissileServer:sendPacketToTracking(packet)
	local pid = packet.pid
	packet = Packet.Encode(packet)
	local data = misc.data_encode(packet)
	local count = self:sendScriptPacketToTracking(data)
	World.AddPacketCount(pid, #data, true, count)
end