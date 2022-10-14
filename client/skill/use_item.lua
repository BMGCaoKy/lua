
local SkillBase = Skill.GetType("Base")
local UseItem = Skill.GetType("UseItem")

UseItem.isTouch = true
UseItem.castAction = "eat"
UseItem.castActionTime = 40
function UseItem:getTouchTime(packet, from)
	local sloter = self:getSloter(packet, from)
	if not sloter then
		return false
	end
	if not sloter:can_use() then
		return false
	end
	
	return sloter:use_time() or 40
end

function UseItem:getSoundCfg(packet,soundName,from)
	local sloter = self:getSloter(packet, from)
	if sloter and (soundName == "castSound" or soundName == "useSound") then
		return sloter:cfg(), sloter:cfg()[soundName]
	end
	return SkillBase.getSoundCfg(self, packet, soundName, from)
end

function UseItem:getSloter(packet, from)
	local tid = packet.tid
	local slot = packet.slot
	local sloter = from:getHandItem()
	if tid and slot and from.objID == Me.objID then
		sloter = from:tray():fetch_tray(tid):fetch_item(slot)
		packet.itemFullName = sloter and sloter:cfg().fullName
	elseif packet.itemFullName then
		sloter = Item.CreateItem(packet.itemFullName, 1)
	end
	return sloter
end

function UseItem:start(packet, from)
	local sloter = self:getSloter(packet, from)
	if sloter then
		self.startAction = sloter:cfg().startAction or  self.startAction
		packet.touchActionTime = sloter:cfg().touchActionTime
		local fullName
		if sloter:is_block() then
			fullName = sloter:block_name()
		else
			fullName = sloter:full_name()
		end
		packet.itemName = fullName
	end
	SkillBase.start(self, packet, from)
end

function UseItem:preCast(packet, from)
	local sloter = self:getSloter(packet, from)
	if sloter then
		local sloterCfg = sloter:cfg()
		self.castActionTime = sloterCfg.useTime or self.castActionTime
		self.castAction = sloterCfg.useAction or  self.castAction
		self.startAction = sloterCfg.startAction or  self.startAction
		if sloterCfg.aimTarget then
			packet.aimPos = Lib.getRayTarget()
		end
	end
	SkillBase.preCast(self, packet, from)
end

local itemCD = {}
local function checkSloterCd(sloter, itemName, from)
	if not sloter and not itemName then
		return
	end
	if from.objID ~= Me.objID then
		return
	end
	local cfg = (sloter and sloter:cfg()) or (itemName and Item.CreateItem(itemName):cfg())
	local cd = cfg.cooldown
	if not cd then 
		return 
	end
	local key = cfg.fullName
	local now = World.Now()
	local curItemCd = itemCD[key] 
	if not curItemCd then
		curItemCd = {}
		itemCD[key] = curItemCd
	end
	curItemCd.startTick = now
	curItemCd.endTick = now + cd
	from:data("cdMap").itemCD = itemCD
	Lib.emitEvent(Event.EVENT_UPDATE_ITEM_CD_MASK, itemCD)
end

function UseItem:cast(packet, from)
	local sloter = self:getSloter(packet, from)
    checkSloterCd(sloter, packet.itemName,from)
	from:EmitEvent("OnUseItem", sloter)
    SkillBase.cast(self, packet, from)
end