

function Lib.getItemBgImage(item)
	return item and item:var("attachVar") and item:var("attachVar").isAttach and "set:bgs.json image:bg_purple.png" or ""
end

function Lib.getItemEnchantColor(item)
    if item and item:var("attachVar") and item:var("attachVar").isAttach then 
        return 238/255, 170/255, 255/255, 1
    else
        return 1,1,1,1
    end
end