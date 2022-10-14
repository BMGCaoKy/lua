require "async_process.async_process"
require "async_process.async_process_cdkey"
require "async_process.async_process_party"

local debugPort = require "common.debugport"
local cjson = require("cjson")
local events = {}

function server_event(event, ...)
	--print("server_event", event, ...)
	local handler = events[event]
	if not handler then
		print("no handler for server_event", event)
		return
	end
	Profiler:begin("server_event."..event)
	handler(...)
	Profiler:finish("server_event."..event)
end

function events.http_response(session, response)
	AsyncProcess.HandleHttpResponse(session, response)
end

local broadcastEvent = {
	[Define.BROADCAST_INVITE] = "PLAYER_BE_INVITE_OTHER_SERVER",
	[Define.BROADCAST_SEND_MSG] = "PLAYER_BE_SEND_MESSAGE",
	[Define.PARTY_ALMOST_OVER] = "PARTY_ALMOST_OVER",
	[Define.PARTY_OVER] = "PARTY_OVER",
	[Define.BROADCAST_SEND_EMAIL] = "PLAYER_BE_SEND_EMAIL",
}

local function receiveRoomCommonMsg(data)
	
end

function events.getBroadcastMessage(msg)
	local ok, data = pcall(cjson.decode, msg)
	if not ok then
		perror("getBroadcastMessage decode error", msg)
		return
	end

	local event = broadcastEvent[data.type]
	local content
	if data.content == "" or not data.content then
		content = {}
	else
		content = cjson.decode(data.content) or {}
	end
	if data.type == Define.BROADCAST_COMMON then
		---receive room common msg
		receiveRoomCommonMsg(content)
		return
	end
    local version1 = content.engineVersion
    local version2 = debugPort.engineVersion
    if version1 and version1 ~= version2 then
        print(string.format("different engineVersion! from: %s, now: %s", version1, version2))
        return
    end
	local targets = data.targets
	local targetPlayers = {}
	if not targets then --data.scope == "game"
		targetPlayers = Game.GetAllPlayers()
	else
		for _, id in pairs(targets) do
			local player = Game.GetPlayerByUserId(tonumber(id))
			if not player then
				print("can not get player!", id)
				goto continue
			end
			targetPlayers[#targetPlayers + 1] = player
			::continue::
		end
	end

	if data.type == Define.PARTY_ALMOST_OVER or data.type == Define.PARTY_OVER then
		targetPlayers = Game.GetAllPlayers()
	end

	if data.type == Define.BROADCAST_INVITE and Game.PlayerBeInviteOtherServer then
		Game.PlayerBeInviteOtherServer(targetPlayers, data.fromUserId, content)
	end
	for _, target in pairs(targetPlayers) do
		Trigger.CheckTriggers(target:cfg(), event, {obj1 = target, fromUserId = data.fromUserId, content = content})
	end
end

function events.onUserAttr(userId, targetId, loc)
	Trigger.CheckTriggers(nil, "ON_USER_ATTR", {userId = userId, targetId = targetId, loc = loc})
end

function events.onSyncActionList(actionId, price, currency, buyId)
	Game.OnSyncActionPriceList(actionId, price, currency, buyId)
end

function events.onStop()
	if World.serverType == "gamecenter" then
		print("gamecenter stoped!")
		ATProxy:onStop()
	else
		print("server stoped!")
		Game.OnStop()
	end
end

function events.userReconnect(userId)
	print("userReconnect! userId : ", userId)
end

local isServerQuitting = false
function events.gameQuitting(gameId)
	if isServerQuitting then
		return
	end
	isServerQuitting = true
	print("gameQuitting !! gameId -> ", gameId)
	Game.ServerQuitting()
end

function events.atproxy_msg(id, data)
	ATProxy.Instance():onMsg(id, data)
end

Server.customizeConfig = cjson.decode(Server.CurServer:getCustomizeConfig())
