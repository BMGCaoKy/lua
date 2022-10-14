local misc = require("misc")

local handles = T(ATProxy, "PackageHandlers")

local atproxy = ATProxy.Instance()

ATProxy.isReady = true

local ServerClass = T(ATProxy, "ServerClass")
ServerClass.__index = ServerClass

local ServerList = T(ATProxy, "ServerList")
local PlayerList = T(ATProxy, "PlayerList")


local function serverInit(id, data)
	print("ATProxy ServerInit:", data.id)
	assert(id == data.id)
	if ServerList[id] then
		perror("ServerInit duplicated id:", id)
		ServerList[id]:close()
	end
	local server = {
		id = id,
		info = data,
		gameId = data.gameId,
		players = {},
	}
	ServerList[id] = setmetatable(server, ServerClass)
	local ret = {
		pid = "CenterInit",
		id = ATProxy.myServerId,
	}
	server:send(ret)
end

function ATProxy:onMsg(id, msg)
	local data = misc.data_decode(msg)
	data = Packet.Decode(data)
	print("ATProxy:onMsg", id, data.pid)
	if data.pid=="ServerInit" then
		serverInit(id, data)
	else
		local func = assert(handles[data.pid], data.pid)
		local server = assert(ServerList[id], id)
		func(server, data)
	end
end

function ATProxy:sendToPlayer(id, data, from)
	local player = PlayerList[id]
	if not player then
		local server = assert(ServerList[from], from)
		data.cmd = "none_player"
		local fromId = data.fromId
		data.fromId = nil
		server:send({
			pid = "PlayerCmd",
			id = fromId,
			data = data.fault or data,
		})
		return false
	end
	player.server:send({
		pid = "PlayerCmd",
		id = id,
		from = from,
		data = data,
	})
	return true
end

function ATProxy:onStop()
	atproxy:broadcastToServer({
		pid = "CenterDisconnect",
		id = ATProxy.myServerId
	})
end

function ATProxy:showServerList(showPlayer)
	local function countTable(tb)
		local n = 0
		for _ in pairs(tb) do
			n = n + 1
		end
		return n
	end
	for _, server in pairs(ServerList) do
		print("server: " .. server.id, "players: " .. countTable(server.players))
		if showPlayer then
			for _, player in pairs(server.players) do
				print("", player.id, player.info.name)
			end
		end
	end
end

function ServerClass:send(data)
	atproxy:sendToServer(self.id, data)
end

function ServerClass:close()
	if not self.id then
		return
	end
	assert(ServerList[self.id] == self)
	for id, player in pairs(self.players) do
		perror("close_server left player:", self.id, id)
		PlayerList[id] = nil
	end
	ServerList[self.id] = nil
	self.id = nil
end

function handles:PlayerEnter(data)
	local oldPlayer = PlayerList[data.id]
	if oldPlayer then
		perror("PlayerEnter repeat id:", data.id, oldPlayer.server.id, self.id)
		PlayerList[data.id] = nil
		oldPlayer.server[data.id] = nil
	end
	data.serverId = self.id
	local player = {
		id = data.id,
		info = data,
		server = self,
		friends = {}
	}
	PlayerList[data.id] = player
	self.players[data.id] = player
	if not World.cfg.loadCenterFriend then
		return
	end
	local users = {}
	for userId in pairs(PlayerList) do
		if userId ~= data.id then
			table.insert(users, userId)
		end
	end
	if #users > 0 then
		self:send({
			pid = "RequestFriends",
			id = data.id,
			users = users,
		})
	end
end

function handles:PlayerLeave(data)
    local oldPlayer = PlayerList[data.id]
    if not oldPlayer then
        perror("PlayerLeave error id:", data.id, self.id)
        return
    end
    assert(oldPlayer.server == self, self.id)
    PlayerList[data.id] = nil
    self.players[data.id] = nil
    for userId in pairs(oldPlayer.friends) do
        local f_data = PlayerList[userId]
        if f_data then
            f_data.friends[data.id] = nil
        end
    end
end

function handles:PlayerCmd(data)
	atproxy:sendToPlayer(data.id, data.data, self.id)
end

function handles:PlayerFriends(data)
    local player = PlayerList[data.id]
    if not player then
        return
    end
    for _, userId in ipairs(data.friends or {}) do
        local f_data = PlayerList[userId]
        if f_data then
            local fInfo = Lib.copy(f_data.info)
            fInfo.together = f_data.server.id == self.id
            local info = Lib.copy(player.info)
            info.together = f_data.server.id == self.id
            player.friends[userId] = fInfo
            f_data.friends[data.id] = info
        end
    end
end

function handles:UpdatePlayerInfo(data)
    local player = PlayerList[data.id]
    if not player then
        return
    end
    local info = data.info
    player.info.data = info
    for userId in pairs(player.friends) do
        local f_data = PlayerList[userId]
        local friendData = f_data and f_data.friends[data.id]
        if friendData then
            friendData.data = info
        end
    end
end

function handles:GotoTargetServer(data)
    local targetPlayer = PlayerList[data.targetUserId]
    local gameId
    if targetPlayer then
       gameId = targetPlayer.server.gameId
    end
    self:send({
        pid = "GotoTargetServer",
        id = data.id,
        gameId = gameId,
        targetUserId = data.targetUserId,
    })
end

function handles:RequestFriends(data)
    local player = PlayerList[data.id]
    if not player then
        return
    end
    self:send({
        pid = "ReceiveFriends",
        id = data.id,
        friends = player.friends,
    })
end

local function syncServers()
	atproxy:broadcastToServer({
		pid = "SyncServerInfo"
	})
end

syncServers()