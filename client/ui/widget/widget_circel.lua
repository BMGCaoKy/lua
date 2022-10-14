local widget_base = require "ui.widget.widget_base"

local M = Lib.derive(widget_base)

function M:init()
	widget_base.init(self, "widget_circel.json")
	self._img = self:child("widget_circel-Img")
	self._img:SetImage("empty.png")	-- uv 是从 0 到 1
	self._img:setProgram("CIRCLE")

	local size = self._img:GetPixelSize()
	self._img:material():iSize(size.x, size.y)
end

function M:setRadius(r)
	self._img:material():iRadius(r)
end

function M:setColor(r, g, b, a)
	self._img:material():iColor(r, g, b, a or 1.0)
end

function M:setThk(t)
	self._img:material():iThk(t)
end

function M:setSolid(v)
	self._img:material():iSolid(v)
end

return M
