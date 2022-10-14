local socket = require('socket.core')
local VERSION = require('autotest.poco.POCO_SDK_VERSION')
local Dumper = require('autotest.poco.bm_frozen_dumper')
local Screen = require('autotest.poco.bm_screen')
local ClientConnection = require('autotest.poco.client_connection')

local LuaTimer = T(Lib, "LuaTimer") ---@type LuaTimer

-- poco
local PocoManager = {}
PocoManager.__index = PocoManager

PocoManager.DEBUG = true
PocoManager.VERSION = VERSION

PocoManager.server_sock = nil
PocoManager.all_socks = {}
PocoManager.clients = {}

-- rpc methods registration
-- rpc 方法统一才是Pascal命名方式，其实是为了跟unity3d里使用的poco-sdk命名相同
local dispatcher = {
    GetSDKVersion = function() return VERSION end,
    Dump = function(onlyVisibleNode) 
        if onlyVisibleNode == nil then
            onlyVisibleNode = true
        end
        return Dumper:dumpHierarchy(onlyVisibleNode)
    end,
    Screenshot = function(width)
        width = width or 720
        return Screen:getScreen(width) 
    end,
    GetScreenSize = function() return Screen:getPortSize() end,
    SetText = function(_instanceId, val)
        local node = Dumper:getCachedNode(_instanceId)
        if node ~= nil then
            return node:setAttr('text', val)
        end
        return false
    end,
    test = function(arg1, arg2) 
        return string.format('test arg1:%s arg2:%s', arg1, arg2) 
    end,
    -- Click = function(x, y)
    -- end,
    -- Swipe = function(x1, y1, x2, y2, duration)
    -- end,
    -- LongClick = function(x, y, duration)
    -- end,
    CallAT = function (method, ...)
        return AT.ServePoco(method, ...)
    end,
}

function PocoManager:init_server(port)
    if self.server_sock then
        return
    end

    port = port or 15004
    local server_sock, err = socket.tcp()
    assert(server_sock)
    table.insert(self.all_socks, server_sock)
    self.server_sock = server_sock
    server_sock:setoption('reuseaddr', true)
    server_sock:setoption('keepalive', true)
    server_sock:settimeout(0.0)
    -- server_sock:bind('*', port)
    server_sock:bind('127.0.0.1', port)
    server_sock:listen(5)
    Lib.logInfo(string.format('[poco] server listens on tcp://*:%s', port))

    -- 放在定时器里循环
    -- cc.Director:getInstance():getScheduler():scheduleScriptFunc(function() self:server_loop() end, 0.025, false)
    LuaTimer:scheduleTimer(function () self:server_loop() end, 0.025)
end

function PocoManager:stop_server()
    for _, s in pairs(self.all_socks) do
        s:close()
    end
    self.server_sock = nil
    self.all_socks = {}
    self.clients = {}
end

function PocoManager:server_loop()
    for _, c in pairs(self.clients) do
        c:drainOutputBuffer()
    end

    local r, w, e = socket.select(self.all_socks, nil, 0)
    if #r > 0 then
        local removed_socks = {}

        for i, v in ipairs(r) do
            if v == self.server_sock then
                local client_sock, err = self.server_sock:accept()
                print('[poco] new client accepted', client_sock:getpeername(), err)
                table.insert(self.all_socks, client_sock)
                self.clients[client_sock] = ClientConnection:new(client_sock, self.DEBUG)
            else
                local client = self.clients[v]
                local reqs = client:receive()
                if reqs == '' then
                    -- client is gone
                    self.clients[v] = nil
                    table.insert(removed_socks, v)
                elseif reqs ~= nil then
                    for _, req in ipairs(reqs) do
                        self:onRequest(req)
                    end
                end
            end
        end

        -- 移除已断开的client socket
        for _, s in pairs(removed_socks) do
            for i, v in ipairs(self.all_socks) do
                if v == s then
                    table.remove(self.all_socks, i)
                    break  -- break inner loop only
                end
            end
        end
    end

    for _, c in pairs(self.clients) do
        c:drainOutputBuffer()
    end
end

function PocoManager:onRequest(req)
    local client = req.client
    local method = req.method
    local params = req.params
    local func = dispatcher[method]
    local ret = {
        id = req.id,
        jsonrpc = req.jsonrpc,
        result = nil,
        error = nil,
    }

    if self.DEBUG then
        Lib.logDebug('[poco] onRequest', method)
    end

    if func == nil then
        ret.error = {
            message = string.format(
                'No such rpc method "%s", reqid: %s, client:%s',
                method,
                req.id,
                req.client:getAddress()
            )
        }
        client:send(ret)
    else
        xpcall(function()
            local result = func(table.unpack(params))
            if type(result) == 'function' then
                -- 如果返回的是一个function，则表示这个调用是异步的，目前就通过这种callback的形式的约定
                result(function(cbresult)
                    ret.result = cbresult
                    client:send(ret)
                end)
                return
            else
                ret.result = result
                client:send(ret)
            end
        end, function(msg)
            ret.error = {message = debug.traceback(msg)}
            client:send(ret)
        end)
    end
end

return PocoManager
