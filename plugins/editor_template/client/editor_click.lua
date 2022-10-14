local SkillBase = Skill.GetType("Base")
local ClickSkill = Skill.GetType("Click")

local function playAction(from, action, time, isResetAction)
	if from:data("reload").reloadTimer and action ~= "idle" and action ~= "" then
		return
	end
	if from and from.isEntity and action and action~="" then
		from:updateUpperAction(action, time, isResetAction)
	end
end

local function canLongTouch(self, packet, from)
	local target = packet.targetID and World.CurWorld:getEntity(packet.targetID)
	if not target then
		return false
	end
	local targetCfg = target:cfg()
	if targetCfg.canlongTouch then
		local item = from:getHandItem()
		local base_ = item and item:cfg()["base"]
		local base = targetCfg.base
		local sameTeam = target and (target:getValue("teamId") == from:getValue("teamId"))
		if (base == "base_revive" and base_ ~= "tool_base" ) or sameTeam then
			return false
		end
		return true
	else
		return false
	end
end

function ClickSkill:start(packet, from)
	if from:isControl() then
		local item = from:getHandItem()
		local target = packet.targetID and World.CurWorld:getEntity(packet.targetID)
		local sameTeam = target and (target:getValue("teamId") == from:getValue("teamId"))
		if item and item:cfg()["base"] == "tool_base" and not sameTeam then
			Lib.emitEvent(Event.EVENT_BREAK_BLOCK_UI_MANAGE, true, packet.touchTime)
		end
	end
	SkillBase.start(self, packet, from)
	if packet.touchTime then
		if canLongTouch(self, packet, from) then
			SkillBase.sustain(self, packet, from)
		else
			playAction(from, self.stopAction or "idle", 0)
		end
	end
end


function ClickSkill:stop(packet, from)
	Lib.emitEvent(Event.EVENT_BREAK_BLOCK_UI_MANAGE, false)
	SkillBase.stop(self, packet, from)
end