---@type SkillBase
local SkillBase = Skill.GetType("Base")

local consume = {}

local function doConsume(from, consumeItem, check)
	local ret = true
	if type(consumeItem) == "table" and #consumeItem > 0 then
		for _,i in pairs(consumeItem) do
			ret = consume:consumeItem(from, i, check)
			if not ret then
				goto continue
			end
		end
	else
		ret = consume:consumeItem(from, consumeItem, check)
	end
	:: continue ::
	return ret
end

function SkillBase:getTouchTime(packet, from)
	return packet.touchTime	-- todo: check
end

function SkillBase:extCheckConsume(packet, from)
	local consumeItem = self.consumeItem
	if consumeItem then
		local ret = doConsume(from, consumeItem, true)
		if not ret then
			return false
		end
	end
	return true
end

function SkillBase:extDoConsume(packet, from)
	local consumeItem = self.consumeItem
	if consumeItem then
		local ret = doConsume(from, consumeItem)
		if not ret then
			return false
		end
	end
	local consumeVp = self:getVpConsume()
	if consumeVp > 0 then
		from:addVp(-consumeVp)
	end
end

function SkillBase:takeContainer(packet, from)
	local container = self.container
	local currentCapacity = self:getContainerVar(from, true)
	if not currentCapacity then
		return
	end
	currentCapacity = currentCapacity - (container.takeNum or 1)
	self:setCurrentCapacity(from, currentCapacity)
end

function consume:consumeItem(from, consumeItem, check)
	if World.cfg.unlimitedRes then
		return true
	end
	local ifTable = type(consumeItem) == "table"
	local consumeName = ifTable and consumeItem.consumeName or consumeItem
	local count = ifTable and consumeItem.count or 1
	local item = Item.CreateItem(consumeName)
	if item and item:use_buff() and not check then
		local useBuff = item:use_buff()
		from:addBuff(useBuff.cfg, useBuff.time)
	end
	local ret = from:tray():remove_item(consumeName, count, check, false, consumeName == "/block" and function(item)
		local setting = require "common.setting"
		return item:block_id() == setting:name2id("block", consumeItem.consumeBlock)
	end, "skill_consume")

    return ret
end