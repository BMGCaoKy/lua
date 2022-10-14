local PlayerDBMgr = T(Lib, "PlayerDBMgr") ---@type PlayerDBMgr
local events = {}

function player_event(player, event, ...)
	--print("player_event", player.name, event, ...)
	local func = events[event]
	if not func then
		print("no event!", event)
		return
	end
	Profiler:begin("player_event."..event)
	func(player, ...)
	Profiler:finish("player_event."..event)
end

function events:reconnect(addr)
	self.justLoginOrLogout = true
	self.clientAddr = addr
	
	local userId = self.platformUserId
	ReportManager:reportUserEnter(userId,self.clientInfo)

	self:timer(1, self.reconnect, self)
	
	GM.updateGMList(self)
end

function events:login(addr)
    self.justLoginOrLogout = true
	self.clientAddr = addr
	if not Game.CheckCanJoin(self) then
		return
	end
	self:data("main").inGameTime = os.time()

	local vars = self.vars
	vars.clanName = ""
	vars.vip = 0

	MapChunkMgr.onPlayerLoginOrLogout(self)
	PlayerDBMgr.onGetLoginDBData(self)
	local userId = self.platformUserId
	ReportManager:reportUserEnter(userId,self.clientInfo)
	
	GM.updateGMList(self)
end

function events:logout()
	print("debug monitor  logout", self.platformUserId)
	self.justLoginOrLogout = true
	self.packetLoss = self:getPacketLoss()
	Lib.XPcall(function()
		Plugins.CallPluginFunc("onPlayerLogout", self)
	end, "events:logout->Plugins.CallPluginFunc")
	Lib.XPcall(function()
		ReportManager:onPlayerLogout(self)
	end, "events:logout->ReportManager:onPlayerLogout")
	Lib.XPcall(function()
		MapChunkMgr.onPlayerLoginOrLogout(self)
	end, "events:logout->MapChunkMgr.onPlayerLoginOrLogout")

	local function xpcallGameLogoutPlayer()
		Lib.XPcall(function()
			Game.OnPlayerLogout(self)
		end, "events:logout->Game.OnPlayerLogout")
	end

	if not self.dataLoaded then
		Game.RemoveLogoutPlayer(self)
		return
	end

	if not World.gameCfg.disableSave and World.cfg.needSave then
		xpcallGameLogoutPlayer()
		self.Logouting = true
		local _, ret = Lib.XPcall(function()
			return PlayerDBMgr.SaveImmediate(self)
		end, "events:logout->PlayerDBMgr.SaveImmediate")
		if ret == false then
			Game.RemoveLogoutPlayer(self)
		end
	else
		xpcallGameLogoutPlayer()
		Game.RemoveLogoutPlayer(self)
	end
end

function events:sendRemove(id)
	local entity = self.world:getEntity(id)

	local objRemovePK
	local function getPk()
		if objRemovePK == nil then
			objRemovePK = {
				pid = "ObjectRemoved",
				entityUI = nil,
				objID = nil
			}
		end
		return objRemovePK
	end

	local pk = getPk()
	pk.entityUI = entity and entity:data("entityUI")
	pk.objID = id
	self:sendPacket(pk)

end

function events:sendRemoveList(list)
	local allEntity = {}
	local packet = {
		pid = "ObjectListRemoved",
		list = allEntity,
	}
	for _, id in ipairs(list) do
		local entity = self.world:getEntity(id)
		allEntity[id] = entity and entity:data("entityUI") or {}
	end
	self:sendPacket(packet)
end

function events:sendSpawn(id)
	local obj = self.world:getObject(id)
	obj:addTracker(self)
	if self:getMode() ~= self:getCommonMode() and id == self:getTargetId() then
		self:setEntityMode(self:getMode(), self:getTargetId())
	end
end

function events:httpResponse(session, response)
	self:handle_http_response(session, response)
end
function events:leaveGround()
	--TODO
--	print("=================leaveGround=====================")
end

function events:fallGround()
	Lib.emitEvent(Event.EVENT_ON_GROUND, self)
end

function events:onPlyerJump()
end
