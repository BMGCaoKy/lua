function M:init()
	WinBase.init(self, "popWnd_edit.json")

    self.BgBtn = self:child("popWndRoot-BgBtn")
    
end

function M:onClose()

end

function M:onOpen()

end

function M:onReload()
end

return M
