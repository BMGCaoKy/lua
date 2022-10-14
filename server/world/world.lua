require "common.map"
require "common.world"
require "world.map"
require "world.region"

local misc = require "misc"
local WorldServer = WorldServer ---@class WorldServer : World

World.isClient = false
World.vars = Vars.MakeVars("global", nil)

local function encodePacket(packet)
	local pid = packet.pid
	return misc.data_encode(Packet.Encode(packet)), pid
end

function WorldServer.BroadcastPacket(packet)
	local data, pid = encodePacket(packet)
	local count = WorldServer.BroadcastScriptPacket(data)
	World.AddPacketCount(pid, #data, true, count)
end

function WorldServer.MulticastPacket(packet, targets)
	if not next(targets) then
		return
	end
	
	local data, pid = encodePacket(packet)
	local count = WorldServer.MulticastScriptPacket(data, targets)
	World.AddPacketCount(pid, #data, true, count)
end

function WorldServer.MapBroadcastPacket(mapId, packet)
	local data, pid = encodePacket(packet)
	local count = WorldServer.MapBroadcastScriptPacket(mapId, data)
	World.AddPacketCount(pid, #data, true, count)
end

function WorldServer.ChatMessage(msg, fromname, type, ...)
	local packet = {
		pid = "ChatMessage",
		fromname = fromname,
		msg = msg,
		type = type,
		args = table.pack(...),
	}
	WorldServer.BroadcastPacket(packet)
end

function WorldServer.SystemChat(typ, key, ...)
	local packet = {
		pid = "SystemChat",
		type = typ,
		key = key,
		args = table.pack(...),
	}
	WorldServer.BroadcastPacket(packet)
end

function WorldServer.SystemNotice(typ, key, time, ...)
	local packet = {
		pid = "ShowTip",
        tipType = typ,
		textKey = key,
        keepTime = time,
        textArgs = {...},
	}
	WorldServer.BroadcastPacket(packet)
end

function WorldServer.SystemPlaySoundProgressBar(time)
	local packet = {
		pid = "ShowPlaySoundProgressBar",
		time = time
	}
	WorldServer.BroadcastPacket(packet)
end

function WorldServer:load()
	self:initMap()
	if self.cfg.enableCollsion then 
		self:setEnableCollision(self.cfg.enableCollsion)
	end
end
