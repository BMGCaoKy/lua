require "common.dropitem"

-- local DropItem = DropItemClient
local defaultHeadTextFont = "HT24"
local defaultHeadTextOffset = {x = 0, y = 1, z = 0}
function DropItemClient.Create(objID, pos, item, moveSpeed, moveTime, guardTime)
	local model = item:model()
	if not model then
		return
	end

	local world = World.CurWorld
	local old = world:getObject(objID)
	if old then
		perror("double create dropitem", World.GameName, objID, World.CurMap and World.CurMap.id)
		old:destroy()
	end
	local itemcfg = item:cfg()
    local block_id = item:block_id()
    local blockCfg
    if block_id and block_id > 0 then
        blockCfg = Block.GetIdCfg(block_id)
    end
	local cfg = DropItem.GetCfg(itemcfg.dropitem or "/dropitem")
	local dropitem = DropItemClient.CreateDropItem(model, cfg.id, world, objID, guardTime or 0)
	dropitem:setData("item", item)
	dropitem:setData("moveSpeed", moveSpeed)
	dropitem:setData("moveTime", moveTime)
	dropitem:setMap(World.CurMap)
	local itemCfg
	if item:is_block() then
		itemCfg = item:block_cfg()
	else
		itemCfg = item:cfg()
	end
	local boundingBox = {boundingVolume = itemCfg.boundingVolume}
	dropitem:setBoundingVolume(boundingBox)
	if pos then
		dropitem:setPosition(pos)
	end
	dropitem.dropSpeed = itemcfg.dropSpeed or World.cfg.itemdropSpeed or 0.2
	local dropMatItem = itemCfg.dropMatItem or {}
	if dropMatItem then
		local scale = dropMatItem.scale or 1
		local rotate = {
			x = dropMatItem.rotateX or 0, 
			z = dropMatItem.rotateY or 0, 
			y = dropMatItem.rotateZ or 0, 
		}
		local translate = dropMatItem.translate or { x = 0, y = 0, z = 0}
		dropitem:setModelMatItem(scale, rotate, translate)
	end
	dropitem:dropEffect(itemcfg.dropEffect, itemcfg)
	dropitem.attractedLv = itemcfg.attractedLv or (blockCfg and blockCfg.attractedLv) or 0
	local blockId = item:block_id() or 0
	local blockCfg = (blockId > 0) and Block.GetIdCfg(blockId) or {}
	local dropItemHeadText = itemcfg.dropItemHeadText or blockCfg.dropItemHeadText
	if dropItemHeadText and dropItemHeadText ~= "" then
		local dropItemHeadTextFont = itemcfg.dropItemHeadTextFont or blockCfg.dropItemHeadTextFont or World.cfg.dropItemHeadTextFont or defaultHeadTextFont
		local dropItemHeadTextOffset = itemcfg.dropItemHeadTextOffset or blockCfg.dropItemHeadTextOffset or World.cfg.dropItemHeadTextOffset or defaultHeadTextOffset
		dropitem:setShowName(Lang:toText(dropItemHeadText), dropItemHeadTextFont, dropItemHeadTextOffset)
	end
	local blockId = item:block_id() or 0
	local blockCfg = (blockId > 0) and Block.GetIdCfg(blockId) or {}
	local dropItemHeadText = itemcfg.dropItemHeadText or blockCfg.dropItemHeadText
	if dropItemHeadText and dropItemHeadText ~= "" then
		local dropItemHeadTextFont = itemcfg.dropItemHeadTextFont or blockCfg.dropItemHeadTextFont or World.cfg.dropItemHeadTextFont or defaultHeadTextFont
		local dropItemHeadTextOffset = itemcfg.dropItemHeadTextOffset or blockCfg.dropItemHeadTextOffset or World.cfg.dropItemHeadTextOffset or defaultHeadTextOffset
		dropitem:setShowName(Lang:toText(dropItemHeadText), dropItemHeadTextFont, dropItemHeadTextOffset)
	end
	dropitem:onCreate()
	if (moveSpeed and (moveSpeed.x ~= 0 or moveSpeed.y ~= 0 or moveSpeed.z ~= 0)) and (moveTime and moveTime > 0) then
		dropitem:spreadMove(moveSpeed, moveTime)
	end
	return dropitem
end


function DropItemClient:preDestroyItem(reason)
    if reason == "PICKED" then 
        local cfg = self:item():cfg()
        if cfg.removeSound then
            local time = math.min(cfg.removeSound.delayTime or 1, 20)
            World.Timer(time, function()
                if self:isValid() then
                    self:playSound(cfg.removeSound)
                end
                Player.CurPlayer:playSound(cfg.removeSound, cfg)
                return false
            end)
        end

        local removeEffect = cfg.removeEffect
        local pos = self:getPosition()
        if removeEffect then
            local time = math.min(removeEffect.delayTime or 1, 20)
            World.Timer(time, function()
                local effectPathName = ResLoader:filePathJoint(cfg, removeEffect.effect)
                local time = tonumber(removeEffect.time)
                time = time and time / 20 * 1000 or -1
                Blockman.instance:playEffectByPos(effectPathName, Lib.v3add(pos, removeEffect.pos or {x = 0, y = 0, z = 0}), 0, time)
                return false
            end)  
        end
    end
end

function DropItemClient:dropEffect(effect, cfg)
	if not effect then
		return
	end
	if not effect.path then
		effect.path= ResLoader:filePathJoint(cfg, effect.effect)
	end
	self:playEffect(effect.path, effect.once, effect.time or -1, effect.pos, effect.yaw)
end

function DropItem:playPickEffect(player)
	local item = self:item()
	local cfg = item:cfg()
	self:playSound(cfg.pickSound)
	if not cfg.pickEffect then
		return
	end
	local path = "plugin/" .. cfg.plugin .. "/" .. cfg.modName .. "/" .. cfg._name .. "/" .. cfg.pickEffect
	local pos = self:getPosition()
	pos. y = pos. y + 0.5
    Blockman.instance:playEffectByPos(path, pos, 0, 1000)
end

function DropItemClient:destroy(reason)
	if self.map and (not self.map.isClosing) and self.pickedTimer then
		return
	end
    if self:item() then 
        self:preDestroyItem(reason)
    end
    Object.destroy(self)
end

function DropItemClient:updateARGBStrength()
	-- self:setARGBStrength(r, g, b, a)
end

function DropItemClient:onItemCfgChanged()
	local model = self:data("item"):model(nil, true)
	if model then
		self:changeModel(model)	
	end
end
