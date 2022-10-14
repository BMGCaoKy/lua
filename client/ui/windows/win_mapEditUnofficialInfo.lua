function M:init()
    WinBase.init(self, "gameCover1_edit.json")
end

function M:setGameInfo(name)

end

function M:onOpen(name)
    self:setGameInfo(name)
end

function M:onReload(reloadArg)

end

return M