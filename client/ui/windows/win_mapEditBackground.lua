function M:init()
    WinBase.init(self, "background_edit.json")

    self:subscribe(self._root, UIEvent.EventWindowClick, function()
        UI:closeWnd("mapEditItemBag")
        UI:closeWnd(self)
	end)
end

return M