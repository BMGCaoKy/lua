
local misc = require("misc")

ATProxy.myServerId = ATProxy.myServerId

function ATProxy:sendToServer(id, data)
	assert(id ~= ATProxy.myServerId)
	data = Packet.Encode(data)
	local ret = self:sendMsg(id, misc.data_encode(data))
	if ret<0 then
		print("ATProxyCli::SendMsg error:", id, ret);
	end
end

function ATProxy:broadcastToServer(data)
	if World.CurWorld:getServerType()~="gamecenter" and not ATProxy.mainGameCenter then
		return
	end
	data = Packet.Encode(data)
	self:broadcastMsg(World.GameName .. "_gameserver", misc.data_encode(data))
end

local function init()
	local cfg = Server.customizeConfig
	if not cfg.atproxyaddr then
		return
	end
	local atproxy = ATProxy.Instance()
	local ret = atproxy:start(cfg.atproxyid or 0, cfg.atproxyaddr, World.GameName .. "_" .. World.serverType,
		cfg.atproxylog or 2, cfg.atproxylisten or {})
	print("connnect ATProxy:", cfg.atproxyaddr, ret)
	if ret>0 then
		ATProxy.myServerId = ret
	end
	if World.CurWorld:getServerType()=="gamecenter" then
		require("atproxy.atproxy_center")
	else
		require("atproxy.atproxy_server")
	end
end

init()
