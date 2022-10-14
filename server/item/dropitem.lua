local misc = require "misc"
require "common.dropitem"

local AURA_MASK = Object:getTypeMask({"EntityServerPlayer"})

function DropItemServer:canPicked(entity)
	return true
end

function DropItemServer:canBePicked(entity)	
	local item = self:item()
	local cfg = item._item_data._cfg

	local ownerId = self:data("ownerId")
	local owner = ownerId and World.CurWorld:getEntity(ownerId)
	if cfg.dropOwn and owner and ownerId ~= entity.objID then
		local ownerTeamId = owner:getValue("teamId")
		if ownerTeamId == 0 or not cfg.friendlyDrop or (entity:getValue("teamId") ~= ownerTeamId) then
			Trigger.CheckTriggers(entity:cfg(), "DROPITEM_WARNING", {obj1 = entity, item = item})
			return false
		end
	end

	local proc
	if item:is_block() then
		local blockName = item:block_name()
		proc = 	function(inItem)
					inItem:set_block(blockName)
				end
	end

	if not entity:tray():add_item(cfg.fullName, item:stack_count(), proc, true) then
		if entity.isPlayer then
			entity:sendPacket({
				pid = "ShowTip",
				tipType = 1,
				keepTime = 60,
				textKey = "pick_drop_item_fail_with_tray_full",
			})
		end
		return false
	end
	return true
end

function DropItemServer:checkPickDropItem(checkEntitys)
	if not checkEntitys[1] or self.isPick then
		return
	end
	for _, entity in ipairs(checkEntitys) do
		if self ~= entity and entity:canPickDropItem(self) and self:canPicked(entity) and self:canBePicked(entity) then
			local context = {obj1 = entity, canPick = true, item = self:item(), dropItem = self}
			Trigger.CheckTriggersOnly(entity:cfg(), "PRE_CHECK_PICK_ITEM", context)
			if context.canPick then
				local packet = {
					pid = "PickDropItem",
					dropItemId = self.objID,
					pickEntityId = entity.objID,
				}
				entity:sendPacketToTracking(packet, true)
				-- entity:pickItem({objID = self.objID})
				self.isPick = true
				self:pick(entity)
				return
			end
		end
	end
end

function DropItemServer:createPickSphere(params)
	local guardTime = params.guardTime or World.cfg.dropItemGuardTime or 0
	self.pickTime = World.Now() + guardTime
	self:timer(guardTime, function()
		local range = math.floor((self:item():cfg().pickedRadius or World.cfg.pickedRadius or 2) / 1)
		self.auraId = range
		self:createObjectSphere(range, range, math.min(range*1.2, range + 1.5) ,AURA_MASK, {x = 0, y = 0, z = 0})
		self:checkPickDropItem(self:getObjectSphereInside(range))
	end)
end

function DropItemServer:call_sphereChange(id, list)
	if self.pickTime > World.Now() then
		return
	end
	local checkEntitys = {}
	for _, tb in ipairs(list) do
		if tb[2] then
			checkEntitys[#checkEntitys + 1] = tb[1]
		end
	end
	self:checkPickDropItem(checkEntitys)
end

local function checkDropItemPosition(map, pos)
	local curMap = World.CurWorld:getMap(map)
	local tempPos = Lib.copy(pos)
	tempPos.x = math.ceil(tempPos.x)
	tempPos.y = math.ceil(tempPos.y) - 1
	tempPos.z = math.ceil(tempPos.z)
	local block = curMap:getBlock(tempPos)
	while block and block.baseName == "/air" and tempPos.y > 0 do
		tempPos.y = tempPos.y - 1
		block = curMap:getBlock(tempPos)
	end
	pos.y = tempPos.y + 1 --上升一个位置，掉落物需要在方块上面
	if math.ceil(pos.x) == pos.x and pos.z == math.ceil(pos.z) then
		--  如果掉落物坐标皆为整数，则取坐标的中心点，x轴和z轴各减去0.5
		pos.x = pos.x + 0.5
		pos.z = pos.z + 0.5
	end
	return pos
end

function DropItemServer.Create(params) -- map, pos, item, lifeTime, pitch, yaw, moveSpeed, moveTime, guardTime
	local map, pos, item, lifeTime, pitch, yaw, moveSpeed, moveTime, guardTime = 
		params.map, params.pos, params.item, params.lifeTime, params.pitch, params.yaw, params.moveSpeed, params.moveTime, params.guardTime
	local world = World.CurWorld
	if not item or item:null() then
		return
	end
    local itemcfg = item:cfg()
	local blockId = item:block_id()
    if blockId then
        itemcfg = Block.GetIdCfg(blockId)
    end

	local cfg = DropItem.GetCfg(itemcfg.dropitem or "/dropitem")
	local dropitem = DropItemServer.CreateDropItem(cfg.id, world)
	item.iniPos = pos
	item.iniMap = map
	dropitem:setData("item", item)
	dropitem:setData("pitch", pitch)
	dropitem:setData("yaw", yaw)
	dropitem:setData("guardTime", guardTime)
	dropitem:setMap(world:getMap(map))
	-- dropitem:setPosition(checkDropItemPosition(map, Lib.copy(pos)))
	dropitem:setPosition(pos)
	dropitem.dropSpeed = itemcfg.dropSpeed or World.cfg.itemdropSpeed or 0.2
	dropitem.attractedLv = itemcfg.attractedLv or 0
	dropitem.moveSpeed = moveSpeed
	dropitem.moveTime = moveTime
	dropitem.createPos  = pos

	if lifeTime then
		dropitem:timer(lifeTime, dropitem.destroy, dropitem)
	end
	if tonumber(itemcfg.ownTime) then
		dropitem:timer(itemcfg.ownTime, function() dropitem:setData("ownerId") end)
	end
	dropitem:onCreate()

	dropitem.createByMapIndex = params.createByMapIndex
	dropitem.objPatchKey = params.objPatchKey or (os.date("%Y%m%d%H%M%S",os.time())..dropitem.objID)
	if not params.notNotifyMapPatchMgr then
		MapPatchMgr.ObjectChange(map, 
			{change = "create", objId = dropitem.objID, pos = pos, yaw = yaw, pitch = pitch, createByMapIndex = dropitem.createByMapIndex,
			objPatchKey = dropitem.objPatchKey, notNeedSaveToPatch = dropitem:cfg().notNeedSaveToPatch,
			isDropItem = true, lifeTime = lifeTime, item_fullName = item:cfg().fullName, item_type = item:full_name(), 
			block_id = item:block_id(), item_count = item:stack_count(), item_moveSpeed = moveSpeed, item_moveTime = moveTime})
	end
	MapPatchMgr.RegistCreateByMapDropItemToTable(dropitem.objID, dropitem.createByMapIndex)
	if (moveSpeed and (moveSpeed.x ~= 0 or moveSpeed.y ~= 0 or moveSpeed.z ~= 0)) and (moveTime and moveTime > 0) then
		dropitem:spreadMove(moveSpeed, moveTime)
		dropitem:timer(moveTime, function()
			dropitem.moveSpeed = nil
			dropitem.moveTime = nil
			dropitem.createPos  = nil
		end)
	end
	dropitem:createPickSphere(params)
	dropitem.fixRotation = params.fixRotation
	return dropitem
end

function DropItemServer:initData()
	DropItem.initData(self)
	self.vars = Vars.MakeVars("dropitem", self:cfg())
end

---@param packet PidPacket
function DropItemServer:sendPacketToTracking(packet)
	local pid = packet.pid
	packet = Packet.Encode(packet)
	local data = misc.data_encode(packet)
    local count = self:sendScriptPacketToTracking(data)
	World.AddPacketCount(pid, #data, true, count)
end

function DropItemServer:pick(player)
	-- just handle picked, cause had check
	local item = self:item()
	local cfg = item._item_data._cfg

	if cfg.noAddBag then
		Stage.UpdateStageScore(player, cfg.addScore or 0)
		player.vars.gameScore = player.vars.gameScore or 0
		player.vars.gameScore = player.vars.gameScore + (cfg.addScore or 0)

		local buff = item:use_buff()
		if buff then
			local target = player
			if buff.toTeam then
				target = player:getTeam() or player
			end
			target:addBuff(buff.cfg, buff.time)
		end
		Trigger.CheckTriggers(player:cfg(), "AUTOUSE_DROPITEM", {obj1 = player, item = item, dropItem = self})
		Trigger.CheckTriggers(item:cfg(), "DROPITEM_AUTOUSED", {obj1 = player, item = item, dropItem = self})
		self:destroy("PICKED")
		return
	end

    local succeed = player:addItemObj(item, "pick")
    if succeed then
        Trigger.CheckTriggers(player:cfg(), "PICK_DROPITEM", {obj1=player, item = item, dropItem = self})
		Trigger.CheckTriggers(cfg, "DROPITEM_PICKED", {obj1 = player, item = item, dropItem = self})
	else
		perror(" server pick dropitem fail !!!!!!!!!!!!!!!!!!!", cfg.fullName)
	end
	self:destroy("PICKED")
end

function DropItemServer:destroy(reason)
	local packet = {
		pid = "ObjectRemoved",
		objID = self.objID,
		reason = reason,
	}
	self:sendPacketToTracking(packet)

	if not self.notNotifyMapPatchMgr then
		MapPatchMgr.ObjectChange(self.map, {change = "destroy", objId = self.objID,
			createByMapIndex = self.createByMapIndex, objPatchKey = self.objPatchKey, isDropItem = true, notNeedSaveToPatch = self:cfg().notNeedSaveToPatch})
	end
	if self.auraId then
		self:removeObjectSphere(self.auraId)
	end
	Object.destroy(self)
end

function DropItemServer:spawnInfo()
	return {
		pid = "DropItemSpawn",
		objID = self.objID,
		pos = self.createPos or self:getPosition(),
		item = self:item() and self:item():seri(),
		pitch = self:data("pitch"),
		yaw = self:data("yaw"),
		moveSpeed = self.moveSpeed,
		moveTime = self.moveTime,
		guardTime = self:data("guardTime"),
		shake = self:data("shake"),
		fixRotation = self.fixRotation,
		instanceId = self:getInstanceID()
	}
end
