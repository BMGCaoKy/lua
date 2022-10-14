function M:init()
    WinBase.init(self, "gameCover_edit.json")

end

function M:setGameInfo(name)

end

function M:onOpen()
    self:setGameInfo(name)
end

function M:onReload(reloadArg)

end

return M