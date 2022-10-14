local widget_base = require "ui.widget.widget_base"

local M = Lib.derive(widget_base)

function M:init(bg, icon)
	widget_base.init(self, "widget_icon_count_down.json")

	-- self:root():SetArea({ 0, 0 }, { 0, 0 }, { 0, width }, { 0, height })
	self._text = self:child("IconCountDown-txt")
	self._bg = self:child("IconCountDown-bg")
	self._icon = self:child("IconCountDown-icon")
	self._bg:SetImage(bg)
	self._icon:SetImage(icon)
end

function M:SETTEXT(text)
	self._text:SetText(text)
end

return M
