local BmNode = require('autotest.poco.bm_node')

local FrozenNode = {}
FrozenNode.__index = FrozenNode
setmetatable(FrozenNode, BmNode)


function FrozenNode:new(node, screenWidth, screenHeight, isNewGUI)
    local n = {}
    setmetatable(n, FrozenNode)
    n.node = node
    n.screenWidth = screenWidth
    n.screenHeight = screenHeight
    n.isNewGUI = isNewGUI
    return n
end

function FrozenNode:getAvailableAttributeNames()
    local ret = {
        '_instanceId',
    }
    for _, name in ipairs(BmNode.getAvailableAttributeNames(self)) do
        table.insert(ret, name)
    end
    return ret
end

function FrozenNode:getAttr(attrName)
    if attrName == '_instanceId' then
        -- -- 仅用于setText时找回对应的node
        -- if self.node.setString ~= nil or self.node.setText ~= nil then
        --     return tostring(self.node)
        -- end
        -- return nil
        if self.isNewGUI then
            return self.node:getID()
        else
            return self.node:getId()
        end
    end

    return BmNode.getAttr(self, attrName)
end


return FrozenNode