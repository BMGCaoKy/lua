-- local cc = _G.cc or require('cc')
local AbstractNode = require('autotest.poco.sdk.AbstractNode')

local function getNodeName(node, isNewGUI)
    if isNewGUI then
        return node:getName()
    else
        return node:GetName()
    end
end

local function getNodeParent(node, isNewGUI)
    if isNewGUI then
        return node:getParent()
    else
        return node:GetParent()
    end
end

local function getNodeText(node, isNewGUI)
    if isNewGUI then
        return node:getText()
    else
        return node:GetText()
    end
end

local function getNodeType(node, isNewGUI)
    if isNewGUI then
        return node:getType()
    else
        return node:GetTypeStr()
    end
end

local function getRootNode()
    return UI.root or UI._desktop
end

local function isNodeEnabled(node, isNewGUI)
    if isNewGUI then
        return not node:isDisabled()
    else
        return node:IsEnabled()
    end
end

local function isNodeVisible(node, isNewGUI)
    if isNewGUI then
        return node:isVisible()
    else
        return node:IsVisible()
    end
end

local function setNodeText(node, isNewGUI, text)
    if isNewGUI then
        return node:setText(text)
    else
        return node:SetText(text)
    end
end

local function setNodeVisible(node, isNewGUI, visible)
    if isNewGUI then
        return node:setVisible(visible)
    else
        return node:SetVisible(visible)
    end
end


local Node = {}
Node.__index = Node
setmetatable(Node, AbstractNode)

function Node:new(node, screenWidth, screenHeight, isNewGUI)
    local n = {}
    setmetatable(n, Node)
    n.node = node
    n.screenWidth = screenWidth
    n.screenHeight = screenHeight
    n.isNewGUI = isNewGUI
    return n
end

function Node:getParent()
    -- local parent = self.node:getParent()
    local parent = getNodeParent(self.node, self.isNewGUI)
    if parent == nil then
        return nil
    end
    return self:new(parent, self.screenWidth, self.screenHeight)
end

function Node:getChildren()
    local children = {}

    -- for _, child in ipairs(self.node:getChildren()) do
    --     table.insert(children, self:new(child, self.screenWidth, self.screenHeight))
    -- end
    if self.isNewGUI then
        local last = self.node:getChildCount() - 1
        for i = 0, last do
            local child = self.node:getChildAtIdx(i)
            table.insert(
                children,
                self:new(child, self.screenWidth, self.screenHeight, self.isNewGUI)
            )
        end
    else
        local last = self.node:GetChildCount() - 1
        for i = 0, last do
            local child = self.node:GetChildByIndex(i)
            table.insert(
                children,
                self:new(child, self.screenWidth, self.screenHeight, self.isNewGUI)
            )
        end
    end

    return children
end

function Node:getAvailableAttributeNames()
    local ret = {
        'text',
        -- 'touchable',
        'enabled',
        -- 'tag',
        -- 'desc',
        -- 'rotation',
        -- 'rotation3D',
        -- 'skew',
    }
    for _, name in ipairs(AbstractNode.getAvailableAttributeNames(self)) do
        table.insert(ret, name)
    end
    return ret
end

function Node:getAttr(attrName)
    if attrName == 'visible' then
        local visible = isNodeVisible(self.node, self.isNewGUI)
        if not visible then
            return false
        end

        -- if the node is visible, check its parent's visibility
        local isNewGUI = self.isNewGUI
        local parent = getNodeParent(self.node, isNewGUI)
        while parent do
            local parentVisible = isNodeVisible(parent, isNewGUI)
            if not parentVisible then
                return false
            end
            parent = getNodeParent(parent, isNewGUI)
        end
        return true

    elseif attrName == 'name' then
        local name = getNodeName(self.node, self.isNewGUI)
        if name == '' then
            -- name = self.node:getDescription()
            name = 'NoName'
        end
        return name

    elseif attrName == 'text' then
        -- -- auto strip
        -- if self.node.getString then
        --     return self.node:getString():match("^%s*(.-)%s*$")    -- for Label
        -- elseif self.node.getStringValue then
        --     return self.node:getStringValue():match("^%s*(.-)%s*$")  -- for TextField
        -- elseif self.node.getTitleText then
        --     return self.node:getTitleText():match("^%s*(.-)%s*$")  -- for Button
        -- end
        -- return nil
        return getNodeText(self.node, self.isNewGUI)

    elseif attrName == 'type' then
        -- local nodeType = tolua.type(self.node)
        -- nodeType = nodeType:gsub("^ccui%.", '')
        -- nodeType = nodeType:gsub("^cc%.", '')
        -- return nodeType
        return getNodeType(self.node, self.isNewGUI)

    elseif attrName == 'pos' then
        -- -- 转换成归一化坐标系，原点左上角
        -- local pos = self.node:convertToWorldSpaceAR(cc.p(0, 0))
        -- pos.x = pos.x / self.screenWidth
        -- pos.y = pos.y / self.screenHeight
        -- pos.y = 1 - pos.y
        -- return {pos.x, pos.y}
        local pos = {0, 0}
        local rootArea = getRootNode():GetUnclippedOuterRect()

        if self.isNewGUI then
        else
            local area = self.node:GetUnclippedOuterRect()
            pos[1] = (area[1] + area[3]) * 0.5 / rootArea[3]
            pos[2] = (area[2] + area[4]) * 0.5 / rootArea[4]
        end
        return pos

    elseif attrName == 'size' then
        -- -- 转换成归一化坐标系
        -- local size = self.node:getContentSize()
        -- -- 有些版本的engine对于某类特殊节点会没有这个值，所以要判断
        -- if size ~= nil then
        --     size.width = size.width / self.screenWidth
        --     size.height = size.height / self.screenHeight
        --     return {size.width, size.height}
        -- end
        local size = {0, 0}
        local rootArea = getRootNode():GetUnclippedOuterRect()

        if self.isNewGUI then
        else
            local area = self.node:GetUnclippedOuterRect()
            size[1] = (area[3] - area[1]) / rootArea[3]
            size[2] = (area[4] - area[2]) / rootArea[4]
        end
        return size

    -- elseif attrName == 'scale' then
    --     return {self.node:getScaleX(), self.node:getScaleY()}

    -- elseif attrName == 'anchorPoint' then
    --     local anchor = self.node:getAnchorPoint()
    --     anchor.y = 1 - anchor.y
    --     return {anchor.x, anchor.y}

    -- elseif attrName == 'zOrders' then
    --     local zOrders = {
    --         global = self.node:getGlobalZOrder(),
    --         ['local'] = self.node:getLocalZOrder(),
    --     }
    --     return zOrders

    -- elseif attrName == 'touchable' then
    --     if self.node.isTouchEnabled then
    --         return self.node:isTouchEnabled()
    --     end
    --     return nil

    -- elseif attrName == 'tag' then
    --     return self.node:getTag()

    elseif attrName == 'enabled' then
        -- if self.node.isEnabled then
        --     return self.node:isEnabled()
        -- end
        -- return nil
        -- TODO
        return isNodeEnabled(self.node, self.isNewGUI)

    -- elseif attrName == 'desc' then
    --     return self.node:getDescription()

    -- elseif attrName == 'rotation' then
    --     local rotationX, rotationY
    --     if self.node.getRotationSkewX ~= nil and self.node.getRotationSkewY ~= nil then
    --         rotationX, rotationY = self.node:getRotationSkewX(), self.node:getRotationSkewY()
    --     end
    --     return rotationX or rotationY

    -- elseif attrName == 'rotation3D' then
    --     local rotationX, rotationY
    --     if self.node.getRotationSkewX ~= nil and self.node.getRotationSkewY ~= nil then
    --         rotationX, rotationY = self.node:getRotationSkewX(), self.node:getRotationSkewY()
    --     end
    --     if rotationX == rotationY and self.node.getRotation3D then
    --         return self.node:getRotation3D()
    --     end
    --     return nil

    -- elseif attrName == 'skew' then
    --     if self.node.getSkewX and self.node.getSkewY then
    --         return {self.node:getSkewX(), self.node:getSkewY()}
    --     end
    --     return nil

    end

    return AbstractNode.getAttr(self, attrName)
end

function Node:setAttr(attrName, val)
    if attrName == 'text' then
        -- if self.node.setString then
        --     self.node:setString(val)
        --     return true
        -- elseif self.node.setText then
        --     self.node:setText(val)
        --     return true
        -- end
        setNodeText(self.node, self.isNewGUI, val)
        return true

    elseif attrName == 'visible' then
        setNodeVisible(self.node, self.isNewGUI, val)
        return true

    end
    return AbstractNode.setAttr(self, attrName, val)
end


return Node