
local SkillBase = Skill.GetType("Base")
local ClickSkill = Skill.GetType("Click")

ClickSkill.isClick = true
ClickSkill.isTouch = true

function ClickSkill:cast(packet, from)
	if from and from.isPlayer and from:isWatch() then
		return
	end
	if packet.targetID then
		local target = World.CurWorld:getEntity(packet.targetID)
		if target then
            local cfg = target:cfg()
			if packet.isTouch then
				if cfg.canTouch then
					Trigger.CheckTriggers(cfg, "ENTITY_TOUCH", {obj1=target, obj2=from})
				end
			else
				if cfg.canClick or target.canClick then
					Trigger.CheckTriggers(cfg, "ENTITY_CLICK", {obj1=target, obj2=from})
                    Trigger.CheckTriggers(from:cfg(), "CLICK_ENTITY", {obj1 = from, obj2 = target})
					local hitPos = packet.hitPos
					target:EmitEvent("OnEntityClick", from, hitPos)
					from:EmitEvent("OnClickEntity", target, hitPos)
                    from:addTarget("FindObject", target._cfg.fullName)
				end
			end
			if cfg.clickProps then
				for _, prop in pairs(cfg.clickProps) do
					if prop.func and Entity.ClickProp[prop.func] then
						Entity.ClickProp[prop.func](target, prop, from)
					end
				end
			end
		end
	elseif packet.blockPos then
		Block.Click(packet.blockPos, from)
	elseif packet.partID then
		local part = Instance.getByInstanceId(packet.partID)
		if part and part:isValid() then
			local hitPos = packet.hitPos
			part:EmitConnectEvent("PART_CLICKED", from, hitPos)
			part:EmitEvent("OnClick", from, hitPos)
			Trigger.CheckTriggers(part._cfg, "PART_CLICKED", {part1 = part, from = from})
			Trigger.CheckTriggers(from:cfg(), "CLICK_PART", {obj1 = from, partID = packet.partID})
		end
	end
	SkillBase.cast(self, packet, from)
end
