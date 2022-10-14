local misc = require "misc"

Player = EntityClientMainPlayer

---@field platformUserId number
---@field objID number
---@class EntityClientMainPlayer : EntityClient
local Player = Player

require "common.player"
require "player.player_event"
require "player.interaction_event"
require "player.player_packet"
require "player.player_control"
require "player.player_task"
require "player.player_recharge"
require "player.player_client_entitys_mgr"

Player.isMainPlayer = true
Player.displayAmount = 0

function Player:initPlayer()
	Blockman.Instance():setLockVisionState(World.cfg.lockVision and World.cfg.lockVision.open or false)
end

function Player:onTick(frameTime)
	--TODO
end

---@class PidPacket
---@field pid string
---@param packet PidPacket
function Player:sendPacket(packet, resp)
	assert(not packet.__session__)
	if resp then
		assert(type(resp) == "function")
		local session = #Session + 1
		Session[session] = resp
		packet.__session__ = session
	end
	local pid = packet.pid
	packet = Packet.Encode(packet)
	local data = misc.data_encode(packet)
	World.AddPacketCount(pid, #data, true)
	WorldClient.SendScriptPacket(data)
	return data
end

function Player:setValue(key, value, noSync)
    local def = Entity.ValueDef[key]
    if not def[3] or noSync then
		self:doSetValue(key, value)
    end
	if noSync then
		return
	end
    local packet = {
        pid = "EntityValue",
        key = key,
		value = value,
		isBigInteger = type(value) == "table" and value.IsBigInteger,
        objID = self.objID,
    }
    self:sendPacket(packet)
	--print(string.format("Player:setValue %s %s", tostring(key), Lib.v2s(value, 1)))
end

function Player:syncBuyShopGood(itemIndex, count)
    local packet = {
        pid = "SyncBuyShops",
        itemIndex = itemIndex,
        count = count
    }
    self:sendPacket(packet)
end

function Player:getSignInData(name,func)
	local packet = {
		pid = "GetSignInData",
		name = name
	}
	self:sendPacket(packet,func)
end

function Player:getSignInReward(name,index,func)
	local packet = {
		pid = "GetSignInReward",
        name = name,
        index = index
	}
	self:sendPacket(packet,func)
end

function Player:espShopCommit(menu,id,func)
    local packet={
        pid="EspShopCommit",
        menu=menu,
        id=id,
    }
    self:sendPacket(packet,func)
end

function Player:syncBuyCommodityGood(itemIndex)
    local packet = {
        pid = "SyncBuyCommoditys",
        itemIndex = itemIndex
	}
	
	local func = function() 
		self:sendPacket(packet) 
	end

	local commodity = Commodity:GetCommodity(itemIndex)
	if commodity and commodity.coinName == "gDiamonds" and Clientsetting.getRemindConsume() ~= 0 then
		local wnd = UI:openWnd("onlineConsumeRemind")
		if wnd then
			wnd:setCallBack(func)
			wnd:setPrice(commodity.price)
		end
	else
		func()
	end
end

function Player:setHandItem(item)
	local isValidItem = item and not item:null()
	local fullName
	if isValidItem then
		if item:is_block() then
			fullName = item:block_name()
		else
			fullName = item:full_name()
		end
	end
	Skill.CheckNeedTouchEnd(fullName)
	self:saveHandItem(item)
	
	local packet = {
		pid = "HandItem",
		tid = item and (not item:null()) and item:tid(),
		slot = item and (not item:null()) and item:slot()
	}
    self:sendPacket(packet)
end

function Player:updateSkillList(skillMap)
	local data = self:data("skill")
	local oldMap = data.skillMap or {}
	data.jumpSkill = nil
	local selfDefaultSkills = self:cfg().defaultSkills
	local clickList = {}
	if not selfDefaultSkills then
		table.insert(clickList, "/click")
	end
	for name, value in pairs(oldMap) do
		if not skillMap[name] then
			local skill = Skill.Cfg(name)
			if skill.icon then
				skill:showIcon(false)
			end
            if skill.frontSight then
                FrontSight.Destroy(skill)
            end
            if skill.snipe then
                Lib.emitEvent(Event.SHOW_SNIPE, false)
            end
		end
	end
	for name, value in pairs(skillMap) do
		local skill = Skill.Cfg(name)
		if not skill then break end
		if skill.icon then
			if not oldMap[name] then
				skill:showIcon(true, value.index)
			end
		end
		if skill.isClick or skill.isTouch then
			table.insert(clickList, name)
		end
		if skill.isJump then
			data.jumpSkill = name
		end
		if skill.frontSight and skill.frontSight~= "" then
			FrontSight.Create(skill, skill.frontSight)
		end
        if skill.snipe then
            Lib.emitEvent(Event.SHOW_SNIPE, true, skill.snipe, skill)
        end
	end
	if not selfDefaultSkills then
		local mapCfg = self.map.cfg
		if mapCfg.canAttack then
			table.insert(clickList, "/attack")
		end
		if mapCfg.canBreak then
			table.insert(clickList, "/break")
		end
		if mapCfg.placeTestBlock then
			table.insert(clickList, "/place_test")
		end
		if mapCfg.canBuild then
			table.insert(clickList, "/build")
		end
		table.insert(clickList, "/empty")
	else
		table.move(selfDefaultSkills,1,#selfDefaultSkills,#clickList + 1,clickList)
		local tempSkills = {}
		for i,v in ipairs(clickList) do
			tempSkills[v] = i
		end
		table.sort(clickList, function(skill1, skill2)
			local s1 = Skill.Cfg(skill1) or {}
			local s2 = Skill.Cfg(skill2) or {}
			local s1p = s1.priority or 0
			local s2p = s2.priority or 0
			if s1p == s2p then
				return tempSkills[skill1] < tempSkills[skill2]
			end
			return s1p < s2p
		end)
	end
	data.skillMap = skillMap
    data.clickList = clickList
end

function Player:updateStudySkillList(studySkillMap)
	local data = self:data("skill")
	local oldMap = {}
	if data.studySkillMap then
		oldMap = data.studySkillMap
	end
	data.studySkillMap = studySkillMap
	for name, objID in pairs(oldMap.studySkills or {}) do 
		local skill = Skill.Cfg(name)
		if skill.icon then
			skill:showIcon(false)
		end
        if skill.frontSight then
            FrontSight.Destroy(skill)
        end
        if skill.snipe then
            Lib.emitEvent(Event.SHOW_SNIPE, false)
		end
	end
	local equipSkillsNames = {}
	for i, skill in pairs(studySkillMap and studySkillMap.equipSkills or {}) do
		equipSkillsNames[skill] = i
	end
	local equipSkillsIndexs = self:data("skill").equipSkillsIndexs
	if not equipSkillsIndexs then
		equipSkillsIndexs = {}
		self:data("skill").equipSkillsIndexs = equipSkillsIndexs
	end
	equipSkillsIndexs.equipSkillType = Lib.copy(equipSkillsNames)
	for name, index in pairs(equipSkillsNames or {}) do
		local skill = Skill.Cfg(name)
		if skill.icon then
			skill:showIcon(true, index)
		end
		if skill.frontSight then
			FrontSight.Create(skill, skill.frontSight)
		end
        if skill.snipe then
            Lib.emitEvent(Event.SHOW_SNIPE, true, skill.snipe, skill)
        end
	end
end

function Player:getSkillEquipIndex(fullName) 
	-- 注：兼容旧配置旧UI代码，不改之前逻辑，那么：
	-- 使用特定技能槽位相关的技能，有装备槽位/装备位置的技能，比如上面的装备技能
	-- 那么需要把装备的技能以及对应的槽位，记录到玩家身上的skill的equipSkillIndexs里面，供新技能UI界面取数据
	-- equipSkillsIndexs = { ATypeSkill = { name = index, name1 = index1 ...}}
	for index, typeSkill in pairs(self:data("skill").equipSkillsIndexs) do
		for name, index in pairs(typeSkill) do
			if name == fullName then
				return index
			end
		end
	end
end

function Player:updateBuffList(buffMap)
	for id, buffTb in pairs(buffMap) do
		self:addClientBuff(buffTb.name, id, buffTb.time)
	end
end

function Player:sendTrigger(target, name, obj1, obj2, context)
	if target and target.objID then
		target = target.objID
	end
	local packet = {
		pid = "ClientTrigger",
		target = target,
		name = name,
		obj1 = obj1 and obj1.objID,
		obj2 = obj2 and obj2.objID,
		context = context,
	}
	self:sendPacket(packet)
end

function Player:getPet(index)
	local objID = self:data("pet")[index]
	if not objID then
		return nil
	end
	return self.world:getEntity(objID)
end

function Player:onTrayItemModify()
	local fireEventTimer = self.fireTrayItemEventTimer
	if fireEventTimer then
		fireEventTimer()
	end
	self.fireTrayItemEventTimer = self:lightTimer("onTrayItemModify", 1, function ()
		Lib.emitEvent(Event.EVENT_PLAYER_ITEM_MODIFY)
		Lib.emitEvent(Event.FETCH_ENTITY_INFO, true)
		Event:EmitEvent("OnTrayItemChanged")
		self.fireTrayItemEventTimer = nil
	end)
end

function Player:switchItem(tid_1, slot_1, tid_2, slot_2, func)
	local my_tray = self:data("tray")
	local tray_1 = my_tray:fetch_tray(tid_1)
	local tray_2 = my_tray:fetch_tray(tid_2)

    local ret, key = Tray:check_switch(tray_1, slot_1, tray_2, slot_2)
	if not ret then
		local packet = {
			pid = "SwitchItemFailed",
            key = key
		}
		self:sendPacket(packet)
		return false
	end

	local packet = {
		pid = "SwitchItem",
		tid_1 = tid_1,
		slot_1 = slot_1,
		tid_2 = tid_2,
		slot_2 = slot_2
	}
	self:sendPacket(packet, func)
end

function Player:sortTypeTray(trayType, func)
	local packet = {
		pid = "SortTypeTray",
		trayType = trayType
	}
	self:sendPacket(packet, func)
end

function Player:integrateTypeTray(trayType, func)
	local packet = {
		pid = "IntegrateTypeTray",
		trayType = trayType
	}
	self:sendPacket(packet, func)
end

function Player:abandonTrayItem(params, func)
	local packet = {
		pid = "AbandonTrayItem",
		params = params
	}
	self:sendPacket(packet, func)
end

function Player:removeTrayItem(params, func)
	local packet = {
		pid = "RemoveTrayItem",
		params = params
	}
	self:sendPacket(packet, func)
end

function Player:splitTrayItem(params, func)
	local packet = {
		pid = "SplitTrayItem",
		params = params
	}
	self:sendPacket(packet, func)
end

function Player:petPutOn(tid, slot, petIndex, func)
	local packet = {
		pid = "PetPutOn",
		petIndex = petIndex,
		tid = tid,
		slot = slot
	}
	self:sendPacket(packet, func)
end

function Player:combineItem(handTid,  handSlot, bagTid, bagSlot)
		local packet = {
		pid = "combineItem",
		handTid = handTid,
		handSlot = handSlot,
		bagTid = bagTid,
		bagSlot = bagSlot
	}
	self:sendPacket(packet)
end

function Player:petTakeOff(petIndex, tid, slot, func)
	local packet = {
		pid = "PetTakeOff",
		petIndex = petIndex,
		tid = tid,
		slot = slot
	}
	self:sendPacket(packet, func)
end

function Player:doCallBack(modName, key, regId, context)
	local packet = {
		pid = "DoCallBack",
		modName = modName,
		key = key,
		regId = regId,
		context = context
	}
	self:sendPacket(packet)
end

function Player:doRemoteCallback(modName, key, regId, context)
	local packet = {
		pid = "DoRemoteCallback",
		modName = modName,
		key = key,
		regId = regId,
		context = context
	}
	self:sendPacket(packet)
end

function Player:routineCommit(cid, typeIndex, func)
	local packet = {
		pid = "RoutineCommit",
		cid = cid,
		typeIndex = typeIndex
	}
	self:sendPacket(packet, func)
end

function Player:doGM(typ, param)
	local packet = {
		pid = "GM",
		typ = typ,
		param = param
	}
	self:sendPacket(packet)
end

function Player:getRecipeList(class, func)
	local packet = {
		pid = "RecipeList",
		class = class
	}
	self:sendPacket(packet, func)
end

function Player:startCompound(class, recipeName, times, func)
	local packet = {
		pid = "StartCompound",
		class = class,
		recipeName = recipeName,
		times = times
	}
	self:sendPacket(packet, func)
end

function Player:finishCompound(class, func)
	local packet = {
		pid = "FinishCompound",
		class = class
	}
	self:sendPacket(packet, func)
end

function Player:sendPlayerInvite(targetUserId, content, crossServer)
	self:sendPacket({
		pid = "OnPlayerInvite",
		targetUserId = targetUserId,--type can be number array, number or nil
		fromUserId = Me.platformUserId,
		content = content,
		crossServer = crossServer,
	})
end

function Player:sendPlayerVisit(targetUserId, content, crossServer)
	self:sendPacket({
		pid = "OnPlayerVisit",
		targetUserId = targetUserId,--type: number
		content = content,
		crossServer = crossServer,
	})
end

function Player:friendOperactionNotice(targetUserId, operationType)
    self:sendPacket({
        pid = "FriendOperactionNotice",
        targetUserId = targetUserId,
        operationType = operationType,
    })
end

function Player:RequestNewRankData(params)
	local packet = {
		pid = "NewRankData",
		rankName = params.rankName,
		id = params.id,
		start = params.start,
		count = params.count,
	}
	self:sendPacket(packet)
end

function Player:onInInteractionRangesChanged(objID, isCheckIn)
	local ranges = Me:data("inInteractionRanges")
	if isCheckIn then
		ranges[objID] = true
		Lib.emitEvent(Event.EVENT_OBJECT_INTERACTION_CHECKIN, objID, true)
		--self:checkSortInteraction()
	else
		ranges[objID] = nil
		Lib.emitEvent(Event.EVENT_OBJECT_INTERACTION_CHECKIN, objID, false)
	end
	self:checkSortInteraction()
end

function Player:checkSortInteraction()
	local ids = {}
	for id in pairs(self:data("inInteractionRanges")) do
		ids[#ids + 1] = id
	end
	self:sortInteractionDistance(ids)
end

function Player:sortInteractionDistance(ids)
    local function sortByDistance(ids)
        local pos = self:getPosition()
        table.sort(ids, function (a, b)
            local obj1, obj2 = self.world:getObject(a), self.world:getObject(b)
            local pos1 = obj1 and obj1:getPosition()
            local pos2 = obj2 and obj2:getPosition()
            local dis1, dis2 = Lib.getPosDistanceSqr(pos1, pos), Lib.getPosDistanceSqr(pos2, pos)
            if dis1 == dis2 then
                return a < b
            end
            return dis1 < dis2
        end)
        return ids
    end
    local timer = self:data("main").sortDistanceTimer
    if timer then
        timer()
    end
    if #ids < 1 then
        if timer then
            self:data("main").sortDistanceTimer = nil
        end
        return
    end
    self:data("main").sortDistanceTimer = self:timer(10, function ()
        Lib.emitEvent(Event.EVENT_OBJECT_INTERACTION_SORT_DISTANCE, sortByDistance(ids))
        return true
    end)
end

function Player:interactWithObject(objID, cfgKey, cfgIndex, btnType, btnIndex)
    local object = World.CurWorld:getObject(objID)
    if not object then--it may be deleted at previous frame
        return
    end
    if object.isEntity then
        self:sendPacket({
            pid = "InteractWithEntity",
            objID = objID,
            cfgKey = cfgKey,
            cfgIndex = cfgIndex,
            btnType = btnType,
            btnIndex = btnIndex,
        })
    end
end

function Player:recheckAllInteractionUIs()
    for id in pairs(self:data("inInteractionRanges")) do
        self:updateObjectInteractionUI({
            objID = id,
            recheck = true,
            show = true,
        })
    end
end

function Player:canShowObjectInteractionUI(objID)
	local object = self.world:getObject(objID)
	local canShow = not self:isWatch() and object
					and object:prop().canInteract == 1
					and objID ~= self.objID
					and not object:isWatch()
					or false
	return canShow
end

function Player:updateObjectInteractionUI(data)
	local objID, show, reset = data.objID, data.show, data.reset
	local recheck = data.recheck
	local object = self.world:getObject(objID)
	if show and not object then
		print("can not find object! ", objID)
		return
	end
	local canShow = self:canShowObjectInteractionUI(objID)
    if recheck then
        local ranges = self:data("inInteractionRanges")
        Lib.emitEvent(Event.EVENT_OBJECT_INTERACTION_SWITCH, objID, canShow and ranges[objID])
        return
    end
    if reset then
        local defaultCfg = canShow and object:cfg().interactionUI
		assert(not canShow or defaultCfg, " has no interaction cfg!")
        Lib.emitEvent(Event.EVENT_OBJECT_INTERACTION_SET, objID, show and canShow, defaultCfg)
	end
	if not reset then
		local cfg
		if data.cfgKey then
			cfg = object:cfg()[data.cfgKey]
		end
		if cfg then
			Lib.emitEvent(Event.EVENT_OBJECT_INTERACTION_SET, objID, false, cfg)
		end
		Lib.emitEvent(Event.EVENT_OBJECT_INTERACTION_SWITCH, objID, show and canShow)
	end
end

function Player:SyncStoreOperation(storeId, itemIndex, targetIndex)
	local packet = {
		pid = "SyncStoreOperation",
		itemIndex = itemIndex,
		storeId = storeId,
		targetIndex = targetIndex
	}
	self:sendPacket(packet)
end

function Player:equipSkill(equipSkillBar, equipSkill)
    self:sendPacket({pid = "EquipSkill", equipSkillBar = equipSkillBar or 1, equipSkill = equipSkill})
end

function Player:itemUpgrade(tray, slot, func)
    self:sendPacket({pid = "ItemUpgrade", tray = tray, slot = slot}, func)
end

function Player:loadTeamMemberInfo(teamId, keys, func)
    self:sendPacket({pid = "LoadTeamMemberInfo", teamId = teamId, keys = keys}, func)
end

function Player:setGuideStep(step, nextOnly) -- ԭsetGuideStep����
    self:doSetValue("guideStep", step)
end

local function checkSignIn(data)
	local today = tonumber(Lib.getYearDayStr(os.time()))
	if data.start_date  == -1 or data.start_date  > today then
		return false
	end
	if data.iscompleted and data.finishKey < today then
		return false
	end
	return true
end

function Player:checkOpenSignIn()
	local uiData = {}
	local open = false
	local CURRENT = 2
	for _, cfg in ipairs(Player.SignIns) do
		local func = function(uiData, signdata)
			if not (signdata and checkSignIn(signdata) and not open) then
				return
			end
			local items = cfg.sign_in_items
			if cfg.randomItem then
				local itemIndex = signdata.start_date 
				items = cfg.sign_in_items[itemIndex]
			end
			for index, item in ipairs(items) do
				if uiData[index] == CURRENT then
					open = true
					Lib.emitEvent(Event.EVENT_SHOW_NEW_SIGIN_IN, true)
					Lib.emitEvent(Event.EVENT_SIGNIN_RED_POINT, true) 
					return
				end
			end
		end
		Me:getSignInData(cfg._name, func)
	end
end
function Player:gameBehaviorReport(...)
	local packet = {
		pid = "GameBehaviorReport",
		params = table.pack(...)
	}
	self:sendPacket(packet)
end
function Player:uiBehaviorLog(uiName, desc, target)
	local packet = {
		pid = "UIBehaviorLog",
		uiName = uiName,
		desc = desc,
		target = target,
	}
	self:sendPacket(packet)
end

function Player:setMap(newMap)
	self.displayAmount = 0
	if (self.map and self.map.id or 0) ~= (newMap and newMap.id or 0) then
		self:resetLocalMapChunkDataIsLoad(self.map)
		self:calcLocalMapChunkData(newMap)
	end

	-- client entity
	self:clearMapClientEntity({mapId = self.map and self.map.id})
	self:recreateMapClientEntitys(newMap)
	-- client entity end

	Object.setMap(self, newMap)
end

function Player:newCurrency(isBigInteger)
	return isBigInteger and  {count = BigInteger.Create(0),} or { count = 0, }
end

function Player:getCurrency(coinName, create)
	local wallet = self:data("wallet")
	local currency = wallet[coinName]
	if currency then
		return currency
	elseif not create then
		return nil
	end
	currency = self:newCurrency(Coin:GetCoinMapping()[coinName] and Coin:GetCoinMapping()[coinName].bigInteger)
	wallet[coinName] = currency
	return currency
end

function Player:changeEntityMode(mode)
	self:sendPacket({ pid = "ChangeEntityMode", mode = mode })
end

function Player:followInterfaceDataReport(data)
	Me:sendPacket({
		pid = "FollowInterfaceDataReport",
		data = data
	})
end
function Player:resetLocalMapChunkDataIsLoad(map)
	if not map then
		return
	end
	local mapChunkDataArr = self.mapChunkDataArr
	if not mapChunkDataArr then
		mapChunkDataArr = {}
        self.mapChunkDataArr = mapChunkDataArr
	end
	local mapChunkDataWithMapId = mapChunkDataArr[map.id]
	if not mapChunkDataWithMapId then
		mapChunkDataWithMapId = {}
		mapChunkDataArr[map.id] = mapChunkDataWithMapId
	end
	for _, chunkDataMap in pairs(mapChunkDataWithMapId) do
		chunkDataMap.isLoad = false
	end
end

function Player:calcLocalMapChunkData(map)
	if not map then
		return
	end
	local mapChunkDataArr = self.mapChunkDataArr
	if not mapChunkDataArr then
		mapChunkDataArr = {}
        self.mapChunkDataArr = mapChunkDataArr
	end
	local mapChunkDataWithMapId = mapChunkDataArr[map.id]
	if not mapChunkDataWithMapId then
		mapChunkDataWithMapId = {}
		mapChunkDataArr[map.id] = mapChunkDataWithMapId
	end
	for _, chunkDataMap in pairs(mapChunkDataWithMapId) do
		if not chunkDataMap.isLoad then
			map:loadChunk(chunkDataMap.chunkData, self:getPosition())
			chunkDataMap.isLoad = true
		end
	end
end

function Player:addLocalChunkData(mapID, chunkData)
	if not mapID or not chunkData then
		return
	end
	local mapChunkDataArr = self.mapChunkDataArr
	if not mapChunkDataArr then
		mapChunkDataArr = {}
		self.mapChunkDataArr = mapChunkDataArr
	end
	local mapChunkDataWithMapId = mapChunkDataArr[mapID]
	if not mapChunkDataWithMapId then
		mapChunkDataWithMapId = {}
		mapChunkDataArr[mapID] = mapChunkDataWithMapId
	end
	local data = chunkData[1]
	local x,z = data.x,data.z
	local isFind = false
	for _, mapChunkDataWithMapIdMap in pairs(mapChunkDataWithMapId) do
		local _data = mapChunkDataWithMapIdMap.chunkData[1]
		if _data.x == x and _data.z == z then
			mapChunkDataWithMapIdMap.chunkData = chunkData
			mapChunkDataWithMapIdMap.isLoad = false
			isFind = true
			break
		end
	end
	if not isFind then
		mapChunkDataWithMapId[#mapChunkDataWithMapId + 1] = {chunkData = chunkData, isLoad = false}
	end
end

function Player:deseriChunkData2map(mapId, chunkData)
	self:addLocalChunkData(mapId, chunkData)
	if mapId == (self.map and self.map.id or -1) then
		self.map:loadChunk(chunkData, self:getPosition())
	end
end

--初始化自动踢人策�
function Player:resetAutoKick(stopTimer)
	if self.objID ~= Me.objID then
		return
	end
	if not World.cfg.kickTipsTime or not World.cfg.kickTime then
		return
	end
	self.lastTime = World.cfg.kickTipsTime
	if self.kickTimer then
		self.kickTimer()
	end
	if self.kickTipsTimer then
		self.kickTipsTimer()
	end
	local state = Game.GetState()
	if state ~= "GAME_GO" or stopTimer then
		return
	end
	self.kickTimer =  self:lightTimer("reset_auto_kick_timer", World.cfg.kickTime-World.cfg.kickTipsTime,function()
		if self.removed then
			return
		end
		self.kickTipsTimer = self:lightTimer("auto_kick_tips_timer", 20, function()
			if self.lastTime <=0 then
				Lib.logDebug("auto kick player", self.objID, self.platformUserId)
				self:sendPacket({
					pid = "PlayerAutoKick"
				})
				CGame.instance:exitGame()
				return false
			end

			--通用弹窗
			Client.ShowTip(1, Lang:toText({"system.message.kick.user.out.auto.kick.out"}), 40)
			self.lastTime = self.lastTime-20
			return true
		end)
	end)
end

function Player:SetReadyForAssignTeam(value)
	self:sendPacket({
		pid = "SetReadyForAssignTeam",
		value = value
	})
end

function Player:startCameraMode()
    if self:isCameraMode() then
        return
    end

    self.showFunc = UI:hideOpenedWnd()
    self:setCameraMode(true)
    self:updateMainPlayerRideOn()
    Me:setFlyMode(true)
    Lib.emitEvent(Event.EVENT_SWITCH_INTERACTION_WND, false)
    UI:openWnd("takePhotos")
end

function Player:cameraModeClose()
    if not self:isCameraMode() then
        return
    end

    Me:setFlyMode(false)

    if not self.showFunc then
        return
    end

    self.showFunc()
    self.showFuncId = nil
    Lib.emitEvent(Event.EVENT_SWITCH_INTERACTION_WND, true)
    self:setCameraMode(false)
    self:updateMainPlayerRideOn()

	if UI:isOpen("takePhotos") then
		UI:closeWnd("takePhotos")
	end
end

function Player:regSwapData(key, data)
	if not key then
		return
	end
	if data and (not data.tid or not data.slot) then
		return
	end
	local swapCellData = self.swapCellData
    if not swapCellData then
        swapCellData = {}
        self.swapCellData = swapCellData 
    end
    swapCellData[key] = data
end

function Player:checkNeedSwapBagItem(checkFun)
	local count = 0
	for _,data in pairs(self.swapCellData or {}) do
		local compoment = true
		if checkFun and not checkFun(data) then
			compoment = false
		end
		if compoment then
			count = count + 1
		end
	end
	return count>=2
end

function Player:swapBagItem()
	local destTid, destSlot
	for _, data in pairs(self.swapCellData or {}) do
		if not destTid then
			destTid = data.tid
			destSlot = data.slot
		else
			self:switchItem(destTid, destSlot, data.tid, data.slot)
			break
		end
	end
	for _, data in pairs(self.swapCellData or {}) do
		if data.callbackFunc then
			data.callbackFunc()
		end
	end
	self.swapCellData = {}
end

function Player:touchClientEntity(entity)
	self:sendPacket({
		pid = "TouchClientEntity",
		clientEntityObjId = entity.objID,
		mapId = self.map.id
	})

end

function Player:switchGameMode(mode)
	self:sendPacket({
		pid = "switchGameMode",
		gameMode = mode
	})
end

function Player:getTaskPluginData(pluginName)
	local data = self:data("taskPlugin")
	local pluginData = data[pluginName]
	if not pluginData then
		pluginData = {}
		data[pluginName] = pluginData
	end
	return pluginData
end

function Player:isForbidRotate()
	return false
end

function Player:RequestFriendList(callback,first,last)
	if not self.allFriendData then 
		self:initClientFriendInfo()
	end
	local function asyncCallback(dataList)
		local friendCompare = function(lhs, rhs)
			local lStatus =	Game.GetPlayerByUserId(lhs.userId) and 20 or lhs.status
			local rStatus = Game.GetPlayerByUserId(rhs.userId) and 20 or rhs.status
			if lStatus < rStatus then 
				return true
			elseif lStatus == rStatus then 
				if lhs.userId < rhs.userId then
					return true
				else
					return false
				end
			else 
				return false
			end
		end
		local data = dataList.data
		table.sort(data,friendCompare)
		
		local friendDataList = {}
		for i = first,last do
			if data[i] then
				local friendDataInfo = {}
				friendDataInfo.NickName = data[i].nickName
				friendDataInfo.UserID = data[i].userId
				friendDataInfo.ProfilePhoto = data[i].picUrl
				friendDataInfo.Language = data[i].language
				friendDataInfo.Online = (data[i].status ~= 30)
				friendDataInfo.CurrentGame = data[i].gameName
				table.insert(friendDataList,friendDataInfo)
			end
		end
		if callback then 
			callback(friendDataList)
		end
	end
	AsyncProcess.ClientGetChatFriend(Me.platformUserId,self.allFriendData.language,0, 50, asyncCallback)
end

function Player:GetUserData(callback)
	local info = UserInfoCache.GetCache(self.platformUserId)
	if not info then 
		return
	end
	local friendDataInfo = {}
	friendDataInfo.NickName = info.nickName
	friendDataInfo.UserID = info.userId
	friendDataInfo.ProfilePhoto = info.picUrl
	friendDataInfo.Language = info.language
	friendDataInfo.Online = Game.GetPlayerByUserId(self.platformUserId) and true or (info.status ~= 30)
	friendDataInfo.CurrentGame = info.gameName

	if callback then 
		callback(friendDataInfo)
	end
end

function Player:RequestIsFriendWith(UserID,callback)
	if not UserID or not callback then 
		return 
	end
	if not self.allFriendData then 
		self:initClientFriendInfo()
	end
	local isFriend = self:checkPlayerIsMyFriend(UserID)
	if isFriend == nil then 
		
		local function asyncCallback(data)
			local isFriend = false
			for _,info in pairs(data.data) do 
				if info.userId == UserID then isFriend = true break end
			end
			if callback then 
				callback(isFriend)
			end
		end
		
		AsyncProcess.ClientGetChatFriend(self.platformUserId, self.allFriendData.language,0, 500, asyncCallback)
	else 
		if callBack then 
			callBack(self:checkPlayerIsMyFriend(UserID) ~= Define.friendStatus.notFriend)
		end
	end
end
