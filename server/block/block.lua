require "common.block"

local blockMap = T(Block, "blockMap")

function Block.Click(pos, byEntity)
	local cfg = byEntity.map:getBlock(pos)
	pos = { x = pos.x, y = pos.y, z = pos.z }
	Trigger.CheckTriggers(cfg, "BLOCK_CLICK", {obj1 = byEntity, pos = pos, map = byEntity.map })
end

function Block.doDamage(pos, damage, owner)
	if not owner or not owner.map then
		return
	end
	local cfg = owner.map:getBlock(pos)
	local data = owner.map:getOrCreateBlockData(pos)
	data.blockHp = data.blockHp == nil and (cfg.blockHp or 0) or data.blockHp
    local immue = data.immue
    if immue == nil then
		immue = {
			lastDamage = 0,
			hurtResistantTime = 0
		}
		data.immue = immue
	end
	if damage <= 0 then
		return
	end
	damage = math.ceil(damage)
	if data.blockHp <= 0 then
		return
	end
	if immue.hurtResistantTime >= World.Now() then
		if damage <= immue.lastDamage then
			return
		end
		data.blockHp = data.blockHp - (damage - immue.lastDamage)
	else
		immue.hurtResistantTime = World.Now() + (cfg.hurtResistantTime or 20)
		data.blockHp = data.blockHp - damage
	end
	immue.lastDamage = damage
	if data.blockHp <= 0 then
		Block.onDead(pos, owner)
	end
end

function Block.onDead(pos, owner)
    local blockcfg = owner.map:getBlock(pos)
    Trigger.CheckTriggers(blockcfg, "BLOCK_DEAD",{pos = pos, obj1 = owner, map = owner.map})
end

local canPutInWater = World.cfg.canBlockPutInWater
local canPutInLava = World.cfg.canBlockPutInLava
function Block.onPlaceBlock(cfg, packet, from)
	local pos
	local blockId = from.map:getBlockConfigId(packet.blockPos)
	if (canPutInWater and WaterMgr.IsWater(blockId)) or (canPutInLava and LavaMgr.IsLava(blockId)) then
		pos = packet.blockPos
	else
		pos = Lib.v3add(packet.blockPos, packet.sideNormal)
	end

    local id = cfg.id
    if cfg.canRotate then
        id = Block.onRotate(cfg, packet, from)
    end

	-- todo: check
	local oldId = from.map:getBlockConfigId(pos)
	local class = blockMap[cfg.blockType]
	if class and class.onPlaceBlock then
		class.onPlaceBlock(cfg, packet, from, pos, id)
	else
		-- from.map:setBlockConfigId(pos, id)
		local BlockAdapt = require "common.blockAdapt"
		BlockAdapt.SetBlockConfigIdAdapt({
			map = from.map, pos = pos, tId = id, fromYaw = from:getRotationYaw(), 
			hitSideNormal = packet.sideNormal or {x = 0, y = 1, z = 0}, isUp = packet.isUp
		})
	end
	Trigger.CheckTriggers(Block.GetIdCfg(oldId), "BLOCK_REPLACED", {obj1=from, pos=pos})
	Trigger.CheckTriggers(cfg, "BLOCK_PLACE", {obj1=from, pos=pos})

	CombinationBlock:placeBlock(cfg, pos, from.map)

	--Lib.logDebug("Block.onPlaceBlock", packet.sideNormal.x, packet.sideNormal.y, packet.sideNormal.z)
end

function Block.onBreakBlock(cfg, packet, from, pos)
	local class = blockMap[cfg.blockType]
	if class and class.onBreakBlock then
		class.onBreakBlock(cfg, packet, from, pos)
	end
end

function Block.onRotate(cfg, packet, from)
	return cfg.id
end

function Block.onDrop(cfg, packet, from, pos)
	if cfg.dropSelf or cfg.dropBlock then
		local item_pos = {
			x = pos.x + 0.1 + math.random() * 0.8,
			z = pos.z + 0.1 + math.random() * 0.8,
			y = pos.y + 0.8
		}
		local item = Item.CreateItem("/block", cfg.dropCount or 1, function(item)
			item:set_block_id(cfg.dropBlock and Block.GetNameCfgId(cfg.dropBlock) or cfg.id)
		end)
		DropItemServer.Create({ map = from.map, pos = item_pos, item = item, lifeTime = cfg.droplifetime })
	end
	if cfg.dropItem then
		for _, val in pairs(cfg.dropItem) do
			local item_pos = {
				x = pos.x + 0.5 + (math.random()-0.5) * #cfg.dropItem,
				y = pos.y + 0.8,
				z = pos.z + 0.5 + (math.random()-0.5) * #cfg.dropItem
			}
			local item = Item.CreateItem(val.item, val.count)
			DropItemServer.Create({ map = from.map, pos = item_pos, item = item })
		end
	end
end

function Block.onWaterFlow(map, pos)
	--TODO
end

function Block.onLavaFlow(map, pos)
	--TODO
end
--Block.InitCfg(false)