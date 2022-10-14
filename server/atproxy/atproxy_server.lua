
local misc = require("misc")
local handles = T(ATProxy, "PackageHandlers")
local atproxy = ATProxy.Instance()
local waitSyncFunc
local PlayerDBMgr = T(Lib, "PlayerDBMgr") ---@type PlayerDBMgr

ATProxy.mainGameCenter = ATProxy.mainGameCenter

local function reportToCenter(self)
	local cfg = World.gameCfg
	local data = {
		pid = "ServerInit",
		id = ATProxy.myServerId,
		ip = cfg.ip or "0.0.0.0",
		port = cfg.port or 19130,
		gameId = Game.GameId(),
	}
	data = Packet.Encode(data)
	self:broadcastMsg(World.GameName .. "_gamecenter", misc.data_encode(data))
end

World.Timer(1, reportToCenter, atproxy)

function ATProxy:onMsg(id, msg)
	local data = misc.data_decode(msg)
	print("ATProxy:onMsg", id, data.pid)
	data = Packet.Decode(data)
	local func = assert(handles[data.pid], data.pid)
	func(id, data)
end

function ATProxy:sendToCenter(data)
	--assert(ATProxy.mainGameCenter)
	if not ATProxy.mainGameCenter then
		print("ATProxy mainGameCenter not open")
		return
	end
	self:sendToServer(ATProxy.mainGameCenter, data)
end

function ATProxy:sendToPlayer(id, data)
	self:sendToCenter({ pid = "PlayerCmd", id = id, data = data })
end


function handles.CenterInit(id, data)
	print("ATProxy CenterInit:", data.id)
	assert(id == data.id)
	ATProxy.mainGameCenter = id
	ATProxy.isReady = true
	for _, player in pairs(Game.GetAllPlayers()) do
		Trigger.CheckTriggers(player:cfg(), "CENTER_INIT", {obj1 = player})
	end
	if waitSyncFunc then
		waitSyncFunc()
		waitSyncFunc = nil
	end
end

function handles.CenterDisconnect(id, data)
	print("ATProxy CenterDisconnect:", data.id)
	ATProxy.mainGameCenter = nil
	ATProxy.isReady = false
	for _, player in pairs(Game.GetAllPlayers()) do
		Trigger.CheckTriggers(player:cfg(), "CENTER_DISCONNECT", {obj1 = player})
	end
end

function handles.SyncServerInfo(id, data)
	reportToCenter(atproxy)
	local function func()
		for _, player in pairs(Game.GetAllPlayers()) do
			ATProxy.Instance():sendToCenter({
				pid = "PlayerEnter",
				id = player.platformUserId,
				name = player.name,
				data = player:viewEntityInfo("centerInfo"),
			})
		end
	end
	if ATProxy.isReady then
		func()
	else
		waitSyncFunc = func
	end
end

function handles.PlayerCmd(id, data)
	local player = Game.GetPlayerByUserId(data.id)
	local params = data.data
	if player then
		params.obj1 = player
		Trigger.CheckTriggers(player:cfg(), "CENTER_CMD", params)
	elseif params.fromId then
		params.cmd = "none_player"
		ATProxy.Instance():sendToPlayer(params.fromId, params.fault or params)
	end
	print("PlayerCmd:", data.id, data.from, player and player.name)
end

function handles.ChatMessage(id, data)
	local msg = data.msg
	if utf8.len(msg) > 1000 then
		return
	end
	msg = World.CurWorld:filterWord(data.msg)
	WorldServer.ChatMessage(msg,data.name,data.type,data.objID)
end

function handles.RequestFriends(id, data)
    AsyncProcess.GetUserRelation(data.id, data.users, function(friends)
		ATProxy.Instance():sendToCenter({pid = "PlayerFriends", id = data.id, friends = friends})
    end)
end

function handles.ReceiveFriends(id, data)
	local player = Game.GetPlayerByUserId(data.id)
	if not player then
		return
	end
	player:sendPacket({
		pid = "ReceiveCenterFriend",
		friends = data.friends,
	})
end

function handles.GotoTargetServer(id, data)
    local player = Game.GetPlayerByUserId(data.id)
    if not player then
        print("player cannot find:", data.id)
        return
    end
    if not data.gameId then
        print("targetPlayer cannot find server", data.targetUserId)
        return
    end
	PlayerDBMgr.SaveImmediate(player)
    player:sendPacket({
        pid = "GotoTargetServer",
        gameId = data.gameId
    })
end