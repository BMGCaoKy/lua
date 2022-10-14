local setting = require "common.setting"

function M:init()
	WinBase.init(self, "edit_headUI.json", true)
	self.bg = self:child("edit_headUI-bg")
    self.icon = self:child("edit_headUI-icon")
end

function M:onOpen(o)
    local icon, bg = o.picPath, o.bg
    self.icon:SetImage(icon or "")
    self.bg:SetImage(bg or "image/icon/bubbling.png")
end

function M:close()
	self.isOpen = false
	self._selectedCell = nil
end