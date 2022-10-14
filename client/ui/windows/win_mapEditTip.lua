function M:init()
    WinBase.init(self, "tip_edit.json")

    self:child("Edit-Map-Tip-Dlg-Sure"):SetText(Lang:toText("win.map.edit.entity.setting.fetch.delete"))
    self:child("Edit-Map-Tip-Dlg-Cancel"):SetText(Lang:toText("composition.replenish.no.btn"))
    self:child("Edit-Map-Tip-Dlg-Title"):SetText(Lang:toText("composition.replenish.title"))

	self:subscribe(self:child("Edit-Map-Tip-Close-Btn"), UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
    end)

    self:subscribe(self:child("Edit-Map-Tip-Bg"), UIEvent.EventWindowClick, function()
        UI:closeWnd(self)
    end)

	self:subscribe(self:child("Edit-Map-Tip-Dlg-Sure"), UIEvent.EventButtonClick, function()
		CGame.instance:deleteDir(self.mapPath)
		UI:closeWnd(self)
		UI:closeWnd(self.closeWin)
		Lib.emitEvent(Event.EVENT_MAP_LAYOUT, self.mapName)
    end)

	self:subscribe(self:child("Edit-Map-Tip-Dlg-Cancel"), UIEvent.EventButtonClick, function()
		UI:closeWnd(self)
    end)

end

function M:onOpen(mapPath, win, mapName)
	self.mapPath = mapPath
	self.closeWin = win
	self.mapName = mapName
    self:child("Edit-Map-Tip-Dlg-Tips"):SetText(Lang:toText({"delete.map.tip", mapName}))
end

function M:onReload(reloadArg)

end

return M