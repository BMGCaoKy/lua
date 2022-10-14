local misc = require "misc"
local item_manager = require "item.item_manager"
local setting = require "common.setting"
local remotedebug = require "common.debug.remotedebug"

local handles = T(Player, "PackageHandlers")

function handle_packet(player, data)
    Profiler:begin("decode_packet")
    local ok, packet = pcall(misc.data_decode, data)
	packet = Packet.Decode(packet)
    Profiler:finish("decode_packet")
    --print("handle_packets", player.name, packet.pid)
	if not ok then
		--print("SCRIPT_EXCEPTION----------------\n")
		print("handle_packets error!", player.name, packet)
		print(#data, data:byte(1, 200))
	end
	World.AddPacketCount(packet.pid, #data, false)
    local func = handles[packet.pid]
    if not func then
        print("no handle!", packet.pid)
        return
	end
    Profiler:begin("handle_packet."..packet.pid)
	CPUTimer.StartForLua("handle_packet."..packet.pid)
    local ret = table.pack(xpcall(func, traceback, player, packet))
    Profiler:finish("handle_packet."..packet.pid)
	CPUTimer.Stop()
    local ok = ret[1]
    if not ok then
        perror("handle_packet", ret[2])
        Lib.sendServerErrMsgToChat(player, ret[2])
        return
    end
    table.remove(ret, 1)
    ret.n = ret.n - 1
	if packet.__session__ then
		player:sendPacket({
			pid = "resp",
			session = packet.__session__,
			ret = ret
		})
	end
end

function handles:ping(packet)
	local ping = self:data("ping")
	local cur = ping.cur
	if cur then
		cur[3] = packet.lastTime or packet.time
		local log = {}
		log.logic = math.floor((cur[3] - cur[1]) / 2000)
		log.raknet, log.out = table.unpack(packet.ping)
		log.out = log.out or nil	-- change false to nil
		log.fps = packet.fps
		self:stats("ping", log)
	end
	local last = ping.last
	if last then
		local svrTime = cur[2] - last[2]
		local clnMin = cur[1] - last[3]
		local clnMax = cur[3] - last[1]
		local log = {
			min = clnMin,
			d1 = svrTime - clnMin,
			d2 = clnMax - svrTime,
		}
		self:stats("time", log)
	end
	ping.last = cur
	ping.cur = {packet.time, misc.now_microseconds(), nil}

	if self.logicPingCount == nil then
		self.logicPingCount=0
	end

	if self.logicPingTotalTime == nil then
		self.logicPingTotalTime=0
	end

	self.logicPingCount = self.logicPingCount + 1
	self.logicPingTotalTime = self.logicPingTotalTime + packet.logicPing

	local packet = {
		pid = "ping",
		time = packet.time,
	}
	self:sendPacket(packet)
	self.clientPingTick = World.Now()
end

function handles:ClientReady(packet)
	Plugins.CallPluginFunc("onPlayerReady", self)
	self:setPlayerControl(self)
	self:incCtrlVer()
end

function handles:HandItem(packet)
	local tid = packet.tid
	local slot = packet.slot
	local item = (tid and slot) and Item.CreateSlotItem(self, tid, slot)
	self:saveHandItem(item, true)
end

function handles:EntityValue(packet)
    local key = packet.key
    local value = packet.value
    local def = Entity.ValueDef[key]
	assert(def and def[2], key)
	if packet.isBigInteger then
		packet.value = BigInteger.Recover(packet.value)
    end
    self:setValue(packet.key, packet.value)
end

function handles:SyncBuyShops(packet)
	Shop:requestCanBuy(packet.itemIndex, self, packet.count)
end

function handles:EspShopCommit(packet)
	local id = packet.id
	local menu= packet.menu
	local upgrade_shop=self:data("upgrade_shop")
	local data = upgrade_shop[menu][id].data
	local money_type= data.money_type

	local context = Lib.copy(data)
	context.obj1 = self
	context.id = id

	if money_type == "gDiamonds" then
		Trigger.CheckTriggers(self:cfg(), data.event,context)
		return ""
	elseif money_type == "item" then
		local canBuy = self:consumeItem(data.deal_item,data.price,"esp_shop")
		if canBuy then
			Trigger.CheckTriggers(self:cfg(), data.event,context)
			return "gui_upgrade_succees",true -- success, don't need Popups
		else
			return "",false,true -- needPopups
		end
	else
		local enoughMoney = self:payCurrency(money_type,data.price,false,false,"esp_shop")
		if enoughMoney then
			Trigger.CheckTriggers(self:cfg(), data.event,context)
			return "gui_upgrade_succees",true
		else
			return "gui_upgrade_false",false
		end
	end
end

function handles:SyncBuyCommoditys(packet)
    Commodity:requestCanBuy(packet.itemIndex, self)
end

function handles:CastSkill(packet)
    Skill.CastByClient(packet, self)
end

function handles:StartSkill(packet)
    Skill.StartByClient(packet, self)
end

function handles:SustainSkill(packet)
    Skill.SustainByClient(packet, self)
end

function handles:StopSkill(packet)
    Skill.StopByClient(packet, self)
end

function handles:StartPreSwing(packet)
   --TODO
   Skill.StartPreSwingByClient(packet,self)
end

function handles:StopPreSwing(packet)
   --TODO
   Skill.StopPreSwingByClient(packet,self)
end

function handles:StartBackSwing(packet)
   --TODO
   Skill.StartBackSwingByClient(packet,self)
end

function handles:StopBackSwing(packet)
   --TODO
   Skill.StopBackSwingByClient(packet,self)
end


function handles:Rebirth(packet)
    if self.curHp > 0 then
        return
    end
    -- todo: more check
    if Game.GetState() ~= "GAME_OVER" then
        self:serverRebirth()
    end
end

function handles:ClientTrigger(packet)
	local world = World.CurWorld
	local cfg = nil
	if packet.target then
		local typ = type(packet.target)
		if typ=="number" then
			local obj = world:getObject(packet.target)
			if obj then
				cfg = obj:cfg()
			end
		elseif typ=="table" then
			cfg = self.map:getBlock(packet.target)
		end
	end
	local context = {pos=packet.pos}
	if packet.context then
		for k, v in pairs(packet.context) do
			context[k] = v
		end
	end
	if packet.obj1 then
		context.obj1 = world:getObject(packet.obj1)
	end
	if packet.obj2 then
		context.obj2 = world:getObject(packet.obj2)
	end
	Trigger.CheckTriggers(cfg, packet.name, context)
end

function handles:SwitchItem(packet)
	local my_tray = self:data("tray")
	local tray_1 = my_tray:fetch_tray(packet.tid_1)
	local tray_2 = my_tray:fetch_tray(packet.tid_2)

	if not Tray:check_switch(tray_1, packet.slot_1, tray_2, packet.slot_2) then
		return false
	end

	Tray:switch(tray_1, packet.slot_1, tray_2, packet.slot_2)
	self:syncSkillMap()

	return true
end

function handles:IntegrateTypeTray(packet)
	self:data("tray"):integrate_tray_item(packet.trayType)
	-- todo ex

	self:checkClearHandItem()
	return true
end

function handles:SortTypeTray(packet)
	self:data("tray"):sort_tray_item(packet.trayType)
	-- todo ex

	return true
end

function handles:SwitchItemFailed(packet)
	Trigger.CheckTriggers(self:cfg(), "SWITCH_ITEM_FAILED", {obj1 = self, key = packet.key})
end

function handles:PetPutOn(packet)
	local pet = self:getPet(packet.petIndex)
	if not pet then
		return false
	end

	local tray_bag = self:tray():fetch_tray(packet.tid)
	if not tray_bag then
		return false
	elseif tray_bag:type() ~= Define.TRAY_TYPE.BAG then
		return false
	end
	local item = Item.CreateSlotItem(self, packet.tid, packet.slot)
	return self:PetPutOn(pet, item)
end

function handles:combineItem(packet)
	local my_tray = self:data("tray")
	local handTray = my_tray:fetch_tray(packet.handTid)
	local bagTray = my_tray:fetch_tray(packet.bagTid)
	local handItem = handTray:fetch_item(packet.handSlot)
	local bagItem = packet.bagSlot and bagTray:fetch_item(packet.bagSlot)
	if not bagItem and not handItem then
		return
	end
	local hand_item_data = handItem and handTray:remove_item(packet.handSlot)
	local bag_item_data = bagItem and bagTray:remove_item(packet.bagSlot)
	if not bagItem and hand_item_data then
		my_tray:combineItem(hand_item_data, {Define.TRAY_TYPE.BAG})
		return
	end

	if hand_item_data then
		my_tray:combineItem(hand_item_data, {Define.TRAY_TYPE.BAG})
	end
	my_tray:combineItem(bag_item_data, {Define.TRAY_TYPE.HAND_BAG})

end

function handles:PetTakeOff(packet)
	local tid_equip = packet.tid
	local slot_equip = packet.slot

	local pet = self:getPet(packet.petIndex)
	if not pet then
		return false
	end
	local my_tray = self:data("tray")
	local pet_tray = pet:data("tray")

	local tray_equip = pet_tray:fetch_tray(tid_equip)
	if not tray_equip then
		return false
	end
	local sloter = Item.CreateSlotItem(pet, tid_equip, slot_equip)
	if sloter:null() then
		return false
	end
	local trayArray = my_tray:query_trays({Define.TRAY_TYPE.HAND_BAG, Define.TRAY_TYPE.BAG})

	for _, element in pairs(trayArray) do
		local tray_bag = element.tray
		local slot_bag = tray_bag:find_free()
		if slot_bag then
			if not Tray:check_switch(tray_bag, slot_bag, tray_equip, slot_equip) then
				return false
			end
			Tray:switch(tray_bag, slot_bag, tray_equip, slot_equip)
			return true
		end
	end
	return false
end

function handles:EquipItem(packet)
	local objID1 = packet.objID1
	local slot1 = packet.slot1
	local slot2 = packet.slot2
	local tray2 = self:tray():fetch_tray(packet.tid2)
	local entity = World.CurWorld:getEntity(objID1)
	local selfID = self.objID
	if not entity or (objID1 ~= selfID and entity.ownerId ~= selfID) then
		return false
	end
	local tray1 = entity:tray():fetch_tray(packet.tid1)
	if not tray1 or not tray2 or not slot1 or not slot2 then
		return false
	end
	if not Tray:check_switch(tray1, slot1, tray2, slot2) then
		return false
	end

	Tray:switch(tray1, slot1, tray2, slot2)
	self:syncSkillMap()

	return true
end

--for block
function handles:SwitchChestItem(packet)
    local chestTray = self.map:getBlockData(packet.chestPos).tray:fetch_tray(1)
	local playerTray = self:tray():fetch_tray(1)

	local dropTray, settleTray = chestTray, playerTray
	if packet.isPutIntoChest then
		dropTray, settleTray = playerTray, chestTray
	end
	local dropSlot = packet.dropSlot
	local settleSlot = settleTray:find_free()
	if not settleSlot then
		return false
	elseif not Tray:check_switch(settleTray, settleSlot, dropTray, dropSlot) then
		return false
	end
	local context = {obj1 = self, result = true, item = dropTray:fetch_item(dropSlot),}
	if packet.isPutIntoChest then
		Trigger.CheckTriggers(self:cfg(), "CHECK_PUT_INTO_CHEST", context)
	else
		Trigger.CheckTriggers(self:cfg(), "CHECK_TAKE_FROM_CHEST", context)
	end
	if not context.result then
		return false
	end
	Tray:switch(settleTray, settleSlot, dropTray, dropSlot)
	return true
end

--for entity
function handles:SwitchNpcChestItem(packet)
	local objID = packet.objID
	local entity = World.CurWorld:getEntity(objID)
	local dropTid = packet.dropTid
	local dropTray, settleEntity, settleTrays
	if packet.isPutIntoChest then
		dropTray, settleEntity, settleTrays = self:tray():fetch_tray(dropTid), entity, {Define.TRAY_TYPE.BAG}
	else
		dropTray, settleEntity, settleTrays = entity:tray():fetch_tray(dropTid), self, {Define.TRAY_TYPE.HAND_BAG, Define.TRAY_TYPE.BAG}
	end

	local dropSlot, dropCount = packet.dropSlot, packet.dropCount
	if not Tray:check_drop(dropTid, dropTray, dropSlot, settleEntity, settleTrays, dropCount) then
		return false
	end

	local context = {
		obj1 = self,
		result = true,
		item = dropTray:fetch_item(dropSlot),
		count = dropCount,
	}
	if packet.isPutIntoChest then
		Trigger.CheckTriggers(self:cfg(), "CHECK_PUT_INTO_CHEST", context)
	else
		Trigger.CheckTriggers(self:cfg(), "CHECK_TAKE_FROM_CHEST", context)
	end
	if not context.result then
		return false
	end

	return Tray:drop(dropTid, dropTray, dropSlot, settleEntity, settleTrays, dropCount)
end

function handles:DoCallBack(packet)
	self:doCallBack(packet.modName, packet.key, packet.regId, packet.context)
end

function handles:DoRemoteCallback(packet)
	self:doRemoteCallback(packet.modName, packet.key, packet.regId, packet.context)
end

function handles:ChatMessage(packet)
	local msg = packet.msg
	if utf8.len(msg) > 1000 then
		return
	end
	msg = World.CurWorld:filterWord(packet.msg)

	if ATProxy.mainGameCenter and packet.type == "world" then
		ATProxy.Instance():broadcastToServer({
			pid = "ChatMessage",
			id = self.platformUserId,
			name = self.name,
			msg = msg,
			type = packet.type,
		})
	end
    Trigger.CheckTriggers(self:cfg(), "SEND_CHAT_MESSAGE", {obj1 = self, msg = msg})
	WorldServer.ChatMessage(msg,self.name,packet.type,self.objID)
end

function handles:QueryEntityViewInfo(packet)
	--print("QueryEntityViewInfo", Lib.v2s(packet))
	local objID = packet.objID
	local player = objID and World.CurWorld:getObject(objID) or self
	assert(player, tostring(objID))
	if not player.isPlayer then
		Lib.logError("QueryEntityViewInfo not player.isPlayer")
		return false
	end

	local entityType = packet.entityType
	if entityType == Define.ENTITY_INTO_TYPE_PLAYER then
		return player:viewInfo()
	else
		local pets = player:data("pet")
		if pets then
			local pet = pets[entityType - 1]
			if pet then
				return pets[entityType - 1]:viewInfo()
			end
		end
		return false
	end
end

function handles:QuerySimpleView(packet)
	local objID = packet.objID
	local entity = objID and World.CurWorld:getObject(objID) or self
	return entity:viewEntityInfo(packet.key or "infoValues")
end

function handles:QueryPlayerlist(packet)
	local data = Game.GetAllPlayers()
	local ret = {}
	for i, v in pairs(data) do
		ret[#ret + 1] = {name = v.name, userId = v.platformUserId}
	end
	return ret
end

function handles:QueryChestTray(packet)
	local tray
	if packet.objID then
		tray = World.CurWorld:getEntity(packet.objID):tray():fetch_tray(1)
	else
		tray = self.map:getBlockData(packet.pos).tray:fetch_tray(1)
	end
	return Tray:seri_tray_items(tray, false)
end

function handles:RankData(packet)
	self:syncRankData(packet.rankType)
end

function handles:RequestRankReward(packet)
	return Rank.RequestRankReward(self.platformUserId, packet)
end

function handles:DeleteItem(packet)
    local my_tray = self:data("tray")
    local bag = my_tray:fetch_tray(packet.bag)
    local item = bag:remove_item(packet.slot)
	Trigger.CheckTriggers(self:cfg(), "DELETE_ITEM", {obj1 = self, item = item, fullName = item and item:full_name()})
end

function handles:DropDamage(packet)
    self:doDropDamage(packet.speed)
end

function handles:SellItem(packet)
    local item = Item.CreateSlotItem(self, packet.tid, packet.slot)
    if item:null() then
        return false
    end
    local sellNum = packet.item_num
    local itemCost = item:cfg().itemcost
	if not itemCost then
		return false
	end
    local sell_sussce = item:consume(sellNum)
	local money = sellNum*itemCost
    if sell_sussce then
        local context = {
		    obj1 = self,
		    item = item,
            reward = money,
	    }
        Trigger.CheckTriggers(self:cfg(), "SELL_SUSSCE", context)
    end
end

function handles:SellItems(packet)
	local sells = packet.sells or {}
	local ret = true
	local retSells = sells
	local items = {}
	for key, sell in pairs(sells) do
		local item = Item.CreateSlotItem(self, sell.tid, sell.slot)
        if item:null() then
            goto continue
        end
        local sellNum = sell.count
        local sellInfo = item:cfg().sell or {}
        if not sellInfo.count then
            goto continue
        end
        local sell_succeed = item:consume(sellNum)
		if sell_succeed then
			table.insert(items, { item = item, count = sellNum * sellInfo.count, coinName = sellInfo.coinName })
		else
			retSells[key] = nil
			ret = false
		end
		:: continue ::
	end
    if next(items) then
        Trigger.CheckTriggers(self:cfg(), "BATCH_SELL_SUSSCE", {obj1 = self, items = items})
    end
	return {ok = ret, sells = retSells}
end

function handles:RoutineCommit(packet)
	local data = nil
	local vars = self.vars
	local routine = vars.routine
	if not routine then
		return
	end
	for _, c in pairs(routine[packet.typeIndex].content) do
		if c.id == packet.cid then
			data = c
			break
		end
	end
	if not data or data.isReward then
		return false
	end
	local succeed = vars[tostring(data.condition)] >= data.nextExp
	data.isReward = succeed
		for _, r in pairs(data.reward) do
			Trigger.CheckTriggers(self:cfg(), data.event, {obj1 = self, fullName = r.fullName, count = r.count, result = succeed, type = r.type})
		end
	return succeed
end

function handles:GuideStep(packet)
	self:setGuideStep(packet.step, packet.flag, false, packet.noSyncClient)
end

function handles:SendFriendOperation(packet)
	local player = Game.GetPlayerByUserId(packet.userId)
	if player then
		player:sendPacket({
			pid = "FriendOperation",     
			operationType = packet.operationType,
			userId = self.platformUserId
        })
	end
end

function handles:DropInventoryItem(packet)
	local tid = packet.tid
	local slot = packet.slot
	local tray_obj = self:tray():fetch_tray(tid)
	if tray_obj then
		local itemData = tray_obj:remove_item(slot)
		if itemData then
			local dropItem = Item.CreateItem(itemData:full_name(), itemData:stack_count())
			if dropItem then
				local item_pos = self:getPosition()
				local item = DropItemServer.Create({
					map = self.map, pos = item_pos, item = dropItem
				})
				item:setData("objId", self.objID)
				item:setData("delayBeforeCanPickup", 40)
			end
		end
	end
end

function handles:AbandonTrayItem(packet)
	return self:abandonTrayItem(packet.params)
end

function handles:RemoveTrayItem(packet)
	return self:removeTrayItem(packet.params)
end

function handles:SplitTrayItem(packet)
	return self:splitTrayItem(packet.params)
end

function handles:GM(packet)
	if not World.gameCfg.gm and not Game.HasGMPermission(self.platformUserId) then
		return
	end
	print("GM:", packet.typ, packet.param)
	if packet.typ=="move" then
		self:getCtrlEntity():setPos(packet.param)
    elseif packet.typ == "GMCall" then
        return GM.call(self, packet.key)
    elseif packet.typ == "GMInputBoxCallBack" then
        return GM.inputBoxCallBack(self, packet.pack)
    elseif packet.typ == "ListCallBack" then
        return GM.listCallBack(self, packet.item)
	elseif packet.typ == "GMCallEditEntity" then
		local params = packet.params
		local func = handles[params.key]
		if not func then
			return false
		end
		return func(self, params)
	elseif packet.typ == "QueryPathInfo" then
		local params = packet.params
		if not self or not self.map then
            return
        end
        local pathFinder = self.map:get2dPathFinder()
		local passPts, radius = pathFinder:getPathInfo(params.roomId, params.position, params.range)
		if not passPts then
			print("!!!QueryPathInfo failed", params.roomId, params.range)
			return
		end
		return {
			passPts = passPts,
			radius = radius
		}
	elseif packet.typ == "telnetDebugInfo" then
		local port = packet.param
		local debugport = require "common.debugport"
		debugport:setServerPlayerPort(self, port)
		print("-------> telnetDebugInfo", port, self.objID)
	end
end

function handles:GetSignInData(packet)
    return self:getSignInList(packet.name)
end

function handles:GetSignInReward(packet)
    return self:getSignInReward(packet.name,packet.index)
end

function handles:TaskList(packet)
	return self:getTaskList()
end

function handles:StartTask(packet)
	local ret = {}
	ret.ok, ret.msg = self:startTask(packet.name)
	return ret
end

function handles:FinishTask(packet)
	local ret = {}
	ret.ok, ret.msg, ret.reward= self:finishTask(packet.name)
	return ret
end

function handles:AbortTask(packet)
	self:abortTask(packet.name)
end

function handles:DoCmdRet(packet)
	local serialNum = packet.serialNum
	if serialNum ~= nil then
		local cmdCB = self:data("cmdCallBack")
		local cb = cmdCB[serialNum]
		if cb then
			cmdCB[serialNum] = nil
			cb[cb.n+1] = packet.message
			cb[cb.n+2] = packet.isREPLMode
			cb[cb.n+3] = packet.isMultilineStatement
			cb[1](table.unpack(cb, 2, cb.n+3))
		end
	else
		print("ClientCmd", self.objID, self.name, packet.message)
	end
end

function handles:SyncViewInfo(packet)
	local viewInfo = self:data("viewInfo")
	if packet.view then
		viewInfo.view = packet.view
	end
end

function handles:RecipeList(packet)
	return Composition:getMasterRecipes(self, packet.class)
end

function handles:EquipSkill(packet) 
	self:syncEquipSkill(packet)
end

function handles:StartCompound(packet)
	local ret = {}
	ret.ok, ret.msg, ret.sup = Composition:startCompound(self, packet.class, packet.recipeName, packet.times)
	return ret
end

function handles:FinishCompound(packet)
	local ret = {}
	ret.ok, ret.msg, ret.times, ret.reward = Composition:finishCompound(self, packet.class)
	return ret
end

function handles:SupStartCompound(packet)
	Composition:supStartCompound(self, packet.class)
end

function handles:StopCompound(packet)
	Composition:stopCompound(self, packet.class)
end

function handles:OnWatchAdResult(packet)
	local code = packet.code
	local context = {obj1 = self, type = packet.type, params = packet.params}
	if code == 1 then --成功观看完广告
		Trigger.CheckTriggers(self:cfg(), "WATCH_AD_FINISHED", context)
	elseif code == 2 then	--观看广告失败
		Trigger.CheckTriggers(self:cfg(), "WATCH_AD_FAILED", context)
	elseif code == 3 then	--主动关闭观看广告
		Trigger.CheckTriggers(self:cfg(), "CLOSE_WATCH_AD", context)
	end
end

function handles:PrepareToStartStage(packet)
    Stage.StartStage(self, packet.fullName, packet.chapterId, packet.stage, packet.test)
end

function handles:LoadEnableChapters(packet)
    Stage.SendEnableChapters(self, packet.fullName, packet.winName)
end

function handles:LoadChapter(packet)
    return Stage.LoadChapter(self, packet.fullName, packet.chapterId, packet.winName, packet.check)
end

function handles:RequestExitStage(packet)
    Stage.ExitStage(self)
end

function handles:ReceivedChapterReward(packet)
    return Stage.ReceiveChapterReward(self, packet.fullName, packet.chapterId, packet.refreshUI, packet.winName)
end

function handles:ReceivedStarReward(packet)
    return Stage.ReceivedStarReward(self, packet.fullName, packet.chapterId, packet.star)
end

function handles:OnRechargeResult(packet)
	local type = packet.type
	if type == 1 then
		AsyncProcess.LoadUserMoney(self.platformUserId)
		self:onRechargeGCube(packet.productId)
	end
end

function handles:InteractWithEntity(packet)
	local entity = World.CurWorld:getEntity(packet.objID)
	if not entity then
		return
	end

	local checkContext = {
		obj1 = self,
		canInteract = true,
		interactTarget = entity,
	}
	Trigger.CheckTriggers(self:cfg(), "CHECK_CAN_INTERACT", checkContext)
	if not checkContext.canInteract then
		return
	end

	local context = {
		obj1 = entity,
		obj2 = self,
	}
	local cfgKey, cfgIndex, btnType, btnIndex = packet.cfgKey, packet.cfgIndex, packet.btnType, packet.btnIndex
	local cfg = entity:cfg()[cfgKey]
	if cfgIndex then
		cfg = cfg[cfgIndex]
	end
	local btnCfg = cfg[btnType][btnIndex]
	Trigger.CheckTriggers(entity:cfg(), btnCfg.event, context)
end

function handles:EditObjectAction(packet)
	local action = packet.action
	local entity = World.CurWorld:getEntity(packet.objID)
	if not entity or not action then
		return
	end
	local context = {
		obj1 = entity,
		obj2 = self,
		action = action,
		params = packet.params or {}
	}
	Trigger.CheckTriggers(entity:cfg(), "EDIT_OBJECT_ACTION", context)
end

function handles:OnPlayerInvite(packet)
	self:onPlayerInvite(packet)
end

function handles:OnPlayerVisit(packet)
	self:onPlayerVisit(packet)
end

function handles:FriendOperactionNotice(packet)
    local targetUserId = tonumber(packet.targetUserId)
    local opType = packet.operationType
    if opType == "ADD_FRIEND" then
        Trigger.CheckTriggers(self:cfg(), "ON_ADD_FRIEND", {obj1 = self, targetUserId = targetUserId})
    end
    local target = Game.GetPlayerByUserId(targetUserId)
    if not target then--crossServer is not supported
        return
    end
    target:sendPacket({
        pid = "FriendOperationNotice",
        operationType = opType,
        userId = self.platformUserId,
    })
end

function handles:RequestCreateTeam(packet)
    return Game.TryCreateTeam(self, packet.additionalInfo)
end

function handles:RequestJoinTeam(packet)
    return Game.TryJoinTeamByPlayer(self, packet.teamID)
end

function handles:RequestLeaveTeam(packet)
    local teamID = self:getValue("teamId")
    local team = Game.GetTeam(teamID)
    if team then
        team:leaveEntity(self)
    end
end

function handles:RequestQuitTeamMember(packet)
    local teamID = self:getValue("teamId")
    local team = Game.GetTeam(teamID)
    local memberId = packet.memberId
    if not team or not memberId then
        return
    end
    local entity = World.CurWorld:getEntity(memberId)
    if not entity then
        return
    end
    local memberTeamID = entity:getValue("teamId")
    if teamID ~= memberTeamID then
        return
    end
    local context = {obj1 = self, obj2 = entity, teamID = teamID, canQuitOut = true}
    Trigger.CheckTriggers(self:cfg(), "TRY_QUIT_MEMBER", context)
    if context.canQuitOut then
        team:leaveEntity(entity)
    end
end

function handles:RequestChangeGameKey(packet)
    Game.ChangeGameKey(self, packet.gameKey)
end

function handles:RequestChangeTeamGame(packet)
    Game.ChangeTeamGame(self, packet.stage)
end

function handles:PauseGame(packet)
	if World.cfg.allowPause then
	    World.CurWorld:setGamePause(packet.state)
	end
end

function handles:SyncStoreOperation(packet)
	Store:operation(self, packet.storeId, packet.itemIndex, packet.targetIndex)
end

function handles:RequestUpdateTeamAdditionalInfo(packet)
    local teamId = self:getValue("teamId")
    Game.UpdateTeamAdditionalInfo(teamId, packet.additionalInfo)
end

function handles:ItemUpgrade(packet)
    local tray, slot = packet.tray, packet.slot
    local tray_bag = self:tray():fetch_tray(tray)
    if not tray_bag then
        return false
    end
    local item = tray_bag:fetch_item(slot)
    if not item then
        return false
    end
    return tray_bag:on_upgrade(item, tray, slot)
end

function handles:StartPlayBGM(packet)
	Trigger.CheckTriggers(self:cfg(), "START_PLAY_BGM", { obj1 = self, index = packet.index })
end

function handles:QueryPartyList()
	PartyManager.RequestPartyList(self.platformUserId)
end

function handles:QueryPartyInfo()
	PartyManager.RequestPartyInfo(self.platformUserId)
end

function handles:CreateParty(packet)
	PartyManager.TryCreateParty(self.platformUserId, packet)
end

function handles:RenewParty(packet)
	PartyManager.RenewParty(self.platformUserId, packet)
end

function handles:IgnoreRenewParty(packet)
	Trigger.CheckTriggers(self:cfg(), "IGNORE_RENEW_PARTY_SUCCESS", {obj1 = self})
end

function handles:LeaveParty(packet)
	PartyManager.LeaveParty(self.platformUserId, packet.inPartyOwnerId)
end

function handles:LikeParty(packet)
	PartyManager.LikeParty(self.platformUserId, packet.inPartyOwnerId)
end

function handles:CloseParty(packet)
	PartyManager.CloseParty(self.platformUserId)
end

function handles:QueryCreatePartyViewInfo(packet)
	return PartyManager.GetCreatePartyViewInfo(self.platformUserId, packet.partyName)
end

function handles:RequestJoinParty(packet)
	local targetUserId = packet.targetUserId
	if self.platformUserId == packet.targetUserId then
		return
	end
	PartyManager.TryJoinParty(self.platformUserId, targetUserId, packet.partyId)
end

function handles:GetGoodsInfo(packet)
	local ret = {}
	local goodsInfo = Shop:getGoodsData(self)
	for _, index in pairs(packet.indexs) do
		ret[index] = goodsInfo[index] or 0
	end
	return ret
end

function handles:TransferPoint(packet)
	local transferCfg = World.cfg.transferData
	local data
	if transferCfg then
		data = transferCfg[packet.id]
	end
	if not data then
		data = self:data("canTransferPoints")[packet.id]
	end
	if not data then
		return
	end
	local map = data.map
	if map and type(map) == "string" then
		map = World.CurWorld:getOrCreateStaticMap(map)
	end
	self:setMapPos(map, data.pos)
end

--TRADE
function handles:AcceptTrade(packet)
	Trade.acceptTrade(self, packet.sessionId)
end

function handles:RefuseTrade(packet)
	Trade.RefuseTrade(self, packet.sessionId)
end

function handles:ChangTradeItem(packet)
	local trade = Trade.getTrade(packet.tradeID)
	if not trade then
		return false, "trade.not.exist"
	end
	if not packet.add  and packet.tid and packet.slot and not trade.finishTimer then
		return trade:playerDelItem(self, packet.tid, packet.slot)
	end
	if packet.add and packet.tid and packet.slot and not trade.finishTimer then
		return trade:playerAddItem(self, packet.tid, packet.slot)
	end
	return false, "Unknown.reason"
end

function handles:ConfirmTrade(packet)
	local trade = Trade.getTrade(packet.tradeID)
	if trade then
		trade:playerConfirm(self, packet.isConfirm)
	end
end

function handles:BreakTrade(packet)
	local trade = Trade.getTrade(packet.tradeID)
	if trade then
		trade:playerCancel(self)
	end
end

function handles:LoadTeamMemberInfo(packet)
    local teamId = packet.teamId or 0
    local keys = packet.keys or {}
    if teamId == 0 or #keys == 0 then
        return nil
    end
    local membersInfo = {}
    local players = Game.GetAllPlayers()
    for _, player in pairs(players) do
        if teamId == player:getValue("teamId") then
            local temp = {}
            for _, key in pairs(keys) do
                local value = player[key] or player:getValue(key)
                local vt = type(value)
                if vt == "string" or vt == "number" or vt == "boolean" then
                    temp[key] = value
                end
            end
            membersInfo[player.objID] = temp
        end
    end
    return membersInfo
end

function handles:GuidePositionChange(packet)
	local context = {
		obj1 = self,
		show = packet.show,
		pos = packet.pos,
		key = packet.key
	}
    Trigger.CheckTriggers(self:cfg(),"GUIDE_POSITION_CHANGE", context)
end

function handles:ItemUnlock(packet)
    local tray, slot, varKey = packet.tray, packet.slot, packet.varKey
    local tray_bag = self:tray():fetch_tray(tray)
    if not tray_bag then
        return false
    end
    local item = tray_bag:fetch_item(slot)
    if not item then
        return false
    end
    local context = {obj1 = self, item = item, varKey = varKey, unlock = true, msg = "", name = ""}
    Trigger.CheckTriggers(self:cfg(), "TRY_UNLOCK_ITEM", context)
    if not context.unlock then
        return context.unlock, context.msg
    end

    local unlock = item:var(varKey)
    if unlock then
        return true
    end
    local cfg = item:cfg()
    local cost = cfg.unlockCost or {}
    local entity = self:owner()
    local player = entity:owner()
    for _, v in ipairs(cost) do
        local typ = v.typ
        local name = v.name
        local count = v.count or 1
        if typ == "Coin" then
            local result = player:payCurrency(name, count, false, true, "itemUnlock")--todo
            if not result then
                return false, "coin_not_enough", name
            end
        elseif typ == "Item" then
            local sloter = player:tray():find_item(name)
            local cfg = setting:fetch("item", name)
            local itemName = cfg.itemname or cfg.name or name
	        if not sloter then
		        return false, "item_not_enough", itemName
	        end
            local result = player:tray():remove_item(sloter:cfg().fullName, count, true)
            if not result then
                return false, "item_not_enough", itemName
            end
        end
    end
    for _, v in ipairs(cost) do
        local typ = v.typ
        local name = v.name
        local count = v.count or 1
        if typ == "Coin" then
            player:payCurrency(name, count, false, false, "itemUnlock")
        elseif typ == "Item" then
            player:consumeItem(name, count, "itemUnlock")
        end
    end
    item:set_var(varKey, true)
    return true
end

function handles:ShowTreasureBox(packet)
    self:UpdataTreasureBox(packet.boxName, false, nil)
end

function handles:OpenTreasureBox(packet)
    self:OpenTreasureBox(packet.boxName)
end

function handles:TreasureBoxResresh(packet)
	self:TreasureBoxResresh(packet.resreshTyp, packet.boxName)
end

function handles:ResetGameFailed(packet)
    local content = {
        obj1 = self,
        resultCode = packet.resultCode,
        resultType = packet.resultType,
    }
    print(string.format("ResetGameFailed, resultCode = %s, resultType = %s", packet.resultCode, packet.resultType))
    Trigger.CheckTriggers(self:cfg(), "RESET_GAME_FAILED", content)
end

function handles:GetGoodsInfo(packet)
	local ret = {}
	local goodsInfo = Shop:getGoodsData(self)
	for _, index in pairs(packet.indexs) do
		ret[index] = goodsInfo[index] or 0
	end
	return ret
end

function handles:GameExplainEvent(packet)
    local guide = setting:fetch("explain", packet.fullName) or {}
    local list = guide.explain or {}
    local item = list[packet.step] or {}
    local event = item.event
    if event then
        Trigger.CheckTriggers(self:cfg(), event, item.context or {})
    end
end

function handles:ToolBarBtnClickEvent(packet)
	local toolBarCfg = World.cfg.toolBarSetting
	local btnCfg = toolBarCfg and toolBarCfg.buttonCfg
	local cfg = btnCfg and btnCfg[packet.key]
	local event = cfg.serverEvent
	if event then
		local context = packet.context or {}
		context.obj1 = self
		Trigger.CheckTriggers(self:cfg(), event, context)
	end
end

function handles:InteractionWithMovementEvent(packet)
	Trigger.CheckTriggers(self:cfg(), "INTERACTION_WITH_MOVEMENT_EVENT", packet.params)
end

function handles:NextGame(packet)
	Game.ReqNextGame(self)
end

function handles:ClickChangeBlock(packet)
	local blockPos = packet.pos
	local cfg = self.map:getBlock(blockPos)
	local clickChangeBlock = cfg.clickChangeBlock
	if cfg.placeCombination and clickChangeBlock then
		CombinationBlock:ClickChangeBlock(cfg, blockPos, self.map)
		return
	end
	-- if Lib.getPosDistanceSqr(blockPos, self:getPosition()) < 4 then 
	-- 	return 
	-- end
	if cfg and clickChangeBlock then 
		local toBlockCfg = Block.GetNameCfg(clickChangeBlock)
		if toBlockCfg then 
			self.map:setBlockConfigId(blockPos, toBlockCfg.id)
		else
			print("Error cfg in block "..cfg.fullName..", clickChangeBlock: ".. clickChangeBlock)
		end
	end
end

function handles:SumRechargeReceive(packet)
	self:onSumRechargeReceive()
end

function handles:GameBehaviorReport(packet)
	-- TODO check
	if not packet.params then
		return
	end
	--print("---------GameBehaviorReport----------",Lib.v2s( {table.unpack(packet.params)} ))
	GameAnalytics.Design(self.platformUserId ,nil ,{table.unpack(packet.params)} )
end
function handles:UIBehaviorLog(packet)
	-- TODO check
	local uiName = "ui_"..packet.uiName
	self:bhvLog(uiName, packet.desc, packet.target)
	GameAnalytics.Design(self.platformUserId ,nil ,{"ClickUI",uiName})
end

function handles:PlayAnimoji(packet)
	if self.removed or self.isMoving then
		return
	end

	 local animoji = self:data("animoji")
	 if not animoji[tostring(packet.actionId)] then
	 	return false
	 end
	 local actionName = "selectable_action_" .. packet.actionId
     self:sendPacketToTracking({
		pid = "EntityPlayAction",
		objID = self.objID,
		action = actionName,
		time = packet.actionTime or 100,
     }, true)

	self:setData("IsPlayingAnimoji", 1)
	local time = packet.actionTime or 100
	self:data("main").AnimojiTimer = World.Timer(time, function()
		if self and not self.removed then
			self:setData("IsPlayingAnimoji", 0)
		end
	end)

	 return true
end

function handles:RequestCenterFriends(packet)
	ATProxy.Instance():sendToCenter({
		pid = "RequestFriends",
		id = self.platformUserId
	})
end

function handles:ReqTeammateInfo(packet)
	local entity = World.CurWorld:getEntity(packet.objId)
	local mTeamId = self:getValue("teamId")
	if entity and mTeamId and entity:getValue("teamId") == mTeamId then
		return {maxHp = entity:prop("maxHp"), curHp = entity.curHp, name = entity.name, level = entity:getValue("level")}
	end
end

function handles:RequestAnimoji(packet)
	self:syncAnimoji()
end

function handles:AbandonItem(packet)
	local my_tray = self:data("tray")
	local bag = my_tray:fetch_tray(packet.tid)
	local itemData = bag:fetch_item(packet.slot)
	if not itemData then
		return false
	end
	local canAbandon = itemData and itemData:cfg().canAbandon
	if itemData and itemData:is_block() then
		local cfg = setting:fetch("block", setting:id2name("block", itemData:block_id()))
		canAbandon = cfg.canAbandon
	end
	if not canAbandon and not World.cfg.allCanAbandon then
		return false
	end
	itemData = bag:remove_item(packet.slot)
	if not itemData then
		return false
	end
	local item = Item.DeseriItem(item_manager:seri_item(itemData))
	local count = itemData:stack_count()
	local cfg = item:cfg()
	if item:is_block() then
		cfg = item:block_cfg()
	end
	local fullName = cfg.fullName
	local yaw = math.rad(self:getRotationYaw())
	local worldCfg = World.cfg
	local distance = cfg.dropDistance or worldCfg.dropDistance or 3
	local moveTime = cfg.moveTime or worldCfg.dorpMoveTime or 20
	local speed = distance / moveTime
	local pos = self:getFrontPos(0.4, false, false)
	pos.y = pos.y + (cfg.dropOffestY or worldCfg.dropOffestY or 0.5)
	local vector = { x = -speed * math.sin(yaw), y = 0, z = speed * math.cos(yaw)}
	local dropItem = DropItemServer.Create({
		map = self.map, pos = pos, item = item, lifeTime = cfg.vanishTime, moveSpeed = vector, moveTime = moveTime, guardTime = cfg.guardTime or worldCfg.itemGuardTime or 60
	})
	Trigger.CheckTriggers(self:cfg(), "ITEM_ON_ABANDONED", {obj1 = self, fullName = fullName, dropItem = dropItem, item = item, itemData = itemData, count = count})
	Trigger.CheckTriggers(cfg, "ITEM_ON_ABANDONED", {obj1 = self, fullName = fullName, dropItem = dropItem, item = item, itemData = itemData, count = count})
end

function handles:ReportFPS(packet)
	GameAnalytics.Design(self.platformUserId, 0, {"player:fps", packet.fps})
end

function handles:ReqTeammateInfo(packet)
	local entity = World.CurWorld:getEntity(packet.objId)
	local mTeamId = self:getValue("teamId")
	if entity and mTeamId and entity:getValue("teamId") == mTeamId then
		return {maxHp = entity:prop("maxHp"), curHp = entity.curHp, name = entity.name, level = entity:getValue("level")}
	end
end

function handles:SetViewRangeSize(packet)
	local player = World.CurWorld:getEntity(packet.objId)
	if not player then
		return
	end
	player:setViewRangeSize(packet.size)
end
---------------region edit 工具--------------------
local saveRegionInMap
local removeRegionInMap
local function comp(s1, s2)
    if s2 == "cfg" then
        return false
    elseif s1 == "cfg" then
        return true
    else
        if s1 == "x" or s1 == "y" or s1 == "z" then
            return s1 < s2
        end
        return s1 > s2
    end
    return true
end
function handles:SaveRegion(packet)
    saveRegionInMap(self, packet.params)
end
function handles:RemoveRegion(packet)
    removeRegionInMap(self, packet.name)
end
saveRegionInMap =  function(player, params)
    local mapName = player.map.name
	local filePath = Root.Instance():getGamePath() .. "map/" .. mapName .. "/" .. "setting.json"
    local cfg = assert(Lib.read_json_file(filePath), "saveRegionInMap : map setting path error. " .. filePath)
    if not cfg.region then
        cfg.region = {}
    end
    cfg.region[params.name] = {
        regionCfg = "myplugin/"..params.cfg, 
        box = params.box
    }
    print("addRegion:",Lib.v2s(params,3))
    print("delRegion:",Lib.v2s(player.map:getRegion(params.name),1)) 
    player.map:removeRegion(params.name)
    player.map:addRegion(params.box.min, params.box.max, "myplugin/"..params.cfg)
    local file = io.open(filePath, "w+")
    file:write(Lib.toJson(cfg, function(s1, s2) return comp(s1, s2) end))
    file:close()
end
removeRegionInMap =  function(player, name)
    local mapName = player.map.name
	local filePath = Root.Instance():getGamePath() .. "map/" .. mapName .. "/" .. "setting.json"
    local cfg = assert(Lib.read_json_file(filePath), "saveRegionInMap : map setting path error. " .. filePath)
    if not cfg.region then
        return
    end
    cfg.region[name] = nil
    print("delRegion "..name..":",Lib.v2s(player.map:getRegion(name),1)) 
    player.map:removeRegion(name)
    local file = io.open(filePath, "w+")
    file:write(Lib.toJson(cfg, function(s1, s2) return comp(s1, s2) end))
    file:close()
end
--------------------------------------------------------
--------------------碰撞盒-------------------------------
local SaveEntityBoundingVolume
function handles:SaveEntityBoundingVolume(packet)
	SaveEntityBoundingVolume(self, packet.params)
end

SaveEntityBoundingVolume =  function(player, params)
	local fullName = params.fullName
	local filePath = Root.Instance():getGamePath() .. "plugin/myplugin/entity/" .. fullName .. "/" .. "setting.json"
	local cfg = assert(Lib.read_json_file(filePath), "saveRegionInMap : map setting path error. " .. filePath)

	if cfg.boundingVolume then
		return
	end

	cfg.boundingVolume = {
		params = {
			params.w_x,
			params.w_y,
			params.w_z
		},
		type = "Box"
	}
	local file = io.open(filePath, "w+")
	file:write(Lib.toJson(cfg, function(s1, s2) return comp(s2, s1) end))
	file:close()

	print("add "..fullName.." boundingVolume")
end

--------------------------------------------------------
------------------------ edit obj
local saveNpcInMap
local removeNpcInMap

local function resetPlayerEditQueue(player)
    player.editNpcQueue = {}
    player.editNpcQueuePtr = 0
end

local function getQueue(player)
    if not player.editNpcQueue then
        resetPlayerEditQueue(player)
    end
    return player.editNpcQueue
end

local function resetPlayerEditQueueUntilPtr(player)
    local editNpcQueue = getQueue(player)
    for i=(player.editNpcQueuePtr or 0) + 1,#editNpcQueue do
        editNpcQueue[i] = nil
    end
end

function handles:ChangeEntityMode(packet)
	self:setEntityMode(packet.mode, self:getTargetId())
end

function handles:FollowEnterGame(packet)
	local serverConfig = Server.CurServer:getConfig();
	local allPlayers = Game.GetAllPlayers()
	local curPlayers = 0
	local watchPlayers = 0

	local userId = 0;
	for _, v in pairs(allPlayers) do
		if v:isWatch() then
			watchPlayers = watchPlayers + 1
		else
			curPlayers = curPlayers + 1
		end
		if v.objID == self:getTargetId() then
			userId = v.platformUserId;
		end
	end

	return {
		watchMode = serverConfig.watchMode,
		maxNum = serverConfig.maxPlayers, ---最大玩家人�
		watchNum =  watchPlayers,	---当前观战人数
		curNum = curPlayers,	---当前玩家人数
		userId = userId		---玩家ID
	}
end

function handles:FollowInterfaceDataReport(packet)
	self:followInterfaceDataReport(packet.data)
end

local function resetTheNewNpcIDToQueue(objID, newObjID, player)
    local editNpcQueue = getQueue(player)
    for i, v in pairs(editNpcQueue) do
        if v.objID == objID then
            v.objID = newObjID
        end
    end
end

local function ruNew(editNpcOperate, player)
    local newNpc = EntityServer.Create({pos = editNpcOperate.pos, map = player.map, cfgName = editNpcOperate.cfg})
    newNpc:setValue("mapEntityIndex", editNpcOperate.mapEntityIndex)
    resetTheNewNpcIDToQueue(editNpcOperate.objID, newNpc.objID, player)
    saveNpcInMap(newNpc, player, {pitch = editNpcOperate.pitch, yaw = editNpcOperate.yaw, roll = editNpcOperate.roll})
end

local function ruRemove(editNpcOperate, player)
    local npc = World.CurWorld:getObject(editNpcOperate.objID)
    removeNpcInMap(npc, player)
end

local function undoEdit(player)
    local editNpcQueue = getQueue(player)
    local editNpcOperate = editNpcQueue[player.editNpcQueuePtr] or {}
    if editNpcOperate.operate == "new" then
        ruRemove(editNpcOperate, player)
    elseif editNpcOperate.operate == "remove" then
        ruNew(editNpcOperate, player)
    end
    player.editNpcQueuePtr = math.max(0, player.editNpcQueuePtr - 1)
end

local function redoEdit(player)
    local editNpcQueue = getQueue(player)
    local editNpcOperate = editNpcQueue[player.editNpcQueuePtr + 1] or {}
    if editNpcOperate.operate == "new" then
        ruNew(editNpcOperate, player)
    elseif editNpcOperate.operate == "remove" then
        ruRemove(editNpcOperate, player)
    end
    player.editNpcQueuePtr = math.min(#editNpcQueue, player.editNpcQueuePtr + 1)
end

local function updateEditQueue(player, npc, operate)
    local editNpcQueue = getQueue(player)
    editNpcQueue[#editNpcQueue + 1] = {
        cfg = npc:cfg().fullName, 
        pos = npc:getPosition(), 
        pitch = npc:getRotationPitch(), 
        ry = npc:getRotationYaw(), 
        rr = npc:getRotationRoll(),
        mapEntityIndex = npc:getValue("mapEntityIndex"),
        objID = npc.objID,
        operate = operate
    }
    player.editNpcQueuePtr = #editNpcQueue
end

-- local function comp(s1, s2)
--     if s2 == "cfg" then
--         return false
--     elseif s1 == "cfg" then
--         return true
--     else
--         if s1 == "x" or s1 == "y" or s1 == "z" then
--             return s1 < s2
--         end
--         return s1 > s2
--     end
--     return true
-- end

saveNpcInMap =  function(npc, player, params, new)
    local mapName = player.map.name
	local filePath = Root.Instance():getGamePath() .. "map/" .. mapName .. "/" .. "setting.json"
    local cfg = assert(Lib.read_json_file(filePath), "saveNpcInMap : map setting path error. " .. filePath)
    if not cfg.entity then
        cfg.entity = {}
    end
    local mapEntityIndex = npc:getValue("mapEntityIndex")
    local index = mapEntityIndex <= 0 and (#cfg.entity + 1) or mapEntityIndex
    local tempEntityTable = cfg.entity[index] or {}
    cfg.entity[index] = {cfg = npc:cfg().fullName, pos = params.pos or npc:getPosition(), 
                pitch = params.pitch or npc:getRotationPitch(), ry = params.yaw or npc:getRotationYaw(), rr = params.roll or npc:getRotationRoll(), isNew = new or tempEntityTable.isNew or nil}
    npc:setValue("mapEntityIndex", index)
    if new then
        resetPlayerEditQueueUntilPtr(player)
        updateEditQueue(player, npc, "new")
    end
    local file = io.open(filePath, "w+")
    file:write(Lib.toJson(cfg, function(s1, s2) return comp(s1, s2) end))
    file:close()
end

removeNpcInMap = function(npc, player, remove)
    local mapName = player.map.name
    local mapEntityIndex = npc:getValue("mapEntityIndex")
    if mapEntityIndex <= 0 then
        npc:kill()
        return
    end
	local filePath = Root.Instance():getGamePath() .. "map/" .. mapName .. "/" .. "setting.json"
    local cfg = assert(Lib.read_json_file(filePath), "removeNpcInMap : map setting path error. " .. filePath)
    if not cfg.entity then
        cfg.entity = {}
    end
    cfg.entity[mapEntityIndex] = nil
    if remove then
        resetPlayerEditQueueUntilPtr(player)
        updateEditQueue(player, npc, "remove")
    end
    local file = io.open(filePath, "w+")
    file:write(Lib.toJson(cfg, function(s1, s2) return comp(s1, s2) end))
    file:close()
    npc:kill()
end

function handles:NewEditObject(packet)
    local player = World.CurWorld:getObject(packet.playerId)
    if not player then
        return
    end

    local playerPosition = player:getPosition() + Lib.v3(0, 1, 0)
    local position = packet.position or playerPosition
    local rotation = packet.rotation or Vector3.new(0, 0, 0)

    local newNpc = EntityServer.Create({ pos = position, map = player.map, ry = rotation.y, rp = rotation.x, cfgName = packet.fullName })
    saveNpcInMap(newNpc, player, {}, true)
    return { objID = newNpc.objID }
end

function handles:ReplaceEditObject(packet)
    local player = World.CurWorld:getObject(packet.playerId)
    if not player then
        return
    end
    local targetReplaceNpc = World.CurWorld:getObject(packet.targetObjId)
    local newNpc = EntityServer.Create({pos = targetReplaceNpc:getPosition(), map = targetReplaceNpc.map, cfgName = packet.fullName})
    removeNpcInMap(targetReplaceNpc, player, true)
	saveNpcInMap(newNpc, player, {}, true)
	return {objID = newNpc.objID}
end

function handles:SaveEditObject(packet)
    local entity = World.CurWorld:getObject(packet.objId)
    local player = World.CurWorld:getObject(packet.playerId)
    if not entity or not player then
        return
    end
    saveNpcInMap(entity, player, packet.params or {})
end

function handles:SyncEditObject(packet)
    local entity = World.CurWorld:getObject(packet.objId)
    local player = World.CurWorld:getObject(packet.playerId)
    if not entity or not player then
        return
    end
    local params = packet.params
    if params then
        entity:setPosition(params.pos or entity:getPosition())
        entity:setRotationYaw(params.yaw or entity:getRotationYaw())
        entity:setRotationPitch(params.pitch or entity:getRotationPitch())
        entity:setRotationRoll(params.roll or entity:getRotationRoll())
    end
end

function handles:UpdateEditObject(packet)
    local entity = World.CurWorld:getObject(packet.objId)
    if not entity then
        return
    end
    Trigger.CheckTriggers(entity:cfg(), "UPDATE_IS_EDIT", {obj1 = entity, isEdit = packet.isEdit})
end

function handles:RemoveEditObject(packet)
    local entity = World.CurWorld:getObject(packet.objId)
    local player = World.CurWorld:getObject(packet.playerId)
    if not entity or not player then
        return
    end
    removeNpcInMap(entity, player, true)
end

function handles:RedoEdit(packet)
    local player = World.CurWorld:getObject(packet.playerId)
    if not player then
        return
    end
    redoEdit(player)
end

function handles:UndoEdit(packet)
    local player = World.CurWorld:getObject(packet.playerId)
    if not player then
        return
    end
    undoEdit(player)
end

function handles:ResetEditQueue(packet)
    local player = World.CurWorld:getObject(packet.playerId)
    if not player then
        return
    end
    resetPlayerEditQueue(player)
end

function handles:ClientPackageHandler(packet)
	return PackageHandlers.receiveClientHandler(self, packet.name, packet.package)
end

function handles:OtherClientHandler(packet)
	local userId = packet.userId
	local player = Game.GetPlayerByUserId(userId)
	if not player then
		return
	end
	PackageHandlers.sendServerHandler(player, packet.name, packet.package)
end

function handles:onbuyActionResult(packet)
	local result = packet.result
	if result == 1 then
		self:syncAnimoji()
		AsyncProcess.LoadUserMoney(self.platformUserId)
	end
end
------------------------ edit obj

------------------------ client entity
function handles:TouchClientEntity(packet)
	if not self:checkClientEntityInLegalRange(packet) then
		return false
	end
    self:touchClientEntity(packet)
end

------------------------ client entity end

function handles:switchGameMode(packet)
	if not packet.gameMode then
		return
	end
	self:switchGameMode(packet.gameMode)
end

function handles:PlayerAutoKick(packet)
	
end

function handles:SetReadyForAssignTeam(packet)
	self:data("main").isReadyForAssignTeam = packet.value
end

function handles:exchangeCDKey(packet)
	self:exchangeCDKey(packet.key)
end

function handles:SetProp(packet)
	if packet.isBigInteger then
		packet.value = BigInteger.Recover(packet.value)
	end
	self:setProp(packet.key, packet.value)
end

function handles:DebugTransferRequest(packet)
	remotedebug.TransferRequest(packet, self)
end

function handles:DebugTransferResponse(packet)
	remotedebug.TransferResponse(packet, self)
end

function handles:ConfirmPayMoney(packet)
	local payHelper = Game.GetService("PayHelper")
	payHelper:confirmedPayMoney(self)
end

function handles:CancelPayMoney(packet)
	local payHelper = Game.GetService("PayHelper")
	payHelper:cancelPayMoney(self)
end

function handles:GetServerOsTime(packet)
	return {
		serverTs = os.time() - (packet.clientTime or os.time())
	}
end

function showErrorMessage(msg)
	local players = Game.GetAllPlayers()
	for _, player in pairs(players or {}) do
		if player and player:isValid() and Game.HasShowErrorPermission(player.platformUserId) then
			player:sendPacket({pid = "ServerErrorMessage", errMsg = msg})
		end
	end
end

function handles:ConnectorMsg(packet)
	Lib.emitEvent(Event.EVENT_CONNECTOR_MSG, packet.data)
end

function handles:PerformanceReport(packet)
	self.performance  = { fps = packet.fps, netPing = packet.netPing, logicPing = packet.logicPing }
end

function handles:BtsMsg(packet)
	local context = packet
	context.player = self
	for i,cfg in ipairs(World.cfgSet) do
        if cfg then
			context.instance = cfg.instance
			Trigger.CheckTriggersOnly(cfg, packet.msg, context)
		end
	end
	if self and self._cfg then
		Trigger.CheckTriggersOnly(self._cfg, packet.msg, context)
	end
end

local reportController = require "report.controller"
function handles:RequestEventTrackingList()
	reportController:requestListByClient()
end