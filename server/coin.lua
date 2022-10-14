require "common.coin"
local setting = require "common.setting"

function Coin:consumeCoin(coinName, player, count)
    local coin = Coin:getCoin(coinName)
    local name = coin and coin.item and coin.item.name
    local type = coin and coin.item and coin.item.type
    if not name or not type then
        return false
    end
    local function consumeBagItem(itemName, proc, check)
        return player:tray():remove_item(itemName, count, check, false, proc, "buy_shop")
    end
    if type == "Item" then
        if consumeBagItem(name, false, true) then
            consumeBagItem(name)
            return true
        end
    elseif type == "Block" then
        if consumeBagItem("/block", function(item)
            return item:block_id() == setting:name2id("block", name)
        end, true) then
            consumeBagItem("/block", function(item)
                return item:block_id() == setting:name2id("block", name)
            end)
            return true
        end
    end
    return false
end