

print("g2060 Start loader script!", World.GameName)

local root = Root.Instance()
package.path = root:getRootPath() .. "lua/libraries/?.lua;" .. root:getRootPath() .. "lua/libraries/luasocket/?.lua;" .. package.path


World.isClient = true
Blockman.Instance().singleGame = false

--[[local filename = "server.lock"
local f = io.open(filename, "r")
if f then
    f:close()
    print("server is running, disable single game!")
    Blockman.Instance().singleGame = false
end]]--

loadingUiPage = function(event, ...)
    print("loadingUiPage event = ", event)
end

handle_tick = function()

end

