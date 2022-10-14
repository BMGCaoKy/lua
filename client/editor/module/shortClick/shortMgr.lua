local shortMgr = L("shortMgr", Lib.derive(EditorModule.baseDerive))
local shortMonster = require "editor.module.shortClick.shortMonster"
local shortBlock = require "editor.module.shortClick.shortBlock"

function shortMgr:click(item)
    local player = Player.CurPlayer
    player:saveHandItem()
    local type = item:type()
    if type == "entity" then
        shortMonster:click(item)
    elseif type == "block" then
        self.info(shortBlock, shortBlock.click)
        shortBlock:click(item)
    end
end

function shortMgr:emptyClick()
    local player = Player.CurPlayer
    player:saveHandItem()
end

RETURN(shortMgr)