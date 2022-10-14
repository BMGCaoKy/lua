function M:init()
    WinBase.init(self, "victorySetting_edit.json")
    self.grid = self:child("Setting-Grid")
    self.grid:InitConfig(0, 50, 1)
    self.winList = {}
    self:initTeamItem()
   
end

function M:initTeamItem()
    local winNameList = Clientsetting.getData("editVictorySettingUIList") or {
        "mapEditVictorySettingLayout",
    }
    for _, name in pairs(winNameList) do
        local win = UI:getWnd(name) and UI:getWnd(name) or nil
        if win then
            self.grid:AddItem(win:root())
            self.winList[#self.winList + 1] = win
        end
    end

end

function M:saveData()

end

function M:onOpen()
    for _, win in pairs(self.winList) do
        win:onOpen()
    end
end

function M:onReload(reloadArg)

end

return M