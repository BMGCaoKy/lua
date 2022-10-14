local shortBlock = L("shortBlock", Lib.derive(EditorModule.baseDerive))

function shortBlock:click(item)
    local player = Player.CurPlayer
    player:saveHandItem(item)
    self.info("block", item:icon())
end

RETURN(shortBlock)