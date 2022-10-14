local SkillBase = Skill.GetType("Base")
local BreakBlock = Skill.GetType("BreakBlock")

function BreakBlock:canCast(packet, from)
	if not SkillBase.canCast(self, packet, from) then
		return false
	end
	if Game.GetState() ~= "GAME_GO" then
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
	if cfg.blockType and (cfg.blockType == "water" or cfg.blockType == "lava") then
		return false
	end
	local context = {pos = pos, map = map, canBreak = true}
	Trigger.CheckTriggers(nil, "BLOCK_CAN_BREAK", context)
	if not context.canBreak then
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
    
    local breakBlockVpConsume = from:prop("breakBlockVpConsume")
    from:addVp(-breakBlockVpConsume)
    
    Trigger.CheckTriggers(cfg, "BLOCK_BREAK", {obj1=from, pos=Lib.copy(pos), map = map})
    Trigger.CheckTriggers(nil, "BLOCK_BREAK_DROP_ITEM", {obj1=from, pos=Lib.copy(pos), dropItemList = cfg.dropItemList})
    local blockdata
    if map then
        blockdata = map:getBlockData(pos)
        map:removeBlock(pos, from)
    end
    if blockdata then
        for posKey, _ in pairs(blockdata.pendant or {}) do
            local ret = Lib.splitString(posKey, ":")
            local blockPos = Lib.v3(tonumber(ret[1]), tonumber(ret[2]), tonumber(ret[3]))
            Skill.Cast("/break", {blockPos = blockPos}, from)
        end
    end

    if cfg.recycle then
        local createBlockPos = Lib.copy(pos)
        World.Timer(cfg.recycleTime or 20, function()
            if map and map:isValid() then
                map:createBlock(createBlockPos, cfg.fullName)
            end
        end)
    end
    if cfg.dropSelf then
        pos.x = pos.x + 0.1 + math.random() * 0.8
        pos.z = pos.z + 0.1 + math.random() * 0.8
        pos.y = pos.y + 0.8
        local item = Item.CreateItem("/block", cfg.dropCount or 1, function(item)
            item:set_block_id(cfg.id)
        end)
        DropItemServer.Create({map = from.map, pos = pos, item = item, lifeTime = cfg.droplifetime})
    elseif cfg.dropItem then
        for _, val in pairs(cfg.dropItem) do
            local item_pos = {
                x = pos.x + 0.5 + (math.random()-0.5) * #cfg.dropItem,
                y = pos.y + 0.8,
                z = pos.z + 0.5 + (math.random()-0.5) * #cfg.dropItem
            }
            local item = Item.CreateItem(val.item, val.count, val.item == "/block" and function(item)
                item:set_block(val.block)
            end)
            DropItemServer.Create({map = from.map, pos = item_pos, item = item})
        end
    end

    SkillBase.cast(self, packet, from)
    CombinationBlock:breakBlock(cfg, pos, from.map)
end
