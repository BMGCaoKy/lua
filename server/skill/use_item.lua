
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

function UseItem:cast(packet, from)
	local cfg, sloter, hasUse
	local tid, slot = packet.tid, packet.slot
	if tid and slot then 
		local sloter = from:tray():fetch_tray(tid):fetch_item(slot)
		if sloter and sloter:cfg().fastUse then 
			cfg = sloter:cfg()
			from:useItem(tid, slot)
			hasUse = true
		end
	end

	if not hasUse then 
		sloter = from:getHandItem()
		cfg = sloter:cfg()
		tid, slot = sloter:tid(), sloter:slot()
		from:useItem(tid, slot)
	end
	if cfg.skillName then
		Skill.Cast(cfg.skillName, packet, from)
	end

	if cfg.cooldown then 
		local key = cfg.fullName
		local now = World.Now()
		local cdMap = from:data("cdMap")
		local itemCD = cdMap.itemCD
		if not itemCD then
			cdMap.itemCD = {}
			itemCD = cdMap.itemCD
		end
		local curItemCd = itemCD[key] 
		if not curItemCd then
			curItemCd = {}
			itemCD[key] = curItemCd
		end
		curItemCd.startTick = now
		curItemCd.endTick = now + cfg.cooldown
	end
	packet.itemName = cfg.fullName
	Trigger.CheckTriggers(cfg, "USE_ITEM", {obj1 = from, item = sloter, itemName = cfg.fullName})
	Trigger.CheckTriggers(from:cfg(), "ENTITY_USE_ITEM", {obj1 = from, item = sloter, itemName = cfg.fullName})
	from:EmitEvent("OnUseItem", sloter)
	SkillBase.cast(self, packet, from)
end
