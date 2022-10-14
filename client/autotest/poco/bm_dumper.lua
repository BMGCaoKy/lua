-- local cc = _G.cc or require('cc')
local AbstractDumper = require('autotest.poco.sdk.AbstractDumper')
local Node = require('autotest.poco.bm_node')

-- local director = cc.Director:getInstance()

local Dumper = {}
Dumper.__index = Dumper
setmetatable(Dumper, AbstractDumper)

function Dumper:getRoot()
    -- local winSize = director:getWinSize()
    -- return Node:new(director:getRunningScene(), winSize.width, winSize.height)
end

return Dumper