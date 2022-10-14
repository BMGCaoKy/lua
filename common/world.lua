local lfs = require "lfs"
local setting = require "common.setting"

---@class World
---@field CurWorld World | WorldServer
---@field getEntity fun(self : World, id : number) : Entity
---@field getAllObject fun(self : World) : Entity[]
local World = World

local gameTick = World.CurWorld:getTickCount()
local timerCalls = L("timerCalls", {})

local packetCount = L("packetCount", {send={}, recv={}})

local init = nil

World.cfg = setting:loadDir("")

function World.Now()
    return gameTick 
end

function World.getTimerCalls()
	return timerCalls
end

local function _doreg(time, call)
	if time<1 then
		time = 1
	else
		if type(time) == "number" then time = time // 1 end
		time = math.tointeger(time)
	end
	call.time = time
	local endTime = gameTick + time
	local calls = timerCalls[endTime]
	if not calls then
		calls = {}
		timerCalls[endTime] = calls
	end
	calls[#calls+1] = call
end

function World.ObjectTimer(time, func, obj, ...)
    local call = {
		func = func,
		args = table.pack(...),
		obj = obj,
		func_name = Lib.getCallTag()
	}
	_doreg(time, call)
	return function(nTime)
		if not nTime then 
			call.func = nil
		else
			call.time = nTime
			return call.time
		end
	end
end

function World.LightTimer(stack, time, func, ...)
    local call = {
		func = func,
		args = table.pack(...),
		func_name = Lib.getCallTag()
	}
	_doreg(time, call)
	return function()
		call.func = nil
	end
end

function World.Timer(time, func, ...)
	local call = {
		func = func,
		args = table.pack(...),
		func_name = Lib.getCallTag()
	}
	_doreg(time, call)
	return function()
		call.func = nil
	end
end

local function _docall(call)
	if not call.func then
		return
	end
	Profiler:begin("CallTimer_" .. call.func_name)
	CPUTimer.StartForLua("docall"..call.func_name)
	local ok, ret = xpcall(call.func, traceback, table.unpack(call.args, 1, call.args.n))
	Profiler:finish("CallTimer_" .. call.func_name)
	CPUTimer.Stop()
	if not ok then
		perror("Error call timer:", ret)
		Lib.sendErrMsgToChat(call.obj, ret)
		return
	end
	if ret==true then
		_doreg(call.time, call)
	elseif type(ret)=="number" then
		_doreg(ret, call)
	end
end

function World.Tick()
	Profiler:begin("World.Tick")
	gameTick = gameTick + 1
	local calls = timerCalls[gameTick]
	if calls then
		timerCalls[gameTick] = nil
		for _, call in ipairs(calls) do
			_docall(call)
		end
	end
	Profiler:finish("World.Tick")
end

function World.AddPacketCount(pid, size, send, count)
	if not World.CurWorld.packetCountEnable then
		return
	end
	count = count or 1
	local list = send and packetCount.send or packetCount.recv
	local info = list[pid]
	if info then
		info.count = info.count + count
		info.size = info.size + size * count
		if size<info.min then
			info.min = size
		elseif size>info.max then
			info.max = size
		end
	else
		list[pid] = {
			count = count,
			size = size * count,
			min = size,
			max = size,
		}
	end
end

function World.ClearPacketCount()
	World.CurWorld:clearPacketCount()
	packetCount.send = {}
	packetCount.recv = {}
end

function World.EnablePacketCount(enable)
	Lib.logInfo("EnablePacketCount", enable)
	World.CurWorld.packetCountEnable = enable
	World.ClearPacketCount()
end

local function printPackCount(cl, m, ll)
	Lib.logInfo("Count\t", "TotSize\t", "MinSize\t", "MaxSize\t", "Pid")
	for	i = 1, 100 do
		local info = cl[i*m]
		if info then
			Lib.logInfo(info.count, "\t", info.size, "\t", info.min, "\t", info.max, "\tC:"..i)
		end
	end
	for pid, info in pairs(ll) do
		Lib.logInfo(info.count, "\t", info.size, "\t", info.min, "\t", info.max, "\t", pid)
	end
end

function World.ShowPacketCount()
	local clist = World.CurWorld:getPacketCount()
	Lib.logInfo("----------- <<send>> ----------- ")
	printPackCount(clist, 1, packetCount.send)
	Lib.logInfo()
	Lib.logInfo("-----------  <<recv>> ----------- ")
	printPackCount(clist, -1, packetCount.recv)
	Lib.logInfo()

	return packetCount
end

function World.Reload()
	init()

	if World.isClient then
		WorldClient.Reload()
	end
	if World.isClient then 
		Blockman.instance:reloadfirstPRVAnimationMap()
	end

	if World.isClient then
		World:reloadMap(World.CurMap)
	end
end

local ontime_default = 1200
local GAME_LOGIC_FPS = 20
local DAYSECONDS = 24 * 3600
function World.getSimulateTime()
	local now = World.CurWorld:getWorldTime()
	local speed = World.CurWorld:getWorldTimeSpeed()
	local seconds = (now / speed / GAME_LOGIC_FPS) * (DAYSECONDS * speed / ontime_default)
	return seconds
end

function World.cfg:onReload()
	local world = World.CurWorld
	local cfg = self

	if cfg.disableGetMouseOver then
		world.disableGetMouseOver = true
	end
	if cfg.enablePhysicsSimulation ~= nil then
		world.enablePhysicsSimulation = cfg.enablePhysicsSimulation
	end
	if cfg.disableDrawSelectionBox ~= nil then
		world.disableDrawSelectionBox = cfg.disableDrawSelectionBox
	end
	if cfg.enableMapEvent ~= nil then
		world.enableMapEvent = cfg.enableMapEvent
	end
	if cfg.disableCameraCollision ~= nil then
		world.disableCameraCollision = cfg.disableCameraCollision
	end
	if cfg.enableReconnectNetwork ~= nil then
		world.enableReconnectNetwork = cfg.enableReconnectNetwork
	end
	if cfg.disableStaticEntityTick ~= nil then
		world.disableStaticEntityTick = cfg.disableStaticEntityTick
	end
	if cfg.enableBatchSceneStatic ~= nil then
		world.enableBatchSceneStatic = cfg.enableBatchSceneStatic
	end

	world:setTimeStopped(cfg.isTimeStopped)
	world:setWorldTime(cfg.nowTime)
	local oneDayTime = cfg.oneDayTime or ontime_default
	if oneDayTime <= 1 then
		oneDayTime = 1
	elseif oneDayTime >= ontime_default then
		oneDayTime = ontime_default
	end
	oneDayTime = ontime_default / oneDayTime
	world:setWorldTimeSpeed(oneDayTime)

	if cfg.worldTimeSpeed then
		world:setWorldTimeSpeed(cfg.worldTimeSpeed)
	end

	if cfg.worldDisableShadow then
		world:setWorldDisableShadow(cfg.worldDisableShadow)
	end
end

function init()	-- local
	World.gameCfg = Lib.read_json_file("gameconfig.json") or {}

	World.guideCfg = Lib.readGameCsv("guide.csv") or {}

end

init()
World.cfg:onReload()

-- Initialize fast table after initialization is finished.
World.Timer(2, initializeFastTable)

RETURN()
