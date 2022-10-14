handle_call = false
handle_tick = false

clients = {}
C = {}
playerCount = 0

Root = {
}
function Root.Instance()
	return Root
end
function Root:getGamePath()
	return ""
end

IS_TESTCLIENT = true
require "common.preload"
require "common.data_cache_container"
require "common.lib"
require "common.math.math"
require "common.packet_convert"

local misc = require "misc"
local client = require "client"
local cjson = require "cjson"

local waitCos = {}

local nowTime = 0

local tokens = {}
local engineVersion = (Lib.read_json_file("Media/engineVersion.json")).engineVersion

local clientIndex = {}
local clientMeta = { __index = clientIndex }

local function run(co, ...)
    local ok, msg = coroutine.resume(co, ...)
    if not ok then
        print("ERROR!", traceback(co, msg))
    end
end

local function sleep(time)
	local co, main = coroutine.running()
    assert(not main)
    time = math.floor(time)
    if time<1 then
        time = 1
    end
    time = nowTime + time
    local tb = waitCos[time]
    if not tb then
        tb = {}
        waitCos[time] = tb
    end
    tb[#tb+1] = co
    coroutine.yield()
end

--随机获取数组中的n个元素
local function randomArray(array, n)
    local arr = {}
    for _, _ in pairs(array) do
        table.insert(arr, #arr + 1)
    end
    math.randomseed(tostring(os.time()):reverse():sub(1, 7))
    local result = {}
    for i = 1, n do
        local temp = math.random(#arr)
        table.insert(result, array[temp])
        table.remove(arr, temp)
    end
    return result
end

local handlers = {}

function handle_call(funcName, ...)
	local _, main = coroutine.running()
    assert(main, "in coroutine!")
    local func = assert(handlers[funcName], funcName)
    local co = coroutine.create(func)
    run(co, ...)
end

local function allPing()
    if not next(clients) then
        return
    end

    local now = misc.now_microseconds()
    local packet = {
        pid = "ping",
        lastTime = now,
        time = now,
        ping = {0, 0},
        logicPing = 0
    }
    for _, client in pairs(clients) do
        client:sendPacket(packet)
    end
end

local lastPingTime = 0
function handle_tick(frameTime)
    nowTime = nowTime + 1

    if frameTime - lastPingTime > 60 * 1000 then
        allPing()
        lastPingTime = frameTime
    end

    local cos = waitCos[nowTime]
    if not cos then
        return
    end
    waitCos[nowTime] = nil
    for _, co in ipairs(cos) do
        run(co)
    end
end

function handlers.event(id, event)
    --print("client_event", id, event)
    local cl = clients[id]
    if event=="ConnectSuc" then
        cl:doLogin()
    elseif event == "nextAutoMove" then
        cl.nextAutoMoveFunc()
    else
        cl:close()
    end
end

function handlers.packet(id, name, packet)
    local cl = assert(clients[id], id)
    local func = cl[name]
    if func then
        func(cl, packet)
	else
		--print("unknown packet", id, name)
    end
end

function handlers.cmd(cmd)
    assert(load(cmd, "@(cmd)"))()
end

function handlers.start()
	--print("strat!!")
end

function clientIndex:sendPacket(packet)
    packet = Packet.Encode(packet)
	local data = misc.data_encode(packet)
    self.c:sendScriptPacket(data)
end

function clientIndex:S2CPacketScriptPacket(packet)
	packet = misc.data_decode(packet.data)
    packet = Packet.Decode(packet)
    ----print("S2CPacketScriptPacket", self.id, packet.pid)
    local func = self[packet.pid]
    if func then
        func(self, packet)
    end
end

function clientIndex:startHandUpMove(packet)
    local navigationPos = packet.navigationPos
    local randomPos = navigationPos[math.random(1,#navigationPos)]
    self.autoMoveFunc = function() 
        self.c:autoMove(packet.mapName,randomPos.x,randomPos.y,randomPos.z)
    end

    self.nextAutoMoveFunc = function()
        local nextPos = navigationPos[math.random(1,#navigationPos)]
        self.c:autoMove(packet.mapName,nextPos.x,nextPos.y,nextPos.z)
    end

    if self.curMap == packet.mapName then 
        self.autoMoveFunc()
        self.autoMoveFunc = nil
        return
    end

    self:sendPacket({
        pid = "OnJumpMap",
        mapName = packet.mapName,
    })
    
end

function clientIndex:ChangeMap(packet)
    self.curMap = packet.name
    self.curPos = Lib.tov3(packet.pos)
    self.c:setCurPos(self.curPos.x, self.curPos.y, self.curPos.z)
    if self.autoMoveFunc then 
        self.autoMoveFunc()
        self.autoMoveFunc = nil
    end
end

function clientIndex:EntitySpawn(packet)
    self.curPos =  Lib.tov3(packet.pos)
    self.c:setCurPos(self.curPos.x, self.curPos.y, self.curPos.z)
end

function clientIndex:GameInfo(packet)
    print("GameInfo", self.id, packet.objID, packet.pid)
    playerCount = playerCount + 1
    self.pos = Lib.tov3(packet.pos)
    self.objID = packet.objID
    self.curMap = packet.map
    self:sendPacket({pid="ClientReady"})
end
function clientIndex:doLogin()
    local id = self.id
    local tk = tokens[id] or {name="test0" .. id,userId=(id+100)*16+2, token="auto"}
    local clientInfo = {
        device = "blockman", user_id = tostring(tk.userId),
        os_version = "android 4.4.4",
        manufacturer = "sandbox", platform = "android",
        android_id = tostring(os.time())..tostring(tk.userId),
        session_num = 1,
        version_code = "1",
        package_name = "com.sandboxol.blockymods",
    }
    self.c:sendLogin(tk.name, 123456789, tk.userId, tk.token, "zh_CN", cjson.encode(clientInfo), engineVersion)
end
function clientIndex:S2CPacketCheckCSVersionResult(packet)
    --print("S2CPacketCheckCSVersionResult", self.id, packet.m_success, packet.m_serverVersion)
    if not packet.m_success then
        return
    end
    self:doLogin()
end
function clientIndex:S2CPacketLoginResult(packet)
    --print("S2CPacketLoginResult", self.id, packet.m_resultCode)
end
function clientIndex:S2CPacketEntityMovement(packet)
    --print("S2CPacketEntityMovement", self.id, packet.m_entityId, packet.m_x, packet.m_y, packet.m_z)
end
function clientIndex:S2CPacketPlayerCtrlVer(packet)
    --print("S2CPacketPlayerCtrlVer", packet.m_ctrlVer)
	self.ctrlVer = packet.m_ctrlVer
    self.c:setCtrl(self.ctrlVer)
end

local function toPos(client, pos, run)
    client.pos.x = pos.x
    client.pos.y = pos.y
    client.pos.z = pos.z
    client.c:sendMovement(pos.x, pos.y, pos.z, 0, 0, 0, true, run, client.ctrlVer)
end

function clientIndex:close()
    print("CloseClient", self.id)
    clients[self.id] = nil
    self.c:close()
	self.id = nil
end

function C:cc(count, serverIp,portId)
    count = count or 1
	serverIp = serverIp or "127.0.0.1"
	portId = portId or 19130
    local index = 0
    while index < count do
        local c = client.create()
        local id = c:id()
        clients[id] = setmetatable({c=c,id=id}, clientMeta)
        if not c:connect(serverIp, portId) then
			print("connect failed!", serverIp, portId)
			c:close()
		end

        index = index + 1
        sleep(200)
    end
end

--随机移动一次，到达目的地停止
function C:move(cls)
    local temp = {}
    for _, c in pairs(cls or clients) do
        if c.pos then
            table.insert(temp, c)
        end
    end
    math.randomseed(tostring(os.time()):reverse():sub(1, 7))
    for _, client in ipairs(temp) do
        local x = math.random(3)
        local z = math.random(3)
        local ax = math.random(6)
        local az = math.random(6)
        local pos = Lib.copy(client.pos)
        pos.x = pos.x + (ax > 3 and x or (-x))
        pos.z = pos.z + (az > 3 and z or (-z))
        client.targetPos = pos
        client.finish = false
    end
    local run = true
    while run do
        for index, client in ipairs(temp) do
            if not client.finish then
                local dir = client.targetPos - client.pos
                local len = dir:len()
                if len < 0.5 then
                    client.finish = true
                    toPos(client, client.targetPos, false)
                else
                    local targetPos = client.pos + dir * (0.125/len)
                    toPos(client, targetPos, true)
                end
            else
                local finishCount = 0
                for _, client in ipairs(temp) do
                    if client.finish then
                        finishCount = finishCount + 1
                    end
                end
                if finishCount == #temp then
                    run = false
                end
            end
        end
        sleep(50)
    end
end

-- 移动n名玩家到pos
-- pos: {x, y, z}
function C:moveTo(n, pos, ...)
    local groups = {}
    table.insert(groups, {n, Lib.v3(table.unpack(pos))})
    local additional = {...}
    while true do
        local pos = table.remove(additional)
        local n = table.remove(additional)
        if not pos or not n then
            break
        end
        table.insert(groups, {n, Lib.v3(table.unpack(pos))})
    end

    local ids = {}
    for id in pairs(clients) do
        table.insert(ids, id)
    end

    for _, tb in ipairs(groups) do
        local n, pos = table.unpack(tb)
        for i = 1, n do
            local id = table.remove(ids)
            if not id then
                print("C:moveTo: not enough robots")
                return
            end
            local robot = clients[id]
            toPos(robot, pos, true)
        end
        print(string.format("C:moveTo, done: %d -> (%s, %s, %s)", n, pos.x, pos.y, pos.z))
    end
end

--若干玩家随机移动N次（times:移动次数，必填；pCount:多少玩家移动，若不填则随机；time时间间隔，默认1秒）
function C:randMove(times, pCount, time)
    if pCount and pCount > playerCount then
        pCount = playerCount
    end
    math.randomseed(tostring(os.time()):reverse():sub(1, 7))
    local count = 0
    while count < (times or 1) do
        local num = pCount or math.random(playerCount)
        local result = randomArray(clients, num)
        self:move(result)
        count = count + 1
        sleep(1000)
    end
end

-- 随机移动N步
function C:stepMove(steps, interval)
    steps = steps or 1
	interval = interval or 100
    for i = 1, steps do
		for _, c in pairs(clients) do
			local pos = c.pos
			if pos then
				pos = {
					x = pos.x + math.random() * 0.6 - 0.3,
					y = pos.y,
					z = pos.z + math.random() * 0.6 - 0.3,
				}
				toPos(c, pos, i<steps)
			end
		end
	end
end

--全体释放技能N次，默认4秒一次（单位秒）
function C:skill(times, time, name)
    time = time and (time * 1000) or 4000
    local packet = {
        pid = "CastSkill",
        name = name or "myplugin/player_skill_shizizhan",
    }
    local count = 0
    while count < (times or 1) do
        for _, client in pairs(clients) do
            if client.objID and client.pos then
                local pos = client.pos
                packet.startPos = pos
                packet.targetPos = {x = pos.x + 1, y = pos.y, z = pos.z}
                packet.fromID = client.objID
                client:sendPacket(packet)
            end
        end
        count = count + 1
        sleep(time)
    end
end

--若干玩家释放技能N次（times:释放次数，必填；playerCount:多少个玩家，若不填则随机；time时间间隔，默认4秒）
function C:randSkill(times, pCount, time, name)
    time = time and (time * 1000) or 4000
    if pCount and pCount > playerCount then
        pCount = playerCount
    end
    math.randomseed(tostring(os.time()):reverse():sub(1, 7))
    local packet = {
        pid = "CastSkill",
        name = name or "myplugin/player_skill_shizizhan",
    }
    local count = 0
    while count < (times or 1) do
        local num = pCount or math.random(playerCount)
        local result = randomArray(clients, num)
        for _, client in pairs(result) do
            local pos = client.pos
            packet.startPos = pos
            packet.targetPos = {x = pos.x + 1, y = pos.y, z = pos.z}
            packet.fromID = client.objID
            client:sendPacket(packet)
        end
        count = count + 1
        sleep(time)
    end
end

function C:customTest(times, pCount, time, name, gamePath, ...)
    time = time and (time * 1000) or 4000
    if pCount and pCount > playerCount then
        pCount = playerCount
    end
    math.randomseed(tostring(os.time()):reverse():sub(1, 7))

    local path,chuck = loadLua(name, gamePath .. "lua/script_client/?.lua")

    local m = {}
    local tbEnv = setmetatable({M = m}, {__index = _G})
    local ret, errorMsg = load(chuck, "@"..path, "bt", tbEnv)
    local func = ret()

    local count = 0
    while count < (times or 1) do
        local num = pCount or math.random(playerCount)
        local result = randomArray(clients, num)
        for _, client in pairs(result) do
            func(client)
        end
        count = count + 1
        sleep(time)
    end
end