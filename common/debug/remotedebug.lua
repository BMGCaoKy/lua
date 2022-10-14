local lfs = require("lfs")
local misc = require("misc")
local cjson = require("cjson")
local ts = require("telnetserver")
local handles = require("common.debug.daphandle")
local myhandles = require("common.debug.dapmyhandle")

local M = L("M", {})
local curClient = L("curClient")
local clientMT = T(M, "clientMT")
clientMT.__index = clientMT

local coroutine_resume = L("coroutine_resume", coroutine.resume)

function clientMT:_sendBuf()
	local bufList = self.sendBuf
	local buf = bufList[1]
	while buf do
		local ok, sl = ts.sendto(self.sock, buf)
		if ok then
			table.remove(bufList, 1)
			buf = bufList[1]
		elseif sl<0 then
			self:log("send error2:", sl)
			self:close()
			return
		else
			bufList[1] = buf:sub(sl+1)
			return
		end
	end
	self.sendBuf = nil
end

function clientMT:tick()
	self.endlessCount = 0
	if self.sendBuf then
		self:_sendBuf()
		if not self.sock then
			return
		end
	end
	if self.transferFrom then
		while self.transferFrom and self:docmd() do end
		return
	end
	local buff = ts.recvfrom(self.sock)
	if buff==nil then
		return
	end
	while buff do
		self.buff = self.buff .. buff
		buff = ts.recvfrom(self.sock)
	end
	while self.sock and self:docmd() do end
	if buff==false then
		self:log("connection lost")
		self:close()
	end
end

function clientMT:readdata()
	local reqs = self.transferReqs
	if reqs then
		local data = reqs[reqs.i]
		if data then
			reqs.i = reqs.i + 1
			return data
		elseif reqs.i>1 then
			self.transferReqs = {i=1}
		end
		return nil
	end
	local buff = self.buff
	if self.recvbody then
		local recvlen = self.recvlen
		if #buff<recvlen then
			return nil
		end
		local text = buff:sub(1, recvlen)
		local data = cjson.decode(text)
		self.buff = buff:sub(recvlen + 1)
		self.recvbody = false
		self.recvlen = nil
		--self:log("recv:", text)
		return data
	end

	local index = buff:find("\r\n")
	if not index then
		return nil
	end
	local line = buff:sub(1, index - 1)
	self.buff = buff:sub(index + 2)
	if line=="" then
		assert(self.recvlen)
		self.recvbody = true
		return self:readdata()
	end
	index = assert(line:find(":"), line)
	local key = line:sub(1, index - 1)
	local value = line:sub(index + 1)
	if key=="Content-Length" then
		self.recvlen = math.tointeger(value)
	else
		error(key)
	end
	return self:readdata()
end

function clientMT:senddata(res)
	if self.transferFrom then
		self:transferResponse("msg", res)
		return
	end
	if not self.sock then
		self:log("send data to closed socket", cjson.encode(res))
		return
	end
	local text = cjson.encode(res)
	--self:log("send:", text)
	text = string.format("Content-Length: %d\r\n\r\n%s", #text, text)
	if self.sendBuf then
		self.sendBuf[#self.sendBuf+1] = text
		return
	end
	local ok, sl = ts.sendto(self.sock, text)
	if ok then
		return
	end
	if sl<0 then
		self:log("send error1:", sl)
		self:close()
	else
		self.sendBuf = {text:sub(sl+1)}
	end
end

function clientMT:docmd()
	local req = self:readdata()
	if not req then
		return false
	end
	if self.transferTo then
		self:transferRequest("msg", req)
		return true
	end
	local func = assert(handles[req.command] or myhandles[req.command], req.command)
	local ok, ret = xpcall(func, traceback, self, req)
	if not ok then
		perror(ret)
		self:responseError(req, ret)
	elseif ret==false then
		self:responseError(req, nil)
	elseif ret==true then
		self:response(req, nil)
	elseif type(ret)=="string" then
		self:responseError(req, ret)
	elseif ret then
		self:response(req, ret)
	end
	return true
end

function clientMT:response(req, body, err)
	self:senddata {
		type = "response",
		command = req.command,
		request_seq = req.seq,
		success = not err,
		body = body,
	}
end

function clientMT:responseError(req, msg)
	if not msg then
		self:response(req, {error={id=1,format="error!"}}, true)
		return
	end
	local errMsg = {
		id = 2,
		format = "{msg}",
		variables = {msg=msg},
		showUser = true,
	}
	self:response(req, {error=errMsg}, true)
end

function clientMT:sendevent(event, body)
	self:senddata {
		type = "event",
		event = event,
		body = body,
	}
end

function clientMT:dostop(hookLevel, reason, description, text)
	self:sethook()
	assert(not self.stopThread)
	self:sendevent ("stopped", {
		reason = reason,
		description = description,
		text = text,
		threadId = 1,
		allThreadsStopped = true,
		preserveFocusHint = false,
	})
	self:log("stopped", reason)
	self.varsI2V = {}
	self.varsV2I = {}
	self.stopThread = coroutine.running()
	self.hookLevel = hookLevel
	local dbgThread = coroutine.create(function()
		while self.stopThread do
			self:tick()
			misc.sleep(0)
		end
	end)
	local ok, msg = coroutine_resume(dbgThread)
	if not ok then
		print(traceback(dbgThread, msg))
	end
	self.varsI2V = nil
	self.varsV2I = nil
	self.stopThread = nil
	self.hookLevel = nil
	self.excMsg = nil
	if self.sock or self.transferFrom then
		self:updateHook(hookLevel)
	end
end

function clientMT:close()
	if self.transferTo then
		self:transferRequest("stop")
		self.transferTo = nil
	end
	assert(self.sock or self.transferFrom)
	assert(curClient == self)
	if self.sock then
		ts.close(self.sock)
	end
	self:sethook()
	curClient = nil
	self.sock = nil
	self.transferFrom = nil
	self.stopThread = false
end

function clientMT:var(value)
	local i = self.varsV2I[value]
	if not i then
		i = #self.varsI2V + 1
		self.varsI2V[i] = value
		self.varsV2I[value] = i
	end
	return i
end

function clientMT:getPathInfo(lpath)
	local info = self.pathInfo[lpath]
	if info then
		return info
	end
	local luaPath, sysPath, name
	if lpath:sub(1,1)~="@" or lpath:sub(2,2)=="(" then
		name = lpath
	else
		luaPath = lpath:sub(2):gsub("\\", "/"):gsub("//", "/")
		name = luaPath
		local ml = 0	-- 客户端目录嵌套的情况下，匹配最长的
		for lua, sys in pairs(self.pathConvert) do
			if #lua>ml and luaPath:sub(1, #lua):lower()==lua:lower() then
				ml = #lua
				name = luaPath:sub(ml + 1)
				sysPath = sys .. name
				if name:sub(1,4)=="lua/" then
					name = name:sub(5)
				end
				break
			end
		end
	end
	info = {
		lua = luaPath,
		sys = sysPath,
		name = name,
	}
	self.pathInfo[lpath] = info
	return info
end

function clientMT:log(...)
	print("[RemoteDebug]", self.sock or self.transferFrom, ...)
end

local function hookFunc(event, line)
	if not curClient then
		return
	end
	local stepHookType = curClient.stepHookType
	local stepHookLevel = curClient.stepHookLevel
	if event=="line" then
		if stepHookType=="in" or (stepHookType and stepHookLevel<=0) then
			curClient:dostop(4, "step")
		elseif (curClient.watchLine or {})[line] then
			curClient:dostop(4, "breakpoint")
		elseif curClient.endlessCheck then
			local endlessCount =  curClient.endlessCount + 1
			curClient.endlessCount = endlessCount
			if endlessCount==1000*1000 then
				curClient.excMsg = "endless?!"
				curClient:dostop(4, "exception")
			elseif endlessCount%1000 == 0 then
				curClient:tick()
			end
		end
	elseif event=="return" then
		if stepHookLevel then
			curClient.stepHookLevel = stepHookLevel - 1
		end
		curClient:updateHook(4)
	else
		if stepHookLevel then
			curClient.stepHookLevel = stepHookLevel + 1
		end
		curClient:updateHook(3)
	end
end

local function getWatchLines(self, info)
	if not info or not info.source then
		return nil
	end
	local bps = self.breakpoints[self:getPathInfo(info.source).lua]
	if not bps then
		return nil
	end
	local watchLine = nil
	local min = info.linedefined
	local max = info.lastlinedefined
	if max==0 then
		max = math.huge
	end
	for _, line in ipairs(bps) do
		if line<=max and line>=min then
			if not watchLine then
				watchLine = {}
			end
			watchLine[line] = true
		end
	end
	return watchLine
end

function clientMT:updateHook(level)
	assert(not self.stopThread)
	local stepHookType = self.stepHookType
	if next(self.breakpoints) then
		local info = debug.getinfo(level or 0, "S")
		local watchLine = getWatchLines(self, info)
		self.watchLine = watchLine
		if watchLine or stepHookType=="in" or self.endlessCheck or (stepHookType and self.stepHookLevel<=0) then
			self:sethook("crl")
		else
			self:sethook("cr")
		end
	elseif not stepHookType then
		self:sethook(self.endlessCheck and "l" or nil)
	elseif stepHookType=="in" then
		self:sethook("l")
	elseif self.stepHookLevel<=0 then
		self:sethook("crl")
	else
		self:sethook("cr")
	end
end

function clientMT:sethook(mode)
	if mode==self.hookMode then
		return
	end
	curClient = nil	-- 临时阻止	hookFunc
	self.hookMode = mode
	if mode then
		debug.sethook(hookFunc, mode)
	else
		debug.sethook()
	end
	curClient = self
end

function clientMT:beginTransfer(req)
	assert(not self.transferTo)
	local player
	if World.isClient then
		player = Me
	else
		player = World.CurWorld:getEntity(req.arguments.id)
		if not player or not player.isPlayer then
			self:responseError(req, "找不到目标")
			return
		end
	end
	self.transferTo = player
	self:transferRequest("start", req)
end

function clientMT:stopTransfer(req)
	assert(self.transferFrom)
	self:transferResponse("stop", {
		type = "response",
		command = req.command,
		request_seq = req.seq,
		success = true,
	})
	self:close()
end

function clientMT:transferRequest(typ, req)
	local player = assert(self.transferTo)
	if player:isValid() then
		player:sendPacket {
			pid = "DebugTransferRequest",
			typ = typ,
			req = req,
		}
	elseif req then
		self:responseError(req, "目标已失效")
	end
end

function clientMT:transferResponse(typ, res, req)
	local player = assert(self.transferFrom)
	if player:isValid() then
		player:sendPacket {
			pid = "DebugTransferResponse",
			typ = typ,
			res = res,
		}
	else
		self:log("send data to invalid player", cjson.encode(res))
	end
end



function coroutine.resume(co, ...)
	if not curClient then
		return coroutine_resume(co, ...)
	end
	if curClient.hookMode then
		debug.sethook()
		debug.sethook(co, hookFunc, curClient.hookMode)
	end
	local pack = table.pack(coroutine_resume(co, ...))
	if curClient and curClient.hookMode then
		debug.sethook(hookFunc, curClient.hookMode)
	end
	return table.unpack(pack, 1, pack.n)
end

on_error_reg("RemoteDebug", function (typ, msg)
	if curClient and not curClient.stopThread and curClient.excMap[typ] then
		curClient.excMsg = msg
		curClient:dostop(4, "exception")
	end
end)

local function addSock(sock, addr)
	if sock then
		ts.noblock(sock, true)
	end
	local client = {
		sock = sock,
		addr = addr,
		buff = "",
		breakpoints = {},
		pathInfo = {},
		sourceIds = {},
		sourcePaths = {},
		excMap = {},
	}
	curClient = setmetatable(client, clientMT)
	client:log("connected", addr)
end

function M.Tick()
	if curClient and (curClient.sock or curClient.transferFrom) then
		curClient:tick()
	elseif M.listen then
		local sock, addr = ts.accept(M.listen)
		if sock then
			addSock(sock, addr)
		end
	end
end

function M.Start(port)
	if M.listen then
		return M.port
	end
	local listen = ts.create()
	M.port = listen and ts.listen(listen, "0.0.0.0", port or 0)
	if M.port then
		print("[RemoteDebug] start listen:", M.port)
		ts.noblock(listen, true)
		M.listen = listen
		return M.port
	else
		print("[RemoteDebug] start failed!", listen)
		if listen then
			ts.close(listen)
		end
		return false
	end
end

function M.Connect(port)
	local sock = ts.connect("127.0.0.1", port)
	print("[RemoteDebug] Connect :", port, sock)
	if not sock then
		return
	end
	addSock(sock, "127.0.0.1:"..port)
	local endTime = misc.now_microseconds() + 1000000
	while curClient and curClient.sock and misc.now_microseconds()<endTime do
		curClient:tick()
		misc.sleep(1)
	end
end

function M.Stop()
	if M.listen then
		ts.close(M.listen)
		M.listen = nil
		M.port = nil
		if curClient then
			curClient:close()
		end
	end
end

local function getTransferAddr(player)
	return World.isClient and CGame.instance:getServerAddr() or player.clientAddr
end

function M.TransferRequest(pack, player)
	if pack.typ=="msg" then
		assert(curClient.transferFrom == player)
		local reqs = curClient.transferReqs
		reqs[#reqs + 1] = pack.req
		return
	elseif pack.typ=="stop" then	-- 由于上级强制断开，结束调试、通知下级
		assert(curClient.transferFrom == player)
		curClient:close()
		return
	end
	assert(pack.typ=="start")
	local ok, msg
	if curClient then
		ok = false
		msg = "目标正在被调试"
	elseif not World.isClient and not World.gameCfg.gm then
		ok = false
		msg = "没有调试权限（需要开启服务器GM）"
	else
		addSock(nil, getTransferAddr(player))
		curClient.transferFrom = player
		curClient.transferReqs = {i=1}
		ok = true
		local data = misc.sys_info()
		msg = string.format("%s<%s,%s> %s - %s", data.name, World.GameName, EngineVersionSetting.getEngineVersion(),
			World.isClient and "client" or "server", data.device or data.sys)
	end
	player:sendPacket {
		pid = "DebugTransferResponse",
		typ = "start",
		req = pack.req,
		ok = ok,
		msg = msg,
	}
end

function M.TransferResponse(pack, player)
	assert(curClient.transferTo == player)
	if pack.typ=="stop" then	-- 下级断开后通知回来
		curClient.transferTo = nil
		curClient:senddata(pack.res);
		return
	elseif pack.typ=="msg" then
		curClient:senddata(pack.res);
		return
	end
	assert(pack.typ=="start")
	if pack.ok then
		curClient:response(pack.req, {
			addr = getTransferAddr(player),
			text = pack.msg,
			client = not World.isClient,
		})
	else
		curClient.transferTo = nil
		curClient:responseError(pack.req, pack.msg)
	end
end


RETURN(M)
