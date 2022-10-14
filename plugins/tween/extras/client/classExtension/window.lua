
CEGUIWindow._scale = 1

local function _refreshSize(self)
    local oldSize = self:getWindowRenderer():getSize()
    local newSize = oldSize * self._scale

    self:getWindowRenderer():setSize(newSize)
end 

function CEGUIWindow:setScale(value)
    self._scale = value
    _refreshSize(self)
end

function CEGUIWindow:scale()
    self._refreshSize()
    return self._scale
end

function CEGUIWindow:setSize(...)
    self:getWindowRenderer():setSize(...)
    _refreshSize(self)
end

