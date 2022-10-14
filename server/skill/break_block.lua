
local SkillBase = Skill.GetType("Base")
local BreakBlock = Skill.GetType("BreakBlock")

BreakBlock.isTouch = true

function BreakBlock:canCast(packet, from)
	if from and from.isPlayer and from:isWatch() then
		return false
	end
	if not SkillBase.canCast(self, packet, from) then
		return false
	end
	local pos =  packet.blockPos or packet.targetPos
	if not pos then
		return false
	end
	local region, oo = from.map:getRegionValue(pos, "blockOperationOwnerOnly")
	if oo and not region:isOwner(from) then
		from:sendTip(3, "block_operation_owner_only", 40)
		return false
	end
	local map = from.map
	local cfg = map:getBlock(pos)
	if cfg.id <= 0 then --break the block at the same time
		return false
	end
	if cfg.canBreak == false then
		return false
	end
	return true
end


function BreakBlock:cast(packet, from)
	local pos = packet.blockPos or packet.targetPos --can casted by missile
	if not pos then
		return
	end
	local map = from.map
	local cfg = map:getBlock(pos)
	if cfg.canBreak == false then-- check cast by server
		return
	end
	local context = {obj1=from, pos=pos, map = map, canBreak = true}
	Trigger.CheckTriggers(cfg, "BLOCK_BREAK", context)

	if context.canBreak == false then
		return
	end

	if map then
		map:removeBlock(pos)
	end

	if cfg.recycle then
		local createBlockPos = Lib.copy(pos)
		World.Timer(cfg.recycleTime or 20, function()
			if map and map:isValid() then
				map:createBlock(createBlockPos, cfg.fullName)
			end
		end)
	end
	Block.onDrop(cfg, packet, from, pos)

	Block.onBreakBlock(cfg, packet, from, pos)

	SkillBase.cast(self, packet, from)
    CombinationBlock:breakBlock(cfg, pos, from.map)
end
