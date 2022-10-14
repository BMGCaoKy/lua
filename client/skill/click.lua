
local SkillBase = Skill.GetType("Base")
local ClickSkill = Skill.GetType("Click")

ClickSkill.isClick = true
ClickSkill.isTouch = true

function ClickSkill:canCast(packet, from)
	if from and from.isPlayer and from:isWatch() then
		return false
	end
	if packet.targetID then
		local target = World.CurWorld:getEntity(packet.targetID)
		local targetCfg = target:cfg()
		if not (targetCfg.canClick or target.canClick) and not targetCfg.canTouch and not World.cfg.enableShowEditEntityPosRot then
			return false
		end
		if targetCfg.clickDistance then
			if from:distance(target) > targetCfg.clickDistance then
				return false
			end
		end
		if targetCfg.checkCanCastClick and target.checkCanCastClick then
			if not target:checkCanCastClick(packet, from) then
				return false
			end
		end
	elseif packet.blockPos then
		local blockPos = packet.blockPos
		local block = from.map:getBlock(blockPos)
		if not block.canClick then
			return false
		end
		local clickDis = block.clickDistance
		local getPosDis = Lib.getPosDistance
		if clickDis and getPosDis(from:getPosition(), blockPos) > clickDis then
			return false
		end
	elseif packet.partID then
		--todo
	else
		--clickAirCast:check can cast when click the air
		return self.clickAirCast and SkillBase.canCast(self, packet, from) or false
	end
	return SkillBase.canCast(self, packet, from)
end

function ClickSkill:getTouchTime(packet, from)
	if not SkillBase.canCast(self, packet, from) then
		return nil
	end
	local cfg = nil
	if packet.targetID then
		cfg = World.CurWorld:getEntity(packet.targetID):cfg()
	elseif packet.blockPos then
		cfg = from.map:getBlock(packet.blockPos)
	elseif packet.partID then
		if Instance and Instance.getByInstanceId then
			local part = Instance.getByInstanceId(packet.partID)
			cfg = (part and part.properties) and part.properties or { canTouch = true }
		end
	else
		return nil
	end
	if not cfg.canTouch then
		return nil
	end
	return cfg.touchTime or 20
end

function ClickSkill:cast(packet, from)
	local target = from
	if self.target~="self" then
		target = World.CurWorld:getEntity(packet.targetID)
	end
	if target then
		local cfg = target:cfg()
		if cfg.canClick or target.canClick then
			if World.cfg.enableShowEditEntityPosRot and from.isMainPlayer then
				if UI:isOpen("editEntityPosRot") then
					UI:getWnd("editEntityPosRot", true):onReload(packet.targetID)
				else
					UI:openWnd("editEntityPosRot", packet.targetID)
				end
			end
			if cfg.editContainer then
				Lib.emitEvent(Event.EVENT_UI_EDIT_UPDATE_EDIT_CONTAINER, packet.targetID, true)
			end
			local hitPos = packet.hitPos
			target:EmitEvent("OnEntityClick", from, hitPos)
			from:EmitEvent("OnClickEntity", target, hitPos)
		end
		if cfg.clickProps then
			for _, prop in pairs(cfg.clickProps) do
				if prop.func and Entity.ClickProp[prop.func] then
					Entity.ClickProp[prop.func](target, prop, from, true)
				end
			end
		end
		Lib.emitEvent(Event.EVENT_OBJECT_CLICK, target, from)
	elseif packet.partID then
		local part = Instance.getByInstanceId(packet.partID)
		if part and part:isValid() then
			local hitPos = packet.hitPos
			part:EmitEvent("OnClick", from, hitPos)
		end
	else
		print("client click wrong target!", packet.targetID)
		return
	end

	SkillBase.cast(self, packet, from)
end
