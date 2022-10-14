local widget_base = require "ui.widget.widget_base"
local M = Lib.derive(widget_base)

function M:init(fileName)
    local path = fileName or "widget_button"
    widget_base.init(self, path .. ".json")
    fileName = fileName or "widget_button"
    self.text = self:child(fileName .. "-text")
    self.image = self:child(fileName .. "-image")
    self.background = self:child(fileName .. "-background")
end

function M:text(text)
    self.text:SetText(Lang:toText(text or ""))
end

function M:showText(isShow)
    if not self.canHideText then
        return
    end
    self.text:SetVisible(isShow)
end

function M:disableAutoHideText(disable)
    self.canHideText = not disable
end

function M:enableTextBorder(enable)
    self.text:SetProperty("TextBorder", tostring(not not enable))
end

function M:image(image)
    self.image:SetImage(image or "")
end

function M:background(image)
    self.background:SetImage(image or "")
end

local function setSize(wnd, size)
    if not size or not size.width or not size.height then
        return
    end
    wnd:SetWidth({0, size.width})
    wnd:SetHeight({0, size.height})
end

function M:backgroundSize(size)
    setSize(self.background, size)
end

function M:textSize(size)
    setSize(self.text, size)
end

function M:imageSize(size)
    setSize(self.image, size)
end

local function setStretchType(wnd, type)
    if not type then
        return
    end
    wnd:SetProperty("StretchType", type)
end

function M:backgroundStretchType(type)
    setStretchType(self.background, type)
end

function M:imageStretchType(type)
    setStretchType(self.image, type)
end

local function setStretchOffset(wnd, offset)
    if not offset then
        return
    end
    wnd:SetProperty("StretchOffset", offset)
end

function M:backgroundStretchOffset(offset)
    setStretchOffset(self.background, offset)
end

function M:imageStretchOffset(offset)
    setStretchOffset(self.image, offset)
end

function M:textFontSize(font)
    if not font then
        return
    end
    self.text:SetFontSize(font)
end

function M:pos(pos)
    if not pos then
        pos = { x = 0, y = 0 }
    end
    self._root:SetXPosition({0, pos.x})
    self._root:SetYPosition({0, pos.y})
end

function M:enable(enable)
    self._root:SetActive(enable)
end

function M:onInvoke(key, ...)
    local fn = M[key]
    assert(type(fn) == "function", key)
    return fn(self, ...)
end

return M