require "common.store"

function Store:syncStore(storeData)
    Me:setData("store", storeData)
    for key, value in pairs(storeData) do
        self:getStoreItem(Bitwise64.Sr(tonumber(key), 16), Bitwise64.And(tonumber(key), 0XFFFF)).status = value
    end
    Lib.emitEvent(Event.EVENT_UPDATE_STORE)
end


function Store:changeStoreItemInfo(storeId, itemIndex, status, remainTime, msg)
    local item =  self:getStoreItem(storeId, itemIndex)
    item.status = status
    if remainTime then
        item.remainTime = remainTime
    end
    local key = tostring(Bitwise64.Or(Bitwise64.Sl(storeId, 16), itemIndex))
    Me:data("store")[key] = status
    Lib.emitEvent(Event.EVENT_UPDATE_STORE_ITEM, storeId, itemIndex)
    if string.len(msg) > 0 then
        Client.ShowTip(2, Lang:toText(msg), 40)
    end
    print("updateItem storeId:" .. storeId .. " itemIndex:" .. itemIndex .. " status:" .. status)
end