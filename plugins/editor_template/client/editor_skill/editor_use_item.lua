
local SkillBase = Skill.GetType("Base")
local UseItem = Skill.GetType("UseItem")

function UseItem:canCast(packet, from)
	local cfg
	local tid, slot = packet.tid, packet.slot
	if tid and slot then 
		local item = from:tray():fetch_tray(tid):fetch_item(slot)
		if item and item:cfg().fastUse then 
			cfg = item:cfg()
		end
	end

	if not cfg then 
		local sloter = from:getHandItem()
		if not sloter then
			return false
		else
			tid, slot = sloter:tid(), sloter:slot()
			cfg = sloter:cfg()
		end
	end
	
	if cfg.cooldown then 
		local itemCD = from:data("cdMap").itemCD or {}
		local tb = itemCD[cfg.fullName]
		if tb and tb.endTick and tb.endTick > World.Now() then 
			return false
		end
	end

	return SkillBase.canCast(self, packet, from)
end