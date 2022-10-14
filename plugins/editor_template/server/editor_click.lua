
local SkillBase = Skill.GetType("Base")
local ClickSkill = Skill.GetType("Click")

ClickSkill.isClick = true
ClickSkill.isTouch = true

function ClickSkill:cast(packet, from)
	if packet.targetID then
		local target = World.CurWorld:getEntity(packet.targetID)
		if target then
            local cfg = target:cfg()
			if packet.isTouch then
				if cfg.canTouch then
					Trigger.CheckTriggers(cfg, "ENTITY_TOUCH", {obj1=target, obj2=from})
				end
			else
				if target and (target:getValue("teamId") == from:getValue("teamId")) then
					local item = from:getHandItem()
					local blockId = item and item:block_id()
					local blockCfg = blockId and Block.GetIdCfg(blockId)
					if blockCfg and blockCfg.fullName == "myplugin/defenceTower" then 
						local pos = target:getPosition()
						pos.x = math.floor(pos.x)
						pos.y = math.floor(pos.y)
						pos.z = math.floor(pos.z)
						from.map:setBlockConfigId(pos, blockId)
						Trigger.CheckTriggers(blockCfg, "BLOCK_PLACE", {obj1=from, pos=pos})
					end
				end

				if cfg.canClick or target.canClick then
					Trigger.CheckTriggers(cfg, "ENTITY_CLICK", {obj1=target, obj2=from})
                    Trigger.CheckTriggers(from:cfg(), "CLICK_ENTITY", {obj1 = from, obj2 = target})
                    from:addTarget("FindObject", cfg.fullName)
				end
			end
		end
	elseif packet.blockPos then
		Block.Click(packet.blockPos, from)
	end
	SkillBase.cast(self, packet, from)
end
