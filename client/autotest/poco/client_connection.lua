local socket = require('socket.core')
local json = require('autotest.poco.support.dkjson')  -- 一定要用这个模块不然字符串发送有问题
local struct = require('autotest.poco.support.struct')

-- client handler
local ClientConnection = {}
ClientConnection.__index = ClientConnection

ClientConnection.DEBUG = false
ClientConnection.sock = nil
ClientConnection.buf = ''
ClientConnection.sendbuf = ''

function ClientConnection:new(sock, debug)
    if debug == nil then
        debug = false
    end

    local c = {}
    setmetatable(c, ClientConnection)
    c.DEBUG = debug
    c.sock = sock
    c.buf = ''
    c.sendbuf = ''
    c.sock:setoption("tcp-nodelay", true)
    c.sock:setoption('keepalive', true)
    c.sock:settimeout(0.0)
    return c
end

function ClientConnection:input(data)
    self.buf = self.buf .. data
    local ret = {}
    while #self.buf > 4 do 
        local len = struct.unpack('i', string.sub(self.buf, 1, 4))
        if #self.buf >= len + 4 then
            local content = string.sub(self.buf, 5, 4 + len)
            self.buf = string.sub(self.buf, 5 + len)
            if self.DEBUG then
                print(content)
            end
            ret[#ret + 1] = json.decode(content)
        else
            break
        end
    end
    return ret
end

function ClientConnection:receive()
    local chunk, status, partial = self.sock:receive(65535)
    if self.DEBUG then
        -- print('client recv', partial or chunk)
        Lib.logDebug('[poco] client recv:', partial or chunk)
    end
    if (not chunk or chunk == '') and (not partial or partial == '') then
        self:close()
        return ''
    else
        local reqs = self:input(partial or chunk)
        if #reqs > 0 then
            for _, req in ipairs(reqs) do
                req.client = self
            end
            return reqs
        end
    end
end

function ClientConnection:send(data)
    local data = json.encode(data)
    local sdata = struct.pack('i', #data) .. data
    if self.DEBUG then
        print(sdata)
    end
    self.sendbuf = self.sendbuf .. sdata
end

function ClientConnection:drainOutputBuffer()
    while #self.sendbuf > 0 do
        local r, w, s = socket.select(nil, {self.sock}, 0)
        if #w > 0 then
            local txSize, errmsg, partialTxSize = self.sock:send(self.sendbuf)
            local txSize = txSize or partialTxSize
            self.sendbuf = string.sub(self.sendbuf, txSize + 1)
            if errmsg ~= nil then
                break
            end
        else
            break
        end
    end
end

function ClientConnection:close()
    self.sock:shutdown('both')
    self.sock:close()
    self.buf = ''
    self.sendbuf = ''
    print('[poco] client disconnect')
end

function ClientConnection:getAddress()
    return self.sock:getpeername()
end

return ClientConnection