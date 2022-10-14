local misc = require "misc"
local seri = require "seri"
local cjson = require "cjson"
local setting = require "common.setting"
local PlayerDBMgr = T(Lib, "PlayerDBMgr") ---@type PlayerDBMgr

---@field platformUserId number
---@field objID number
---@class EntityServerPlayer : EntityServer
Player = EntityServerPlayer

---@type EntityServerPlayer
local Player = Player

require "common.player"
require "player.player_event"
require "player.player_packet"
require "player.player_rank"
require "player.player_sign_in"
require "player.player_task"
require "player.player_target"
require "player.player_recharge"
require "player.player_client_entitys_mgr"


function Player:initPlayer()
	local attrInfo = self:getPlayerAttrInfo()
	self:setData("mainInfo", attrInfo.mainInfo)

	local mainData = self:data("main")
	mainData.sex = attrInfo.sex==2 and 2 or 1
	mainData.team = attrInfo.team

	local temp_actor = 	mainData.sex == 2 and self:cfg().actorGirlName or self:cfg().actorName

	if self:cfg().ignorePlayerSkin then
	else
		self:changeSkin(attrInfo.skin)
	end
	
	if mainData.sex==2 then
		mainData.actorName = (temp_actor ~= nil and temp_actor ~= "" and temp_actor) or "girl.actor"
	else
		mainData.actorName = (temp_actor ~= nil and temp_actor ~= "" and temp_actor) or "boy.actor"
	end
	self:initCurrency()
end

function Player:changeToAppAppearance()
	local attrInfo = self:getPlayerAttrInfo()
	local actorNameOnApp = attrInfo.sex==2 and "girl.actor" or "boy.actor"
	local nowActorName = self:data("main").actorName
	if nowActorName ~= actorNameOnApp then
		self:changeActor(actorNameOnApp, true)
	end
	self:changeSkin(attrInfo.skin)
end

function Player:sendPacket(packet)
	if not World.CurWorld:getEntity(self.luaObjID) then
		Lib.logError("obj not found, user, packet", self.luaPlatformUserId or 0, Lib.v2s(packet, 1))
		return
	end

	local pid = packet.pid
	packet = Packet.Encode(packet)
	local ok, packet = Lib.XPcall(misc.data_encode, "player sendPacket error -> misc.data_encode(packet). pid = " .. pid, packet)
	if not ok then
		return
	end

	World.AddPacketCount(pid, #packet, true)
	self:sendScriptPacket(packet)
end

function Player:secondTimer()
	-- TODO
	local playTime = 1 + self:getValue("playTime")
	self:setValue("playTime", playTime, true)
	Trigger.CheckTriggers(self:cfg(), "ENTITY_SECOND_TIMER", {obj1 = self, playTime = playTime})
	return true
end


function Player:useItem(trayId, slot)
	local my_tray = self:data("tray")
	return my_tray:use_item(trayId, slot)
end

function Player:sendTip(tipType, textKey, keepTime, vars, event, ...)
	local regId
	if event then
		regId = self:regCallBack("SendTip"..tipType, {key = event}, 1, true)
	end
    self:sendPacket( {
        pid = "ShowTip",
        tipType = tipType,
		keepTime = keepTime,
        textKey = textKey,
		vars = vars,
		regId = regId,
        textArgs = {...},
    })
end

function Player:syncTrays()
	self:tray():sync_on_load()
end

function Player:syncEquipSkill(packet)
	local skillFullName = packet.equipSkill.fullName
	local studySkillMap = self:data("skill").studySkillMap
	if studySkillMap and studySkillMap.studySkills[skillFullName] then 
		local equipSkills = studySkillMap.equipSkills
		local equipBar = packet.equipSkillBar
		for i,skill in pairs(equipSkills) do
			if skill == skillFullName and i ~= equipBar then
				equipSkills[i] = equipSkills[equipBar]
				break
			end
		end
		equipSkills[equipBar] = skillFullName 
	end
	Trigger.CheckTriggers(self:cfg(), "EQUIP_SKILL", {obj1=self, skillName = skillFullName})
	self:syncStudySkillMap()
end

function Player:learnSkill(name)
	local data = self:data("skill")
	local studySkillMap = data.studySkillMap
	if not studySkillMap then
		data.studySkillMap = {studySkills = {}, equipSkills = {}}
		studySkillMap = data.studySkillMap
	end
	studySkillMap.studySkills[name] = true
	self:syncStudySkillMap()
end

function Player:equipSkill(name)
	local studySkillMap = self:data("skill").studySkillMap
	if not studySkillMap or not studySkillMap.studySkills or not studySkillMap.studySkills[name] then
		return
	end
	for _, v in ipairs(studySkillMap.equipSkills or {}) do
		if v == name then
			return
		end
	end
	table.insert(studySkillMap.equipSkills, name)
	self:syncStudySkillMap()
end

function Player:forgetSkill(name)
	local studySkillMap = self:data("skill").studySkillMap
	if not studySkillMap then
		return
	end
	studySkillMap.studySkills[name] = nil
	for i, skill in pairs(studySkillMap.equipSkills or {}) do
		if skill == name then
			studySkillMap.equipSkills[i] = nil
		end
	end
	self:syncStudySkillMap()
end

function Player:syncSkillMap()
	local skillMap = self:getSkillMap()
	self:data("skill").skillMap = skillMap

	local packet = {
		pid = "SkillMap",
		map = skillMap,
	}
	self:sendPacket(packet)
end

function Player:syncStudySkillMap() 
	local studySkillMap = self:getStudySkillMap()
	self:data("skill").studySkillMap = studySkillMap

	local packet = {
		pid = "StudySkillMap",
		map = studySkillMap,
	}
	self:sendPacket(packet)
end

local function getBuffMap(self)
	local ret = {}
	local buffMap = self:data("buff")
	local now = World.Now()
	for id, buff in pairs(buffMap) do
		ret[id] = {
			name = buff.cfg.fullName,
			time = buff.endTime and (buff.endTime - now) or nil
		}
	end
	return ret
end

function Player:syncBuffMap() 
	self:sendPacket({
		pid = "BuffMap",
		map = getBuffMap(self),
	})
end

function Player:saveHandItem(item, syncExcludeSelf, force)
	EntityServer.saveHandItem(self, item, syncExcludeSelf, force)
	self:syncSkillMap()
end

--especiallyShop_update("menu1",1,{menu="menu1",id=1,title="title",image=nil,deal_ico=nil, des="des", btn="",money_type="",deal_number=10})
function Player:especiallyShop_update(menu,id,data,event,close)
	local packet={
		pid="EspeciallyShop_update",
		id=id,
		menu=menu,
		data=data,
        close = close
	}
	local upgrade_shop=self:data("upgrade_shop")
	local menu_={}
	local id_={}

	local menu_index= upgrade_shop[menu]
	if not menu_index then upgrade_shop[menu]=menu_	end

	if data ~=nil then
		upgrade_shop[menu][id]=id_
		upgrade_shop[menu][id].data=data
	else
		upgrade_shop[menu]=nil
	end
	self:sendPacket(packet)
end

function Player:createPet(cfgName, show, map, pos)
	if show then
		map = map or self.map
		pos = pos or self:getFrontPos(2)
	else
		map = nil
		pos = nil
	end
	local petCfg = Entity.GetCfg(cfgName)
	local name = petCfg.name or self.name
	local entity = EntityServer.Create({cfgName = cfgName, map = map, pos = pos, name = name, owner = self})
	entity.isShowingPet = show
	return self:addPet(entity)
end

function Player:addPet(entity, index)
	--assert(entity:getValue("ownerId")==0, entity.objID)
	local data = self:data("pet")
	index = index or #data + 1
	data[index] = entity
	entity:setValue("ownerId", self.objID)
	entity:setValue("petIndex", index)
	local control = entity:getAIControl()
	if control then 
		control:setFollowTarget(self)
	end
	self:syncPet()
	return index
end

function Player:getPet(index)
	return self:data("pet")[index]
end

function Player:relievedPet(index)
	local data = self:data("pet")
	local entity = data[index]
	if not entity then
		return
	end
	data[index] = nil
	self:syncPet()
    entity:setValue("ownerId", 0)
    entity:setValue("petIndex", 0)
	return entity
end

function Player:removePet(index)
	local data = self:data("pet")
	local entity = data[index]
	if not entity then
		return
	end
	entity:destroy()
	data[index] = nil
	self:syncPet()
end

function Player:changePetCfg(index, cfgName)
	local data = self:data("pet")
	local entity = data[index]
	if not entity then
		return
	end
	local dat = entity:saveData()
	local map = entity.map
	local pos = entity:getPosition()
	entity:destroy()
	data[index] = nil
	entity = EntityServer.Create({cfgName=cfgName, map=map, pos=pos, name=self.name, owner = self})
	self:addPet(entity, index)
	entity:loadData(dat)
	return entity
end

function Player:showPet(index, map, pos)
	local entity = self:data("pet")[index]
	if not entity then
		return nil
	end
	map = map or self.map
	pos = pos or self:getFrontPos(2)
	if entity.curHp<=0 then
		entity:serverRebirth(map, pos)
	else
		entity:setMapPos(map, pos, self:getRotationYaw(), 0)
	end
	entity.isShowingPet = true
	return entity
end

function Player:setPetFollow(index, followSwitch)
	local entityPet = self:data("pet")[index]
	if not entityPet then 
		return nil
	end
	local aiControl = entityPet:getAIControl()
	aiControl:setFollowSwitch(followSwitch)
end

function Player:updateShowPetsOnEnterMap(map, pos)
	-- print(" ------------ Player:updateShowPetsOnEnterMap() ShowingPets ", Lib.v2s(self:data("ShowingPets")))
	if self:cfg().showShowingPetsOnEnterMap then
		local ShowingPets = self:data("ShowingPets")
		for index in pairs(ShowingPets) do
			self:showPet(index, map, pos)
		end
		self:setData("ShowingPets", {})
	end
end

function Player:hidePet(index)
	local entity = self:data("pet")[index]
	if not entity then
		return nil
	end
	if not entity.map then
		return entity
	end
	entity.isShowingPet = false
	entity:leaveMap()
	return entity
end

function Player:updateShowPetsOnLeaveMap(map)
	self:setData("ShowingPets", {})
	local ShowingPets = self:data("ShowingPets")
	local pets = self:data("pet") or {}
	for i, pet in pairs(pets) do
		if pet and pet:isValid() then
			if pet.isShowingPet == true then
				ShowingPets[i] = i
			end
			self:hidePet(i)
		end
	end
	-- print(" ------------ Player:updateShowPetsOnLeaveMap() ShowingPets ", Lib.v2s(self:data("ShowingPets")))
	-- todo ex
end

function Player:PetPutOn(pet, item)
	if item:null() then
		return false
	end

	if not pet then
		return false
	end

    local tray_bag = self:tray():fetch_tray(item:tid())
    local slot_bag = item:slot()
    for type in pairs(item:tray_type()) do
        if type ~= Define.TRAY_TYPE.BAG then
            local trayArray = pet:tray():query_trays(type)
            local tray_equip = trayArray[1] and trayArray[1].tray
            if tray_equip then
                if (Tray:check_switch(tray_equip, 1, tray_bag, slot_bag)) then
                    Tray:switch(tray_equip, 1, tray_bag, slot_bag)
					return true
                end
            end
        end
	end
	return false
end

function Player:syncPet()
	local list = {}
	local packet = {
		pid = "PetList",
		list = list,
	}
	for index, entity in pairs(self:data("pet")) do
		list[index] = entity.objID
	end
	self:sendPacket(packet)
end

function Player:syncTreasurebox()
	local list = {}
	local packet = {
		pid = "syncTreasurebox",
		list = list,
	}
	for boxName, v in pairs(self:data("treasurebox")) do
		list[boxName] = v
	end
	self:sendPacket(packet)
end

function Player:initCurrency()
	local wallet = self:data("wallet")
	local currency = Coin:GetCoinCfg()[1]
	if currency then
		wallet[currency.coinName] = self:newCurrency(currency.bigInteger)
	end
	local lockVision = World.cfg.lockVision and World.cfg.lockVision.open or false
	if lockVision then
		self:setLockVision(lockVision)
	end
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

function Player:getCurrencyBalance()
	local wallet = self:data("wallet")
	local currencyBalance = {}
	for coinName, v in pairs(wallet or {}) do
		local coinId = Coin:getCoinId(coinName)
		if coinId then
			table.insert(currencyBalance,{
				currency_type = coinId,
				currency_num = v.count
			})
		end
	end
	return currencyBalance
end

function Player:setCurrency(coinName, count)
	local currency = self:getCurrency(coinName, true)
	currency.count = count
	self:syncCurrency()
end

function Player:addCurrency(coinName, count, reason, related)
    local coin = Coin:getCoin(coinName)
    if not coin then
        return
    end
	local currency = self:getCurrency(coinName, true)
    currency.count = currency.count + count
	local args = {
		type = "currency",
		name = coinName,
		reason = reason,
		count = count,
		result = currency.count,
	}
	self:resLog(args, related)
    Trigger.CheckTriggers(self:cfg(), "ADD_CURRENCY", {coincount=count, obj1=self, coinName = coinName, reason=reason})
	if count ~= BigInteger.Create(0) then
		local updateInfo = {name = coinName, currency = currency, reason = reason}
		self:syncCurrencySingle(updateInfo)
	end
	-- 打印金币获得记录
	self:bhvLog("addCurrency_" .. coinName, string.format("addCurrency %s:count:%s,reason:%s", coinName, count,reason))
	--self:syncCurrency()

	GameAnalytics.MoneyFlow(self, Coin:getCoinId(coinName), count, true, reason, "")
end

function Player:setLockVision(state)
	local packet = {
		pid = "lockVision",
		state = state,
	}
	self:sendPacket(packet)
end

function Player:consumeDiamonds(coinName, diamonds, event, uniqueId)
	local coinId = Coin:getCoinId(coinName)
	if not coinId then
		return false
	end
    local session = Shop:AllocSession()
    Shop:registerBuyEvent(self.platformUserId, event, session)
	Lib.payMoney(self, uniqueId or 1, coinId, diamonds, function(isSuccess)
		Shop.requestBuyResult(self.platformUserId, isSuccess, session)
	end)
end

function Player:consumeItem(coinName,count,reason)
	local sloter = self:tray():find_item(coinName)
	if not sloter then
		return false
	end
	local fullName = sloter:cfg().fullName
	local ret = self:tray():remove_item(fullName,count,true)
	if ret then
		self:tray():remove_item(fullName,count,false,nil,nil,reason)

		GameAnalytics.ItemFlow(self, "", fullName, count, false, reason, "")
	end
	return ret
end

function Player:payCurrency(coinName,count,clear,check,reason,related)
	assert(coinName ~= "golds" and coinName ~= "gDiamonds", string.format("This type of currency cannot be defined:%s", coinName))
	if not count then
		return false
	end
	if os.getenv("startFromWorldEditor") then
		return true
	end
	if string.sub(World.GameName or "",-1) == "b" then -- beat 版,和编辑器启动一样直接返回true，购买成功
		return true
	end
	local currency = self:getCurrency(coinName)
    if not currency or currency.count < count then
        if clear and currency and not check then
            currency.count = 0
			self:syncCurrency()
		end
        return false
    end
	if not check then
		currency.count = currency.count - count
		local args = {
			type = "currency",
			name = coinName,
			reason = reason,
			count = -count,
			result = currency.count,
		}
		self:resLog(args, related)
		self:syncCurrency()
	end
	Trigger.CheckTriggers(self:cfg(), "USER_CONSUME_MONEY", {obj1 = self, coinName = coinName, count = count, reason=reason})
	GameAnalytics.MoneyFlow(self, Coin:getCoinId(coinName), count, false, reason, "")
	return true
end

function Player:getWalletBalance(coinName)
    local wallet = self:data("wallet")
    return wallet[coinName] and wallet[coinName].count or 0
end

function Player:UpdateDiamondsAndGolds(gDiamonds, golds)
	local wallet = self:data("wallet")
    if wallet["gDiamonds"] then
        wallet["gDiamonds"].count = gDiamonds or 0
    end
    if wallet["golds"] then
        wallet["golds"].count = golds or 0
    end
    self:syncCurrency()
end


function Player:syncCurrency()
	local packet = {
        pid = "SyncWallet",
        wallet = self:data("wallet")
    }
    self:sendPacket(packet)
end

--同步单个货币
function Player:syncCurrencySingle(updateInfo)
	local packet = {
		pid = "SynCurrencySingle",
		updateInfo = updateInfo
	}
	self:sendPacket(packet)
end

function Player:destroy()
	if not string.find(debug.traceback(), "RemoveLogoutPlayer") then
		return
	end
	for _, entity in pairs(self:data("pet")) do
		entity:destroy()
	end
	self:setData("pet", {})
	EntityServer.destroy(self)
end

local function getMapPos(self)
	local map = self.map
	if map and map.static and self:isSaveMapPos(map) then
		local mapPos = self:getPosition()
		mapPos.map = map.name
		mapPos.yaw = self:getRotationYaw()
		mapPos.pitch = self:getRotationPitch()
		self.saveMapPos = mapPos
	end
	return self.saveMapPos
end

local function getPetData(self)
	local pet = {}
	for index, entity in pairs(self:data("pet")) do
		local dat = entity:saveData()
		dat.cfg = entity:cfg().fullName
		dat.show = entity:getPosition()~=nil
		pet[index] = dat
	end
	return pet
end

local function getTaskData(self)
	local taskData = {}
	for name, td in pairs(self:data("task")) do
		if td.task.needSave == nil or td.task.needSave then
			local std = {
				targets = {},
				status = td.status,
			}
			for index, tar in ipairs(td.targets) do
				std.targets[index] = tar.tc.save(self, tar)
			end
			taskData[name] = std
		end
	end
	return taskData
end

local function checkNeedSaveData(data)
	-- print("want to know all keys? ", Lib.v2s(data, 1))
	local onlySaveData = World.cfg.onlySaveData
	if not onlySaveData then
		return
	end

	local saveKeys = {}
	if (type(onlySaveData) == "table") then
		for _, key in ipairs(onlySaveData) do
			saveKeys[key] = true
		end
	elseif (type(onlySaveData) == "string") then
		saveKeys[onlySaveData] = true
	end

	if not next(saveKeys) then
		return
	end
	for key in pairs(data) do
		if not saveKeys[key] then
			data[key] = nil
		end
	end
end

function Player:getMapPos()
	-- 游戏对本地函数getMapPos有重写，所以用Player:getMapPos获取
	return getMapPos(self)
end

local function getTaskPluginNeedSaveData(player)
	local data = {}
	for pluginName, pluginData in pairs(player:data("taskPlugin")) do
		if pluginData.needSave then
			data[pluginName] = pluginData
		end
	end

	return data
end

function Player:saveDBData()
	local data = self:saveData()
	data.pet = getPetData(self)
	data.taskData = getTaskData(self)
	data.saveMapPos = World.cfg.saveMapPos and self:getMapPos()
	data.wallet = self:data("wallet")
	data.taskFinish = self:data("taskFinish")
	data.treasurebox = self:data("treasurebox")
	data.signInData = self:data("signInData")
	data.rechargeData = self:data("rechargeData")
	data.chapters = self.chapters or {}
	data.store = self:data("store")
	data.taskPluginData = getTaskPluginNeedSaveData(self)
	data.insertData = self:data("__insertSaveData")
	checkNeedSaveData(data)

	Plugins.CallPluginFunc("OnPlayerSaveDB", self)

	return data
end

local function setMapPos(self, mapPos)
	self:setMap(self.world:getMap(mapPos.map))
	self:setPosition(mapPos)
	if mapPos.yaw then
		self:setRotationYaw(mapPos.yaw)
	end
	if mapPos.pitch then
		self:setRotationPitch(mapPos.pitch)
	end
	Trigger.CheckTriggers(self:cfg(), "ENTITY_TELEPORT", {obj1 = self, map = self.world:getMap(mapPos.map), init=true})
end

local function loadPetsData(self, data)
	for index, petData in pairs(data) do
		local pos = nil	-- petData.show and self:getFrontPos(2) or nil
		local entity = EntityServer.Create({cfgName = petData.cfg, pos = pos, name = self.name, owner = self})
		if entity then
			self:addPet(entity, index)
			entity:loadData(petData)
		end
	end
end

local function setWalletData(self, data)
	local wallet = self:data("wallet")
	for name, tb in pairs(data) do
		if (name ~= "golds" and name ~= "gDiamonds") then
			if type(tb.count) == "table" then
				tb.count = BigInteger.Recover(tb.count)
			end
			local t = wallet[name]
			if t then
				t.count = t.count + tb.count
			else
				wallet[name] = tb
			end
		end
	end
end

local function setTaskData(self, data)
	local targetData = self:data("task")
	for name, std in pairs(data) do
		local task = Player.TaskMap[name]
		if task then
			local td = {
				task = task,
				targets = {},
				status = std.status,
			}
			targetData[name] = td
			for index, tt in ipairs(task.targets) do
				td.targets[index] = self:loadTarget(tt, std.targets[index])
			end
			self:checkTaskStatus(name)
		else
			print("unknown task!", name)
		end
	end
end
function Player:initMapPos()
end
local function setEditorMapPos(entity)
    local testMap = World.cfg.testMap or "map001"
    local map = World.CurWorld:getMap(testMap)
    if map then
        local mapCfg = map.cfg
        entity:setMapPos(map, mapCfg.pos, mapCfg.yaw, mapCfg.pitch)
    end
end

local function setTaskPluginData(player, data)
	local taskPluginData = player:data("taskPlugin")
	for pluginName, pluginData in pairs(data) do
		taskPluginData[pluginName] = pluginData
	end
end

function Player:loadDBData(data)
    if World.cfg.saveMapPos and data.saveMapPos then
        if Lib.checkNumberValueIsNan(data.saveMapPos.x) or
				Lib.checkNumberValueIsNan(data.saveMapPos.y) or
				Lib.checkNumberValueIsNan(data.saveMapPos.z) then

            local initPos = WorldServer.defaultMap.cfg.initPos or World.cfg.initPos
            data.saveMapPos = initPos
            data.saveMapPos.map = World.cfg.defaultMap or "map001"
			Lib.logError("Error:data.saveMapPos contain a nan value:",Lib.v2s(data.saveMapPos))
        end
    end

	self:resetData()
	if self:isWatch() then
		local target = World.CurWorld:getEntity(self:getTargetId())
		if target then
			self:setMapPos(target.map, target:getPosition())
		end
	else
		setMapPos(self, World.cfg.saveMapPos and data.saveMapPos or self:getInitPos())
	end
	self:initMapPos()

	Game.SendGameInfo(self)--after get pos

	loadPetsData(self, data.pet or {})
	setWalletData(self, data.wallet or {})
	setTaskData(self, data.taskData or {})
	setTaskPluginData(self, data.taskPluginData or {})

	self:setData("taskFinish", data.taskFinish or {})
	self:setData("signInData", data.signInData or {})
	self:setData("store", data.store or {})
	self:setData("rechargeData", data.rechargeData or {})
	self.chapters = data.chapters or {}
	self:initRecharge()
	self:setData("treasurebox", data.treasurebox or {})
	self:setData("__insertSaveData", data.insertData)

	if self.curHp <= 0 then
		self.curHp = self:prop("maxHp")
	end
	self:loadData(data)
	--加一个trigger，让业务能直接拿到DB返回的原始data
	Trigger.CheckTriggers(self:cfg(), "PLAYER_LOAD_DATA", {obj1=self, data=data})
	return true
end

function Player:reconnect()
	-- TODO ex sync
	Game.SendGameInfo(self)
	Game.OnPlayerReconnect(self)
	
	self:reconnectSetMap()

	self:syncSkillMap()
	self:syncStudySkillMap()
	self:syncBuffMap()
	self:syncCurrency()
	self:syncStore()
	self:syncAnimoji()
	self:syncPet()
	self:syncTreasurebox()
	self:syncTrays()
	self:initRank()
	self:syncProp()

	AsyncProcess.LoadUserMoney(self.platformUserId)
end

function Player:onGetDBFailed(subKey)
	if not self:isValid() then
		return
	end
	perror("player kicked for load db data failed", self.platformUserId or 0, self.name or "nil", subKey)
	Game.KickOutPlayer(self, "game.loaddb.failed")
end

function Player:onGetPlayerDBData(_, data)
	if self.dataLoaded then
		return -- TODO: player may login repeat
	end
	
	local function loadPlayerData()
		local ok, msg = xpcall(self.loadDBData, traceback, self, data)
		if not ok then
			perror("player load db data failed", self.platformUserId, self.name, msg)
			Game.KickOutPlayer(self, "game.loaddb.failed")
			return
		end
		self.dataLoaded = true
		Game.OnPlayerLogin(self)
		Game.tryPlayerGetExchangeProps(self)
		self:syncCurrency()
		self:syncSkillMap()
		self:syncStudySkillMap()
		self:syncStore()
		self:initRank()
		self:syncAnimoji()
		AsyncProcess.LoadUserMoney(self.platformUserId)
	end

	if World.IsLibServer then
		loadPlayerData()
		return
	end

	AsyncProcess.PlayerLoadDetailInfo(self, function(success)
		if success then
			loadPlayerData()
		else
			Game.KickOutPlayer(self, "game.loaddb.failed")
		end
	end)
end

function Player:onGetHomeDBData(_, data)
	if self.home then
		self.home:loadData(data)
	end
end

function Player:regCallBack(modName, eventMap, once, needId, context)
	local data = self:data("callBack")
	local regId = nil
	if needId then
		regId = (data.regId or 0) + 1
		data.regId = regId
	end
	data[modName] = {
		eventMap = eventMap,
		context = context,
		once = once,
		regId = regId
	}
    return regId
end

local callBackDefaultContinueTime = 120
function Player:checkRemoteCallbackTimeout()
	local data = self:data("remoteCallBack")
	if self.remoteCallbackCheckTimer then
		self.remoteCallbackCheckTimer()
	end
	self.remoteCallbackCheckTimer = self:timer(20 * 60, function()
		if not next(data) then
			self.remoteCallbackCheckTimer = nil
			return false
		end
		local now = World.Now()
		for modName, regMap in pairs(data) do
			if modName == "regId" then
				goto CONTINUE
			end
			for regId, callbackMap in pairs(regMap) do
				if callbackMap.endTime <= now then
					regMap[regId] = nil
				end
			end
			if not next(regMap) then
				data[modName] = nil
			end
			::CONTINUE::
		end
		return true
	end)
end

-- data = {regId = 1++, modName1 = {}, modName2 = {}, ...}
function Player:regRemoteCallback(modName, eventMap, once, needId, context, displace, time)
	local data = self:data("remoteCallBack")
	local regId = (data.regId or 0) + 1
	data.regId = regId

	local regMap = data[modName]
	if not regMap or displace == nil or displace == true then
		regMap = {}
		data[modName] = regMap
	end
	regMap[regId] = {
		eventMap = eventMap,
		context = context,
		once = once,
		regId = regId,
		continueTime = time or callBackDefaultContinueTime,
		endTime = World.Now() + ((time or callBackDefaultContinueTime) * 20)
	}
	-- 过期处理
	if not self.remoteCallbackCheckTimer then
		self:checkRemoteCallbackTimeout()
	end
    return needId and regId or nil
end

local function handleModCallback(self, mod, modName, key, regId, context)
	if not mod then
		print("doCallBack handleModCallback - no modName!", modName)
		return false
	end
	if mod.regId and mod.regId~=regId then
		print("doCallBack handleModCallback - wrong regId!", modName, mod.regId, regId)
		return false
	end
	if not mod.eventMap then
		mod = mod[regId or 1] or mod
	end
	local event = mod.eventMap and mod.eventMap[key]
	if not event then
		if event==nil then
			print("doCallBack handleModCallback - wrong key!", modName, key)
		end
		return false
	end

	context = context or {}
	for k, v in pairs(mod.context or {}) do
		context[k] = v
	end
	context.obj1 = self
	Trigger.CheckTriggers(self:cfg(), event, context)
	return true
end

function Player:doCallBack(modName, key, regId, context)
	local data = self:data("callBack")
	local mod = data[modName]
	if not handleModCallback(self, mod, modName, key, regId, context) then
		print("Player:doCallBack -- handleModCallback error! ")
		return
	end
	if mod.once then
		data[modName] = nil
	end
end

function Player:doRemoteCallback(modName, key, regId, context)
	local data = self:data("remoteCallBack")
	local mod = data[modName] and (regId and data[modName][regId] or data[modName][1])
	if not handleModCallback(self, mod, modName, key, regId, context) then
		print("Player:doRemoteCallback -- handleModCallback error! ")
		return
	end
	if mod.once then
		data[modName][regId or 1] = nil
	else
		mod.endTime = World.Now() + (mod.continueTime or callBackDefaultContinueTime) * 20
	end
end

function Player:getCallBackRegId(modName)
	local data = self:data("callBack")
	return data[modName] and data[modName].regId
end

function Player:checkPlayerAreaCount(distance)
	local count = 0
	if self:cfg().checkAreaDistance == nil then
		return
	end
	local pos = Lib.tov3(self:getPosition())
    for _, v in pairs(Game.GetSurvivePlayers()) do
        repeat
            if v.platformUserId == self.platformUserId then
                break
            end
            if pos:inArea(v:getPosition(), distance) then
                count = count + 1
            end
        until true
    end
	return count
end

function Player:setHeartbeatSpeed(interval)
    local soundInfo = self:data("soundInfo")
    if soundInfo.interval == interval then
        return
    end
    soundInfo.interval = interval
    local packet = {
		pid = "SetHeartbeatSpeed",
		interval = interval
	}
	self:sendPacket(packet)
end

function handle_createplayer(param)
    local worldCfg = World.cfg
    local playerCfg = Entity.GetCfg(worldCfg.playerCfg)
	---@type EntityServerPlayer
    local player = Player.CreatePlayer(playerCfg.id, param.ssid)
	assert(player, worldCfg.playerCfg)

	player:setName(param.name)
	player.dispatchReqId = param.reqId
	player.platformUserId = param.platformUserId
	player.luaObjID = player.objID
	player.luaName = player.name
	player.luaPlatformUserId = player.platformUserId
	player.language = param.language or "en_US"

	if param.clientInfo then
		local status, ret = pcall(cjson.decode, param.clientInfo)
		if status then
			player.clientInfo = ret
		else
			perror("handle_createplayer", ret, param.clientInfo)
		end
	end
	local attrInfo = player:getPlayerAttrInfo()
	local followEnterType = attrInfo.mainInfo.followEnterType

	if followEnterType > 0 then
		local target = Game.GetPlayerByUserId(attrInfo.mainInfo.targetUserId)
		if followEnterType == 1 then
			if target then
				target:sendTip(1, "user_follow_join_game", 80, nil, nil, player.name)
			end
		elseif followEnterType == 2 then
			if target then
				player:setMode(player:getObserverMode())
				Game.UpdatePlayerInfo(player)
				player:setTargetId(target.objID)
				target:sendTip(1, "user_watch_game", 80, nil, nil, player.name)
			else
				print("[error] follow enter target player not exist.")
			end
		end
		player:followInterfaceDataReport({followEnterType == 1 and "follow_watch" or "follow_game", World.GameName})
	end

	player:initPlayer()
	player:invokeCfgPropsCallback()
	player:resetData()
	--player:setValue("camp", Define.CAMP_PLAYER_DEF) --为兼容老项目,CAMP_PLAYER_DEF没有默认给player设置上
	player:onCreate()
	ExecUserScript.chunk(playerCfg, player, "_serverScript")
    return player
end

function player_touchdown(entity)
	local cfg = entity:cfg()
	if cfg.touchdownTimeToDie and entity.curHp > 0 then
		local tttda = entity.touchdownTimeToDieArray
		local now = World.Now()
		if not tttda or ( (now - (tttda[#tttda] or now)) > cfg.touchdownInterval) then
			tttda = {}
			entity.touchdownTimeToDieArray = tttda
		end
		if #tttda >= ((cfg.touchdownTimeToDieTick or 3) - 1) then
			entity:doDamage({
				damage = entity.curHp + 1,
				cause = "ENGINE_TOUCHDOWN",
			})
			entity.touchdownTimeToDieArray = {}
			return
		end
		tttda[#tttda + 1] = now
	end
    local buff = cfg and cfg.touchdownBuff
	if entity.curHp > 0 and buff then
		entity:addBuff(buff, cfg.touchdownBuffTime or 20)
	end
	local context = {
		canDoDamage = true,
		obj1 = entity,
	}
	Trigger.CheckTriggers(entity:cfg(), "ENTITY_TOUCHDOWN", context)
	entity:EmitEventAsync("OnFallOffMap")
	if not context.canDoDamage then
		return
	end
	entity:doDamage({
		damage = cfg.touchdownDamage or 5,
		cause = "ENGINE_TOUCHDOWN",
	})
end

function release_manor(platformUserId)

end

function Player:searchItem(cfgKey, val)
	local sloter = EntityServer.searchItem(self, cfgKey, val)
	if sloter and not sloter:null() then
		return sloter
	end

	local pets = self:data("pet")
	for _, pet in pairs(pets) do
		local sloter = pet:searchItem(cfgKey, val)
		if sloter and not sloter:null() then
			return sloter
		end
	end
end

function Player:setCameraYaw(target)
	if not target then
		return
	end
	self:sendPacket({
		pid = "SetCameraYaw",
		objID = target.objID
	})
end

function Player:isDead()
	return self.curHp <= 0
end

function Player:UpdataRoutine(content, data)
	local vars = self.vars
	local m_content = vars.routine or {}
	if #m_content == 0 then
		m_content = Lib.copy(content)
		vars.getTaskTime = os.time()
		vars.routine = m_content
	end
	local packet = {
		pid = "ShowRoutine",
		open = true,
		content = m_content,
		data = Lib.copy(data) or {}
	}
	self:sendPacket(packet)
end

function Player:showCountDown(time, flag)
	self:sendPacket({
		pid = "ShowDeadCountDown",
		time = time,
		notHideMain = flag
	})
end

function Player:showBuyRevive(time, coin, cost, event, title, sure, cancel, msg, newReviveUI)
	local regId = self:regCallBack("buyRevive", { ["1"] = event }, true, true )
	self:sendPacket({
		pid = "ShowBuyRevive",
		time = time,
		coin = coin,
		cost = cost,
		regId = regId,
		title = title,
		sure = sure,
		cancel = cancel,
		msg = msg,
		newReviveUI = newReviveUI
	})
end

local TipType = {
	HINT = 0,
    REVIVE = 1,
    COMMON = 2,
    CONSUME = 3,
    REWARD = 4,
    PAY = 5,
	EFFECT = 6
}
function Player:showRewardTip(tipType, rewardTb)
	if tipType == TipType.EFFECT and #rewardTb == 1 then
		local data = rewardTb[1].data
		self:sendPacket({
			pid = "ShowRewardItemEffect",
			key = data and data.name,
			count = data and data.count or 1,
			type = data and data.type
		})
	elseif tipType ~= TipType.EFFECT then
		self:showDialogTip(tipType, false, {rewardTb})
	end
end

function Player:showDialogTip(tipType, event, args, context)
	local regId = event and self:regCallBack("dialogTip", {[tostring(tipType)] = event}, false, true, context)
	self:sendPacket({
		pid = "ShowDialogTip",
		tipType = tipType or 0,
		regId = regId,
		args = args
	})
end

function Player:setGuideStep(step, nextOnly, canBack, noSyncClient) -- 原setGuideStep方法
	local oldStep = self:getValue("guideStep")
	if not step or not oldStep then
		self:setValue("guideStep", step)
		return true
	end
	local oldIndex, newIndex = 0, nil
	for index, cfg in ipairs(World.guideCfg) do
		if cfg.saveKey==step then
			newIndex = index
		end
		if cfg.saveKey==oldStep then
			oldIndex = index
		end
	end
	if not newIndex then
		print("no guide step:", step)
		return false
	end
	if not canBack and newIndex<oldIndex then
		return false
	elseif nextOnly and oldIndex+1~=newIndex then
		return false
	end
	self:setValue("guideStep", step, noSyncClient)
	print("set guide step", step)
	return true
end

function Player:dropOnDie()
	EntityServer.dropOnDie(self)
	local pos = self:getPosition()
	local trayArray = self:tray():query_trays(function() return true end)
	for _, element in pairs(trayArray) do
		local tray_obj = element.tray
		local items = tray_obj:query_items(function(item)
			return item:can_drop() == true
		end)
		for slot in pairs(items) do
			local item = tray_obj:remove_item(slot)
			local dropItem, block_cfg
			if not item:is_block() then
				dropItem = Item.CreateItem(item:full_name(), item:stack_count())
			else
				local block_id = item:block_id()
				block_cfg = Block.GetIdCfg(block_id)
				dropItem = Item.CreateItem("/block", item:stack_count(), function(dropItem)
					dropItem:set_block_id(block_id)
				end)
			end
			local imcV3 = {
				x = 0.5 + (math.random()-0.5),
				y = 0.8,
				z = 0.5 + (math.random()-0.5)
			}
			self:dropDropitem({
				map = self.map, selfPos = pos, imcV3 = imcV3, item = dropItem, 
				lifeTime = item:cfg().droplifetime, guardTime = item:cfg().dropGuardTime or (block_cfg and block_cfg.dropGuardTime)
			})
		end
	end
end

function Player:removeOnDie()
	--EntityServer.removeOnDie(self)
	local trayArray = self:tray():query_trays(function() return true end)
	for _, element in pairs(trayArray) do
		local tray_obj = element.tray
		local items = tray_obj:query_items(function(item)
			return item:die_remove() == true
		end)
		for slot in pairs(items) do
			tray_obj:remove_item(slot)
		end
	end
end

function Player:AttachDebugPort(sessionId)
	local packet = {
		pid = "AttachDebugPort",
		sessionId = sessionId
	}
	self:sendPacket(packet)
end

function Player:DetachDebugPort(sessionId)
	local packet = {
		pid = "DetachDebugPort",
		sessionId = sessionId
	}
	self:sendPacket(packet)
end

function Player:doClientCmd(cmd, sessionId, callBack, ...)
	local packet = {
		pid = "DoCmd",
		cmd = cmd,
		sessionId = sessionId
	}
	if callBack then
		local cmdCB = self:data("cmdCallBack")
		local serialNum = #cmdCB + 1
		packet.serialNum = serialNum
		cmdCB[serialNum] = table.pack(callBack, ...)
	end
	self:sendPacket(packet)
end

function Player:sendKillerInfo(killer, weaponName, reviveCost, event, timeout)
	local weapon
	local cfg
	if weaponName and weaponName~="" then
		cfg = setting:fetch("item", weaponName)
	end
	if cfg then
		local buff = cfg.handBuff and setting:fetch("buff", cfg.handBuff) or {}
		weapon = {
			name = weaponName,
			props = {
				{"itemtype", cfg.itemtype or ""},
				{"damage", buff.damage or 0},
				{"critDmgProb", buff.critDmgProb or 0},
				{"critDmgPct", buff.critDmgPct or 0},
				{"itemintroduction", cfg.itemintroduction or ""},
			},
		}
	end
	local equips = {}
	local trays = killer:data("tray"):query_trays(function(tray)
		return tray:class() == Define.TRAY_CLASS_EQUIP
	end)
	for _, element in pairs(trays) do
		for _, item in pairs(element.tray:query_items()) do
			local cfg = item:cfg()
			local buff = cfg.equip_buff and setting:fetch("buff", cfg.equip_buff) or {}
			equips[#equips + 1] = {
				name = cfg.fullName,
				props = {
					{"itemtype", cfg.itemtype or ""},
					{"defense", buff.defense or 0},
					{"maxHp", buff.maxHp or 0},
					{"dodgeDmgProb", buff.dodgeDmgProb or 0},
					{"itemintroduction", cfg.itemintroduction or ""},
				},
			}
		end
	end
	local actor = {
		name = killer:data("main").actorName or killer:cfg().actorName,
		scale = 0.65,
	}
	local regId = self:regCallBack("killerInfo", {key = event}, false, true, {})
	self:sendPacket({
		pid = "ShowKillerInfo",
		name = killer.name,
		isPlayer  = killer.isPlayer,
		actor = actor,
		level = killer.isPlayer and killer:getValue("level") or killer:cfg().level or 1,
		weapon = weapon,
		equips = equips,
		cost = reviveCost,
		regId = regId,
		timeout = timeout,
	})
end

function Player:stats(typ, data)
	if typ == "ping" then
		local time = os.time()
		local last = self.lastStatPingTime or 0
		if time - last < 60 then
			return
		end
		self.lastStatPingTime = time
	end
	data = data or {}
	data.userId = self.platformUserId
	Game.Stats(typ, data)
end

--完成广告观看
function Player:watchAdFinished(type, params)
	Trigger.CheckTriggers(self:cfg(), "WATCH_AD_FINISHED", { obj1 = self, type = type, params = params})
end

--广告观看失败
function Player:watchAdFailed(type, params)
	Trigger.CheckTriggers(self:cfg(), "WATCH_AD_FAILED", { obj1 = self, type = type, params = params})
end

function Player:onPlayerInvite(packet)
	local targetUserId = packet.targetUserId
	local content = packet.content or {}
	local crossServer = packet.crossServer
	if not targetUserId and crossServer then
		Trigger.CheckTriggers(self:cfg(), "ON_SEND_INVITE_TO_GAME", {obj1 = self, content = content })
		return
	end
	if type(targetUserId) ~= "table" then
		targetUserId = {tonumber(targetUserId)}
	end
	local targetIds = {}
	for _, id in ipairs(targetUserId) do
		id = tonumber(id)
		local target = Game.GetPlayerByUserId(id)
		if not target then
			targetIds[#targetIds + 1] = id
			goto continue
		end
		Trigger.CheckTriggers(target:cfg(), "PLAYER_BE_INVITE", {obj1 = target, obj2 = self, content = content })
		::continue::
	end
	if next(targetIds) and crossServer then
		content.regionId = self:data("mainInfo").regionId or 0
		AsyncProcess.SendBroadcastMessage(targetIds, content, Define.BROADCAST_INVITE, "user")
	end
end

function Player:onPlayerVisit(packet)
	local targetUserId = tonumber(packet.targetUserId)
	local content = packet.content or {}
	local target = Game.GetPlayerByUserId(targetUserId)
	if not target and packet.crossServer then
		Trigger.CheckTriggers(self:cfg(), "PLAYER_ON_VISIT_OTHER_SERVER", {obj1 = self, targetUserId = targetUserId, content = content})
		return
	end
	Trigger.CheckTriggers(self:cfg(), "PLAYER_ON_VISIT", {obj1 = self, obj2 = target, content = content})
end

function Player:bhvLog(typ, desc, target, related)
	local data = {
		behavior = typ,
		desc = desc or "",
		target = target,
		userId = self.platformUserId,
	}
	Game.Stats("behavior", data, related)
end

function Player:resLog(args, related)
	assert(args.type)	-- 资源大类�
	assert(args.name)	-- 具体资源名（如道具fullname、货币名称）
	assert(args.reason)	-- 资源来源（原因）
	local count = args.count or 1	-- 资源数量
	local desc = args.desc
	if not desc then
		if type(count) == "table" then
			desc =args.name ..count:debugFullFormat()--  string.format("%s %s%d", , count>=0 and "+" or "",type(count) == "table" and  or count)
		else
			desc = string.format("%s %s%d", args.name, count>=0 and "+" or "", count)
		end
		
		if args.result then
			desc = desc .. " =" .. args.result
		end
	end
	local data = {
		behavior = string.format("%s_%s", args.type, count>=0 and "add" or "dec"),
		target = args.name,
		count = count,
		result = args.result,
		desc = desc,
		reason = args.reason,
		userId = self.platformUserId,
	}
	Game.Stats("behavior", data, related)
end

function Player:getStoreItemStatus(storeId, index)
	local key = tostring(Bitwise64.Or(Bitwise64.Sl(storeId, 16), index))
	local item = Store:getStoreItem(storeId, index)
	local status = self:data("store")[key]
	return status or item.status
end

function Player:syncStore()
	local packet = {pid = "SyncStore", store = self:data("store")}
	self:sendPacket(packet)
end

function Player:syncStoreItemInfo(storeId, itemIndex, status, remainTime, msg)
	local packet = {pid = "SyncStoreItemInfo", storeId = storeId, itemIndex = itemIndex, status = status, remainTime = remainTime, msg = msg}
	self:sendPacket(packet)
end

function Player:crossServerLogin(targetUserId)
	PlayerDBMgr.SaveImmediate(self)
    self:sendGotoOtherGame(targetUserId, World.GameName, "")
end

function Player:reenterGame()
	PlayerDBMgr.SaveImmediate(self)
    self:sendGotoOtherGame(self.platformUserId, World.GameName, "")
end

function Player:switchGameMode(gameMode)
	local params = ""
	if gameMode and string.len(gameMode) > 0 then
		params = '{"gameMode": "' .. gameMode .. '"}'
	end
	Lib.logDebug("jump server", params)
	self:reenterGameByMode(params)
end

function Player:reenterGameByMode(attributes)
	PlayerDBMgr.SaveImmediate(self)
	print("zyy: reenterGameByMode attributes:", attributes)
    self:sendGotoOtherGame(self.platformUserId, World.GameName, "", attributes or "")
end

function Player:syncCameraMode(isOpen)
	self:setCameraMode(isOpen)
	local packet = {pid = "SyncCameraMode", isOpen = self:isCameraMode()}
	self:sendPacket(packet)
end

function Player:syncAnimoji()
	local userId = self.platformUserId
	AsyncProcess.GetUserAnimoji(userId, function(data)
		local player = Game.GetPlayerByUserId(userId)
		if not player then
			return
		end
		local animoji = {}
		if data and data.selectable_action then
			local actions =  Lib.splitString(data.selectable_action, "-")
			for _, actionId in pairs(actions) do
				animoji[actionId] = true
			end
		end

		player:setData("animoji", animoji)
		player:sendPacket({
			pid = "UpdateAnimoji",
			data = animoji
		})
	end)
end

function Player:onLeaveMap(map)
	self:updateShowPetsOnLeaveMap(map)
	-- todo ex
	if self:cfg().saveDBWithLeaveMap and not self.Logouting then
		PlayerDBMgr.SaveImmediate(self)
	end
	EntityServer.onLeaveMap(self, map)
end

function Player:onEnterMap(map)
	self:updateShowPetsOnEnterMap(map, self:getPosition())
	EntityServer.onEnterMap(self, map)
end

function Player:onReceiveCommonReward(propsType, propsId, propsCount, expireTime)
	print("Player:onReceiveCommonReward", propsType, propsId, propsCount, expireTime)
end

function Player:followInterfaceDataReport(parts)
	--print("................", Lib.v2s(parts))
	GameAnalytics.Design(self.platformUserId ,nil ,parts )
end

local function getTrayItemData(self, tid, slot, itemCheckFunc)
	local tray_obj = self:tray():fetch_tray(tid)
	if not tray_obj then
		return
	end
	local itemData = tray_obj:fetch_item(slot)
	if not itemData then
		return
	end
	if itemCheckFunc and not itemCheckFunc(itemData) then
		return
	end
	return itemData
end

function Player:abandonTrayItem(params)
	local tid = params.tid
	local slot = params.slot
	local oldItemData = getTrayItemData(self, tid, slot, function(itemData)
		return itemData:cfg().canAbandon ~= false
	end)
	if not oldItemData then
		return false
	end
	local vars = oldItemData.vars
	local fullName = oldItemData:full_name()
	local max_count = oldItemData:stack_count()
	local p_count = params.count or max_count
	local drop_count = math.min(p_count, max_count)
	local dropItem
	if fullName == "/block" then
		dropItem = Item.CreateItem("/block", drop_count, function(itemData)
			itemData:set_block_id(oldItemData:block_id())
		end)
	else
		dropItem = Item.CreateItem(fullName, drop_count)
	end
	if not dropItem then
		return false
	end
	if vars then
		for key, value in pairs(vars) do
			if key ~= "cfg" then
				dropItem:setVar(key, value)
			end
		end
	end
	DropItemServer.Create(
			{
				map = self.map,
				pos = params.pos or self:getPosition(),
				item = dropItem,
				lifeTime = params.lifeTime,
				pitch = params.pitch,
				yaw = params.yaw,
				moveSpeed = params.moveSpeed,
				moveTime = params.moveTime,
				guardTime = params.guardTime
			}
	)
	if p_count < max_count then
		oldItemData:set_stack_count(max_count - p_count)
	else
		self:tray():fetch_tray(tid):remove_item(slot)
	end
	return true
end

function Player:removeTrayItem(params)
	local tid = params.tid
	local slot = params.slot
	local itemData = getTrayItemData(self, tid, slot)
	if not itemData then
		return false
	end
	local max_count = itemData:stack_count()
	local p_count = params.count
	if p_count and p_count < max_count then
		itemData:set_stack_count(max_count - p_count)
	else
		self:tray():fetch_tray(tid):remove_item(slot)
	end
	return true
end

local STATIC_FIND_TRAYS = {
	Define.TRAY_TYPE.BAG,
	Define.TRAY_TYPE.HAND_BAG
}
function Player:splitTrayItem(params)
	local splitCount = params.count
	if not splitCount then
		return false
	end
	local tid = params.tid
	local slot = params.slot
	local itemData = getTrayItemData(self, tid, slot)
	if not itemData then
		return false
	end
	local stack_count = itemData:stack_count()
	if splitCount >= stack_count then
		return false
	end
	local s_tray = self:tray()
	local trays = s_tray:query_trays(params.findTrays or STATIC_FIND_TRAYS)
	local t_tid, t_slot, t_tray
	for _, trayTb in ipairs(trays) do
		local tray = trayTb.tray
		local f_slot = tray:find_free()
		if f_slot then
			t_tid = trayTb.tid
			t_slot = f_slot
			break
		end
	end
	if not t_tid then
		return false
	end

	local fullName = itemData:full_name()
	if fullName == "/block" then
		s_tray:add_item_in_slot(t_tid, t_slot, "/block", splitCount, function(item)
			item:set_block_id(itemData:block_id())
		end)
	else
		s_tray:add_item_in_slot(t_tid, t_slot, fullName, splitCount)
	end

	itemData:set_stack_count(stack_count - splitCount)
	return true
end

function Player:canPickDropItem(dropItem)
	if self:cfg().canPickOnDie or self.curHp > 0 then
		return true
	end
	return false
end

function Player:changeFlyMode(mode)
	self:setFlyMode(mode)
	self:sendPacketToTracking({ pid = "SyncFlyMode", mode = mode, objID = self.objID}, true)
end

function Player:exchangeCDKey(key)
	AsyncProcess.PostCDKey(self.platformUserId, key)
end

function Player:syncProp()
	self:sendPacket({
		pid = "SyncProp",
		props = self:data("prop"),
		objID = self.objID
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

--插入需要存储的玩家数据 force:如果数据存在，是否强制插入
function Player:insertSaveData(key, data, force)
	local ok, ret = pcall(seri.serialize_string, data)
	--检测存储数据的合法性，只能存储简单的数据类型（number,string,table,boolean）
	if not ok then
		return false, ret
	end
	local insertData = self:data("__insertSaveData")
	if insertData[key] and not force then
		return false, "Data already exists!"
	end
	insertData[key] = data
	return true
end

--移除插入的存储数据,返回移除数据
function Player:removeInsertSaveData(key)
	local insertData = self:data("__insertSaveData")
	local data = insertData[key]
	insertData[key] = nil
	return data
end

--获取插入的玩家存储数据
function Player:getInsertSaveData(key)
	local insertData = self:data("__insertSaveData")
	return insertData[key]
end

function Player:SetForceSwim(enable)
	self:setForceSwimMode(enable)
	self:sendPacket({
		pid = "SetForceSwim",
		enable = enable,
	})
end

function Player:SetForceClimb(enable, speed, angle)
	self:setForceClimbMode(enable, speed, angle)
	self:sendPacket({
		pid = "SetForceClimb",
		enable = enable,
		speed = speed,
		angle = angle,
	})
end

function Player:RequestFriendList(callback,first,last)
	if not self.allFriendData then 
		self:initServerFriendDataList()
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

	AsyncProcess.GetChatFriend(self.platformUserId, self.allFriendData.language,0, 500, asyncCallback)
end

function Player:RequestIsFriendWith(UserID,callback)
	if not UserID or not callback then 
		return 
	end
	if not self.allFriendData then 
		self:initServerFriendDataList()
	end
	local isFriend = self:checkPlayerIsMyFriend(UserID)
	if isFriend == nil then 
		
		local function asyncCallback(data)
			local isFriend = false
			for _,id in pairs(data) do 
				if id == UserID then isFriend = true break end
			end
			if callback then 
				callback(isFriend)
			end
		end
		
		AsyncProcess.GetChatFriendUserId(self.platformUserId,self.allFriendData.language,asyncCallback)
	else 
		if callBack then 
			callBack(self:checkPlayerIsMyFriend(UserID) ~= Define.friendStatus.notFriend)
		end
	end
end

function Player:GetUserData(callback)
	if not self.allFriendData then 
		self:initServerFriendDataList()
	end
	local function asyncCallback(data)
		local info = data
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
	
	AsyncProcess.GetUserDeatailInfo(self.platformUserId,self.platformUserId,self.allFriendData.language, asyncCallback)
end