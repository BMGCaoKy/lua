local misc = require "misc"
local debugport = require "common.debugport"
local setting = require "common.setting"
local remotedebug = require "common.debug.remotedebug"

local NpcPos={}

local handles = T(Player, "PackageHandlers") ---@class PlayerPackageHandlers
local packetCacheQueue = L("packetCacheQueue", {})
local receivedGameInfo = L("receivedGameInfo", false)

Player.CurPlayer = Player.CurPlayer    -- set after login (GameInfo packet)
local LogicPing = 0

local Ping = T(Player, "Ping")

local upgrade_shop = T(Player, "espcially_shop_data")

local function dealPacket(packet)
    local func = handles[packet.pid]
    if not func then
        print("no handle!", packet.pid)
        return
    end
    Profiler:begin("handle_packet."..packet.pid)
    CPUTimer.StartForLua("handle_packet."..packet.pid)

    local InitGameReportProcess ={InitGameBegin = 7, InitGameFailed = 8, InitGameSuc = 9}
    local isGameInfo = ( packet.pid =="GameInfo")
    if(isGameInfo) then
        ClientDataReport.ReportGameStartProcess(InitGameReportProcess.InitGameBegin, "");
    end
    local ok, ret = xpcall(func, traceback, Player.CurPlayer, packet)
    Profiler:finish("handle_packet."..packet.pid)
    CPUTimer.Stop()
    if not ok then
        perror("dealPacket", ret)
        GM:sendErrMsgToChatBar(ret)
        if isGameInfo then
            ClientDataReport.ReportGameStartProcess(InitGameReportProcess.InitGameFailed, "HandleGameInfoFailed");
        end
    elseif(isGameInfo) then
        ClientDataReport.ReportGameStartProcess(InitGameReportProcess.InitGameSuc, "");
    end
end

local function getMilliseconds()
	return math.floor(misc.now_nanoseconds() / 1000000)
end

local function handle_delay_packet()
    if not receivedGameInfo or #packetCacheQueue == 0 then
        return
    end
    
    local threshold = Blockman.instance.gameSettings:getMaxEventsHandleTime() or 100
	local startTime = getMilliseconds()
	while #packetCacheQueue ~= 0 and getMilliseconds() - startTime < threshold do
        dealPacket(packetCacheQueue[1])
        table.remove(packetCacheQueue, 1)
	end
end

function handle_packet(data)
    Profiler:begin("handle_packet")
    Profiler:begin("decode_packet")
    local packet = misc.data_decode(data)
    packet = Packet.Decode(packet)
    Profiler:finish("decode_packet")
    World.AddPacketCount(packet.pid, #data, false)
    if packet.pid == "ShowInfoPanel" then
        dealPacket(packet)
    elseif packet.pid == "GameInfo" then
        dealPacket(packet)
        Lib.emitEvent(Event.EVENT_FINISH_DEAL_GAME_INFO)
        Event:EmitEvent("OnClientInitDone")
        receivedGameInfo = true
        print("cached packet count before GameInfo: ", #packetCacheQueue)
        -- for _, packet in ipairs(packetCacheQueue) do
        --     print("cached packet: ", Lib.v2s(packet, 1))
        --     RunTime:AddTime(packet.pid)
        --     RunTime:StartRecord("HandleDelayedPacket")
        --     dealPacket(packet)
        --     RunTime:StopRecord("HandleDelayedPacket")
        -- end
        -- packetCacheQueue = {}
    elseif receivedGameInfo and #packetCacheQueue == 0 then
        dealPacket(packet)
    else
        packetCacheQueue[#packetCacheQueue + 1] = packet
        handle_delay_packet()
    end

    Profiler:finish("handle_packet")
end

local function getPing(ip)
	local time = misc.end_ping(ip)
	misc.begin_ping(ip, 5000, true)
	return time
end

local function sendPing()
	if Ping.LastRecvTime==false then
		print("ping no reply")
		return true
	end
	local now = misc.now_microseconds()
	local packet = {
		pid = "ping",
		lastTime = Ping.LastRecvTime or now,
		time = now,
        ping = {CGame.instance:getPing(), getPing("8.8.8.8")},
        --fps = CGame.instance:getCurrentFps(),
        logicPing = LogicPing
	}
	Player.sendPacket(Player.CurPlayer, packet)	--Player.CurPlayer doesn't have to exist at this time
	Ping.LastRecvTime = false
	return true
end

if Ping.Timer then
	Ping.Timer()
end

if not Blockman.instance.singleGame then
    Ping.Timer = World.Timer(10 * 20, sendPing)
end

function handles:ping(packet)
	Ping.LastRecvTime = misc.now_microseconds()
	local ping = (misc.now_microseconds() - packet.time) / 2000
	LogicPing = math.floor(ping)
	CGame.instance:setLogicPing(LogicPing)
end

function handles:resp(packet)
	local func = assert(Session[packet.session])
	Session[packet.session] = nil

	func(table.unpack(packet.ret))
end

function handles:EnterEditorMode()
    EditorModule:emitEvent("enterEditorMode")
end

function handles:SyncPlayerName(packet)
    self:setName(Lang:toText(packet.name))
    self:updateShowName()
end

function handles:GameInfo(packet)
    Plugins.CallPluginFunc("onGameReady")
    Lib.setBoolProperty("isGameParty", packet.isGameParty or false)
	local bm = Blockman.instance
    ---@type World
	local world = World.CurWorld
    world:setTimeStopped(packet.isTimeStopped)
    world:setWorldTime(packet.worldTime)
	debugport.serverPort = packet.debugport

    -- self is nil before this
    local cfg = Entity.GetCfg(packet.cfgName)
    assert(cfg, packet.cfgName)
    Me = {}---@type EntityClientMainPlayer
    self = bm:createMainPlayer(cfg.id, packet.objID, packet.actorName)
    Player.CurPlayer = self ---@type EntityClientMainPlayer
	Me = self ---@type EntityClientMainPlayer

    ---重写os.time，使其跟服务器时间对应上
    Me:sendPacket({
        pid = "GetServerOsTime",
        clientTime = os.time(),
    }, function (data)
        if not data or type(data) ~= "table" then
            return
        end
        local oldOsTime = os.time
        os.time = function(table)
            return oldOsTime(table) - data.serverTs
        end
    end)

    self:setEntityMode(packet.mode, packet.targetId)
    self:addLocalChunkData(packet.map.id, packet.mapChunkData)
	world:loadCurMap(packet.map, packet.pos, packet.mapChunkData)

	self.onGround = false
    self:initPlayer()
    self:setShowHpColor(0x00ff00)
    local setHpIntoBar = World.cfg.setHpIntoBar
    self:setShowHpMode(setHpIntoBar and 1 or 0)
    self:setShowHpTextColor(setHpIntoBar and 0xff000000 or 0x00000000) -- alpha 255 black


    Game.SetAudioDir(packet.audioDir)
    Game.SetGameMode(packet.gameMode)
    CGame.instance:setGetServerInfo(true);
    self:data("main").actorName = packet.actorName--must behind self:initPlayer()
	self:applySkin(packet.skin)
    --tmp - after map loaded

	local worldCfg = World.cfg
	local WorldCameraCfg = worldCfg.cameraCfg
	if WorldCameraCfg then
		bm.gameSettings:loadCameraCfg(WorldCameraCfg)
    end
    local viewMode = World.CurWorld.isEditor and worldCfg.editorViewMode
	viewMode = viewMode or WorldCameraCfg and WorldCameraCfg.defaultView
	viewMode = viewMode or worldCfg.viewMode or self:cfg().defaultView or 0
	bm:setPersonView(viewMode)
	if WorldCameraCfg then
		local defaultPitch = WorldCameraCfg.defaultPitch
		local defaultYaw = WorldCameraCfg.defaultYaw
		Player.CurPlayer:changeCameraView(nil, defaultYaw, defaultPitch, nil, 1)
	end
    --bm:setSingleViewMode(World.cfg.singleViewMode)

    if not World.CurWorld.isEditor and worldCfg.viewMode then
        bm.gameSettings.cameraYaw = self:getBodyYaw() - 90
    end

	World.CurWorld:setNeedShowLuaErrorMessage(packet.isShowErrorLog or false)

	bm.gameSettings.viewBobbing = worldCfg.viewBobbing or false
	bm.gameSettings.viewRotateBobbing = worldCfg.viewRotateBobbing or false
	bm.gameSettings.hurtCemaraEffect = worldCfg.hurtCemaraEffect or false
	bm.gameSettings.cameraPitchCompensate = World.cfg.cameraPitchCompensate or 30

    bm:setRakssid(packet.raknetID)
    Game.InitTeamsInfo(packet.teamsInfo)
    Game.InitPlayersInfo(packet.playersInfo, packet.gameState, packet.startTs)
    Lib.emitEvent(Event.UPDATE_UI_NAVIGATION_REGCALLBACK_ID, packet.navRegId)

	self:updatePropShow(true)
    PlayerControl.UpdatePersonView()
    AsyncProcess.GetUserDetail(Me.platformUserId, function (data)
        if not data then
            return
        end

        Me.userDetailData = data

        Lib.emitEvent(Event.LOAD_USER_DETAIL_FINISH, data)
    end)
	local headInfo = self:cfg().showHeadInfo
	if headInfo and next(headInfo) then
		Lib.emitEvent(Event.EVENT_SHOW_ENTITY_HEADINFO, { objID = self.objID, headInfo = headInfo })
	end
    bm:control().enable = false
    World.Timer(20, function()
        self:sendPacket({ pid = "ClientReady" })
		bm:control().enable = true
        return false
    end)
    UI:setCheckPause(true)
    self:initRecharge()
    self:onCreate()
    --执行用户自定义脚本
	ExecUserScript.chunk(Entity.GetCfg(packet.cfgName), self, "_clientScript")
	Me.isEditorServerEnvironment = packet.isEditorServerEnvironment
	if CGame.instance:getIsMobileEditor() then
		local eventTrackingMgr = require "editor.edit_record.manager"
		eventTrackingMgr:initOnlineEventTracking()
	end
	CGame.instance:loadMapComplete()
    self:setInstanceID(packet.instanceId)
    T(Lib, "LuaCinemachine"):_loadFromJsonConfig(worldCfg.cinemachine)

	Trigger.CheckTriggers(nil, "Client_Init_Finished")--触发客户端初始化完成Trigger
end

function handles:ChangeMap(packet)
	local oldMap = World.CurMap
    if oldMap and oldMap.id ~= packet.id then
        --先清徐一次静态数据，否则太占内存了
        oldMap:resetStaticSceneBatch()
    end
	local world = World.CurWorld
	world:loadCurMap(packet, packet.pos)
    local map = World.CurMap
	if map==oldMap then
		return
	end
	for _, obj in ipairs(world:getAllObject()) do
		if obj.waitMapId==map.id then
			obj:setMap(map)
			obj.waitMapId = nil
		end
	end
	if oldMap then
		oldMap:leaveAllEntity()
		oldMap:close()

        local manager = World.CurWorld:getSceneManager()
        local scene = manager:getOrCreateScene(World.CurWorld.CurMap.obj)
        manager:setCurScene(scene)
	end
end

function handles:OnPlayerLogin(packet)
    Game.OnPlayerLogin(packet.playerInfo)
end

function handles:OnPlayerLogout(packet)
    Game.OnPlayerLogout(packet.objID)
end

function handles:OnPlayerReconnect(packet)
    Game.OnPlayerReconnect(packet.objID)
end

function handles:SetGameState(packet)
    Game.SetState(packet.state, packet.startTs)
end

function handles:UpdateTeamInfo(packet)
    Game.UpdateTeamInfo(packet.teamID, packet.info or {})
end

function handles:SetPlayerTeam(packet)
    Game.SetPlayerTeam(packet.objId, packet.teamId, packet.leaderId, packet.joinTeamTime, packet.oldTeamLeaderId)
end

function handles:CreateTeam(packet)
    Game.CreateTeam(packet.id, packet.state, packet.createTime, packet.additionalInfo)
    -- print(" packet.id ", packet.id)
    Lib.emitEvent(Event.TEAM_UPDATE, {teamID = packet.id, isCreate = true})
end

function handles:UpdateTeamAdditionalInfo(packet)
    Game.UpdateTeamAdditionalInfo(packet.id, packet.createTime, packet.additionalInfo)
end

function handles:DismissTeam(packet)
    Game.DismissTeam(packet.id)
end

function handles:SkillMap(packet)
	self:updateSkillList(packet.map)
end

function handles:StudySkillMap(packet)
	self:updateStudySkillList(packet.map)
end

function handles:BuffMap(packet) 
	self:updateBuffList(packet.map)
end

function handles:PetList(packet)
	self:setData("pet", packet.list)
end

function handles:syncTreasurebox(packet)
	self:setData("treasurebox", packet.list)
end

function handles:SendBuyShopResult(packet)
    Shop:responseBuyResult(packet.itemIndex, packet.limit, packet.msg, packet.forceUpdate, packet.succeed)
end

function handles:ShowRestartBox(packet)
    Lib.emitEvent(Event.EVENT_GAME_SHOW_RESTART_BOX, packet)
end

function handles:SendBuyCommodityResult(packet)
    Lib.emitEvent(Event.EVENT_SEND_BUY_COMMODITY_RESULT, packet.msg)
end
local function recoverBigIntegeer(packet)
    for index, currency in pairs(packet.wallet) do
        if type(currency.count) == "table" then
            currency.count = BigInteger.Recover(currency.count)
        end
	end
end
function handles:SyncWallet(packet)
    recoverBigIntegeer(packet)
    self:setData("wallet", packet.wallet)
    Lib.emitEvent(Event.EVENT_CHANGE_CURRENCY)
end

function handles:SynCurrencySingle(packet)
    local updateInfo = packet.updateInfo
    local currency = self:getCurrency(updateInfo.name, true)
    if type(updateInfo.currency.count) == "table" then
        updateInfo.currency.count = BigInteger.Recover(updateInfo.currency.count)
    end
    local countDif = updateInfo.currency.count - currency.count
    currency.count = updateInfo.currency.count

    Lib.emitEvent(Event.EVENT_CHANGE_CURRENCY, {countDif = countDif, reason = updateInfo.reason})

    --飘字 差�
    if countDif > 0 then
        Lib.emitEvent(Event.EVENT_CLIENT_SHOW_FLYTEXT, {name = updateInfo.name, countDif = countDif})
    end
end

function handles:AddBuff(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if not entity then
        return
    end
    local from = World.CurWorld:getEntity(packet.fromID)
    entity:addClientBuff(packet.name, packet.id, packet.time, from)
end

function handles:RemoveBuff(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if not entity then
        return
    end
    local buff = entity:data("buff")[packet.id]
    if not buff then return end
	entity:removeClientBuff(buff)
end

function handles:ChangeBuffTime(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    local buff = entity:data("buff")[packet.id]
	entity:changeClientBuffTime(buff, packet.time)
end

--local function set_hand_item(entity, itemData)
--    if itemData then
--        local item = Item.DeseriItem(itemData)
--        if item then
--            entity:saveHandItem(item)
--        end
--    end
--end

function handles:EntitySpawn(packet)
	--packet.name packet.cfgName packet.cfgID packet.objID packet.pos packet.rotationYaw
	--packet.rotationPitch packet.rotationRoll packet.uid packet.movingStyle packet.curHp packet.curVp
	--packet.skin packet.handItem 15packet.rideOnId packet.rideOnIdx packet.headText packet.values packet.buffList
	--packet.actorName packet.isPlayer packet.entityToBlock packet.passengers packet.entityUI packet.targetId
	--packet.mode packet.flyMode
    local entity = Game.EntitySpawn(self, packet)
    self:onCreate()
	--执行用户自定义脚本 npc的客户端脚本不执行Game.EntitySpawn(self, packet,) callback(entity)
    --ExecUserScript.chunk(self.GetCfg(packet.cfgName), entity, "_clientScript")

    if packet.isDead or tonumber(packet.curHp) <= 0 then
        entity:timer(1, entity.onDead, entity)
    end

    if (packet.instanceId or 0) > 0 and entity:isValid() then
        entity:setInstanceID(packet.instanceId)
    end
end

function handles:AddEntitySceneUI(packet)
    local entity = World.CurWorld:getObject(packet.objID)
    if not entity then
        return
    end
    SceneUIManager.AddEntitySceneUI(packet.objID, packet.key, packet.uiData)
end

function handles:RemoveEntitySceneUI(packet)
    SceneUIManager.RemoveEntitySceneUI(packet.key)
end

function handles:RefreshEntitySceneUI(packet)
    SceneUIManager.RefreshEntitySceneUI(packet.key, packet.openParams)
end

function handles:AddEntityHeadUI(packet)
    local entity = World.CurWorld:getObject(packet.objID)
    if not entity then
        return
    end
    SceneUIManager.AddEntityHeadUI(packet.objID, packet.uiData)
end

function handles:RemoveEntityHeadUI(packet)
    SceneUIManager.RemoveEntityHeadUI(packet.objID)
end

function handles:RefreshEntityHeadUI(packet)
    SceneUIManager.RefreshEntityHeadUI(packet.objID, packet.openParams)
end

function handles:AddSceneUI(packet)
    SceneUIManager.AddSceneUI(packet.key, packet.uiData)
end

function handles:RemoveSceneUI(packet)
    SceneUIManager.RemoveSceneUI(packet.key)
end

--==================================================================

function handles:RefreshSceneUI(packet)
    SceneUIManager.RefreshSceneUI(packet.key, packet.openParams)
end

function handles:ShowAllSceneUI(packet)
    SceneUIManager.ShowAllSceneUI(packet.curMapUI)
end

function handles:CloseAllSceneUI(packet)
    SceneUIManager.CloseAllSceneUI(packet.curMapUI)
end

function handles:DropItemSpawn(packet)
    local instanceId = packet.instanceId
    local item = Item.DeseriItem(packet.item)
    local dropitem = DropItemClient.Create(packet.objID, packet.pos, assert(item),packet.moveSpeed,packet.moveTime, packet.guardTime)
    local pitch = tonumber(packet.pitch)
    local yaw = tonumber(packet.yaw)
    if pitch or yaw then
        dropitem:setRotation(yaw or 0, pitch or 0)
    end
    local shake = tonumber(packet.shake)
    if shake and shake ~= 0 then
        dropitem.shake = shake
    end
    dropitem:updateARGBStrength()
    local cfg = item:is_block() and item:block_cfg() or item:cfg()
    local forceAutoRotate = cfg and cfg.forceAutoRotate
    if forceAutoRotate ~= nil then
        dropitem:setFixRotation(not forceAutoRotate)
    end
    if packet.fixRotation ~= nil then
        dropitem:setFixRotation(packet.fixRotation)
    end
    dropitem:setProperty("id", tostring(instanceId))
end

local function removeObject(id, ui, reason)
    local world = World.CurWorld
    local obj = world:getObject(id)
	if obj then
        if obj.isEntity then
            if ui and next(ui) then
                SceneUIManager.RemoveEntityUI(id, ui)
            end
            obj:removeInteractionSphere()
        end

        local curViewEntity = Blockman.instance:viewEntity()
        if curViewEntity and curViewEntity.objID == id then
            Blockman.instance:setViewEntity(Player.CurPlayer)
        end

        obj:destroy(reason)
	end
end

function handles:ObjectRemoved(packet)
	removeObject(packet.objID, packet.entityUI, packet.reason)
end

function handles:ObjectListRemoved(packet)
	for id, ui in pairs(packet.list) do
		removeObject(id, ui, packet.reason)
	end
end

function handles:EntityDeadAction(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    local actionCfgName = packet.actionCfgName
    local deadActions = entity:cfg().deadActions
    if not deadActions then
        return
    end
    local actionCfg = deadActions[actionCfgName]
    if not actionCfg then
        return
    end
    if actionCfgName == "squashed" then
        entity:updateUpperAction("freeze", 1000)
        entity:entityActorSquashed(actionCfg.scaleY or 0.1)
    else
        if actionCfg.changeActor then
            entity:changeActor(actionCfg.changeActor)
        end
        entity:updateUpperAction(actionCfg.name, actionCfg.time)
    end
end

function handles:EntityDead(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if not entity or not entity:isValid() then
        return
    end
    entity:onDead()
    local owner
    if packet.ownerID then
        owner = World.CurWorld:getEntity(packet.ownerID)
        if owner and owner.isMainPlayer then
            owner:EmitEvent("OnKillEntity", entity)
        end
    end
    if not entity.isMainPlayer then
        return
    end
    entity:EmitEvent("OnEntityDie", owner)
    local reviveTime = entity:cfg().reviveTime
    if not reviveTime then
        return
    end
    Lib.emitEvent(Event.EVENT_PLAYER_DEATH, reviveTime, entity.sendPacket, entity, {pid = "Rebirth"})
end

function handles:EntityRebirth(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if not entity or not entity:isValid() then
        return
    end
	local oldPos = entity:getPosition()
    local cfg = entity:cfg()
    if entity.isPlayer and cfg.deathEffect then
        local effectPathName = ResLoader:filePathJoint(cfg, cfg.deathEffect.effect)
        Blockman.instance:delEffect(effectPathName, oldPos)
    end
	entity:resetData()

    for _, buff in pairs(entity:data("buff")) do
        if buff.cfg then
            if buff.cfg.removeOnDie then
                entity:removeClientBuff(buff)
            end
        end
    end
    PlayerControl.OnRebirth()
    local revive = cfg.revive
    if revive then
		if revive.changeActor then
			entity:changeActor(revive.changeActor)
		end
        entity:updateUpperAction(revive.action, revive.actionTime)
		entity:data("main").brithActionTimer = entity:timer(revive.actionTime, function()
			entity:changeActor(cfg.actorName)
		end)
		local rebirthEffect = revive.effect
		if rebirthEffect and rebirthEffect.name then
			local effectPathName = ResLoader:filePathJoint(cfg, rebirthEffect.name)
			Blockman.instance:playEffectByPos(effectPathName, Lib.v3add(oldPos, rebirthEffect.pos or {x = 0, y = 0, z = 0}), 0, rebirthEffect.time)
		end
    end
    if cfg.rebirthSound then
        local time = math.min(cfg.rebirthSound.delayTime or 1, 100)
        entity:timer(time, function()
            entity:playSound(cfg.rebirthSound)
			cfg.rebirthSound.path = ResLoader:filePathJoint(cfg, cfg.rebirthSound.sound)
            Player.CurPlayer:playSound(cfg.rebirthSound)
            return false
        end)
    end

    local playDeadInfo = self:data("main").playDeadInfo
    if playDeadInfo then
        self:data("main").playDeadInfo = nil
        -- self:setBaseAction("idle")
        self:refreshUpperAction()
        self:refreshBaseAction()
        
		if self.isMainPlayer then
		    local bm = Blockman.instance
            bm.gameSettings:setLockBodyRotation(playDeadInfo.oldIsLockBodyRotation)
            -- bm.gameSettings:setLockSlideScreen(playDeadInfo.oldIsLockSlideScreen)
            bm:setPersonView(playDeadInfo.oldView)
        end
		self:doSetProp("canTurnHeadProp", self:prop().canTurnHeadProp + playDeadInfo.oldCanTurnHeadProp)
    end

	Lib.emitEvent(Event.EVENT_PLAYER_REBIRTH, packet.objID)
end

local function resetEntityStatus(entity)
    if entity then
        entity.isMoving = false
		entity:resetHitchingInfo()
    end
end

function handles:EntityMove(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if not entity then
        return
    end
    resetEntityStatus(entity)
	local map = World.mapList[packet.map]
	if map then
		entity:setMap(map)
		entity.waitMapId = nil
	else
		entity:setMap(nil)
		entity.waitMapId = packet.map
	end

    if packet.cameraParam and entity.objID == Me.objID then
        local yaw = packet.cameraParam.yaw or 0
        local pitch = packet.cameraParam.pitch or 0
        local distance = packet.cameraParam.distance
        entity:changeCameraView(nil, yaw, pitch, distance)
    end

    local yaw = packet.yaw or entity:getRotationYaw()
    entity:setMove(0, packet.pos, yaw, packet.pitch or entity:getRotationPitch(), 0, 0)

    -- 延迟修正yaw
    World.Timer(3, function()
        if entity and entity:isValid() then
            entity:setBodyYaw(yaw)
        end
        return false
    end)
end

function handles:EntityRideOff(packet)
    local world = self.world
    local entity = world:getEntity(packet.objID)
    if not entity then
        return
    end
    if not packet.rideOffId then
        return
    end
    entity:rideOff(packet.rideOffId)
end

function handles:EntityRideOn(packet)
    local world = self.world
    local entity = world:getEntity(packet.objID)
    if not entity then
        return
    end
    if packet.rideOnId == 0 then
        entity:rideOn(nil, 0)
        return
    end
    local target = world:getEntity(packet.rideOnId)
    if target then
        entity:rideOn(target, packet.rideOnIdx)
    end
end

function handles:EntityValue(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if entity and entity:isValid() then
        if packet.isBigInteger then
            packet.value = BigInteger.Recover(packet.value)
        end
        entity:doSetValue(packet.key, packet.value)
    end
end

function handles:ChangeActor(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if entity and entity:isValid() then
        entity:data("main").actorName = packet.name
        print(" packet.name, packet.clearSkin ", packet.name, packet.clearSkin)
        entity:changeActor(packet.name, packet.clearSkin)
    else
        Lib.logWarning("ChangeActor cant find entity,objid=",packet.objID)
    end

end

function handles:PlayerScoreShow(packet)
    local tipName = { "SCORE",  packet.score }
    Lib.emitEvent(Event.EVENT_CENTER_TIPS, 40, nil, nil, tipName)
end

function handles:ShowTip(packet)
	Client.ShowTip(packet.tipType, packet.textKey, packet.keepTime, packet.vars, packet.regId, packet.textArgs)
end

function handles:ChatMessage(packet)
    Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, packet.msg, packet.fromname, packet.type)
    local entity = World.CurWorld:getEntity(packet.args[1])
    if entity ~= nil then
        entity:showHeadMessage(packet.msg);
    end
end

function handles:SystemChat(packet)
	local msg = Lang:formatMessage(packet.key, packet.args)
    if packet.args.isOpenChatWnd then
        local toolbar = UI:getWnd("toolbar", true)
        if GUIManager:Instance():isEnabled() then
            toolbar.chatWnd:setVisible(true)
        end
    end
    Lib.emitEvent(Event.EVENT_CHAT_MESSAGE, msg)
end

function handles:UpdateCountDownTip(packet)
    local msg = Lang:toText({packet.textKey, packet.textP1})
    Lib.emitEvent(Event.EVENT_UPDATE_COUNT_DOWN_TIP, msg, packet.textIcon)
end

function handles:RankData(packet)
	Rank.ReceiveRankData(packet)
end

function handles:RankDataDirty(packet)
    Rank.RankDataDirty(packet.rankType)
end

function handles:ShowRank(packet)
    --print("client received ShowRank", Lib.v2s(packet))
	local rankType = packet.rankType
	Lib.emitEvent(Event.EVENT_SHOW_RANK, rankType, packet.uiName)
	Rank.RequestRankData(rankType)
end

function handles:ShowRoutine(packet)
    Lib.emitEvent(Event.EVENT_SHOW_ROUTINE, packet.open, packet.content, packet.data)
end

function handles:SyncShop(packet)
    Shop:updateGoodsData(packet)
end

function handles:ShowNotice(packet)
    Lib.emitEvent(Event.EVENT_SHOW_NOTICE, packet)
end

function handles:AddWaitDealUI(packet)
    Lib.emitEvent(Event.EVENT_ADD_WAIT_DEAL_UI, packet)
end

function handles:ShowSelect(packet)
    Lib.emitEvent(Event.EVENT_SHOW_SELECT, packet)
end

function handles:ShowSettlement(packet)
    Lib.emitEvent(Event.EVENT_SEND_SETTLEMENT, packet.result, packet.isNextServer)
end

function handles:ShowGameQuality(packet)
    Lib.emitEvent(Event.EVENT_SHOW_GAMEQUALITY, packet.show)
end

function handles:ShowStageSettlement(packet)
    Stage.ShowStageSettlement(packet)
end

function handles:SyncStageScore(packet)
    Lib.emitEvent(Event.EVENT_UPDATE_STAGE_SCORE, packet.score, packet.pyramid, packet.oldScore)
end

function handles:SyncStageStars(packet)
    Lib.emitEvent(Event.EVENT_UPDATE_STAGE_STAR, packet.stars)
end

function handles:StageEndTime(packet)
    Lib.emitEvent(Event.EVENT_STAGE_TIME_END, packet.regId)
end

function handles:SetStageTopInfo(packet)
    Lib.emitEvent(Event.EVENT_UPDATE_STAGE_TOP_INFO, packet.key, packet.value, packet.textKey)
end

function handles:RequestStartStageResult(packet)
    Stage.RequestStartStageResult(packet)
end

function handles:SendEnableChapters(packet)
    local winName = packet.winName
    if winName == "win_stage" then
        Lib.emitEvent(Event.EVENT_SHOW_CHAPTERS, {show = true, fullName = packet.fullName, enableChapters = packet.enableChapters, cfg = Stage.GetStageCfg(packet.fullName)})
    end
end

function handles:SendChapterInfo(packet)
    Stage.ShowChapterInfo(self, packet)
end

function handles:StageExited(packet)
    Stage.StageExited(self, packet.fullName, packet.chapterId, packet.stage, packet.finish)
end

function handles:ShowDeadSummary(packet)
    Lib.emitEvent(Event.EVENT_SEND_DEADSUMMARY, packet.result, packet.isNextServer, packet.isWatcher, packet.title)
end

function handles:SendGameEnd(packet)
    Lib.emitEvent(Event.EVENT_SEND_GAMEEND, packet.result, packet.title)
end

function handles:ShowInfoPanel(packet)
	CGame.instance:reportGameOver(packet.tipID)
    if not packet.isKick then
        ---正常游戏结束
        Lib.emitEvent(Event.EVENT_SEND_GAMEOVER, Lang:toText(packet.tipID))
        return
    end
    if Game.IsGameParty() then
        ---私人派对直接退出游戏，不尝试进入其他服务器
        Lib.emitEvent(Event.EVENT_KICKED_BY_SERVER, Lang:toText(packet.tipID))
        return
    end
    if CGame.instance:getEnterGameWithTeam() then
        ---组队进入游戏的，直接退出游戏，不尝试进入其他服务器
        Lib.emitEvent(Event.EVENT_KICKED_BY_SERVER, Lang:toText(packet.tipID))
        return
    end
    if packet.tipID == "game.startAlready" or packet.tipID == "game.full" then
        ---进入异常被踢出游戏（游戏已开始、满人了）
        Lib.logInfo("game full or game start, reset game ...", packet.tipID)
        CGame.instance:resetGameAddr(Me.platformUserId, World.GameName, "", "", "")
        return
    end
    Lib.emitEvent(Event.EVENT_KICKED_BY_SERVER, Lang:toText(packet.tipID))
end

function handles:ShowPersonalInformations(packet)
    Lib.emitEvent(Event.EVENT_SHOW_PERSONALINFORMATIONS, packet.objID)
end

function handles:ShowRewardRollTip(packet)
    Lib.emitEvent(Event.EVENT_SHOW_REWARD_ROLL_TIP, packet)
end

function handles:ShowRewardNotice(packet)
    Lib.emitEvent(Event.EVENT_SHOW_REWARD_NOTICE, packet)
end

function handles:EntityPlayAction(packet)
	local entity = World.CurWorld:getEntity(packet.objID)
	if entity then
		entity:updateUpperAction(packet.action, packet.time, packet.refreshBaseAction or false)
	end
end

function handles:CastSkillSimulation(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if entity then
        Skill.Cast(packet.name, packet, entity)
    end
end

function handles:CastSkill(packet)
    Skill.CastByServer(packet)
end

function handles:StartSkill(packet)
	Skill.StartByServer(packet)
end

function handles:SustainSkill(packet)
	Skill.SustainByServer(packet)
end

function handles:StopSkill(packet)
    Skill.StopByServer(packet)
end

function handles:StartPreSwing(packet)
   --TODO
   Skill.StartPreSwingByServer(packet)
end

function handles:StopPreSwing(packet)
   --TODO
   Skill.StopPreSwingByServer(packet)
end

function handles:StartBackSwing(packet)
   --TODO
   Skill.StartBackSwingByServer(packet)
end

function handles:StopBackSwing(packet)
   --TODO
   Skill.StopBackSwingByServer(packet)
end

function handles:HandItem(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if not entity or not entity:isValid() then
        return
    end
	local item
	if packet.itemData then
		item = Item.DeseriItem(packet.itemData)
	end
	entity:saveHandItem(item)
end

function handles:ShowMerchantShop(packet)
    Lib.emitEvent(Event.EVENT_OPEN_MERCHANT, true, packet.showType, packet.showTitle)
end

function handles:ShowShop(packet)
    UI:openShopInstance(packet.showType, packet.showGroup)
end

function handles:ShowUpgradeShop(packet)
	Lib.emitEvent(Event.EVENT_OPEN_UPGRADE_SHOP, true)
end

function handles:HeadText(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if not entity then
        return
    end
    local ary = packet.ary
    
    local function aryTranslate(ary)
        if ary and type(ary) == "table" then
            for _,t in pairs(ary) do
                if type(t) == "table" then
                    for k,str in pairs(t) do
                        if type(str) == "string" then
                            ary[_][k] = Lang:formatText(ary[_][k])
                        end
                    end
                end
            end
        end
        return ary
    end

    entity:data("headText").svrAry = packet.isNeedTranslate and aryTranslate(ary) or ary
    entity:updateShowName()
end

function handles:DamageText(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if not entity then
        return
    end
    local textArrSize = World.cfg.damageTextArrSize or 2
    textArrSize = math.max( 1,textArrSize )

    entity.textArr = entity.textArr or {}
    local textArr = entity.textArr

    for i = 1, textArrSize - 1 do
        local temp = textArr[i + 1] or ""
        textArr[i] = temp
    end
    textArr[textArrSize] = packet.text

    for i = 1, textArrSize do
        entity:setHeadText(-1, -i, textArr[i])
    end

    local damageTextTimer = World.cfg.damageTextTimer or 20
    local timerArr = entity.timerArr or {}
    for i,timer in ipairs(timerArr) do
        if timer and type(timer) == "function" then
            timer()
        end
        timerArr[i] = nil
    end

    local function timer(i)
        if i then
            textArr[i] = ""
            timerArr[i] = nil
            entity:setHeadText(-1, -i, "")
            entity:data("headText").svrAry = entity:data("headText").ary
            entity:updateShowName()
        end
        return false
    end
    for i = 1, textArrSize do
        timerArr[i] = World.Timer(damageTextTimer * i, timer, i)
    end
    entity:data("headText").svrAry = entity:data("headText").ary
	entity:updateShowName()
end

function handles:SkinPartChange(packet)
	local entity = World.CurWorld:getEntity(packet.objID)
	if not entity then
		return
	end

	entity:applySkinPart(packet.skinPartData)
end

function handles:SkinChange(packet)
	local entity = World.CurWorld:getEntity(packet.objID)
	if not entity then
		return
	end

	entity:applySkin(packet.skinData)
end

function handles:PlayHeartbeat(packet)
    local soundInfo = self:data("soundInfo")
    if packet.path then
        soundInfo.path = packet.path
        if soundInfo.func then
            soundInfo.func()
            soundInfo.func = nil
        end
        local function tick()
            TdAudioEngine.Instance():play2dSound(packet.path, false)
            return true
        end
        soundInfo.func= World.Timer(packet.interval or 20, tick)
    end
end

function handles:StopHeartbeat(packet)
    local soundInfo = self:data("soundInfo")
    if soundInfo.func then
        soundInfo.func()
        soundInfo.func = nil
    end
end

function handles:SetHeartbeatSpeed(packet)
    local soundInfo = self:data("soundInfo")
    if packet.interval then
        if soundInfo.path then
            if soundInfo.func then
                soundInfo.func()
                soundInfo.func = nil
            end
            local function tick()
                TdAudioEngine.Instance():play2dSound(soundInfo.path, false)
                return true
            end
            soundInfo.func= World.Timer(packet.interval, tick)
        end
    end
end

function handles:ShowPlaySoundProgressBar(packet)
    Lib.emitEvent(Event.EVENT_PLAY_SOUND_PROGRESSBAR, packet.time)
end

function handles:SetCameraYaw(packet)
    local target = World.CurWorld:getEntity(packet.objID)
    local pos = self:getPosition()
    if target == nil then
        return
    end
    local t_pos = target:getPosition()
    local x = t_pos.x - pos.x
    local z = t_pos.z - pos.z
    local tan = math.atan(z, x) -- based on a 0-degree angle
    local yaw = math.deg(tan)  -- [-180, 180]  the reverse is consistent with the coordinates in game
    self:setRotationYaw(yaw - 90)
end

function handles:EspeciallyShop_update(packet)
	local id = packet["id"]
    local menu=packet["menu"]
    local data=packet["data"]

	local menu_=self:data(menu)
	local id_=self:data(id)

	local menu_index= upgrade_shop[menu]
	if not menu_index then upgrade_shop[menu]=menu_	end

	if data ~=nil then
		local id_index= upgrade_shop[menu][id]
		upgrade_shop[menu][id]=id_
		upgrade_shop[menu][id].data=data
	else
		upgrade_shop[menu][id]=nil
    end
    if World.cfg.autoClearUpgradeShop then
        self.espcially_shop_data[menu][id] = upgrade_shop[menu][id]
    end

	Lib.emitEvent(Event.EVENT_SEND_ESPECIALLY_SHOP_UPDATE, packet.close, menu)
end

function handles:SetMapPlayerIcon(packet)
    if not World.CurMap then
        return
    end
    -- 没有小地图，没必要开启minimap,miniMap 有帧方法
    local config = World.CurMap.cfg.miniMap
    if not config then
        return
    end

    local icon=nil;
    if UI:isOpen("minimap") == false then
        UI:getWnd("minimap")
    end
    for _, objID in ipairs(packet.list) do
        icon = objID == Me.objID and "me.png" or "else.png"
		Lib.emitEvent(Event.EVENT_MAP_SETICON, objID, icon, nil, {x=0,y=0,z=0}, nil, objID, true)
	end
end

function handles:ShowNoviceGuide(packet)
	Lib.emitEvent(Event.EVENT_PLAYER_SHOWNOVICEGUIDE, packet.fullName, packet.close)
end

function handles:SetNoviceGuide(packet)
    Lib.emitEvent(Event.EVENT_PLAYER_SETNOVICEGUIDE, packet.fullName, packet.image)
end

function handles:RemoveMapIcon(packet)
    Lib.emitEvent(Event.EVENT_MAP_REMOVEICON,packet.key)
end

function handles:SetEntityYaw(packet)
    local obj = World.CurWorld:getObject(packet.objID)
    if obj then
        obj:setRotationYaw(packet.rotationYaw or obj:getRotationYaw())
    end
end

function handles:SetTextFlash(packet)
    local key = packet.pos.x .. "_" .. packet.pos.y .. "_" .. packet.pos.z
    local temp = nil
    if NpcPos[key] ~= nil then
        NpcPos[key].timer()
        temp = NpcPos[key].entity
    else
        temp = EntityClient.CreateClientEntity({cfgName="myplugin/door_entity",pos=packet.pos})
    end
    temp:setHeadText(0, 0, packet.headText)
	temp:data("headText").svrAry = temp:data("headText").ary
	temp:updateShowName()
    local function tick()
        NpcPos[key] = nil
        temp:destroy()
        return false
    end
    if packet.time ~= -1 then
        NpcPos[key] = {entity=temp,timer=temp:timer(packet.time, tick)}
    end
end

function handles:ShowDeadCountDown(packet)
    if packet.notHideMain then
        Lib.emitEvent(Event.EVENT_COUNT_DOWN, packet.time)
    else
        Lib.emitEvent(Event.EVENT_PLAYER_DEATH, packet.time)
    end
end

function handles:StopDeadCountDown()
    Lib.emitEvent(Event.EVENT_STOP_DEAD_COUNTDOWN)
end

function handles:ShopGoodIsLimit(packet)
    SingleShop:setLimit(packet.shopType, packet.shopGroup, packet.index)
end

function handles:ShowBuyRevive(packet)
    Lib.emitEvent(Event.EVENT_SHOW_REVIVE, packet.regId, packet.coin, packet.cost, packet.time, packet.title,
                    packet.sure, packet.cancel, packet.msg, packet.newReviveUI)
end

function handles:ShowDialogTip(packet)
    local args = packet.args
    Lib.emitEvent(Event.EVENT_SHOW_DIALOG_TIP, packet.tipType, packet.regId, table.unpack(args))
end

function handles:ShowRecharge(packet)
    Interface.onRecharge(1)
end

function handles:ShowContentsList(packet)
    Lib.emitEvent(Event.EVENT_SHOW_CONTENTS_LIST, packet)
end

function handles:FriendOperation(packet)
	Lib.emitEvent(Event.EVENT_FRIEND_OPERATION_FOR_SERVER, packet.operationType, packet.userId)
end

function handles:FriendOperationNotice(packet)
    Lib.emitEvent(Event.EVENT_FRIEND_OPERATION_NOTICE, packet.operationType, packet.userId)
end

function handles:setEntityView(packet)
    Blockman.instance:setPersonView(packet.view)
end

function handles:setGuidePosition(packet)
    self:setGuidePosition(packet.pos)
end

function handles:setGuideTarget(packet)
    self:setGuideTarget(packet.pos, packet.guideTexture or "guide_arrow.png", packet.guideSpeed or 1)
end

function handles:DelGuideTarget(packet)
    self:delGuideTarget()
    Lib.emitEvent(Event.EVENT_GUIDE_POSITION_CHANGE)
end

function handles:SyncTask(packet)
    local taskData = self:data("task")
    local name = packet.name
    local hint = false
    if not taskData[name] then
        self:addTraceTask(name)
    end
    if name then
        self:checkTaskFinish(name, packet.targets)
        hint = taskData[name] == nil or packet.targets and Player.CheckTaskHint(name, packet.targets)
        taskData[name] = taskData[name] or {}
        local data = taskData[name]
        data.targets = packet.targets
        data.hint = hint
        data.status = packet.status
    end
    self:updateClientTask(packet)
    if packet.status == 0 then
        taskData[name] = nil
    end
end

function handles:AttachDebugPort(packet)
    debugport.Attach(packet.sessionId)
end

function handles:DetachDebugPort(packet)
    debugport.Detach(packet.sessionId)
end

function handles:DoCmd(packet)
    local message, isREPLMode, isMultilineStatement = debugport.DoCmd(packet.sessionId, packet.cmd)
    local data = {
        pid = "DoCmdRet",
        serialNum = packet.serialNum,
		sessionId = packet.sessionId,
		message = message,
		isREPLMode = isREPLMode,
		isMultilineStatement = isMultilineStatement,
	}
	self:sendPacket(data)
end

function handles:ShowComposition(packet)
    Lib.emitEvent(Event.SHOW_COMPOSITION, packet.class, packet.show)
end

function handles:SendCompoundResult(packet)
    Lib.emitEvent(Event.SHOW_COMPOUND_RESULT, packet.result)
end

function handles:SubmitRecipe(packet)
    Lib.emitEvent(Event.SHOW_SUBMIT_RECIPE, packet.class, packet.recipeName, packet.info, packet.title, packet.button)
end

function handles:ShowHome(packet)
    Lib.emitEvent(Event.EVENT_SHOW_HOME, packet.show, packet.params)
end

function handles:ShowUINavigation(packet)
    if packet.delay then
        World.Timer(packet.delay, function()
            Lib.emitEvent(Event.EVENT_SHOW_NAV, packet.name, packet.show)
        end)
    else
        Lib.emitEvent(Event.EVENT_SHOW_NAV, packet.name, packet.show)
    end
end

function handles:ShowNavigation(packet)
    Lib.emitEvent(Event.UPDATE_UI_NAVIGATION_REGCALLBACK_ID, packet.navRegId)
end

function handles:NavCollapsible(packet)
    Lib.emitEvent(Event.NAV_COLLAPSIBLE_CHANGE, packet.type or "top", packet.colBool)
end

function handles:OpenConversation(packet)
    Lib.emitEvent(Event.EVENT_OPEN_CONVERSATION, true, packet)
end

function handles:OnWatchAd(packet)
    if CGame.instance:getPlatformId() == 1 then
        local packet = {
            pid = "OnWatchAdResult",
            type = 1,
            code = 1
        }
        self:sendPacket(packet)
        return
    end
    CGame.instance:getShellInterface():onWatchAd(packet.type, packet.param, packet.adsId)
end

function handles:ShowKillerInfo(packet)
	Lib.emitEvent(Event.EVENT_SHOW_KILLERINFO, packet)
end

function handles:HideKillerInfo(packet)
	Lib.emitEvent(Event.EVENT_SHOW_KILLERINFO, nil)
end

function handles:ShowTask(packet)
    Lib.emitEvent(Event.EVENT_SHOW_TASK, packet.show , packet.type, packet.name, packet.msg)
end

function handles:ChangeCameraView(packet)
	self:changeCameraView(packet.pos, packet.yaw, packet.pitch, packet.distance, packet.smooth * 5)
end

function handles:ChangeCameraCfg(packet)
	local config = packet.config
	if not config then
		return
	end
	local bm = Blockman.instance
	local modifyViewIndex = packet.viewIndex
	if not modifyViewIndex then
		modifyViewIndex = bm:getCurrPersonView()
	end
	bm:changeCameraCfg(config, modifyViewIndex)
end

function handles:CameraContorlSwitch(packet)
	Blockman.instance.gameSettings.cameraContorl = packet.switch;
end

function handles:FillBlockMask(packet)
	World.CurMap:fillBlockMask(packet.min, packet.max, packet.id);
end
-- item
-- item
do
    local item_manager = require "item.item_manager"

    function handles:tray_load(packet)
        -- load data
        do
            if not next(packet.data) then
                return
            end
            local entity = World.CurWorld:getEntity(packet.entity)
            assert(entity, packet.entity)
            local tray = entity:tray()
			for _, data in ipairs(packet.data) do
				local create_data = data.create_data
				local obj_tray = Tray:new_tray(create_data.type, create_data.capacity)
                if create_data.maxCapacity then
                    obj_tray:set_max_capacity(create_data.maxCapacity)
                end
				tray:add_tray(data.tid, obj_tray)

				obj_tray:deseri(data.tray_data)
				obj_tray:deseri_item(data.item_data)
			end
        end

		Lib.emitEvent(Event.EVENT_PLAYER_ITEM_LOADED)
    end

    function handles:tray_reload(packet)
        local data = packet.data
        local obj_tray = self:data("tray"):fetch_tray(packet.tid)
        assert(obj_tray)
        obj_tray:deseri(data.tray_data)
        obj_tray:deseri_item_with_clean(data.item_data)
    end

    function handles:tray_new(packet)
		local my_tray = self:data("tray")

		local data = packet.data
		local create_data = data.create_data
		local obj_tray = Tray:new_tray(create_data.type, create_data.capacity)
		my_tray:add_tray(packet.tid, obj_tray)

		obj_tray:deseri(data.tray_data)
		obj_tray:deseri_item(data.item_data)
    end

    function handles:tray_del(packet)
        local my_tray = self:data("tray")
        my_tray:del_tray(packet.tid)
    end

    function handles:tray_stat(packet)
        local my_tray = self:data("tray")
        local obj_tray = my_tray:fetch_tray(packet.tid)
        assert(obj_tray)
        obj_tray:deseri(packet.data)

        Lib.emitEvent(Event.EVENT_PLAYER_TRAY_STAT)
    end

    function handles:slot_stat(packet)
        local my_tray = self:data("tray")
        local obj_item = packet.data and item_manager:deseri_item(packet.data)
        my_tray:set_item(packet.tid, packet.slot, obj_item)
    end

    function handles:Play3dSound(packet)
        local entity = World.CurWorld:getEntity(packet.objID)
        assert(entity)
        entity:play3dSound(packet.filename)
    end

    function handles:Stop3dSound(packet)
        local entity = World.CurWorld:getEntity(packet.objID)
        assert(entity)
        entity:stop3dSound()
    end

    function handles:OpenChest(packet)
        Lib.emitEvent(Event.EVENT_OPEN_CHEST, true, packet.pos)
    end

    function handles:OpenNpcChest(packet)
        Lib.emitEvent(Event.EVENT_OPEN_NPC_CHEST, true, packet)
    end

    function handles:SetRegion(packet)
        local map = Me.map
        if not map or map.id ~= packet.mapId then
            return
        end
        local info = packet.regionInfo
        map:setRegion(info.id, info.min, info.max, false)
    end

    function handles:DelRegion(packet)
        local map = Me.map
        if not map or map.id ~= packet.mapId then
            return
        end
        local info = packet.regionInfo
        map:delRegion(info.id, false)
    end

    function handles:UpdateRegion(packet)
        local map = Me.map
        if not map or map.id ~= packet.mapId then
            return
        end
        local newInfos = packet.newRegionInfos
        for _, info in pairs(newInfos) do
            map:setRegion(info.id, info.min, info.max, false)
        end
        local delInfos = packet.delRegionInfos
        for _, info in pairs(delInfos) do
            map:delRegion(info.id, false)
        end
    end

	function handles:delMapEffect(packet)
        local map = Me.map
        if not map or not packet.mapID or map.id ~= packet.mapID then
            return
        end
        local effectIdNameMap = self:data("effectIdNameMap")
        for k, info in pairs(packet.packet or {}) do
            local id = info.id
            local effectName = info.effectName
            if not effectName then
                if not effectIdNameMap[id] then
                    return
                end
                effectName = effectIdNameMap[id]
            else
                effectIdNameMap[id] = effectName
            end
            Blockman.instance:delEffect(effectName, info.pos)
        end
	end

    function handles:playMapEffect(packet)
        local map = Me.map
        if not map or not packet.mapID or map.id ~= packet.mapID then
            return
        end
        local effectIdNameMap = self:data("effectIdNameMap")
        for k, info in pairs(packet.packet or {}) do
            local id = info.id
            local effectName = info.effectName
            if not effectName then
                if not effectIdNameMap[id] then
                    return
                end
                effectName = effectIdNameMap[id]
            else
                effectIdNameMap[id] = effectName
            end
			Blockman.instance:playEffectByPos(effectName, info.pos, 0, info.time)
        end
    end
end

function handles:PlayEffectByPos(packet)
    if not packet.pos or not packet.effectPath then
        return
    end
    Blockman.instance:playEffectByPos(packet.effectPath, packet.pos, 0, packet.times or -1)
end

function handles:ShowTargetInfo(packet)
    self:showTargetInfo(packet.targetInfo)
end

function handles:GMList(packet)
	GM.ServerList = packet.list
    GM.BTSGMList = packet.btsList
    Lib.emitEvent(Event.EVENT_SHOW_GM_LIST)
    local gmBaseUI = GUIManager:Instance():isEnabled() and UIMgr:getQueueWindow("actionControl") or UIMgr:getQueueWindow("main")
    -- local gmBaseUI = GUIManager:Instance():isEnabled() and UI:getWnd("actionControl") or UI:getWnd("main")
    if gmBaseUI then
        gmBaseUI:showGM(true)
    end

    Lib.emitEvent(Event.EVENT_SHOW_GM_BTN)
    ------新UI添加GM按钮
    local guiMgr = L("guiMgr", GUIManager:Instance())
    if guiMgr:isEnabled() then
        local WindowName = "GmDefaultWindow"
        local windowInstance = UI:openWindow(WindowName)
        if windowInstance then
            return
        end
        local defaultWnd = UI:createWindow(WindowName)
        defaultWnd:setArea2({0.5, 0}, {0, 0}, {0, 60}, {0, 30})
        local btn = UI:createButton("GMBtn")
        btn:setArea2({0, 0}, {0, 0}, {0, 60}, {0, 30})
        btn.onMouseClick = function()
            Lib.emitEvent(Event.EVENT_SHOW_GMBOARD)
        end
        btn:setText("GM")
        defaultWnd:addChild(btn)
        defaultWnd:setAlwaysOnTop(true)
        defaultWnd:setMousePassThroughEnabled(true)
        local root = guiMgr:getRootWindow()
        root:addChild(defaultWnd:getWindow())
    end
end

function handles:GMSubList(packet)
    Lib.emitEvent(Event.EVENT_SHOW_GM_PLUGIN, packet)
end

function handles:GMInputBox(packet)
    Lib.emitEvent(Event.EVENT_SHOW_GM_INPUTBOX, packet.pack)
end

function handles:ServerError(packet)
    local msg = "server error: " .. packet.errMsg
    perror(msg)
    GM:sendErrMsgToChatBar(msg)
end

function handles:Reload(packet)
    debugport.Reload(packet.hasChangeImage)
end

function handles:ShowCardOptionsView(packet)
    Lib.emitEvent(Event.EVENT_SHOW_CARDOPTIONS, packet)
end

function handles:ShowNewRanks(packet)
	Rank.RanksList[packet.rankName] = packet.ranks
	Rank.myRanks[packet.rankName] = packet.myrank
	Lib.emitEvent(Event.EVENT_SHOW_NEW_RANK, packet.rankName, packet.uiName)
end

function handles:UpdataRankData(packet)
	Rank.RanksList[packet.rankName] = packet.ranks
	Rank.newMyScores[packet.rankName] = packet.myrank
	Lib.emitEvent(Event.EVENT_UPDATA_NEW_RANK, packet.rankName)
end

function handles:SetEntityActorFlashEffect(packet)
    self:setEntityActorFlashEffect(packet.add)
end

function handles:SetEntityActorAlpha(packet)
	local entity = World.CurWorld:getEntity(packet.objID)
	if entity then
		entity:setAlpha(packet.alpha)
	end
end

function handles:SetBoundingBox(packet)
	local entity = World.CurWorld:getEntity(packet.objID)
	if entity then
		entity:setBoundingVolume(packet.boxTable)
	end
end

function handles:MarkEntity(packet)
    local target = World.CurWorld:getEntity(packet.objID)
	if not target then
		return
	end
	local ui = UILib.UIFromImage(packet.imagePath or "set:challenge_tower.json image:target_lock.png", packet.size)
	local timer, func = UILib.uiFollowObject(ui, packet.objID, {
		offset = {
			x = 0,
			y = 0,
			z = 0
		},
		rateTime = 1,
		autoScale = true,
		beginPos = UILib.Define.FOLLOW_OBJECT_MID,
		anchor = {
			x = 0.5,
			y = 0.5
		}
	})
    target.vars = target.vars or {}
    target.vars.markTimer = timer
    target.vars.markFunc = func
end

function handles:UnMarkEntity(packet)
    local target = World.CurWorld:getEntity(packet.objID)
	if not target then
		return
	end
    local vars = target.vars or {}
	local timer = target.vars.markTimer
    local func = target.vars.markFunc
    if timer then
        timer()
    end
    if func then
        func()
    end
end

function handles:OpenStore(packet)
    Lib.emitEvent(Event.EVENT_SHOW_STORE, packet.storeId, packet.itemIndex)
end

function handles:SyncStore(packet)
    Store:syncStore(packet.store or {})
end

function handles:SyncStoreItemInfo(packet)
    Store:changeStoreItemInfo(packet.storeId, packet.itemIndex, packet.status, packet.remainTime, packet.msg or "")
end

function handles:SetEntityActorScale(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if entity then
        entity:setActorScale(packet.scale)
    end
end

function handles:ShowNumberEffect(packet)
	local desktop = GUISystem.instance:GetRootWindow()
	local number = packet.number
	local pos = packet.pos
	local imgset = packet.imgset
	local imgfmt = packet.imgfmt
	local width = 20
	local hegiht = 30
	local win = UILib.makeNumbersGrid("showNumberUi", number, imgset or "number_mla", imgfmt)
	local result = Blockman.instance:getScreenPos(pos)
	local len = string.len(tostring(number))
	win:SetArea({result.x, 0}, {result.y, 0}, {0, width * len}, {0, hegiht})
	desktop:AddChildWindow(win)
	local targetY = win:GetYPosition()[1] - (packet.distance or 0.1)
	Lib.uiTween(win, {
		Y = {targetY, 0},
		Alpha = 1.0
	}, 20, function()
		desktop:RemoveChildWindow1(win)
	end)
end

function handles:ShowTextUIOnEntity(packet)
	local FollowObjID = packet.FollowObjID
    if not FollowObjID then
        return
    end
    local followObj = self.world:getObject(FollowObjID)
    if not followObj then
        Lib.logError("ShowTextUIOnEntity not followObj", FollowObjID)
        return
    end
    local desktop = GUISystem.instance:GetRootWindow()

    local beginOffsetPos = packet.beginOffsetPos or Lib.v3(0, 1, 0)
    if World.cfg.flyNumBeginOffsetPos then
        local pos = World.cfg.flyNumBeginOffsetPos
        beginOffsetPos = Lib.v3(pos[1], pos[2], pos[3])
    end
    local imgset = packet.imgset

    local win, widthSum, maxHeight = UILib.makeTextUIGrid("showTextUi", packet.textList, imgset or "number_mla")
    Lib.logInfo("ShowTextUIOnEntity widthSum and maxHeight = ", widthSum, maxHeight)

    win:SetTouchable(false)
    win:SetLevel(100)

    local height = World.cfg.whiteAbsHeight or 0
    if not packet.justSelf then
        local flyNumDistanceRatio = World.cfg.flyNumDistanceRatio or 0
        local flyNumBaseHeight = World.cfg.flyNumBaseHeight or 0
        local flyNumMaxHeight = World.cfg.flyNumMaxHeight or 0

        local distanceDec = Lib.getPosDistanceSqr(followObj:getPosition(), self:getPosition()) * flyNumDistanceRatio
        height = flyNumMaxHeight - distanceDec
        if height <= flyNumBaseHeight then
            height = flyNumBaseHeight
        end
    end
    local width = height * (widthSum / maxHeight)

    win:SetArea({0, 0}, {0, 0}, {0, width}, {0, height})
    desktop:AddChildWindow(win)
    local followCancel = UILib.uiFollowObject(win, FollowObjID, {offset = beginOffsetPos})
    Blockman.instance:setFollowWindowOffset(win, {x = math.random(-200, 200) / 100,
                                                  y = beginOffsetPos.y + (packet.distance or World.cfg.flyNumDistance or 2), z = 0}, World.cfg.flyNumMoveTime or 20)
    World.Timer(World.cfg.flyNumVanishTime or 20, function()
        if followCancel then
            followCancel()
        end
        desktop:RemoveChildWindow1(win)
        GUIWindowManager.instance:DestroyGUIWindow(win)
    end)
end

function handles:ShowNumberUIOnEntity(packet)
	local FollowObjID = packet.FollowObjID
	if not FollowObjID then
        return
    end
	local desktop = GUISystem.instance:GetRootWindow()
    local number
    if packet.isBigNum and type(packet.number) == "table" then
        number = BigInteger.Recover(packet.number)
    else
        number = packet.number
    end
	local beginOffsetPos = packet.beginOffsetPos
	local imgset = packet.imgset
	local imgfmt = packet.imgfmt
	local width = packet.imageWidth or 20
	local height = packet.imageHeight or 20
	local win = UILib.makeNumbersGrid("showNumberUi", number, imgset or "number_mla", imgfmt)
	local len = string.len(tostring(number))
	win:SetArea({0, 0}, {0, 0}, {0, width * len}, {0, height})
	desktop:AddChildWindow(win)
    local followCancel = UILib.uiFollowObject(win, FollowObjID, {offset = beginOffsetPos})
	Blockman.instance:setFollowWindowOffset(win, {x = 0, y = beginOffsetPos.y + (packet.distance or 2), z = 0}, 20)
	World.Timer(20, function()
        if followCancel then
            followCancel()
        end
		desktop:RemoveChildWindow1(win)
        GUIWindowManager.instance:DestroyGUIWindow(win)
	end)
end
function handles:ShowImagesEffect(packet)
	local images = packet.images or {}
	local desktop = GUISystem.instance:GetRootWindow()
	local pos = packet.pos
	local width = packet.imageWidth or 20
	local height = packet.imageHeight or 20
	local win = UILib.makeImagesGrid(images)
	local result = Blockman.instance:getScreenPos(pos)
	local len = #images
	win:SetArea({result.x, -width * len * 0.5}, {result.y, 0}, {0, width * len}, {0, height})
	desktop:AddChildWindow(win)
	local targetY = win:GetYPosition()[1] - (packet.distance or 0.1)
	Lib.uiTween(win, {
		Y = {targetY, 0},
		Alpha = 1.0
	}, 20, function()
		desktop:RemoveChildWindow1(win)
	end)
end

function handles:ShowBackpackDisplay(packet)
    Lib.emitEvent(Event.EVENT_BACKPACK_DISPLAY, packet.key, packet.title, packet.regId, packet.relativeSize)
end

function handles:ShowTreasureBox(packet)
    Lib.emitEvent(Event.SHOW_TREASUREBOX, packet)
end

function handles:UpdataTreasureBox(packet)
    Lib.emitEvent(Event.UPDATA_TREASURE_BOX, packet)
end

function handles:ResreshTreasureBoxCd(packet)
    Lib.emitEvent(Event.REFRESG_OPEN_CD)
end

function handles:SetEntityBodyYaw(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if entity then
        entity:setBodyYaw(packet.rotationYaw)
    end
end

function handles:ShowGenericListDisplayBox(packet)
    if packet.closeWin then
        Lib.emitEvent(Event.EVENT_OPEN_GENERIC_LIST_DISPLAY_BOX, false)
        return
    end
    if not packet.isOpenChild then
        Lib.emitEvent(Event.EVENT_OPEN_GENERIC_LIST_DISPLAY_BOX, true, packet.infoTb)
    else
        Lib.emitEvent(Event.EVENT_OPEN_GENERIC_LIST_DISPLAY_BOX_CHILD, packet.infoTb)
    end
end

function handles:ShowTitleBarPage(packet)
    if packet.updateWin then
        Lib.emitEvent(Event.EVENT_UPDATE_TITLE_BAR_PAGE, packet.infoTb)
        return
    end
	Lib.emitEvent(Event.EVENT_SHOW_TITLE_BAR_PAGE, not packet.closeWin, packet.infoTb)
end

function handles:ShowGenericActorShowStore(packet)
    if packet.updateWin then
        Lib.emitEvent(Event.EVENT_UPDATE_GENERIC_ACTOR_SHOW_STORE, packet.infoTb)
        return
    end
	Lib.emitEvent(Event.EVENT_OPEN_GENERIC_ACTOR_SHOW_STORE, not packet.closeWin, packet.infoTb)
end

function handles:SceneUiOperaction(packet)
    Lib.emitEvent(Event.EVENT_SCENEWND_OPERATION, packet.isOpen, packet.uiCfg)
end

function handles:SceneEntityUiOperaction(packet)
    Lib.emitEvent(Event.EVENT_ENTITY_SCENEWND_OPERATION, packet.isOpen, packet.uiCfg)
end

--todo: to be replaced
function handles:SceneUIOpen(packet)
	Lib.emitEvent(Event.EVENT_SCENEWND_OPERATION, packet.show, packet.data)
end

function handles:ShowAttackHitTip(packet)
	Lib.emitEvent(Event.EVENT_SHOW_HIT_COUNT, packet.start, packet.finish, packet.imageset)
end

function handles:ShowPlayerKillTip(packet)
	Lib.emitEvent(Event.EVENT_SHOW_PLAYER_KILL_COUNT, packet.count)
end

function handles:SetBgmRate(packet)
    local bgmsoundId = self:data("main").bgmsoundId
    if bgmsoundId then
        TdAudioEngine.Instance():setSoundSpeed(bgmsoundId, packet.rate)
    end
end

function handles:ShowObjectInteractionUI(packet)
    self:updateObjectInteractionUI({objID = packet.objID, show = true})
end

function handles:HideObjectInteractionUI(packet)
	self:updateObjectInteractionUI({objID = packet.objID, show = false})
end

function handles:SwitchInteractionWindow(packet)
    Lib.emitEvent(Event.EVENT_SWITCH_INTERACTION_WND, packet.isShow)
end

function handles:UpdateObjectInteractionUI(packet)
	self:updateObjectInteractionUI(packet)
end

function handles:RecheckAllInteractionUIs(packet)
	self:recheckAllInteractionUIs()
end

function handles:UpdatePartyInnerSettingUI(packet)
    Lib.emitEvent(Event.EVENT_SHOW_PARTY_INNER_SETTING, packet.isShow, packet)
end

function handles:ShowPartyList(packet)
    Lib.emitEvent(Event.EVENT_SHOW_PARTY_LIST, nil, packet.regId)
end

function handles:UpdateEntityEditContainer(packet)
	Lib.emitEvent(Event.EVENT_UI_EDIT_UPDATE_EDIT_CONTAINER, packet.objID, packet.show)
end

function handles:RefreshPartyList(packet)
    Lib.emitEvent(Event.EVENT_PARTY_LIST_CHANGED, packet.data)
end

function handles:RefreshPartyInfo(packet)
    Lib.emitEvent(Event.EVENT_PARTY_INFO_CHANGED, packet.partyData)
end


function handles:ShowGeneralOptions(packet)
    Lib.emitEvent(Event.EVENT_GENERAL_OPTIONS, packet)
end

function handles:UpdateGeneralOptionsRightSide(packet)
    Lib.emitEvent(Event.EVENT_GENERALOPTIONS_RIGHTSIDE, packet)
end

function handles:ShowGeneralOptionDerive(packet)
    Lib.emitEvent(Event.EVENT_SHOW_GENERAL_OPTION_DERIVE, packet.show, packet)
end

function handles:UpdateGeneralOptionDeriveRight(packet)
    Lib.emitEvent(Event.EVENT_UPDATE_GENERAL_OPTION_DERIVE, packet.frame, packet.params)
end

function handles:ShowNewShop(packet)
    Lib.emitEvent(Event.EVENT_NEW_SHOP, packet)
end

function handles:SpawItemEffect(packet)
	local cfg = Entity.GetCfg(packet.cfgName)
	local entity
	if cfg and cfg.spawEffect then
		entity = EntityClient.CreateClientEntity({
			cfgName = packet.cfgName,
			pos = packet.pos
		})
		if not entity then
			return
		end
		local spawData = cfg.spawEffect
		local actionData = spawData.action
		local effectData = spawData.effect
		local sound = spawData.sound
		if sound then
			local time = math.min(sound.delayTime or 1, 20)
			World.Timer(time, function()
				if entity and entity:isValid() then
					entity:playSound(sound)
				end
				Player.CurPlayer:playSound(sound)
				return false
			end)
		end
		if actionData then
			entity:updateUpperAction(actionData.name, actionData.time)
		end
		if effectData then
			World.Timer(effectData.delayTime or 1, function()
				local effectPathName = ResLoader:filePathJoint(cfg, effectData.effect)
				local time = tonumber(effectData.time)
				time = time and time / 20 * 1000 or -1
				Blockman.instance:playEffectByPos(effectPathName, Lib.v3add(packet.pos, effectData.pos or {x = 0, y = 0, z = 0}), 0, time)
				if time > 0 then
					World.Timer(effectData.time, function()
						entity:destroy()
					end)
				end
			end)
		end
	end
end

function handles:MarkEntityForPlayer(packet)
    local entity = World.CurWorld:getEntity(packet.targetId)
    if not entity then
        return
    end
    --local beginTime
    --local endTime
    --if packet.buffTime then
    --    beginTime = World.Now()
    --    endTime = beginTime + packet.buffTime
    --end
    local buffName = packet.buffName
	local buff = entity:addClientBuff(buffName, nil, packet.buffTime)
    local markBuff = entity:data("markBuff") or {}
    markBuff[buffName] = buff
    entity:setData("markBuff", markBuff)
    self:setData("targetId", packet.targetId)
end

function handles:UnMarkEntityForPlayer(packet)
    local entity = World.CurWorld:getEntity(packet.targetId)
    if not entity then
        return
    end
    local markBuff = entity:data("markBuff")
    local buff = markBuff[packet.buffName]
    if buff then
        entity:removeClientBuff(buff)
        markBuff[packet.buffName] = nil
    end
    self:setData("targetId")
end

function handles:SetEntityName(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if entity then
        entity:setName(Lang:toText(packet.name))
        entity:updateShowName()
    end
end

function handles:ShowInputDialog(packet)
    Lib.emitEvent(Event.EVNET_SHOW_INPUT_DIALOG, packet)
end

function handles:RequestTrade(packet)
	Lib.emitEvent(Event.EVENT_REQUEST_TRADE, packet)
end

function handles:TradeRefused(packet)
	Lib.emitEvent(Event.EVENT_TRADE_NOTICE, "gui_trade_refuse")
end

function handles:TradeSucceed(packet)
	Lib.emitEvent(Event.EVENT_TRADE_NOTICE, "gui_request_accomplish")
end

function handles:StartTrade(packet)
	Lib.emitEvent(Event.EVENT_START_TRADE, true, packet.tradeID, packet.targetUid, packet.tradeItem)
end

function handles:TradeClose(packet)
	local showType = {
		showCenter = 2,
		keepTime = 40,
		textKey = "gui.trade." .. packet.reason
	}
	Client.ShowTip(showType.showCenter, showType.textKey, showType.keepTime)
	Lib.emitEvent(Event.EVENT_START_TRADE, false)
end

function handles:TradePlayerConfirm(packet)
	Lib.emitEvent(Event.EVENT_TRADE_CONFIRM, packet.isConfrim, packet.tradeID)
end

function handles:TradeItemChange(packet)
	Lib.emitEvent(Event.EVENT_TRADE_ITEM_CHANGE, packet.tradeID ,packet.operation, packet.data)
end

function handles:TradePlayerCancel(packet)
	local showType = {
		showCenter = 2,
		keepTime = 40,
		textKey = "gui.trade.close"
	}
	Client.ShowTip(showType.showCenter, showType.textKey, showType.keepTime)
	Lib.emitEvent(Event.EVENT_START_TRADE, false)
end

function handles:TradeReset(packet)
	Lib.emitEvent(Event.EVENT_RESET_TRADE, packet.tradeID)
end

function handles:ShowEquipUpgradeUI(packet)
    Lib.emitEvent(Event.EVENT_SHOW_EQUIP_UPGRADE, packet)
end

function handles:UpdateSkillJackArea(packet)
    Lib.emitEvent(Event.EVENT_UPDATE_SKILL_JACK_AREA, packet.info)
end

function handles:lockVision(packet)
    Blockman.instance:setLockVisionState(packet.state)
end

function handles:TouchBlock(packet)
    PlayerControl.OnTouchBlock(self, packet.pos)
end

function handles:SyncVarVal(packet)
    Lib.emitEvent(Event.EVENT_VARS_SYNC, packet.key, packet.val)
end

function handles:EntityFly(packet)
    self.isFlying = packet.flag
end

function handles:PauseGame(packet)
    Lib.emitEvent(Event.EVENT_SYNC_PAUSE_STATE, packet.state)
    World.CurWorld:setGamePause(packet.state)
end

function handles:ShowTeamInfo(packet)
	Lib.emitEvent(Event.EVENT_SHOW_TEAM_INFO, packet)
end

function handles:AddMainGains(packet)
    Lib.emitEvent(Event.EVENT_ADD_MAIN_GAIN, packet)
end

function handles:OperationWindows(packet)
    if packet.isOpen then
        UI:openWnd(packet.winName, packet.data)
    else
        UI:closeWnd(packet.winName)
    end
end

function handles:ShowRewardItemEffect(packet)
	Lib.emitEvent(Event.EVENT_SHOW_REWARD_EFFECT,packet.type, packet.key, packet.count or 1, packet.time)
end

function handles:ShowBgmList(packet)
	Lib.emitEvent(Event.EVENT_SHOW_BGM_LIST, packet.show)
	if packet.playingIndex then
		Lib.emitEvent(Event.EVENT_PLAYING_BGM_CHANGED, packet.playingIndex)
	end
end

function handles:UpdateBgmPlayingIndex(packet)
	Lib.emitEvent(Event.EVENT_PLAYING_BGM_CHANGED, packet.playingIndex)
end

function handles:ShowSellShop(packet)
    Lib.emitEvent(Event.EVENT_SHOW_SELL_SHOP, packet)
end


function handles:playerEffect(packet)
    Blockman.instance:playEffectByPos(packet.name, packet.pos, 0, 1000)
end

function handles:SyncCameraMode(packet)
    self:setCameraMode(packet.isOpen)
    self:updateMainPlayerRideOn()
end

function handles:HeadCountDown(packet)
	Lib.emitEvent(Event.SHOW_HEAD_COUNT_DOWN, packet)
end

function handles:TakePhotos(packet)
    local Recorder = T(Lib, "Recorder")
    local uiEffectWnds = Recorder:GetUiEffectWindows()

    if GUISystem.instance:GetRootWindow() then
        UI:HideAllWindowsExcept(uiEffectWnds, true)
        Me:timer(5, function()
            Interface.onAppActionTrigger(8)
        end)
        Me:timer(3 * 20, function ()
            UI:RestoreAllWindows()
            return false
        end)
    end
end

function handles:OpenSignIn(packet)
	Lib.emitEvent(Event.EVENT_SHOW_NEW_SIGIN_IN, true)
	Lib.emitEvent(Event.EVENT_SIGNIN_RED_POINT, true)
end

function handles:ShowInviteTip(packet)
    Lib.emitEvent(Event.EVENT_SHOW_INVITE_TIP, packet)
end

function handles:ShowLongTextTip(packet)
    Lib.emitEvent(Event.EVENT_SHOW_LONG_TEXT_TIP, packet)
end

function handles:ShowToolBarBtn(packet)
	Lib.emitEvent(Event.EVENT_SHOW_TOOLBAR_BTN, packet.name, packet.show)
end

function handles:ShowGoldShop(packet)
	 Lib.emitEvent(Event.EVENT_SHOW_GOLD_SHOP, packet.show)
end

function handles:ShowAnimationReward(packet)
    Lib.emitEvent(Event.EVENT_SHOW_ANIMATION_TIP, packet.cfgKey, function()
        Lib.emitEvent(Event.EVENT_SHOW_REWARD_EFFECT, packet.type, packet.key, packet.count or 1, packet.time)
    end)
end

function handles:HideOpenedWnd(packet)
    Me.showFuncMap = Me.showFuncMap or {}
    Me.showFuncMap[packet.showFuncId] = UI:hideOpenedWnd(packet.excluded)
end

function handles:ShowOpenedWnd(packet)
    local showFuncMap = Me.showFuncMap or {}
    local func = showFuncMap[packet.showFuncId]
    if func then
        func()
        showFuncMap[packet.showFuncId] = nil
    end
end

function handles:ShowRecharge(packet)
    Lib.emitEvent(Event.EVENT_SHOW_RECHARGE)
end

function handles:ShowSumRecharge(packet)
    local config = Player.getSumRecharge(packet.id)
    if not config then
        return
    end
    local layout = UI:getWnd("sum_recharge_layout")
    layout:reloadUI(config)
    layout:onOpen(config)
    UI:closeWnd(layout)
    if packet.remind then
        UI:openWnd("sum_recharge_layout")
    end
end

function handles:SumRechargeGCube(packet)
    local layout = UI:getWnd("sum_recharge_layout")
    layout:updateGCubeValue(packet.gcube)
end

function handles:SumRechargeResult(packet)
    local config = Player.getSumRecharge(packet.id)
    if not config then
        return
    end
    local result = UI:getWnd("sum_recharge_result")
    result:reloadUI(config)
    UI:openWnd("sum_recharge_result", config)
end

function handles:ShowEdge(packet)
    local objId = packet.targetId or self.objID
    local entity = World.CurWorld:getEntity(objId)
    if not entity then
        return
    end
    entity:setEdge(packet.switch, packet.color or {1,1,1,1})
end

function handles:ReceiveCenterFriend(packet)
    FriendManager.ReceiveCenterFriend(packet.friends)
end

function handles:ShowCenterFriend(packet)
    if packet.show then
        UI:openWnd("invite_friends", packet)
    else
        UI:closeWnd("invite_friends")
    end
end

function handles:ShowSlidingPrompt(packet)
    Lib.emitEvent(Event.EVENT_SLIDING_PROMPT, packet)
end

function handles:ClearSlidingPrompt(packet)
    Lib.emitEvent(Event.ENTITY_CLEAR_SLIDING_PROMPT, packet.key, packet.value)
end

function handles:ShowUpglideTip(packet)
    local textArgs = packet.textArgs or {}
    local t_arg = {packet.textKey, table.unpack(textArgs)}
    Lib.emitEvent(Event.ENTITY_UPGLIDE_TIP, Lang:toText(t_arg), packet.keepTime)
end

function handles:GotoTargetServer(packet)
    print("jump server gameId:" , packet.gameId)
    CGame.instance:resetGameByGameId(tostring(packet.gameId))
end

function handles:ShowChatChannel(packet)
    Lib.emitEvent(Event.EVENT_CHAT_CHANNEL, packet.show, packet.channelName)
end

function handles:UpdateAnimoji(packet)
	self:setData("animoji", packet.data)
	Lib.emitEvent(Event.EVENT_UPDATE_ANIMOJI)
end

function handles:BeAttacked(packet)
    Lib.emitEvent(Event.EVENT_BE_ATTACKED, packet)
end

function handles:SyncEntityMode(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if entity then
        entity:setEntityMode(packet.mode, packet.targetId)
    end
end

function handles:ShowEditEntityPosRot(packet)
    if UI:isOpen("editEntityPosRot") then
        UI:getWnd("editEntityPosRot", true):onReload(packet.objID)
    else
        UI:openWnd("editEntityPosRot", packet.objID)
    end
end

-- test code -- TODO DEL
-- local misc = require "misc"
-- local now_nanoseconds = misc.now_nanoseconds
-- local function getTime()
--     return now_nanoseconds() / 1000000
-- end
-- test code end

function handles:ChunkData(packet)
    -- local beginTime = getTime() -- todo del
    self:deseriChunkData2map(packet.mapId, packet.data)
    -- print(" client handles:ChunkData(packet) ", getTime() - beginTime) -- todo del
end

function handles:PickDropItem(packet)
    local dropItem = World.CurWorld:getObject(packet.dropItemId)
    local player = World.CurWorld:getObject(packet.pickEntityId)
    if not dropItem or not dropItem:isValid() then
        return
    end
    if player and player:isValid() then
        local len = Lib.getPosDistanceSqr(player:getPosition(), dropItem:getPosition())
        if	0 < dropItem.attractedLv and dropItem.attractedLv <= player:prop("attractLv") and len <= (player:prop("attractRange") * player:prop("attractRange")) then
            dropItem:setTargetId(packet.pickEntityId)
        end
    end
    local item = dropItem:item()
    local itemcfg = item:cfg()
    local blockId = item:block_id()
    if blockId then
        itemcfg = Block.GetIdCfg(blockId)
    end

    dropItem.pickedTimer = dropItem:timer(itemcfg.flyTowardsPickedTime or World.cfg.dropItemFlyTowardsPickedTime or 0, function()
        dropItem.pickedTimer = nil
        dropItem:playPickEffect()
        dropItem:destroy("fly towards picked")
    end)
end

function handles:RecalcCacheChunkData(packet)
	local mapChunkDataArr = self.mapChunkDataArr
    if not mapChunkDataArr then
        mapChunkDataArr = {}
        self.mapChunkDataArr = mapChunkDataArr
	end
	local mapChunkDataWithMapId = mapChunkDataArr[packet.mapId]
    if not mapChunkDataWithMapId then
        mapChunkDataWithMapId = {}
		mapChunkDataArr[packet.mapId] = mapChunkDataWithMapId
    end
    local chunkPos = packet.chunkPos
    local x,z = chunkPos.x, chunkPos.z
    local data = packet.data

    local isFind = false
    for i, chunkDatas in pairs(mapChunkDataWithMapId) do
        for _, chunkData in pairs(chunkDatas.chunkData) do
            if chunkData.x == x and chunkData.z == z then
                chunkData.isZip = data.isZip
                chunkData.data = data.data
                chunkData.chunkBuffSize = data.chunkBuffSize
                chunkDatas.isLoad = false
                isFind = true
                break
            end
        end
    end
    
    if not isFind then
        mapChunkDataWithMapId[#mapChunkDataWithMapId + 1] = {
            chunkData = {[1] = { x = chunkPos.x, z = chunkPos.z, isZip = data.isZip, data = data.data, chunkBuffSize = data.chunkBuffSize}}, 
            isLoad = false
        }
    end
end

function handles:SyncFlyMode(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if entity then
        entity:setFlyMode(packet.mode)
        if entity.isMainPlayer then
            Lib.emitEvent(Event.EVENT_UPDATE_FLY_STATE, packet.mode < 0)
        end
    end
end

------------------------ client entity
function handles:CreateMapClientEntitys(packet)
    self:createMapClientEntitys(packet)
end

function handles:RemoveMapClientEntitys(packet)
    self:removeMapClientEntitys(packet)
end

function handles:ClearMapClientEntity(packet)
    self:clearMapClientEntity(packet)
end

function handles:ClearAllClientEntity(packet)
    self:clearAllClientEntity(packet)
end
------------------------ client entity end

function handles:ForceMoveToSelf(packet)
	self:setForceMove(packet.pos, packet.time)
end

function handles:MultiStageSkillData(packet)
    self:data("skill").multiStageData = packet.data
end

function handles:ServerPackageHandler(packet)
    PackageHandlers.receiveServerHandler(self, packet.name, packet.package)
end

function handles:SyncActionPriceList(packet)
    if not packet.actionList then
        return
    end

    self:setData("actionPriceList", packet.actionList)
end

local propNotify = {
    maxHp = "ENTITY_HP_NOTIFY",
    maxVp = "ENTITY_VP_NOTIFY"
}
function handles:SetProp(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    if entity == nil then
        Lib.logError("handles:SetProp error ", Lib.v2s(packet, 2))
        return
    end
    if not entity:isValid() then
        return
    end
    if packet.isBigInteger then
        packet.value = BigInteger.Recover(packet.value)
    end
    local key,value = packet.key,packet.value
	entity:doSetProp(key,value)
    local event = propNotify[key]
    if event then
        Lib.emitEvent(Event[event],value,entity)
    end
end

function handles:PromptPayment(packet)
    if GUIManager:Instance():isEnabled() then
        local payConfirmWnd = UI:openSystemWindow("payConfirm", nil, packet.price)
        payConfirmWnd:updatePrice(packet.price)
        --UI:openSystemWindowAsync(function(window) window:updatePrice(packet.price) end,"payConfirm", nil, packet.price)

    end
end

function handles:SyncProp(packet)
    local entity = World.CurWorld:getEntity(packet.objID)
    entity:setProps(packet.props)
end

function handles:SetForceSwim(packet)
    Me:setForceSwimMode(packet.enable)
end

function handles:SetForceClimb(packet)
    Me:setForceClimbMode(packet.enable, packet.speed, packet.angle)
end

function handles:DebugTransferRequest(packet)
	remotedebug.TransferRequest(packet, self)
end

function handles:DebugTransferResponse(packet)
	remotedebug.TransferResponse(packet, self)
end

function handles:ResetItemSelect(packet)
    if not GUIManager:Instance():isEnabled() then
        return
    end

    local shortcutBarWnd = UI:isOpenWindow("shortcutBar")
    if shortcutBarWnd then
        shortcutBarWnd:resetSelect()
    end
end

function handles:ShowPropCollectCountDown(packet)
    Lib.emitEvent(Event.EVENT_PROP_COLLECTION_COUNTDOWN, {collectorsName = packet.collectorsName, isCancel = packet.isCancel, CountdownTime = packet.CountdownTime, 
        autoCountDown = packet.autoCountDown, fromPCGameOverCondition = packet.fromPCGameOverCondition})
end

function handles:ServerGameOver(packet)
    Lib.emitEvent(Event.EVENT_SERVER_GAMEOVER, packet)
end

function handles:ServerErrorMessage(packet)
    showErrorMessage(packet.errMsg, "-server:")
end

local isOpenLuaErrorMessage = false
function showErrorMessage(msg, env)
    if World.CurWorld and World.CurWorld:getNeedShowLuaErrorMessage() and not isOpenLuaErrorMessage then
        isOpenLuaErrorMessage = true
        env = env or "-client:"
        UILib.openChoiceDialog({titleText = Me.platformUserId .. env ..": 脚本出错, 请联系程序",
                                msgText = string.sub(msg, 1, 256), leftText = "取消",
                                rightText = "确定并复制"}, function(ok)

            World.CurWorld:setNeedShowLuaErrorMessage(ok)
            if not ok then
                Blockman.instance:onSetClipboard(env .. "\n" .. msg)
            end
            isOpenLuaErrorMessage = false
        end)
    end
end

function handles:ConnectorMsg(packet)
    Lib.emitEvent(Event.EVENT_CONNECTOR_MSG, packet.data)
end

function handles:ExitGame(packet)
    Game.Exit()
end

function handles:BtsMsg(packet)
	local context = packet
	for i,cfg in pairs(World.cfgSet) do
        if cfg then
			context.instance = cfg.instance
			context.player = self
		    Trigger.CheckTriggersOnly(cfg, packet.msg, context)
        end
	end
    --Lib.pv({trigger = msg, player = self, msg = msg, vars = vars})
end

function handles:EventAsync(packet)
    local EventName = packet.EventName
    local Args = packet.Args
    self:EmitEvent(EventName, table.unpack(Args))
end

local reportController = require "report.controller"
function handles:EventTrackingList(packet)
    reportController:receiveEventTrackingList(packet.list)
end