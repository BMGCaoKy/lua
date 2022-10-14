
local Region = World.Region
local RegionCamera = require "world.region.region_camera"
local eventRegionMap = {
	["camera"] = RegionCamera
}

function Region:findTargetTypeRegion()
	local cfg = self.cfg
	local type = cfg.type
	if not type then
		return
	end
	return eventRegionMap[type]
end

local function calcAddRegionBuff(entity, self)
	local buffCfg = self.cfg.ownerBuffCfg
	if not buffCfg or not self:isOwner(entity) then
		buffCfg = self.cfg.buffCfg
	end
	if buffCfg then
		local regionBuff = entity:data("regionBuff")
		assert(not regionBuff[self.key], self.cfg.fullName)
		regionBuff[self.key] = entity:tryAddClientOnlyBuff(buffCfg)
	end
end

function Region:onEntityEnter(entity)
	calcAddRegionBuff(entity, self)
	local targetRegion = self:findTargetTypeRegion()
	if not targetRegion then
		return
	end
	targetRegion:onEntityEnter(entity, self.cfg)
end

local function calcRemoveRegionBuff(entity, self)
	local regionBuff = entity:data("regionBuff")
	local buff = regionBuff[self.key]
	if buff then
		regionBuff[self.key] = nil
		entity:removeClientBuff(buff)
	end
end

function Region:onEntityLeave(entity)
	calcRemoveRegionBuff(entity, self)
	local targetRegion = self:findTargetTypeRegion()
	if not targetRegion then
		return
	end
	targetRegion:onEntityLeave(entity, self.cfg)
end

