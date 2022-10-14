local widget_base = require "ui.widget.widget_base"

local M = Lib.derive(widget_base)

function M:init(width, height, baseText, exText)
	widget_base.init(self, "widget_text.json")

	self:root():SetArea({ 0, 0 }, { 0, 0 }, { 0, width }, { 0, height })
	self._baseTextStr = baseText
	self._text = self:child("widget-text-disc")
	self._text:SetText(baseText..exText)
end

function M:SETTEXT(text)
	self._text:SetText(self._baseTextStr..text)
end

function M:SET_HORIZONALIGN(type)
	self:root():SetHorizontalAlignment(type)
end

function M:SET_TEXT_HORIZONALIGN(type)
	self._text:SetTextHorzAlign(type)
end

function M:SET_TEXT_COLOR(color)
	self._text:SetTextColor(color)
end

function M:FRAME_AREA(xPos, yPos, width, height)
	self:root():SetArea(xPos or { 0, 0 }, yPos or { 0, 0 }, width or { 0, 150 }, height or { 0, 50 })
end

function M:SET_XPOSTION(xPos)
	self:root():SetXPosition(xPos or { 0, 0 })
end

return M
