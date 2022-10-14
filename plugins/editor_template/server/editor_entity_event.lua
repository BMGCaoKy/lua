
local events = require "server.entity.entity_event"

function events:inBlockChanged(oldId, newId)
	Trigger.CheckTriggers(self:cfg(), "IN_BLOCK_CHANGED", {obj1 = self, oldId = oldId, newId = newId})
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