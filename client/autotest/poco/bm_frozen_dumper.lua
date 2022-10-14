local AbstractDumper = require('autotest.poco.sdk.AbstractDumper')
local FrozenNode = require('autotest.poco.bm_frozen_node')


local FrozenDumper = {}
FrozenDumper.__index = FrozenDumper
setmetatable(FrozenDumper, AbstractDumper)

FrozenDumper._nodes_cache = {}  -- tostring(node) -> FrozenNode instance

function FrozenDumper:getRoot()
    -- 每次获取hierarchy前清空一下上次的node缓存
    self._nodes_cache = {}

    -- local winSize = director:getWinSize()
    -- return FrozenNode:new(director:getRunningScene(), winSize.width, winSize.height)
    if UI.root then
        return FrozenNode:new(UI.root, 100, 100, true)
    end
    if UI._desktop then
        return FrozenNode:new(UI._desktop, 100, 100, false)
    end
end

function FrozenDumper:dumpHierarchyImpl(node, onlyVisibleNode)
    local result = AbstractDumper.dumpHierarchyImpl(self, node, onlyVisibleNode)

    -- 如果这个node有_instanceId，则缓存起来备用    
    local instanceId = node:getAttr('_instanceId')
    if instanceId ~= nil then
        self._nodes_cache[instanceId] = node
    end

    return result
end

function FrozenDumper:getCachedNode(instanceId)
    return self._nodes_cache[instanceId]
end

return FrozenDumper